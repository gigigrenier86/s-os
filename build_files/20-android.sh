#!/usr/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------------
# Android — et ce qu'on ne fait PAS
# --------------------------------------------------------------------------
# Bazzite fournit sa propre recette Waydroid : « ujust configure-waydroid ».
# Elle installe le conteneur, propose la traduction ARM (libhoudini ou libndk,
# jamais les deux), les services Google ou microG, et elle est maintenue en
# amont. La reimplementer serait la seule facon de se tromper ici.
#
# On verifie en revanche qu'elle est toujours la. Si Bazzite la deplace ou la
# retire un jour, la construction doit echouer ICI, bruyamment — plutot que de
# livrer un OS dont la brique Android a disparu en silence.

if [[ ! -x /usr/bin/waydroid-launcher ]]; then
    echo "ECHEC : /usr/bin/waydroid-launcher est absent de l'image de base." >&2
    echo "        Bazzite portait cette brique ; elle l'a peut-etre retiree." >&2
    echo "        Voir build_files/20-android.sh et la documentation amont." >&2
    exit 1
fi

# --------------------------------------------------------------------------
# Le module binder — et pourquoi ce n'est pas inconditionnel
# --------------------------------------------------------------------------
# Waydroid a besoin de binder. Selon la configuration du noyau, il est soit
# compile dedans (=y, rien a faire), soit un module (=m, a charger avant
# waydroid-container.service, faute de quoi /dev/binder n'est jamais cree).
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
    echo "                Waydroid pourrait ne pas demarrer — a verifier au jalon 3." >&2
    grep -i binder "${KCONFIG}" >&2 || true
fi
