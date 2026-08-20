#!/usr/bin/bash
set -euxo pipefail
source /ctx/build_files/lib-opt.sh

# ==========================================================================
# Les applications : visioconference et emulation
# ==========================================================================

# ------------------------------------------------------------- RetroArch --
# RetroArch n'est PAS dans les depots Fedora — verifie le 2026-08-20 sur le
# systeme installe, « dnf5 info retroarch » ne rend rien. Il vient de RPM
# Fusion Free.
#
# Le paquet « release » est installe sans verification de signature parce
# qu'il EST le porteur de la cle : c'est l'amorcage habituel et documente de
# RPM Fusion. Tout ce qui vient ensuite est verifie contre cette cle.
if [[ ! -f /etc/yum.repos.d/rpmfusion-free.repo ]]; then
    dnf5 install -y --nogpgcheck \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
fi

dnf5 install -y retroarch retroarch-assets retroarch-database retroarch-joypad-autoconfig

# Un jeu de coeurs choisi plutot que « libretro-* », qui ajouterait plusieurs
# gigaoctets a une image qui en fait deja 5,4. « --skip-unavailable » evite
# qu'un nom de paquet change d'une version a l'autre ne fasse tout echouer.
dnf5 install -y --skip-unavailable \
    libretro-nestopia \
    libretro-snes9x \
    libretro-genesis-plus-gx \
    libretro-mgba \
    libretro-beetle-psx \
    libretro-mupen64plus \
    libretro-flycast \
    || echo "AVERTISSEMENT : certains coeurs libretro n'ont pas ete trouves."

# A SAVOIR, et ce n'est pas un defaut de S : la construction Fedora de
# RetroArch desactive l'acces reseau par defaut, donc le telechargeur de
# coeurs interne est inerte. C'est pourquoi les coeurs sont poses ici, en
# paquets, plutot que laisses a l'utilisateur.

# ------------------------------------------------------------------ Zoom --
# Zoom ne publie pas de depot : un RPM direct, et il s'installe dans /opt/zoom
# — d'ou le detour de lib-opt.sh, le meme que pour Vivaldi.
rpm --import https://zoom.us/linux/download/pubkey?version=5-12-6 || \
    echo "AVERTISSEMENT : cle Zoom non importee, l'installation le dira."

opt_preparer
dnf5 install -y https://zoom.us/client/latest/zoom_x86_64.rpm
opt_ranger zoom
opt_restaurer

# ---------------------------------------------------------- Verification --
manque=0
command -v retroarch >/dev/null || { echo "ABSENT : retroarch" >&2; manque=1; }
[[ -x /usr/lib/opt/zoom/zoom ]] || { echo "ABSENT : /usr/lib/opt/zoom/zoom" >&2; ls -la /usr/lib/opt/ >&2 || true; manque=1; }
[[ "$manque" -eq 0 ]] || exit 1

echo "Applications posees :"
retroarch --version 2>/dev/null | head -1 | sed 's/^/  RetroArch  /' || echo "  RetroArch  version non lue"
echo "  coeurs     $(ls /usr/lib64/libretro/*.so 2>/dev/null | wc -l) trouves"
echo "  Zoom       range dans /usr/lib/opt/zoom"
