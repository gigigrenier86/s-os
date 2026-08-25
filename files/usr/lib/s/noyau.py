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


def dossiers_icones():
    """Ou chercher le fichier d'une icone, du plus grand au plus petit.

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
                chemin = os.path.join(base, taille, "apps")
                if os.path.isdir(chemin):
                    dossiers.append(chemin)
    for nu in ("/usr/share/pixmaps", os.path.join(maison, ".local/share/pixmaps")):
        if os.path.isdir(nu):
            dossiers.append(nu)
    return dossiers


def chemin_icone(nom):
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

    vu = _ICONES.get(nom)
    if vu is not None and (time.monotonic() - vu[1]) < _ICONES_TTL:
        if not vu[0] or os.path.isfile(vu[0]):
            return vu[0]

    trouve = ""
    for dossier in dossiers_icones():
        for ext in (".png", ".svg"):
            essai = os.path.join(dossier, nom + ext)
            if os.path.isfile(essai):
                trouve = essai
                break
        if trouve:
            break
    _ICONES[nom] = (trouve, time.monotonic())
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

    ordre = sorted(apps.values(), key=lambda a: -usage.get(a["id"], 0))
    if choisies is None:
        epinglees = [a["id"] for a in ordre[:EPINGLEES_PAR_DEFAUT]]
    else:
        # On ne garde que celles qui existent encore : une application
        # desinstallee laisserait sinon un trou cliquable dans la barre.
        epinglees = [e for e in choisies if e in apps]

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

REGLAGES_DEFAUT = {"fond": "nebuleuse", "noms": False}


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
