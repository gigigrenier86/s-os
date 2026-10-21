import QtQuick

// Le verre : le fond des panneaux de Constellation.
//
// LE FLOU D'ARRIERE-PLAN DE LA PAGE N'EST PAS REPRIS, ET C'EST UN CHOIX MESURE.
// « backdrop-filter: blur(16px) » s'appliquait a une teinte deja opaque a 86 %
// posee sur un ciel presque noir : le flou n'y deplace que quelques niveaux de
// gris. Le reproduire en QML demande de capturer la scene (ShaderEffectSource),
// de la flouter et de la masquer a un rectangle arrondi, a chaque image. On
// paierait une passe de rendu par panneau pour un resultat que l'oeil ne
// distingue pas du a-plat.
//
// LES MENUS DE WINDOWS ET D'ANDROID PORTENT UNE OMBRE — ajoutee le 2026-10-20.
// Elle n'est chargee que si le theme en a une (Theme.ombre) : en
// Constellation, le Loader reste vide et le verre ne coute rien de plus.
Rectangle {
    id: verre
    property bool ombre: true
    color: Theme.verre
    border.color: Theme.bord
    border.width: 1
    antialiasing: true

    Loader {
        z: -1
        anchors.fill: parent
        anchors.margins: -24
        active: verre.ombre && Theme.ombre.a > 0
        sourceComponent: Component {
            Ombre { marge: 24; flou: 18; decalageY: 6; rayon: verre.radius }
        }
    }
}
