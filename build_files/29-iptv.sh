#!/usr/bin/bash
set -euxo pipefail
source /ctx/build_files/lib-opt.sh

# ==========================================================================
# Lecteur IPTV natif — VLC, jamais reimplemente
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
# VLC (paquet Fedora officiel, signe — mesure : vlc-libs est deja dans la
# base, tire par phonon pour l'audio KDE, donc le moteur est la ; on ajoute
# l'interface GUI) fait le decodage et le rendu : HLS, TS brut, RTMP,
# multicast. mpv, plus leger, a ete REMPLACE PAR VLC sur demande explicite de
# l'utilisateur le 2026-10-23, malgre son poids superieur — decision assumee.
dnf5 install -y --setopt=install_weak_deps=False vlc

# ---------------------------------------------------------- Verification --
# Regle 2 du carnet : un paquet pose hors de /usr et /etc livrerait une
# image creuse sans que rien ne le dise.
if rpm -ql vlc 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : vlc a pose des fichiers hors de /usr et /etc." >&2
    exit 1
fi

# Rapport non bloquant : voir la note de 26-outils.sh.
echo "Lecteur IPTV : vlc $(rpm -q vlc --qf '%{VERSION}') pose pour s-iptv" || true
