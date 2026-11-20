#!/usr/bin/bash
# S-Constellation : S cesse d'etre une base habillee et devient une session.
#
# CE QUE CETTE ETAPE CHANGE, ET IL FAUT LE DIRE NETTEMENT :
# jusqu'ici Constellation etait une page ouverte dans une fenetre, par-dessus
# le bureau de la base. Elle devient LA session — le greeter propose « S », et
# ce que S lance n'est plus la coquille de l'amont mais la sienne.
#
# CE QUI A CHANGE LE 2026-08-24 : LA COQUILLE N'EST PLUS UNE PAGE WEB.
# Elle etait servie en HTTP sur 127.0.0.1:7373 par s-etoiles et affichee par
# Vivaldi lance en « --app ». C'est fini. Constellation est un client Wayland
# natif (QtQuick), et il appelle le noyau de S dans son propre processus.
# Consequences, toutes voulues :
#   - le bureau ne depend plus d'un navigateur ni de ses mises a jour ;
#   - plus aucun port n'est ouvert sur la machine ;
#   - LE CLIC DROIT EST CELUI DU BUREAU, et non plus celui du navigateur.
#
# CE QUE CETTE ETAPE NE CHANGE TOUJOURS PAS : le compositeur. Voir s-session
# pour le raisonnement — c'est la seule piece d'un bureau que personne ne voit.
#
# Rien ici ne desinstalle quoi que ce soit. Une image atomique se repare par
# « bootc rollback », mais un bureau arrache ne se remet pas d'un clic : on
# MASQUE la session d'origine, on ne la supprime pas, et on en garde une entree
# de secours explicitement nommee.
set -euo pipefail
echo "=== 36-constellation : la session S ==="

QML=/usr/share/s/constellation/qml

# --- Ce dont la coquille depend, verifie plutot que suppose ----------------
COMPOSITEUR=""
for essai in kwin_wayland labwc; do
    if command -v "$essai" >/dev/null 2>&1; then COMPOSITEUR="$essai"; break; fi
done
[[ -n "$COMPOSITEUR" ]] || { echo "ECHEC : aucun compositeur Wayland dans la base." >&2; exit 1; }
echo "  compositeur   : $(command -v "$COMPOSITEUR")"

command -v python3 >/dev/null 2>&1 \
    || { echo "ECHEC : python3 absent — la coquille ne peut pas tourner." >&2; exit 1; }
echo "  interprete    : $(python3 --version)"

# LE MOTEUR DE RENDU N'EST PLUS VIVALDI, ET C'EST TOUT L'OBJET DE CETTE VERSION.
# On n'exige donc plus /usr/lib/opt/vivaldi/vivaldi ici. Le navigateur reste
# pose dans l'image — c'est une application, plus une piece du bureau.

# --- Qt pour Python : le moteur de la coquille ----------------------------
# POURQUOI python3-pyside6 ET NON qt6-qtdeclarative-devel. Les deux apportent de
# quoi faire tourner du QML. Le second le fait par l'outil « qml », qui vit dans
# un paquet de developpement et tirerait cmake et pkg-config dans une image de
# bureau. Le premier permet en plus a la coquille d'appeler le noyau de S
# DIRECTEMENT, dans le meme processus, sans pont ni port.
# ROBOTO, POUR LE THEME ANDROID (ajoute le 2026-10-21 avec les themes). La
# police d'Android est le premier signe qu'on y est ; sans elle, Theme.qml
# retombe sur Noto Sans et le theme ressemble a un bureau Linux deguise. Paquet
# Fedora, Apache-2.0 et CC0, 4,2 Mio. Celle de Windows (Segoe) n'a pas
# d'equivalent libre dans les depots, et elle appartient a Microsoft : le
# theme Windows la prend si l'utilisateur l'a, sinon Selawik, Open Sans, Noto.
dnf5 install -y python3-pyside6 ibm-plex-sans-fonts ibm-plex-mono-fonts google-roboto-fonts

# Regle 2 du carnet : une installation qui atterrit hors de /usr livrerait une
# image creuse sans que rien ne le dise.
if rpm -ql python3-pyside6 ibm-plex-sans-fonts ibm-plex-mono-fonts google-roboto-fonts \
   | grep -qE '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : un paquet est pose hors de /usr." >&2
    exit 1
