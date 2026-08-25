#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Pose la regle kwin qui place la bulle de notification en haut a droite.

POURQUOI UNE REGLE, ET PAS DES COORDONNEES DANS LE QML. Un client Wayland ne
se place pas lui-meme : le protocole ne le permet pas, et le compositeur
decide. Mesure du 2026-08-25 : une fenetre demandant x=1516 y=24 s'est
affichee AU CENTRE de l'ecran. Ce n'est pas un defaut de Qt.

POURQUOI DANS ~/.config ET NON DANS L'IMAGE, ce qui contredit en apparence la
regle « ce qui doit tenir va dans l'image ». KConfig cascade : le fichier de
l'utilisateur l'emporte sur celui de /etc/xdg. Or « [General] rules= » existe
deja ici, vide, et kwin ne lit QUE les groupes nommes dans cette liste. Une
regle livree dans l'image serait donc masquee par une ligne vide du dossier
personnel.

LE CONTOURNEMENT EST DONC DANS L'AUTRE SENS : le code qui pose la regle, lui,
vit dans l'image. Il tourne a chaque ouverture de session, il se repare tout
seul si quelqu'un efface le fichier, et il ne detruit rien de ce que
l'utilisateur aurait ajoute — sa propre liste de regles est preservee, la
notre est seulement ajoutee si elle manque.
"""

import configparser
import io
import os
import subprocess
import sys


GROUPE = "s-bulle"
# Le titre est la seule chose qui distingue la bulle du bureau : les deux
# fenetres appartiennent a s-constellation et portent donc la meme classe.
# Il doit correspondre MOT POUR MOT au « title: » de Bulle.qml.
TITRE = "S - notification"

REGLE = {
    "Description": "S - la bulle de notification, en haut a droite",
    "above": "true",
    "aboverule": "2",
    "position": "1516,24",
    "positionrule": "2",
    "skiptaskbar": "true",
    "skiptaskbarrule": "2",
    "skippager": "true",
    "skippagerrule": "2",
    "skipswitcher": "true",
    "skipswitcherrule": "2",
    "title": TITRE,
    "titlematch": "1",
    "types": "1",
    "wmclass": "s-constellation",
    "wmclasscomplete": "false",
    "wmclassmatch": "1",
}


def fichier_regles():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "kwinrulesrc")


def poser():
    chemin = fichier_regles()
    lecteur = configparser.ConfigParser(interpolation=None, strict=False)
    # KConfig distingue les majuscules ; configparser les ecrase par defaut.
    lecteur.optionxform = str
    if os.path.isfile(chemin):
        try:
            lecteur.read(chemin, encoding="utf-8")
        except configparser.Error as err:
            # ON NE REECRIT PAS UN FICHIER QU'ON NE SAIT PAS LIRE. Perdre les
            # regles de l'utilisateur pour poser la notre serait un mauvais
            # marche.
            return False, "kwinrulesrc illisible (%s) — regle non posee" % err

    if not lecteur.has_section("General"):
        lecteur.add_section("General")

    liste = [n for n in lecteur.get("General", "rules", fallback="").split(",")
             if n]

    inchange = (GROUPE in liste
                and lecteur.has_section(GROUPE)
                and all(lecteur.get(GROUPE, c, fallback=None) == v
                        for c, v in REGLE.items()))
    if inchange:
        return False, None

    if GROUPE not in liste:
        liste.append(GROUPE)
    lecteur.set("General", "rules", ",".join(liste))
    lecteur.set("General", "count", str(len(liste)))

    if not lecteur.has_section(GROUPE):
        lecteur.add_section(GROUPE)
    for clef, valeur in REGLE.items():
        lecteur.set(GROUPE, clef, valeur)

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


if __name__ == "__main__":
    change, ennui = poser()
    if ennui:
        print("regle-bulle : " + ennui, file=sys.stderr)
        sys.exit(1)
    if change:
        relire()
        print("regle-bulle : la bulle est placee en haut a droite",
              file=sys.stderr)
    sys.exit(0)
