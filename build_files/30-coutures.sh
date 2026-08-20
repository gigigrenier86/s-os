#!/usr/bin/bash
set -euxo pipefail

# ==========================================================================
# Les coutures — ce qui fait qu'un compte neuf est pret a la seconde ou il
# s'ouvre
# ==========================================================================
# Demande de l'utilisateur : « du pret au moment meme ou je me connecte pour
# la premiere fois ». Poser les logiciels dans l'image ne suffit pas : les
# extensions d'un editeur, elles, vivent dans le dossier personnel.
#
# D'ou « /etc/skel », le squelette que le systeme recopie dans le dossier de
# CHAQUE compte cree. C'est le seul mecanisme qui soit a la fois dans l'image
# — donc durable — et personnel — donc modifiable ensuite par l'utilisateur.
# Un service de premier demarrage aurait echoue comme les trois de Bazzite.

install -d /etc/skel/.vscode/extensions

# VS Code refuse de tourner en root sans « --no-sandbox », et il lui faut un
# dossier de donnees jetable pour ne rien laisser dans l'image.
poser_extension() {
    /usr/bin/code --no-sandbox \
        --user-data-dir /tmp/vscode-construction \
        --extensions-dir /etc/skel/.vscode/extensions \
        --install-extension "$1" --force 2>&1 | tail -2 \
    || echo "AVERTISSEMENT : extension $1 non posee." >&2
}

# Claude Code et Gemini dans l'editeur, et l'interface en francais — meme
# regle que partout ailleurs ici.
poser_extension anthropic.claude-code
poser_extension google.geminicodeassist
poser_extension ms-ceintl.vscode-language-pack-fr

rm -rf /tmp/vscode-construction

# Que l'editeur s'ouvre en francais sans qu'on ait a le lui demander.
install -d /etc/skel/.vscode
cat > /etc/skel/.vscode/argv.json <<'JSON'
{
  "locale": "fr"
}
JSON

echo "Extensions posees dans /etc/skel :"
ls -1 /etc/skel/.vscode/extensions 2>/dev/null | sed 's/^/  /' || echo "  aucune"

# --------------------------------------------------------------------------
# Ce qui reste a faire ici, et qui n'est pas oublie
# --------------------------------------------------------------------------
# Les vraies coutures entre les trois mondes attendent le jalon 5 :
#   1. un seul menu, ou un .exe, un .apk et une application native se rangent
#      ensemble deliberement ;
#   2. un seul dossier personnel, vu depuis Z:\ sous Wine et depuis
#      /storage/emulated/0 sous Android ;
#   3. un seul presse-papiers — Waydroid le fait mal, ce sera du vrai travail ;
#   4. un seul jeu d'associations de fichiers.
echo "Coutures inter-mondes : jalon 5, rien a poser encore."