fi
python3 -c 'import PySide6, PySide6.QtQuick; print("  PySide6       :", PySide6.__version__)'
# Regle 5 : une ligne de rapport ne fait jamais tomber une image saine.
echo "  polices       : $(fc-list 2>/dev/null | grep -ci 'IBM Plex' || true) fichiers IBM Plex" || true
echo "  polices       : $(fc-list 2>/dev/null | grep -ci 'Roboto' || true) fichiers Roboto" || true

# --- Les gestes de la session ---------------------------------------------
# Le bit d'execution ne survit pas a un depot edite sous Windows ; on le repose
# plutot que de dependre de ce que git a bien voulu enregistrer.
chmod 0755 /usr/bin/s-session /usr/bin/s-coquille /usr/bin/s-constellation \
    /usr/bin/s-chrome /usr/bin/s-salon-session /usr/bin/s-salon-rapide \
    /usr/bin/s-retro-rapide

# Une faute de syntaxe ne se verrait qu'au premier ouverture de session,
# c'est-a-dire sur un ecran noir. Elle se voit ici en une seconde.
bash -n /usr/bin/s-session
bash -n /usr/bin/s-coquille
bash -n /usr/bin/s-salon-session
bash -n /usr/bin/s-salon-rapide
bash -n /usr/bin/s-retro-rapide
python3 -m py_compile /usr/bin/s-constellation /usr/bin/s-chrome /usr/lib/s/noyau.py
# LE CACHE DISQUE DE QML DOIT RESTER COUPE. Qt ne l'ecrit jamais pour des sources
# a date epoch 0 (tout /usr sur ostree) mais relit sans verifier celui qu'un essai
# a date reelle a laisse dans ~/.cache : la coquille executait la barre et le
# bureau du 7 septembre, neuf commits QML plus tard. Voir s-constellation.
grep -qF 'os.environ["QML_DISK_CACHE"] = "none"' /usr/bin/s-constellation \
    || { echo "ECHEC : s-constellation ne coupe plus le cache disque de QML — un ancien cache perime pourrait servir a la place du QML deploye." >&2; exit 1; }
grep -qF 'os.environ["QML_DISK_CACHE"] = "none"' /usr/bin/s-chrome \
    || { echo "ECHEC : s-chrome ne coupe plus le cache disque de QML — meme peril que s-constellation." >&2; exit 1; }
# LA VARIABLE LAYER-SHELL NE DOIT PAS FUIR VERS CE QUE LA BARRE LANCE. Qt choisit
# l'integration au demarrage de l'application (mesure du 2026-11-19, kwin 6.8.3) :
# la retirer de l'environnement juste apres QGuiApplication ne change rien pour
# la barre, et evite que tout programme Qt lance depuis une epinglee (Dolphin,
# Konsole, Kate) devienne une surface de couche plein ecran, non gerable, dont
# le bas passe sous la barre. Sans cette ligne la construction reste verte :
# c'est une panne d'usage, que rien d'autre ne voit.
grep -qF 'os.environ.pop("QT_WAYLAND_SHELL_INTEGRATION", None)' /usr/bin/s-chrome \
    || { echo "ECHEC : s-chrome ne retire plus QT_WAYLAND_SHELL_INTEGRATION de son environnement — tout programme Qt lance depuis la barre redeviendrait une surface de couche plein ecran." >&2; exit 1; }
# LA BARRE RESERVE SA PLACE, ET LES DEUX AUTRES SURFACES LA LUI LAISSENT. Sans
# zone d'exclusion, une fenetre maximisee ou haute finit sous la barre (bas 1080
# au lieu de 1028). Avec elle, les surfaces a zone 0 sont repoussees (laterale
# 1028 de haut, bulle 52 px trop haut) : -1 les laisse ou elles sont.
grep -qF 'LayerShell.Window.exclusionZone: barre.hauteur' /usr/share/s/constellation/qml/Barre.qml \
    || { echo "ECHEC : Barre.qml ne reserve plus sa place (exclusionZone) — les fenetres maximisees repasseraient sous la barre." >&2; exit 1; }
