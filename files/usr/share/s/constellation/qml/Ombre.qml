import QtQuick

// L'OMBRE PORTEE D'UN PANNEAU — Windows et Material en ont, Constellation non.
//
// HUIT RECTANGLES ARRONDIS EMPILES, et non un flou de canevas. La premiere
// version peignait l'ombre avec « shadowBlur » sur un Canvas : MESURE DU
// 2026-10-20, le flou d'ombre du contexte 2D est calcule en logiciel, et il
// a fallu vingt-trois secondes pour un fond d'ecran qui s'en servait — une
// ombre de menu Demarrer en aurait coute plusieurs a chaque ouverture. Ici,
// chaque couche deborde un peu plus que la precedente et ne porte qu'un
// huitieme de l'opacite : la ou elles se superposent toutes, contre le bord du
// panneau, l'ombre est pleine ; au bord exterieur, il n'en reste qu'une. Un
// degrade en huit marches, que le GPU compose comme n'importe quel rectangle,
// sans texture, sans repeinture.
//
// A poser sous le panneau, debordant de « marge » de chaque cote :
//     Ombre { anchors.fill: parent; anchors.margins: -marge; z: -1 }
Item {
    id: ombre

    property real rayon: Theme.rayon
    property real flou: 22
    property real decalageY: 8
    property real marge: 30
    property color teinte: Theme.ombre
    readonly property int couches: 8

    visible: teinte.a > 0

    Repeater {
        model: ombre.couches
        delegate: Rectangle {
            required property int index
            // De la plus large (index 0) a la plus serree.
            readonly property real part: (ombre.couches - index) / ombre.couches
            readonly property real etendue: part * ombre.flou * 0.55
            x: ombre.marge - etendue
            y: ombre.marge - etendue + ombre.decalageY * (0.35 + 0.65 * part)
            width: Math.max(0, ombre.width - 2 * ombre.marge + 2 * etendue)
            height: Math.max(0, ombre.height - 2 * ombre.marge + 2 * etendue)
            radius: ombre.rayon + etendue
            color: Qt.rgba(ombre.teinte.r, ombre.teinte.g, ombre.teinte.b,
                           Math.min(1, ombre.teinte.a * 1.7 / ombre.couches))
            antialiasing: true
        }
    }
}
