#!/usr/bin/bash
# Pre-cuire le monde Windows, pour que le premier double-clic ne coute pas
# une attente de plusieurs minutes.
#
# CE QUI NE MARCHE PAS, et qu il a fallu essayer pour le savoir : poser Proton
# deplie dans /usr et y pointer PROTONPATH. Pressure-vessel — le bac a sable de
# Steam qu umu utilise — RESERVE /usr et refuse de le partager dans son
# conteneur : « Not sharing path STEAM_COMPAT_MOUNTS=/usr/lib/s/proton because
# /usr is reserved by the container framework », puis « exec: proton: not
# found ». Meme famille que le piege /opt d ostree : un chemin qui semble libre
# ne l est pas.
#
# D ou cette forme : l ARCHIVE entre dans l image, et s-ouvrir-exe la deplie
# dans le dossier personnel au premier usage. Le reseau disparait du chemin
# critique ; il ne reste qu une decompression locale.
set -euxo pipefail

DEST=/usr/lib/s/windows
TRAVAIL=/tmp/proton
mkdir -p "$DEST" "$TRAVAIL"

# La derniere version publiee par Open Wine Components, avec son condensat.
LISTE="$(curl -fsSL --retry 3 https://api.github.com/repos/Open-Wine-Components/umu-proton/releases/latest)"
TAG="$(printf '%s' "$LISTE" | grep -m1 '"tag_name"' | cut -d'"' -f4)"
URL="https://github.com/Open-Wine-Components/umu-proton/releases/download/${TAG}"

curl -fsSL --retry 3 -o "$TRAVAIL/proton.tar.gz" "${URL}/${TAG}.tar.gz"
curl -fsSL --retry 3 -o "$TRAVAIL/proton.sha512sum" "${URL}/${TAG}.sha512sum"

# Le condensat publie fait foi. Un paquet de 468 Mo qu on deplie ensuite dans le
# dossier personnel merite exactement le meme controle qu un binaire pose.
ATTENDU="$(cut -d' ' -f1 < "$TRAVAIL/proton.sha512sum")"
OBTENU="$(sha512sum "$TRAVAIL/proton.tar.gz" | cut -d' ' -f1)"
if [ "$ATTENDU" != "$OBTENU" ]; then
    echo "ECHEC : le condensat de Proton ne correspond pas." >&2
    echo "  attendu $ATTENDU" >&2
    echo "  obtenu  $OBTENU" >&2
    exit 1
fi

install -m 0644 "$TRAVAIL/proton.tar.gz" "$DEST/proton.tar.gz"
printf '%s\n' "$TAG" > "$DEST/proton.version"
rm -rf "$TRAVAIL"

set +x
echo "Proton pre-cuit : $TAG" || true
du -sh "$DEST/proton.tar.gz" || true
