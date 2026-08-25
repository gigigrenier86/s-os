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
dnf5 install -y python3-pyside6 ibm-plex-sans-fonts ibm-plex-mono-fonts

# Regle 2 du carnet : une installation qui atterrit hors de /usr livrerait une
# image creuse sans que rien ne le dise.
if rpm -ql python3-pyside6 ibm-plex-sans-fonts ibm-plex-mono-fonts \
   | grep -qE '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : un paquet est pose hors de /usr." >&2
    exit 1
fi
python3 -c 'import PySide6, PySide6.QtQuick; print("  PySide6       :", PySide6.__version__)'
# Regle 5 : une ligne de rapport ne fait jamais tomber une image saine.
echo "  polices       : $(fc-list 2>/dev/null | grep -ci 'IBM Plex' || true) fichiers IBM Plex" || true

# --- Les gestes de la session ---------------------------------------------
# Le bit d'execution ne survit pas a un depot edite sous Windows ; on le repose
# plutot que de dependre de ce que git a bien voulu enregistrer.
chmod 0755 /usr/bin/s-session /usr/bin/s-coquille /usr/bin/s-constellation

# Une faute de syntaxe ne se verrait qu'au premier ouverture de session,
# c'est-a-dire sur un ecran noir. Elle se voit ici en une seconde.
bash -n /usr/bin/s-session
bash -n /usr/bin/s-coquille
python3 -m py_compile /usr/bin/s-constellation /usr/lib/s/noyau.py
rm -rf /usr/bin/__pycache__ /usr/lib/s/__pycache__ /root/.cache 2>/dev/null || true
echo "  syntaxe       : session, coquille, coquille native et noyau analyses"

# Le noyau doit s'importer, pas seulement se compiler : un import casse ne se
# verrait, la encore, qu'a la premiere connexion.
python3 -c "import sys; sys.path.insert(0, '/usr/lib/s'); import noyau; noyau.inventaire()" \
    || { echo "ECHEC : /usr/lib/s/noyau.py ne s'importe pas." >&2; exit 1; }
echo "  noyau         : importe, inventaire parcouru"

# --- La scene QML ---------------------------------------------------------
for f in Constellation.qml Theme.qml Astre.qml Tuile.qml Glyphe.qml Anneau.qml \
         Verre.qml Rangee.qml ArticleMenu.qml SeparateurMenu.qml \
         Fonds.js Glyphes.js qmldir; do
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

# --- Le greeter ne propose plus que S -------------------------------------
echo "  sessions trouvees :"
masquees=0
for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    case "$base" in
        s.desktop|s-secours.desktop) echo "    $base  (gardee)"; continue ;;
    esac
    grep -q '^NoDisplay=true' "$f" || printf 'NoDisplay=true\n' >> "$f"
    echo "    $base  masquee"
    masquees=$((masquees + 1))
done
echo "  sessions masquees : $masquees"

for s in /usr/share/wayland-sessions/s.desktop /usr/share/wayland-sessions/s-secours.desktop; do
    [[ -s "$s" ]] || { echo "ECHEC : $s absente." >&2; exit 1; }
done
test -x /usr/bin/s-session
grep -q '^Name=S$' /usr/share/wayland-sessions/s.desktop

if [[ ! -x /usr/bin/startplasma-wayland ]]; then
    echo "  ATTENTION : /usr/bin/startplasma-wayland absent — le bureau de secours ne demarrera pas." >&2
fi

echo "=== 36-constellation : la session S est posee ==="
