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

    implicitHeight: Theme.hauteurArticle
    implicitWidth: 216

    // « grave » teinte les gestes qu'on ne defait pas. Le menu contextuel n'en
    // porte pas aujourd'hui ; la propriete existe pour que le jour ou l'on y
    // mettra « Desinstaller », la couleur soit deja la.
    property bool grave: false
    // Le rouge des gestes graves : rose pale sur un fond sombre, le rouge de
    // Windows (#c42b1c) sur un fond clair — le rose y serait illisible.
    readonly property color rouge: Theme.sombre ? "#ffbfbf" : "#c42b1c"

    scale: article.down ? 0.98 : 1.0
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

    // EN CONSTELLATION, LE TEXTE AU REPOS EST SECONDAIRE et s'eclaire au
    // survol ; Windows et Android ecrivent leurs menus en couleur pleine.
    contentItem: Text {
        leftPadding: Theme.estAndroid ? 16 : 13
        rightPadding: 13
        text: article.text
        color: article.down ? Theme.texte
             : (article.grave && article.hovered ? article.rouge
             : ((article.hovered || !Theme.estConstellation) ? Theme.texte : Theme.texte2))
        font.family: Theme.police
        font.pixelSize: Theme.taillePolice
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Android colle son calque d'etat aux bords du menu ; Windows et
    // Constellation l'arrondissent, en retrait de quatre pixels.
    background: Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.estAndroid ? 0 : 4
        radius: Theme.estAndroid ? 0 : (Theme.estWindows ? 4 : 6)
        color: article.down ? Theme.verre3
             : (!article.hovered ? "transparent"
                                 : (article.grave ? Qt.rgba(1, 0.30, 0.30, 0.14) : Theme.verre2))
        border.color: article.down && Theme.estConstellation ? Theme.bordVif : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }
    }
}
