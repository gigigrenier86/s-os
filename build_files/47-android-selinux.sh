#!/usr/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------------
# s-android : le module SELinux, et la verification de ce que COPY a pose
# --------------------------------------------------------------------------
# APRES « COPY files/ / » (ligne 84 du Containerfile), et pas avant : ce
# script lit /usr/lib/s/android-*, /usr/lib/s/android/, /usr/share/selinux/
# s-android/ et les unites systemd que COPY vient de deposer. Plus haut, il
# ne les verrait pas et livrerait une image dont s-android.service echoue
# des le premier "Failed at step EXEC" — la meme forme de panne qu'a payee
# ce depot le 2026-08-26 avec un autre script lu vingt lignes trop tot.
#
# --------------------------------------------------------------------------
# LE MODULE SELINUX s_android — renommage mecanique de celui de Waydroid
# --------------------------------------------------------------------------
# lxc-start reste le moteur de s-android.service PRECISEMENT parce qu'il
# herite d'un domaine SELinux deja audite pour binder/dma/graphics — mais ce
# domaine (waydroid_t) disparait avec le paquet retire dans 20-android.sh. On
# le reconstruit a l'identique sous notre nom : meme regles, domaine a nous
# (voir files/usr/share/selinux/s-android/s_android.te, un
# `sed s/waydroid/s_android/g` sur le fichier amont — pas une politique
# reecrite de zero).
#
# UN SEUL FICHIER PEUT ENTRER DANS s_android_t DEPUIS init_t — la meme
# raison qui a impose une seule ligne ExecStart= dans s-android.service,
# mesure sur la machine le 2026-08-28 : "Failed at step EXEC" des qu'une
# ligne ExecStartPre= separee tentait d'executer waydroid-net.sh depuis
# init_t, qui n'a pas le droit d'entrer dans ce domaine. s_android.fc,
# compile avec le module, fait ce lien : android-lancer.sh et
# android-net.sh entrent dans le domaine, /var/lib/waydroid porte le type de
# donnees — verifie sur la machine (matchpathcon) le 2026-08-28.
#
# Les outils de compilation ne servent qu'ici : retires juste apres, comme
# tout ce qui ne doit pas rester dans l'image finie.
dnf5 install -y selinux-policy-devel policycoreutils-devel

pushd /usr/share/selinux/s-android
make -f /usr/share/selinux/devel/Makefile s_android.pp
semodule -i s_android.pp
rm -rf tmp s_android.mod s_android.mod.fc
popd

semodule -l | grep -q '^s_android$' \
    || { echo "ECHEC : le module s_android ne s'est pas charge." >&2; exit 1; }
echo "module SELinux s_android charge."

dnf5 remove -y selinux-policy-devel policycoreutils-devel

# --------------------------------------------------------------------------
# CE QUE COPY DOIT AVOIR POSE
# --------------------------------------------------------------------------
# MESURE DU 2026-08-24 (sur l'ancien montage) : dev-binderfs.mount est
# « static », sans section [Install] — il ne se declenche que tire par
# quelqu'un. C'etait waydroid-container.service qui le tirait via
# « Wants=dev-binderfs.mount ». s-android.service porte la meme ligne
# (verifiee ci-dessous) : le jour ou il demarre — a la main ou plus tard
# automatiquement — il tire binderfs avec lui, exactement comme avant.
#
# s-android.service N'EST PAS ACTIVE AU DEMARRAGE ICI, volontairement : le
# script suppose une session graphique deja ouverte (le socket Wayland de
# l'utilisateur), ce qu'un demarrage systeme n'a pas encore. L'activation
# reste un geste manuel pour l'instant — chantier a part.
test -f /usr/lib/systemd/system/s-android.service \
    || { echo "ECHEC : s-android.service est absent de l'image." >&2; exit 1; }
grep -q 'Wants=dev-binderfs.mount' /usr/lib/systemd/system/s-android.service \
    || { echo "ECHEC : s-android.service ne tire plus binderfs." >&2; exit 1; }
test -f /usr/lib/systemd/system/dev-binderfs.mount \
    || { echo "ECHEC : dev-binderfs.mount absent — Android ne pourra pas monter binderfs." >&2; exit 1; }
echo "  chaine verifiee : s-android.service -> dev-binderfs.mount -> /dev/binder"

for f in /usr/lib/s/android-lancer.sh /usr/lib/s/android-net.sh; do
    test -x "${f}" || { echo "ECHEC : ${f} absent ou non executable." >&2; exit 1; }
done
test -f /usr/lib/s/android/config_static \
    || { echo "ECHEC : config_static absent — s-android.service n'a pas de config LXC." >&2; exit 1; }
