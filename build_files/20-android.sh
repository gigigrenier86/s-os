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


# --------------------------------------------------------------------------
# LE CONTENEUR DOIT DEMARRER TOUT SEUL — ET IL NE LE FAISAIT PAS
# --------------------------------------------------------------------------
# MESURE DU 2026-08-24, SUR LA MACHINE. binder est bien compile dans le noyau,
# waydroid et lxc sont bien poses, s-android sait tout faire — et pourtant
# Android ne pouvait pas demarrer. La raison tenait en une ligne absente :
#
#   waydroid-container.service etait « disabled ».
#
# Or c'est LUI qui porte « Wants=dev-binderfs.mount ». Et dev-binderfs.mount est
# « static » : sans section [Install], il ne peut PAS etre active directement —
# il ne se declenche que tire par quelqu'un. Personne ne le tirait. Resultat :
# /dev/binderfs jamais monte, /dev/binder jamais cree, et le conteneur Android
# incapable de s'ouvrir meme si tout le reste etait pret.
#
# C'est le defaut le plus cher du projet : le carnet a ecrit « Waydroid n'a
# jamais tourne, c'est pourtant le coeur du projet » pendant cinq jours, pour
# une unite qu'il suffisait d'activer.
systemctl enable waydroid-container.service
echo "waydroid-container.service active — il tire dev-binderfs.mount avec lui."

# L'assertion qui empeche la panne de revenir. « is-enabled » sort en 1 quand
# l'unite est desactivee : sans ce controle, une mise a jour de l'amont qui
# reinitialiserait le preset repasserait inapercue.
systemctl is-enabled waydroid-container.service >/dev/null \
    || { echo "ECHEC : waydroid-container.service n'est pas active." >&2; exit 1; }
test -f /usr/lib/systemd/system/dev-binderfs.mount \
    || { echo "ECHEC : dev-binderfs.mount absent — Waydroid ne pourra pas monter binderfs." >&2; exit 1; }
grep -q 'dev-binderfs.mount' /usr/lib/systemd/system/waydroid-container.service \
    || { echo "ECHEC : le conteneur ne tire plus binderfs — l'amont a change." >&2; exit 1; }
echo "  chaine verifiee : conteneur -> dev-binderfs.mount -> /dev/binder"


# --------------------------------------------------------------------------
# LE PRESSE-PAPIERS LINUX <-> ANDROID — IL EXISTAIT, IL LUI MANQUAIT UN PAQUET
# --------------------------------------------------------------------------
# Le carnet a porte « le presse-papiers Linux/Android n'existe pas » comme un
# chantier a ecrire. C'etait faux : Waydroid le fournit en entier depuis
# l'amont, et personne n'avait regarde.
#
#   /usr/lib/waydroid/tools/interfaces/IClipboard.py
#       publie un service binder « waydroidclipboard », interface
#       « lineageos.waydroid.IClipboard », avec ses deux sens :
#         transaction 1  sendClipboardData  Android a copie -> on ecrit cote Linux
#         transaction 2  getClipboardData   Android veut coller -> on lui rend Linux
#   /usr/lib/waydroid/tools/services/clipboard_manager.py
#       le demarre dans le processus de session (session_manager.py:108),
#       a cote du gestionnaire de notifications.
#
# CE QUI L'ETEIGNAIT, ET POURQUOI PERSONNE NE POUVAIT LE VOIR. Le gestionnaire
# s'ouvre sur un « try: import pyclip » et, si l'import echoue, pose
# canClip = False puis se saute lui-meme :
#
#     logging.debug("Skipping clipboard manager service because of missing
#                    pyclip package")
#
# Niveau DEBUG. Donc invisible sans -v, meme dans /var/lib/waydroid/waydroid.log.
# La session demarre, Android tourne, tout va bien — et la moitie d'une couture
# n'est jamais armee. Le succes silencieux de la regle 2, pris dans une
# dependance optionnelle.
#
# Le paquet « waydroid » de Fedora ne tire pas python3-pyclip, qui existe
# pourtant dans les depots (0.7.0-15.fc44) et se pose entierement dans /usr.
#
# MESURE SUR LA MACHINE, LE 2026-08-25 — deux sessions, une seule variable :
#     avec pyclip  : 7 fils dans le processus de session
#     sans pyclip  : 6 fils
#     avec pyclip  : 7 fils   (reproduit au retour)
# Le fil de difference est celui du gestionnaire. Et pyclip choisit bien son
# moteur Wayland ici — detect_clipboard() rend WaylandClipboard, l'aller-retour
# par wl-copy/wl-paste est exact.
#
# On ne reimplemente donc RIEN. On fournit ce qui manquait.

dnf5 install -y python3-pyclip

# pyclip ne parle pas Wayland tout seul : son moteur appelle wl-copy et
# wl-paste. Sans eux il leve ClipboardSetupException a la premiere copie —
# c'est-a-dire plus tard, chez l'utilisateur, et pas ici.
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

# L'import doit reussir avec le python de l'image, pas avec un autre.
/usr/bin/python3 -c 'import pyclip' \
    || { echo "ECHEC : python3-pyclip pose mais non importable." >&2; exit 1; }

# Et le garde-fou qui compte vraiment : si l'amont deplace ou retire son pont,
# on installerait une dependance pour rien et le presse-papiers retomberait en
# silence. La construction doit echouer ICI, comme pour waydroid-launcher.
test -f /usr/lib/waydroid/tools/services/clipboard_manager.py \
    || { echo "ECHEC : Waydroid n'a plus de clipboard_manager — pont disparu en amont." >&2; exit 1; }
grep -q 'import pyclip' /usr/lib/waydroid/tools/services/clipboard_manager.py \
    || { echo "ECHEC : le pont Waydroid ne depend plus de pyclip — a reexaminer." >&2; exit 1; }
echo "presse-papiers : python3-pyclip pose, pont Waydroid arme (les deux sens)."
