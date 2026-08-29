#!/usr/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------------
# Android — Bazzite pose les images, S retire l'outillage Waydroid
# --------------------------------------------------------------------------
# MESURE SUR LA MACHINE, LE 2026-08-28 (voir CLAUDE.md, "Android tourne sous
# s-android.service"). system.img/vendor.img sont telecharges par le paquet
# waydroid AVANT qu'on le retire ici (son initializer.py les pose dans
# /var/lib/waydroid/images, un dossier hors du paquet lui-meme — verifie :
# `rpm -ql waydroid` ne montre rien sous /var/lib/waydroid) et le domaine
# SELinux deja audite pour binder/graphics reste utile sous un nom a nous.
# Le paquet Python — sa CLI, son gestionnaire de session, son gestionnaire de
# conteneur — n'est plus necessaire : s-android.service (voir
# 47-android-selinux.sh, APRES le COPY files/ /, puisqu'il en depend) le
# remplace en entier.
#
# ON NE REIMPLEMENTE PAS system.img/vendor.img. « ujust configure-waydroid »
# de Bazzite est ce qui les pose la premiere fois — on le laisse faire
# entierement, et on retire seulement l'outillage Python APRES.

if [[ ! -x /usr/bin/waydroid-launcher ]]; then
    echo "ECHEC : /usr/bin/waydroid-launcher est absent de l'image de base." >&2
    echo "        Bazzite portait cette brique ; elle l'a peut-etre retiree." >&2
    echo "        Voir build_files/20-android.sh et la documentation amont." >&2
    exit 1
fi

# --nodeps : waydroid-selinux depend du paquet waydroid pour son scriptlet de
# politique, et l'ordre de suppression standard de dnf braille dessus sans
# raison relle — les deux partent ensemble de toute facon, et
# 47-android-selinux.sh charge un module de remplacement avant que quoi que
# ce soit n'ait besoin de l'ancien.
if rpm -q waydroid >/dev/null 2>&1; then
    dnf5 remove -y waydroid waydroid-selinux
    echo "waydroid/waydroid-selinux retires — S les remplace, voir 47-android-selinux.sh."
fi

# --------------------------------------------------------------------------
# lxc/lxc-libs — Waydroid les tirait comme dependance, pas comme un a-cote
# --------------------------------------------------------------------------
# MESURE LE 2026-08-29, EN CONSTRUCTION REELLE : dnf5 a retire lxc et
# lxc-libs comme "dependance inutilisee" en meme temps que waydroid
# ci-dessus — exactement la meme famille de surprise que
# dev-binderfs.mount (voir CLAUDE.md, "la construction echouait"). Sans ce
# paquet, /usr/lib/s/android-lancer.sh echoue avec "lxc-start: Aucun
# fichier ou dossier de ce nom" — trouve sur une machine deja redemarree
# sur l'image, pas en local. Demande explicitement, comme le reste de ce
# que s-android.service utilise : plus rien ici ne doit dependre d'un
# paquet qu'on vient de retirer trois lignes plus haut.
dnf5 install -y lxc lxc-libs

# --------------------------------------------------------------------------
# Le module binder — et pourquoi ce n'est pas inconditionnel
# --------------------------------------------------------------------------
# Waydroid avait besoin de binder ; s-android.service en a besoin pareil, la
# question ne depend pas du gestionnaire. Selon la configuration du noyau, il
# est soit compile dedans (=y, rien a faire), soit un module (=m, a charger
# avant s-android.service, faute de quoi /dev/binder n'est jamais cree).
#
# Poser un /etc/modules-load.d inconditionnel serait faux dans le premier cas :
# systemd tenterait a chaque demarrage de charger un module qui n'existe pas,
# et journaliserait une erreur pour rien. On lit donc la configuration du noyau
# de l'image, et on tranche.

KCONFIG="$(ls /usr/lib/modules/*/config 2>/dev/null | head -n1 || true)"

if [[ -z "${KCONFIG}" ]]; then
    echo "AVERTISSEMENT : aucune configuration de noyau trouvee sous /usr/lib/modules." >&2
    echo "                L'etat de binder reste indetermine — a verifier au jalon 3." >&2
elif grep -q '^CONFIG_ANDROID_BINDER_IPC=m' "${KCONFIG}"; then
    echo "binder est un MODULE dans ${KCONFIG} : chargement au demarrage installe."
    install -d /usr/lib/modules-load.d
    printf 'binder_linux\n' > /usr/lib/modules-load.d/s-binder.conf
elif grep -q '^CONFIG_ANDROID_BINDER_IPC=y' "${KCONFIG}"; then
    echo "binder est COMPILE dans le noyau (${KCONFIG}) : rien a charger."
else
    echo "AVERTISSEMENT : CONFIG_ANDROID_BINDER_IPC introuvable dans ${KCONFIG}." >&2
    echo "                Android pourrait ne pas demarrer — a verifier au jalon 3." >&2
    grep -i binder "${KCONFIG}" >&2 || true
fi

# --------------------------------------------------------------------------
# Le presse-papiers — les deux paquets independants du paquet waydroid
# --------------------------------------------------------------------------
# pyclip et gbinder ne viennent jamais du paquet waydroid (verifie : Fedora
# les distribue a part). Les poser ICI, avant sa suppression plus haut, evite
# tout ordre de dependance a se soucier. Les fichiers qui les UTILISENT
# (android-presse-papiers.py) arrivent par COPY files/ / et sont verifies
# dans 47-android-selinux.sh, apres.

dnf5 install -y python3-pyclip python3-gbinder

for outil in /usr/bin/wl-copy /usr/bin/wl-paste; do
    test -x "${outil}" \
        || { echo "ECHEC : ${outil} absent — pyclip ne pourra pas parler Wayland." >&2; exit 1; }
done

# La regle 1 du depot : rien ne doit se poser hors de /usr et /etc, sans quoi
# l'image serait creuse a l'installation sans qu'une seule etape echoue.
if rpm -ql python3-pyclip 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : python3-pyclip a pose des fichiers hors de /usr." >&2
    exit 1
fi

/usr/bin/python3 -c 'import pyclip' \
    || { echo "ECHEC : python3-pyclip pose mais non importable." >&2; exit 1; }
/usr/bin/python3 -c 'import gbinder' \
    || { echo "ECHEC : python3-gbinder pose mais non importable." >&2; exit 1; }
echo "presse-papiers : pyclip + gbinder poses (le script qui les utilise est verifie apres COPY)."
