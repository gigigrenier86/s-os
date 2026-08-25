import QtQuick

// Une tuile du menu Demarrer : une application, sa bulle, son nom, son epingle.
Item {
    id: tuile

    property var app: ({})
    signal ouvrir()
    signal epingler(bool oui)
    signal menuDemande(real ex, real ey)

    readonly property color teinte: Theme.teinte(app.src || "linux")
    readonly property bool exerce: (app.ep || 0) > 0
    readonly property bool epinglee: (app.epingle || 0) > 0

    implicitWidth: 78
    implicitHeight: 88

    HoverHandler { id: survol; cursorShape: Qt.PointingHandCursor }

    Rectangle {
        anchors.fill: parent
        radius: 9
        color: survol.hovered ? Theme.verre2 : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 7

        // La bulle : meme grammaire que l'etoile, en plus petit. Anneau plein
        // ou pointille selon que le logiciel a deja tourne.
        Item {
            width: 38; height: 38
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                anchors.fill: parent
                source: "../glyphes/sphere.svg"
                sourceSize.width: 76; sourceSize.height: 76
                smooth: true
            }
            Anneau {
                anchors.fill: parent
                couleur: tuile.teinte
                pointille: !tuile.exerce
                epaisseur: 1.5
            }
            Image {
                id: vraieIcone
                anchors.centerIn: parent
                width: 19; height: 19
                source: tuile.app.img || ""
                sourceSize.width: 38; sourceSize.height: 38
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: source !== "" && status === Image.Ready
            }
            Glyphe {
                anchors.centerIn: parent
                width: 17; height: 17
                nom: tuile.app.ico || "i-boite"
                couleur: tuile.teinte
                visible: !vraieIcone.visible
            }
        }

        Text {
            // Suit la tuile : une largeur figee coupait les noms longs
            // au milieu d'un mot (« Documentatio / n »).
            width: tuile.width - 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: tuile.app.nom || ""
            color: survol.hovered ? Theme.texte : Theme.texte2
            font.family: Theme.police
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 1.25
        }
    }

    // --- L'EPINGLE ---------------------------------------------------------
    // ELLE N'EXISTAIT PAS, ET C'EST LA PANNE QUE L'UTILISATEUR A NOMMEE. La
    // barre se composait toute seule des sept applications les plus lancees ;
    // aucun geste ne permettait d'y ajouter ni d'en retirer quoi que ce soit.
    // Ce bouton, et le menu du clic droit, sont les deux voies vers le meme
    // reglage — l'une se voit en parcourant le menu, l'autre se trouve la ou
    // tout le monde la cherche.
    Rectangle {
        id: epingle
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 6
        anchors.topMargin: 2
        width: 18; height: 18; radius: 9
        color: tuile.epinglee ? Qt.rgba(1, 1, 1, 0.14) : Theme.verre2
        border.color: (tuile.epinglee || survolEpingle.hovered) ? Theme.bordVif : Theme.bord
        border.width: 1
        opacity: (survol.hovered || tuile.epinglee) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        HoverHandler { id: survolEpingle; cursorShape: Qt.PointingHandCursor }

        Glyphe {
            anchors.centerIn: parent
            width: 10; height: 10
            nom: "i-etincelle"
            couleur: (tuile.epinglee || survolEpingle.hovered) ? Theme.texte : Theme.texte3
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: tuile.epingler(!tuile.epinglee)
        }
    }

    // Le clic gauche ouvre. Pas de double-clic ici : dans une liste, un seul
    // clic est ce que tout le monde attend — c'est le ciel qui demande deux
    // clics, parce qu'on y deplace aussi les etoiles.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: tuile.ouvrir()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: function (evenement) {
            var p = tuile.mapToItem(null, evenement.position.x, evenement.position.y);
            tuile.menuDemande(p.x, p.y);
        }
    }
}
