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

import os
import shutil
import subprocess
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
    _oublier("contraste")
    return (code == 0), (sortie.strip().splitlines()[-1][:120] if code and sortie
                         else "%d %%" % valeur)


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
# L'energie — tuned, et non power-profiles-daemon
# --------------------------------------------------------------------------
#
# BAZZITE EMPLOIE TUNED. « powerprofilesctl » n'est PAS sur cette machine —
# mesure du 2026-08-26 — et le chercher aurait donne un reglage absent alors
# que la machine sait parfaitement changer de profil. Elle tournait sur
# « balanced-bazzite » au moment du releve.

_PROFILS = [
    ("balanced-bazzite", "Equilibre"),
    ("throughput-performance", "Performance"),
    ("balanced-battery-bazzite", "Economie"),
]


def _energie():
    if not _outil("tuned-adm"):
        return None
    code, sortie = _lire(["tuned-adm", "active"], delai=12)
    if code != 0:
        return None
    actuel = sortie.split(":")[-1].strip()
    connus = [c for c, _ in _PROFILS]
    return {"profil": actuel,
            "nom": dict(_PROFILS).get(actuel, actuel),
            "connu": actuel in connus}


def _regler_energie(profil):
    if not _outil("tuned-adm"):
        return False, "aucun profil d'energie"
    code, sortie = _lire(["tuned-adm", "profile", profil], delai=25)
    _oublier("energie")
    return (code == 0), (sortie.strip()[:120] or dict(_PROFILS).get(profil, profil))


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


# LE FICHIER DE PROPRIETES ANDROID, PARTAGE PAR LES FONCTIONS CI-DESSOUS.
# Meme mecanisme cote Python que « s_android_etat »/« s_android_prop_lire »
# dans files/usr/lib/s/partage-android.sh (voir ce fichier pour les mesures
# du 2026-08-29 : etat par systemd et non lxc-info, waydroid.prop en clair,
# root:root 0644) — deux langages differents pour deux appelants differents
# (une couture bash, ce module Python), pas de bibliotheque commune entre
# les deux mondes dans ce depot.
_PROP_ANDROID = "/var/lib/waydroid/waydroid.prop"

# Petit script autonome, execute par un python3 SEPARE sous pkexec — jamais
# dans CE processus, qui n'a pas les droits d'ecrire un fichier root:root.
# Remplace la cle si elle existe deja, l'ajoute sinon ; ecriture atomique
# (fichier temporaire puis os.replace) pour qu'une coupure ne laisse jamais
# le fichier a moitie ecrit.
_SCRIPT_ECRIRE_PROP_ANDROID = """
import sys, os
chemin, cle, valeur = sys.argv[1:4]
try:
    with open(chemin, encoding="utf-8") as f:
        lignes = f.read().splitlines()
except FileNotFoundError:
    lignes = []
vue = False
for i, ligne in enumerate(lignes):
    if ligne.split("=", 1)[0] == cle:
        lignes[i] = cle + "=" + valeur
        vue = True
        break
if not vue:
    lignes.append(cle + "=" + valeur)
tmp = chemin + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write("\\n".join(lignes) + "\\n")
os.replace(tmp, chemin)
"""


