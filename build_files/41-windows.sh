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

# ---------------------------------------------------------------------------
# LE WINDOWS DE S DEVIENT UNE SESSION — 2026-08-26
# ---------------------------------------------------------------------------
# CE QUI ETAIT FAUX, ET LA MESURE, sur la machine de l utilisateur :
#
#   « cmd /c exit » par umu-run            4,53 a 5,12 s, A CHAQUE FOIS
#   wine direct, 1er apres la session      1,37 s
#   wine direct, lancements suivants       0,109 s  (huit mesures, ecart 0,004)
#
# Chaque double-clic reconstruisait un Windows entier. Le conteneur
# pressure-vessel sert a CONSTRUIRE le prefixe — c est le script proton qui y
# copie DXVK et VKD3D — pas a l executer. Une fois construit, le prefixe est
# autonome. Voir /usr/lib/s/windows.sh pour le detail.
set -euxo pipefail

# icoutils : wrestool et icotool sortent l icone d un binaire Windows de sa
# section de ressources. IL ETAIT DEJA LA, MAIS PAR ACCIDENT — aucun paquet ne
# le demandait, aucune ligne de ce depot ne le nommait. Un jour il aurait
# disparu et les icones seraient redevenues grises sans que personne comprenne.
dnf5 install -y --setopt=install_weak_deps=False icoutils

chmod 0755 /usr/bin/s-windows /usr/bin/s-ouvrir-exe /usr/bin/s-menu-windows
bash -n /usr/bin/s-windows
bash -n /usr/bin/s-ouvrir-exe
bash -n /usr/bin/s-menu-windows
bash -n /usr/lib/s/windows.sh
bash -n /usr/lib/s/icone-exe.sh
python3 -m py_compile /usr/lib/s/polices.py
rm -rf /usr/lib/s/__pycache__ 2>/dev/null || true

set +x
echo "  s-windows      : syntaxe analysee"

# --- LE SERVEUR RESIDENT ----------------------------------------------------
test -s /usr/lib/systemd/user/s-windows.service \
    || { echo "ECHEC : s-windows.service absent — le Windows de S renaitrait a chaque .exe." >&2; exit 1; }
systemctl --global enable s-windows.service
test -L /etc/systemd/user/s-session.target.wants/s-windows.service \
    || { echo "ECHEC : s-windows.service n est pas tire par s-session.target." >&2; exit 1; }
echo "  s-windows.service : resident, tire par s-session.target"

# --- CE QUE s-ouvrir-exe DOIT ENCORE FAIRE ----------------------------------
# LA VERIFICATION D AVANT LISAIT UN COMMENTAIRE, ET C EST LE PIEGE QUE CE DEPOT
# A DEJA PAYE UNE FOIS. Le garde-fou de plasma_waitforname, ecrit le
# 2026-08-25, matchait sa propre documentation et faisait echouer la
# construction. Ici l inverse : « grep -q s-partage /usr/bin/s-ouvrir-exe »
# aurait continue de passer alors que l appel a demenage dans s-windows — il ne
# restait qu une phrase de commentaire. On ancre donc sur l APPEL.
grep -qE '^\s*"\$S_GESTES/s-partage"' /usr/bin/s-windows \
    || { echo "ECHEC : s-windows ne rappelle pas s-partage — la lettre P: ne serait jamais posee." >&2; exit 1; }
echo "  s-windows      : pose la lettre P: apres creation du prefixe"

grep -qE '^\s*"\$S_GESTES/s-lien-windows" --recenser' /usr/bin/s-ouvrir-exe \
    || { echo "ECHEC : s-ouvrir-exe ne recense plus les protocoles." >&2; exit 1; }
echo "  s-ouvrir-exe   : recense les protocoles apres chaque execution"

# --- LE FILET DOIT DESCENDRE LE SERVEUR -------------------------------------
# Mesure du 2026-08-26 : umu-run pendant qu un wineserver tient le prefixe rend
# AUCUNE FENETRE apres soixante secondes, sans un mot. Un filet qui ne rattrape
# rien tout en ayant l air de le faire est pire qu aucun filet.
grep -q 's_windows_pause' /usr/bin/s-ouvrir-exe \
    || { echo "ECHEC : le repli sur umu-run n arrete pas le serveur resident — il echouerait en silence." >&2; exit 1; }
echo "  s-ouvrir-exe   : le repli arrete le serveur avant de rejouer"

# --- L EXTRACTEUR D ICONES --------------------------------------------------
command -v wrestool >/dev/null || { echo "ECHEC : wrestool absent." >&2; exit 1; }
command -v icotool  >/dev/null || { echo "ECHEC : icotool absent." >&2; exit 1; }
grep -q 's_icone_exe' /usr/bin/s-menu-windows \
    || { echo "ECHEC : s-menu-windows ne sort pas l icone des programmes." >&2; exit 1; }
echo "  icones         : wrestool + icotool, branches dans s-menu-windows"

# --- LE LECTEUR DE NOM DE POLICE --------------------------------------------
# Il decide sous quel nom une police est declaree au registre, et ce nom ne se
# deduit PAS du fichier : SegoeIcons.ttf se declare « Segoe Fluent Icons ». On
# l eprouve sur une police reelle de l image plutot que d esperer.
python3 - <<'ESSAI'
import glob
import sys
sys.path.insert(0, "/usr/lib/s")
import polices

candidats = sorted(glob.glob("/usr/share/fonts/**/*.ttf", recursive=True))
assert candidats, "aucune police dans l image pour eprouver le lecteur"
noms = polices.nom_windows(candidats[0])
assert noms and noms[0].strip(), "le lecteur n a rendu aucun nom pour %s" % candidats[0]
print("  polices.py     : %s -> %r" % (candidats[0].rsplit("/", 1)[-1], noms[0]))
ESSAI

echo "=== 41-windows : fait ==="
