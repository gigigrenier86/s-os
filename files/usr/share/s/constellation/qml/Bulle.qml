import QtQuick

// ═══════════════════════════════════════════════════════════════════════════
// LA BULLE — ce que S dit, enfin visible.
//
// POURQUOI UNE FENETRE SEPAREE ET NON UN ELEMENT DU BUREAU. Constellation est
// une fenetre plein ecran, et le compositeur la garde DERRIERE les autres :
// c'est ce qu'on attend d'un bureau. Une bulle dessinee dans sa scene serait
// donc invisible des qu'une seule fenetre est ouverte — c'est-a-dire presque
// toujours, et exactement quand une notification sert a quelque chose.
//
// CE QUI A ETE MESURE LE 2026-08-25, SUR LA MACHINE :
//   1. « Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool » suffit a
//      passer devant les autres fenetres sous kwin_wayland. Verifie en
//      photographiant l'ecran pendant qu'une autre fenetre etait au premier
//      plan.
//   2. LES COORDONNEES x ET y SONT IGNOREES. Un client Wayland ne se place pas
//      lui-meme — le compositeur decide, et il a centre la bulle. Ce n'est pas
//      un defaut de Qt, c'est le protocole. Le placement en haut a droite vient
//      donc d'une regle kwin posee par s-coquille ; ce fichier ne demande rien.
// ═══════════════════════════════════════════════════════════════════════════

