import QtQuick
import QtQuick.Controls.Basic
import "Fonds.js" as Fonds

// ═══════════════════════════════════════════════════════════════════════════
// PERSONNALISER — le theme, le fond, les couleurs. Ajoute le 2026-10-20.
//
// TOUT S'APPLIQUE AU CLIC, en direct : changer de theme, de fond, de mode ou
// d'accent ne redemarre rien et ne demande aucune confirmation — on voit tout
// de suite, et on revient d'un clic. Chaque choix est garde dans les reglages
// de S (voir Constellation.qml : appliquerTheme, choisirFond, reglerTheme).
//
// SON CONTENU N'EXISTE QUE PENDANT QU'ELLE EST OUVERTE. Une vingtaine de
// vignettes peintes et les miniatures des images de l'utilisateur, gardees en
// memoire toute la session pour une boite qu'on ouvre une fois par mois, ce
// serait payer en permanence pour un geste rare : le Loader les cree a
// l'ouverture et les rend a la fermeture.
// ═══════════════════════════════════════════════════════════════════════════

Popup {
    id: perso
    objectName: "personnaliser"
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(820, (Session.bureau ? Session.bureau.width : 1200) - 80)
    height: Math.min(720, (Session.bureau ? Session.bureau.height : 900) - 120)
    x: ((Session.bureau ? Session.bureau.width : 1200) - width) / 2
    y: ((Session.bureau ? Session.bureau.height : 900) - height) / 2 - 20

    // Les images de l'utilisateur, relues a chaque ouverture.
    property var images: []
    onAboutToShow: images = pont.images(10)

    background: Panneau {
        rayon: Theme.estAndroid ? 28 : Theme.rayon
        teinte: Theme.estConstellation ? Theme.verre
              : (Theme.estAndroid ? Theme.palette.surfaceContainerLow
                                  : (Theme.sombre ? "#2b2b2b" : "#f9f9f9"))
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dureeNormale; easing.type: Theme.courbe }
            NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.dureeNormale; easing.type: Theme.courbe }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.dureeRapide }
    }

    contentItem: Loader {
        active: perso.visible
        sourceComponent: contenu
    }

    // ── Les petites pieces ──────────────────────────────────────────────────

    component Titre: Text {
        color: Theme.texte
        font.family: Theme.police
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }

    component Interrupteur: Item {
        id: inter
        property bool actif: false
        signal bascule()
        width: 44; height: 22
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: inter.actif ? Theme.accent : "transparent"
            border.width: inter.actif ? 0 : 1
            border.color: Theme.bordVif
            Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
        }
        Rectangle {
            width: inter.actif ? 14 : 12
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: inter.actif ? parent.width - width - 4 : 5
            color: inter.actif ? Theme.surAccent : Theme.texte2
            Behavior on x { NumberAnimation { duration: Theme.dureeNormale; easing.type: Theme.courbe } }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: inter.bascule() }
    }

    // Une ligne de reglage : un libelle a gauche, un interrupteur a droite.
    component LigneReglage: Item {
        id: ligne
        property string texte: ""
        property string detail: ""
        property bool actif: false
        signal bascule()
        width: parent ? parent.width : 400
        height: 52
        Rectangle {
            anchors.fill: parent
            radius: Theme.estAndroid ? 16 : 6
            color: Theme.carte
            border.width: Theme.estConstellation ? 1 : 0
            border.color: Theme.bord
        }
        Column {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: ligne.texte; color: Theme.texte; font.family: Theme.police; font.pixelSize: 14 }
            Text {
                visible: text !== ""
                text: ligne.detail
                color: Theme.texte2
                font.family: Theme.police
                font.pixelSize: 12
            }
        }
        Interrupteur {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            actif: ligne.actif
            onBascule: ligne.bascule()
        }
    }

    // Deux boutons cote a cote, un seul choisi : Clair / Sombre.
    component Segment: Rectangle {
        id: segment
        property string texte: ""
        property bool choisi: false
        signal clique()
        width: 120; height: 36
        radius: Theme.estAndroid ? 18 : 6
        color: choisi ? Theme.accentDoux : (survolS.hovered ? Theme.verre2 : "transparent")
        border.width: 1
        border.color: choisi ? Theme.accent : Theme.bord
        Text {
            anchors.centerIn: parent
            text: segment.texte
            color: segment.choisi ? Theme.surAccentDoux : Theme.texte
            font.family: Theme.police
            font.pixelSize: 13
            font.weight: segment.choisi ? Font.DemiBold : Font.Normal
        }
        HoverHandler { id: survolS; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: segment.clique() }
    }

    // Une pastille de couleur, cochee quand c'est la couleur en place.
    component Nuance: Rectangle {
        id: nuance
        property string couleur: "#808080"
        property bool choisie: false
        signal clique()
        width: 34; height: 34
        radius: Theme.estAndroid ? 17 : 5
        color: couleur
        border.width: choisie ? 3 : 0
        border.color: Theme.texte
        Rectangle {
            visible: nuance.choisie
            anchors.centerIn: parent
            width: 10; height: 10; radius: 5
            color: "#ffffff"
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: nuance.clique() }
    }

    Component {
        id: contenu
        Flickable {
            id: defile
            clip: true
            contentHeight: colonne.height + 48
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }

            Column {
                id: colonne
                x: 32
                y: 26
                width: defile.width - 64
                spacing: 16

                // ── L'en-tete ──────────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 34
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Personnaliser"
                        color: Theme.texte
                        font.family: Theme.police
                        font.pixelSize: 22
                        font.weight: Theme.estAndroid ? Font.Normal : Font.DemiBold
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34; height: 34
                        radius: Theme.estAndroid ? 17 : 4
                        color: survolFermer.hovered ? Theme.verre2 : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Theme.texte2
                            font.pixelSize: 14
                        }
                        HoverHandler { id: survolFermer; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: perso.close() }
                    }
                }

                // ── Le theme ───────────────────────────────────────────────
                Titre { text: "Thème" }
                Row {
                    spacing: 16
                    Repeater {
                        model: Theme.themes
                        delegate: CarteTheme {
                            required property var modelData
                            width: Math.floor((colonne.width - 32) / 3)
                            implicitHeight: Math.round(width * 9 / 16) + 42
                            cle: modelData.cle
                            nom: modelData.nom
                            detail: modelData.detail
                            onChoisie: Session.bureau.appliquerTheme(modelData.cle)
                        }
                    }
                }

                // ── Le fond ────────────────────────────────────────────────
                Titre { text: "Fond d'écran" }
                Grid {
                    id: grilleFonds
                    width: parent.width
                    columns: 4
                    spacing: 12
                    Repeater {
                        model: Fonds.ordre(Theme.nom)
                        delegate: Item {
                            id: vignette
                            required property string modelData
                            width: (grilleFonds.width - 36) / 4
                            height: Math.round(width * 9 / 16)
                            Rectangle { anchors.fill: parent; radius: 8; color: "#000000" }
                            FondEcran {
                                anchors.fill: parent
                                anchors.margins: 1
                                fondId: vignette.modelData
                                theme: Theme.nom
                                options: Theme.optionsVignette(vignette.modelData)
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "transparent"
                                border.width: Theme.fondId === vignette.modelData ? 3 : 1
                                border.color: Theme.fondId === vignette.modelData
                                              ? (Theme.estConstellation ? Theme.texte : Theme.accent)
                                              : Theme.bord
                            }
                            // LE NOM SUR UNE PASTILLE SOMBRE : en blanc nu, il
                            // disparaissait sur les fonds clairs.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                width: nomFond.implicitWidth + 12
                                height: nomFond.implicitHeight + 4
                                radius: height / 2
                                color: Qt.rgba(0, 0, 0, 0.45)
                                Text {
                                    id: nomFond
                                    anchors.centerIn: parent
                                    text: Fonds.FONDS[vignette.modelData].nom
                                    color: "#ffffff"
                                    font.family: Theme.police
                                    font.pixelSize: 11
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: Session.bureau.choisirFond(vignette.modelData) }
                        }
                    }
                }

                // ── Les images de l'utilisateur ────────────────────────────
                Titre { text: "Vos images" }
                Text {
                    width: parent.width
                    visible: perso.images.length === 0
                    text: "Aucune image dans votre dossier Images — « Parcourir » ouvre n'importe quel dossier."
                    color: Theme.texte2
                    font.family: Theme.police
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                Flow {
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: perso.images
                        delegate: Item {
                            id: miniature
                            required property var modelData
                            readonly property bool choisie: Theme.fondId === "image:" + modelData.chemin
                            width: (grilleFonds.width - 36) / 4
                            height: Math.round(width * 9 / 16)
                            Rectangle { anchors.fill: parent; radius: 8; color: Theme.carte }
                            // DECODEE A LA TAILLE DE LA MINIATURE, jamais a la
                            // sienne : dix photos de vingt megapixels ouvertes
                            // en grand pour des vignettes, ce serait pres d'un
                            // gigaoctet. Asynchrone : la boite s'ouvre d'abord.
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: "file://" + miniature.modelData.chemin
                                sourceSize.width: Math.round(miniature.width)
                                sourceSize.height: Math.round(miniature.height)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "transparent"
                                border.width: miniature.choisie ? 3 : 1
                                border.color: miniature.choisie
                                              ? (Theme.estConstellation ? Theme.texte : Theme.accent)
                                              : Theme.bord
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: Session.bureau.choisirFond("image:" + miniature.modelData.chemin) }
                        }
                    }
                    // « PARCOURIR » OUVRE LA BOITE DE KDE (kdialog), pas une
                    // boite ecrite ici : la vraie, avec ses favoris et ses
                    // apercus. Elle tourne dans un fil ; la reponse revient par
                    // pont.imageChoisie.
                    Rectangle {
                        width: (grilleFonds.width - 36) / 4
                        height: Math.round(width * 9 / 16)
                        radius: 8
                        color: survolParcourir.hovered ? Theme.verre2 : Theme.carte
                        border.width: 1
                        border.color: Theme.bord
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Glyphe {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 22; height: 22
                                nom: "i-dossier"
                                couleur: Theme.texte2
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Parcourir…"
                                color: Theme.texte
                                font.family: Theme.police
                                font.pixelSize: 13
                            }
                        }
                        HoverHandler { id: survolParcourir; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: pont.choisirImage() }
                    }
                }

                // ── Windows : le mode et l'accent ──────────────────────────
                Column {
                    visible: Theme.estWindows
                    width: parent.width
                    spacing: 12
                    Titre { text: "Mode" }
                    Row {
                        spacing: 8
                        Segment {
                            texte: "Clair"
                            choisi: !Theme.sombreWindows
                            onClique: Session.bureau.reglerTheme("sombre_windows", false)
                        }
                        Segment {
                            texte: "Sombre"
                            choisi: Theme.sombreWindows
                            onClique: Session.bureau.reglerTheme("sombre_windows", true)
                        }
                    }
                    Titre { text: "Couleur d'accentuation" }
                    LigneReglage {
                        texte: "Automatique"
                        detail: "la couleur vient du fond d'écran"
                        actif: Theme.accentWindows === ""
                        onBascule: Session.bureau.reglerTheme("accent_windows",
                            Theme.accentWindows === "" ? Theme.accentBase : "")
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: ["#FFB900", "#FF8C00", "#CA5010", "#E81123", "#E3008C",
                                    "#B146C2", "#8764B8", "#744DA9", "#0078D4", "#0063B1",
                                    "#0099BC", "#038387", "#00B294", "#10893E", "#498205",
                                    "#68768A", "#7A7574", "#4C4A48"]
                            delegate: Nuance {
                                required property string modelData
                                couleur: modelData
                                choisie: Theme.accentWindows.toUpperCase() === modelData
                                onClique: Session.bureau.reglerTheme("accent_windows", modelData)
                            }
                        }
                    }
                }

                // ── Android : le mode et la palette ────────────────────────
                Column {
                    visible: Theme.estAndroid
                    width: parent.width
                    spacing: 12
                    Titre { text: "Mode" }
                    Row {
                        spacing: 8
                        Segment {
                            texte: "Clair"
                            choisi: !Theme.sombreAndroid
                            onClique: Session.bureau.reglerTheme("sombre_android", false)
                        }
                        Segment {
                            texte: "Sombre"
                            choisi: Theme.sombreAndroid
                            onClique: Session.bureau.reglerTheme("sombre_android", true)
                        }
                    }
                    Titre { text: "Palette" }
                    LigneReglage {
                        texte: "Couleurs du fond d'écran"
                        detail: "Material You tire la palette du fond"
                        actif: Theme.graineAndroid === ""
                        onBascule: Session.bureau.reglerTheme("graine_android",
                            Theme.graineAndroid === "" ? Theme.graine : "")
                    }
                    Flow {
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: ["#6750A4", "#0061A4", "#006A6A", "#386A20", "#7C5800",
                                    "#8B5000", "#B3261E", "#984061", "#5C5F61"]
                            delegate: Nuance {
                                required property string modelData
                                couleur: modelData
                                choisie: Theme.graineAndroid.toUpperCase() === modelData
                                onClique: Session.bureau.reglerTheme("graine_android", modelData)
                            }
                        }
                    }
                }

                // ── Constellation : le ciel ────────────────────────────────
                Column {
                    visible: Theme.estConstellation
                    width: parent.width
                    spacing: 10
                    Titre { text: "Le ciel" }
                    LigneReglage {
                        texte: "Ciel vivant"
                        detail: "étoiles qui scintillent, profondeur, étoiles filantes"
                        actif: Theme.cielVivant
                        onBascule: Session.bureau.reglerTheme("ciel_vivant", !Theme.cielVivant)
                    }
                    LigneReglage {
                        texte: "Toujours afficher les noms"
                        actif: Session.bureau ? Session.bureau.nomsToujours : false
                        onBascule: {
                            Session.bureau.nomsToujours = !Session.bureau.nomsToujours;
                            pont.reglerFond("noms", Session.bureau.nomsToujours);
                        }
                    }
                }
            }
        }
    }
}
