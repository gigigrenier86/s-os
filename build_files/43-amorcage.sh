#!/usr/bin/bash
# S — l'ecran d'amorcage graphique.
#
# BRANCHE DANS LE Containerfile DEPUIS LE 2026-08-24, sur demande explicite
# de l'utilisateur — voir le commentaire pose a cote du RUN correspondant.
# Le paragraphe qui suivait ici disait encore « ce script n'est pas branche,
# et c'est delibere » : c'etait vrai le jour ou ce script a ete ecrit, faux
# depuis. Il est resurgi ce soir-la parce que personne ne l'avait relu apres
# l'avoir branche — la meme faute que ce depot reproche ailleurs a un
# commentaire perime. La precaution qu'il demandait (exercer un vrai
# « bootc rollback » avant de brancher) etait deja satisfaite : voir CLAUDE.md,
# 2026-08-25, 19 h 49 — le rollback a ete exerce pour de vrai et fonctionne.
# Cette etape regenere l'initramfs a chaque construction depuis ; c'est
# toujours le seul changement de ce depot qui puisse rendre la machine
# incapable de demarrer, et c'est pour ca qu'il reste seul dans son propre
# script plutot que noye dans les coutures.
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
# LE RISQUE, EN CLAIR — ET CE QUI LE COUVRE
# ---------------------------------------------------------------------------
# Un initramfs mal construit ne se voit pas a la construction, ni au controle
# de l'image, ni au telechargement : il se voit au demarrage suivant, sous la
# forme d'une machine qui ne demarre plus. Le filet est « bootc rollback » —
# exerce pour de vrai le 2026-08-25 (huit secondes, zero octet de reseau,
# CLAUDE.md le date) et redemontre depuis a chaque mise a jour normale de S.
#
# La methode ci-dessous est celle que Bazzite et BlueBuild emploient en
# production tous les jours. Elle tourne ici aussi, en production, depuis le
# 2026-08-24 : cette machine a redemarre plusieurs fois sur des images
# construites par ce script sans jamais echouer a amorcer.
set -euo pipefail

echo "=== 43-amorcage : l'ecran d'amorcage aux couleurs de S ==="

LOGO=/usr/share/icons/hicolor/256x256/apps/s-logo.png
test -s "$LOGO" || { echo "ECHEC : $LOGO absent." >&2; exit 1; }

# Le filigrane d'amorcage n'est PAS le meme fichier que l'icone de 256 px.
# Demande explicite du 2026-08-30 : « rends ca spectaculaire au demarrage ».
# « two-step » (le module du theme spinner) place son filigrane par un simple
# alignement fractionnaire (WatermarkVerticalAlignment=.96, mesure dans
# /usr/share/plymouth/themes/spinner/spinner.plymouth de cette image) — il ne
# le redimensionne jamais, la taille a l'ecran EST la taille du fichier. Un
# fichier plus grand se voit donc vraiment plus grand, sans rien configurer
# d'autre. 816 px, halo inclus dans l'image elle-meme (Plymouth ne fait aucun
# fondu lui-meme) : mesure geometriquement pour rester sous la ligne du
# spinner (Alignment=.7, soit 70 % de la hauteur de l'ecran) sur un ecran
# 1080p — au-dela, les deux se chevaucheraient.
FILIGRANE=/usr/share/s/marque/s-logo-amorcage.png
test -s "$FILIGRANE" || { echo "ECHEC : $FILIGRANE absent." >&2; exit 1; }

# --- 1. Les images de marque -------------------------------------------------
# On garde le theme « bgrt » de l'amont plutot que d'en ecrire un nouveau :
# il affiche le logo du micrologiciel en fond, ce qui donne un amorcage sans
# rupture, et son script gere les invites de mot de passe LUKS. Refaire cela
# serait le refaire moins bien — et un theme neuf sans les invites de saisie
# rendrait un disque chiffre inutilisable.
if [ -e /usr/share/plymouth/themes/spinner/watermark.png ]; then
    install -Dm0644 "$FILIGRANE" /usr/share/plymouth/themes/spinner/watermark.png
    echo "  image posee   : /usr/share/plymouth/themes/spinner/watermark.png (filigrane, 816 px)"
else
    echo "  ABSENT        : watermark.png — l'amont a change, verifier avant de continuer"
fi
if [ -e /usr/share/pixmaps/system-logo-white.png ]; then
    install -Dm0644 "$LOGO" /usr/share/pixmaps/system-logo-white.png
    echo "  image posee   : /usr/share/pixmaps/system-logo-white.png (icone, 256 px)"
else
    echo "  ABSENT        : system-logo-white.png — l'amont a change, verifier avant de continuer"
fi

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
