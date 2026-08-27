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

    // LE NOM D'UNE EPINGLEE S'AFFICHE AU-DESSUS D'ELLE, JAMAIS DESSUS.
    // L'infobulle de Qt se posait PAR-DESSUS la pastille — il n'y a pas la
    // place de la mettre en dessous, la barre touche le bas de l'ecran — et
    // elle arrivait assez vite pour intercepter le clic qu'on etait en train
    // de faire. Une etiquette qui empeche d'atteindre ce qu'elle nomme est
    // pire que pas d'etiquette du tout.
    property string nomSurvole: ""
    property real centreSurvole: 0

    width: Screen.width
    height: hauteur
    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
           | Qt.WindowDoesNotAcceptFocus

    // CE QUE LA BARRE AFFICHE DE LA VEILLE, ET QU'ELLE NE CALCULE PAS. Le mode
    // et le compte des fenetres oubliees viennent de Constellation, qui les
    // tient du pont. La barre est une vue : elle montre, elle previent, elle
    // ne demande rien elle-meme. Voir le piege du nom « fenetres » plus haut —
    // il a coute un clic mort a chaque entree de la barre.
    property string veille: "geler"
    property int inactives: 0
    // DIX JOURS, PARCE QUE L'UTILISATEUR A DIT DIX JOURS. Le nombre est ici et
    // dans l'etiquette du menu, jamais ecrit deux fois.
    property int joursInactivite: 10

    signal menuDemande()
    signal fermeture(string ident)
    signal sommeil(string ident)
    signal menageDemande(int jours)
    signal veilleChoisie(string mode)
    // LE COMPTE DES OUBLIEES SE DEMANDE A L'OUVERTURE DU MENU, PAS EN CONTINU.
    // Il se refaisait a chaque nouvelle du compositeur — donc a chaque
    // changement de titre, donc plusieurs fois par seconde pendant qu'on tape
    // dans un terminal — pour une etiquette que personne ne regarde tant que
    // le menu est ferme.
    signal inactivesDemandees()
    // ELLE TRANSMET L'ETAT QU'ELLE AFFICHE, ET C'EST TOUT L'OBJET DU SECOND
    // ARGUMENT. Laisser kwin relire « quelle fenetre est active » au moment ou
    // le script tourne rend une reponse qui a pu changer depuis le clic : le
    // premier clic reactivait alors sans rien faire de visible, et il en
    // fallait deux pour reduire. La barre, elle, sait ce qu'elle vient de
    // montrer a l'utilisateur — c'est cette verite-la qu'il a cliquee.
    signal activation(string ident, bool estActive)

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
            // ELLES DESCENDENT DE SEPT PIXELS, et c'est tout le correctif :
            // ces sept pixels, plus les onze deja libres au-dessus, font la
            // place ou le nom peut s'ecrire sans couvrir la pastille.
            anchors.verticalCenterOffset: 7
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

                    Connections {
                        target: survolEp
                        function onHoveredChanged() {
                            if (survolEp.hovered) {
                                barre.nomSurvole = parent.app ? parent.app.nom : "";
                                barre.centreSurvole = parent.mapToItem(
                                    null, parent.width / 2, 0).x;
                            } else if (barre.nomSurvole ===
                                       (parent.app ? parent.app.nom : "")) {
                                barre.nomSurvole = "";
                            }
                        }
                    }

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

                    TapHandler {
                        onTapped: barre.activation(modelData.id,
                                                   modelData.active === true)
                    }

                    // ── LE CLIC DROIT, QUI N'EXISTAIT PAS ─────────────────
                    // Il n'y avait AUCUN moyen de fermer une fenetre depuis
                    // la barre : il fallait la remonter, viser sa croix, et
                    // celle d'un programme Windows n'est pas au meme endroit
                    // que celle d'un programme Linux. Releve par l'utilisateur
                    // le 2026-08-26 : « pas de clic droit fermer la fenetre ».
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: function (point) {
                            menuFenetre.ouvrirPour(
                                modelData,
                                parent.mapToItem(null, point.position.x, 0).x);
                        }
                    }
                }
            }
        }

        // ── Le nom de l'epinglee survolee ─────────────────────────────────
        Rectangle {
            id: etiquette
            visible: barre.nomSurvole !== ""
            // Bornee aux deux extremites : une epinglee tout a gauche ne doit
            // pas faire deborder son nom hors de l'ecran.
            x: Math.max(4, Math.min(parent.width - width - 4,
                                    barre.centreSurvole - width / 2))
            y: 2
            width: nomTexte.implicitWidth + 14
            height: 15
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.10)
            Text {
                id: nomTexte
                anchors.centerIn: parent
                text: barre.nomSurvole
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 10
            }
        }

        // ── Le menu du clic droit sur une fenetre ─────────────────────────
        //
        // IL EST DESSINE DANS LA FENETRE DE LA BARRE, ET C'ETAIT LE SEUL CHOIX.
        // Le menu du bureau vit dans Constellation.qml — mais le bureau reste
        // DERRIERE toutes les fenetres, c'est sa place. Un menu ouvert la
        // s'afficherait sous la fenetre qu'il propose de fermer. La barre, elle,
        // porte « WindowStaysOnTop » : ce qu'elle ouvre passe devant.
        //
        // IL S'OUVRE VERS LE HAUT, EXPLICITEMENT. La barre touche le bas de
        // l'ecran et ne fait que cinquante-deux pixels ; on ne s'en remet pas au
        // rabattement automatique, qui depend du positionneur du compositeur.
        Menu {
            id: menuFenetre
            objectName: "menuFenetre"

            // IL A SA PROPRE FENETRE, ET C'EST MESURE. Un Popup ordinaire est
            // mis en page DANS sa fenetre hote et s'y trouve borne : neuf
            // articles hauts de 360 pixels rendaient « height 52 », la hauteur
            // de la barre, soit une ligne visible sur neuf. Mesure hors ecran,
            // meme scene, Qt 6.11 :
            //     defaut        implicitHeight 360 -> height  52
            //     Popup.Window  implicitHeight 360 -> height 360
            popupType: Popup.Window

            // L'IDENTIFIANT PLUTOT QUE L'OBJET, PARCE QUE LA LISTE EST
            // REMPLACEE EN ENTIER. « ouvertures » est refait par JSON.parse a
            // chaque nouvelle de kwin : garder le modelData du delegue laissait
            // le menu decrire un etat perime — « Ranger » sur une fenetre deja
            // rangee, « Mettre en veille » sur une fenetre endormie. Les
            // identifiants kwin, eux, ne bougent pas.
            property string cibleId: ""
            readonly property var cible: {
                for (var i = 0; i < barre.ouvertures.length; i++)
                    if (barre.ouvertures[i].id === menuFenetre.cibleId)
                        return barre.ouvertures[i];
                return null;
            }
            readonly property bool rangee: cible !== null && cible.reduite === true

            // Une fenetre qui disparait pendant que son menu est ouvert
            // laisserait un menu qui ne vise plus rien.
            onCibleChanged: if (cible === null && visible) close()

            // ON SE POSE SUR LES TAILLES IMPLICITES, JAMAIS SUR LES EFFECTIVES.
            // « height » vaut l'implicite avant la premiere ouverture et la
            // valeur bornee ensuite : le menu se posait a deux hauteurs
            // differentes selon qu'on l'avait deja ouvert ou non.
            function ouvrirPour(fenetre, ex) {
                cibleId = fenetre.id;
                barre.inactivesDemandees();
                popup(Math.max(4, Math.min(barre.width - implicitWidth - 4,
                                           ex - implicitWidth / 2)),
                      -implicitHeight - 6);
            }

            background: Verre {
                radius: 8
                implicitWidth: 268
            }

            ArticleMenu {
                text: menuFenetre.rangee ? "Afficher" : "Ranger"
                onTriggered: barre.activation(menuFenetre.cibleId,
                                              !menuFenetre.rangee)
            }

            ArticleMenu {
                // Sans objet quand la veille ne gele rien : l'article
                // promettrait un arret qui n'aurait pas lieu.
                visible: barre.veille === "geler" && !menuFenetre.rangee
                height: visible ? implicitHeight : 0
                text: "Mettre en veille maintenant"
                onTriggered: barre.sommeil(menuFenetre.cibleId)
            }

            SeparateurMenu { }

            ArticleMenu {
                grave: true
                text: "Fermer la fenetre"
                onTriggered: barre.fermeture(menuFenetre.cibleId)
            }

            ArticleMenu {
                // LE COMPTE EST DANS L'ETIQUETTE. « Fermer les fenetres
                // inactives » sans nombre demande a l'utilisateur de cliquer
                // pour savoir ce qu'il detruit. A zero, l'article se grise au
                // lieu de disparaitre : son absence ne dirait pas qu'il n'y a
                // rien a fermer, elle dirait que la fonction n'existe pas.
                grave: barre.inactives > 0
                enabled: barre.inactives > 0
                opacity: enabled ? 1 : 0.45
                text: barre.inactives > 0
                      ? "Fermer %1 fenetre%2 inactive%2 depuis %3 j"
                        .arg(barre.inactives)
                        .arg(barre.inactives > 1 ? "s" : "")
                        .arg(barre.joursInactivite)
                      : "Aucune fenetre inactive depuis %1 j"
                        .arg(barre.joursInactivite)
                onTriggered: barre.menageDemande(barre.joursInactivite)
            }

            SeparateurMenu { }

            // ── Le mode de veille, reglable la ou il se voit ───────────────
            // TROIS ARTICLES PLUTOT QU'UN SOUS-MENU. Le style « Basic » ne
            // peint rien de lui-meme (voir ArticleMenu.qml) : un sous-menu
            // demanderait d'habiller une seconde fois le fond, la fleche et
            // le survol, pour trois lignes qu'on lit d'un coup d'oeil.
            Repeater {
                model: [
                    { cle: "non", nom: "Veille : aucune" },
                    { cle: "reduire", nom: "Veille : ranger les autres" },
                    { cle: "geler", nom: "Veille : arreter les programmes" }
                ]
                delegate: ArticleMenu {
                    required property var modelData
                    text: (barre.veille === modelData.cle ? "\u2713  " : "     ")
                          + modelData.nom
                    onTriggered: barre.veilleChoisie(modelData.cle)
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
