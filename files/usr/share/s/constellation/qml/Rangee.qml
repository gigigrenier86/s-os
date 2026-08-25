import QtQuick

// Une rangee de liste : un glyphe, un libelle, un detail a droite.
// Sert aux dossiers, aux reglages et aux gestes d'alimentation.
Item {
    id: rangee

    property string texte: ""
    property string detail: ""
    property string glyphe: "i-boite"
    // « grave » teinte de rouge au survol les gestes qu'on ne defait pas :
    // redemarrer, eteindre. La couleur est le seul avertissement necessaire.
    property bool grave: false

    signal choisi()

    implicitWidth: 200
    implicitHeight: 38
    width: parent ? parent.width : implicitWidth

    HoverHandler { id: survol; cursorShape: Qt.PointingHandCursor }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: !survol.hovered ? "transparent"
                               : (rangee.grave ? Qt.rgba(1, 0.30, 0.30, 0.14) : Theme.verre2)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.right: parent.right
        anchors.rightMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        spacing: 13

        Glyphe {
            width: 17; height: 17
            anchors.verticalCenter: parent.verticalCenter
            nom: rangee.glyphe
            couleur: rangee.grave && survol.hovered ? "#ffbfbf" : Theme.texte2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 17 - 13 - detailTexte.implicitWidth - 13
            text: rangee.texte
            color: rangee.grave && survol.hovered ? "#ffbfbf"
                                                  : (survol.hovered ? Theme.texte : Theme.texte2)
            font.family: Theme.police
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Text {
            id: detailTexte
            anchors.verticalCenter: parent.verticalCenter
            text: rangee.detail
            color: Theme.texte3
            font.family: Theme.policeMono
            font.pixelSize: 11
        }
    }

    TapHandler { onTapped: rangee.choisi() }
}
