import QtQuick
import QtQuick.Controls.Basic

// Un article du menu contextuel, aux couleurs de S.
//
// LE STYLE « Basic » DE QtQuick.Controls NE PEINT RIEN DE LUI-MEME, et c'est
// pour cela qu'on le choisit : le style « Fusion » ou celui du bureau
// imposerait ses propres couleurs par-dessus la palette de Constellation. Le
// prix a payer est qu'il faut habiller chaque piece a la main — c'est ce que
// fait ce fichier, une fois, pour tous les articles.
MenuItem {
    id: article

    implicitHeight: 34
    implicitWidth: 216

    // « grave » teinte les gestes qu'on ne defait pas. Le menu contextuel n'en
    // porte pas aujourd'hui ; la propriete existe pour que le jour ou l'on y
    // mettra « Desinstaller », la couleur soit deja la.
    property bool grave: false

    scale: article.down ? 0.98 : 1.0
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

    contentItem: Text {
        leftPadding: 13
        rightPadding: 13
        text: article.text
        color: article.down ? "#ffffff"
             : (article.grave && article.hovered ? "#ffbfbf"
             : (article.hovered ? Theme.texte : Theme.texte2))
        font.family: Theme.police
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 6
        color: article.down ? Theme.verre3
             : (!article.hovered ? "transparent"
                                 : (article.grave ? Qt.rgba(1, 0.30, 0.30, 0.14) : Theme.verre2))
        border.color: article.down ? Theme.bordVif : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }
    }
}