for qml in BarreLaterale Bulle; do
    grep -qF 'LayerShell.Window.exclusionZone: -1' "/usr/share/s/constellation/qml/$qml.qml" \
        || { echo "ECHEC : $qml.qml n'ignore plus la zone reservee de la barre (exclusionZone -1) — kwin la repousserait de 52 pixels." >&2; exit 1; }
done
rm -rf /usr/bin/__pycache__ /usr/lib/s/__pycache__ /root/.cache 2>/dev/null || true
echo "  syntaxe       : session, coquille, coquille native et noyau analyses"

# Le noyau doit s'importer, pas seulement se compiler : un import casse ne se
# verrait, la encore, qu'a la premiere connexion.
python3 -c "import sys; sys.path.insert(0, '/usr/lib/s'); import noyau; noyau.inventaire()" \
    || { echo "ECHEC : /usr/lib/s/noyau.py ne s'importe pas." >&2; exit 1; }
echo "  noyau         : importe, inventaire parcouru"

# LE SERVICE DE NOTIFICATIONS DOIT S'IMPORTER, ET SES DEUX BIBLIOTHEQUES ETRE LA.
# Il tient a PySide6 ET a dbus-python : si l'une des deux disparaissait d'une
# reconstruction de la base, la coquille demarrerait sans bulles et personne ne
# le saurait avant qu'un geste reste muet.
python3 -c "
import sys; sys.path.insert(0, '/usr/lib/s')
import notifications
assert notifications.NOM == 'org.freedesktop.Notifications'
" || { echo "ECHEC : /usr/lib/s/notifications.py ne s'importe pas." >&2; exit 1; }
echo "  notifications : importe"

# LA BARRE DES TACHES TIENT A DEUX FICHIERS, ET L'UN N'EST PAS DU PYTHON. Le
# rapporteur est un script kwin : s'il manquait, la barre s'ouvrirait vide et
# rien n'echouerait — l'utilisateur croirait qu'aucune fenetre n'est ouverte.
python3 -c "
import sys; sys.path.insert(0, '/usr/lib/s')
import fenetres
assert fenetres.NOM == 'org.s.Constellation'
" || { echo "ECHEC : /usr/lib/s/fenetres.py ne s'importe pas." >&2; exit 1; }
test -s /usr/lib/s/fenetres.js \
    || { echo "ECHEC : /usr/lib/s/fenetres.js absent — barre sans fenetres." >&2; exit 1; }
test -s /usr/lib/s/regles-kwin.py \
    || { echo "ECHEC : /usr/lib/s/regles-kwin.py absent." >&2; exit 1; }
echo "  barre         : rapporteur et regles en place"

# LE FOURNISSEUR DE PLASMA DOIT ETRE RECOUVERT. L'original lance
# « plasma_waitforname », qui attend pour toujours dans une session sans
# plasmashell — c'est la panne qui a gele toutes les coutures le 2026-08-25.
# Le COPY doit l'avoir remplace ; si un jour il ne le fait plus, on veut
# l'apprendre ici et non par un geste qui ne rend jamais la main.
SERVICE_NOTIF=/usr/share/dbus-1/services/org.kde.plasma.Notifications.service
# ET ON REGARDE LA LIGNE Exec, PAS LE FICHIER. La premiere version de ce
# controle cherchait « plasma_waitforname » n'importe ou — et le trouvait dans
# le commentaire qui explique ce qu'on remplace. Un garde-fou qui lit sa propre
# documentation comme une preuve du defaut : construction rouge, code juste.
if grep -qE '^[[:space:]]*Exec=.*plasma_waitforname' "$SERVICE_NOTIF" 2>/dev/null
then
    echo "ECHEC : $SERVICE_NOTIF lance encore plasma_waitforname." >&2
    exit 1
fi
echo "  activation    : plasma_waitforname ecarte"

