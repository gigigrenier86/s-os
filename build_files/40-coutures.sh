#!/usr/bin/bash
# Les coutures : ce qui relie un double-clic au monde qui sait l'ouvrir.
#
# Aucun moteur n'est ajoute ici — umu-run, distrobox, flatpak et waydroid sont
# deja dans la base. Ce qui manquait, ce sont les gestes : quatre formats de
# fichier n'avaient AUCUN gestionnaire, et le .deb s'ouvrait dans l'archiveur.
set -euo pipefail
echo "=== 40-coutures : les gestes qui manquaient ==="

# Le bit d'execution ne survit pas a un depot clone sous Windows. On le repose
# ici plutot que de dependre de ce que git a bien voulu enregistrer.
chmod 0755 /usr/bin/s-monde /usr/bin/s-ouvrir-* /usr/bin/s-menu-windows \
           /usr/bin/s-android /usr/bin/s-play-store

# --- Un magasin de secours, a provenance certaine ---------------------------
# Le Play Store arrive avec l'image GAPPS de Waydroid, telechargee au premier
# usage. F-Droid est pose en plus : c'est la seule boutique Android dont l'APK
# ait une URL stable et verifiable, et elle sert si Google refuse l'appareil.
install -d /usr/share/s/apk
curl -fsSL --retry 3 -o /usr/share/s/apk/fdroid.apk https://f-droid.org/F-Droid.apk
test -s /usr/share/s/apk/fdroid.apk
echo "  F-Droid : $(stat -c%s /usr/share/s/apk/fdroid.apk) octets"

# --- Les types que Windows connait et que Linux ignore ----------------------
# .AppImage et .msi n'ont pas de type declare sur une Fedora nue : sans cela,
# aucune association n'est possible et le double-clic ne peut rien faire.
# Le fichier de types (files/usr/share/mime/packages/s-formats.xml) est pose
# par COPY. On ne fait ici que reconstruire les index qui en dependent.
test -s /usr/share/mime/packages/s-formats.xml || { echo "ECHEC : s-formats.xml absent." >&2; exit 1; }

# --- Qui ouvre quoi ---------------------------------------------------------
# /etc/xdg vaut pour tous les comptes et se laisse surcharger par l'utilisateur :
# c'est le bon etage pour un defaut, et le seul qui survive a une mise a jour.
# Les associations elles-memes sont un fichier statique, pose par COPY :
# files/etc/xdg/mimeapps.list. Un defaut est de la donnee, pas du code.
test -s /etc/xdg/mimeapps.list || { echo "ECHEC : mimeapps.list absent." >&2; exit 1; }

update-mime-database /usr/share/mime >/dev/null 2>&1 || true
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
# Le logo s-logo entre par COPY dans hicolor, et os-release y fait reference
# depuis 35-identite.sh — qui tourne AVANT le COPY et ne peut donc pas le
# verifier lui-meme. L'assertion vit ici. Sans cache reconstruit, une icone
# nouvelle peut rester invisible jusqu'a la prochaine reindexation.
test -s /usr/share/icons/hicolor/256x256/apps/s-logo.png || { echo "ECHEC : s-logo.png absent." >&2; exit 1; }
gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true

# --- Controle : rien ne doit avoir atterri hors de /usr et /etc -------------
# Sur un systeme ostree, /var et /opt ne sont PAS transportes par l'image :
# un fichier pose la disparait, et l'image part vide sans que rien n'echoue.
if find /var /opt -maxdepth 3 -name 's-*' -o -maxdepth 3 -name 'fdroid.apk' 2>/dev/null | grep -q .; then
    echo "ECHEC : une couture a ete posee hors de /usr et /etc." >&2; exit 1
fi

echo "  associations posees : $(grep -c '=' /etc/xdg/mimeapps.list) types"
echo "=== 40-coutures : fait ==="
