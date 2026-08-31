#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Le noyau de Constellation — la machine, lue et actionnee.

CE FICHIER EST L'ANCIEN PONT, MOINS LE PONT. Jusqu'au 2026-08-24, Constellation
etait une page servie en HTTP sur 127.0.0.1:7373 et affichee par Vivaldi en
mode « --app ». Toute cette plomberie n'existait que pour une raison : une page
web ne peut pas lire un menu d'applications ni lancer un programme.

Constellation n'est plus une page. La coquille est desormais un client Wayland
natif (QtQuick), qui appelle ces fonctions DIRECTEMENT, dans son propre
processus. Il n'y a donc plus de serveur, plus de port ouvert, plus de
verification d'en-tete Host, et plus de moteur de navigateur au demarrage de la
session.

CE QUI N'A PAS CHANGE, ET C'EST VOULU : tout ce qui suit — la lecture des
.desktop, le choix du monde, la resolution des icones, le lancement par
« gio launch », les gestes de session, le temoin de sortie — est repris MOT
POUR MOT du pont qui tournait. Ce code avait deja ete exerce sur la machine ;
le reecrire pour le plaisir de le reecrire aurait perdu ses corrections sans
rien apporter.
"""

import json
import os
import re
import shlex
import subprocess
import sys
import time


ETAT = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "s")
FICHIER_USAGE = os.path.join(ETAT, "usage.json")
FICHIER_PLACEES = os.path.join(ETAT, "placees.json")
FICHIER_EPINGLES = os.path.join(ETAT, "epingles.json")
FICHIER_REGLAGES = os.path.join(ETAT, "reglages.json")

# LE DOSSIER DU BUREAU NE SE DEVINE PAS, IL SE DEMANDE. « ~/Bureau » est vrai
# sur cette machine parce qu'elle est en francais ; elle rendrait « ~/Desktop »
# en anglais et « ~/Escritorio » en espagnol. Deviner un chemin est la faute que
# le carnet nomme le plus souvent dans ce depot — on lit donc la declaration
# XDG, et le repli n'est utilise que si elle manque.
def dossier_bureau():
    fichier = os.path.join(
        os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
        "user-dirs.dirs")
    try:
        with open(fichier, "r", encoding="utf-8") as f:
            for ligne in f:
                ligne = ligne.strip()
                if not ligne.startswith("XDG_DESKTOP_DIR="):
                    continue
                brut = ligne.split("=", 1)[1].strip().strip('"')
                return os.path.expandvars(
                    brut.replace("$HOME", os.path.expanduser("~")))
    except OSError:
        pass
    return os.path.expanduser("~/Bureau")

# --------------------------------------------------------------------------
# L'inventaire : lire les .desktop de la machine, et n'en garder que des astres
# --------------------------------------------------------------------------

# Ce que S ne montre pas. Pas pour le cacher — le carnet nomme la base, le depot
# est public — mais parce que l'utilisateur ouvre UN systeme, pas un empilement.
# C'est la regle 9 du carnet : une couture ne montre jamais son moteur.
TAIRE = ("bazzite", "fedora", "ublue", "plasma", "kde ", "waydroid", "distrobox",
         "steam linux runtime", "proton", "wine")

# Les gestes de S sont des GESTIONNAIRES de fichiers, pas des applications :
# ils n'ont de sens que derriere un double-clic. Une etoile « Ouvrir un .exe »
# n'aurait rien a lancer.
#
# ON FILTRE PAR IDENTIFIANT, ET LA NUANCE A COUTE UN DEFAUT REEL. Filtrer sur
# la COMMANDE — tout .desktop dont l'Exec appelle s-ouvrir-exe — paraissait plus
# sur et supprimait le monde Windows en entier : les raccourcis moissonnes par
# s-menu-windows appellent TOUS s-ouvrir-exe, c'est leur raison d'etre. Trouve
# au banc du 2026-08-22, ou « Lineage II » avait disparu du ciel sans un mot.
IDENTIFIANTS_CACHES = ("s-ouvrir-", "s-menu-")


def dossiers_applications():
    """Les endroits ou vivent les .desktop, dans l'ordre de priorite XDG."""
    maison = os.path.expanduser("~")
    dirs = [os.path.join(os.environ.get("XDG_DATA_HOME") or
                         os.path.join(maison, ".local/share"), "applications")]
    for d in (os.environ.get("XDG_DATA_DIRS") or
              "/usr/local/share:/usr/share").split(":"):
        if d:
            dirs.append(os.path.join(d, "applications"))
    # Flatpak s'exporte ailleurs, et rien ne garantit qu'il soit dans XDG_DATA_DIRS
    # au moment ou la session demarre.
    dirs += ["/var/lib/flatpak/exports/share/applications",
             os.path.join(maison, ".local/share/flatpak/exports/share/applications")]
    vus, sortie = set(), []
    for d in dirs:
        r = os.path.realpath(d)
        if r not in vus and os.path.isdir(r):
            vus.add(r)
            sortie.append(d)
    return sortie


def lire_desktop(chemin):
    """Un analyseur minimal, volontairement : on ne lit que [Desktop Entry].

    Les groupes suivants sont des « actions » (Nouvelle fenetre, Navigation
    privee...) qui portent leurs propres Name= et Exec=. Les laisser entrer
    donnerait des etoiles fantomes qui lancent la mauvaise chose.
    """
    champs, dedans = {}, False
    try:
        with open(chemin, "r", encoding="utf-8", errors="replace") as f:
            for ligne in f:
                ligne = ligne.strip()
                if ligne.startswith("["):
                    dedans = (ligne == "[Desktop Entry]")
                    continue
                if not dedans or "=" not in ligne or ligne.startswith("#"):
                    continue
                cle, _, val = ligne.partition("=")
                champs.setdefault(cle.strip(), val.strip())
    except OSError:
        return None
    return champs


def vrai(champs, cle):
    return (champs.get(cle, "") or "").lower() == "true"


def nom_affiche(champs):
    """Le francais d'abord — S parle francais, et les .desktop le savent."""
    for cle in ("Name[fr_CA]", "Name[fr]", "Name"):
        if champs.get(cle):
            return champs[cle]
    return ""


def commentaire(champs):
    for cle in ("Comment[fr_CA]", "Comment[fr]", "Comment", "GenericName"):
        if champs.get(cle):
            return champs[cle]
    return ""


CATEGORIE_ICONE = (
    ("TerminalEmulator", "i-terminal"),
    ("FileManager",      "i-dossier"),
    ("FileTools",        "i-dossier"),
    ("WebBrowser",       "i-globe"),
    ("IDE",              "i-code"),
    ("Development",      "i-code"),
    ("Game",             "i-manette"),
    ("Emulator",         "i-manette"),
    ("Video",            "i-video"),
    ("AudioVideo",       "i-video"),
    ("Audio",            "i-note-mus"),
    ("Music",            "i-note-mus"),
    ("Photography",      "i-image"),
    ("Graphics",         "i-image"),
    ("Settings",         "i-reglages"),
    ("System",           "i-reglages"),
    ("PackageManager",   "i-magasin"),
    ("InstantMessaging", "i-bulle"),
    ("Chat",             "i-bulle"),
    ("Telephony",        "i-tel"),
    ("TextEditor",       "i-doc"),
    ("WordProcessor",    "i-doc"),
    ("Office",           "i-doc"),
    ("Network",          "i-reseau"),
    ("Utility",          "i-boite"),
)

