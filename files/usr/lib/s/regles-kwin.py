#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Les regles kwin dont S a besoin pour poser ses deux fenetres de service.

POURQUOI DES REGLES, ET PAS DES COORDONNEES DANS LE QML. Un client Wayland ne
se place pas lui-meme : le protocole ne le permet pas, et le compositeur
decide. Mesure du 2026-08-25 : une fenetre demandant x=1516 y=24 s'est affichee
AU CENTRE de l'ecran. Ce n'est pas un defaut de Qt.

POURQUOI DANS ~/.config ET NON DANS L'IMAGE, ce qui contredit en apparence la
regle « ce qui doit tenir va dans l'image ». KConfig cascade : le fichier de
l'utilisateur l'emporte sur celui de /etc/xdg. Or « [General] rules= » existe
deja ici, vide, et kwin ne lit QUE les groupes nommes dans cette liste. Une
regle livree dans l'image serait donc masquee par une ligne vide du dossier
personnel.

LE CONTOURNEMENT EST DONC DANS L'AUTRE SENS : le code qui pose les regles, lui,
vit dans l'image. Il tourne a chaque ouverture de session, il se repare tout
seul si quelqu'un efface le fichier, et il n'ecrase jamais les regles que
l'utilisateur aurait ajoutees.

ET IL EST APPELE PAR CONSTELLATION, PAS PAR LA COQUILLE, parce que les deux
regles ont besoin de la taille de l'ecran — que seul un programme connecte au
compositeur connait. La deviner en lisant kscreen-doctor serait une seconde
source de verite pour une chose que Qt sait deja.
"""

import configparser
import io
import os
import subprocess
import sys


# Les titres sont des CLEFS, pas des decorations : la barre, la bulle et le
# bureau appartiennent tous a s-constellation et portent donc la meme classe.
# Le titre est le seul moyen de les distinguer, et il doit correspondre mot
# pour mot au « title: » de Bulle.qml et de Barre.qml.
TITRE_BULLE = "S - notification"
TITRE_BARRE = "S - barre"

LARGEUR_BULLE = 380
MARGE_BULLE = 24
HAUTEUR_BARRE = 52

COMMUN = {
    "skiptaskbar": "true",
    "skiptaskbarrule": "2",
    "skippager": "true",
    "skippagerrule": "2",
    "skipswitcher": "true",
    "skipswitcherrule": "2",
    "above": "true",
    "aboverule": "2",
    "positionrule": "2",
    "types": "1",
    "wmclass": "s-constellation",
    "wmclasscomplete": "false",
    "wmclassmatch": "1",
    "titlematch": "1",
}


def fichier_regles():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "kwinrulesrc")


def regles(largeur, hauteur):
    """Les deux groupes, calcules pour cet ecran-ci."""
    bulle = dict(COMMUN)
    bulle.update({
        "Description": "S - la bulle de notification, en haut a droite",
        "title": TITRE_BULLE,
        "position": "%d,%d" % (max(0, largeur - LARGEUR_BULLE - MARGE_BULLE),
                               MARGE_BULLE),
    })

    barre = dict(COMMUN)
    barre.update({
        "Description": "S - la barre des taches, en bas",
        "title": TITRE_BARRE,
        "position": "0,%d" % max(0, hauteur - HAUTEUR_BARRE),
        # LA TAILLE EST FORCEE, ET C'EST NECESSAIRE : la barre demande la
        # largeur de l'ecran, mais kwin peut la retailler a l'ouverture si une
        # autre regle ou un souvenir de geometrie traine. Une barre des taches
        # de 800 pixels de large collee a gauche a l'air d'un bogue.
        "size": "%d,%d" % (largeur, HAUTEUR_BARRE),
        "sizerule": "2",
    })
    return {"s-bulle": bulle, "s-barre": barre}


def poser(largeur, hauteur):
    """Ecrit les regles si elles manquent ou ont change. Rend (change, ennui)."""
    chemin = fichier_regles()
    lecteur = configparser.ConfigParser(interpolation=None, strict=False)
    # KConfig distingue les majuscules ; configparser les ecrase par defaut.
    lecteur.optionxform = str
    if os.path.isfile(chemin):
        try:
            lecteur.read(chemin, encoding="utf-8")
        except configparser.Error as err:
            # ON NE REECRIT PAS UN FICHIER QU'ON NE SAIT PAS LIRE. Perdre les
            # regles de l'utilisateur pour poser les notres serait un mauvais
            # marche.
            return False, "kwinrulesrc illisible (%s) — regles non posees" % err

    if not lecteur.has_section("General"):
        lecteur.add_section("General")
    liste = [n for n in lecteur.get("General", "rules", fallback="").split(",")
             if n]

    voulues = regles(largeur, hauteur)
    change = False
    for groupe, contenu in voulues.items():
        deja = (groupe in liste
                and lecteur.has_section(groupe)
                and all(lecteur.get(groupe, c, fallback=None) == v
                        for c, v in contenu.items()))
        if deja:
            continue
        change = True
        if groupe not in liste:
            liste.append(groupe)
        if not lecteur.has_section(groupe):
            lecteur.add_section(groupe)
        for clef, valeur in contenu.items():
            lecteur.set(groupe, clef, valeur)

    if not change:
        return False, None

    lecteur.set("General", "rules", ",".join(liste))
    lecteur.set("General", "count", str(len(liste)))

    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    tampon = io.StringIO()
    lecteur.write(tampon, space_around_delimiters=False)
    # Ecriture puis remplacement : une session qui se ferme au mauvais moment
    # ne doit pas laisser un fichier de regles a moitie ecrit.
    provisoire = chemin + ".s-nouveau"
    with io.open(provisoire, "w", encoding="utf-8") as sortie:
        sortie.write(tampon.getvalue())
    os.replace(provisoire, chemin)
    return True, None


def relire():
    """Demande a kwin de relire ses regles, sans redemarrer la session."""
    try:
        subprocess.run(
            ["busctl", "--user", "call", "org.kde.KWin", "/KWin",
             "org.kde.KWin", "reconfigure"],
            timeout=10, check=False,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        # kwin n'est pas encore la : il lira le fichier en demarrant, ce qui
        # est le cas normal a l'ouverture de session.
        pass


def appliquer(largeur, hauteur):
    """Pose et fait relire. Rend une phrase a journaliser, ou None."""
    change, ennui = poser(largeur, hauteur)
    if ennui:
        return ennui
    if change:
        relire()
        return "regles kwin posees pour un ecran de %dx%d" % (largeur, hauteur)
    return None


if __name__ == "__main__":
    # En ligne de commande, on prend la taille en arguments : c'est le seul
    # moyen d'essayer ce fichier sans ouvrir une session.
    l = int(sys.argv[1]) if len(sys.argv) > 1 else 1920
    h = int(sys.argv[2]) if len(sys.argv) > 2 else 1080
    phrase = appliquer(l, h)
    if phrase:
        print("regles-kwin : " + phrase, file=sys.stderr)
