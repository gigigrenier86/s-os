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

# LA DERNIERE VERSION PUBLIEE PAR GLORIOUSEGGROLL (GE-PROTON), PAS umu-proton.
#
# CHANGE LE 2026-08-29, ET C'EST UNE DECISION PRISE AVEC L'UTILISATEUR, PAS
# DEVINEE. umu-proton (Open-Wine-Components) reste coince sur wine-10.0 —
# verifie en direct ce soir-la, meme requete que ci-dessous, meme reponse
# (« UMU-Proton-10.0-4 ») : rien a esperer d'une simple reconstruction
# d'image. GE-Proton, lui, est deja a wine-11 (« GE-Proton11-6 », publie le
# 28 aout 2026) — la base minimale pour le support ntsync stable (voir
# CLAUDE.md). Le format d'assets differe d'un seul detail, verifie en
# direct : GE-Proton suffixe l'architecture (« ${TAG}-x86_64.tar.gz »), la
# ou umu-proton ne le faisait pas.
#
# MEME DISCIPLINE QU'AVANT, AU MOT PRES : le condensat publie par l'amont
# fait foi, jamais un octet installe sans qu'il corresponde.
LISTE="$(curl -fsSL --retry 3 https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest)"
TAG="$(printf '%s' "$LISTE" | grep -m1 '"tag_name"' | cut -d'"' -f4)"
URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${TAG}"

curl -fsSL --retry 3 -o "$TRAVAIL/proton.tar.gz" "${URL}/${TAG}-x86_64.tar.gz"
curl -fsSL --retry 3 -o "$TRAVAIL/proton.sha512sum" "${URL}/${TAG}-x86_64.sha512sum"

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

# LE TAG N'EST PAS TOUJOURS LE DOSSIER — ON LE VERIFIE, ON NE LE SUPPOSE PAS.
# Piege trouve le 2026-08-29 en testant en direct sur la machine, avant
# qu'il ne casse une vraie construction : l'archive GE-Proton se deplie en
# « ${TAG}-x86_64 », pas en « ${TAG} » tout court — contrairement a
# umu-proton, ou les deux coincidaient exactement. « proton.version » doit
# porter le VRAI nom du dossier de premier niveau dans l'archive : c'est lui
# que s_windows_proton() recompose en chemin, et un mauvais nom casserait
# tout le monde Windows au premier lancement suivant la construction — en
# silence, puisque rien n'echouerait avant ce moment-la.
# « || true » A LA FIN, PAS PAR PARESSE : « head -1 » ferme son entree des
# la premiere ligne lue, et tar — qui continuerait a ecrire les milliers de
# lignes suivantes — recoit SIGPIPE. Avec « set -o pipefail » (ligne 16), ce
# SIGPIPE fait echouer tout le pipeline (141 = 128+13), et « set -e » arrete
# le script net, SANS LE MOINDRE MESSAGE — mesure en local le 2026-08-30,
# reproduction fidele de l'echec de construction #33317639535 : le script
# meurt exactement apres cette ligne, code de sortie 141. La valeur de
# DOSSIER_ARCHIVE est deja correcte au moment ou tar recoit son signal —
# c'est cut qui a fini d'ecrire avant que tar ne finisse d'echouer — donc
# neutraliser l'echec du pipeline ici est sur, pas un pansement sur une
# vraie erreur.
DOSSIER_ARCHIVE="$(tar tzf "$TRAVAIL/proton.tar.gz" | head -1 | cut -d/ -f1 || true)"
[ -n "$DOSSIER_ARCHIVE" ] || { echo "ECHEC : impossible de lire le nom du dossier dans l'archive Proton." >&2; exit 1; }

install -m 0644 "$TRAVAIL/proton.tar.gz" "$DEST/proton.tar.gz"
printf '%s\n' "$DOSSIER_ARCHIVE" > "$DEST/proton.version"
rm -rf "$TRAVAIL"

set +x
echo "Proton pre-cuit : $TAG" || true
du -sh "$DEST/proton.tar.gz" || true

# ---------------------------------------------------------------------------
# icoutils : wrestool et icotool sortent l icone d un binaire Windows de sa
# section de ressources, pour que chaque programme porte la sienne au menu.
#
# IL ETAIT DEJA LA, MAIS PAR ACCIDENT — aucun paquet ne le demandait, aucune
# ligne de ce depot ne le nommait. Un jour il aurait disparu et les icones
# seraient redevenues grises sans que personne comprenne pourquoi.
#
# CE FICHIER TOURNE AVANT « COPY files/ / » (ligne 63 contre ligne 84 du
# Containerfile) : il ne peut donc RIEN verifier des gestes de S, qui n existent
# pas encore a cette etape. Les controles du Windows resident vivent dans
# 40-coutures.sh, qui passe apres les COPY. C est la cause exacte de l echec de
# construction du 2026-08-26 a 03 h 37 — les verifications etaient ici.
dnf5 install -y --setopt=install_weak_deps=False icoutils
command -v wrestool >/dev/null || { echo "ECHEC : wrestool absent." >&2; exit 1; }
command -v icotool  >/dev/null || { echo "ECHEC : icotool absent." >&2; exit 1; }

set +x
echo "  icoutils       : wrestool et icotool poses"
echo "=== 41-windows : fait ==="