# Les noms priment sur les categories : « Konsole » est un terminal quoi qu'en
# dise sa liste de categories, et une icone juste vaut mieux qu'une categorie
# exacte.
NOM_ICONE = (
    ("vivaldi", "i-globe"), ("firefox", "i-globe"), ("chrom", "i-globe"),
    ("code", "i-code"), ("antigravity", "i-code"),
    ("claude", "i-etincelle"), ("gemini", "i-etincelle"),
    ("konsole", "i-terminal"), ("terminal", "i-terminal"), ("ptyxis", "i-terminal"),
    ("dolphin", "i-dossier"), ("fichiers", "i-dossier"), ("files", "i-dossier"),
    ("retroarch", "i-manette"), ("steam", "i-manette"), ("jeu", "i-manette"),
    ("zoom", "i-video"), ("f-droid", "i-magasin"), ("fdroid", "i-magasin"),
    ("magasin", "i-magasin"), ("store", "i-magasin"),
    ("rapido", "i-fenetre"), ("android", "i-tel"),
    ("reglage", "i-reglages"), ("parametre", "i-reglages"),
)


def choisir_icone(nom, categories):
    n = nom.lower()
    for cle, ico in NOM_ICONE:
        if cle in n:
            return ico
    for cle, ico in CATEGORIE_ICONE:
        if cle in categories:
            return ico
    return "i-boite"


_ICONES = {}          # nom d'icone -> (chemin trouve ou "", instant)
_ICONES_TTL = 30.0    # une icone posee par une installation doit finir par etre vue


def dossiers_icones(categories=("apps",)):
    """Ou chercher le fichier d'une icone, du plus grand au plus petit.

    LA CATEGORIE N'EST PAS UN DETAIL, ET L'AVOIR CODEE EN DUR A COUTE UN
    DEFAUT. Cette fonction ne regardait que « apps », ce qui suffisait tant que
    Constellation ne portait que des lanceurs. Les icones d'un FICHIER vivent
    ailleurs — « mimetypes » pour les types, « places » pour les dossiers — et
    aucun fichier du bureau n'en recevait : ils retombaient tous sur le glyphe,
    sans qu'une seule ligne signale que le theme en avait une.

    On ne fait pas une vraie resolution de theme freedesktop — elle demande de
    remonter les heritages de « index.theme » et n'apporterait rien ici. On
    parcourt les emplacements ou une application POSE son icone, ce qui est
    exactement ce dont on a besoin : Wine ecrit dans hicolor du dossier
    personnel, les RPM dans celui du systeme, Flatpak dans ses exports.
    """
    maison = os.path.expanduser("~")
    racines = [os.path.join(maison, ".local/share/icons"),
               os.path.join(maison, ".icons"),
               "/usr/share/icons",
               "/usr/local/share/icons",
               os.path.join(maison, ".local/share/flatpak/exports/share/icons"),
               "/var/lib/flatpak/exports/share/icons"]

    def rang(taille):
        # Le vectoriel passe apres les tres grandes tailles : un PNG de 512 est
        # plus sur qu'un SVG que le rendu pourrait mal servir, et plus net
        # qu'un PNG de 48 agrandi sur une etoile de 60 pixels.
        if taille == "scalable":
            return 400
        try:
            return int(taille.split("x")[0])
        except (ValueError, IndexError):
            return 0

    dossiers = []
    for racine in racines:
        for theme in ("hicolor", "breeze", "Adwaita"):
            base = os.path.join(racine, theme)
            try:
                tailles = os.listdir(base)
            except OSError:
                continue
            for taille in sorted(tailles, key=rang, reverse=True):
                for categorie in categories:
                    chemin = os.path.join(base, taille, categorie)
                    if os.path.isdir(chemin):
                        dossiers.append(chemin)
            # BREEZE RANGE A L'ENVERS, ET C'EST MESURE SUR CETTE MACHINE :
            # « breeze/mimetypes/16/application-pdf.svg » — la categorie avant
            # la taille, alors qu'Adwaita et hicolor font « 16x16/mimetypes ».
            # Ne connaitre qu'une des deux dispositions revient a ignorer le
            # theme d'icones de KDE en entier.
            for categorie in categories:
                sous = os.path.join(base, categorie)
                try:
                    tailles2 = os.listdir(sous)
                except OSError:
                    continue
                for taille in sorted(tailles2, key=rang, reverse=True):
                    chemin = os.path.join(sous, taille)
                    if os.path.isdir(chemin):
                        dossiers.append(chemin)
    for nu in ("/usr/share/pixmaps", os.path.join(maison, ".local/share/pixmaps")):
        if os.path.isdir(nu):
            dossiers.append(nu)
    return dossiers


def chemin_icone(nom, categories=("apps",)):
    """Le fichier de l'icone d'une application, ou "" s'il n'y en a pas.

    POURQUOI CETTE FONCTION EXISTE. Les glyphes dessines dans la page disent le
    GENRE d'un logiciel — une note de musique, une boite. L'icone du programme
    dit LEQUEL. Une etoile VLC doit porter le cone de VLC. Demande de
    l'utilisateur le 2026-08-23.

    On ne rend que du PNG ou du SVG : un .xpm ne s'affiche dans aucun
    navigateur, et le servir ne ferait que declencher le repli cote page.
    """
    if not nom:
        return ""
    if nom.startswith("/"):
        return nom if os.path.isfile(nom) else ""

    # LA CATEGORIE ENTRE DANS LA CLEF DU CACHE. Sans elle, un « folder »
    # cherche dans « apps » et non trouve empecherait de le retrouver dans
    # « places » pendant tout le TTL — un cache qui memorise une absence
    # repond faux plus longtemps qu'il ne repond juste.
    clef = (nom, categories)
    vu = _ICONES.get(clef)
    if vu is not None and (time.monotonic() - vu[1]) < _ICONES_TTL:
        if not vu[0] or os.path.isfile(vu[0]):
            return vu[0]

    trouve = ""
    for dossier in dossiers_icones(categories):
        for ext in (".png", ".svg"):
            essai = os.path.join(dossier, nom + ext)
            if os.path.isfile(essai):
                trouve = essai
                break
        if trouve:
            break
    _ICONES[clef] = (trouve, time.monotonic())
    return trouve


def choisir_monde(exec_ligne):
    """De quel monde vient ce logiciel — c'est ce que dit l'anneau de l'etoile.

    On le lit dans la commande, seul endroit ou la verite se trouve : un
    raccourci Windows moissonne par s-menu-windows repasse par s-ouvrir-exe,
    une application Android par waydroid. Tout le reste est natif.
    """
    e = exec_ligne.lower()
    if "s-ouvrir-exe" in e or "umu-run" in e or "wine" in e or "proton" in e:
        return "windows"
    if "waydroid" in e or "s-android" in e:
        return "android"
    return "linux"


def inventaire():
    """Toutes les applications visibles de la machine, une seule fois chacune."""
    trouves = {}
    for dossier in dossiers_applications():
        try:
            noms = sorted(os.listdir(dossier))
        except OSError:
            continue
        for nom_fichier in noms:
            if not nom_fichier.endswith(".desktop"):
                continue
            ident = nom_fichier[:-len(".desktop")]
            if ident in trouves:      # priorite XDG : le premier vu gagne
                continue
            champs = lire_desktop(os.path.join(dossier, nom_fichier))
            if not champs:
                continue
            if champs.get("Type", "Application") != "Application":
                continue
            if vrai(champs, "NoDisplay") or vrai(champs, "Hidden"):
                continue
            ligne_exec = champs.get("Exec", "")
            if not ligne_exec:
                continue
            if ident.startswith(IDENTIFIANTS_CACHES):
                continue
            # TryExec dit « ne me montre pas si ce binaire n'existe pas ». C'est
            # exactement le defaut qui a casse Vivaldi sur la machine reelle : un
            # lanceur qui pointe dans le vide. On l'honore.
            essai = champs.get("TryExec")
            if essai and not chemin_executable(essai):
                continue
            nom = nom_affiche(champs)
            if not nom:
                continue
            bas = nom.lower()
            if any(t in bas for t in TAIRE):
                continue
            # Constellation ne se met pas elle-meme dans le ciel.
            if ident in ("constellation", "s-constellation"):
                continue
            categories = champs.get("Categories", "")
            trouves[ident] = {
                "id": ident,
                "nom": nom,
                "src": choisir_monde(ligne_exec),
                "ico": choisir_icone(nom, categories),
                # Le nom de l'icone declaree par le logiciel. Il n'est pas
                # resolu ici : la resolution coute des acces disque, et
                # l'inventaire est relu toutes les quinze secondes.
                "icone": champs.get("Icon", ""),
                "txt": commentaire(champs) or ligne_exec,
                "fichier": os.path.join(dossier, nom_fichier),
            }
    return trouves


