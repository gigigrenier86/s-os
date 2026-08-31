#!/usr/bin/bash
set -euxo pipefail

# ==========================================================================
# L'egaliseur — EasyEffects, jamais reimplemente
# ==========================================================================
#
# DEMANDE DE L'UTILISATEUR LE 2026-08-30, POUR L'ETOILE « Egaliseur » DE LA
# BARRE LATERALE. Le format « etoile » de cette barre (bascule/glissiere/
# choix) ne se prete pas a un vrai egaliseur a plusieurs bandes — personne ne
# le reimplemente ici : EasyEffects, l'outil PipeWire officiel de Fedora,
# EST cet egaliseur, entretenu par l'amont. L'etoile ne fait que le piloter,
# voir /usr/lib/s/reglages.py.
#
# VERIFIE AVANT D'ECRIRE : « dnf5 info easyeffects » le donne dans les depots
# Fedora officiels (updates/updates-archive), pas un COPR, licence GPL-3.0,
# 2,8 Mio a telecharger. Aucun detour /opt : ses fichiers visent tous /usr.
dnf5 install -y --setopt=install_weak_deps=False easyeffects

# ---------------------------------------------------------- Verification --
if rpm -ql easyeffects 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : EasyEffects a pose des fichiers hors de /usr et /etc." >&2
    exit 1
fi
[[ -x /usr/bin/easyeffects ]] \
    || { echo "ECHEC : /usr/bin/easyeffects absent apres installation." >&2; exit 1; }

echo "EasyEffects pose :"
rpm -q easyeffects | sed 's/^/  /'