# --- La scene QML ---------------------------------------------------------
for f in Constellation.qml Theme.qml Astre.qml Tuile.qml Glyphe.qml Anneau.qml \
         Verre.qml Rangee.qml ArticleMenu.qml SeparateurMenu.qml Bulle.qml Barre.qml \
         BarreLaterale.qml EtoileReglage.qml Session.qml \
         FondEcran.qml FondFloute.qml Ombre.qml Panneau.qml IconeApp.qml CielVivant.qml \
         CarteTheme.qml DemarrerConstellation.qml DemarrerWindows.qml TiroirAndroid.qml \
         Personnaliser.qml AccueilAndroid.qml TuileReglage.qml CurseurReglage.qml \
         Fonds.js Glyphes.js Couleurs.js qmldir; do
    [[ -s "$QML/$f" ]] || { echo "ECHEC : $QML/$f absent." >&2; exit 1; }
done
[[ -s /usr/share/s/constellation/glyphes/sphere.svg ]] \
    || { echo "ECHEC : sphere.svg absente — les etoiles n'auraient pas de corps." >&2; exit 1; }
echo "  scene         : $(ls "$QML" | wc -l) fichiers en place"

# LE CONTROLE QUI MANQUAIT A LA PAGE, ET QUI VAUT POUR TOUTE CETTE REFONTE.
# QML n'est pas compile : il est lu quand la scene s'ouvre. Une faute ne se
# verrait donc qu'a la premiere connexion de l'utilisateur, sur un ecran noir.
# On charge la scene ICI, sans ecran et sans GPU, avec un pont leurre, et la
# construction s'arrete si le moteur QML se plaint une seule fois.
python3 /ctx/build_files/verifier-constellation.py "$QML" \
    || { echo "ECHEC : la scene de Constellation ne tient pas debout." >&2; exit 1; }

# CE QUE LA SCENE FAIT QUAND KWIN PARLE, PAS SEULEMENT QU'ELLE CHARGE. Une
# nouvelle de kwin doit nourrir « ouvertures » sans jamais reconstruire les
# etoiles, et le ciel ne doit animer que s'il n'est cache par aucune fenetre.
# Mesure du 2026-09-19 : sans cette garantie, le ciel animait pour rien
# derriere les fenetres. Les tuiles de la barre, elles, se verifient dans
# verifier-chrome.py depuis le 2026-11-14 (le chrome a sa scene).
python3 /ctx/build_files/verifier-tuiles.py "$QML" \
    || { echo "ECHEC : les nouvelles de kwin cassent la scene, ou le ciel anime cache." >&2; exit 1; }

# CE QUE LE RAPPORTEUR DOIT FAIRE QUAND UN ECRAN SE DEBRANCHE. Le script kwin
# ne tourne que dans le compositeur ; un « kwin de carton » lui joue donc le
# signal screensChanged (banc-fenetres.js) et verifie que le bureau reprend le
# plein ecran, que la barre et la barre laterale retombent sur les bords de
# l'ecran restant, que la bulle visible est replacee, que les vraies fenetres
# restent intouchees, et que le pont est prevenu de reposer les regles pour la
# nouvelle taille. Sans ce controle, une faute dedans ne se verrait qu'au
# prochain debranchement de HDMI, chez l'utilisateur.
python3 /ctx/build_files/verifier-fenetres.py /usr/lib/s/fenetres.js \
    || { echo "ECHEC : le rapporteur ne rattrape pas la coquille apres un debranchement d'ecran." >&2; exit 1; }

# LE CHROME EN SURFACES DE COUCHE, ETAPE 1. La scene du chrome (barre, barre
# laterale, bulle) se charge desormais dans son propre processus (s-chrome),
# avec l'integration layer-shell : on verifie ICI qu'elle tient debout avec
# des ponts leurres — une faute dedans ne se verrait qu'au premier clic sur
# la barre, chez l'utilisateur.
python3 /ctx/build_files/verifier-chrome.py "$QML" \
    || { echo "ECHEC : la scene du chrome ne tient pas debout." >&2; exit 1; }
