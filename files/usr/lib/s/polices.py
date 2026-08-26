#!/usr/bin/python3
"""Lire le nom sous lequel Windows enregistre une police.

POURQUOI CE FICHIER EXISTE, ET CE QU'IL REPARE.

Le 2026-08-26, 26 polices ont ete copiees du Windows de la machine vers
C:\\windows\\Fonts du prefixe. A l'ecran : aucun changement, les icones sont
restees des carres vides. « wineboot -u » n'y a rien change non plus — 549
entrees de police au registre avant, 549 apres.

Copier le fichier ne suffit pas. Windows ne trouve une police que si elle est
DECLAREE au registre, sous son nom de famille, dans deux cles :

    HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts
    HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Fonts
        "Segoe Fluent Icons (TrueType)" = "SegoeIcons.ttf"

C'est exactement ce que fait winetricks dans « w_register_font », et c'est de
la que vient cette forme — on ne reimplemente pas ce que l'amont maintient, on
le lit.

RESTE LE VRAI PROBLEME, ET IL EST ICI : ce nom ne se DEDUIT PAS du nom du
fichier. « SegoeIcons.ttf » se declare « Segoe Fluent Icons », « segmdl2.ttf »
se declare « Segoe MDL2 Assets », « seguisb.ttf » se declare « Segoe UI
Semibold ». Aucune regle ne relie les deux. Le nom est dans la table « name »
du fichier, et il faut aller l'y chercher.

On ne prend pas une bibliotheque pour ca : lire une table « name » tient en
trente lignes, et une dependance de plus dans une image immuable se paie a
chaque reconstruction.
"""
import struct
import sys

# Les deux enregistrements qui nous interessent dans la table « name ».
FAMILLE = 1
SOUS_FAMILLE = 2


def _lire_table_name(donnees, decalage):
    """Rend {(nameID): texte} pour la table name situee a ce decalage."""
    fmt, nb, decalage_chaines = struct.unpack(">HHH", donnees[decalage:decalage + 6])
    noms = {}
    for i in range(nb):
        base = decalage + 6 + i * 12
        plateforme, encodage, langue, ident, longueur, pos = struct.unpack(
            ">HHHHHH", donnees[base:base + 12])
        brut = donnees[decalage + decalage_chaines + pos:
                       decalage + decalage_chaines + pos + longueur]
        try:
            # Plateforme 3 = Windows, toujours en UTF-16BE. Plateforme 1 =
            # Macintosh, en MacRoman. On prefere Windows/anglais quand il existe.
            texte = brut.decode("utf-16-be" if plateforme == 3 else "latin-1")
        except (UnicodeDecodeError, ValueError):
            continue
        if not texte:
            continue
        priorite = (plateforme == 3, langue == 0x409)
        precedent = noms.get(ident)
        if precedent is None or priorite > precedent[0]:
            noms[ident] = (priorite, texte)
    return {k: v[1] for k, v in noms.items()}


def _faces(donnees):
    """Rend la liste des decalages de table name — plusieurs pour un .ttc."""
    if donnees[:4] == b"ttcf":
        nb = struct.unpack(">I", donnees[8:12])[0]
        debuts = struct.unpack(">%dI" % nb, donnees[12:12 + 4 * nb])
    else:
        debuts = (0,)
    sorties = []
    for debut in debuts:
        nb_tables = struct.unpack(">H", donnees[debut + 4:debut + 6])[0]
        for i in range(nb_tables):
            base = debut + 12 + i * 16
            tag = donnees[base:base + 4]
            if tag == b"name":
                sorties.append(struct.unpack(">I", donnees[base + 8:base + 12])[0])
                break
    return sorties


def nom_windows(chemin):
    """Le nom exact sous lequel Windows declare cette police, sans le suffixe.

    Regle de Windows : le style « Regular » ne s'ecrit pas. « Segoe UI » et non
    « Segoe UI Regular » ; mais « Segoe UI Bold » avec son style.
    """
    with open(chemin, "rb") as f:
        donnees = f.read()
    resultats = []
    for decalage in _faces(donnees):
        noms = _lire_table_name(donnees, decalage)
        famille = noms.get(FAMILLE)
        if not famille:
            continue
        style = (noms.get(SOUS_FAMILLE) or "Regular").strip()
        if style.lower() in ("regular", "normal", "book", ""):
            resultats.append(famille.strip())
        else:
            resultats.append("%s %s" % (famille.strip(), style))
    return resultats


if __name__ == "__main__":
    for chemin in sys.argv[1:]:
        try:
            for nom in nom_windows(chemin):
                print("%s\t%s" % (nom, chemin.rsplit("/", 1)[-1]))
        except (OSError, struct.error, IndexError):
            # Une police illisible ne doit pas faire echouer l'emprunt entier :
            # on la saute, les autres valent toujours d'etre posees.
            continue
