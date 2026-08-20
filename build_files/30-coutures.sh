#!/usr/bin/bash
set -euxo pipefail

# ==========================================================================
# Les coutures — ce qui fait qu'un compte neuf est pret a la seconde ou il
# s'ouvre
# ==========================================================================
# Poser les logiciels dans l'image ne suffit pas : les extensions d'un
# editeur vivent dans le dossier personnel.
#
# D'ou « /etc/skel », le squelette recopie dans le dossier de CHAQUE compte
# cree. Et il se trouve que /etc est le bon endroit pour ca : contrairement a
# /opt, /home ou /usr/local, ce n'est PAS un lien vers /var — verifie sur le
# systeme installe. Il est stocke dans le commit sous /usr/etc puis fusionne
# au deploiement. C'est donc durable.
#
# LIMITE A CONNAITRE : /etc/skel ne sert que les comptes crees APRES le
# deploiement. Un compte deja existant ne recevra rien.

SKEL=/etc/skel/.vscode
ATELIER=/tmp/atelier-vscode

install -d -m 0755 "${SKEL}" "${SKEL}/extensions"
install -d -m 0700 "${ATELIER}/maison" "${ATELIER}/donnees"

# Deux reglages sans lesquels rien ne se pose :
#
#   --user-data-dir  OBLIGATOIRE. C'est le seul drapeau qui leve le garde-fou
#                    « ne pas lancer en root » de /usr/share/code/bin/code.
#                    Sans lui : sortie en code 1, aucune extension, aucun
#                    message clair.
#   HOME redirige    /root est un lien vers var/roothome. Sans redirection, le
#                    CLI ecrirait hors de l'image.
#
# « --no-sandbox » est en revanche inutile : --install-extension tourne dans
# Node via cli.js et ne demarre jamais Chromium. Ni DISPLAY ni xvfb requis.
export HOME="${ATELIER}/maison"
export DONT_PROMPT_WSL_INSTALL=1

poser_extension() {
    /usr/bin/code \
        --user-data-dir "${ATELIER}/donnees" \
        --extensions-dir "${SKEL}/extensions" \
        --install-extension "$1" --force 2>&1 | tail -3 \
    || { echo "AVERTISSEMENT : extension $1 non posee." >&2; return 0; }
}

poser_extension anthropic.claude-code
poser_extension ms-ceintl.vscode-language-pack-fr

# « google.geminicodeassist » est volontairement absent. Deux raisons : elle
# pese environ 178 Mio et /etc/skel est recopie POUR CHAQUE COMPTE cree ; et
# Google aurait bascule ses paliers individuels vers Antigravity a la
# mi-2026 — information rapportee mais NON verifiee ici. Gemini reste servi
# par sa CLI et par son lanceur en fenetre dediee. A rajouter en une ligne si
# le besoin se confirme.

# L'editeur s'ouvre en francais sans qu'on ait a le lui demander.
# VS Code n'ecrase jamais un argv.json deja present : l'utilisateur garde la
# main.
printf '{\n\t"locale": "fr"\n}\n' > /etc/skel/.vscode/argv.json

# Le fichier extensions.json ecrit par le CLI porte « relativeLocation »
# depuis VS Code 1.75 : les chemins se recalculent depuis le dossier courant,
# donc la recopie /etc/skel -> /var/home/<compte> reste valide. Ne jamais en
# fabriquer un a la main avec des chemins absolus — c'est le seul cas ou les
# extensions sont ignorees en silence.
rm -rf "${ATELIER}"
chmod -R a+rX /etc/skel/.vscode

echo "Extensions posees dans /etc/skel :"
ls -1 "${SKEL}/extensions" 2>/dev/null | sed 's/^/  /' || echo "  aucune"
echo "  poids : $(du -sh /etc/skel/.vscode 2>/dev/null | cut -f1) par compte cree"

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
