#!/usr/bin/bash
# GRIMOIRE — savoir si ce compositeur place un popup Qt là où on le lui demande
# PREUVE : 2026-08-27, sur S, kwin_wayland. Six intégrations de shell mesurées,
#          trois fois chacune, résultat identique à chaque fois. A tranché une
#          question qui avait coûté un correctif faux poussé dans l'image — et
#          a réfuté au passage la formule « un client Wayland ne se positionne
#          pas lui-même » appliquée aux popups, qui est vraie des fenêtres de
#          premier rang et fausse des popups.
# POUR   : avant d'ouvrir un menu, une infobulle ou tout Popup à une position
#          calculée, depuis une fenêtre qui n'est pas une fenêtre ordinaire.
#
# CE QUE CE BANC RÉPOND, ET LA FAUTE QU'IL AURAIT ÉVITÉE
#
# Un « Popup » Qt Quick est mis en page DANS sa fenêtre hôte, et s'y trouve
# borné. Une barre des tâches haute de cinquante-deux pixels ne peut donc pas
# ouvrir un menu de deux cent vingt : il sort à cinquante-deux, un article
# visible sur neuf.
#
# La réponse évidente est « popupType: Popup.Window » — donner au menu sa
# propre fenêtre. Elle rend bien la hauteur. Elle perd l'abscisse : le menu se
# pose tout à gauche de l'écran. Le correctif est parti dans l'image avant
# qu'on le sache, et c'est l'utilisateur qui l'a vu.
#
# LE PIÈGE QUI REND CE BANC NÉCESSAIRE
#
# On peut lire « QRect(600, 171, 200, 360) » sur un popup qui n'est PAS à 600.
# La géométrie côté client est une demande, pas un constat : sous Wayland c'est
# le compositeur qui place. Trois intégrations rendent ici la bonne abscisse —
# « qt-shell », « wl-shell », et n'importe quel nom inexistant — et ce sont
# exactement les trois que kwin ne parle pas. La fenêtre retombe alors en
# décorations côté client : elle « marche » parce qu'elle a cessé d'être une
# fenêtre gérée. Un banc qui ne lit que le nombre conclut l'inverse de la
# vérité, d'où la capture d'écran à la fin.
#
# CE QUE LA MESURE A DONNÉ LE 2026-08-27
#
#   (aucune variable)  ->  QRect(0, 0, 200, 360)      perdu
#   xdg-shell          ->  QRect(0, 0, 200, 360)      perdu
#   qt-shell           ->  QRect(600, 171, 200, 360)  placé, mais non géré
#   wl-shell           ->  QRect(600, 171, 200, 360)  placé, mais non géré
#   layer-shell        ->  QRect(0, 0, 200, 360)      perdu, et menu détruit
#   (nom inexistant)   ->  QRect(600, 171, 200, 360)  placé, mais non géré
#
# CE QU'IL FAUT FAIRE QUAND LE BANC REND « perdu »
#
# Ne pas donner de fenêtre au popup. Agrandir la fenêtre hôte pour qu'elle le
# contienne, et masquer sa zone sensible avec « QWindow::setMask », qui part en
# « wl_surface.set_input_region ». C'est ce que fait la barre des tâches de S,
# et c'est déjà ce que faisait sa barre latérale depuis le 2026-08-25.

set -uo pipefail

ou_se_pose_un_popup() {
    local demande="${1:-600}"
    local capture="${2:-}"
    local d
    d="$(mktemp -d)"
    trap 'rm -rf "$d"' RETURN

    cat > "$d/sonde.qml" <<'QML'
import QtQuick
import QtQuick.Controls.Basic

Window {
    id: hote
    title: "sonde popup"
    width: Screen.width
    height: 52
    visible: true
    color: "#141428"
    property int demande: 600
    Text { anchors.centerIn: parent; color: "white"; text: "sonde : fenetre hote" }
    Menu {
        id: m
        popupType: Popup.Window
        Repeater { model: 9
                   delegate: MenuItem { required property int index
                                        text: "article numero " + index } }
    }
    function essai() { m.popup(hote.demande, -m.implicitHeight - 6); }
}
QML

    cat > "$d/sonde.py" <<'PY'
import sys, functools
print = functools.partial(print, flush=True)
from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

chemin, demande, tenir = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
app = QGuiApplication([])
moteur = QQmlApplicationEngine()
moteur.load(QUrl.fromLocalFile(chemin))
if not moteur.rootObjects():
    print("ECHEC-SCENE"); sys.exit(1)
racine = moteur.rootObjects()[0]
racine.setProperty("demande", demande)

def mesurer():
    for w in app.allWindows():
        if w.title() != "sonde popup":
            g = w.geometry()
            print("%d %d %d %d" % (g.x(), g.y(), g.width(), g.height()))
            return
    print("PAS-DE-POPUP")

def ouvrir():
    racine.essai()
    QTimer.singleShot(700, mesurer)

QTimer.singleShot(900, ouvrir)
QTimer.singleShot(tenir, app.quit)
sys.exit(app.exec())
PY

    printf 'on demande x = %s, et on regarde ou le popup se pose\n\n' "$demande"
    printf '  %-18s %-28s %s\n' "integration" "geometrie rendue" "verdict"
    printf '  %-18s %-28s %s\n' "------------------" \
           "----------------------------" "-------"

    local v nom sortie x verdict
    for v in AUCUNE xdg-shell qt-shell wl-shell layer-shell nexistepas; do
        nom="$v"
        if [[ "$v" == AUCUNE ]]; then
            sortie="$(python3 "$d/sonde.py" "$d/sonde.qml" "$demande" 3500 \
                      2>/dev/null | tail -1)"
        else
            sortie="$(QT_WAYLAND_SHELL_INTEGRATION="$v" \
                      python3 "$d/sonde.py" "$d/sonde.qml" "$demande" 3500 \
                      2>/dev/null | tail -1)"
        fi
        x="$(awk '{print $1}' <<<"$sortie")"
        if [[ "$x" == "$demande" ]]; then verdict="place"; else verdict="PERDU"; fi
        printf '  %-18s %-28s %s\n' "$nom" "${sortie:-(rien)}" "$verdict"
    done

    # LE NOMBRE NE SUFFIT PAS, ET C'EST TOUT L'INTERET DE CETTE PARTIE. Voir
    # l'en-tete : trois integrations rendent la bonne abscisse en cessant
    # d'etre des fenetres gerees. On regarde donc l'ecran.
    if [[ -n "$capture" ]] && command -v spectacle >/dev/null; then
        printf '\ncapture avec l integration par defaut -> %s\n' "$capture"
        python3 "$d/sonde.py" "$d/sonde.qml" "$demande" 9000 >/dev/null 2>&1 &
        sleep 3
        spectacle -b -n -f -o "$capture" >/dev/null 2>&1
        wait 2>/dev/null || true
    fi
}

# Lance directement quand on l'execute plutot que de le sourcer.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ou_se_pose_un_popup "${1:-600}" "${2:-}"
fi
