import QtQuick
import QtQuick.Controls.Basic

// ═══════════════════════════════════════════════════════════════════════════
// LA BARRE DES TACHES — toujours en bas, toujours visible.
//
// POURQUOI ELLE A QUITTE LA SCENE DU BUREAU. Elle y etait, en pilule flottante,
// et elle etait donc invisible des qu'une fenetre s'ouvrait : le bureau reste
// DERRIERE, c'est ce qu'on attend d'un bureau. Une barre qu'il faut degager
// pour voir n'est pas une barre — elle vit ici dans une fenetre a elle,
// posee au-dessus des autres, comme la bulle.
//
// CE QUE LE PROTOCOLE NE PERMET PAS, ET QU'IL FAUT DIRE. Sous Wayland, un
// client ne reserve pas d'espace a l'ecran : cela demande zwlr_layer_shell_v1
// ou org_kde_plasma_shell, deux protocoles que kwin annonce mais qu'aucune
// liaison Python de cette image ne sait parler. Une fenetre maximisee passe
// donc SOUS la barre au lieu de s'arreter au-dessus. C'est le prix, il est
// connu, et il vaut mieux qu'une barre qu'on ne voit jamais.
// ═══════════════════════════════════════════════════════════════════════════

Window {
    id: barre

    // LE TITRE EST UNE CLEF : la regle kwin qui pose cette fenetre en bas la
    // reconnait par ce texte. Le changer ici sans changer regles-kwin.py la
    // renverrait au milieu de l'ecran.
    title: "S - barre"

    property int hauteur: 52

    // ELLE S'APPELAIT « fenetres », ET C'ETAIT UN PIEGE PARFAIT. La propriete
    // de contexte qui porte le pont vers kwin s'appelle « fenetres » elle
    // aussi : dans ce fichier, le nom nu designait donc LA LISTE, et
    // « fenetres.activer(...) » cherchait une methode sur un tableau. Le clic
    // arrivait, le gestionnaire explosait, et rien ne bougeait a l'ecran. Le
    // journal le disait a chaque clic — personne ne l'avait ouvert.
    //
    // Une vue ne parle plus au pont : elle previent, et Constellation agit.
    // Meme patron que menuDemande, qui lui a toujours marche.
    property var ouvertures: []

    width: Screen.width
    height: hauteur
    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
           | Qt.WindowDoesNotAcceptFocus

    signal menuDemande()
    signal activation(string ident)

    Rectangle {
        anchors.fill: parent
        // PLUS OPAQUE QUE LE VERRE DES PANNEAUX, ET C'EST MESURE : a 86 %, le
        // texte du bureau transparaissait a travers la barre et se melangeait
        // aux titres des fenetres. Un panneau qu'on regarde de temps en temps
        // peut etre translucide ; une barre qu'on lit pour choisir une fenetre,
        // non.
        color: Qt.rgba(12 / 255, 12 / 255, 20 / 255, 0.97)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.bord
        }

        // ── Le noyau : le menu Demarrer de S ──────────────────────────────
        Rectangle {
            id: noyau
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 38; height: 38; radius: 19
            border.color: Theme.bordVif
            border.width: 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#33333f" }
                GradientStop { position: 0.78; color: "#07070f" }
            }
            scale: survolNoyau.hovered ? 1.06 : 1.0
            Behavior on scale { NumberAnimation { duration: 240 } }

            HoverHandler { id: survolNoyau; cursorShape: Qt.PointingHandCursor }
            Rectangle {
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                color: "#ffffff"
            }
            TapHandler { onTapped: barre.menuDemande() }
        }

        // ── Les epinglees : ce qu'on lance, pas ce qui tourne ──────────────
        Row {
            id: epinglees
            anchors.left: noyau.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
                model: bureau.donnees.epingles
                delegate: Item {
                    required property string modelData
                    readonly property var app: bureau.appParId(modelData)
                    visible: app !== null
                    width: visible ? 32 : 0
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "transparent"
                        border.width: 1.5
                        border.color: app ? Theme.teinte(app.src) : "transparent"
                        antialiasing: true
                    }
                    Image {
                        id: icoEp
                        anchors.centerIn: parent
                        width: 17; height: 17
                        source: parent.app ? (parent.app.img || "") : ""
                        sourceSize.width: 34; sourceSize.height: 34
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: source !== "" && status === Image.Ready
                    }
                    Glyphe {
                        anchors.centerIn: parent
                        width: 15; height: 15
                        nom: parent.app ? (parent.app.ico || "i-boite") : "i-boite"
                        couleur: parent.app ? Theme.teinte(parent.app.src) : Theme.texte2
                        visible: !icoEp.visible
                    }

                    HoverHandler { id: survolEp; cursorShape: Qt.PointingHandCursor }
                    y: survolEp.hovered ? -2 : 0
                    Behavior on y { NumberAnimation { duration: 150 } }

                    ToolTip.visible: survolEp.hovered
                    ToolTip.text: app ? app.nom : ""
                    ToolTip.delay: 400

                    TapHandler {
                        onTapped: { bureau.dire(pont.lancer(parent.app.id)); bureau.relire(); }
                    }
                }
            }
        }

        // ── Le trait qui separe « ce qu'on lance » de « ce qui tourne » ────
        Rectangle {
            id: coupure
            anchors.left: epinglees.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22
            color: Theme.bord
            visible: barre.ouvertures.length > 0
        }

        // ── Les fenetres ouvertes ─────────────────────────────────────────
        // UNE FENETRE PORTE SON TITRE, PAS SEULEMENT SON ICONE, et c'est tout
        // l'interet : deux Konsole ouvertes ont la meme icone. Sans le titre,
        // changer de fenetre redevient un tirage au sort — ce qu'Alt+Tab fait
        // deja, et que cette barre existe pour eviter.
        Row {
            id: ouvertes
            anchors.left: coupure.right
            anchors.leftMargin: 12
            anchors.right: horloge.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            clip: true

            Repeater {
                model: barre.ouvertures
                delegate: Rectangle {
                    required property var modelData
                    readonly property var app: bureau.appParId(modelData.classe)

                    // La largeur se partage, avec un plancher et un plafond :
                    // douze fenetres ouvertes ne doivent pas rendre les titres
                    // illisibles, et deux ne doivent pas occuper l'ecran.
                    width: Math.max(46, Math.min(210,
                        (ouvertes.width - (barre.ouvertures.length - 1) * 6)
                        / Math.max(1, barre.ouvertures.length)))
                    height: 34
                    radius: 8
                    color: modelData.active ? Theme.verre2
                                            : (survolF.hovered ? Qt.rgba(1,1,1,0.03)
                                                               : "transparent")
                    Behavior on color { ColorAnimation { duration: 130 } }

                    // Le liseré du monde : rouge Linux, bleu Windows, vert
                    // Android. La meme grammaire que les etoiles du ciel.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: parent.height - 12
                        radius: 1
                        color: parent.app ? Theme.teinte(parent.app.src) : Theme.texte3
                        opacity: modelData.active ? 1 : 0.55
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 7

                        Item {
                            width: 17; height: 17
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: icoF
                                anchors.fill: parent
                                source: parent.parent.parent.app
                                        ? (parent.parent.parent.app.img || "") : ""
                                sourceSize.width: 34; sourceSize.height: 34
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                visible: source !== "" && status === Image.Ready
                            }
                            Glyphe {
                                anchors.fill: parent
                                nom: parent.parent.parent.app
                                     ? (parent.parent.parent.app.ico || "i-boite") : "i-boite"
                                couleur: Theme.texte2
                                visible: !icoF.visible
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 17 - 7 - 18
                            text: modelData.titre
                            color: modelData.active ? Theme.texte : Theme.texte2
                            font.family: Theme.police
                            font.pixelSize: 12
                            // Une fenetre reduite se lit en italique : c'est le
                            // seul etat qu'on ne devine pas en regardant l'ecran.
                            font.italic: modelData.reduite
                            elide: Text.ElideRight
                            visible: parent.parent.width > 90
                        }
                    }

                    HoverHandler { id: survolF; cursorShape: Qt.PointingHandCursor }
                    ToolTip.visible: survolF.hovered && width <= 90
                    ToolTip.text: modelData.titre
                    ToolTip.delay: 400

                    TapHandler { onTapped: barre.activation(modelData.id) }
                }
            }
        }

        // ── L'heure ───────────────────────────────────────────────────────
        Text {
            id: horloge
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.texte2
            font.family: Theme.policeMono
            font.pixelSize: 12
            text: "--:--"
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: horloge.text = Qt.formatTime(new Date(), "HH:mm")
            }
        }
    }
}
