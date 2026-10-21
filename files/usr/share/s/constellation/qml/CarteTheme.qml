import QtQuick

// L'APERCU D'UN THEME : son fond, une barre des taches esquissee, son nom.
//
// Il montre le theme TEL QU'IL SERAIT — son propre fond, son propre mode, ses
// propres couleurs — et non le theme qu'on regarde : voir Theme.optionsPour.
// Un clic l'applique tout de suite, sans redemarrer quoi que ce soit.
Item {
    id: carte

    property string cle: "constellation"
    property string nom: ""
    property string detail: ""
    readonly property bool courante: Theme.nom === cle

    signal choisie()

    implicitWidth: 156
    implicitHeight: 118

    Item {
        id: apercu
        width: parent.width
        height: Math.round(width * 9 / 16)
        scale: tap.pressed ? 0.97 : (survol.hovered ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: Theme.dureeRapide; easing.type: Theme.courbe } }

        Rectangle {
            id: cadre
            anchors.fill: parent
            radius: 8
            color: "#000000"
        }

        FondEcran {
            anchors.fill: parent
            anchors.margins: 1
            fondId: Theme.fondPour(carte.cle)
            theme: carte.cle
            options: Theme.optionsPour(carte.cle)
        }

        // LA BARRE, ESQUISSEE — c'est elle, plus que le fond, qui dit quel
        // systeme on regarde.
        Rectangle {
            visible: carte.cle === "constellation"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 1; anchors.rightMargin: 1
            height: 9
            color: Qt.rgba(12 / 255, 12 / 255, 20 / 255, 0.95)
            Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 5; radius: 2.5; color: "#ffffff" }
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    x: 14 + index * 8; anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5; color: "transparent"
                    border.width: 1; border.color: ["#ff4d4d", "#4da6ff", "#4dff88"][index]
                }
            }
        }
        Rectangle {
            visible: carte.cle === "windows"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 1; anchors.rightMargin: 1
            height: 9
            color: Theme.sombrePour("windows") ? Qt.rgba(0.13, 0.13, 0.13, 0.9) : Qt.rgba(0.95, 0.95, 0.95, 0.9)
            Row {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        width: 5; height: 5; radius: 1
                        color: index === 0 ? Theme.optionsPour("windows").accent
                                           : (Theme.sombrePour("windows") ? "#9a9a9a" : "#6a6a6a")
                    }
                }
            }
        }
        Rectangle {
            visible: carte.cle === "android"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: 46; height: 8; radius: 4
            color: Theme.sombrePour("android") ? Qt.rgba(0.15, 0.15, 0.17, 0.9) : Qt.rgba(0.95, 0.94, 0.97, 0.9)
            Row {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        width: 4; height: 4; radius: 2
                        color: Theme.optionsPour("android").graine
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "transparent"
            border.width: carte.courante ? 2 : 1
            border.color: carte.courante ? (Theme.estConstellation ? Theme.texte : Theme.accent)
                                         : Theme.bord
        }
    }

    Text {
        anchors.top: apercu.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        width: parent.width
        text: carte.nom
        color: carte.courante ? Theme.texte : Theme.texte2
        font.family: Theme.police
        font.pixelSize: 12
        font.weight: carte.courante ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
    }
    Text {
        anchors.top: apercu.bottom
        anchors.topMargin: 22
        anchors.left: parent.left
        width: parent.width
        text: carte.detail
        color: Theme.texte3
        font.family: Theme.police
        font.pixelSize: 10
        elide: Text.ElideRight
    }

    HoverHandler { id: survol; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: carte.choisie() }
}
