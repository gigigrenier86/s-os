#!/usr/bin/bash
# RecompLauncher, NATIF — dans l'image, sans Wine (demande du 2026-11-05).
#
# POURQUOI. Jusqu'ici RecompLauncher tournait dans le Windows de S : le .exe
# d'installation passe par s-ouvrir-exe, puis WebView2 (Edge, hors processus)
# + un correctif de l'executable (corriger_webview2.py) pour qu'il ne plante pas
# sur RevokeDragDrop. Mesure du 2026-11-05 : 3,5 Go de memoire pour une fenetre
# de lanceur, sur une machine a 16 Go — c'est ce qui a fait tomber Steam le soir
# meme. L'amont (elripalda/RecompLauncher, GPL-3.0, Rust/Tauri) publie pourtant
# une vraie version Linux : un binaire de 18 Mo qui utilise WebKitGTK, DEJA dans
# l'image. Plus de Wine, plus de WebView2, plus de correctif a rejouer.
#
# CE QUI EST ETABLI, ET CE QUI NE L'EST PAS (releve le 2026-11-05) :
#   - le .deb ne porte que /usr/bin/recomplauncher, un .desktop et des icones :
#     tout dans /usr, rien dans /var ni /opt (le piege d'ostree ne s'applique pas) ;
#   - toutes les bibliotheques declarees (readelf) sont deja sur la machine ;
#   - l'empreinte SHA-256 mesuree est celle que GitHub publie pour ce fichier ;
#   - LE BINAIRE N'A PAS ETE LANCE : l'essai a ete refuse par le systeme de
#     permissions (code tiers telecharge), et il n'a donc jamais ouvert de
#     fenetre ici. Voir CLAUDE.md.
#
# VERSION EPINGLEE, PAS « LA DERNIERE ». C'est une bete de sortie quotidienne
# (beta.15, .16 et .17 en deux jours) et une installation qui resout « latest »
# a la construction casse un matin au hasard — la lecon du 2026-11-04 (n8n,
# FROM :stable). Pour monter de version : changer VERSION et SHA256 ensemble ;
# l'empreinte se lit dans l'API des releases
# (api.github.com/repos/elripalda/RecompLauncher/releases, champ « digest »).
#
# LES DONNEES NE SONT PAS TOUCHEES : le lanceur natif range les siennes dans
# ~/.local/share/, la bibliotheque de jeux de la version Windows (C:\Recomp
# Library, dans le Windows de S) reste ou elle est.
set -euxo pipefail

VERSION="0.90.0-beta.17"
SHA256="a878345d759c14934352a92db89f3520c9d52a4fdc97f47d147e42df41b90d3f"
URL="https://github.com/elripalda/RecompLauncher/releases/download/v${VERSION}/RecompLauncher_${VERSION}_amd64.deb"

TRAVAIL=/tmp/recomplauncher
rm -rf "$TRAVAIL"
mkdir -p "$TRAVAIL/deb"

# --- Les bibliotheques viennent de la base : on verifie qu'elles y sont toujours.
# Si Bazzite en retire une, la construction doit echouer ici, bruyamment, plutot
# que de livrer un lanceur qui ne s'ouvre pas (comme 20-android.sh pour waydroid).
for p in webkit2gtk4.1 gtk3 libappindicator-gtk3; do
    rpm -q "$p" >/dev/null \
        || { echo "ECHEC : $p absent de la base — RecompLauncher natif ne pourrait pas s'ouvrir." >&2; exit 1; }
done

# --retry-all-errors : --retry seul ne rejoue pas un echec TLS (leçon de F-Droid).
curl -fsSL --retry 3 --retry-all-errors -o "$TRAVAIL/r.deb" "$URL"

OBTENU="$(sha256sum "$TRAVAIL/r.deb" | cut -d' ' -f1)"
if [ "$SHA256" != "$OBTENU" ]; then
    echo "ECHEC : l'empreinte du .deb de RecompLauncher ne correspond pas." >&2
    echo "  attendu $SHA256" >&2
    echo "  obtenu  $OBTENU" >&2
    exit 1
fi

cd "$TRAVAIL/deb"
ar x ../r.deb
DATA="$(ls data.tar.* | head -1)"

# Rien ne doit se poser hors de /usr : on lit la liste AVANT d'extraire.
# (Succes silencieux : une extraction vers /var « marche » et livre du vide.)
HORS="$(tar -tf "$DATA" | sed 's|^\./||' | grep -vE '^(usr(/|$)|$)' || true)"
if [ -n "$HORS" ]; then
    echo "ECHEC : le .deb pose des fichiers hors de /usr :" >&2
    echo "$HORS" >&2
    exit 1
fi
tar -xf "$DATA" -C / --no-same-owner --no-same-permissions --exclude='usr/share/applications' --exclude='./usr/share/applications'
chmod 0755 /usr/bin/recomplauncher

# Chaque bibliotheque declaree par le binaire doit se resoudre. readelf lit,
# il n'execute rien — c'est la raison de ne pas utiliser ldd sur un binaire tiers.
# La sortie de ldconfig est lue dans une VARIABLE puis cherchee par « <<< » : un
# « ldconfig -p | grep -q » sous pipefail fait mourir ldconfig en SIGPIPE des que
# grep a trouve (code 141) et conclut a tort « manquante » — le defaut du
# 2026-09-21 (41-windows.sh), retrouve ici au premier essai en conteneur.
CACHE_LIBS="$(ldconfig -p)"
for lib in $(readelf -d /usr/bin/recomplauncher | awk '/NEEDED/ { gsub(/[][]/, "", $5); print $5 }'); do
    grep -qF "$lib" <<< "$CACHE_LIBS" \
        || { echo "ECHEC : bibliotheque manquante pour RecompLauncher : $lib" >&2; exit 1; }
done

# LE LANCEUR EST LE NOTRE, pas celui du .deb : chemin absolu et TryExec (gio
# rejette un .desktop dont l'Exec ne se resout pas, et ne dit pas pourquoi —
# le defaut de Vivaldi du 2026-08-23), nom francais pour la description.
install -d /usr/share/applications
cat > /usr/share/applications/recomplauncher.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=RecompLauncher
Comment=One home for PC recomps
Comment[fr]=Trouver, installer et lancer les portages PC (recomps)
Exec=/usr/bin/recomplauncher
TryExec=/usr/bin/recomplauncher
Icon=recomplauncher
Terminal=false
Categories=Game;
StartupWMClass=recomplauncher
EOF
desktop-file-validate /usr/share/applications/recomplauncher.desktop

for f in /usr/bin/recomplauncher /usr/share/applications/recomplauncher.desktop \
         /usr/share/icons/hicolor/128x128/apps/recomplauncher.png; do
    test -s "$f" || { echo "ECHEC : $f absent apres la pose." >&2; exit 1; }
done

rm -rf "$TRAVAIL"

set +x
echo "RecompLauncher natif ${VERSION} pose"
du -sh /usr/bin/recomplauncher || true
echo "=== 54-recomplauncher : fait ==="
