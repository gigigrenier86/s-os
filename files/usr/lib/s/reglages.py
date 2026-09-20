#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Les reglages rapides de S — ce que la machine sait vraiment changer.

POURQUOI UN FICHIER A PART. Le noyau lit la machine pour en tirer des astres ;
ici on la REGLE, ce qui est un tout autre metier — chaque reglage a son outil,
son cout et sa facon d'echouer. Les melanger ferait grossir noyau.py sans que
l'un serve jamais a l'autre.

RIEN N'EST INCONDITIONNEL. C'est la regle du carnet, et elle vaut ici plus
qu'ailleurs : cette machine n'a AUCUN adaptateur Bluetooth visible — mesure du
2026-08-26, huit demarrages sans qu'il s'annonce une seule fois, le port USB
interne echouant a s'enumerer avec « error -71 ». Ecrire une etoile Bluetooth
en dur donnerait un reglage mort et muet. Chaque reglage se DECLARE indisponible
quand son materiel ou son outil manque, et reapparait le jour ou il revient.

CE QU'ON NE REIMPLEMENTE PAS : le volume passe par wpctl (PipeWire), la
luminosite par ddcutil (DDC/CI), le reseau par nmcli, l'energie par tuned-adm.
Aucun de ces quatre n'est reecrit ici — on les appelle, et on rend ce qu'ils
disent.
"""

import grp
import json
import os
import re
import shutil
import subprocess
import threading
import time


# La lecture d'un reglage coute cher pour certains : releve du 2026-08-26,
# « ddcutil getvcp 10 » prend 483 ms sur cette machine, parce qu'il parle en
# I2C a l'ecran. Relire cela a chaque ouverture du panneau serait une demi-
# seconde de panneau fige. On garde donc ce qu'on a lu, brievement.
_CACHE = {}
_TTL = 4.0


def _outil(nom):
    return shutil.which(nom)


def _lire(argv, delai=6):
    """Lance et rend (code, sortie). Ne leve jamais."""
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=delai)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except (OSError, subprocess.SubprocessError):
        return 127, ""


def _cache(cle, calcul):
    vu = _CACHE.get(cle)
    if vu is not None and (time.monotonic() - vu[1]) < _TTL:
        return vu[0]
    valeur = calcul()
    _CACHE[cle] = (valeur, time.monotonic())
    return valeur


def _oublier(cle):
    _CACHE.pop(cle, None)


# --------------------------------------------------------------------------
# Le son
# --------------------------------------------------------------------------

def _volume():
    if not _outil("wpctl"):
        return None
    code, sortie = _lire(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
    if code != 0:
        return None
    # « Volume: 0.65 » ou « Volume: 0.65 [MUTED] »
    part = sortie.replace("Volume:", "").strip().split()
    if not part:
        return None
    try:
        v = float(part[0])
    except ValueError:
        return None
    return {"valeur": int(round(v * 100)), "muet": "MUTED" in sortie.upper()}


def _regler_volume(pourcent):
    if not _outil("wpctl"):
        return False, "aucun controle du son"
    pourcent = max(0, min(150, int(pourcent)))
    code, sortie = _lire(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",
                          "%d%%" % pourcent])
    _oublier("volume")
    return (code == 0), (sortie.strip()[:120] or "%d %%" % pourcent)


def _basculer_muet():
    if not _outil("wpctl"):
        return False, "aucun controle du son"
    code, sortie = _lire(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
    _oublier("volume")
    return (code == 0), (sortie.strip()[:120] or "son")


# --------------------------------------------------------------------------
# L'egaliseur — EasyEffects, jamais reimplemente
# --------------------------------------------------------------------------
#
# DEMANDE DE L'UTILISATEUR LE 2026-08-30. Aucun outil n'etait deja pose : ni
# EasyEffects ni son ancetre PulseEffects. Recherche faite avant d'ecrire une
# ligne — le format « etoile » (bascule/glissiere/choix) de cette barre ne se
# prete pas a un vrai egaliseur a plusieurs bandes, et personne ne le
# reimplemente : EasyEffects (paquet Fedora officiel, 8.2.8 au moment
# d'ecrire, ~2,8 Mo) EST cet outil, entretenu par l'amont. L'etoile ne fait
# que le PILOTER — bascule d'un coup d'oeil, fenetre complete pour regler les
# bandes elle-meme.
#
# LE VRAI OUTIL, INSPECTE AVANT DE DEVINER SON APPEL. « easyeffects --help »
# donne, entre autres :
#   -b, --bypass <bypass-state>   1 pour activer le bypass (donc ETEINDRE les
#                                  effets), 2 pour le desactiver (les ALLUMER),
#                                  3 pour lire l'etat actuel.
#   -w, --hide-window              lance sans montrer la fenetre.
# La forme exacte de la reponse a « --bypass 3 » n'a pas ete observee en
# direct — aucune session PipeWire dans le conteneur ou l'outil a ete
# inspecte — mais son propre binaire porte l'expression reguliere qu'il
# emploie pour SE relire lui-meme : « ^global_bypass:([01]) ». C'est donc son
# propre format, pas une supposition batie a cote.
_MOTIF_BYPASS = re.compile(r"global_bypass:([01])")


def _assurer_egaliseur_lance():
    """Demarre le service resident s'il ne tourne pas deja — sans attendre.

    EasyEffects doit tourner pour repondre a « --bypass ». Le service
    resident (s-egaliseur.service, meme patron que s-windows.service pour le
    wineserver) le tient deja pret des l'ouverture de session ; cet appel
    n'est qu'un filet pour le jour ou il n'aurait pas encore demarre.
    """
    _lire(["systemctl", "--user", "start", "s-egaliseur.service"], delai=15)


def _egaliseur():
    if not _outil("easyeffects"):
        return None
    _assurer_egaliseur_lance()
    code, sortie = _lire(["easyeffects", "--bypass", "3"], delai=10)
    if code != 0:
        return None
    m = _MOTIF_BYPASS.search(sortie)
    if not m:
        return None
    # bypass=1 veut dire « les effets sont COUPES » : « actif », pour cette
    # etoile, c'est l'inverse du bypass.
    return {"actif": m.group(1) == "0"}


def _regler_egaliseur(actif):
    if not _outil("easyeffects"):
        return False, "aucun egaliseur sur cette machine"
    _assurer_egaliseur_lance()
    code, sortie = _lire(["easyeffects", "--bypass", "2" if actif else "1"], delai=10)
    _oublier("egaliseur")
    if code != 0:
        return False, (sortie.strip()[:120] or "reglage refuse")
    if actif:
        # OUVRIR LA FENETRE POUR REGLER LES BANDES — DEMANDE EXPLICITE DE
        # L'UTILISATEUR, PAS SEULEMENT LA BASCULE. EasyEffects est une
        # application a instance unique (GApplication) : le relancer SANS
        # « --hide-window » ne demarre pas un second exemplaire, il active
        # l'exemplaire existant — le meme mecanisme qu'un second clic sur une
        # icone deja ouverte fait remonter sa fenetre.
        #
        # NON VERIFIE EN DIRECT : aucune session PipeWire complete n'etait
        # disponible pour l'observer au moment d'ecrire ce fichier — c'est le
        # comportement attendu d'une GApplication a instance unique, pas une
        # mesure sur cette machine.
        try:
            subprocess.Popen(["easyeffects"], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass
    return True, ("egaliseur allume" if actif else "egaliseur eteint")


# --------------------------------------------------------------------------
# La webcam — une bascule de confidentialite, jamais un chmod a l'aveugle
# --------------------------------------------------------------------------
#
# DEMANDE DE L'UTILISATEUR LE 2026-08-30. MESURE AVANT D'ECRIRE : cette
# machine porte une vraie webcam USB (« j5 WebCam JVCU100 », /dev/video1 et
# /dev/video2) ET une camera VIRTUELLE (« OBS Virtual Camera », /dev/video0,
# posee par v4l2loopback pour recevoir ce qu'OBS y ecrit). Les confondre
# aurait pose une etoile qui bloque la sortie d'OBS au lieu du micro-espion —
# exactement l'inverse de ce qu'on cherche.
#
# LA DISTINCTION, MESUREE ET NON DEVINEE : le lien « device » de chaque noeud
# sous /sys/class/video4linux/videoN/ resout, pour la webcam reelle, a travers
# un vrai bus USB (« .../usb1/1-7/1-7:1.0 ») ; pour la camera virtuelle, il
# resout a « /sys/devices/VIRTUAL/video4linux/video0/device ». Le mot
# « virtual » dans le chemin resolu est le seul signal fiable trouve — aucun
# champ dedie n'existe pour ca en v4l2.
#
# LE MECANISME DE BLOCAGE : PAS DE RFKILL POUR UNE CAMERA — verifie,
# « rfkill list » sur cette machine n'a qu'une entree, le Wi-Fi. Et cette
# machine n'appartient PAS au groupe unix « video » (verifie : « id » ne le
# liste pas) : le SEUL acces qu'elle a au noeud vient d'une ACL POSIX precise
# — « user:RyuRex:rw- », posee par systemd-logind (uaccess) a l'ouverture de
# session. Retirer PRECISEMENT cette entree ACL coupe l'acces sans toucher au
# proprietaire, au groupe, ni au mode de base — et la remettre restaure
# exactement ce que logind avait pose.
def _noeuds_camera_reels():
    """(nom, [/dev/videoN, ...]) des vraies cameras — jamais une virtuelle."""
    racine = "/sys/class/video4linux"
    try:
        entrees = sorted(os.listdir(racine))
    except OSError:
        return None, []
    nom = None
    noeuds = []
    for entree in entrees:
        reel = os.path.realpath(os.path.join(racine, entree, "device"))
        if "/virtual/" in reel:
            continue
        if nom is None:
            try:
                with open(os.path.join(racine, entree, "name"),
                          encoding="utf-8") as f:
                    nom = f.read().strip()
            except OSError:
                nom = entree
        noeuds.append("/dev/" + entree)
    return nom, noeuds


def _utilisateur_courant():
    return os.environ.get("USER") or os.environ.get("LOGNAME") or ""


def _acl_utilisateur_presente(noeud, utilisateur):
    code, sortie = _lire(["getfacl", "--omit-header", noeud])
    if code != 0:
        return None
    motif = "user:%s:" % utilisateur
    return any(l.startswith(motif) for l in sortie.splitlines())


def _membres_groupe_video():
    """Comptes qui contourneraient ce reglage par le groupe unix « video »
    (gid 39, permission de base root:video 0660 sur /dev/video*) plutot
    que par l'ACL nommee que ce fichier pose et retire. Vide sur cette
    machine au 2026-09-01 — aucun second compte n'existe — mais rien ne le
    garantit pour demain, et l'ACL ne protege qu'UN utilisateur nomme.
    Voir CLAUDE.md, 2026-09-01, « le meme probleme est-il ailleurs »."""
    try:
        return [m for m in grp.getgrnam("video").gr_mem
                if m != _utilisateur_courant()]
    except KeyError:
        return []


# CE REGLAGE NE PROTEGE QUE L'UTILISATEUR LINUX COURANT, JAMAIS ANDROID.
# Mesure du 2026-09-01 (CLAUDE.md) : le processus camera de Waydroid tourne
# sous un uid etranger (1047 sur cette machine), sans ACL, sans membre du
# groupe video, sans capacite DAC_OVERRIDE — le bind-mount LXC rend le
# noeud VISIBLE dans le conteneur, jamais ACCESSIBLE. Android n'a donc
# aujourd'hui aucun acces reel a la camera, dans aucun des deux etats de ce
# reglage : il n'y a rien a etendre, seulement un nom a ne pas faire mentir
# sur sa portee — d'ou « Webcam (Linux) » plutot que « Webcam » nu.
def _webcam():
    if not _outil("getfacl") or not _outil("setfacl"):
        return None
    nom, noeuds = _noeuds_camera_reels()
    if not noeuds:
        return None
    utilisateur = _utilisateur_courant()
    if not utilisateur:
        return None
    # UN SEUL NOEUD OUVERT SUFFIT A FILMER — « actif » (la camera est
    # accessible) reste donc vrai des que L'UN des noeuds porte encore
    # l'acces, jamais seulement quand ils le portent tous.
    etats = [_acl_utilisateur_presente(n, utilisateur) for n in noeuds]
    if any(e is None for e in etats):
        return None
    return {"actif": any(etats), "nom": nom, "noeuds": noeuds,
            "autres_comptes": _membres_groupe_video()}


def _basculer_webcam(actif):
    outil = _outil("setfacl")
    if not outil:
        return False, "aucun controle d'acces sur cette machine"
    nom, noeuds = _noeuds_camera_reels()
    if not noeuds:
        return False, "aucune camera sur cette machine"
    utilisateur = _utilisateur_courant()
    if not utilisateur:
        return False, "utilisateur inconnu"
    pkexec = _outil("pkexec")
    if not pkexec:
        return False, "pkexec n'est pas sur cette machine"
    # « root » possede le noeud, pas nous : meme si l'ACL nous donne
    # actuellement rw-, modifier une ACL exige d'etre le proprietaire ou root.
    drapeaux = (["-m", "u:%s:rw-" % utilisateur] if actif
                else ["-x", "u:%s" % utilisateur])
    ok_tout = True
    for noeud in noeuds:
        code, _s = _lire([pkexec, outil] + drapeaux + [noeud], delai=10)
        ok_tout = ok_tout and (code == 0)
    _oublier("webcam")
    return ok_tout, ("%s accessible" % (nom or "camera") if actif
                     else "%s bloquee" % (nom or "camera"))


# --------------------------------------------------------------------------
# La luminosite — par DDC/CI, la seule voie sur une machine sans ecran integre
# --------------------------------------------------------------------------
#
# CETTE MACHINE N'A PAS D'ECRAN A ELLE. Un mini-PC de bureau n'a donc aucun
# « backlight » dans /sys : brightnessctl n'y trouverait rien. DDC/CI parle a
# l'ecran par le bus I2C du cable video, et le LG ULTRAGEAR de cette machine
# repond — mesure du 2026-08-26, luminosite 60/100 lue sans droits root grace a
# l'ACL posee sur /dev/i2c-1.

def _ddc(code_vcp):
    if not _outil("ddcutil"):
        return None
    code, sortie = _lire(["ddcutil", "getvcp", str(code_vcp), "--brief"], delai=12)
    if code != 0:
        return None
    # Forme brieve : « VCP 10 C 60 100 »
    champs = sortie.split()
    if len(champs) < 5:
        return None
    try:
        return {"valeur": int(champs[3]), "max": int(champs[4])}
    except (ValueError, IndexError):
        return None


# LE PLANCHER N'EST PAS UNE PRUDENCE, C'EST UN CORRECTIF. Mesure le
# 2026-08-26 : l'utilisateur a descendu la luminosite ET le contraste a ZERO en
# essayant la molette. L'ecran est alors noir — et la barre laterale qui
# permettrait de remonter est invisible comme le reste. Le geste se rendait
# lui-meme irreversible, ce qui est exactement ce qu'un reglage ne doit jamais
# faire.
#
# Dix pour cent, parce que l'ecran y reste lisible. Un plancher plus haut
# priverait d'un reglage legitime — travailler la nuit dans le noir.
PLANCHER_ECRAN = 10


def _regler_ddc(code_vcp, valeur):
    if not _outil("ddcutil"):
        return False, "aucun ecran pilotable"
    valeur = max(PLANCHER_ECRAN, min(100, int(valeur)))
    code, sortie = _lire(["ddcutil", "setvcp", str(code_vcp), str(valeur)], delai=12)
    _oublier("luminosite")
    return (code == 0), (sortie.strip().splitlines()[-1][:120] if code and sortie
                         else "%d %%" % valeur)


# --------------------------------------------------------------------------
# Le mode Jeu — ce que Salon et Retro appliquent en entrant, defont en sortant
# --------------------------------------------------------------------------
#
# CE N'EST PLUS UN REGLAGE DE LA BARRE LATERALE. Le 2026-09-01 l'utilisateur
# avait demande trois modes interchangeables (Travail, Jeu, Art) ; le
# 2026-09-20, invite a choisir les options a retirer, il a repondu « enleve
# tout sauf retroarch », et « Mode S », « Energie » et « Android : affichage »
# ont quitte la barre. Ce qui RESTE est le mecanisme, parce que ce qu'il garde
# en depend : s-retro-rapide, s-salon-rapide et s-salon-session appellent
# regler("mode", "jeu") en entrant et regler("mode", "travail") en sortant.
# Sans lui, RetroArch et Salon perdraient le profil de performance a l'entree
# et le retour au profil normal a la sortie.
#
# Il tient en quatre leviers, chacun deja reel separement :
#
#   - le profil tuned-adm ;
#   - la frequence plancher du GPU Intel (root, via pkexec — /sys est en
#     0644/root ici, mesure sur cette machine) ;
#   - les effets du compositeur kwin (jamais « le compositing » lui-meme :
#     SOUS WAYLAND, kwin_wayland EST le compositeur, il n'y a rien a
#     desactiver comme sous X11 — seuls les EFFETS individuels se coupent) ;
#   - Android, arrete en Jeu.
#
# GameMode (build_files/49-jeu.sh) s'auto-active par jeu via D-Bus des qu'il
# est installe — rien a piloter ici, seulement a poser.
#
# « ART » A DISPARU AVEC LE REGLAGE : plus aucun geste ne pouvait le demander.
# Et il n'y a plus de lecture de l'etat courant — la barre ne l'affiche plus.

_GPU_MIN = "/sys/class/drm/card0/gt_min_freq_mhz"
_GPU_MAX = "/sys/class/drm/card0/gt_max_freq_mhz"
_GPU_RPN = "/sys/class/drm/card0/gt_RPn_freq_mhz"  # le plancher materiel reel

_MODES = [("travail", "Travail"), ("jeu", "Jeu")]

# Effets kwin coupes en mode Jeu — identifiants verifies sur cette machine
# (« Id » dans /usr/share/kwin-wayland/builtin-effects/*.json et
# /usr/share/kwin/effects/*/metadata.json), jamais devines : blur et
# translucency coutent reellement du GPU en compositing, les trois glissements
# sont l'essentiel des animations visibles. wobblywindows est deja hors
# service par defaut sur cette image (EnabledByDefault: false), pas la peine
# d'y toucher.
_EFFETS_A_COUPER = ("blur", "translucency", "slide", "slidingpopups",
                     "slidingnotifications")


def _lire_int_sysfs(chemin):
    try:
        with open(chemin, encoding="utf-8") as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return None


def _regler_gpu(pinner_haut):
    pkexec = _outil("pkexec")
    if not pkexec:
        return False, "pkexec absent"
    mx, rpn = _lire_int_sysfs(_GPU_MAX), _lire_int_sysfs(_GPU_RPN)
    if mx is None or rpn is None:
        return False, "frequence GPU illisible sur cette machine"
    cible = mx if pinner_haut else rpn
    # _lire() ne sait pas nourrir un stdin — la redirection se fait donc
    # DANS le sh eleve par pkexec, pas dans notre propre shell non privilegie.
    code, sortie = _lire([pkexec, "sh", "-c",
                          "echo %d > %s" % (cible, _GPU_MIN)], delai=8)
    return (code == 0), (sortie.strip()[:120] or "%d MHz" % cible)


def _regler_effets_kwin(actifs):
    kwriteconfig6 = _outil("kwriteconfig6")
    if not kwriteconfig6:
        return False, "kwriteconfig6 absent"
    ok = True
    code, _s = _lire([kwriteconfig6, "--file", "kdeglobals", "--group", "KDE",
                      "--key", "AnimationDurationFactor",
                      "" if actifs else "0"])
    ok = ok and (code == 0)
    for effet in _EFFETS_A_COUPER:
        code, _s = _lire([kwriteconfig6, "--file", "kwinrc", "--group", "Plugins",
                          "--key", "%sEnabled" % effet,
                          "true" if actifs else "false"])
        ok = ok and (code == 0)
    # Recharger a chaud, meme geste que regles-kwin.py — sans lui, kwin ne
    # relirait ces fichiers qu'a la prochaine ouverture de session.
    _lire(["busctl", "--user", "call", "org.kde.KWin", "/KWin",
          "org.kde.KWin", "reconfigure"], delai=8)
    return ok, ("effets actifs" if actifs else "effets reduits")


def _regler_mode(cle):
    noms = dict(_MODES)
    if cle not in noms:
        return False, "mode inconnu"
    if cle == "jeu":
        ok_e, msg_e = _regler_energie("accelerator-performance")
        ok_g, msg_g = _regler_gpu(True)
        ok_k, msg_k = _regler_effets_kwin(False)
        code_a, _s = _arreter_android()
        ok_a = (code_a == 0)
    else:  # travail
        ok_e, msg_e = _regler_energie("throughput-performance-bazzite")
        ok_g, msg_g = _regler_gpu(False)
        ok_k, msg_k = _regler_effets_kwin(True)
        # ANDROID N'EST JAMAIS REDEMARRE AUTOMATIQUEMENT EN SORTANT DU MODE
        # JEU. Rallumer tout un monde sans qu'on le demande serait plus
        # surprenant que de le laisser eteint — le reglage « Android »
        # existant s'en charge, a la main.
        ok_a = True
    ok = ok_e and ok_g and ok_k and ok_a
    detail = noms[cle] if ok else "%s (partiel)" % noms[cle]
    return ok, detail


# --------------------------------------------------------------------------
# Les radios
# --------------------------------------------------------------------------

def _autre_route_que_le_wifi():
    """Existe-t-il une voie vers l'exterieur qui ne soit pas le Wi-Fi ?

    ═══ POURQUOI CETTE QUESTION EXISTE ═══
    Sur cette machine, mesure le 2026-08-26 : « eno1 » est la mais son
    « carrier » vaut 0 — aucun cable — et la route par defaut passe par
    « wlp2s0 ». LE WI-FI EST LA SEULE VOIE.

    L'eteindre coupe donc Internet, Tailscale, et l'acces distant depuis le
    telephone. Et si l'on est JUSTEMENT a distance au moment du clic, on se
    coupe soi-meme sans aucun moyen de rallumer : il faut retourner devant la
    machine. C'est la meme faute que la luminosite descendue a zero le meme
    soir — un geste qui se rend irreversible.
    """
    try:
        with open("/proc/net/route", "r", encoding="utf-8") as f:
            lignes = f.read().splitlines()[1:]
    except OSError:
        return True   # on ne sait pas : on ne verrouille pas
    for ligne in lignes:
        champs = ligne.split()
        if len(champs) < 3 or champs[1] != "00000000":
            continue
        nom = champs[0]
        # tailscale0 n'est pas une voie INDEPENDANTE : il passe par-dessus le
        # Wi-Fi. Le compter serait se mentir.
        if nom.startswith(("wl", "wlan", "tailscale", "wg")):
            continue
        return True
    return False


def _wifi():
    if not _outil("nmcli"):
        return None
    code, sortie = _lire(["nmcli", "-t", "radio", "wifi"])
    if code != 0:
        return None
    etat = sortie.strip().lower()
    # nmcli parle la langue du systeme : « enabled » en anglais, « activé » en
    # francais. On teste les deux plutot que d'imposer LC_ALL, qui changerait
    # aussi les messages d'erreur qu'on affiche a l'utilisateur.
    actif = etat.startswith("enab") or etat.startswith("activ")

    # Le nom du reseau vaut mieux que « allume » : il dit A QUOI on est
    # connecte, ce qu'on cherche vraiment en regardant cette etoile.
    reseau = ""
    code2, sortie2 = _lire(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION",
                            "device"])
    if code2 == 0:
        for ligne in sortie2.splitlines():
            parts = ligne.split(":")
            if len(parts) >= 3 and parts[0] == "wifi" and parts[1] == "connected":
                reseau = parts[2]
                break

    return {"actif": actif, "reseau": reseau,
            "seule_voie": actif and not _autre_route_que_le_wifi()}


def _basculer_wifi(actif):
    if not _outil("nmcli"):
        return False, "aucun controle du reseau"
    # LE REFUS EST DANS LE MOTEUR, PAS SEULEMENT DANS L'INTERFACE. Une garde
    # posee uniquement cote QML ne protegerait pas un appel venu d'ailleurs —
    # et c'est ici qu'on sait si le Wi-Fi est la seule voie.
    if not actif:
        etat = _wifi()
        if etat and etat.get("seule_voie"):
            return False, "seule voie vers le reseau — l'eteindre couperait tout"
    code, sortie = _lire(["nmcli", "radio", "wifi", "on" if actif else "off"], delai=12)
    _oublier("wifi")
    return (code == 0), (sortie.strip()[:120] or ("Wi-Fi allume" if actif else "Wi-Fi eteint"))


def _bluetooth():
    """Rend None quand il n'y a PAS d'adaptateur — pas False.

    LA DIFFERENCE EST TOUT LE RESTE. « False » voudrait dire « eteint, tu peux
    l'allumer » et poserait une etoile qui ne fait rien. « None » veut dire
    « cette machine n'en a pas », et l'etoile ne se dessine pas du tout.
    """
    try:
        adaptateurs = os.listdir("/sys/class/bluetooth")
    except OSError:
        return None
    if not adaptateurs:
        return None
    code, sortie = _lire(["rfkill", "list", "bluetooth"])
    if code != 0:
        return {"actif": True}
    return {"actif": "Soft blocked: yes" not in sortie}


def _basculer_bluetooth(actif):
    if not _outil("rfkill"):
        return False, "aucun controle des radios"
    code, sortie = _lire(["rfkill", "unblock" if actif else "block", "bluetooth"])
    _oublier("bluetooth")
    return (code == 0), (sortie.strip()[:120] or "Bluetooth")


# --------------------------------------------------------------------------
# Le materiel — fwupd, jamais reimplemente (voir s-pilotes)
# --------------------------------------------------------------------------
#
# CE RELEVE NE FORCE JAMAIS UN RAFRAICHISSEMENT RESEAU. « fwupdmgr refresh »
# est deja fait, periodiquement, par s-pilotes.timer — le relire ici a chaque
# ouverture du panneau ferait dependre l'affichage d'un reseau qui peut etre
# absent ou lent. « get-devices »/« get-updates » lisent l'etat DEJA connu de
# fwupd, en local : mesure sur cette machine, 30-50 ms les deux, sans reseau.
#
# L'ACTION NE FAIT JAMAIS D'ECRITURE ELLE-MEME. Elle appelle « s-pilotes
# --appliquer », le seul endroit du depot qui sait ecrire un firmware — meme
# raison que partout ailleurs : un flash rate ne se defait pas par un
# « bootc rollback ». Voir s-pilotes pour le detail du geste et son cout.

def _materiel():
    if not _outil("fwupdmgr"):
        return None
    code, sortie = _lire(["fwupdmgr", "get-devices", "--json"], delai=10)
    if code != 0:
        return None
    try:
        appareils = len(json.loads(sortie).get("Devices", []))
    except (ValueError, TypeError):
        return None
    maj = 0
    code, sortie = _lire(["fwupdmgr", "get-updates", "--json"], delai=10)
    if code == 0:
        try:
            maj = len(json.loads(sortie).get("Devices", []))
        except (ValueError, TypeError):
            maj = 0
    return {"appareils": appareils, "maj": maj}


def _appliquer_materiel():
    outil = shutil.which("s-pilotes") or "/usr/bin/s-pilotes"
    if not os.path.isfile(outil) and not shutil.which("s-pilotes"):
        return False, "s-pilotes absent"
    try:
        # Detache et sans attente : « fwupdmgr update » peut prendre plusieurs
        # minutes (telechargement d'un firmware), et s-pilotes previent deja
        # par sa propre notification (s_dire) une fois termine — bloquer le
        # panneau jusque-la referait ce que la bulle fait deja mieux.
        subprocess.Popen([outil, "--appliquer"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        return False, str(err)
    _oublier("materiel")
    return True, "mise a jour lancee en arriere-plan"


# --------------------------------------------------------------------------
# Le profil d'energie — tuned, et non power-profiles-daemon
# --------------------------------------------------------------------------
#
# BAZZITE EMPLOIE TUNED. « powerprofilesctl » n'est PAS sur cette machine —
# mesure du 2026-08-26. Seul le mode Jeu ci-dessus pose un profil ; le reglage
# « Energie » qui laissait l'utilisateur en choisir un a ete retire (voir plus
# haut), avec la lecture du profil courant qu'il etait seul a appeler.

def _regler_energie(profil):
    if not _outil("tuned-adm"):
        return False, "aucun profil d'energie"
    code, sortie = _lire(["tuned-adm", "profile", profil], delai=25)
    return (code == 0), (sortie.strip()[:120] or profil)


# --------------------------------------------------------------------------
# Le tailnet, Android, la capture
# --------------------------------------------------------------------------

def _tailscale():
    if not _outil("tailscale"):
        return None
    code, sortie = _lire(["tailscale", "status", "--json"], delai=10)
    if code != 0:
        return None
    try:
        import json
        d = json.loads(sortie)
    except ValueError:
        return None
    etat = d.get("BackendState") or ""
    moi = d.get("Self") or {}
    ips = moi.get("TailscaleIPs") or []
    return {"actif": etat == "Running",
            "etat": etat,
            "adresse": ips[0] if ips else ""}


def _basculer_tailscale(actif):
    if not _outil("tailscale"):
        return False, "Tailscale n'est pas sur cette machine"
    # « up » et « down » touchent l'etat du demon : c'est un geste privilegie.
    # On passe par pkexec, comme les autres gestes systeme de S.
    outil = _outil("pkexec") or ""
    argv = ([outil] if outil else []) + [_outil("tailscale"),
                                         "up" if actif else "down"]
    code, sortie = _lire(argv, delai=45)
    _oublier("tailscale")
    return (code == 0), (sortie.strip().splitlines()[-1][:120] if sortie
                         else ("tailnet rejoint" if actif else "tailnet quitte"))


def _android():
    # Sans images Android, la bascule serait un bouton mort : la regle de ce
    # fichier — un reglage se declare indisponible quand son materiel manque —
    # vaut aussi pour un monde entier.
    if not os.path.isfile("/var/lib/waydroid/images/system.img"):
        return None
    # PAS lxc-info : sans privilege il repond « Insufficent privileges »
    # precisement quand le conteneur TOURNE (mesure du 2026-08-29, voir
    # s_android_etat dans partage-android.sh). systemd, lui, se lit sans
    # aucun droit, et s-android.service est l'unique proprietaire de
    # lxc-start.
    code, _sortie = _lire(
        ["systemctl", "is-active", "--quiet", "s-android.service"], delai=6)
    actif = (code == 0)
    return {"actif": actif, "etat": "RUNNING" if actif else "STOPPED"}


def _arreter_android():
    # SANS MOT DE PASSE DEPUIS LE 2026-08-29 AU SOIR : 50-s-android.rules
    # autorise start/stop/restart de CETTE unite, pour un membre actif de
    # wheel, sans authentification. « --no-ask-password » fait echouer
    # immediatement si la regle manque plutot que de laisser l'agent polkit
    # ouvrir une fenetre — le repli pkexec la pose alors lui-meme, comme
    # avant, pour une machine qui n'a pas encore recu l'image.
    code, sortie = _lire(["systemctl", "--no-ask-password", "stop", "s-android.service"],
                         delai=30)
    if code != 0:
        outil = _outil("pkexec")
        if not outil:
            return False, "pkexec n'est pas sur cette machine"
        code, sortie = _lire([outil, "systemctl", "stop", "s-android.service"], delai=30)
    return code, sortie


def _basculer_android(actif):
    if actif:
        # LE DEMARRAGE PASSE PAR LE GESTE DE S, PAS PAR systemctl DIRECTEMENT.
        # « s-android » fait bien plus que lancer le conteneur : il verse les
        # proprietes, regle la mise en veille et ouvre une application.
        # L'appeler d'ici evite d'avoir deux facons de demarrer Android, dont
        # une incomplete — la faute que ce depot a payee cinq jours.
        geste = "/usr/bin/s-android"
        if os.path.isfile(geste):
            try:
                subprocess.Popen([geste, "--silencieux"], start_new_session=True,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
                return True, "Android demarre"
            except OSError as err:
                return False, str(err)
        return False, "s-android est absent de cette machine"
    code, sortie = _arreter_android()
    _oublier("android")
    return (code == 0), (sortie.strip()[:120] or "Android arrete")


def _capturer():
    outil = _outil("spectacle")
    if not outil:
        return False, "aucun outil de capture"
    try:
        # « -r » : selection rectangulaire. C'est ce qu'on veut d'un raccourci —
        # une capture plein ecran depuis un panneau photographierait le panneau.
        subprocess.Popen([outil, "-r", "-b"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        return False, str(err)
    return True, "capture"


# --------------------------------------------------------------------------
# Le pont de developpement — tester une fois, dans les trois mondes
# --------------------------------------------------------------------------
#
# DEMANDE DE L'UTILISATEUR LE 2026-09-01 : un geste qui lance le meme test
# dans les trois mondes a la fois, « pour ne jamais briser son rythme de
# travail ». Aucune detection magique du type de projet — un petit fichier
# .s-dev.json a la racine du projet dit CE QU'IL FAUT LANCER, S se contente
# d'appeler ce qui existe deja pour chaque monde :
#
#   - linux         : une commande shell, executee telle quelle ;
#   - windows       : s-ouvrir-exe <chemin>, EXACTEMENT le geste du
#                      double-clic — jamais umu-run appele a la main ;
#   - android_apk /
#     android_paquet: s-android-lancer --installer <apk> puis
#                      s-android-lancer <paquet> — le meme service binder
#                      que le Magasin Android, sans jamais ouvrir Android
#                      (voir s-magasin-android : « une couture ne montre
#                      jamais son moteur »).
#
# Un champ absent est saute, jamais un echec bruyant — un projet purement
# Linux n'a pas a fournir un .exe qui n'existe pas. Aucune extraction de
# nom de paquet depuis l'APK (aapt/apkanalyzer) : demande a l'utilisateur
# de le dire une fois, plutot que de deviner.

_DOSSIER_PROJETS = os.path.expanduser("~/Projets")


def _projets_dev():
    """Les dossiers de ~/Projets qui portent un .s-dev.json — jamais un nom
    de fichier hypothetique cherche a l'aveugle, seulement ceux qui l'ont
    reellement."""
    try:
        noms = sorted(os.listdir(_DOSSIER_PROJETS))
    except OSError:
        return []
    return [n for n in noms
            if os.path.isfile(os.path.join(_DOSSIER_PROJETS, n, ".s-dev.json"))]


def _lire_config_dev(nom_projet):
    chemin = os.path.join(_DOSSIER_PROJETS, nom_projet, ".s-dev.json")
    try:
        with open(chemin, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _lancer_test_projet(nom_projet):
    cfg = _lire_config_dev(nom_projet)
    if cfg is None:
        return False, "%s : .s-dev.json illisible" % nom_projet

    faits, manques = [], []
    dossier = os.path.join(_DOSSIER_PROJETS, nom_projet)

    linux = cfg.get("linux")
    if linux:
        try:
            subprocess.Popen(linux, shell=True, cwd=dossier,
                             start_new_session=True)
            faits.append("Linux")
        except OSError as err:
            manques.append("Linux (%s)" % err)

    windows = cfg.get("windows")
    if windows:
        outil = _outil("s-ouvrir-exe")
        if not outil:
            manques.append("Windows (s-ouvrir-exe absent)")
        else:
            try:
                subprocess.Popen([outil, windows], start_new_session=True,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
                faits.append("Windows")
            except OSError as err:
                manques.append("Windows (%s)" % err)

    apk, paquet = cfg.get("android_apk"), cfg.get("android_paquet")
    if apk and paquet:
        lanceur = _outil("s-android-lancer")
        if not lanceur:
            manques.append("Android (s-android-lancer absent)")
        else:
            # L'installation reste synchrone (on doit savoir si elle a
            # reussi avant de lancer) ; le lancement, lui, est detache comme
            # les deux autres mondes — on n'attend pas qu'une fenetre Android
            # se ferme pour rendre la main.
            code, _s = _lire([lanceur, "--installer", apk], delai=60)
            if code == 0:
                try:
                    subprocess.Popen([lanceur, paquet], start_new_session=True,
                                     stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL)
                    faits.append("Android")
                except OSError as err:
                    manques.append("Android (%s)" % err)
            else:
                manques.append("Android (installation en echec)")
    elif apk or paquet:
        manques.append("Android (android_apk et android_paquet vont ensemble)")

    if not faits and not manques:
        return False, "%s : .s-dev.json ne declare aucun monde" % nom_projet
    detail = ", ".join(faits) if faits else "rien"
    if manques:
        detail += " — manque : " + ", ".join(manques)
    return bool(faits), detail


# --------------------------------------------------------------------------
# Acces rapide — Salon et Retro, sans quitter Constellation
# --------------------------------------------------------------------------
#
# DEMANDE DE L'UTILISATEUR LE 2026-09-10, APRES LE CHANTIER MODE SALON.
# Distinct de "s-salon-session"/"s-salon.desktop" (la vraie session de
# greeter, --backend drm, ecran pris directement) : ceci est un GESTE DEPUIS
# LA BARRE LATERALE, qui ouvre gamescope en mode IMBRIQUE (--backend wayland)
# comme une fenetre normale de la session en cours — exactement le mode deja
# eprouve, pour Steam ET pour RetroArch, le 2026-09-10 (voir CLAUDE.md). On
# ne quitte jamais Constellation ; Windows et Android restent joignables
# pendant que la fenetre est ouverte.
#
# CHAQUE ENTREE DISPARAIT SI L'OUTIL MANQUE — meme regle que le reste de ce
# fichier. Le geste lui-meme vit dans un script a part (s-salon-rapide,
# s-retro-rapide) plutot qu'ici : il doit tourner en avant-plan pour pouvoir
# repasser en mode Travail apres la fermeture de la fenetre, ce qu'un appel
# Python detache ne saurait pas attendre proprement.

def _salon_rapide_disponible():
    return bool(_outil("gamescope")) and bool(_outil("steam"))


def _lancer_salon_rapide():
    script = "/usr/bin/s-salon-rapide"
    if not os.path.isfile(script):
        return False, "s-salon-rapide absent de cette machine"
    try:
        subprocess.Popen([script], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        return False, str(err)
    return True, "Steam Big Picture en cours d'ouverture"


def _retro_rapide_disponible():
    return bool(_outil("gamescope")) and bool(_outil("retroarch"))


def _lancer_retro_rapide():
    script = "/usr/bin/s-retro-rapide"
    if not os.path.isfile(script):
        return False, "s-retro-rapide absent de cette machine"
    try:
        subprocess.Popen([script], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        return False, str(err)
    return True, "RetroArch en cours d'ouverture"


# --------------------------------------------------------------------------
# La composition — ce que la barre laterale affiche
# --------------------------------------------------------------------------
#
# CHAQUE ENTREE PORTE SON TYPE, et la barre ne connait que trois formes :
#   « bascule »   un etat qu'on allume ou qu'on eteint ;
#   « glissiere » une valeur de 0 a 100 ;
#   « choix »     quelques possibilites nommees ;
#   « action »    un geste sans etat.
# Ajouter un reglage ne demande donc rien a la barre — c'est ce qui permet d'en
# mettre autant que la machine en offre.

def _prechauffer():
    """Lance EN PARALLELE les sondes qui coutent plus de trente millisecondes.

    Quatorze sondes en serie prenaient 1,2 s a froid — 2,4 s mesurees le
    2026-09-19 sur la machine chargee — et chaque ouverture de la barre laterale
    les relance, que l'utilisateur travaille ou joue. Chiffrees une a une :
    egaliseur 219 ms, luminosite 213, materiel 58, wifi 32 ; les autres sont sous
    15 ms. (Le profil d'energie, 240 ms, le contraste, 174, et les deux modes
    ont quitte la barre le 2026-09-20 : il ne reste que dix sondes.)

    UN FIL PAR SONDE LENTE, sauf « materiel » et « wifi » qui partagent le leur
    (58 + 32 ms : moins que la plus lente des autres, un fil de plus ne gagnerait
    rien). ddcutil parle en I2C a l'ecran, un bus qui n'aime pas les acces
    simultanes (le carnet du 2026-09-18 le dit) : « luminosite » est aujourd'hui
    son seul appelant ici, donc rien ne peut le lancer deux fois en meme temps —
    si un second reglage d'ecran revenait, il devrait rejoindre CE fil.

    Le resultat n'est pas rendu : il est dans _CACHE, et la suite de rapides()
    n'a plus qu'a le lire. Une sonde encore en cours passe le delai est rattrapee
    par l'appel sequentiel normal — plus lent, jamais faux.
    """
    groupes = (
        (("luminosite", lambda: _ddc(10)),),
        (("egaliseur", _egaliseur),),
        (("materiel", _materiel), ("wifi", _wifi)),
    )

    def travailler(groupe):
        for cle, calcul in groupe:
            try:
                _cache(cle, calcul)
            except Exception:  # noqa: BLE001 — une sonde ne doit pas en emporter une autre
                pass

    fils = [threading.Thread(target=travailler, args=(g,), daemon=True)
            for g in groupes]
    for fil in fils:
        fil.start()
    limite = time.monotonic() + 8.0
    for fil in fils:
        fil.join(max(0.0, limite - time.monotonic()))


def rapides():
    """L'etat de tout ce que S sait regler, ici et maintenant.

    Un reglage dont le materiel ou l'outil manque n'est PAS dans la liste. Une
    etoile grisee dirait « c'est possible, mais pas maintenant », ce qui est
    faux pour un adaptateur qui n'existe pas.
    """
    sortie = []
    _prechauffer()

    son = _cache("volume", _volume)
    if son is not None:
        sortie.append({"cle": "volume", "nom": "Volume", "ico": "i-son",
                       "type": "glissiere", "valeur": son["valeur"],
                       "max": 150, "actif": not son["muet"],
                       "detail": "muet" if son["muet"] else "%d %%" % son["valeur"]})

    eg = _cache("egaliseur", _egaliseur)
    if eg is not None:
        sortie.append({"cle": "egaliseur", "nom": "Egaliseur", "ico": "i-egaliseur",
                       "type": "bascule", "actif": eg["actif"],
                       "detail": "allume" if eg["actif"] else "eteint"})

    wc = _cache("webcam", _webcam)
    if wc is not None:
        detail = "accessible" if wc["actif"] else "bloquee"
        # Le nom porte deja « (Linux) » — voir le commentaire de _webcam().
        # Ce suffixe-ci est l'autre moitie du meme aveu : si le groupe unix
        # video n'est plus vide, le blocage n'est plus total, quel que soit
        # l'etat de la bascule.
        if wc["autres_comptes"]:
            detail += " (+ groupe video)"
        sortie.append({"cle": "webcam", "nom": "Webcam (Linux)",
                       "ico": "i-video", "type": "bascule",
                       "actif": wc["actif"], "detail": detail})

    lum = _cache("luminosite", lambda: _ddc(10))
    if lum is not None:
        sortie.append({"cle": "luminosite", "nom": "Luminosite", "ico": "i-ecran",
                       "type": "glissiere", "valeur": lum["valeur"],
                       "max": lum["max"], "actif": True,
                       "detail": "%d %%" % lum["valeur"]})

    w = _cache("wifi", _wifi)
    if w is not None:
        sortie.append({"cle": "wifi", "nom": "Wi-Fi", "ico": "i-reseau",
                       "type": "bascule", "actif": w["actif"],
                       # VERROUILLE QUAND C'EST LA SEULE VOIE. On ne retire pas
                       # l'etoile — voir l'etat du reseau est utile, et une
                       # etoile absente ne dit rien. On retire le pouvoir de
                       # couper la branche sur laquelle on est assis.
                       "verrouille": bool(w.get("seule_voie")),
                       "detail": (w.get("reseau") or "allume") if w["actif"]
                                 else "eteint"})

    bt = _cache("bluetooth", _bluetooth)
    if bt is not None:
        sortie.append({"cle": "bluetooth", "nom": "Bluetooth", "ico": "i-tel",
                       "type": "bascule", "actif": bt["actif"],
                       "detail": "allume" if bt["actif"] else "eteint"})

    ts = _cache("tailscale", _tailscale)
    if ts is not None:
        sortie.append({"cle": "tailscale", "nom": "Tailnet", "ico": "i-globe",
                       "type": "bascule", "actif": ts["actif"],
                       "detail": ts["adresse"] or ts["etat"]})

    # LE PANNEAU MATERIEL N'APPARAIT QUE S'IL Y A QUELQUE CHOSE A APPLIQUER. Son
    # seul geste lance s-pilotes --appliquer ; sans mise a jour, c'est un bouton
    # qui ne fait rien, et il disait « 10 appareil(s), a jour » en permanence —
    # sur cette machine, en BIOS legacy, fwupd n'en trouve jamais. Comme le reste
    # de ce fichier (« un reglage dont le materiel manque n'est PAS dans la
    # liste »), l'entree est absente plutot que grisee, et elle sert alors de
    # signal : elle monte quand une mise a jour attend. La verification
    # hebdomadaire de s-pilotes.timer continue de prevenir par une bulle.
    mat = _cache("materiel", _materiel)
    if mat is not None and mat["maj"] > 0:
        detail = "%d appareil(s), %d mise(s) a jour" % (mat["appareils"], mat["maj"])
        sortie.append({"cle": "materiel", "nom": "Materiel", "ico": "i-disque",
                       "type": "action", "actif": True, "detail": detail})

    an = _cache("android", _android)
    if an is not None:
        sortie.append({"cle": "android", "nom": "Android", "ico": "i-tel",
                       "type": "bascule", "actif": an["actif"],
                       "detail": an["etat"].lower() or "arrete"})

    if _outil("spectacle"):
        sortie.append({"cle": "capture", "nom": "Capturer", "ico": "i-image",
                       "type": "action", "actif": True, "detail": "selection"})

    projets = _cache("dev-pont", _projets_dev)
    if projets:
        sortie.append({"cle": "dev-pont", "nom": "Pont dev", "ico": "i-code",
                       "type": "choix", "valeur": "", "actif": True,
                       "detail": "%d projet(s)" % len(projets),
                       "choix": [{"cle": n, "nom": n} for n in projets]})

    if _salon_rapide_disponible():
        sortie.append({"cle": "salon-rapide", "nom": "Salon rapide",
                       "ico": "i-manette", "type": "action", "actif": True,
                       "detail": "Steam Big Picture, en fenetre"})

    if _retro_rapide_disponible():
        sortie.append({"cle": "retro-rapide", "nom": "Retro rapide",
                       "ico": "i-manette", "type": "action", "actif": True,
                       "detail": "RetroArch, en fenetre"})

    sortie.append({"cle": "verrouiller", "nom": "Verrouiller", "ico": "i-cadenas",
                   "type": "action", "actif": True, "detail": ""})

    return sortie


def regler(cle, valeur):
    """Applique un reglage. Rend (ok, phrase)."""
    if cle == "volume":
        return _regler_volume(valeur)
    if cle == "volume-muet":
        return _basculer_muet()
    if cle == "egaliseur":
        return _regler_egaliseur(bool(valeur))
    if cle == "webcam":
        return _basculer_webcam(bool(valeur))
    if cle == "luminosite":
        return _regler_ddc(10, valeur)
    if cle == "wifi":
        return _basculer_wifi(bool(valeur))
    if cle == "bluetooth":
        return _basculer_bluetooth(bool(valeur))
    if cle == "tailscale":
        return _basculer_tailscale(bool(valeur))
    if cle == "materiel":
        return _appliquer_materiel()
    # « mode » N'EST PLUS DANS rapides() : aucune etoile ne le propose. Il reste
    # ici parce que s-retro-rapide, s-salon-rapide et s-salon-session l'appellent
    # (« jeu » en entrant, « travail » en sortant) — voir le mode Jeu plus haut.
    if cle == "mode":
        return _regler_mode(str(valeur))
    if cle == "android":
        return _basculer_android(bool(valeur))
    if cle == "capture":
        return _capturer()
    if cle == "dev-pont":
        return _lancer_test_projet(str(valeur))
    if cle == "salon-rapide":
        return _lancer_salon_rapide()
    if cle == "retro-rapide":
        return _lancer_retro_rapide()
    return False, "reglage inconnu : %s" % cle
