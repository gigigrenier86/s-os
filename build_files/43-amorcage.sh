#!/usr/bin/bash
# S — l'ecran d'amorcage graphique.
#
# CE SCRIPT N'EST PAS BRANCHE DANS LE Containerfile, ET C'EST DELIBERE.
# Pour l'activer, ajouter le RUN correspondant avant 40-coutures.sh. Lire
# d'abord ce qui suit : c'est le seul changement de tout ce depot qui puisse
# rendre la machine incapable de demarrer.
#
# ---------------------------------------------------------------------------
# CE QUE L'UTILISATEUR VOIT, ET D'OU CA VIENT
# ---------------------------------------------------------------------------
# Le theme Plymouth de cette image est « bgrt » (mesure dans le journal de
# construction de S). Il declare « ImageDir=<themes>/spinner » : l'image de
# marque affichee est donc /usr/share/plymouth/themes/spinner/watermark.png —
# que Fedora fournit et que Bazzite remplace par la sienne. Plymouth est en
# outre compile avec « -Dlogo=/usr/share/pixmaps/system-logo-white.png », que
# Bazzite ecrase aussi.
#
# ---------------------------------------------------------------------------
# POURQUOI REMPLACER LES IMAGES NE SUFFIT PAS
# ---------------------------------------------------------------------------
# Le script officiel « plymouth-populate-initrd » copie DANS L'INITRAMFS le
# fichier de logo, tout le dossier du theme, et — quand ImageDir en differe,
# ce qui est exactement le cas ici — le dossier d'images en plus. Les deux
# fichiers vivent donc en double : dans /usr, et dans l'initramfs. C'est
# l'initramfs qui s'affiche a l'amorcage.
#
# Remplacer les images sans regenerer l'initramfs serait donc du travail
# correct et parfaitement invisible. Le carnet a un nom pour ca, et c'est la
# raison pour laquelle ce script fait les deux ou rien.
#
# ---------------------------------------------------------------------------
# LE RISQUE, EN CLAIR
# ---------------------------------------------------------------------------
# Un initramfs mal construit ne se voit pas a la construction, ni au controle
# de l'image, ni au telechargement : il se voit au demarrage suivant, sous la
# forme d'une machine qui ne demarre plus. Le filet prevu pour ce cas est
# « bootc rollback », et le carnet dit depuis le premier jour qu'il N'A JAMAIS
# ETE EXERCE.
#
# La methode ci-dessous est celle que Bazzite et BlueBuild emploient en
# production tous les jours — elle n'est pas de mon invention. Mais elle n'a
# jamais tourne ici, et « ca marche chez eux » n'est pas une mesure.
#
# A FAIRE AVANT DE BRANCHER CE SCRIPT :
#   1. exercer « bootc rollback » une fois, pour de vrai ;
#   2. brancher ce script seul, sans aucun autre changement dans la meme
#      version — une seule variable a la fois, c'est la lecon du halt de QEMU.
set -euo pipefail

echo "=== 43-amorcage : l'ecran d'amorcage aux couleurs de S ==="

LOGO=/usr/share/icons/hicolor/256x256/apps/s-logo.png
test -s "$LOGO" || { echo "ECHEC : $LOGO absent." >&2; exit 1; }

# --- 1. Les deux images de marque -------------------------------------------
# On garde le theme « bgrt » de l'amont plutot que d'en ecrire un nouveau :
# il affiche le logo du micrologiciel en fond, ce qui donne un amorcage sans
# rupture, et son script gere les invites de mot de passe LUKS. Refaire cela
# serait le refaire moins bien — et un theme neuf sans les invites de saisie
# rendrait un disque chiffre inutilisable.
for cible in /usr/share/plymouth/themes/spinner/watermark.png \
             /usr/share/pixmaps/system-logo-white.png; do
    if [ -e "$cible" ]; then
        install -Dm0644 "$LOGO" "$cible"
        echo "  image posee   : $cible"
    else
        echo "  ABSENT        : $cible — l'amont a change, verifier avant de continuer"
    fi
done

# --- 2. Regenerer l'initramfs ------------------------------------------------
# « --no-hostonly » est OBLIGATOIRE : on construit dans un conteneur, qui n'a
# ni le materiel de la machine cible ni son /lib/modules. Sans ce drapeau,
# dracut echoue, ou pire, produit un initramfs taille pour le conteneur.
#
# « --reproducible » n'est pas cosmetique : sans lui, chaque construction
# quotidienne produirait des octets differents pour un contenu identique, donc
# une nouvelle couche de ~100 Mo a telecharger a CHAQUE « bootc upgrade ».
# Avec lui, la couche ne change que quand le noyau ou le contenu changent.
# C'est la regle 11 du carnet appliquee a l'initramfs.
#
# L'image va dans /usr/lib/modules/<version>/initramfs.img, jamais dans /boot :
# sur un systeme ostree, /boot est gere par le deploiement.
NOYAUX=(/usr/lib/modules/*/)
if [ "${#NOYAUX[@]}" -ne 1 ]; then
    echo "ECHEC : ${#NOYAUX[@]} noyaux dans /usr/lib/modules — ce script en attend un seul." >&2
    exit 1
fi
KVER="$(basename "${NOYAUX[0]}")"
echo "  noyau         : $KVER"

dracut --no-hostonly --kver "$KVER" --reproducible --zstd \
       --add ostree --force "/usr/lib/modules/${KVER}/initramfs.img"
chmod 0600 "/usr/lib/modules/${KVER}/initramfs.img"

test -s "/usr/lib/modules/${KVER}/initramfs.img" \
    || { echo "ECHEC : l'initramfs n'a pas ete produit." >&2; exit 1; }
echo "  initramfs     : regenere ($(stat -c%s "/usr/lib/modules/${KVER}/initramfs.img") octets)"

echo "=== 43-amorcage : fait ==="
