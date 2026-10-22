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

# ------------------------------------------------------- Archives : Ark ---
# DEMANDE EXPLICITE DE L'UTILISATEUR (« incorpore 7zip a S »). VERIFIE AVANT
# D'AGIR, PAS SUPPOSE : « ark » et « 7zip » sont deja dans l'image de base
# « ghcr.io/ublue-os/bazzite:stable » — rejoue le 2026-09-22 dans un conteneur
# jetable, tout neuf, jamais touche par cette machine : « dnf5 install ark
# 7zip » y repond « Package … is already installed » pour les DEUX, avant
# meme que ce script n'existe. Rien n'y etait donc casse ni absent ; les deux
# etaient deja herites, et le geste « Compresser » du clic droit
# (« noyau.py::compresser() », qui appelle « ark » depuis le 2026-08-26)
# fonctionnait deja sans que ce depot le sache.
#
# Ce qui est ecrit ici n'est donc pas un correctif : c'est une DECLARATION
# explicite d'une dependance dont S se sert deja, pour ne plus en dependre
# par accident. « rpm -q --whatrequires ark/7zip » rend vide sur cette
# machine : rien ne les REQUIERT, l'amont les pose par choix de paquetage —
# un choix qu'il pourrait un jour changer sans avertir. Meme regle que
# « waydroid-launcher » dans 20-android.sh : on verifie que l'amont fournit
# toujours ce qu'on suppose, on ne le devine pas.
#
# CE QUE CA N'EST PAS : un gain de vitesse. Mesure sur cette machine avant
# d'ecrire cette ligne : compresser 269 Mio de contenu realiste (80 Mio de
# binaire deja compresse + du texte tres compressible) prend 18 s avec
# « zip », 79 s avec « 7z a » par defaut — 7-Zip est plus LENT a compresser
# ici, son reglage par defaut (LZMA2) visant le taux de compression et non la
# vitesse (87,6 Mio contre 143,0 Mio, pas plus vite). Ce que 7-Zip apporte
# reellement est le format .7z lui-meme, que rien d'autre ne sait ouvrir, via
# le plugin « cli7z » d'Ark deja present (kerfuffle_cli7z.so) mais inerte
# sans le binaire « 7z ».
dnf5 install -y --setopt=install_weak_deps=False ark 7zip

# ---------------------------------------------------------- Verification --
if rpm -ql retroarch retroarch-assets retroarch-filters 2>/dev/null \
   | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : RetroArch a pose des fichiers hors de /usr et /etc." >&2
    exit 1
fi

manque=0
[[ -x /usr/bin/retroarch ]]           || { echo "ABSENT : /usr/bin/retroarch" >&2; manque=1; }
[[ "$manque" -eq 0 ]] || exit 1

# Rapport non bloquant : voir la note de 26-outils.sh.
echo "Applications posees :"
/usr/bin/retroarch --version 2>&1 | head -1 | sed 's/^/  RetroArch  /' || true
echo "  coeurs     $(ls /usr/lib64/libretro/*.so 2>/dev/null | wc -l) fichiers" || true