def chemin_executable(cmd):
    if cmd.startswith("/"):
        return cmd if os.access(cmd, os.X_OK) else None
    for d in (os.environ.get("PATH") or "/usr/bin").split(":"):
        p = os.path.join(d, cmd)
        if os.access(p, os.X_OK):
            return p
    return None


# --------------------------------------------------------------------------
# L'usage : ce qui fait grossir une etoile
# --------------------------------------------------------------------------

def charger_usage():
    try:
        with open(FICHIER_USAGE, "r", encoding="utf-8") as f:
            u = json.load(f)
        return {k: int(v) for k, v in u.items() if isinstance(v, (int, float))}
    except (OSError, ValueError, AttributeError):
        return {}


def sauver_usage(usage):
    try:
        os.makedirs(ETAT, exist_ok=True)
        temporaire = FICHIER_USAGE + ".tmp"
        with open(temporaire, "w", encoding="utf-8") as f:
            json.dump(usage, f)
        os.replace(temporaire, FICHIER_USAGE)   # jamais de fichier a moitie ecrit
    except OSError as err:
        print("s-noyau : usage non sauve : %s" % err, file=sys.stderr)


# --------------------------------------------------------------------------
# Les etoiles PLACEES : ce que l'utilisateur a choisi de mettre au ciel
# --------------------------------------------------------------------------
# L'inventaire brut de la machine peut compter des dizaines d'entrees — sur
# la M720q, 81 le 2026-08-23, EmuDeck et consorts compris. Les deverser toutes
# sur le ciel d'un coup n'est pas une etoile choisie, c'est un fouillis. Ce que
# le ciel affiche vient de la, jamais de l'inventaire entier.
def charger_placees():
    try:
        with open(FICHIER_PLACEES, "r", encoding="utf-8") as f:
            p = json.load(f)
        return {str(k): {"x": float(v["x"]), "y": float(v["y"])}
                for k, v in p.items() if isinstance(v, dict) and "x" in v and "y" in v}
    except (OSError, ValueError, KeyError, TypeError):
        return {}


def sauver_placees(placees):
    try:
        os.makedirs(ETAT, exist_ok=True)
        temporaire = FICHIER_PLACEES + ".tmp"
        with open(temporaire, "w", encoding="utf-8") as f:
            json.dump(placees, f)
        os.replace(temporaire, FICHIER_PLACEES)
    except OSError as err:
        print("s-noyau : placement non sauve : %s" % err, file=sys.stderr)


# --------------------------------------------------------------------------
# Les gestes
# --------------------------------------------------------------------------

def lancer(entree):
    """Lancer par le .desktop lui-meme, jamais par une commande recomposee.

    « gio launch » applique les regles du fichier — repertoire de travail,
    Terminal=true, variables — que reconstruire a la main ferait perdre. Le
    repli n'existe que si gio manquait : on retire alors les codes de champ
    (%f %u %i...), qui sinon arriveraient tels quels au programme.
    """
    fichier = entree["fichier"]
    if chemin_executable("gio"):
        cmd = ["gio", "launch", fichier]
    else:
        champs = lire_desktop(fichier) or {}
        brut = re.sub(r"%[fFuUdDnNickvm]", "", champs.get("Exec", "")).strip()
        if not brut:
            return False, "aucune commande dans %s" % os.path.basename(fichier)
        cmd = shlex.split(brut)
    try:
        subprocess.Popen(cmd, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        return False, str(err)
    return True, "lancee"


def lancer_en_root(entree):
    """Relance la commande d'une etoile avec pkexec.

    DEMANDE DE L'UTILISATEUR (entretien du 2026-08-27, reponse 16) : pouvoir
    executer un logiciel pose au bureau avec des droits d'administration,
    comme sur n'importe quel bureau normal — un outil de partitionnement, un
    gestionnaire reseau bas niveau.

    MEME GARDE-FOU QUE LES NEUF pkexec DE S (voir « s_root » dans s-monde) :
    un « timeout --foreground » borne l'attente si personne ne repond a la
    fenetre de polkit, plutot que de bloquer la coquille sans fin.
    """
    fichier = (entree or {}).get("fichier")
    if not fichier:
        return False, "cette etoile n'a pas de commande a relancer"
    champs = lire_desktop(fichier) or {}
    brut = re.sub(r"%[fFuUdDnNickvm]", "", champs.get("Exec", "")).strip()
    if not brut:
        return False, "aucune commande dans %s" % os.path.basename(fichier)
    cmd = shlex.split(brut)
    pkexec = chemin_executable("pkexec")
    if not pkexec:
        return False, "pkexec n'est pas sur cette machine"

    # PKEXEC VIDE L'ENVIRONNEMENT DU PROGRAMME LANCE — sa propre page de
    # manuel le dit : « The environment that PROGRAM will run in, will be set
    # to a minimal known and safe environment… pkexec will not by default
    # allow you to run X11 applications… since $DISPLAY and $XAUTHORITY are
    # not set ». WAYLAND_DISPLAY, XDG_RUNTIME_DIR et DBUS_SESSION_BUS_ADDRESS
    # ne font pas plus partie de cet environnement minimal. C'est exactement
    # le symptome rapporte le 2026-08-30 : pkexec authentifie (le mot de
    # passe est demande), puis le programme meurt en silence, incapable de
    # joindre le compositeur — jamais teste contre un vrai clic avant ce
    # jour, le carnet le disait deja.
    #
    # RIEN N'EMPECHE ROOT DE PARLER AU COMPOSITEUR UNE FOIS QU'ON LUI DONNE
    # CES VARIABLES : mesure sur cette machine, /run/user/<uid>/wayland-0 est
    # « srwxr-xr-x » et le bus de session « srw-rw-rw- » — seule la racine
    # /run/user/<uid> (0700) protege le socket, et root la traverse sans
    # restriction. On ne devine pas ces valeurs, on les relit dans l'environ-
    # nement de Constellation lui-meme, qui EST la session graphique.
    env_exe = chemin_executable("env")
    env_args = []
    if env_exe:
        for var in ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY",
                     "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS"):
            valeur = os.environ.get(var)
            if valeur:
                env_args.append("%s=%s" % (var, valeur))
        env_args = [env_exe] + env_args

    timeout = chemin_executable("timeout")
    argv = (([timeout, "--foreground", "120", pkexec] if timeout else [pkexec])
            + env_args + cmd)
    return _lancer_detache(argv)


