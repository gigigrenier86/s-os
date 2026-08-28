import QtQuick

// Une etoile : une application, posee dans le ciel de Constellation.
//
// CE QUE L'ANNEAU DIT, ET C'EST LA DISCIPLINE DU CARNET RENDUE VISIBLE :
//   sa COULEUR  -> le monde d'ou vient le logiciel (rouge/bleu/vert) ;
//   son TRAIT   -> plein si le logiciel a deja tourne ICI (compteur > 0),
//                  pointille s'il est seulement pose dans l'image.
// « Pose et jamais exerce » est ecrit partout dans ce depot ; ici il se voit
// sans un mot.
Item {
    id: astre

    property var app: ({})
    property real diametre: Theme.sphere
    property bool choisi: false
    property bool montrerNom: false

    signal ouvrir()
    signal menuDemande(real ex, real ey)
    signal deplacee(real nx, real ny)

    readonly property color teinte: Theme.teinte(app.src || "linux")
    readonly property bool exerce: (app.ep || 0) > 0

    width: diametre
    height: diametre

    // Le grossissement au survol, et la mise en avant quand l'etoile est
    // choisie. Les durees sont celles de la page : 180 ms, meme courbe.
    scale: choisi ? 1.22 : (survol.hovered ? 1.16 : 1.0)
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on diametre { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    HoverHandler { id: survol; cursorShape: Qt.PointingHandCursor }

    // --- Le halo ----------------------------------------------------------
    // Pose SOUS le corps, agrandi : un rond flou de la couleur du monde. La
    // page le faisait avec box-shadow, qui n'existe pas ici.
    Rectangle {
        anchors.centerIn: parent
        width: astre.diametre * 1.5
        height: width
        radius: width / 2
        color: "transparent"
        border.color: astre.teinte
        border.width: astre.diametre * 0.16
        opacity: (survol.hovered || astre.choisi) ? 0.28 : 0.0
        visible: opacity > 0
        antialiasing: true
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    // --- Le corps de la sphere -------------------------------------------
    Image {
        id: corps
        anchors.fill: parent
        source: "../glyphes/sphere.svg"
        sourceSize.width: Math.max(4, Math.round(astre.diametre * 2))
        sourceSize.height: Math.max(4, Math.round(astre.diametre * 2))
        smooth: true
    }

    // --- L'anneau ---------------------------------------------------------
    Anneau {
        anchors.fill: parent
        couleur: astre.teinte
        pointille: !astre.exerce
        epaisseur: astre.choisi ? 2.5 : 2
    }

    // --- Ce qu'elle porte : l'icone VRAIE, sinon le glyphe ----------------
    // L'icone du programme dit LEQUEL ; le glyphe ne dit que le genre. On
    // prefere donc toujours la premiere, et on ne retombe sur le second que
    // si la machine n'a aucun fichier d'icone pour cette application.
    Image {
        id: vraieIcone
        anchors.centerIn: parent
        width: astre.diametre * 0.54
        height: width
        source: app.img || ""
        sourceSize.width: Math.max(8, Math.round(astre.diametre * 1.08))
        sourceSize.height: Math.max(8, Math.round(astre.diametre * 1.08))
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: source !== "" && status === Image.Ready
    }

    Glyphe {
        anchors.centerIn: parent
        width: astre.diametre * 0.47
        height: width
        nom: app.ico || "i-boite"
        couleur: astre.teinte
        visible: !vraieIcone.visible
    }

    // --- Le compteur de lancements ---------------------------------------
    Rectangle {
        visible: (app.compte || 0) > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -5
        anchors.topMargin: -5
        height: 16
        width: Math.max(16, compteur.implicitWidth + 8)
        radius: height / 2
        color: Theme.verre
        border.color: Theme.bordVif
        border.width: 1
        Text {
            id: compteur
            anchors.centerIn: parent
            text: (app.compte || 0) > 99 ? "99+" : String(app.compte || 0)
            color: Theme.texte
            font.family: Theme.policeMono
            font.pixelSize: 10
        }
    }

    // --- L'etiquette ------------------------------------------------------
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 8
        text: app.nom || ""
        color: Theme.texte2
        font.family: Theme.police
        font.pixelSize: 11
        opacity: (survol.hovered || astre.choisi || astre.montrerNom) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        // Le nom se lit sur un ciel sombre : une ombre portee evite qu'il
        // disparaisse sur une nebuleuse claire.
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.9)
    }

    // --- Les gestes -------------------------------------------------------
    // UN DOUBLE-CLIC OUVRE, UN SIMPLE CLIC NE FAIT QUE CHOISIR. C'est la regle
    // de la page, et c'est ce qui permet de deplacer une etoile sans la lancer.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: astre.choisi = !astre.choisi
        onDoubleTapped: astre.ouvrir()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: function (evenement) {
            var p = astre.mapToItem(null, evenement.position.x, evenement.position.y);
            astre.menuDemande(p.x, p.y);
            // SANS CECI, LE CIEL RECOIT LE MEME CLIC DROIT JUSTE APRES, ET
            // OUVRE menuDuFond PAR-DESSUS menuContextuel — releve par
            // l'utilisateur le 2026-08-28 : « les choix du clic droit sur le
            // bureau et sur les etoiles sont les memes ». Un TapHandler ne
            // consomme pas un point par defaut ; il faut le dire.
            evenement.accepted = true;
        }
    }

    DragHandler {
        id: glisser
        target: astre
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: if (!active) astre.deplacee(astre.x, astre.y)
    }
}