Window {
    id: bulle

    // LE TITRE EST UNE CLEF, PAS UNE DECORATION. La regle kwin qui pose cette
    // fenetre en haut a droite la reconnait par ce texte : la coquille et la
    // bulle partagent la meme classe d'application, donc le titre est le seul
    // moyen de les distinguer. Le changer ici sans changer la regle recentre
    // la bulle au milieu de l'ecran.
    //
    // UN TITRE PAR THEME, ET C'EST CE QUI LA DEPLACE — depuis le 2026-10-20.
    // Constellation la pose en haut a droite ; Windows en bas a droite, au-
    // dessus de la barre, comme ses notifications ; Android en haut au centre.
    // Une regle kwin par titre (regles-kwin.py) : la bulle est cachee entre
    // deux notifications, et une fenetre cachee puis montree est une fenetre
    // NEUVE pour kwin, qui relit alors ses regles avec le titre du moment.
    title: Theme.estWindows ? "S - notification (bas)"
         : (Theme.estAndroid ? "S - notification (haut)" : "S - notification")

    // EN WINDOWS, LA FENETRE A UNE HAUTEUR FIXE ET LA CARTE S'Y POSE EN BAS. La
    // regle kwin fixe le coin haut-gauche ; une fenetre qui grandit vers le bas
    // passerait sous la barre. On garde donc la place la plus haute, et c'est
    // la zone SENSIBLE qui suit la carte (pont.bornerBarre, le meme geste que
    // la barre des taches).
    readonly property int hauteurFixe: 220
    width: Theme.estWindows ? 364 : (Theme.estAndroid ? 400 : 380)
    height: Theme.estWindows ? hauteurFixe : carte.height
    color: "transparent"
    visible: fileAttente.length > 0 || courante.id > 0

    function borner() {
        if (typeof pont === "undefined" || !pont || !pont.bornerBarre) return;
        pont.bornerBarre(bulle, Theme.estWindows ? Math.ceil(carte.height) + 2 : bulle.height);
    }
    onHeightChanged: borner()
    onVisibleChanged: if (visible) borner()
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
           | Qt.WindowDoesNotAcceptFocus

    // Un bouton d'action a ete choisi. La coquille (Constellation.qml) branche
    // ce signal sur le serveur de notifications, qui remonte « ActionInvoked »
    // au poseur. La bulle ne connait pas le serveur : elle ne fait que dire
    // « ce bouton-ci, sur CETTE notification-la ».
    signal actionChoisie(int ident, string cle)

    // --- L'etat -----------------------------------------------------------
    property var fileAttente: []
    property var courante: ({ id: 0, app: "", titre: "", corps: "", urgence: 1,
                              actions: [], defaut: "" })

    // On n'en montre qu'une a la fois. Une pile de bulles demande une gestion
    // de place, d'ordre et de recouvrement que S n'a pas ; une file, non.
    function poser(id, app, titre, corps, duree, urgence, actions) {
        actions = actions || [];
        // « actions » arrive en paires {cle, nom}. La cle « default » n'est pas
        // un bouton : c'est le clic sur le corps de la bulle (voir zoneClic).
        var boutons = [];
        var defaut = "";
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].cle === "default") defaut = actions[i].cle;
            else boutons.push(actions[i]);
        }
        var avis = { id: id, app: app, titre: titre, corps: corps,
                     duree: duree, urgence: urgence, actions: boutons,
                     defaut: defaut };
        // UN MEME IDENTIFIANT REMPLACE, il ne s'ajoute pas : c'est ainsi qu'une
        // application met a jour sa propre notification (une copie qui avance,
        // un telechargement qui progresse).
        if (courante.id === id) { afficher(avis); return; }
        for (var i = 0; i < fileAttente.length; i++) {
            if (fileAttente[i].id === id) {
                fileAttente[i] = avis;
                return;
            }
        }
        if (courante.id === 0) afficher(avis);
        else fileAttente = fileAttente.concat([avis]);
    }

    function afficher(avis) {
        courante = avis;
        vie.stop();
        // duree 0 = elle reste. La specification le demande pour l'urgence
        // critique, et c'est par la que passe « Constellation n'a pas demarre ».
        if (avis.duree > 0) { vie.interval = avis.duree; vie.start(); }
    }

    function retirer(id) {
        if (courante.id === id) { suivante(); return; }
        var reste = [];
        for (var i = 0; i < fileAttente.length; i++)
            if (fileAttente[i].id !== id) reste.push(fileAttente[i]);
        fileAttente = reste;
    }

    function action(cle) {
        actionChoisie(courante.id, cle);
    }

    function suivante() {
        vie.stop();
        if (fileAttente.length > 0) {
            var avis = fileAttente[0];
            fileAttente = fileAttente.slice(1);
            afficher(avis);
        } else {
            courante = { id: 0, app: "", titre: "", corps: "", urgence: 1,
                         actions: [], defaut: "" };
        }
    }

    Timer { id: vie; onTriggered: bulle.suivante() }

    // --- La carte -----------------------------------------------------------
    Item {
        id: carte
        width: parent.width
        height: contenu.implicitHeight + (Theme.estConstellation ? 28 : 34)
        y: Theme.estWindows ? bulle.height - height : 0
        onHeightChanged: bulle.borner()

        Rectangle {
            id: fondBulle
            anchors.fill: parent
            radius: Theme.estAndroid ? 24 : Theme.rayon
            color: Theme.estConstellation
                   ? (zoneHover.hovered ? (zoneClic.pressed ? Theme.verre3 : Theme.verre2) : Theme.verre)
                   : (Theme.estAndroid ? Theme.palette.surfaceContainerHigh
                                       : (Theme.sombre ? "#2c2c2c" : "#f9f9f9"))
            border.color: zoneClic.pressed ? Theme.bordVif
                        : (courante.urgence >= 2 ? Theme.linux
                                                  : (Theme.estAndroid ? "transparent" : Theme.bord))
            border.width: 1
            antialiasing: true

            scale: zoneClic.pressed ? 0.97 : (zoneHover.hovered ? 1.01 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.dureePression; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
            Behavior on border.color { ColorAnimation { duration: Theme.dureeRapide } }

            // Le survol, pour Windows et Android : un calque d'etat, la teinte
            // du texte a peine posee.
            Rectangle {
                visible: !Theme.estConstellation
                anchors.fill: parent
                radius: parent.radius
                color: zoneHover.hovered ? Theme.verre2 : "transparent"
            }

            // LE LISERE DE GAUCHE PORTE L'URGENCE. Une bordure rouge complete
            // crierait pour un simple « fichier copie » ; un trait de trois pixels
            // se voit sans occuper l'ecran.
            Rectangle {
                visible: Theme.estConstellation || courante.urgence >= 2
                width: 3
                height: parent.height - 2 * Theme.rayon
                anchors.left: parent.left
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: courante.urgence >= 2 ? Theme.linux : Theme.lienVif
                opacity: courante.urgence >= 2 ? 1 : 0.5
            }

            Column {
                id: contenu
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.estConstellation ? 18 : 16
                anchors.rightMargin: 14
                spacing: Theme.estConstellation ? 4 : 5

                // L'EN-TETE DE WINDOWS ET D'ANDROID : d'ou vient la
                // notification, en petit et EN HAUT — c'est la qu'ils la
                // mettent. Constellation la met en bas, voir plus loin.
                Row {
                    visible: !Theme.estConstellation
                    spacing: 7
                    Rectangle {
                        width: 16; height: 16
                        radius: Theme.estAndroid ? 8 : 3
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                        Glyphe {
                            anchors.centerIn: parent
                            width: 10; height: 10
                            nom: "i-bulle"
                            couleur: Theme.surAccent
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (courante.app || "S") + (Theme.estAndroid ? "  •  maintenant" : "")
                        color: Theme.texte2
                        font.family: Theme.police
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Text {
                    width: parent.width
                    text: courante.titre
                    visible: text.length > 0
                    color: Theme.texte
                    font.family: Theme.police
                    font.pixelSize: Theme.estConstellation ? 13 : 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: courante.corps
                    visible: text.length > 0
                    color: Theme.texte2
                    font.family: Theme.police
                    font.pixelSize: Theme.estConstellation ? 12 : 13
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    // L'APPLICATION SE NOMME EN PETIT, EN BAS. Une notification qui
                    // ne dit pas d'ou elle vient oblige a deviner ; une qui le dit
                    // trop fort vole la place du message.
                    text: courante.app
                    visible: Theme.estConstellation && text.length > 0 && text !== courante.titre
                    color: Theme.texte3
                    font.family: Theme.policeMono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                // LES BOUTONS D'ACTION — la demande d'appairage de KDE Connect,
                // un « Accepter »/« Refuser », vit ici. Sans eux, un clic sur la
                // bulle la fermait sans jamais repondre a l'application.
                Flow {
                    id: rangeeBoutons
                    visible: courante.actions.length > 0
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: courante.actions
                        delegate: Rectangle {
                            height: 30
                            width: Math.max(72, libelle.implicitWidth + 30)
                            radius: 15
                            color: survolBouton.hovered ? Theme.verre3 : Theme.verre2
                            border.color: survolBouton.hovered ? Theme.bordVif : Theme.bord
                            border.width: 1

                            Text {
                                id: libelle
                                anchors.centerIn: parent
                                text: modelData.nom
                                color: Theme.texte
                                font.family: Theme.police
                                font.pixelSize: 12
                            }

                            HoverHandler {
                                id: survolBouton
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: bulle.action(modelData.cle)
                            }
                        }
                    }
                }
            }

            HoverHandler {
                id: zoneHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: zoneClic
                onTapped: {
                    if (courante.defaut !== "")
                        bulle.action(courante.defaut);
                    else
                        bulle.suivante();
                }
            }
        }
    }
}
