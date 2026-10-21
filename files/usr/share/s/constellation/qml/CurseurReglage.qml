import QtQuick

// UN CURSEUR DE REGLAGE — le volume, la luminosite — pour Windows 11 et
// Android. Constellation garde sa glissiere a cote de l'etoile.
//
// LES MEMES GARDES QUE LA GLISSIERE DE CONSTELLATION, et pour les memes
// raisons, payees le 2026-08-26 :
//   - le PLANCHER de dix pour cent sur la luminosite (a zero, l'ecran est noir
//     et la barre qui permettrait de remonter l'est avec lui) ;
//   - le DIFFERE de 180 ms (un changement de luminosite coute un aller-retour
//     I2C de pres d'une demi-seconde ; un glissement en produit cinquante) ;
//   - la valeur montree est celle qu'on DEMANDE, pas celle relue, tant que le
//     doigt bouge — sinon le curseur reviendrait en arriere sous lui.
Item {
    id: curseur

    property var reglage: ({})

    signal valeurDemandee(real v)
    signal muetDemande()

    readonly property real maximum: reglage.max || 100
    readonly property real plancher: reglage.cle === "luminosite" ? 10 : 0
    property real valeurLocale: -1
    property bool enGlissement: false
    // Une relecture du panneau rend la vraie valeur — mais jamais pendant que
    // le doigt est sur le curseur.
    onReglageChanged: if (!enGlissement) valeurLocale = -1
    readonly property real valeurVue: valeurLocale >= 0 ? valeurLocale : (reglage.valeur || 0)
    readonly property real fraction: maximum > 0 ? Math.max(0, Math.min(1, valeurVue / maximum)) : 0
    readonly property bool estVolume: reglage.cle === "volume"

    implicitHeight: Theme.estAndroid ? 52 : 40

    Timer {
        id: differe
        interval: 180
        onTriggered: curseur.valeurDemandee(Math.round(curseur.valeurVue))
    }

    function viser(x, largeur) {
        var f = Math.max(0, Math.min(1, x / Math.max(1, largeur)));
        valeurLocale = Math.max(plancher, f * maximum);
        differe.restart();
    }

    // ── Windows : l'icone (qui coupe le son), la piste fine, la valeur ──────
    Item {
        visible: !Theme.estAndroid
        anchors.fill: parent

        Rectangle {
            id: iconeW
            width: 36; height: 36
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: survolIcone.hovered && curseur.estVolume ? Theme.verre2 : "transparent"
            Glyphe {
                anchors.centerIn: parent
                width: 18; height: 18
                nom: curseur.reglage.ico || "i-reglages"
                couleur: Theme.texte
            }
            HoverHandler { id: survolIcone; cursorShape: curseur.estVolume ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { enabled: curseur.estVolume; onTapped: curseur.muetDemande() }
        }
        Text {
            id: valeurW
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            horizontalAlignment: Text.AlignRight
            text: Math.round(curseur.valeurVue)
            color: Theme.texte
            font.family: Theme.police
            font.pixelSize: 13
        }
        Item {
            id: pisteW
            anchors.left: iconeW.right
            anchors.leftMargin: 10
            anchors.right: valeurW.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: Theme.sombre ? Qt.rgba(1, 1, 1, 0.54) : Qt.rgba(0, 0, 0, 0.45)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * curseur.fraction; height: 4; radius: 2
                color: Theme.accent
            }
            // LE POUCE DE WINDOWS : un rond clair, un point d'accent au centre
            // qui grossit sous le doigt.
            Rectangle {
                x: parent.width * curseur.fraction - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20; radius: 10
                color: Theme.sombre ? "#454545" : "#ffffff"
                border.width: 1
                border.color: Theme.bord
                Rectangle {
                    anchors.centerIn: parent
                    width: (glisseW.active || survolPiste.hovered) ? 14 : 10
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.dureeRapide } }
                }
            }
            HoverHandler { id: survolPiste; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: function (e) { curseur.viser(e.position.x, pisteW.width); } }
            DragHandler {
                id: glisseW
                target: null
                onActiveChanged: curseur.enGlissement = active
                onCentroidChanged: if (active) curseur.viser(centroid.position.x, pisteW.width)
            }
        }
    }

    // ── Android : la piste epaisse de Material, l'icone dans la partie pleine ─
    Item {
        visible: Theme.estAndroid
        anchors.fill: parent

        Rectangle {
            id: pisteA
            anchors.fill: parent
            radius: height / 2
            color: Theme.palette.secondaryContainer
            clip: true
            // LA PARTIE PLEINE NE DESCEND JAMAIS SOUS SA PROPRE HAUTEUR : a
            // zero, elle reste un rond qui porte l'icone, comme sur Android.
            Rectangle {
                height: parent.height
                width: Math.max(height, parent.width * curseur.fraction)
                radius: height / 2
                color: Theme.palette.primary
                Behavior on width { enabled: !curseur.enGlissement; NumberAnimation { duration: Theme.dureeRapide } }
            }
            Glyphe {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20
                nom: curseur.reglage.ico || "i-reglages"
                couleur: Theme.palette.onPrimary
                TapHandler { enabled: curseur.estVolume; onTapped: function (e) { curseur.muetDemande(); e.accepted = true; } }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(curseur.valeurVue) + " %"
                color: curseur.fraction > 0.82 ? Theme.palette.onPrimary : Theme.palette.onSecondaryContainer
                font.family: Theme.police
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: function (e) { curseur.viser(e.position.x, pisteA.width); } }
            DragHandler {
                target: null
                onActiveChanged: curseur.enGlissement = active
                onCentroidChanged: if (active) curseur.viser(centroid.position.x, pisteA.width)
            }
        }
    }
}
