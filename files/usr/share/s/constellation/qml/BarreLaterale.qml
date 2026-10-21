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

    // 360 DEPUIS LE 2026-10-20 : c'est la largeur des reglages rapides de
    // Windows 11 et du volet d'une tablette Android. La colonne de
    // Constellation, elle, n'a pas bouge — la fenetre est seulement plus large
    // a sa gauche, ou elle ecrit deja le nom du reglage survole.
    readonly property int largeur: 360
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
    readonly property int epaisseurLigne: 0

    // LA POIGNEE NE COUVRE PLUS TOUTE LA HAUTEUR DE L'ECRAN — demande de
    // l'utilisateur le 2026-08-27, capture a l'appui : pousser la souris vers
    // les boutons de fenetre d'une application (coin haut-droit) ou vers
    // l'horloge de la barre des taches (coin bas-droit) declenchait la barre
    // laterale sans le vouloir, puisque la poignee de 1 px s'etendait sur
    // TOUTE la hauteur, y compris ces deux coins.
    //
    //   margeHaut  Espace ou une fenetre applicative pose d'ordinaire ses
    //              boutons (reduire/agrandir/fermer) — coin haut-droit,
    //              convention de bureau bien etablie, pas une fenetre en
    //              particulier.
    //   margeBas   La HAUTEUR EXACTE de la barre des taches (Barre.qml,
    //              hauteur: 52) : l'horloge y vit, dans le coin bas-droit.
    //              Meme valeur des deux cotes, jamais recopiee a l'oeil —
    //              une des deux dériverait sinon sans que l'autre bouge.
    readonly property int margeHaut: 48
    readonly property int margeBas: 52

    property bool deploye: false
    // Un jeu en plein ecran fait disparaitre la barre ENTIEREMENT. Demande de
    // l'utilisateur, mot pour mot : « apparaissant quand nous ne sommes pas en
    // train de jouer a un jeu par exemple ».
    property bool efface: false
    property var reglages: []

    // LE REPEATER REGARDE LES CLES, PAS LES REGLAGES. Chaque ouverture de la
    // barre relance les sondes et remplace « reglages » en entier ; un Repeater
    // dont le tableau change — d'UNE valeur, un volume qui passe de 131 a 130 —
    // detruit et recree TOUTES ses etoiles, au moment precis ou l'on commence a
    // s'en servir : la glissiere ouverte visait une etoile qui n'existait plus.
    // Un tableau de cles, lui, ne change que si l'ENSEMBLE des reglages change
    // (Qt compare deux tableaux par valeur), et chaque etoile relit sa donnee
    // par cle : elle se met a jour sur place, sans etre recreee.
    readonly property var cles: reglages.map(function (r) { return r.cle; })
    function reglageDe(cle) {
        for (var i = 0; i < reglages.length; i++)
            if (reglages[i].cle === cle)
                return reglages[i];
        return ({});
    }
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
    // LA BASCULE DU SON — correctif du 2026-10-20, voir EtoileReglage.qml.
    // Distinct de reglageBascule : celui-ci enverrait un booleen a la
    // place d'un pourcentage sur la cle "volume" de la glissiere.
    signal reglageMuet(string cle)
    signal ouverte()
    // Le rouage des reglages rapides de Windows et d'Android ouvre la boite de
    // personnalisation, comme celui de leurs vrais panneaux.
    signal personnaliserDemande()
    // Prevenir la mise en page courante qu'on se replie : elle ferme ce qu'elle
    // a ouvert (la glissiere, la liste d'un choix). Un signal plutot qu'un acces
    // direct, parce que ces pieces vivent dans un Loader.
    signal replier()

    objectName: "barreLaterale"
    title: "S - barre laterale"
    // « WindowDoesNotAcceptFocus » MANQUAIT ICI, ET NULLE PART AILLEURS DANS
    // CE FICHIER. Barre.qml et Bulle.qml le portent tous les deux — trouve
    // le 2026-09-05 en mesurant, avec un temoin D-Bus, que cliquer un
    // reglage de cette fenetre laissait « S - barre laterale » activee POUR
    // DE BON, sans jamais rendre l'activation a la vraie fenetre derriere.
    // Voir fenetres.js::estChromeS pour le rattrapage general qui accompagne
    // ce correctif — ce drapeau seul ne suffit pas (Barre.qml le porte deja
    // et se fait quand meme activer par kwin a chaque clic, mesure le meme
    // jour), mais l'absence ici etait une incoherence sans raison connue.
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
           | Qt.WindowDoesNotAcceptFocus
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
        if (!deploye) laterale.replier();
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

    Shortcut {
        sequence: "Escape"
        enabled: laterale.deploye
        onActivated: laterale.deploye = false
    }

    // ══ LA MISE EN PAGE, SELON LE THEME ═══════════════════════════════════
    // UNE SEULE EST VIVANTE A LA FOIS. Constellation garde sa colonne
    // d'etoiles ; Windows et Android montrent leurs reglages rapides. Les
    // reglages, les signaux et la zone sensible sont les memes pour les trois :
    // ils vivent au-dessus, dans cette fenetre.
    Loader {
        id: miseEnPage
        anchors.fill: parent
        sourceComponent: Theme.estConstellation ? miseConstellation : miseRapide
    }

    Component {
        id: miseConstellation
        Item {
            id: miseC
            anchors.fill: parent

            Connections {
                target: laterale
                function onReplier() { glissiere.visible = false; choix.visible = false; }
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
            // LA BARRE MONTE DEPUIS LE BAS, AU-DESSUS DE L'ETOILE OPTION.
            // Demande expresse de l'utilisateur du 2026-09-10 : elle ne doit plus pop
            // au contact du bord de l'ecran (« c'est tannant »), mais monter au-dessus
            // de la barre des taches lors d'un clic sur l'etoile option a cote de l'heure.
            Verre {
                id: colonne
                anchors.right: parent.right
                y: laterale.deploye ? laterale.margeHaut : (parent.height - laterale.margeBas)
                height: parent.height - laterale.margeHaut - laterale.margeBas
                width: laterale.largeurBarre
                radius: 8
                x: laterale.largeur - laterale.largeurBarre
                opacity: laterale.deploye ? 1 : 0
                visible: opacity > 0

                Behavior on y {
                    NumberAnimation {
                        duration: laterale.deploye ? (Theme.dureeNormale + 40) : Theme.dureeRapide
                        easing.type: laterale.deploye ? Easing.OutCubic : Easing.InQuad
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: laterale.deploye ? Theme.dureeNormale : Theme.dureeRapide
                    }
                }

                HoverHandler {
                    id: survolColonne
                    onHoveredChanged: if (!hovered && laterale.deploye) fermeture.restart()
                }

                Timer {
                    id: fermeture
                    interval: 600
                    onTriggered: if (!survolColonne.hovered
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
                        model: laterale.cles

                        delegate: EtoileReglage {
                            // La cle du reglage ; « donnee » est sa valeur COURANTE,
                            // relue chaque fois que « reglages » est remplace.
                            required property string modelData
                            required property int index
                            readonly property var donnee: laterale.reglageDe(modelData)
                            reglage: donnee
                            diametre: 46
                            teinteImposee: index < laterale.teintes.length
                                           ? laterale.teintes[index] : Theme.texte

                            // Le nom part a gauche, avec la hauteur de cette etoile —
                            // c'est ce qui fait que l'etiquette se pose EN FACE.
                            onHoveredChanged: {
                                if (hovered)
                                    laterale.survole = {
                                        "nom": donnee.nom || "",
                                        "detail": donnee.detail || "",
                                        "y": mapToItem(laterale.contentItem, 0, 0).y - 0
                                    };
                                else if (laterale.survole
                                         && laterale.survole.nom === (donnee.nom || ""))
                                    laterale.survole = null;
                            }

                            onBascule: {
                                if (donnee.type === "action")
                                    laterale.reglageAction(donnee.cle);
                                else
                                    laterale.reglageBascule(donnee.cle,
                                                            !(donnee.actif === true));
                            }
                            onValeurDemandee: function (v) {
                                laterale.reglageValeur(donnee.cle, v);
                            }
                            onMuetDemande: laterale.reglageMuet(donnee.cle)
                            onChoixDemande: choix.ouvrirPour(donnee,
                                                             mapToItem(laterale.contentItem, 0, 0).y)
                            onGlissiereDemandee: glissiere.ouvrirPour(
                                donnee, mapToItem(laterale.contentItem, 0, 0).y, this)
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
                    plancher = (cle === "luminosite") ? 10 : 0;
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
    }

    // ── WINDOWS 11 ET ANDROID : les reglages rapides ──────────────────────
    // Windows les ouvre EN BAS, au-dessus de la barre, d'un clic sur ses
    // icones ; une tablette Android, EN HAUT a droite. Le panneau monte ou
    // descend de quelques pixels en apparaissant, comme sur les deux.
    Component {
        id: miseRapide
        Item {
            id: miseR
            anchors.fill: parent

            readonly property var tuiles: laterale.cles.filter(function (c) {
                return (laterale.reglageDe(c).type || "bascule") !== "glissiere";
            })
            readonly property var curseurs: laterale.cles.filter(function (c) {
                return laterale.reglageDe(c).type === "glissiere";
            })
            property bool survoleUneFois: false

            Connections {
                target: laterale
                function onReplier() {
                    listeChoix.visible = false;
                    miseR.survoleUneFois = false;
                }
            }

            // UN CLIC A COTE DU PANNEAU LE FERME, comme un vrai volet. La
            // fenetre est plus grande que le panneau ; tant qu'il est ouvert,
            // toute sa zone est sensible — c'est ce qui permet de recevoir ce
            // clic-la au lieu de le laisser tomber au travers.
            TapHandler {
                onTapped: function (e) {
                    var p = miseR.mapToItem(carte, e.position.x, e.position.y);
                    if (p.x < 0 || p.y < 0 || p.x > carte.width || p.y > carte.height)
                        laterale.deploye = false;
                }
            }

            // ON SE DETOURNE DU PANNEAU : il se ferme, mais seulement une fois
            // qu'on y est entre — le trajet de la barre jusqu'a lui ne compte pas.
            Timer {
                id: departR
                interval: 1400
                onTriggered: if (!survolCarte.hovered && !listeChoix.survole)
                                 laterale.deploye = false
            }

            Panneau {
                id: carte
                x: miseR.width - width - 12
                width: miseR.width - 24
                height: contenuR.implicitHeight + (Theme.estAndroid ? 40 : 32)
                rayon: Theme.estAndroid ? 28 : 8
                teinte: Theme.estAndroid ? Theme.palette.surfaceContainer
                                         : (Theme.sombre ? Qt.rgba(36 / 255, 36 / 255, 36 / 255, 0.97)
                                                         : Qt.rgba(243 / 255, 243 / 255, 243 / 255, 0.97))
                readonly property real yOuvert: Theme.estAndroid ? 12
                                                : miseR.height - laterale.margeBas - 12 - height
                property real decalage: laterale.deploye ? 0 : (Theme.estAndroid ? -24 : 24)
                Behavior on decalage { NumberAnimation { duration: Theme.dureeNormale; easing.type: Theme.courbe } }
                y: yOuvert + decalage
                opacity: laterale.deploye ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.dureeRapide } }

                HoverHandler {
                    id: survolCarte
                    onHoveredChanged: {
                        if (hovered) { miseR.survoleUneFois = true; departR.stop(); }
                        else if (laterale.deploye && miseR.survoleUneFois) departR.restart();
                    }
                }

                Column {
                    id: contenuR
                    x: Theme.estAndroid ? 20 : 16
                    y: Theme.estAndroid ? 20 : 16
                    width: carte.width - 2 * x
                    spacing: Theme.estAndroid ? 14 : 12

                    // L'EN-TETE D'ANDROID : l'heure et la date, le rouage.
                    Item {
                        visible: Theme.estAndroid
                        width: parent.width
                        height: visible ? 52 : 0
                        Text {
                            id: heureA
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatTime(new Date(), "HH:mm")
                            color: Theme.palette.onSurface
                            font.family: Theme.police
                            font.pixelSize: 34
                            // Relue a chaque ouverture : le panneau ne vit
                            // pas assez longtemps pour qu'une horloge y vaille
                            // un minuteur.
                            Connections {
                                target: laterale
                                function onOuverte() { heureA.text = Qt.formatTime(new Date(), "HH:mm"); }
                            }
                        }
                        Text {
                            anchors.left: heureA.right
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: Theme.dateCourteFr(new Date())
                            color: Theme.palette.onSurfaceVariant
                            font.family: Theme.police
                            font.pixelSize: 14
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40; height: 40; radius: 20
                            color: survolRouageA.hovered ? Theme.verre2 : "transparent"
                            Glyphe {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                nom: "i-reglages"
                                couleur: Theme.palette.onSurfaceVariant
                            }
                            HoverHandler { id: survolRouageA; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: laterale.personnaliserDemande() }
                        }
                    }

                    // ANDROID MET SES CURSEURS EN HAUT, Windows en bas : chaque
                    // systeme a sa maniere, on garde la sienne. Les deux
                    // Repeater portent les memes delegues ; un seul a des
                    // curseurs selon le theme.
                    Repeater {
                        objectName: "repeaterReglagesCurseurs"
                        model: Theme.estAndroid ? miseR.curseurs : []
                        delegate: CurseurReglage {
                            required property string modelData
                            width: contenuR.width
                            reglage: laterale.reglageDe(modelData)
                            onValeurDemandee: function (v) { laterale.reglageValeur(modelData, v); }
                            onMuetDemande: laterale.reglageMuet(modelData)
                        }
                    }

                    Grid {
                        id: grilleTuiles
                        width: parent.width
                        columns: Theme.estAndroid ? 2 : 3
                        columnSpacing: Theme.estAndroid ? 10 : 10
                        rowSpacing: Theme.estAndroid ? 10 : 6
                        Repeater {
                            objectName: "repeaterReglagesTuiles"
                            model: miseR.tuiles
                            delegate: TuileReglage {
                                id: tuileR
                                required property string modelData
                                width: (grilleTuiles.width - grilleTuiles.columnSpacing
                                        * (grilleTuiles.columns - 1)) / grilleTuiles.columns
                                reglage: laterale.reglageDe(modelData)
                                onBascule: {
                                    var d = laterale.reglageDe(modelData);
                                    if (d.type === "action") laterale.reglageAction(modelData);
                                    else laterale.reglageBascule(modelData, !(d.actif === true));
                                }
                                onChoixDemande: listeChoix.ouvrirPour(laterale.reglageDe(modelData), tuileR)
                            }
                        }
                    }

                    Repeater {
                        objectName: "repeaterReglagesCurseurs2"
                        model: Theme.estAndroid ? [] : miseR.curseurs
                        delegate: CurseurReglage {
                            required property string modelData
                            width: contenuR.width
                            reglage: laterale.reglageDe(modelData)
                            onValeurDemandee: function (v) { laterale.reglageValeur(modelData, v); }
                            onMuetDemande: laterale.reglageMuet(modelData)
                        }
                    }

                    // LE PIED DE WINDOWS : le rouage, a droite.
                    Item {
                        visible: !Theme.estAndroid
                        width: parent.width
                        height: visible ? 36 : 0
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36; radius: 4
                            color: survolRouageW.hovered ? Theme.verre2 : "transparent"
                            Glyphe {
                                anchors.centerIn: parent
                                width: 17; height: 17
                                nom: "i-reglages"
                                couleur: Theme.texte
                            }
                            HoverHandler { id: survolRouageW; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: laterale.personnaliserDemande() }
                        }
                    }
                }
            }

            // ── La liste d'un reglage « choix », posee contre sa tuile ───────
            Verre {
                id: listeChoix
                visible: false
                width: Math.min(220, miseR.width - 24)
                height: colChoix.implicitHeight + 12
                radius: Theme.rayonMenu
                readonly property bool survole: survolListe.hovered
                property string cle: ""
                property var possibles: []

                function ouvrirPour(reglage, tuile) {
                    cle = reglage.cle || "";
                    possibles = reglage.choix || [];
                    var p = tuile.mapToItem(miseR, 0, 0);
                    x = Math.max(12, Math.min(miseR.width - width - 12, p.x));
                    // En Windows le panneau est en bas : la liste s'ouvre
                    // au-dessus de la tuile. En Android, en dessous.
                    y = Theme.estAndroid ? p.y + tuile.height + 6
                                         : Math.max(8, p.y - height - 6);
                    visible = possibles.length > 0;
                }

                HoverHandler { id: survolListe }

                Column {
                    id: colChoix
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 2
                    Repeater {
                        model: listeChoix.possibles
                        delegate: Rectangle {
                            required property var modelData
                            width: colChoix.width
                            height: Theme.hauteurArticle - 4
                            radius: Theme.estAndroid ? 8 : 4
                            color: zoneChoix.hovered ? Theme.verre2 : "transparent"
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.nom || ""
                                color: Theme.texte
                                font.family: Theme.police
                                font.pixelSize: 13
                            }
                            HoverHandler { id: zoneChoix; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    laterale.reglageChoix(listeChoix.cle, modelData.cle);
                                    listeChoix.visible = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
