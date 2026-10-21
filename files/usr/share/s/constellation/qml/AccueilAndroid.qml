import QtQuick

// L'ECRAN D'ACCUEIL D'UNE TABLETTE ANDROID — l'horloge en grand, la date, et la
// recherche, en haut de l'ecran comme sur une tablette Pixel.
//
// RIEN NE TOURNE AU REPOS. L'horloge se reveille au changement de minute — le
// meme minuteur que celui de la barre, pour la meme raison : un tic par seconde
// reecrirait soixante fois le meme texte et reveillerait le compositeur pour
// rien.
Item {
    id: accueil

    property string heure: "--:--"
    property string date: ""

    readonly property var jours: ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
    readonly property var mois: ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
                                 "août", "septembre", "octobre", "novembre", "décembre"]

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var m = new Date();
            accueil.heure = Qt.formatTime(m, "HH:mm");
            accueil.date = accueil.jours[m.getDay()] + " " + m.getDate() + " " + accueil.mois[m.getMonth()];
            interval = 60000 - (m.getSeconds() * 1000 + m.getMilliseconds()) + 50;
        }
    }

    // ── L'horloge : le « coup d'oeil » d'Android, en tres grand et tres fin ──
    Column {
        x: Theme.origineX + 10
        y: 30
        spacing: 0
        Text {
            text: accueil.heure
            color: Theme.texteBureau
            font.family: Theme.police
            font.pixelSize: 84
            font.weight: Font.Light
            style: Text.Raised
            styleColor: Theme.fondClair ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
            text: accueil.date
            color: Theme.texteBureau
            font.family: Theme.police
            font.pixelSize: 19
            font.weight: Font.Medium
            style: Text.Raised
            styleColor: Theme.fondClair ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.35)
        }
    }

    // ── La recherche : une pilule, qui ouvre le tiroir sur sa recherche ─────
    Rectangle {
        id: pilule
        anchors.horizontalCenter: parent.horizontalCenter
        y: 52
        width: Math.min(600, parent.width * 0.36)
        height: 56
        radius: 28
        color: tap.pressed ? Theme.palette.surfaceContainerHighest : Theme.palette.surfaceContainerHigh
        scale: tap.pressed ? 0.98 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.dureeRapide; easing.type: Theme.courbe } }

        Ombre {
            z: -1
            anchors.fill: parent
            anchors.margins: -marge
            marge: 22
            rayon: 28
            flou: 16
            decalageY: 4
            teinte: Qt.rgba(0, 0, 0, Theme.sombre ? 0.40 : 0.14)
        }

        Glyphe {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22
            nom: "i-recherche"
            couleur: Theme.palette.onSurfaceVariant
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 60
            anchors.verticalCenter: parent.verticalCenter
            text: "Rechercher des applications, le Web"
            color: Theme.palette.onSurfaceVariant
            font.family: Theme.police
            font.pixelSize: 16
        }
        // Le rond de la couleur primaire, a droite : la place ou Android met
        // le micro. Ici il dit seulement « c'est la qu'on cherche ».
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            color: Theme.palette.primaryContainer
            Glyphe {
                anchors.centerIn: parent
                width: 18; height: 18
                nom: "i-etincelle"
                couleur: Theme.palette.onPrimaryContainer
            }
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: tap
            onTapped: Session.menu.ouvrirRecherche()
        }
    }
}
