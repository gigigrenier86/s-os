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
    title: "S - notification"

    width: 380
    height: contenu.implicitHeight + 28
    color: "transparent"
    visible: fileAttente.length > 0 || courante.id > 0
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
           | Qt.WindowDoesNotAcceptFocus

    // --- L'etat -----------------------------------------------------------
    property var fileAttente: []
    property var courante: ({ id: 0, app: "", titre: "", corps: "", urgence: 1 })

    // On n'en montre qu'une a la fois. Une pile de bulles demande une gestion
    // de place, d'ordre et de recouvrement que S n'a pas ; une file, non.
    function poser(id, app, titre, corps, duree, urgence) {
        var avis = { id: id, app: app, titre: titre, corps: corps,
                     duree: duree, urgence: urgence };
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

    function suivante() {
        vie.stop();
        if (fileAttente.length > 0) {
            var avis = fileAttente[0];
            fileAttente = fileAttente.slice(1);
            afficher(avis);
        } else {
            courante = { id: 0, app: "", titre: "", corps: "", urgence: 1 };
        }
    }

    Timer { id: vie; onTriggered: bulle.suivante() }

    // --- Le verre ---------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: Theme.rayon
        color: Theme.verre
        border.color: courante.urgence >= 2 ? Theme.linux : Theme.bord
        border.width: 1
        antialiasing: true

        // LE LISERE DE GAUCHE PORTE L'URGENCE. Une bordure rouge complete
        // crierait pour un simple « fichier copie » ; un trait de trois pixels
        // se voit sans occuper l'ecran.
        Rectangle {
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
            anchors.leftMargin: 18
            anchors.rightMargin: 14
            spacing: 4

            Text {
                width: parent.width
                text: courante.titre
                visible: text.length > 0
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 13
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
                font.pixelSize: 12
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
                visible: text.length > 0 && text !== courante.titre
                color: Theme.texte3
                font.family: Theme.policeMono
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: bulle.suivante()
        }
    }
}