test -f /usr/lib/s/android/android.seccomp \
    || { echo "ECHEC : android.seccomp absent." >&2; exit 1; }
echo "fichiers de s-android.service verifies presents."

# --------------------------------------------------------------------------
# LE PRESSE-PAPIERS — le script deploye, active pour chaque compte
# --------------------------------------------------------------------------
# Le pont lui-meme (interface binder « lineageos.waydroid.IClipboard », cote
# Android deja dans system.img) n'a jamais eu besoin du paquet waydroid pour
# tourner — seul le cote hote en avait un, ecrit en Python. Verifie sur la
# machine le 2026-08-28 : `service list` depuis Android montre
# `waydroidclipboard` avec android-presse-papiers.py seul en face.
test -x /usr/lib/s/android-presse-papiers.py \
    || { echo "ECHEC : android-presse-papiers.py absent ou non executable." >&2; exit 1; }
test -f /usr/lib/systemd/user/s-android-presse-papiers.service \
    || { echo "ECHEC : l'unite utilisateur du presse-papiers est absente." >&2; exit 1; }

# Activee pour chaque compte des la construction — comme
# waydroid-container.service l'etait pour le conteneur, sauf que celle-ci
# peut tourner sans session Android ouverte (elle attend juste que le binder
# existe, sans effet si personne n'a jamais demarre s-android.service).
systemctl --global enable s-android-presse-papiers.service
echo "presse-papiers : service utilisateur active pour chaque compte."

# --------------------------------------------------------------------------
# LE DEMARRAGE AUTOMATIQUE ET LES ICONES PAR APPLICATION — 2026-08-29, soir
# --------------------------------------------------------------------------
# Meme mecanisme que le presse-papiers ci-dessus : le service binder
# « waydroidplatform » de system.img (android_plateforme.py) repond depuis la
# session sans aucun privilege, donc plus aucun outillage Python de Waydroid
# n'est necessaire pour lancer, installer ou lister les applications
# Android — voir CLAUDE.md, 2026-08-29, et android_plateforme.py pour la
# mesure du protocole (numeros de transaction, piege du segfault sur une
# lecture non gardee).
# PAS test -x : c'est un module purement importe (sys.path.insert + import),
# jamais execute directement — meme convention que noyau.py et
# regles-kwin.py, tous deux 100644.
test -f /usr/lib/s/android_plateforme.py \
    || { echo "ECHEC : android_plateforme.py absent." >&2; exit 1; }
test -x /usr/bin/s-android-lancer \
    || { echo "ECHEC : s-android-lancer absent ou non executable." >&2; exit 1; }
test -x /usr/lib/s/android-applications.py \
    || { echo "ECHEC : android-applications.py absent ou non executable." >&2; exit 1; }
test -f /usr/lib/systemd/user/s-android-applications.service \
    || { echo "ECHEC : l'unite du demon d'icones Android est absente." >&2; exit 1; }
test -f /usr/lib/systemd/user/s-android-demarrer.service \
    || { echo "ECHEC : l'unite de demarrage automatique d'Android est absente." >&2; exit 1; }
test -f /usr/share/polkit-1/rules.d/50-s-android.rules \
    || { echo "ECHEC : la regle polkit du demarrage sans mot de passe est absente." >&2; exit 1; }
echo "demarrage automatique et icones Android : fichiers verifies presents."

# Meme raisonnement que s-android-presse-papiers.service : activee pour
# chaque compte des la construction, sans effet tant qu'aucune session
# graphique (graphical-session.target) n'existe.
systemctl --global enable s-android-applications.service s-android-demarrer.service
echo "Android : demarrage automatique et icones par application actives pour chaque compte."

# --------------------------------------------------------------------------
# LES NOTIFICATIONS ANDROID → BULLE S — 2026-09-01
# --------------------------------------------------------------------------
# Meme patron que le presse-papiers et les icones : service Binder
# « waydroidnotification » enregistre sur /dev/binder, appele par le greffon
# Android existant dans system.img a chaque notify(). Le service hote
# (android-notifications.py) reçoit les champs (app, titre, corps, icone
# base64) et les retransmet via notify-send.
chmod +x /usr/lib/s/android-notifications.py 2>/dev/null || true
test -x /usr/lib/s/android-notifications.py \
    || { echo "ECHEC : android-notifications.py absent ou non executable." >&2; exit 1; }
test -f /usr/lib/systemd/user/s-android-notifications.service \
    || { echo "ECHEC : l'unite de notifications Android est absente." >&2; exit 1; }

systemctl --global enable s-android-notifications.service
echo "notifications Android : service utilisateur active pour chaque compte."
