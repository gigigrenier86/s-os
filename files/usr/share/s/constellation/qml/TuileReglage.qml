import QtQuick

// UNE TUILE DE REGLAGE RAPIDE — Windows 11 et Android, la ou Constellation
// dessine une etoile (EtoileReglage.qml).
//
// MEMES SIGNAUX QUE L'ETOILE, ET C'EST TOUT L'INTERET : le panneau qui la porte
// (BarreLaterale.qml) envoie les memes ordres au pont quel que soit le theme.
// Un reglage ne se comporte pas autrement parce qu'il est dessine autrement.
//
//   Windows : un bouton carre, l'icone au centre, plein de l'accent quand c'est
//             allume, le nom en dessous — la grille des reglages rapides.
//   Android : une pilule large, l'icone a gauche, le nom et l'etat a droite,
//             pleine de la couleur primaire quand c'est allume.
Item {
    id: tuile

    property var reglage: ({})

    signal bascule()
    signal choixDemande()

    readonly property string forme: reglage.type || "bascule"
    readonly property bool allume: reglage.actif === true && forme !== "action"
    // UN REGLAGE PEUT ETRE VERROUILLE (le Wi-Fi, seule voie vers le reseau) :
    // le clic reste possible et RAPPELLE POURQUOI — voir EtoileReglage.qml.
    readonly property bool verrouille: reglage.verrouille === true

    implicitWidth: Theme.estAndroid ? 156 : 98
    implicitHeight: Theme.estAndroid ? 64 : 82

    HoverHandler { id: survol; cursorShape: tuile.verrouille ? Qt.ArrowCursor : Qt.PointingHandCursor }
    TapHandler {
        id: tap
        onTapped: {
            if (tuile.forme === "choix") tuile.choixDemande();
            else tuile.bascule();
        }
    }

    // ── Windows ─────────────────────────────────────────────────────────────
    Item {
        visible: !Theme.estAndroid
        anchors.fill: parent

        Rectangle {
            id: boutonW
            width: parent.width
            height: 48
            radius: 4
            color: tuile.allume ? Theme.accent : Theme.carte
            border.width: 1
            border.color: tuile.allume ? "transparent" : Theme.bord
            scale: tap.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.dureePression; easing.type: Theme.courbe } }
            Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
            // Le survol eclaircit ou assombrit d'un cran, sans changer la teinte.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: tuile.allume ? Qt.rgba(1, 1, 1, survol.hovered ? 0.10 : 0)
                                    : (survol.hovered ? Theme.verre2 : "transparent")
            }
            Glyphe {
                anchors.centerIn: parent
                width: 18; height: 18
                nom: tuile.reglage.ico || "i-reglages"
                couleur: tuile.allume ? Theme.surAccent : Theme.texte
            }
            // Le chevron d'un reglage « choix » : il ouvre une liste.
            Text {
                visible: tuile.forme === "choix"
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: tuile.allume ? Theme.surAccent : Theme.texte2
                font.pixelSize: 16
            }
        }
        Text {
            anchors.top: boutonW.bottom
            anchors.topMargin: 7
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tuile.reglage.nom || ""
            color: Theme.texte
            font.family: Theme.police
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    // ── Android ─────────────────────────────────────────────────────────────
    Rectangle {
        visible: Theme.estAndroid
        anchors.fill: parent
        radius: height / 2
        color: tuile.allume ? Theme.palette.primary : Theme.palette.surfaceContainerHighest
        scale: tap.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.dureeRapide; easing.type: Theme.courbe } }
        Behavior on color { ColorAnimation { duration: Theme.dureeNormale } }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: survol.hovered ? (tuile.allume ? Qt.rgba(1, 1, 1, 0.10) : Theme.verre2) : "transparent"
        }
        Glyphe {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22
            nom: tuile.reglage.ico || "i-reglages"
            couleur: tuile.allume ? Theme.palette.onPrimary : Theme.palette.onSurfaceVariant
        }
        Column {
            x: 54
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 64
            spacing: 1
            Text {
                width: parent.width
                text: tuile.reglage.nom || ""
                color: tuile.allume ? Theme.palette.onPrimary : Theme.palette.onSurface
                font.family: Theme.police
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: tuile.reglage.detail || (tuile.forme === "action" ? ""
                      : (tuile.allume ? "Activé" : "Désactivé"))
                color: tuile.allume ? Theme.palette.onPrimary : Theme.palette.onSurfaceVariant
                opacity: 0.85
                font.family: Theme.police
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }
}
