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
#
# « --retry-all-errors », ET PAS SEULEMENT « --retry ». Releve le 2026-08-28 :
# une construction a echoue sur « SSL certificate has expired », alors que
# l'horloge de la machine etait saine (NTP) et que f-droid.org repond derriere
# plusieurs noeuds — deux requetes consecutives ont rendu 200 puis 60, a
# quelques secondes d'ecart, le temps que la rotation du certificat Let's
# Encrypt finisse de se propager partout. « --retry » seul ne rejoue QUE les
# pannes que curl juge transitoires (delais, 5xx) ; un echec de verification
# TLS n'en fait pas partie par defaut, et le retry ne se declenchait donc
# jamais. « --retry-all-errors » l'etend a tout, y compris ce cas — une
# nouvelle tentative peut retomber sur un autre noeud, deja a jour.
install -d /usr/share/s/apk
curl -fsSL --retry 3 --retry-all-errors -o /usr/share/s/apk/fdroid.apk https://f-droid.org/F-Droid.apk

# ET ON VERIFIE LA SIGNATURE, PARCE QUE « TEST -S » N'EN EST PAS UNE.
#
# CE QUE CETTE LIGNE REPARE, RELEVE LE 2026-08-26. Jusqu'ici ce fichier se
# contentait de « test -s » — non vide. Vingt lignes plus loin, dans le meme
# depot, 41-windows.sh verifie le sha512 de Proton et SORT EN ECHEC s'il
# differe. Deux telechargements, deux poids et mesures, et le commentaire de
# celui-ci affirmait que l'URL etait « verifiable » alors que rien ne la
# verifiait. La provenance n'est pas la signature.
#
# CE QU'ON VERIFIE, ET AVEC QUOI. F-Droid publie une signature PGP detachee a
# cote de son APK, et documente ses empreintes :
#
#   https://f-droid.org/en/docs/Release_Channels_and_Signing_Keys/
#     cle primaire  37D2 C987 89D8 3119 4839 4E3E 41E7 044E 1DBA 2E89
#     sous-cle      802A 9799 0161 1234 6E1F EFF4 7A02 9E54 DD5D CE7A
#
# C'est la SOUS-CLE qui signe l'APK — verifie le 2026-08-26 en lisant les
# paquets de la signature elle-meme. La cle publique est POSEE DANS LE DEPOT
# (build_files/cles/f-droid.asc), pas telechargee : une cle prise sur le meme
# hote que le fichier qu'elle valide ne prouve rien de plus que l'hote.
# Recuperee de keys.openpgp.org et confrontee aux empreintes ci-dessus.
#
# gpgv plutot que gpg : il ne fait QUE verifier, ne cree aucun trousseau, et
# n'a aucune notion de confiance a configurer. Il vient de « gnupg2-verify »,
# present dans l'image de base — S ne l'installe pas.
#
# EPROUVE DANS LES DEUX SENS le 2026-08-26 : signature valide -> code 0 ; un
# seul octet change dans l'APK -> code 1. Un controle qui ne sait pas echouer
# n'est pas un controle.
CLE_FDROID_ATTENDUE=802A9799016112346E1FEFF47A029E54DD5DCE7A
curl -fsSL --retry 3 --retry-all-errors -o /tmp/fdroid.apk.asc https://f-droid.org/F-Droid.apk.asc

# AUCUN APPEL A « gpg » ICI, ET C'EST UNE CORRECTION PAYEE PAR UNE CONSTRUCTION.
#
# La premiere version de ce controle appelait « gpg --dearmor » et
# « gpg --show-keys ». La construction a echoue a 426 s sur 517 — pile sur cette
# couche, la derniere. La cause n'etait pas la verification : c'est que gpg cree
# son dossier « ~/.gnupg » au premier appel, que « /root » est un LIEN vers
# « var/roothome » sur un systeme ostree, et que ce RUN se termine par
# « ostree container commit », qui refuse du contenu dans /var.
#
# Un outil parfaitement innocent, une verification juste, et une image qui ne se
# construit plus — parce qu'un dossier de travail est tombe dans le seul endroit
# que cette couche doit laisser vide.
#
# gpgv suffit et ne cree rien : il ne fait QUE verifier, avec le trousseau
# qu'on lui donne. Le trousseau est donc pose dans le depot en forme BINAIRE
# (build_files/cles/f-droid.gpg), ce qui supprime le « --dearmor ». GNUPGHOME
# est malgre tout deroute vers /tmp — monte en tmpfs pour ce RUN, donc jamais
# dans l'image — au cas ou une version future de gpgv voudrait ecrire.
#
# Pour relire ou refaire ce trousseau, sur une machine de travail et non ici :
#   gpg --show-keys build_files/cles/f-droid.gpg
#   curl -fsSL 'https://keys.openpgp.org/vks/v1/by-fingerprint/37D2C98789D8311948394E3E41E7044E1DBA2E89' \
#     | gpg --dearmor > build_files/cles/f-droid.gpg
export GNUPGHOME=/tmp/gnupg
install -d -m 700 "$GNUPGHOME"

