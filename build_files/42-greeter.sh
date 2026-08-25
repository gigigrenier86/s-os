#!/usr/bin/bash
# S — l'ecran de connexion, et le dernier endroit ou la base se montrait.
#
# LA DECOUVERTE QUI A RENDU CE SCRIPT POSSIBLE, ET QUI INVALIDE CE QUE LE
# CARNET SUPPOSAIT : le gestionnaire de connexion de cette image n'est PAS
# SDDM. Fedora 44 a bascule ses variantes KDE vers « Plasma Login Manager »
# (paquet plasma-login-manager), et Bazzite ne reinstalle SDDM que sur ses
# images « deck ». La preuve est dans le journal de construction de S lui-meme,
# ou 36-constellation.sh imprime depuis le premier jour :
#
#     greeter : aucun theme sddm
#
# Ce message etait juste, et personne ne l'avait lu : /usr/share/sddm/themes
# n'existe pas dans cette image. Tout travail sur /etc/sddm.conf, sur un theme
# QML SDDM ou sur « [Theme] Current= » aurait ete un succes silencieux parfait —
# du code correct, applique a un logiciel absent.
#
# CE QUI EST POSSIBLE, ET CE QUI NE L'EST PAS. Plasma Login Manager n'a AUCUN
# systeme de themes : son QML est compile dans le binaire. On ne peut donc pas
# lui dessiner une coquille comme on l'a fait pour la session. Ce qu'on peut
# regler est precisement ce que l'utilisateur nomme : le fond d'ecran, et la
# session preselectionnee.
set -euo pipefail

echo "=== 42-greeter : l'ecran de connexion aux couleurs de S ==="

# LE LOGO DE S EST DANS CE FICHIER, ET C'EST LE SEUL ENDROIT OU IL PEUT ETRE.
# Ce greeter n'ayant pas de themes, on ne peut pas lui AJOUTER un logo : on le
# grave dans le seul pixel qu'il accepte de nous, son fond d'ecran. L'image est
# produite par galerie/foudre-gelee/graver-le-s.ps1 et entre par COPY.
#
# Le fond du BUREAU, lui, reste la Foudre gelee nue — un logo permanent au
# milieu d'un bureau qu'on regarde toute la journee serait une signature, pas
# une identite.
FOND=/usr/share/s/connexion/foudre-gelee-s.png
SESSION=s.desktop

# Le fond d'ecran entre par COPY, donc AVANT ce script. S'il manque, l'image
# afficherait un ecran de connexion vide : on prefere ne pas la livrer.
test -s "$FOND" || { echo "ECHEC : $FOND absent — le COPY a-t-il change ?" >&2; exit 1; }
# Et il doit VRAIMENT porter le logo. Un fichier present mais identique au fond
# nu voudrait dire que le graveur n'a pas tourne — le logo aurait disparu de
# l'ecran de connexion sans qu'une seule etape echoue. Les deux images ne
# different que par la plaque, donc leurs tailles different : c'est le controle
# le moins cher qui distingue les deux.
NU=/usr/share/wallpapers/FoudreGelee/contents/images/3840x2160.png
if [ -s "$NU" ] && cmp -s "$FOND" "$NU"; then
    echo "ECHEC : le fond de connexion est identique au fond nu — logo non grave." >&2
    exit 1
