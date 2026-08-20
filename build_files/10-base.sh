#!/usr/bin/bash
set -euxo pipefail

# La langue de l'interface est le francais, partout. Les paquets de langue ne
# sont pas dans l'image de base : sans eux, les applications retombent en anglais
# meme quand la locale est correctement posee.
dnf5 install -y glibc-langpack-fr hunspell-fr

# Le reste de l'identite — nom affiche, theme, ecran d'amorcage — attend le
# jalon 6. Ce jalon-ci ne prouve qu'une chose, et c'est deja beaucoup : la
# chaine de fabrication tourne de bout en bout.

# --------------------------------------------------------------------------
# Empecher un service de figer le demarrage indefiniment
# --------------------------------------------------------------------------
# « bazzite-hardware-setup.service » se place AVANT
# systemd-user-sessions.service et n'a aucune limite de temps. S'il ne rend
# jamais la main, aucune session ne s'ouvre — ni console, ni SSH — et la
# machine reste inutilisable sans qu'aucune erreur ne s'affiche : systemd
# annonce simplement « no limit » et compte les minutes.
#
# Constate le 2026-08-20 sur cette image, installee par « bootc install
# to-disk » : bloque au-dela de dix minutes. Le script appelle
# « rpm-ostree kargs », et l'unite se declare After=rpm-ostreed.service — ce
# qui rend l'interaction avec une installation bootc suspecte. C'est aussi un
# defaut connu en amont (ublue-os/bazzite, issue 434).
#
# On ne desactive pas le service : il configure de vraies choses sur du vrai
# materiel. On lui refuse seulement le droit de bloquer le demarrage sans fin.
# Un echec au bout de deux minutes est infiniment preferable a une machine qui
# ne s'ouvre jamais.
install -d /usr/lib/systemd/system/bazzite-hardware-setup.service.d
cat > /usr/lib/systemd/system/bazzite-hardware-setup.service.d/10-s-limite.conf <<'CONF'
[Service]
TimeoutStartSec=120
CONF
echo "bazzite-hardware-setup : limite de demarrage posee a 120 s."
