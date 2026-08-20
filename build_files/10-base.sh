#!/usr/bin/bash
set -euxo pipefail

# La langue de l'interface est le francais, partout. Les paquets de langue ne
# sont pas dans l'image de base : sans eux, les applications retombent en anglais
# meme quand la locale est correctement posee.
dnf5 install -y glibc-langpack-fr hunspell-fr

# Le reste de l'identite — nom affiche, theme, ecran d'amorcage — attend le
# jalon 6. Ce jalon-ci ne prouve qu'une chose, et c'est deja beaucoup : la
# chaine de fabrication tourne de bout en bout.