# L'EMPREINTE EST VERIFIEE SUR LA SORTIE DE gpgv LUI-MEME, et pas a cote : une
# signature valide faite par une AUTRE cle passerait un controle qui se
# contenterait du code de retour. On exige les deux.
if ! gpgv --keyring /ctx/build_files/cles/f-droid.gpg \
          /tmp/fdroid.apk.asc /usr/share/s/apk/fdroid.apk > /tmp/fdroid-verdict 2>&1; then
    cat /tmp/fdroid-verdict >&2
    echo "ECHEC : la signature de F-Droid.apk ne verifie pas." >&2
    exit 1
fi
if ! grep -q "key ${CLE_FDROID_ATTENDUE}" /tmp/fdroid-verdict; then
    cat /tmp/fdroid-verdict >&2
    echo "ECHEC : signature valide, mais faite par une autre cle que celle attendue." >&2
    exit 1
fi
rm -rf /tmp/fdroid.apk.asc /tmp/fdroid-verdict "$GNUPGHOME"
unset GNUPGHOME
echo "  F-Droid : $(stat -c%s /usr/share/s/apk/fdroid.apk) octets, signature verifiee"

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

# LE MOTIF A DU SUIVRE L'APPEL, ET NE PAS L'AVOIR FAIT A COUTE UNE CONSTRUCTION.
#
# Ce controle cherchait « s-lien-windows --recenser ». Le geste reecrit appelle
# desormais « "$S_GESTES/s-lien-windows" --recenser » — avec un GUILLEMET
# FERMANT entre le nom et l'option. La sous-chaine n'existe plus, et la
# construction du 2026-08-26 a 03 h 56 est tombee la.
#
# J'avais raisonne que le motif matcherait quand meme. C'est une supposition,
# pas une mesure, et c'est precisement ce que ce carnet interdit. Le rejeu qui
# aurait du l'attraper ne rejouait que le bloc AJOUTE, jamais le fichier entier.
#
# D'ou grimoire/construction-eprouver-les-motifs.sh : il rejoue TOUS les
# controles par motif de TOUS les scripts contre les fichiers que l'image
# livrera vraiment. Deux secondes, au lieu de quarante minutes de construction.
grep -qE '^\s*"\$S_GESTES/s-lien-windows" --recenser' /usr/bin/s-ouvrir-exe \
    || { echo "ECHEC : s-ouvrir-exe ne recense pas les protocoles." >&2; exit 1; }
echo "  s-ouvrir-exe    : recense les protocoles apres chaque execution"

# ---------------------------------------------------------------------------
# LE WINDOWS DE S EST UNE SESSION, PAS UN LANCEUR — 2026-08-26
# ---------------------------------------------------------------------------
# Mesure sur la machine de l'utilisateur, avec preuve d'ecriture a chaque coup :
#
#   « cmd /c exit » par umu-run            4,53 a 5,12 s, A CHAQUE FOIS
#   wine direct, 1er de la session         1,37 s
#   wine direct, lancements suivants       0,109 s  (huit mesures, ecart 0,004)
#
# CES CONTROLES SONT ICI ET NON DANS 41-windows.sh, ET C'EST UN CORRECTIF.
# Ils y etaient, et la construction du 2026-08-26 a 03 h 37 a echoue pour ca :
# 41-windows.sh tourne a la ligne 63 du Containerfile, « COPY files/ / » a la
# ligne 84. Aucun geste de S n'existe encore a cette etape — le chmod echouait
# sur un fichier absent. Une verification doit s'executer APRES ce qu'elle
# verifie, et c'est exactement ce que dit le commentaire de 36-constellation.
chmod 0755 /usr/bin/s-windows /usr/bin/s-ouvrir-exe /usr/bin/s-menu-windows
bash -n /usr/bin/s-windows
bash -n /usr/bin/s-ouvrir-exe
bash -n /usr/bin/s-menu-windows
bash -n /usr/lib/s/windows.sh
bash -n /usr/lib/s/icone-exe.sh
python3 -m py_compile /usr/lib/s/polices.py
rm -rf /usr/lib/s/__pycache__ 2>/dev/null || true
echo "  s-windows      : syntaxe analysee"

# --- LE SERVEUR RESIDENT ----------------------------------------------------
test -s /usr/lib/systemd/user/s-windows.service \
    || { echo "ECHEC : s-windows.service absent — le Windows de S renaitrait a chaque .exe." >&2; exit 1; }
systemctl --global enable s-windows.service
test -L /etc/systemd/user/s-session.target.wants/s-windows.service \
    || { echo "ECHEC : s-windows.service n'est pas tire par s-session.target." >&2; exit 1; }
echo "  s-windows.service : resident, tire par s-session.target"

