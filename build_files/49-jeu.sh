#!/usr/bin/bash
set -euxo pipefail

# ==========================================================================
# GameMode — jamais reimplemente, seulement pose
# ==========================================================================
#
# DEMANDE DE L'UTILISATEUR LE 2026-09-01, POUR LE MODE « Jeu » DE LA BARRE
# LATERALE (/usr/lib/s/reglages.py::_regler_mode). Le mode « Jeu » bascule
# deja tuned-adm, la frequence GPU et les effets kwin — GameMode (Feral
# Interactive) est le complement qui manquait : une bibliotheque
# (libgamemodeauto.so) que Proton et la plupart des jeux Steam chargent
# DEJA tout seuls des qu'elle existe sur le systeme, sans qu'aucun geste de
# S n'ait besoin de la piloter. On ne reimplemente rien — on pose l'outil
# que l'amont (Feral, puis Fedora) maintient, et rien de plus.
#
# VERIFIE AVANT D'ECRIRE : « dnf5 list gamemode » le donne dans les depots
# Fedora officiels (fedora), licence BSD-3-Clause, aucun COPR. Le paquet
# pose un service utilisateur DBus-active (gamemoded.service), jamais lance
# en permanence — il ne consomme rien tant qu'aucun jeu ne le sollicite.
dnf5 install -y --setopt=install_weak_deps=False gamemode

# ---------------------------------------------------------- Verification --
if rpm -ql gamemode 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : GameMode a pose des fichiers hors de /usr et /etc." >&2
    exit 1
fi
[[ -x /usr/bin/gamemoderun ]] \
    || { echo "ECHEC : /usr/bin/gamemoderun absent apres installation." >&2; exit 1; }

echo "GameMode pose :"
rpm -q gamemode | sed 's/^/  /'
