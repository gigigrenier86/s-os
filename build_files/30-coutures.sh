#!/usr/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------------
# Les coutures — le coeur du projet, et il est encore vide
# --------------------------------------------------------------------------
# C'est ici que vivra ce qui n'existe nulle part ailleurs :
#
#   1. Un seul menu — les .desktop de Waydroid et de Wine, ranges ensemble
#      deliberement plutot que juxtaposes par hasard.
#   2. Un seul dossier personnel — le meme ~/Documents vu depuis Z:\ sous Wine
#      et depuis /storage/emulated/0 sous Android, par montages lies.
#   3. Un seul presse-papiers — Wine le fait deja, Waydroid mal ; c'est du vrai
#      developpement.
#   4. Un seul jeu d'associations — un .apk s'installe, un .exe se propose,
#      par xdg-mime.
#
# Rien de tout cela au jalon 1 : ce jalon ne prouve que la chaine de
# fabrication. Ecrire les coutures avant d'avoir vu l'image demarrer serait
# ecrire a l'aveugle.
echo "Coutures : rien a poser pour l'instant — voir le jalon 5 du plan."
