import QtQuick

// LE FOND D'UN GRAND PANNEAU — menu Demarrer, tiroir d'applications, reglages
// rapides, boite de personnalisation.
//
// Trois couches, de bas en haut, et chacune ne coute que si le theme la veut :
//   1. l'ombre portee      (Windows, Android ; jamais en Constellation) ;
//   2. le fond flou        (l'acrylique de Windows ; seulement si « flou ») ;
//   3. la teinte du theme  (toujours), avec son bord.
//
// LE FOND FLOU EST RENTRE DE TROIS DIXIEMES DU RAYON, ET C'EST UN CALCUL, PAS
// UN REGLAGE A L'OEIL. Un decoupage arrondi demanderait un masque, donc un
// shader, que le controle de construction n'a pas. Le flou reste donc
// rectangulaire — et le coin d'un rectangle rentre de r(1 - 1/racine(2)), soit
// 0,293 r, tombe exactement sur l'arc du coin arrondi. A 0,3 r, aucun pixel flou
// ne depasse jamais de la teinte arrondie qui le recouvre.
Item {
    id: panneau

    property real rayon: Theme.rayon
    property color teinte: Theme.panneau
    property color bordure: Theme.bord
    property bool flou: false
    property bool ombre: Theme.ombre.a > 0
    // Position de ce panneau sur l'ecran, pour que le flou montre ce qui est
    // DERRIERE lui.
    property real ox: 0
    property real oy: 0
    property real ecranL: 1920
    property real ecranH: 1080

    readonly property int retrait: Math.ceil(rayon * 0.3)

    Loader {
        z: -1
        anchors.fill: parent
        anchors.margins: -32
        active: panneau.ombre
        sourceComponent: Component {
            Ombre { rayon: panneau.rayon; marge: 32; flou: 26; decalageY: 10 }
        }
    }

    Loader {
        anchors.fill: parent
        anchors.margins: panneau.retrait
        active: panneau.flou
        sourceComponent: Component {
            FondFloute {
                ox: panneau.ox + panneau.retrait
                oy: panneau.oy + panneau.retrait
                ecranL: panneau.ecranL
                ecranH: panneau.ecranH
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: panneau.rayon
        color: panneau.teinte
        border.color: panneau.bordure
        border.width: 1
        antialiasing: true
    }
}