# ═══ DESINSTALLER, DEMANDE PAR L'UTILISATEUR LE 2026-08-29 ═══════════════════
#
# TROIS MONDES, TROIS MOYENS DE SAVOIR SI C'EST VRAIMENT POSSIBLE — et un
# quatrieme cas, les applications Linux natives de l'image, ou ce n'est PAS
# possible sans alourdir une couche rpm-ostree et redemarrer : on ne propose
# rien plutot que de promettre un geste qu'on ne peut pas honorer proprement.
#
# ANDROID : Android sait desinstaller ses propres applications — c'est
# « removeApp », le meme service IPlatform que « installApp » (voir
# android_plateforme.py). Une vraie desinstallation, synchrone, en moins
# d'une seconde d'apres les mesures deja faites sur cette machine pour
# « installApp ».
#
# WINDOWS : ON NE DEVINE PAS OU EFFACER, ON CHERCHE LE VRAI DESINSTALLEUR.
# La plupart des installateurs Windows (Inno Setup, NSIS...) posent leur
# propre executable de desinstallation a cote du programme — c'est cet
# executable que « s-menu-windows » ecarte deja de la moisson des raccourcis
# (voir son commentaire : « un desinstalleur n'a rien a faire dans le
# menu »). On le retrouve ici, dans le meme dossier ou son voisin d'a cote,
# et on le LANCE — le vrai, celui de l'editeur, jamais un « rm -rf » invente
# a sa place.
#
# LINUX (distrobox) ET LINUX NATIF : hors de portee ce soir. Le nom du
# paquet apt/dnf reellement installe n'est retenu nulle part apres la pose
# (voir s-ouvrir-paquet, qui le lit une fois et ne le garde pas) — le
# deviner depuis le nom du fichier .desktop serait faux pour tout paquet
# dont l'identifiant differe de son .desktop. Chantier a part.

_MOTIFS_DESINSTALLEUR = ("uninstall.exe", "uninst.exe", "unins000.exe")


def _exe_windows(fichier_desktop):
    """Le chemin Linux du .exe qu'un lanceur Windows appelle, ou None."""
    champs = lire_desktop(fichier_desktop) or {}
    m = re.search(r'"([^"]+\.exe)"', champs.get("Exec", ""), re.IGNORECASE)
    return m.group(1) if m else None


def _desinstalleur_windows(exe):
    """Cherche un vrai desinstalleur pres du .exe. Rend son chemin, ou None.

    DEUX DOSSIERS, PAS UN SEUL : le programme lance peut vivre dans un
    sous-dossier (« bin », « x64»...) alors que l'installateur a pose son
    desinstalleur au niveau du dossier parent — releve courant chez les
    installateurs NSIS multi-plateformes.
    """
    dossiers = []
    d = os.path.dirname(exe)
    if d:
        dossiers.append(d)
        parent = os.path.dirname(d)
        if parent and parent != d:
            dossiers.append(parent)
    for dossier in dossiers:
        try:
            noms = os.listdir(dossier)
        except OSError:
            continue
        for nom in noms:
            bas = nom.lower()
            if bas in _MOTIFS_DESINSTALLEUR or (
                    bas.startswith("unins") and bas.endswith(".exe")):
                return os.path.join(dossier, nom)
    return None


def desinstallable(entree):
    """Cette etoile peut-elle vraiment etre desinstallee — pas juste retiree
    du menu ? Rend un booleen, jamais une supposition."""
    monde = entree.get("src")
    if monde == "android":
        return entree.get("id", "").startswith("waydroid.")
    if monde == "windows":
        fichier = entree.get("fichier")
        exe = _exe_windows(fichier) if fichier else None
        return bool(exe and _desinstalleur_windows(exe))
    return False


def desinstaller(entree):
    """Desinstalle pour de vrai. Rend (ok, phrase a afficher)."""
    monde = entree.get("src")
    nom = entree.get("nom", entree.get("id", "?"))

    if monde == "android":
        ident = entree.get("id", "")
        if not ident.startswith("waydroid."):
            return False, "pas une application Android"
        paquet = ident[len("waydroid."):]
        try:
            import android_plateforme as ap
        except ImportError as err:
            return False, "pont Android indisponible (%s)" % err
        plateforme = ap.obtenir(15)
        if not plateforme:
            return False, "Android ne repond pas"
        try:
            exception = plateforme.removeApp(paquet)
        except Exception as err:  # noqa: BLE001
            return False, "echec de la desinstallation (%s)" % err
        if exception:
            return False, "Android refuse (code %s)" % exception
        # LE LANCEUR EST RETIRE TOUT DE SUITE, PAS DANS TRENTE SECONDES. Le
        # demon android-applications.py l'aurait fait au prochain passage
        # periodique — l'utilisateur ne doit pas voir une icone morte
        # pendant ce temps, pour une action qu'on sait deja reussie.
        fichier = entree.get("fichier")
        if fichier:
            try:
                os.remove(fichier)
            except OSError:
                pass
        return True, "%s desinstallee" % nom

    if monde == "windows":
        fichier = entree.get("fichier")
        exe = _exe_windows(fichier) if fichier else None
        desins = _desinstalleur_windows(exe) if exe else None
        if not desins:
            return False, "aucun desinstalleur trouve pour %s" % nom
        # LE VRAI DESINSTALLEUR DE L'EDITEUR, PAR LE MEME CHEMIN QUE
        # N'IMPORTE QUEL .exe DE S — « s-ouvrir-exe » sait deja gerer le
        # serveur Wine resident et son repli umu-run ; le reecrire ici
        # dupliquerait un mecanisme deja eprouve pour rien.
        outil = _outil("s-ouvrir-exe")
        if not outil:
            return False, "s-ouvrir-exe est absent de cette machine"
        # DETACHE, JAMAIS ATTENDU. La plupart des desinstalleurs Windows
        # ouvrent un assistant qui demande des clics — bloquer ce Slot
        # jusqu'a sa fermeture gelerait toute la coquille, l'exact defaut
        # que ce depot a deja corrige neuf fois pour pkexec (voir s_root).
        ok, err = _lancer_detache([outil, desins])
        if not ok:
            return False, "desinstalleur introuvable au lancement (%s)" % err
        return True, "Desinstallation de %s lancee — suivez l'assistant" % nom

    return False, "desinstallation non prise en charge pour %s" % nom


GESTES_SESSION = {
    "verrouiller": ["loginctl", "lock-session"],
    "deconnecter": ["loginctl", "terminate-session", os.environ.get("XDG_SESSION_ID", "self")],
    "redemarrer":  ["systemctl", "reboot"],
    "eteindre":    ["systemctl", "poweroff"],
}


# Le temoin de sortie voulue. La coquille relance Constellation chaque fois
# qu'elle se ferme — sans quoi un Alt+F4 malheureux deconnecterait l'utilisateur
# au milieu de son travail, ce qu'aucun bureau ne fait. Il faut donc distinguer
# « la fenetre s'est fermee » de « l'utilisateur veut partir », et seul ce
# fichier fait la difference.
TEMOIN_SORTIE = os.path.join(ETAT, "quitter")


