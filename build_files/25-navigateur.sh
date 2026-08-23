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

# --------------------------------------------------------------------------
# Le .desktop du paquet vise /usr/bin/vivaldi-stable, et c'est le piege
# --------------------------------------------------------------------------
# Trouve sur la M720q le 2026-08-23 : /usr/bin/vivaldi-stable -> /opt/vivaldi/
# vivaldi -> /var/opt/vivaldi/vivaldi, et ce dernier pont ne s'etait jamais
# refait — /var/opt/vivaldi existait deja comme un vrai dossier (les codecs
# proprietaires que Vivaldi y telecharge), si bien que le « L » de tmpfiles.d
# refuse de poser un lien par-dessus. Consequence mesuree : « gio launch »
# refuse meme de CHARGER le .desktop (pas seulement de l'executer), puisque
# gio resout Exec des le chargement. Toute etoile Vivaldi de Constellation en
# silence, et le menu KDE tout autant.
#
# Le correctif retenu par s-coquille pour son propre moteur s'applique ici :
# viser le chemin de L'IMAGE, jamais le pont qui peut se rompre.
F=/usr/share/applications/vivaldi-stable.desktop
sed -i 's|^Exec=/usr/bin/vivaldi-stable|Exec=/usr/lib/opt/vivaldi/vivaldi|' "$F"
# TryExec n'a le droit de vivre QUE dans [Desktop Entry] — un TryExec dans un
# groupe [Desktop Action ...] est rejete par desktop-file-validate. Premiere
# tentative en sed aveugle, corrigee au banc le 2026-08-23.
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
with open(p) as f:
    lignes = f.readlines()
sortie, section, pose = [], None, False
for ligne in lignes:
    s = ligne.strip()
    if s.startswith("["):
        section = s
    sortie.append(ligne)
    if section == "[Desktop Entry]" and s.startswith("Exec=") and not pose:
        sortie.append("TryExec=/usr/lib/opt/vivaldi/vivaldi\n")
        pose = True
with open(p, "w") as f:
    f.writelines(sortie)
PY
if grep -q '/usr/bin/vivaldi-stable' "$F"; then
    echo "ECHEC : vivaldi-stable.desktop vise encore /usr/bin/vivaldi-stable." >&2
    exit 1
fi
command -v desktop-file-validate >/dev/null 2>&1 && desktop-file-validate "$F"
echo "  lanceur       : vivaldi-stable.desktop vise /usr/lib/opt/vivaldi/vivaldi directement"

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
