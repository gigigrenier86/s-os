#!/usr/bin/bash
set -euxo pipefail
source /ctx/build_files/lib-opt.sh

# ==========================================================================
# Les applications : emulation et visioconference
# ==========================================================================

# ------------------------------------------------------------- RetroArch --
# CORRECTION d'une erreur commise plus tot : RetroArch n'est PAS dans RPM
# Fusion, il est dans les depots FEDORA officiels — verifie le 2026-08-20 sur
# le systeme installe, « dnf5 list --available retroarch » rend 1.22.0-20.fc44.
# Ma verification precedente avait ete mal lue, la sortie etant coupee.
#
# Il ne pose aucun fichier hors /usr et /etc : aucun detour ostree.
#
# « install_weak_deps=False » n'est pas cosmetique : les Recommends de
# retroarch tirent les quatorze coeurs, les assets, la base et les filtres
# d'un seul coup. On choisit plutot que de subir.
dnf5 install -y --setopt=install_weak_deps=False \
    retroarch retroarch-assets retroarch-filters

# Les quatorze coeurs qui existent VRAIMENT, releves un a un dans les depots.
# Cinq noms que j'avais supposes n'existent nulle part : libretro-snes9x,
# libretro-beetle-psx, libretro-genesis-plus-gx, libretro-mupen64plus et
# libretro-flycast. Le SNES est couvert par bsnes-mercury, la PS1 par
# pcsx-rearmed ; Mega Drive, N64 et Dreamcast ne le sont par aucun paquet.
dnf5 install -y --setopt=install_weak_deps=False \
    libretro-beetle-ngp \
    libretro-beetle-pce-fast \
    libretro-beetle-vb \
    libretro-beetle-wswan \
    libretro-bsnes-mercury \
    libretro-desmume2015 \
    libretro-gambatte \
    libretro-gw \
    libretro-handy \
    libretro-mgba \
    libretro-nestopia \
    libretro-pcsx-rearmed \
    libretro-prosystem \
    libretro-stella2014

# « retroarch-database » est volontairement absent : 290 Mio pour le seul
# scan de contenu. Il s'ajoute apres coup si le besoin s'en fait sentir.
#
# A SAVOIR, et ce n'est pas un defaut de S : la construction Fedora desactive
# l'acces reseau, donc le telechargeur de coeurs interne est inerte. C'est
# pourquoi les coeurs sont poses ici, en paquets.

# ------------------------------------------------------------------ Zoom --
# Zoom ne publie pas de depot : un RPM direct, et la quasi-totalite de ses
# fichiers visent /opt/zoom. C'est le seul de tous les logiciels de cette
# image a exiger le detour complet de lib-opt.sh.
rpm --import https://zoom.us/linux/download/pubkey

opt_preparer
dnf5 install -y https://zoom.us/client/latest/zoom_x86_64.rpm
opt_ranger zoom
opt_restaurer

# Un lien direct vers le lanceur, pour que Zoom demarre meme si
# systemd-tmpfiles n'a pas encore refait le pont.
if [[ -x /usr/lib/opt/zoom/ZoomLauncher ]]; then
    ln -sfn /usr/lib/opt/zoom/ZoomLauncher /usr/bin/zoom
fi

# ---------------------------------------------------------- Verification --
if rpm -ql retroarch retroarch-assets retroarch-filters 2>/dev/null \
   | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : RetroArch a pose des fichiers hors de /usr et /etc." >&2
    exit 1
fi

manque=0
[[ -x /usr/bin/retroarch ]]           || { echo "ABSENT : /usr/bin/retroarch" >&2; manque=1; }
[[ -d /usr/lib/opt/zoom ]]            || { echo "ABSENT : /usr/lib/opt/zoom" >&2; ls -la /usr/lib/opt/ >&2 || true; manque=1; }
[[ -f /usr/lib/tmpfiles.d/s-opt-zoom.conf ]] || { echo "ABSENT : le pont tmpfiles de Zoom" >&2; manque=1; }
[[ "$manque" -eq 0 ]] || exit 1

echo "Applications posees :"
/usr/bin/retroarch --version 2>&1 | head -1 | sed 's/^/  RetroArch  /'
echo "  coeurs     $(ls /usr/lib64/libretro/*.so 2>/dev/null | wc -l) fichiers dans /usr/lib64/libretro"
echo "  Zoom       $(du -sh /usr/lib/opt/zoom 2>/dev/null | cut -f1) dans /usr/lib/opt/zoom"