def geste_session(action):
    cmd = GESTES_SESSION.get(action)
    if not cmd:
        return False, "geste inconnu"
    if action in ("deconnecter", "redemarrer", "eteindre"):
        try:
            os.makedirs(ETAT, exist_ok=True)
            with open(TEMOIN_SORTIE, "w", encoding="utf-8") as f:
                f.write(action)
        except OSError:
            pass          # le geste doit partir meme si le temoin echoue
    try:
        subprocess.Popen(cmd, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        return False, str(err)
    return True, action


# --------------------------------------------------------------------------
# La page, avec la machine dedans
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Les epinglees : ce que l'utilisateur decide, et non plus le compteur
# --------------------------------------------------------------------------
# CE QUI EXISTAIT AVANT, ET POURQUOI C'ETAIT UNE PANNE. La barre affichait
# « ordre[:7] » — les sept applications les plus lancees. Personne ne pouvait
# y ajouter ni en retirer quoi que ce soit : il n'y avait pas d'API pour cela,
# et pas de clic droit pour l'appeler. Une barre des taches qui se recompose
# toute seule dans le dos de l'utilisateur n'est pas une barre des taches.
#
# LE DEFAUT RESTE LE COMPTEUR, ET C'EST DELIBERE. Sur une machine neuve, aucun
# choix n'a encore ete fait : une barre vide serait un bureau vide. Tant que le
# fichier n'existe pas, on sert donc les plus utilisees. Des que l'utilisateur
# epingle ou desepingle une seule fois, le fichier nait et son choix l'emporte
# — definitivement, y compris s'il choisit de tout retirer.
EPINGLEES_PAR_DEFAUT = 7


def charger_epingles():
    """Les identifiants epingles, ou None si l'utilisateur n'a jamais choisi.

    None et [] sont deux reponses DIFFERENTES : « je n'ai rien dit, decide pour
    moi » et « je veux une barre vide ». Les confondre rendrait impossible de
    vider sa barre — elle se repeuplerait toute seule au tour suivant.
    """
    try:
        with open(FICHIER_EPINGLES, "r", encoding="utf-8") as f:
            p = json.load(f)
        if not isinstance(p, list):
            return None
        return [str(x) for x in p]
    except (OSError, ValueError):
        return None


def sauver_epingles(epingles):
    try:
        os.makedirs(ETAT, exist_ok=True)
        temporaire = FICHIER_EPINGLES + ".tmp"
        with open(temporaire, "w", encoding="utf-8") as f:
            json.dump(list(epingles), f)
        os.replace(temporaire, FICHIER_EPINGLES)
    except OSError as err:
        print("s-noyau : epingles non sauvees : %s" % err, file=sys.stderr)


def epingler(ident, oui):
    """Poser ou retirer une epingle. Rend la liste telle qu'elle est ensuite.

    L'ORDRE EST CELUI DES GESTES, PAS CELUI DE L'ALPHABET NI DE L'USAGE : une
    application epinglee garde sa place dans la barre tant qu'on ne la retire
    pas. C'est ce qui permet de viser une icone sans regarder.
    """
    epingles = charger_epingles()
    if epingles is None:
        # Premier choix : on part de ce que la barre montrait deja, pour que le
        # geste AJOUTE au lieu de tout balayer.
        epingles = [a["id"] for a in _ordre_par_usage()[:EPINGLEES_PAR_DEFAUT]]
    if oui:
        if ident not in epingles:
            epingles.append(ident)
    else:
        epingles = [e for e in epingles if e != ident]
    sauver_epingles(epingles)
    return epingles


def _ordre_par_usage():
    usage = charger_usage()
    return sorted(inventaire().values(), key=lambda a: -usage.get(a["id"], 0))


# --------------------------------------------------------------------------
# L'inventaire mis en forme pour la coquille
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# LES ETOILES JAUNES : ce que le bureau porte et qui n'est pas une application
# --------------------------------------------------------------------------
#
# CE QUI CHANGE DE NATURE ICI. Jusqu'ici le ciel ne portait que des LANCEURS,
# et une etoile ne montait qu'apres avoir ete placee a la main. Un fichier
# obeit a la regle inverse : il est au ciel parce qu'il est dans le dossier,
# et il en part quand on l'en sort. C'est ce que tout bureau fait depuis
# trente ans, et s'en ecarter voudrait dire qu'un fichier depose sur le bureau
# ne s'y verrait pas.
#
# LE JAUNE NE DIT PAS UN MONDE. Rouge, bleu et vert repondent « d'ou vient ce
# logiciel ». Le jaune repond « ce n'en est pas un ».

# Le glyphe d'un fichier, par famille de type MIME. Aucun n'est dessine pour
# l'occasion : les vingt-huit glyphes de Constellation existaient deja, et huit
# d'entre eux nomment exactement ces familles.
_GLYPHES_MIME = (
    ("inode/directory", "i-dossier"),
    ("image/",          "i-image"),
    ("video/",          "i-video"),
    ("audio/",          "i-note-mus"),
    ("text/html",       "i-globe"),
    ("text/x-",         "i-code"),
    ("application/x-shellscript", "i-code"),
    ("application/json", "i-code"),
    ("application/xml",  "i-code"),
    ("application/zip",  "i-boite"),
    ("application/x-tar", "i-boite"),
    ("application/x-compressed", "i-boite"),
    ("application/gzip", "i-boite"),
    ("application/pdf",  "i-doc"),
    ("text/",            "i-notes"),
)

# Le cache des icones de fichiers. Clef : (chemin, mtime, taille). QMimeDatabase
# LIT LE CONTENU pour trancher un fichier sans extension, ce qui coute un acces
# disque — et l'inventaire est relu toutes les quinze secondes. Le mtime dans la
# clef fait que le cache se perime tout seul quand le fichier change.
_MIME_CACHE = {}
_MIME_CACHE_MAX = 4096
_BASE_MIME = None


def _base_mime():
    """QMimeDatabase, ou None si Qt n'est pas la.

    L'IMPORT EST PARESSEUX, ET CE N'EST PAS UNE PRECAUTION DE STYLE. « s-monde »
    appelle ce module depuis un python3 NU — pas celui de la coquille — pour
    poser la position d'une etoile a l'installation d'un logiciel, et son bloc
    se termine par « 2>/dev/null || true ». Un « import PySide6 » en tete de
    fichier y echouerait SANS UN MOT, et le placement automatique des etoiles
    cesserait sans que rien ne le signale. Le succes silencieux, pris par le
    bout ou personne ne regarde.
    """
    try:
        from PySide6.QtCore import QMimeDatabase
    except Exception:
        return None
    global _BASE_MIME
    if _BASE_MIME is None:
        _BASE_MIME = QMimeDatabase()
    return _BASE_MIME


def _glyphe_pour(type_mime):
    for prefixe, glyphe in _GLYPHES_MIME:
        if type_mime == prefixe or type_mime.startswith(prefixe):
            return glyphe
    return "i-doc"


def icone_de_fichier(chemin, est_dossier, mtime, taille):
    """Le glyphe et le fichier d'icone d'un fichier du bureau.

    Rend (glyphe, chemin_icone). Le glyphe est toujours rendu ; le chemin
    d'icone peut etre vide, auquel cas l'etoile retombe sur le glyphe — la
    meme regle que pour les applications.
    """
    clef = (chemin, mtime, taille)
    vu = _MIME_CACHE.get(clef)
    if vu is not None:
        return vu

    CAT = ("mimetypes", "places", "apps")

    if est_dossier:
        resultat = ("i-dossier",
                    chemin_icone("folder", CAT) or chemin_icone("inode-directory", CAT))
    else:
        base = _base_mime()
        if base is None:
            # REPLI SANS QT, ET IL EST HONNETE SUR CE QU'IL SAIT. « mimetypes »
            # ne lit que l'extension : il ne trouvera rien sur un fichier qui
            # n'en a pas. Mieux vaut un glyphe generique qu'un mauvais.
            import mimetypes
            type_mime = mimetypes.guess_type(chemin)[0] or "application/octet-stream"
            resultat = (_glyphe_pour(type_mime), "")
        else:
            m = base.mimeTypeForFile(chemin)
            type_mime = m.name()
            # DEUX NOMS D'ICONE, ET IL FAUT LES DEUX. « iconName » rend
            # « text-plain », qui n'existe dans presque aucun theme ;
            # « genericIconName » rend « text-x-generic », qui existe partout.
            # N'essayer que le premier laisserait la plupart des fichiers sans
            # icone alors que le theme en a une.
            fichier = (chemin_icone(m.iconName(), CAT)
                       or chemin_icone(m.genericIconName(), CAT))
            # UNE IMAGE EST SA PROPRE ICONE. C'est ce que fait tout bureau
            # depuis toujours, et ca ne coute rien ici : QML borne deja la
            # memoire de decodage par « sourceSize ». La borne de taille, elle,
            # evite de decoder un TIFF de 200 Mo pour une vignette de 40 px.
            if type_mime.startswith("image/") and taille <= 20 * 1024 * 1024:
                fichier = chemin
            resultat = (_glyphe_pour(type_mime), fichier)

    if len(_MIME_CACHE) > _MIME_CACHE_MAX:
        _MIME_CACHE.clear()
    _MIME_CACHE[clef] = resultat
    return resultat


def fichiers_bureau():
    """Ce que porte le dossier du bureau, sous la forme d'etoiles.

    L'ordre est celui de tout gestionnaire de fichiers : les dossiers d'abord,
    puis les fichiers, chacun par nom. Il n'est pas cosmetique — c'est lui qui
    decide de la place en grille des etoiles qu'on n'a jamais deplacees, donc
    de leur stabilite d'une session a l'autre.
    """
    racine = dossier_bureau()
    try:
        noms = os.listdir(racine)
    except OSError:
        return []

    entrees = []
    for nom in noms:
        # Les fichiers caches restent caches. Un bureau qui montre « .directory »
        # ne montre pas ce que l'utilisateur y a mis.
        if nom.startswith("."):
            continue
        chemin = os.path.join(racine, nom)
        try:
            etat = os.stat(chemin)
        except OSError:
            # Un lien casse, ou un fichier disparu entre le listing et le stat.
            # On l'ignore plutot que de faire tomber tout l'inventaire.
            continue
        entrees.append((chemin, nom, os.path.isdir(chemin), etat))

    entrees.sort(key=lambda e: (not e[2], e[1].lower()))

    etoiles = []
    for chemin, nom, est_dossier, etat in entrees:
        # UN .desktop POSE SUR LE BUREAU EST UN LANCEUR, PAS UN FICHIER. Le
        # peindre en jaune avec une icone de document dirait le contraire de ce
        # qu'il est — et le carnet reproche deja au menu d'avoir dit « le genre
        # et jamais lequel ». On le lit donc, et il prend son monde et son icone.
        if not est_dossier and nom.endswith(".desktop"):
            champs = lire_desktop(chemin)
            if champs and champs.get("Exec"):
                ligne_exec = champs.get("Exec", "")
                etoiles.append({
                    "id": "fichier:" + chemin,
                    "nom": nom_affiche(champs) or nom[:-len(".desktop")],
                    "src": choisir_monde(ligne_exec),
                    "ico": choisir_icone(nom_affiche(champs) or nom,
                                         champs.get("Categories", "")),
                    "ep": 1,
                    "epingle": 0,
                    "img": _url_icone(chemin_icone(champs.get("Icon", ""))),
                    "txt": commentaire(champs) or chemin,
                    "compte": 0,
                    "chemin": chemin,
                    "dossier": 0,
                })
                continue

        glyphe, fichier_icone = icone_de_fichier(
            chemin, est_dossier, int(etat.st_mtime), etat.st_size)
        etoiles.append({
            "id": "fichier:" + chemin,
            "nom": nom,
            "src": "fichier",
            "ico": glyphe,
            # « ep » vaut 1 : l'anneau d'une etoile jaune est PLEIN. Le trait
            # pointille veut dire « pose dans l'image et jamais exerce », ce qui
            # n'a aucun sens pour un fichier qui est la, sur le disque.
            "ep": 1,
            "epingle": 0,
            "img": _url_icone(fichier_icone),
            "txt": chemin,
            "compte": 0,
            "chemin": chemin,
            "dossier": 1 if est_dossier else 0,
        })
    return etoiles


def _url_icone(chemin):
    return ("file://" + chemin) if chemin else ""


def ouvrir_fichier(chemin):
    """Ouvre un fichier ou un dossier avec ce que la machine lui associe.

    ON NE REIMPLEMENTE PAS CE QUE L'AMONT MAINTIENT. « kioclient exec » est
    l'ouvreur de KDE : il resout le type MIME, trouve l'application par defaut,
    honore les .desktop et les executables, et sait ouvrir un dossier dans le
    gestionnaire de fichiers. Ecrire cette resolution ici serait la refaire
    moins bien.
    """
    if not os.path.exists(chemin):
        return False, "ce fichier n'existe plus"
    outil = chemin_executable("kioclient")
    if not outil:
        # Repli sur la voie freedesktop, presente meme sans KDE.
        outil = chemin_executable("gio")
        if outil:
            argv = [outil, "open", chemin]
        else:
            return False, "aucun ouvreur sur cette machine"
    else:
        argv = [outil, "exec", chemin]
    try:
        subprocess.Popen(argv, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        return False, "ouverture impossible : %s" % err
    return True, os.path.basename(chemin)


def applications_pour_type(chemin):
    """Les applications qui declarent savoir ouvrir ce fichier.

    « Ouvrir avec… » — le troisieme reflexe universel d'un clic droit sur un
    fichier (apres Ouvrir et Renommer), reste absent jusqu'ici.

    ON NE DEVINE RIEN. Le vrai type MIME vient de QMimeDatabase — la meme
    source qu'icone_de_fichier() consulte deja — et chaque .desktop de la
    machine dit LUI-MEME, dans sa cle MimeType=, ce qu'il sait ouvrir ;
    lire_desktop() la capture deja, puisqu'elle lit tout le groupe
    [Desktop Entry] sans liste blanche de cles. Rien de neuf a lire.

    Rend une liste de {id, nom, ico, fichier, defaut}, l'associee courante
    en tete quand on la connait — « xdg-mime query default » est la meme
    source que kioclient/gio consultent pour choisir tout seuls, on la relit
    au lieu de la recalculer.
    """
    if not os.path.exists(chemin):
        return []
    type_mime = ""
    base = _base_mime()
    if base is not None:
        type_mime = base.mimeTypeForFile(chemin).name()
    if not type_mime:
        import mimetypes
        type_mime = mimetypes.guess_type(chemin)[0] or ""
    if not type_mime:
        return []

    par_defaut = ""
    xdg_mime = _outil("xdg-mime")
    if xdg_mime:
        try:
            r = subprocess.run([xdg_mime, "query", "default", type_mime],
                               capture_output=True, text=True, timeout=5)
            par_defaut = (r.stdout or "").strip()
        except (OSError, subprocess.SubprocessError):
            pass

    trouves = {}
    for dossier in dossiers_applications():
        try:
            noms = sorted(os.listdir(dossier))
        except OSError:
            continue
        for nom_fichier in noms:
            if not nom_fichier.endswith(".desktop") or nom_fichier in trouves:
                continue
            fichier = os.path.join(dossier, nom_fichier)
            champs = lire_desktop(fichier)
            if not champs:
                continue
            declares = [t.strip() for t in champs.get("MimeType", "").split(";") if t.strip()]
            if type_mime not in declares:
                continue
            if champs.get("Type", "Application") != "Application":
                continue
            if vrai(champs, "NoDisplay") or vrai(champs, "Hidden"):
                continue
            essai = champs.get("TryExec")
            if essai and not chemin_executable(essai):
                continue
            nom = nom_affiche(champs)
            if not nom:
                continue
            trouves[nom_fichier] = {
                "id": nom_fichier[:-len(".desktop")],
                "nom": nom,
                "ico": choisir_icone(nom, champs.get("Categories", "")),
                "fichier": fichier,
                "defaut": nom_fichier == par_defaut,
            }
    # Le defaut en tete, le reste par nom — comme n'importe quel sous-menu
    # « Ouvrir avec » d'un vrai bureau.
    return sorted(trouves.values(), key=lambda a: (not a["defaut"], a["nom"].lower()))


def ouvrir_avec(chemin, fichier_desktop):
    """Ouvre un fichier avec UNE application precise, sans toucher au defaut.

    MEME OUTIL QUE lancer() : « gio launch » applique les regles du .desktop
    vise (repertoire de travail, Terminal=true…) et sait deja passer un
    fichier en argument selon les codes %f/%F/%u/%U qu'il declare — rien a
    reconstruire. Le repli sans gio va un cran plus loin que celui de
    lancer(), qui n'a jamais eu de fichier a transmettre : ici il en faut un.
    """
    if not os.path.exists(chemin):
        return False, "ce fichier n'existe plus"
    if not os.path.isfile(fichier_desktop):
        return False, "cette application n'existe plus"
    gio = chemin_executable("gio")
    if gio:
        cmd = [gio, "launch", fichier_desktop, chemin]
    else:
        champs = lire_desktop(fichier_desktop) or {}
        brut = champs.get("Exec", "")
        if not brut:
            return False, "aucune commande dans %s" % os.path.basename(fichier_desktop)
        if re.search(r"%[fFuU]", brut):
            brut = re.sub(r"%[fFuU]", shlex.quote(chemin), brut, count=1)
        else:
            brut = brut + " " + shlex.quote(chemin)
        brut = re.sub(r"%[dDnNickvm]", "", brut).strip()
        cmd = shlex.split(brut)
    try:
        subprocess.Popen(cmd, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as err:
        return False, str(err)
    return True, "ouvert"


def composer_etoiles():
    """Tout ce que la coquille affiche, en une seule lecture.

    Rend un dictionnaire plutot qu'un tuple : la coquille le passe tel quel a
    QML, ou chaque cle devient une propriete. Un tuple positionnel obligerait
    a se souvenir de l'ordre des trois elements, et le prochain ajout casserait
    silencieusement l'appelant.
    """
    apps = inventaire()
    usage = charger_usage()
    placees = charger_placees()
    choisies = charger_epingles()
    fichiers = fichiers_bureau()

    # UN FICHIER EPINGLE QUI QUITTE LE BUREAU RESTE EPINGLE. On range une
    # capture dans Images apres l'avoir mise a la barre : elle doit y rester.
    # La barre le retrouve par « appParId », qui ne cherche que dans cette
    # liste — un fichier absent d'ici serait donc une epingle morte, cliquable
    # et sans effet. Le drapeau « bureau » dit au ciel de ne pas le dessiner.
    sur_le_bureau = set(f["id"] for f in fichiers)
    for f in fichiers:
        f["bureau"] = 1
    for e in (choisies or []):
        if not e.startswith("fichier:") or e in sur_le_bureau:
            continue
        chemin = e[len("fichier:"):]
        if not os.path.exists(chemin):
            continue
        try:
            etat = os.stat(chemin)
        except OSError:
            continue
        est_dossier = os.path.isdir(chemin)
        glyphe, ico = icone_de_fichier(chemin, est_dossier,
                                       int(etat.st_mtime), etat.st_size)
        fichiers.append({
            "id": e, "nom": os.path.basename(chemin), "src": "fichier",
            "ico": glyphe, "ep": 1, "epingle": 1, "img": _url_icone(ico),
            "txt": chemin, "compte": 0, "chemin": chemin,
            "dossier": 1 if est_dossier else 0, "bureau": 0,
        })

    ordre = sorted(apps.values(), key=lambda a: -usage.get(a["id"], 0))
    if choisies is None:
        epinglees = [a["id"] for a in ordre[:EPINGLEES_PAR_DEFAUT]]
    else:
        # On ne garde que celles qui existent encore : une application
        # desinstallee laisserait sinon un trou cliquable dans la barre.
        #
        # UN FICHIER PASSE PAR UNE AUTRE PORTE. Il n'est pas dans « apps » — il
        # n'a pas de .desktop — et le filtre le rejetait donc SANS UN MOT :
        # l'epingle etait ecrite dans epingles.json, la barre ne montrait rien,
        # et le geste paraissait ne pas marcher.
        vivants = set(f["id"] for f in fichiers)
        epinglees = [e for e in choisies if e in apps or e in vivants]

    etoiles = []
    for a in ordre:
        # L'ICONE EST UN CHEMIN DE FICHIER, PLUS UNE ADRESSE HTTP. Le pont
        # servait « /icone?id=... » parce qu'une page web ne peut pas lire
        # /usr/share/icons. Un client natif le peut : QML charge le fichier
        # directement, sans requete, sans serveur, sans copie en memoire.
        fichier_icone = chemin_icone(a.get("icone", ""))
        etoiles.append({
            "id": a["id"],
            "nom": a["nom"],
            "src": a["src"],
            "ico": a["ico"],
            "ep": 1 if usage.get(a["id"], 0) > 0 else 0,
            "epingle": 1 if a["id"] in epinglees else 0,
            "img": ("file://" + fichier_icone) if fichier_icone else "",
            "txt": a["txt"],
            "compte": usage.get(a["id"], 0),
        })
    return {
        "etoiles": etoiles,
        "usage": usage,
        "placees": placees,
        "epingles": epinglees,
        # LES FICHIERS SONT UNE CLEF A PART, ET C'EST DELIBERE. Les verser dans
        # « etoiles » les ferait monter dans le menu Demarrer, qui liste les
        # applications de la machine — un menu ou l'on trouverait les captures
        # d'ecran posees sur le bureau ne serait plus un menu.
        "fichiers": fichiers,
    }


# --------------------------------------------------------------------------
# Les reglages du bureau
# --------------------------------------------------------------------------
# LA PAGE LES GARDAIT DANS localStorage, C'EST-A-DIRE DANS LE PROFIL DE VIVALDI.
# Cela marchait, et personne ne s'en etait apercu : le fond d'ecran choisi
# survivait aux redemarrages parce que le navigateur gardait son profil. En
# passant a une coquille native, ne rien ecrire aurait fait REVENIR le fond par
# defaut a chaque connexion — une regression que l'utilisateur aurait vue le
# premier matin, et qu'aucun de ces fichiers n'aurait expliquee.

# « veille » est le mode de mise au repos des fenetres, ajoute le
# 2026-08-26 : « non », « reduire » ou « geler ». Il vit ici, avec les
# autres reglages du bureau, plutot que dans fenetres.py — un reglage
# range a cote du code qui l'utilise est un reglage que personne ne
# trouve. Voir /usr/lib/s/veille.py pour ce que « geler » veut dire.
REGLAGES_DEFAUT = {"fond": "nebuleuse", "noms": False, "veille": "geler"}


def charger_reglages():
    reglages = dict(REGLAGES_DEFAUT)
    try:
        with open(FICHIER_REGLAGES, "r", encoding="utf-8") as f:
            lus = json.load(f)
        if isinstance(lus, dict):
            # On ne retient que les cles connues : un fichier bricole a la main
            # ne doit pas pouvoir injecter n'importe quoi dans la scene.
            for cle in REGLAGES_DEFAUT:
                if cle in lus:
                    reglages[cle] = lus[cle]
    except (OSError, ValueError):
        pass
    return reglages


def sauver_reglage(cle, valeur):
    if cle not in REGLAGES_DEFAUT:
        return
    reglages = charger_reglages()
    reglages[cle] = valeur
    try:
        os.makedirs(ETAT, exist_ok=True)
        temporaire = FICHIER_REGLAGES + ".tmp"
        with open(temporaire, "w", encoding="utf-8") as f:
            json.dump(reglages, f)
        os.replace(temporaire, FICHIER_REGLAGES)
    except OSError as err:
        print("s-noyau : reglage non sauve : %s" % err, file=sys.stderr)


# --------------------------------------------------------------------------
# LES GESTES DE FICHIERS
# --------------------------------------------------------------------------
#
# ON N'EN ECRIT AUCUN. Copier, deplacer, mettre a la corbeille, ouvrir une
# boite de proprietes, compresser : KDE fait tout cela depuis vingt ans, et
# « kioclient » l'expose en ligne de commande. Reecrire ces gestes ici, ce
# serait refaire moins bien ce que l'amont maintient — la faute que ce depot a
# payee cinq jours sur « s-android ».
#
# CE QUI EST ECRIT ICI EST DONC UNIQUEMENT LA COUTURE : trouver l'outil, lui
# passer le bon chemin, et rendre une phrase que la coquille puisse afficher.

def _outil(nom):
    return chemin_executable(nom)


def _lancer_detache(argv):
    """Lance sans attendre, hors du groupe de processus de l'appelant.

    « start_new_session » n'est pas une precaution de style : un programme
    lance depuis un script meurt avec le groupe de processus de son lanceur.
    Ce depot l'a paye deux fois — le wineserver resident le 2026-08-26 a
    l'aube, PURPLE le meme jour en fin de journee.
    """
    try:
        subprocess.Popen(argv, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True, ""
    except OSError as err:
        return False, str(err)


def proprietes_fichier(chemin):
    """La vraie boite de proprietes de KDE, celle de Dolphin."""
    if not os.path.exists(chemin):
        return False, "ce fichier n'existe plus"
    outil = _outil("kioclient")
    if not outil:
        return False, "kioclient n'est pas sur cette machine"
    ok, err = _lancer_detache([outil, "openProperties", chemin])
    return (True, os.path.basename(chemin)) if ok else (False, err)


def corbeille(chemin):
    """Met a la corbeille — jamais « rm ».

    LA DIFFERENCE N'EST PAS COSMETIQUE. « rm » est definitif ; la corbeille est
    un geste qu'on peut defaire. Un bureau qui supprime pour de bon au clic
    droit est un bureau qu'on n'ose plus utiliser.
    """
    if not os.path.exists(chemin):
        return False, "ce fichier n'existe plus"
    outil = _outil("kioclient")
    if not outil:
        return False, "kioclient n'est pas sur cette machine"
    try:
        r = subprocess.run([outil, "move", chemin, "trash:/"],
                           capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as err:
        return False, "corbeille impossible : %s" % err
    if r.returncode != 0:
        # LA BRANCHE D'ECHEC MONTRE CE QUI S'EST PASSE AVANT DE CONCLURE. Ce
        # depot a paye deux fois le meme faux verdict le 2026-08-26 : un
        # message qui nommait UNE cause pour n'importe quel echec.
        detail = (r.stderr or r.stdout or "").strip().splitlines()
        return False, detail[-1][:120] if detail else "code %d" % r.returncode
    return True, os.path.basename(chemin)


def renommer(chemin, nouveau_nom):
    """Renomme dans le meme dossier. Le nouveau nom ne peut pas changer d'endroit."""
    if not os.path.exists(chemin):
        return False, "ce fichier n'existe plus"
    nouveau_nom = (nouveau_nom or "").strip()
    if not nouveau_nom:
        return False, "un nom vide n'est pas un nom"
    # UN NOM N'EST PAS UN CHEMIN. Sans ce controle, taper « ../ailleurs » dans
    # la boite de renommage DEPLACERAIT le fichier hors du bureau — un geste
    # que rien dans l'interface n'annonce.
    if "/" in nouveau_nom or nouveau_nom in (".", ".."):
        return False, "un nom ne peut pas contenir de barre oblique"
    cible = os.path.join(os.path.dirname(chemin), nouveau_nom)
    if os.path.exists(cible):
        return False, "%s existe deja" % nouveau_nom
    try:
        os.rename(chemin, cible)
    except OSError as err:
        return False, "renommage impossible : %s" % err
    return True, nouveau_nom


def compresser(chemins):
    """Ouvre Ark sur une archive a creer, avec les fichiers dedans.

    « --add-to » demande le nom de l'archive ; sans lui, « --add » demande a
    l'utilisateur ou la mettre, ce qui est exactement le comportement voulu
    pour un clic droit « Compresser… ».
    """
    chemins = [c for c in (chemins or []) if os.path.exists(c)]
    if not chemins:
        return False, "rien a compresser"
    outil = _outil("ark")
    if not outil:
        return False, "Ark n'est pas sur cette machine"
    ok, err = _lancer_detache([outil, "--add", "--changetofirstpath"] + chemins)
    return (True, "%d element(s)" % len(chemins)) if ok else (False, err)


def coller(source, dossier_cible, deplacer):
    """Copie ou deplace « source » dans « dossier_cible », par kioclient.

    LE GESTE LE PLUS COMMUN DE TOUT GESTIONNAIRE DE FICHIERS, ET IL N'AVAIT
    PAS DE PLACE ICI. Meme outil que corbeille() (« kioclient move »), la
    meme discipline : on ne reimplemente pas ce que l'amont maintient.
    « --interactive » laisse KDE poser sa propre boite de conflit si un nom
    existe deja a l'arrivee — meme raisonnement que proprietes_fichier() :
    on ne redevine pas la boite que Dolphin sait deja montrer.

    DETACHE, PAS ATTENDU — meme choix que compresser() et terminal_ici().
    Un fichier peut peser plusieurs gigaoctets, et le grand disque de ce
    projet est deja documente comme lent (plateau USB). Attendre la fin
    bloquerait le clic pour un temps qu'on ne connait pas d'avance. Le bureau
    se relit tout seul toutes les 15 secondes (voir le Timer de
    Constellation.qml) ; le fichier colle finira par y apparaitre sans qu'on
    ait rien a faire de plus ici.
    """
    if not os.path.exists(source):
        return False, "ce fichier n'existe plus"
    if not os.path.isdir(dossier_cible):
        return False, "le dossier de destination n'existe plus"
    outil = _outil("kioclient")
    if not outil:
        return False, "kioclient n'est pas sur cette machine"
    verbe = "move" if deplacer else "copy"
    ok, err = _lancer_detache([outil, "--interactive", verbe, source, dossier_cible])
    return (True, os.path.basename(source)) if ok else (False, err)


def terminal_ici(dossier):
    """Ouvre un terminal dans un dossier."""
    if not os.path.isdir(dossier):
        return False, "ce dossier n'existe plus"
    for nom, argv in (("konsole", ["--workdir", dossier]),
                      ("kgx", ["--working-directory", dossier]),
                      ("xterm", ["-e", "cd '%s' && $SHELL" % dossier])):
        outil = _outil(nom)
        if outil:
            ok, err = _lancer_detache([outil] + argv)
            return (True, os.path.basename(dossier) or "/") if ok else (False, err)
    return False, "aucun terminal sur cette machine"


def creer(dossier, nom, est_dossier):
    """Cree un dossier ou un fichier vide sur le bureau."""
    nom = (nom or "").strip()
    if not nom:
        return False, "un nom vide n'est pas un nom"
    if "/" in nom or nom in (".", ".."):
        return False, "un nom ne peut pas contenir de barre oblique"
    cible = os.path.join(dossier, nom)
    if os.path.exists(cible):
        return False, "%s existe deja" % nom
    try:
        if est_dossier:
            os.makedirs(cible)
        else:
            with open(cible, "x", encoding="utf-8"):
                pass
    except OSError as err:
        return False, "creation impossible : %s" % err
    return True, nom
