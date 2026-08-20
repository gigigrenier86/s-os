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
# bazzite-hardware-setup : un script qui suppose un premier demarrage fabrique
# autrement que par « bootc install ».
#
# On ne repare pas ce mecanisme, on s'en passe : le navigateur entre dans
# l'image. Il est la des le premier demarrage, sans reseau, sans marqueur,
# sans premiere ouverture de session.
#
# NOTE DE LICENCE, a connaitre puisque ce depot est public : Vivaldi est un
# logiciel proprietaire gratuit. Sa page destinee aux distributions Linux
# indique qu'aucun accord n'est necessaire pour l'integrer, et Manjaro comme
# FerenOS le livrent par defaut ; son CLUF, lui, interdit la redistribution.
# Les deux textes se contredisent.

rpm --import https://repo.vivaldi.com/archive/linux_signing_key.pub

cat > /etc/yum.repos.d/vivaldi.repo <<'REPO'
[vivaldi]
name=Vivaldi
baseurl=https://repo.vivaldi.com/archive/rpm/x86_64
enabled=1
gpgcheck=1
gpgkey=https://repo.vivaldi.com/archive/linux_signing_key.pub
REPO

# --------------------------------------------------------------------------
# Le detour par /opt, obligatoire sur une image ostree
# --------------------------------------------------------------------------
# Premier essai, echoue :
#
#   [RPM] failed to open dir opt of /opt/: cpio: mkdir failed - File exists
#   [RPM] unpacking of archive failed on file /opt/vivaldi
#
# Deux contraintes se croisent. D'abord « /opt » est un lien vers « var/opt »
# sur un systeme ostree, et RPM REFUSE de depaqueter a travers un lien
# symbolique — c'est un durcissement deliberé contre une classe de failles, pas
# un bogue. Ensuite « /var » n'entre pas dans une image bootc : il est propre a
# la machine et recree a l'installation. Meme si l'on forcait, les fichiers ne
# seraient pas dans l'image.
#
# D'ou ce detour en quatre temps : rendre /opt reel, installer, deplacer le
# resultat sous /usr — qui, lui, EST l'image —, puis remettre /opt tel
# qu'ostree l'attend et laisser systemd-tmpfiles recreer le pont a chaque
# demarrage.

OPT_CIBLE="$(readlink /opt || echo var/opt)"
rm -rf /opt
mkdir -p /opt

dnf5 install -y vivaldi-stable

mkdir -p /usr/lib/opt
mv /opt/vivaldi /usr/lib/opt/vivaldi

rm -rf /opt
ln -s "${OPT_CIBLE}" /opt

# Le pont, refait a chaque demarrage : /var/opt/vivaldi pointe vers l'image.
# Sans lui, /usr/bin/vivaldi-stable — qui vise /opt/vivaldi/vivaldi — ne
# resoudrait rien.
install -d /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/s-vivaldi.conf <<'TMP'
#  Vivaldi vit dans /usr/lib/opt (donc dans l'image, en lecture seule) et se
#  montre a l'endroit ou le paquet l'attend.
L  /var/opt/vivaldi  -  -  -  -  /usr/lib/opt/vivaldi
TMP

# Le depot ne reste PAS dans l'image : sur un systeme bootc, les mises a jour
# arrivent par reconstruction de l'image, pas par dnf sur la machine. Le laisser
# suggererait le contraire.
rm -f /etc/yum.repos.d/vivaldi.repo

# On verifie le binaire REEL, pas /usr/bin/vivaldi-stable : celui-ci vise
# /opt/vivaldi/vivaldi, qui ne resout pas pendant la construction puisque le
# pont n'existe qu'au demarrage.
if [[ ! -x /usr/lib/opt/vivaldi/vivaldi ]]; then
    echo "ECHEC : /usr/lib/opt/vivaldi/vivaldi est absent apres deplacement." >&2
    ls -la /usr/lib/opt/ /opt >&2 || true
    exit 1
fi
echo "Vivaldi pose dans /usr/lib/opt/vivaldi, pont tmpfiles installe."
ls -l /usr/bin/vivaldi* || true
