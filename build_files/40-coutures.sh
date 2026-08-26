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
           /usr/bin/s-android /usr/bin/s-play-store \
           /usr/bin/s-diagnostic /usr/bin/s-nettoyer \
           /usr/bin/s-magasin-android

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
# Meme raison pour le fond d'ecran : 35-identite.sh le declare par defaut
# avant que le COPY ne le pose — c'est ici qu'on verifie qu'il est bien la.
test -s /usr/share/wallpapers/FoudreGelee/contents/images/3840x2160.png || { echo "ECHEC : Foudre gelee absente." >&2; exit 1; }
test -s /usr/share/wallpapers/FoudreGelee/metadata.json || { echo "ECHEC : metadata.json de Foudre gelee absent." >&2; exit 1; }
gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true

# --- Controle : rien ne doit avoir atterri hors de /usr et /etc -------------
# Sur un systeme ostree, /var et /opt ne sont PAS transportes par l'image :
# un fichier pose la disparait, et l'image part vide sans que rien n'echoue.
if find /var /opt -maxdepth 3 -name 's-*' -o -maxdepth 3 -name 'fdroid.apk' 2>/dev/null | grep -q .; then
    echo "ECHEC : une couture a ete posee hors de /usr et /etc." >&2; exit 1
fi

echo "  associations posees : $(grep -c '=' /etc/xdg/mimeapps.list) types"

# --- LE DOSSIER PARTAGE : la couture que le carnet reclamait -----------------
# « Les coutures n'existent pas : menu unique, dossier partage entre les trois
# mondes, presse-papiers commun. C'est ce qui ferait de S autre chose qu'une
# Bazzite avec des logiciels en plus. » — LISEZ-MOI.md, depuis le 2026-08-20.
#
# Le menu unique existait deja (Constellation, plus s-menu-windows et les
# .desktop que Waydroid pose pour ses applications). Le dossier partage, non.
# Il existe maintenant : un seul dossier, trois noms.
chmod 0755 /usr/bin/s-partage
bash -n /usr/bin/s-partage
echo "  s-partage     : syntaxe analysee"

test -s /usr/lib/systemd/system/s-partage.service \
    || { echo "ECHEC : s-partage.service absent." >&2; exit 1; }
systemctl enable s-partage.service
systemctl is-enabled s-partage.service >/dev/null \
    || { echo "ECHEC : s-partage.service n'est pas active." >&2; exit 1; }
echo "  s-partage     : service active (apres le conteneur Android)"

# LA LETTRE P: A DEMENAGE, ET CETTE VERIFICATION AVEC ELLE — 2026-08-26.
#
# La creation du prefixe est passee de s-ouvrir-exe a « s-windows --preparer »
# quand le Windows de S est devenu une session residente. Le controle qui vivait
# ici cherchait « s-partage » dans s-ouvrir-exe ; il aurait CONTINUE DE PASSER,
# parce qu'il reste une phrase de commentaire qui nomme s-partage dans ce
# fichier — sans qu'aucun appel n'y soit plus.
#
# C'est le meme piege que le garde-fou de plasma_waitforname, ecrit la veille :
# une verification qui lit de la documentation et croit lire du code. Elle est
# donc reecrite dans 41-windows.sh, ancree sur l'APPEL et non sur le mot.


# --- LES LIENS QUE WINDOWS ENREGISTRE ---------------------------------------
# Un logiciel Windows moderne se connecte en renvoyant vers
# « monappli://callback?token=... ». Il inscrit ce protocole dans le registre
# DU PREFIXE ; Linux ne le lit pas, et le retour de connexion tombe dans le
# vide. Mesure du 2026-08-24 : c'est ce qui rendait Cursor inutilisable — on
# cliquait « Login », il ne se passait rien, et le journal repetait
# « Authorization omitted: no access token » toutes les trente secondes.
chmod 0755 /usr/bin/s-lien-windows
bash -n /usr/bin/s-lien-windows
python3 -m py_compile /usr/lib/s/registre.py
rm -rf /usr/lib/s/__pycache__ 2>/dev/null || true
echo "  s-lien-windows : syntaxe analysee"

# Le lecteur de registre a deja echoue deux fois sur l'echappement de Wine :
# on l'eprouve sur un registre fabrique plutot que d'esperer.
python3 - <<'ESSAI'
import sys, tempfile, os
sys.path.insert(0, "/usr/lib/s")
import registre
d = tempfile.mkdtemp()
open(os.path.join(d, "user.reg"), "w", encoding="utf-8").write(
    '[Software\\\\Classes\\\\essai] 1787620468\n'
    '@="URL:essai"\n'
    '"URL Protocol"=""\n\n'
    '[Software\\\\Classes\\\\essai\\\\shell\\\\open\\\\command] 1787620468\n'
    '@="\\"C:\\\\Program Files\\\\App\\\\App.exe\\" --open-url -- \\"%1\\""\n\n'
    '[Software\\\\Classes\\\\App.txt] 1787620447\n'
    '@="Fichier texte"\n'
)
p = registre.protocoles(d)
assert list(p) == ["essai"], "protocoles trouves : %r" % p
assert p["essai"] == '"C:\\Program Files\\App\\App.exe" --open-url -- "%1"', p["essai"]
print("  registre.py    : protocole extrait, type de fichier ecarte")
ESSAI

test -s /usr/lib/systemd/user/s-session.target \
    || { echo "ECHEC : s-session.target absente — le portail XDG ne demarrerait jamais." >&2; exit 1; }
grep -q 'BindsTo=graphical-session.target' /usr/lib/systemd/user/s-session.target \
    || { echo "ECHEC : s-session.target ne tire pas graphical-session.target." >&2; exit 1; }
grep -q 's-session.target' /usr/bin/s-coquille \
    || { echo "ECHEC : la coquille ne leve pas la session graphique." >&2; exit 1; }
echo "  session systemd : s-session.target -> graphical-session.target -> portail XDG"

grep -q 's-lien-windows --recenser' /usr/bin/s-ouvrir-exe \
    || { echo "ECHEC : s-ouvrir-exe ne recense pas les protocoles." >&2; exit 1; }
echo "  s-ouvrir-exe    : recense les protocoles apres chaque execution"

echo "=== 40-coutures : fait ==="