def _lire_prop_android(cle):
    try:
        with open(_PROP_ANDROID, encoding="utf-8") as f:
            for ligne in f:
                if ligne.split("=", 1)[0] == cle:
                    return ligne.split("=", 1)[1].strip()
    except OSError:
        return None
    return None


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
                subprocess.Popen([geste], start_new_session=True,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
                return True, "Android demarre"
            except OSError as err:
                return False, str(err)
        return False, "s-android est absent de cette machine"
    outil = _outil("pkexec")
    if not outil:
        return False, "pkexec n'est pas sur cette machine"
    code, sortie = _lire(
        [outil, "systemctl", "stop", "s-android.service"], delai=30)
    _oublier("android")
    return (code == 0), (sortie.strip()[:120] or "Android arrete")


# LE MODE D'AFFICHAGE D'ANDROID — DEMANDE DE L'UTILISATEUR (reponse 14 de
# l'entretien du 2026-08-27) : « je prefere avoir le choix » entre fenetre et
# plein ecran, plutot qu'un mode impose une fois pour toutes dans s-android.
#
# CE RELEVE NE DEPEND PLUS DE LA SESSION VIVANTE — CHANGEMENT DU 2026-08-29.
# Avant, « waydroid prop get » exigeait la session (sans elle : « WayDroid
# session is stopped » plutot qu'une vraie valeur), donc ce reglage restait
# invisible tant qu'Android etait eteint. Ce n'est plus un appel a un outil
# externe : c'est la lecture directe de waydroid.prop, le fichier
# qu'android-lancer.sh bind-monte tel quel dans le conteneur — la meme
# verite que le conteneur lira au prochain demarrage, qu'il tourne ou non en
# ce moment.
#
# CE RELEVE NE DECIDE TOUJOURS RIEN A CHAUD. Le carnet du 2026-08-25 l'a
# mesure : « persist.waydroid.multi_windows » ne prend qu'au PROCHAIN
# demarrage du conteneur, jamais a chaud. Changer ce reglage redemarre donc
# le conteneur — tout ce qui y tournait se ferme, exactement comme changer
# de moniteur redemarrerait un serveur d'affichage.
def _mode_android():
    valeur = _lire_prop_android("persist.waydroid.multi_windows")
    if valeur is None:
        return None
    return {"fenetre": valeur.lower() == "true"}


def _regler_mode_android(mode):
    outil = _outil("pkexec")
    if not outil:
        return False, "pkexec n'est pas sur cette machine"
    fenetre = (mode == "fenetre")
    code, _sortie = _lire(
        [outil, "/usr/bin/python3", "-c", _SCRIPT_ECRIRE_PROP_ANDROID,
         _PROP_ANDROID, "persist.waydroid.multi_windows",
         "true" if fenetre else "false"], delai=10)
    if code != 0:
        return False, "reglage refuse"
    _oublier("mode-android")
    # NE PREND EFFET QU'AU PROCHAIN DEMARRAGE : redemarrer si le conteneur
    # tourne deja, sinon passer par s-android — meme geste que
    # « _basculer_android(True) », pour les memes raisons : il verse aussi
    # les proprietes et la mise en veille, pas seulement le conteneur.
    etat = _android()
    if etat and etat.get("actif"):
        _lire([outil, "systemctl", "restart", "s-android.service"], delai=30)
    else:
        geste = "/usr/bin/s-android"
        if os.path.isfile(geste):
            try:
                subprocess.Popen([geste], start_new_session=True,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
            except OSError as err:
                return False, str(err)
    return True, ("Android en fenetres (redemarrage...)" if fenetre
                 else "Android en plein ecran (redemarrage...)")


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

def rapides():
    """L'etat de tout ce que S sait regler, ici et maintenant.

    Un reglage dont le materiel ou l'outil manque n'est PAS dans la liste. Une
    etoile grisee dirait « c'est possible, mais pas maintenant », ce qui est
    faux pour un adaptateur qui n'existe pas.
    """
    sortie = []

    son = _cache("volume", _volume)
    if son is not None:
        sortie.append({"cle": "volume", "nom": "Volume", "ico": "i-son",
                       "type": "glissiere", "valeur": son["valeur"],
                       "max": 150, "actif": not son["muet"],
                       "detail": "muet" if son["muet"] else "%d %%" % son["valeur"]})

    lum = _cache("luminosite", lambda: _ddc(10))
    if lum is not None:
        sortie.append({"cle": "luminosite", "nom": "Luminosite", "ico": "i-ecran",
                       "type": "glissiere", "valeur": lum["valeur"],
                       "max": lum["max"], "actif": True,
                       "detail": "%d %%" % lum["valeur"]})

    con = _cache("contraste", lambda: _ddc(12))
    if con is not None:
        sortie.append({"cle": "contraste", "nom": "Contraste", "ico": "i-grille",
                       "type": "glissiere", "valeur": con["valeur"],
                       "max": con["max"], "actif": True,
                       "detail": "%d %%" % con["valeur"]})

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

    en = _cache("energie", _energie)
    if en is not None:
        sortie.append({"cle": "energie", "nom": "Energie", "ico": "i-alim",
                       "type": "choix", "valeur": en["profil"],
                       "actif": True, "detail": en["nom"],
                       "choix": [{"cle": c, "nom": n} for c, n in _PROFILS]})

    an = _cache("android", _android)
    if an is not None:
        sortie.append({"cle": "android", "nom": "Android", "ico": "i-tel",
                       "type": "bascule", "actif": an["actif"],
                       "detail": an["etat"].lower() or "arrete"})

    mode = _cache("mode-android", _mode_android)
    if mode is not None:
        sortie.append({"cle": "mode-android", "nom": "Android : affichage",
                       "ico": "i-tel", "type": "choix",
                       "valeur": "fenetre" if mode["fenetre"] else "plein",
                       "actif": True,
                       "detail": "Fenetres" if mode["fenetre"] else "Plein ecran",
                       "choix": [{"cle": "fenetre", "nom": "Fenetres"},
                                 {"cle": "plein", "nom": "Plein ecran"}]})

    if _outil("spectacle"):
        sortie.append({"cle": "capture", "nom": "Capturer", "ico": "i-image",
                       "type": "action", "actif": True, "detail": "selection"})

    sortie.append({"cle": "verrouiller", "nom": "Verrouiller", "ico": "i-cadenas",
                   "type": "action", "actif": True, "detail": ""})

    return sortie


def regler(cle, valeur):
    """Applique un reglage. Rend (ok, phrase)."""
    if cle == "volume":
        return _regler_volume(valeur)
    if cle == "volume-muet":
        return _basculer_muet()
    if cle == "luminosite":
        return _regler_ddc(10, valeur)
    if cle == "contraste":
        return _regler_ddc(12, valeur)
    if cle == "wifi":
        return _basculer_wifi(bool(valeur))
    if cle == "bluetooth":
        return _basculer_bluetooth(bool(valeur))
    if cle == "tailscale":
        return _basculer_tailscale(bool(valeur))
    if cle == "energie":
        return _regler_energie(str(valeur))
    if cle == "android":
        return _basculer_android(bool(valeur))
    if cle == "mode-android":
        return _regler_mode_android(str(valeur))
    if cle == "capture":
        return _capturer()
    return False, "reglage inconnu : %s" % cle