# --- LA LETTRE P: A DEMENAGE AVEC LA CREATION DU PREFIXE ---------------------
# On ancre sur l'APPEL et non sur le mot : la version precedente cherchait
# « s-partage » dans s-ouvrir-exe et aurait continue de passer sur une simple
# phrase de commentaire. Meme piege que le garde-fou de plasma_waitforname.
grep -qE '^\s*"\$S_GESTES/s-partage"' /usr/bin/s-windows \
    || { echo "ECHEC : s-windows ne rappelle pas s-partage — la lettre P: ne serait jamais posee." >&2; exit 1; }
echo "  s-windows      : pose la lettre P: apres creation du prefixe"

# --- LE FILET DOIT DESCENDRE LE SERVEUR -------------------------------------
# Mesure du 2026-08-26 : umu-run pendant qu'un wineserver tient le prefixe rend
# AUCUNE FENETRE apres soixante secondes, sans un mot. Un filet qui ne rattrape
# rien tout en ayant l'air de le faire est pire qu'aucun filet.
grep -q 's_windows_pause' /usr/bin/s-ouvrir-exe \
    || { echo "ECHEC : le repli sur umu-run n'arrete pas le serveur resident — il echouerait en silence." >&2; exit 1; }
echo "  s-ouvrir-exe   : le repli arrete le serveur avant de rejouer"

# --- LE VERROU DOIT SUPPORTER D'ETRE REPRIS PAR UN ENFANT --------------------
# s-ouvrir-exe prend le verrou puis appelle « s-windows --preparer », qui prend
# le meme. Sans le garde d'environnement, le tout premier double-clic d'une
# machine neuve attendait dix minutes. Eprouve le 2026-08-26 : l'ancienne forme
# bloque, la nouvelle passe.
grep -q 's_windows_verrou' /usr/bin/s-ouvrir-exe \
    || { echo "ECHEC : s-ouvrir-exe emploie un verrou non reentrant — blocage au premier lancement." >&2; exit 1; }
grep -q 'S_VERROU_WINDOWS' /usr/lib/s/windows.sh \
    || { echo "ECHEC : le verrou de windows.sh n'est pas reentrant." >&2; exit 1; }
echo "  verrou         : reentrant entre s-ouvrir-exe et s-windows"

# --- LA FENETRE NOIRE -------------------------------------------------------
# WPF dessine par Direct3D 9. Quand ce chemin echoue sous Wine, la fenetre
# existe, elle a la bonne taille, et elle ne contient qu'une couleur.
# L'interrupteur de repli logiciel la repare — mais il casse d'autres
# programmes, mesure a l'appui :
#
#                        materiel    logiciel
#   PURPLE (CefSharp)     1 couleur   3133 couleurs
#   PcBoostApp (WPF)      6426        zone centrale absente
#
# Chacun marche la ou l'autre echoue : le reglage est PAR PROGRAMME, et le
# geste porte le nom du symptome pour etre trouvable.
grep -q -- '--fenetre-noire' /usr/bin/s-windows \
    || { echo "ECHEC : s-windows n'offre pas --fenetre-noire — aucun recours contre une fenetre qui ne peint pas." >&2; exit 1; }
grep -q 's_windows_rendu_pose' /usr/bin/s-ouvrir-exe \
    || { echo "ECHEC : s-ouvrir-exe ne pose pas le mode de rendu retenu pour le programme." >&2; exit 1; }
echo "  rendu WPF      : reglable par programme, pose a chaque lancement"

# --- L'EXTRACTEUR D'ICONES --------------------------------------------------
command -v wrestool >/dev/null || { echo "ECHEC : wrestool absent." >&2; exit 1; }
command -v icotool  >/dev/null || { echo "ECHEC : icotool absent." >&2; exit 1; }
grep -q 's_icone_exe' /usr/bin/s-menu-windows \
    || { echo "ECHEC : s-menu-windows ne sort pas l'icone des programmes." >&2; exit 1; }
echo "  icones         : wrestool + icotool, branches dans s-menu-windows"

# --- LE LECTEUR DE NOM DE POLICE --------------------------------------------
# Il decide sous quel nom une police est declaree au registre, et ce nom ne se
# deduit PAS du fichier : SegoeIcons.ttf se declare « Segoe Fluent Icons ». On
# l'eprouve sur une police reelle de l'image plutot que d'esperer.
python3 - <<'ESSAI_POLICES'
import glob
import sys
sys.path.insert(0, "/usr/lib/s")
import polices

candidats = sorted(glob.glob("/usr/share/fonts/**/*.ttf", recursive=True))
assert candidats, "aucune police dans l'image pour eprouver le lecteur"
noms = polices.nom_windows(candidats[0])
assert noms and noms[0].strip(), "le lecteur n'a rendu aucun nom pour %s" % candidats[0]
print("  polices.py     : %s -> %r" % (candidats[0].rsplit("/", 1)[-1], noms[0]))
ESSAI_POLICES

echo "=== 40-coutures : fait ==="
