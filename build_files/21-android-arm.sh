#!/usr/bin/bash
# Pre-cuire libhoudini (traduction ARM d'Android), pour que le premier
# lancement d'une application qui n'existe qu'en ARM ne demande pas de
# reseau.
#
# CODE NOIR ASSUME, PAS CACHE — voir CLAUDE.md, 2026-08-30. Ce binaire est
# proprietaire (vendor Intel, republie par un mainteneur communautaire —
# supremegamers — sans licence documentee), verifie par MD5 seul : c'est le
# seul controle que l'amont lui-meme applique (ublue-os/waydroid_script,
# stuff/houdini.py, releve mot pour mot le 2026-08-30). DECISION PRISE AVEC
# L'UTILISATEUR, PAS DEVINEE : S vise a fonctionner pour d'autres que lui
# un jour, et « ca marche ici » doit vouloir dire « ca marche partout » —
# le binaire entre donc dans l'image publique, sous la signature de S, en
# connaissance de cause plutot qu'en silence.
#
# CE QUI N'ENTRE PAS DANS L'IMAGE : l'INSTALLATION elle-meme. L'extraction
# dans /var/lib/waydroid/overlay/system, la pose de houdini.rc et le
# reglage des proprietes Android restent un GESTE — « s-android
# --traduction-arm » (partage-android.sh) — parce que /var/lib/waydroid
# n'existe pas a la construction, et parce qu'Android peut ne pas meme
# etre initialise sur la machine qui recoit cette image. Seule l'ARCHIVE,
# deja verifiee, est pre-cuite ici — meme principe que Proton
# (41-windows.sh) : le reseau disparait du chemin critique, il ne reste
# qu'une extraction locale au moment ou l'utilisateur la demande.
#
# SEULE LA VERSION ANDROID 13 EST CABLEE : c'est celle de S (LineageOS
# 20.0, sdk 33 — mesure par android_plateforme.py le 2026-08-30). L'URL et
# l'empreinte sont EXACTEMENT celles que porte stuff/houdini.py chez
# l'amont pour cette version, extraites par ast.literal_eval, jamais
# devinees.
set -euxo pipefail

DEST=/usr/lib/s/android
TRAVAIL=/tmp/houdini-precuisson
mkdir -p "$DEST" "$TRAVAIL"

URL="https://github.com/supremegamers/vendor_intel_proprietary_houdini/archive/7e21ea3f63bd89e9e8af54e32da41bd8b65c93a1.zip"
MD5_ATTENDU="f8cf5db10e5fdb9b77e98e515a9b08c9"

curl -fsSL --retry 3 -o "$TRAVAIL/libhoudini.zip" "$URL"

# LE CONDENSAT PUBLIE PAR L'AMONT FAIT FOI, MEME DISCIPLINE QU'AVANT :
# jamais un octet installe sans qu'il corresponde. MD5 seul est le controle
# que l'amont applique lui-meme — pas mieux, pas moins, verifie mot pour mot.
MD5_OBTENU="$(md5sum "$TRAVAIL/libhoudini.zip" | cut -d' ' -f1)"
if [ "$MD5_ATTENDU" != "$MD5_OBTENU" ]; then
    echo "ECHEC : le condensat de libhoudini ne correspond pas." >&2
    echo "  attendu $MD5_ATTENDU" >&2
    echo "  obtenu  $MD5_OBTENU" >&2
    exit 1
fi

install -m 0644 "$TRAVAIL/libhoudini.zip" "$DEST/libhoudini.zip"
rm -rf "$TRAVAIL"

set +x
echo "libhoudini pre-cuit (Android 13, Intel)"
du -sh "$DEST/libhoudini.zip" || true
echo "=== 21-android-arm : fait ==="
