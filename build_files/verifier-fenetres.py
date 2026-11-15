#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Jouer le debranchement d'ecran du rapporteur, pendant la construction.

POURQUOI CE CONTROLE EXISTE. fenetres.js ne tourne que DANS le compositeur :
une faute dedans ne se verrait qu'au prochain debranchement de HDMI, chez
l'utilisateur — le bureau redevenu une fenetre, la barre posee au milieu de
l'ecran. Node est dans l'image (26-outils.sh) : on peut donc charger le script
dans un « kwin de carton » (banc-fenetres.js), lui jouer « screensChanged » et
verifier que la coquille est rattrapee — plein ecran rendu au bureau, barre et
barre laterale reposees aux bords de l'ecran restant, bulle visible replacee,
vraies fenetres intouchees, et pont prevenu de reposer les regles.

LE CHEMIN S'AFFICHE, ET CE N'EST PAS DECORATIF. Le defaut vise
/usr/lib/s/fenetres.js, ce qui est juste PENDANT la construction — le COPY de
« files/ » a deja eu lieu. Lance a la main sur la machine, sans argument, il
verifierait donc l'IMAGE INSTALLEE et non le depot qu'on vient de modifier —
le meme piege deja documente dans verifier-constellation.py.
"""

import os
import subprocess
import sys

CHEMIN = sys.argv[1] if len(sys.argv) > 1 else "/usr/lib/s/fenetres.js"
BANC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "banc-fenetres.js")

print("  rapporteur verifie : " + CHEMIN)

# LA SYNTAXE D'ABORD, LE CONTRAT ENSUITE. Une faute de syntaxe tuerait le
# script kwin entier a son chargement — barre vide, sans aucun message. Node
# la voit sans avoir besoin de kwin.
controle = subprocess.run(
    ["node", "--check", CHEMIN], stdout=subprocess.DEVNULL,
    stderr=subprocess.PIPE)
if controle.returncode != 0:
    print("ECHEC : fenetres.js ne tient pas debout — "
          + controle.stderr.decode("utf-8", "replace").strip(),
          file=sys.stderr)
    sys.exit(1)

# LE BANC JOUE LE DEBRANCHEMENT, DEUX KWIN : un qui obeit a « fullScreen »,
# un qui ne l'offre pas. Dans les deux cas, la coquille doit etre rattrapee.
banc = subprocess.run(["node", BANC, CHEMIN], stderr=subprocess.PIPE)
if banc.returncode != 0:
    print(banc.stderr.decode("utf-8", "replace"), file=sys.stderr)
    sys.exit(1)

print("  rapporteur     : le debranchement d'ecran est rattrape")
