import QtQuick

// L'icone d'une application : la VRAIE, sinon le glyphe de son genre.
//
// Meme regle que l'etoile et la tuile : l'icone du programme dit LEQUEL, le
// glyphe ne dit que le genre. On prefere toujours la premiere, et on ne
// retombe sur le second que si la machine n'a aucun fichier d'icone.
Item {
    id: icone

    property var app: null
    property real taille: 24
    property color couleur: app ? Theme.teinte(app.src || "linux") : Theme.texte2

    implicitWidth: taille
    implicitHeight: taille

    Image {
        id: image
        anchors.fill: parent
        source: icone.app ? (icone.app.img || "") : ""
        // Decodee au double de sa taille d'affichage : nette sur un ecran
        // dense, sans jamais decoder une icone de 512 pixels pour en montrer 24.
        sourceSize.width: Math.max(8, Math.round(icone.taille * 2))
        sourceSize.height: Math.max(8, Math.round(icone.taille * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: source !== "" && status === Image.Ready
    }

    Glyphe {
        anchors.centerIn: parent
        width: icone.taille * 0.86
        height: width
        nom: icone.app ? (icone.app.ico || "i-boite") : "i-boite"
        couleur: icone.couleur
        visible: !image.visible
    }
}