fi
test -s "/usr/share/wayland-sessions/$SESSION" \
    || { echo "ECHEC : la session $SESSION n'existe pas." >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Le fond d'ecran, et la session preselectionnee
# ---------------------------------------------------------------------------
# D'OU VENAIT « LA MAUDITE PHOTO BAZZITE », exactement : Bazzite livre
# /usr/lib/plasmalogin/defaults.conf, qui pointe sur
# /usr/share/backgrounds/default.jxl, lui-meme un lien vers son fond maison
# « convergence.jxl ». C'est le SEUL vecteur de sa marque a cet ecran — le QML
# du greeter n'affiche ni nom de distribution ni logo.
#
# POURQUOI ON REECRIT LE FICHIER DE L'AMONT PLUTOT QUE D'AJOUTER UN FRAGMENT.
# La cascade de Plasma Login Manager va, du plus faible au plus fort :
#   /usr/lib/plasmalogin/plasmalogin.conf.d/*  <  /usr/lib/plasmalogin/defaults.conf
#   <  /etc/plasmalogin.conf.d/*  <  /etc/plasmalogin.conf
# Le support de « plasmalogin.conf.d » est recent et a ete rapporte comme
# ignore sur des versions publiees. On ne parie donc pas dessus : on reecrit le
# fichier du constructeur — c'est le mecanisme que le README de l'amont designe
# lui-meme pour les deploiements geres — et on double dans /etc/plasmalogin.conf,
# qui gagne dans tous les cas.
#
# On garde MOT POUR MOT les noms de cles deja presents chez Bazzite
# (« WallpaperPlugin », pas « WallpaperPluginId ») : le schema de l'amont et
# ses valeurs par defaut ne s'accordent pas sur l'orthographe, et la seule
# forme dont on sache qu'elle est lue par cette version est celle qui marchait
# pour afficher la photo de Bazzite.
ecrire_reglage() {
    cat <<CONF
[Greeter]
# Pose par S. La session de S est preselectionnee : l'utilisateur n'a plus a la
# choisir a chaque connexion. Cette cle l'emporte sur la session memoree — le
# greeter ne retombe sur « la derniere utilisee » que si elle est absente.
# La valeur est un NOM DE FICHIER, pas le nom affiche.
PreselectedSession=${SESSION}
WallpaperPlugin=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file://${FOND}
PreviewImage=file://${FOND}
CONF
}

install -d /usr/lib/plasmalogin
ecrire_reglage > /usr/lib/plasmalogin/defaults.conf
ecrire_reglage > /etc/plasmalogin.conf

echo "  greeter       : fond = Foudre gelee AU LOGO DE S, session preselectionnee = ${SESSION}"

# ---------------------------------------------------------------------------
# 2. « A propos de ce systeme » disait Bazzite malgre os-release
# ---------------------------------------------------------------------------
# 35-identite.sh reecrit NAME, PRETTY_NAME, HOME_URL et LOGO dans os-release,
# et c'est juste. Mais le panneau « A propos » de KDE ne s'y fie qu'EN DERNIER
# RECOURS : il lit d'abord kcm-about-distrorc, et Bazzite en livre un dans
# /etc/xdg qui reecrit les quatre valeurs en dur. Le travail de 35-identite.sh
# etait donc annule a l'endroit meme ou l'utilisateur va verifier le nom de son
# systeme. Encore un succes silencieux, trouve en lisant le code du panneau.
install -d /etc/xdg
cat > /etc/xdg/kcm-about-distrorc <<'CONF'
# Pose par S. Sans ce fichier, celui de la base s'applique et le panneau
# « A propos » annonce Bazzite, quoi que dise os-release.
[General]
LogoPath=/usr/share/icons/hicolor/256x256/apps/s-logo.png
Name=S
Website=https://github.com/gigigrenier86/s-os
Variant=Windows, Linux et Android sur une seule machine
CONF
echo "  a propos      : le panneau annonce S, et non plus la base"

# ---------------------------------------------------------------------------
# 3. L'avatar par defaut
# ---------------------------------------------------------------------------
# Plasma Login Manager n'a AUCUN reglage pour retirer l'avatar : il resout
# /var/lib/AccountsService/icons/<compte>, puis ~/.face.icon, puis une image
# compilee dans le binaire. Le seul levier depuis l'image est donc /etc/skel —
# avec sa limite connue : cela ne sert que les comptes crees ENSUITE.
if [ -s /usr/share/icons/hicolor/256x256/apps/s-logo.png ]; then
    install -Dm0644 /usr/share/icons/hicolor/256x256/apps/s-logo.png /etc/skel/.face.icon
    echo "  avatar        : le logo de S dans /etc/skel (comptes futurs seulement)"
fi

# ---------------------------------------------------------------------------
# Ce qui RESTE a la base, et qu'il faut ecrire plutot que laisser croire
# ---------------------------------------------------------------------------
# L'ecran d'amorcage graphique (Plymouth) est traite depuis le 2026-08-24 par
# build_files/43-amorcage.sh, DESORMAIS BRANCHE dans le Containerfile — il pose
# le logo de S sur le theme « bgrt » et regenere l'initramfs, sans quoi les
# images de l'amont continueraient de s'afficher depuis l'initramfs.
#
# Ce paragraphe disait « NON TRAITE » depuis le premier jour, et c'etait la
# derniere surface de la base que l'utilisateur voyait encore.
echo "  amorcage      : traite par 43-amorcage.sh (branche) — initramfs regenere"

# La liste des sessions du greeter, elle, ne se filtre pas : Plasma Login
# Manager liste tous les .desktop de wayland-sessions SANS honorer NoDisplay,
# contrairement a SDDM. Le NoDisplay pose par 36-constellation.sh est donc
# inoperant ICI. On ne supprime pas les sessions de l'amont pour autant — un
# bureau arrache ne se remet pas d'un clic — et la preselection ci-dessus rend
# la question sans consequence : on ne choisit plus, on se connecte.
echo "  sessions      : NoDisplay inoperant sur ce greeter — la preselection y supplee"

test -s /usr/lib/plasmalogin/defaults.conf || { echo "ECHEC : defaults.conf absent." >&2; exit 1; }
test -s /etc/plasmalogin.conf              || { echo "ECHEC : plasmalogin.conf absent." >&2; exit 1; }
test -s /etc/xdg/kcm-about-distrorc        || { echo "ECHEC : kcm-about-distrorc absent." >&2; exit 1; }
grep -q "PreselectedSession=${SESSION}" /etc/plasmalogin.conf \
    || { echo "ECHEC : la session preselectionnee n'est pas ecrite." >&2; exit 1; }

echo "=== 42-greeter : fait ==="
