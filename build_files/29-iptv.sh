#!/usr/bin/bash
set -euxo pipefail
source /ctx/build_files/lib-opt.sh

# ==========================================================================
# Lecteur IPTV natif — mpv, jamais reimplemente
# ==========================================================================
#
# Demande de l'utilisateur : un lecteur IPTV NATIF pour S — pas un service
# qui fournirait des chaines (ce que ce depot refuserait sans provenance
# verifiable des chaines), un LECTEUR : l'utilisateur apporte sa propre
# playlist M3U ou ses identifiants Xtream Codes, exactement comme il le fait
# deja avec Ibo Player Pro et CAP Player, sous Wine (voir windows.sh) — sauf
# que celui-ci ne depend d'aucun prefixe, demarre en une seconde, et vit
# dans le meme langage visuel que le reste de S.
#
# mpv (paquet Fedora officiel, signe) fait tout le travail de decodage et
# de rendu : HLS, TS brut, RTMP, multicast — tout ce qu'un flux IPTV peut
# prendre comme forme. On ne reimplemente pas ce qu'ffmpeg/mpv maintiennent
# deja, et rien de plus robuste n'existe pour cet usage sur Linux. Il tourne
# dans sa propre fenetre, geree comme n'importe quelle autre par
# fenetres.js/fenetres.py — aucune couture cote compositeur a poser.
dnf5 install -y --setopt=install_weak_deps=False mpv

# ---------------------------------------------------------- Verification --
# Regle 2 du carnet : un paquet pose hors de /usr et /etc livrerait une
# image creuse sans que rien ne le dise.
if rpm -ql mpv 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : mpv a pose des fichiers hors de /usr et /etc." >&2
    exit 1
fi

# Rapport non bloquant : voir la note de 26-outils.sh.
echo "Lecteur IPTV : mpv $(rpm -q mpv --qf '%{VERSION}') pose pour s-iptv" || true