# « -x », PAS « -s » : le bit d'execution est la difference entre une barre
# des taches et un fichier pose au bon endroit — la coquille ne lance le chrome
# que s'il est executable, et une construction qui livre s-chrome en 0644
# produirait une session sans barre, sans barre laterale, sans bulle, sans que
# rien n'echoue ici. C'est arrive le 2026-11-15, mesure sur la machine.
test -x /usr/bin/s-chrome \
    || { echo "ECHEC : /usr/bin/s-chrome absent ou non executable — chrome sans surfaces de couche." >&2; exit 1; }
python3 -c "
import sys; sys.path.insert(0, '/usr/lib/s')
import pont_lointain
assert pont_lointain.FenetresLointain
assert pont_lointain.BureauLointain
assert pont_lointain.NotificationLointaine
" || { echo "ECHEC : /usr/lib/s/pont_lointain.py ne s'importe pas." >&2; exit 1; }
# LA PREUVE COMPLETE, PAS SEULEMENT LA SCENE. verifier-chrome.py charge QML
# avec des ponts LEURRES : il ne voit rien de ce qui se passe AVANT la scene.
# Or c'est exactement la qu'est tombee la session du 2026-11-15, deux fois :
# s-chrome livre 0644 (jamais lance), puis son chargeur de module qui ne
# reconnaissait plus /usr/bin/s-constellation — sans extension — sous
# Python 3.15 (processus mort au premier pas). La scene, elle, tenait debout,
# et la construction etait verte. On lance donc ici s-chrome LUI-MEME,
# offscreen, avec ses vrais ponts, sous la garde d'un « if » : sans elle,
# le code 124 de timeout (la preuve qu'il tient) ferait mourir le script —
# « set -e » ne pardonne pas un retour non nul hors condition. Mesure du
# 2026-11-15 au soir : trois constructions rouges la-dessus, toutes en 124.
if QT_QPA_PLATFORM=offscreen timeout 10 python3 /usr/bin/s-chrome >/dev/null 2>&1; then
    echo "ECHEC : s-chrome s'est arrete tout seul avant la fin du delai." >&2
    exit 1
fi
# Sorti du « if », timeout a tue s-chrome (124) : il tenait toujours au bout
# de dix secondes — c'est la preuve, et le seul code qui ne dit pas ECHEC.
echo "  chrome         : scene, ponts et processus reels en place"

# --- Le greeter ne propose plus que S -------------------------------------
echo "  sessions trouvees :"
masquees=0
for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    case "$base" in
        s.desktop|s-secours.desktop|s-salon.desktop) echo "    $base  (gardee)"; continue ;;
    esac
    grep -q '^NoDisplay=true' "$f" || printf 'NoDisplay=true\n' >> "$f"
    echo "    $base  masquee"
    masquees=$((masquees + 1))
done
echo "  sessions masquees : $masquees"

for s in /usr/share/wayland-sessions/s.desktop /usr/share/wayland-sessions/s-secours.desktop \
         /usr/share/wayland-sessions/s-salon.desktop; do
    [[ -s "$s" ]] || { echo "ECHEC : $s absente." >&2; exit 1; }
done
test -x /usr/bin/s-session
test -x /usr/bin/s-salon-session
grep -q '^Name=S$' /usr/share/wayland-sessions/s.desktop

if [[ ! -x /usr/bin/startplasma-wayland ]]; then
    echo "  ATTENTION : /usr/bin/startplasma-wayland absent — le bureau de secours ne demarrera pas." >&2
fi

# MODE SALON NE VAUT RIEN SANS GAMESCOPE NI STEAM. Les deux viennent de la
# base (Terra pour gamescope, le depot Steam pour steam) — on ne les
# construit pas, on verifie juste qu'ils sont toujours la plutot que de
# laisser une session choisie au greeter echouer en silence sur un « command
# not found » que personne ne verrait avant de s'y connecter.
if [[ ! -x /usr/bin/gamescope ]]; then
    echo "ECHEC : /usr/bin/gamescope absent — Mode Salon ne demarrerait jamais." >&2
    exit 1
fi
if [[ ! -x /usr/bin/steam ]]; then
    echo "ECHEC : /usr/bin/steam absent — Mode Salon ne demarrerait jamais." >&2
    exit 1
fi
echo "  mode salon    : gamescope et steam presents, session prete"

echo "=== 36-constellation : la session S est posee ==="
