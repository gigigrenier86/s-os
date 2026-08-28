import QtQuick
import QtQuick.Controls.Basic

// La barre laterale de S : une fine ligne au bord droit, qui se deploie en une
// colonne d'etoiles au contact de la souris.
//
// ═══ TROIS LARGEURS, ET ELLES NE SE CONFONDENT PAS ═════════════════════════
//
//   « largeur »       la FENETRE. Elle ne change jamais et ne bouge jamais.
//   « largeurBarre »  ce qu'on VOIT deploye : une colonne d'etoiles, fine.
//   « epaisseurLigne » ce qu'on voit replie : la poignee, cinq pixels.
//
// LA FENETRE EST PLUS LARGE QUE LA BARRE, ET C'EST DELIBERE. Le nom d'un
// reglage ne tient pas dans soixante-seize pixels ; il s'ecrit donc A GAUCHE de
// la colonne, dans le reste de la fenetre. Une infobulle de Qt ferait l'affaire
// ailleurs — pas ici : au bord droit de l'ecran, elle se poserait PAR-DESSUS la
// colonne qu'elle nomme, exactement le defaut corrige sur la barre des taches
// le 2026-08-25.
//
// ET LA FENETRE NE PEUT PAS SE RETRECIR A LA DEMANDE : un client Wayland ne se
// positionne pas lui-meme — mesure du 2026-08-25, une fenetre demandant x=1516
// s'est affichee au centre de l'ecran. Une languette qui grandirait devrait
// etre replacee par kwin a chaque ouverture, et on la verrait sauter.
//
// CE QUI CHANGE, C'EST DONC SA ZONE SENSIBLE, jamais sa taille. Repliee, elle
// ne recoit la souris que sur ses cinq derniers pixels et laisse tout le reste
// cliquer AU TRAVERS, jusqu'au bureau. C'est « pont.bornerLaterale » qui le
// pose : QML n'expose pas « mask » sur une Window.
Window {
    id: laterale

    readonly property int largeur: 300
    readonly property int largeurBarre: 76
    // UN SEUL PIXEL, ET C'EST DELIBERE — demande de l'utilisateur le 2026-08-26 :
    // « elle s'active trop tot, elle devrait s'ouvrir au point mort de la souris,
    // quand elle ne peut plus aller plus loin ». A 5 px, la zone sensible se
    // declenchait en TRAVERSANT le bord, pas en s'y arretant. A 1 px, la seule
    // position qui l'ouvre est le dernier pixel de l'ecran — celui ou le
    // curseur reste PARCE QU'IL NE PEUT PAS ALLER PLUS LOIN, jamais un survol
    // de passage. Fiable a cette largeur : le compositeur clampe deja le
    // curseur au bord de l'ecran, donc pousser la souris a droite l'y amene
    // toujours, sans viser un pixel precis a l'oeil.
    readonly property int epaisseurLigne: 1

    property bool deploye: false
    // Un jeu en plein ecran fait disparaitre la barre ENTIEREMENT. Demande de
    // l'utilisateur, mot pour mot : « apparaissant quand nous ne sommes pas en
    // train de jouer a un jeu par exemple ».
    property bool efface: false
    property var reglages: []
    // Le reglage survole, dont on ecrit le nom a gauche. Null quand aucun.
    property var survole: null

    // LES TEINTES SONT RETIREES A CHAQUE OUVERTURE, et c'est une demande de
    // l'utilisateur du 2026-08-26 : la colonne etait monochrome et terne.
    // Elles ne veulent rien dire — un reglage n'appartient a aucun monde —
    // c'est justement pourquoi elles peuvent changer : une couleur qui
    // signifiait quelque chose ne pourrait pas bouger sans mentir.
    property var teintes: []

    signal reglageBascule(string cle, bool vers)
    signal reglageValeur(string cle, real valeur)
    signal reglageChoix(string cle, string valeur)
    signal reglageAction(string cle)
    signal ouverte()

    objectName: "barreLaterale"
    title: "S - barre laterale"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    width: largeur
    height: Screen.height
    visible: !efface

    // LA ZONE SENSIBLE SUIT L'ETAT, ET C'EST QML QUI LE DIT AU PONT. La
    // premiere version gardait la fenetre cote Python : son enveloppe etait
    // liberee par PySide6 des le premier retour a la boucle, et le masque
    // n'etait jamais repose — la souris n'entrait donc jamais dans le panneau,
    // qui se refermait sous le doigt.
    function borner() {
        if (typeof pont !== "undefined" && pont && pont.bornerLaterale)
            pont.bornerLaterale(laterale, deploye);
    }

    onDeployeChanged: {
        borner();
        if (!deploye) { glissiere.visible = false; choix.visible = false; }
        if (deploye) {
            // Le tirage precede l'appel : « ouverte » va demander au pont de
            // relire les reglages, et sa reponse arrive apres — les etoiles
            // seraient repeintes deux fois si l'ordre etait inverse.
            teintes = Theme.tirage(Math.max(reglages.length, 12));
            laterale.ouverte();
        } else {
            survole = null;
        }
    }

    // Un reglage qui arrive APRES l'ouverture — la premiere lecture met pres
    // d'une seconde — doit trouver sa teinte deja tiree. On complete si la
    // liste s'allonge, sans retirer celles qui sont deja a l'ecran.
    onReglagesChanged: if (teintes.length < reglages.length)
                           teintes = Theme.tirage(reglages.length + 4)
    onWidthChanged: borner()
    onHeightChanged: borner()
    Component.onCompleted: borner()

    // ── La fine ligne, toujours la ────────────────────────────────────────
    Rectangle {
        id: ligne
        anchors.right: parent.right
        width: laterale.epaisseurLigne
        height: parent.height
        opacity: laterale.deploye ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // Un degrade plutot qu'un a-plat : une ligne uniforme sur mille pixels
        // se lit comme un defaut d'affichage, pas comme une poignee.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.28) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.05) }
        }

        HoverHandler {
            id: survolLigne
            onHoveredChanged: {
                if (hovered) laterale.deploye = true;
                else if (laterale.deploye) fermeture.restart();
            }
        }
    }

    // ── Le nom du reglage survole, ecrit A GAUCHE de la colonne ────────────
    Verre {
        id: etiquette
        anchors.right: colonne.left
        anchors.rightMargin: 10
        y: laterale.survole ? laterale.survole.y : 0
        height: 44
        width: Math.min(200, texteNom.implicitWidth + 26)
        radius: 8
        visible: laterale.deploye && laterale.survole !== null
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
                id: texteNom
                text: laterale.survole ? (laterale.survole.nom || "") : ""
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 12
            }
            Text {
                text: laterale.survole ? (laterale.survole.detail || "") : ""
                color: Theme.texte3
                font.family: Theme.policeMono
                font.pixelSize: 10
                visible: text !== ""
            }
        }
    }

    // ── La colonne d'etoiles ──────────────────────────────────────────────
    Verre {
        id: colonne
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: laterale.largeurBarre
        radius: 0
        // Elle glisse depuis le bord droit : cela dit d'ou elle vient et ou
        // elle retourne.
        x: laterale.deploye ? laterale.largeur - laterale.largeurBarre
                            : laterale.largeur
        opacity: laterale.deploye ? 1 : 0
        visible: opacity > 0
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        HoverHandler {
            id: survolColonne
            onHoveredChanged: if (!hovered && laterale.deploye) fermeture.restart()
        }

        Timer {
            id: fermeture
            interval: 500
            // ON VERIFIE LE SURVOL, JAMAIS LA VISIBILITE — c'est le defaut
            // trouve le 2026-08-28 : « !glissiere.visible » ne redevient
            // jamais vrai une fois la glissiere ouverte (rien dans ce fichier
            // ne la referme d'elle-meme), donc ce minuteur refusait de fermer
            // pour toujours des qu'on avait clique une seule jauge. La souris
            // a pu passer de la ligne a la colonne, ou de la colonne aux
            // possibilites d'un choix ou d'une glissiere : c'est leur survol
            // qui doit suspendre la fermeture, pas leur presence a l'ecran.
            onTriggered: if (!survolColonne.hovered && !survolLigne.hovered
                             && !survolChoix.hovered && !survolGlissiere.hovered)
                             laterale.deploye = false
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 22
            spacing: 10

            Repeater {
                objectName: "repeaterReglages"
                model: laterale.reglages

                delegate: EtoileReglage {
                    required property var modelData
                    required property int index
                    reglage: modelData
                    diametre: 46
                    teinteImposee: index < laterale.teintes.length
                                   ? laterale.teintes[index] : Theme.texte

                    // Le nom part a gauche, avec la hauteur de cette etoile —
                    // c'est ce qui fait que l'etiquette se pose EN FACE.
                    onHoveredChanged: {
                        if (hovered)
                            laterale.survole = {
                                "nom": modelData.nom || "",
                                "detail": modelData.detail || "",
                                "y": mapToItem(laterale.contentItem, 0, 0).y - 0
                            };
                        else if (laterale.survole
                                 && laterale.survole.nom === (modelData.nom || ""))
                            laterale.survole = null;
                    }

                    onBascule: {
                        if (modelData.type === "action")
                            laterale.reglageAction(modelData.cle);
                        else
                            laterale.reglageBascule(modelData.cle,
                                                    !(modelData.actif === true));
                    }
                    onValeurDemandee: function (v) {
                        laterale.reglageValeur(modelData.cle, v);
                    }
                    onChoixDemande: choix.ouvrirPour(modelData,
                                                     mapToItem(laterale.contentItem, 0, 0).y)
                    onGlissiereDemandee: glissiere.ouvrirPour(
                        modelData, mapToItem(laterale.contentItem, 0, 0).y, this)
                }
            }
        }
    }

    // ── LA GLISSIERE, a gauche de la colonne ──────────────────────────────
    //
    // POURQUOI ELLE EXISTE. La molette reglait a l'aveugle : la valeur ne se
    // relit qu'apres pres d'une seconde d'I2C, donc l'anneau montrait l'ancienne
    // pendant qu'on tournait. Le 2026-08-26, l'utilisateur a ainsi descendu
    // luminosite ET contraste a zero — ecran noir, et la barre qui aurait permis
    // de remonter invisible avec le reste.
    //
    // LE DIFFERE N'EST PAS UN CONFORT. Chaque changement de luminosite coute un
    // aller-retour I2C de pres d'une demi-seconde ; un glissement en produit
    // cinquante. Sans attendre l'arret du doigt, on empilerait cinquante
    // commandes que l'ecran executerait longtemps apres.
    Verre {
        id: glissiere
        anchors.right: colonne.left
        anchors.rightMargin: 10
        width: 190
        height: 54
        radius: 8
        visible: false

        property string cle: ""
        property real valeur: 0
        property real maximum: 100
        property real plancher: 0
        property var etoile: null

        function ouvrirPour(reglage, hauteur, source) {
            cle = reglage.cle || "";
            maximum = reglage.max || 100;
            plancher = (cle === "luminosite" || cle === "contraste") ? 10 : 0;
            valeur = reglage.valeur || 0;
            etoile = source || null;
            y = Math.max(8, Math.min(laterale.height - height - 8, hauteur - 4));
            choix.visible = false;
            visible = true;
        }

        HoverHandler {
            id: survolGlissiere
            onHoveredChanged: if (!hovered && laterale.deploye) fermeture.restart()
        }

        Timer {
            id: differe
            interval: 180
            onTriggered: laterale.reglageValeur(glissiere.cle,
                                                Math.round(glissiere.valeur))
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: Math.round(glissiere.valeur) + " %"
                color: Theme.texte
                font.family: Theme.policeMono
                font.pixelSize: 12
            }

            Item {
                id: piste
                width: parent.width
                height: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.verre2
                    border.color: Theme.bord
                    border.width: 1
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * (glissiere.valeur / glissiere.maximum)
                    height: 4
                    radius: 2
                    // La glissiere prend la teinte de l'etoile qu'elle regle :
                    // c'est ce qui dit LAQUELLE on est en train de changer.
                    color: glissiere.etoile ? glissiere.etoile.teinte : Theme.texte
                }

                Rectangle {
                    id: pastille
                    x: parent.width * (glissiere.valeur / glissiere.maximum) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7
                    color: Theme.espace
                    border.width: 2
                    border.color: glissiere.etoile ? glissiere.etoile.teinte : Theme.texte
                }

                function viser(x) {
                    var f = Math.max(0, Math.min(1, x / piste.width));
                    var v = Math.max(glissiere.plancher, f * glissiere.maximum);
                    glissiere.valeur = v;
                    // L'anneau de l'etoile suit le doigt, lui aussi.
                    if (glissiere.etoile) glissiere.etoile.valeurLocale = v;
                    differe.restart();
                }

                TapHandler { onTapped: function (e) { piste.viser(e.position.x); } }
                DragHandler {
                    target: null
                    onCentroidChanged: if (active) piste.viser(centroid.position.x)
                }
            }
        }
    }

    // ── Les possibilites d'un reglage « choix », a gauche de la colonne ────
    Verre {
        id: choix
        anchors.right: colonne.left
        anchors.rightMargin: 10
        width: 150
        height: liste.implicitHeight + 16
        radius: 8
        visible: false

        property string cle: ""
        property var possibles: []

        function ouvrirPour(reglage, hauteur) {
            cle = reglage.cle || "";
            possibles = reglage.choix || [];
            y = Math.max(8, hauteur);
            glissiere.visible = false;
            visible = possibles.length > 0;
        }

        HoverHandler {
            id: survolChoix
            onHoveredChanged: if (!hovered && laterale.deploye) fermeture.restart()
        }

        Column {
            id: liste
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 2

            Repeater {
                model: choix.possibles
                delegate: Rectangle {
                    required property var modelData
                    width: liste.width
                    height: 26
                    radius: 5
                    color: zone.hovered ? Theme.verre2 : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.nom || ""
                        color: zone.hovered ? Theme.texte : Theme.texte2
                        font.family: Theme.police
                        font.pixelSize: 12
                    }
                    HoverHandler { id: zone; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            laterale.reglageChoix(choix.cle, modelData.cle);
                            choix.visible = false;
                        }
                    }
                }
            }
        }
    }
}
