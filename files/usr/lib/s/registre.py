#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Lire le registre d'un prefixe Wine — les protocoles, et qui les ouvre.

POURQUOI CE FICHIER EST EN PYTHON ET PAS EN awk. Le registre de Wine est un
fichier texte, mais son echappement est retors et deux details l'ont rendu
illisible a la premiere tentative, tous deux mesures sur le prefixe reel :

  1. L'EN-TETE DE BLOC PORTE UN HORODATAGE APRES LE CROCHET :
         [Software\\\\Classes\\\\cursor\\\\shell\\\\open\\\\command] 1787620468
     Comparer la ligne entiere a « [...] » ne trouve donc jamais rien.

  2. LES ANTISLASHS SONT DOUBLES DANS LES NOMS DE CLE, mais ceux des VALEURS
     suivent les regles de C :
         @="\\"C:\\\\Program Files\\\\cursor\\\\Cursor.exe\\" --open-url -- \\"%1\\""
     Il faut donc deux decodages differents dans le meme fichier.

CE QUI DISTINGUE UN PROTOCOLE D'UN TYPE DE FICHIER, et c'est le seul critere
fiable : un protocole porte « "URL Protocol"="" » dans son bloc. Cursor
enregistre 1 protocole et plus de deux cents types de fichiers ; sans ce
critere, on declarerait « Cursor.asp » comme un protocole reseau.
"""

import os
import re
import sys

# Les protocoles que Windows connait nativement. Les reprendre volerait au
# navigateur de Linux tous les liens de la machine.
NATIFS = {
    "http", "https", "ftp", "ftps", "file", "mailto", "news", "nntp", "snews",
    "about", "javascript", "res", "shell", "search-ms", "ms-windows-store",
    "microsoft-edge", "callto", "tel", "sms", "ldap", "gopher", "wais",
}

_ENTETE = re.compile(r"^\[([^\]]+)\]")


def _decloisonner(nom):
    """« Software\\\\Classes\\\\cursor » -> « Software\\Classes\\cursor »."""
    return nom.replace("\\\\", "\\")


def _valeur(brut):
    """Decoder une valeur entre guillemets, echappement a la C.

    ECRIT A LA MAIN PLUTOT QU'AVEC codecs.escape_decode, ET C'EST UNE
    CORRECTION MESUREE : cette fonction leve « Trailing \\ in string » sur au
    moins une valeur du prefixe reel, ce qui faisait tomber toute la lecture du
    registre pour un seul enregistrement malforme. Un analyseur de registre ne
    doit jamais mourir sur une valeur : il doit la rendre du mieux qu'il peut
    et continuer.
    """
    brut = brut.strip()
    if len(brut) >= 2 and brut[0] == '"' and brut[-1] == '"':
        brut = brut[1:-1]
    sortie = []
    i = 0
    n = len(brut)
    while i < n:
        c = brut[i]
        if c != "\\":
            sortie.append(c)
            i += 1
            continue
        # Un antislash en toute fin de chaine n'echappe rien : on le garde tel
        # quel plutot que de refuser la ligne entiere.
        if i + 1 >= n:
            sortie.append("\\")
            break
        suivant = brut[i + 1]
        if suivant == "x" and i + 3 < n:
            try:
                sortie.append(chr(int(brut[i + 2:i + 4], 16)))
                i += 4
                continue
            except ValueError:
                pass
        sortie.append({"n": "\n", "r": "\r", "t": "\t",
                       "0": "\0"}.get(suivant, suivant))
        i += 2
    return "".join(sortie)


def blocs(prefixe):
    """Tous les blocs du registre : {nom de cle: {nom de valeur: valeur}}."""
    trouve = {}
    for nom_fichier in ("user.reg", "system.reg", "userdef.reg"):
        chemin = os.path.join(prefixe, nom_fichier)
        if not os.path.isfile(chemin):
            continue
        cle = None
        with open(chemin, "r", encoding="utf-8", errors="replace") as f:
            for ligne in f:
                ligne = ligne.rstrip("\n")
                m = _ENTETE.match(ligne)
                if m:
                    cle = _decloisonner(m.group(1))
                    trouve.setdefault(cle, {})
                    continue
                if cle is None or not ligne or ligne.startswith("#"):
                    continue
                if ligne.startswith("@="):
                    trouve[cle]["@"] = _valeur(ligne[2:])
                elif ligne.startswith('"'):
                    nom, _, val = ligne.partition("=")
                    trouve[cle][_valeur(nom)] = _valeur(val)
    return trouve


def protocoles(prefixe):
    """Les protocoles enregistres, avec la commande qui les ouvre.

    Rend {scheme: commande}, ou la commande porte encore son « %1 ».
    """
    tout = blocs(prefixe)
    sortie = {}
    for cle, valeurs in tout.items():
        if not cle.startswith("Software\\Classes\\"):
            continue
        reste = cle[len("Software\\Classes\\"):]
        if "\\" in reste:
            continue
        # LE CRITERE : « URL Protocol » present, meme vide.
        if "URL Protocol" not in valeurs:
            continue
        scheme = reste.lower()
        if scheme in NATIFS:
            continue
        cmd = tout.get(cle + "\\shell\\open\\command", {}).get("@")
        if cmd:
            sortie[scheme] = cmd
    return sortie


if __name__ == "__main__":
    pfx = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("WINEPREFIX", "")
    trouves = protocoles(pfx)
    if len(sys.argv) > 1 and sys.argv[1] == "--liste":
        for s in sorted(trouves):
            print(s)
    elif len(sys.argv) > 1 and sys.argv[1] == "--commande":
        scheme = os.environ.get("S_SCHEME", "")
        cmd = trouves.get(scheme.lower())
        if not cmd:
            sys.exit(1)
        print(cmd)
    else:
        for s, c in sorted(trouves.items()):
            print("%s\t%s" % (s, c))
