#!/usr/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------------
# La machine s'annonce S — jalon 6, premiere piece posee dans l'image
# --------------------------------------------------------------------------
# Tout ce qui affiche « Bazzite » le lit au meme endroit : /usr/lib/os-release,
# que /etc/os-release pointe. L'invite de console (agetty developpe \S en
# PRETTY_NAME), l'entree du chargeur d'amorcage (composee depuis PRETTY_NAME au
# deploiement — c'est elle qui dit « title Bazzite (ostree:0) » sur la Seagate),
# le centre d'information de KDE : une seule source, donc une seule retouche.
#
# ID reste « bazzite », a dessein : les recettes ujust et les scripts de
# l'amont testent l'identifiant, jamais le nom affiche. Changer ID casserait
# ce qu'on herite ; changer NAME ne casse rien.

echo "os-release avant :"
grep -E '^(NAME|PRETTY_NAME|ID|DEFAULT_HOSTNAME|HOME_URL)=' /usr/lib/os-release || true

sed -i \
  -e 's|^NAME=.*|NAME="S"|' \
  -e 's|^PRETTY_NAME=.*|PRETTY_NAME="S"|' \
  -e 's|^HOME_URL=.*|HOME_URL="https://github.com/gigigrenier86/s-os"|' \
  /usr/lib/os-release

# Le logo : l'icone s-logo entre par COPY dans hicolor, et LOGO= dit a KDE de
# l'afficher dans le centre d'information. La ligne peut exister ou non selon
# la base — on remplace si elle est la, on l'ajoute sinon.
if grep -q '^LOGO=' /usr/lib/os-release; then
  sed -i 's|^LOGO=.*|LOGO=s-logo|' /usr/lib/os-release
else
  echo 'LOGO=s-logo' >> /usr/lib/os-release
fi

# DEFAULT_HOSTNAME ne sert qu'aux machines dont personne ne choisit le nom ;
# celles deja baptisees — ThinkCentre720Q — ne sont pas touchees.
grep -q '^DEFAULT_HOSTNAME=' /usr/lib/os-release \
  && sed -i 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="s"|' /usr/lib/os-release \
  || true

# /etc/os-release doit rester un lien vers /usr/lib/os-release. S'il etait un
# vrai fichier, la retouche ci-dessus ne se verrait nulle part — le succes
# silencieux, exactement ce que ce depot s'interdit.
ls -l /etc/os-release
test -L /etc/os-release

echo "os-release apres :"
grep -E '^(NAME|PRETTY_NAME|ID|DEFAULT_HOSTNAME|HOME_URL|LOGO)=' /usr/lib/os-release

# Les assertions : une image qui ne s'annonce pas S ne sort pas d'ici,
# et ID n'a pas bouge — c'est la promesse faite aux scripts de l'amont.
grep -q '^NAME="S"$' /usr/lib/os-release
grep -q '^PRETTY_NAME="S"$' /usr/lib/os-release
grep -q '^ID=bazzite' /usr/lib/os-release
grep -q '^LOGO=s-logo$' /usr/lib/os-release
