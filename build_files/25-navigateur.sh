#!/usr/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------------
# Un navigateur, et pourquoi il est DANS l'image
# --------------------------------------------------------------------------
# Constate le 2026-08-20 sur une installation reelle : S n'avait AUCUN
# navigateur. Ni en RPM, ni en Flatpak.
#
# Bazzite prevoit pourtant Firefox — il figure dans
# /usr/share/ublue-os/bazzite/flatpak/install. Mais son gestionnaire a tourne
# en 5,6 s sans rien poser, PUIS a ecrit ses marqueurs dans /etc/bazzite/ :
# la condition « $VER = $VER_RAN » sera vraie a tous les demarrages suivants,
# et il ne reessaiera donc jamais. Meme famille de defaut que
# bazzite-hardware-setup : un script qui suppose un premier demarrage
# fabrique autrement que par « bootc install ».
#
# On ne repare pas ce mecanisme, on s'en passe : le navigateur entre dans
# l'image. Il est la des le premier demarrage, sans reseau, sans marqueur,
# sans premiere ouverture de session.
#
# NOTE DE LICENCE, a connaitre puisque ce depot est public : Vivaldi est un
# logiciel proprietaire gratuit. Sa page destinee aux distributions Linux
# indique qu'aucun accord n'est necessaire pour l'integrer, et Manjaro comme
# FerenOS le livrent par defaut ; son CLUF, lui, interdit la redistribution.
# Les deux textes se contredisent. Si cette zone grise gene, une seule ligne
# suffit a passer a une pose au premier demarrage plutot qu'a une inclusion.

rpm --import https://repo.vivaldi.com/archive/linux_signing_key.pub

cat > /etc/yum.repos.d/vivaldi.repo <<'REPO'
[vivaldi]
name=Vivaldi
baseurl=https://repo.vivaldi.com/archive/rpm/x86_64
enabled=1
gpgcheck=1
gpgkey=https://repo.vivaldi.com/archive/linux_signing_key.pub
REPO

dnf5 install -y vivaldi-stable

# Le depot ne reste PAS dans l'image : sur un systeme bootc, les mises a jour
# arrivent par reconstruction de l'image, pas par dnf sur la machine. Le laisser
# suggererait le contraire.
rm -f /etc/yum.repos.d/vivaldi.repo

# La suite depend du nom exact du binaire — on le verifie plutot que de le
# supposer, et la construction echoue ici si Vivaldi le change un jour.
if [[ ! -x /usr/bin/vivaldi-stable ]]; then
    echo "ECHEC : /usr/bin/vivaldi-stable est absent apres installation." >&2
    ls -l /usr/bin/vivaldi* >&2 || true
    exit 1
fi
echo "Vivaldi installe : $(/usr/bin/vivaldi-stable --version 2>/dev/null || echo 'version non lue')"
