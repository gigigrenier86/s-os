import QtQuick
import QtQuick.Controls.Basic

// ═══════════════════════════════════════════════════════════════════════════
// LE TIROIR D'APPLICATIONS, A LA FACON D'UNE TABLETTE ANDROID (MATERIAL YOU).
//
// Une grande feuille aux coins tres ronds qui monte du bas : la recherche en
// pilule, des puces pour passer des applications aux dossiers, et la grille de
// toutes les applications par ordre alphabetique, chacune sur sa pastille ronde
// aux couleurs de la palette — les « icones a theme » d'Android 13.
//
// Comme le menu de Windows, il ne reecrit ni la recherche ni le lancement :
// tiroir.menu les porte pour les trois themes.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: tiroir

    // LE MENU ET LE BUREAU ARRIVENT EN PROPRIETES, posees par Constellation.qml
    // a la creation — et non lus dans Session : ce menu nait AVANT que le bureau
    // ne remplisse Session (son Component.onCompleted passe apres celui de ses
    // enfants), et une liaison sur tiroir.menu y tombait sur « null ». Les
    // delegues de ce fichier les atteignent par l'identifiant de sa racine.
    property var menu: Session.menu
    property var hote: Session.bureau
    property alias champRecherche: champ

    readonly property bool recherche: tiroir.menu.requete.trim() !== ""

    Connections {
        target: tiroir.menu
        function onClosed() { tiroir.menu.vue = "apps"; }
    }

    // Une puce de Material : une pilule a bord fin, pleine quand elle est
    // choisie.
    component Puce: Rectangle {
        id: puce
        property string texte: ""
        property string glyphe: ""
        property bool choisie: false
        signal clique()
        width: rangee.implicitWidth + 28
        height: 34
        radius: 10
        color: choisie ? Theme.palette.secondaryContainer
             : (tapP.pressed ? Theme.verre3 : (survolP.hovered ? Theme.verre2 : "transparent"))
        border.width: choisie ? 0 : 1
        border.color: Theme.palette.outlineVariant
        Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
        Row {
            id: rangee
            anchors.centerIn: parent
            spacing: 8
            Glyphe {
                visible: puce.glyphe !== ""
                width: 16; height: 16
                anchors.verticalCenter: parent.verticalCenter
                nom: puce.glyphe || "i-boite"
                couleur: puce.choisie ? Theme.palette.onSecondaryContainer : Theme.palette.onSurfaceVariant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: puce.texte
                color: puce.choisie ? Theme.palette.onSecondaryContainer : Theme.palette.onSurfaceVariant
                font.family: Theme.police
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
        HoverHandler { id: survolP; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tapP; onTapped: puce.clique() }
    }

    // Une application : sa pastille ronde, son nom en dessous.
    component AppA: Item {
        id: appA
        property var app: null
        HoverHandler { id: survolA; cursorShape: Qt.PointingHandCursor }
        Rectangle {
            id: pastille
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: 56; height: 56
            radius: 28
            color: tapA.pressed ? Theme.palette.primaryContainer : Theme.palette.surfaceContainerHighest
            scale: tapA.pressed ? 0.92 : (survolA.hovered ? 1.06 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.dureeRapide; easing.type: Theme.courbe } }
            Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
            IconeApp {
                anchors.centerIn: parent
                taille: 34
                app: appA.app
                couleur: Theme.palette.primary
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: pastille.y + pastille.height + 8
            width: parent.width - 8
            text: appA.app ? (appA.app.nom || "") : ""
            color: Theme.palette.onSurface
            font.family: Theme.police
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        TapHandler { id: tapA; onTapped: Session.menu.lancerApp(appA.app) }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: function (e) {
                var p = appA.mapToItem(null, e.position.x, e.position.y);
                Session.bureau.ouvrirMenuContextuel(appA.app, p.x, p.y);
            }
        }
    }

    // ── La poignee, puis la recherche ──────────────────────────────────────
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        width: 36; height: 4; radius: 2
        color: Theme.palette.outline
        opacity: 0.6
    }

    Rectangle {
        id: barreRecherche
        x: 28
        y: 30
        width: parent.width - 56
        height: 56
        radius: 28
        color: Theme.palette.surfaceContainerHighest

        Glyphe {
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22
            nom: "i-recherche"
            couleur: Theme.palette.onSurfaceVariant
        }
        TextField {
            id: champ
            anchors.left: parent.left
            anchors.leftMargin: 56
            anchors.right: boutonAlim.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 44
            placeholderText: "Rechercher des applications"
            placeholderTextColor: Theme.palette.onSurfaceVariant
            color: Theme.palette.onSurface
            font.family: Theme.police
            font.pixelSize: 16
            selectByMouse: true
            background: Item { }
            onTextChanged: tiroir.menu.requete = text
            onAccepted: tiroir.menu.valider()
        }
        // L'ALIMENTATION, DANS LE TIROIR. Android la range dans ses reglages
        // rapides ; ici elle doit etre a portee depuis le menu, comme dans les
        // deux autres themes — rien ne doit se perdre en changeant de theme.
        Rectangle {
            id: boutonAlim
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: tapAlim.pressed ? Theme.verre3 : (survolAlim.hovered ? Theme.verre2 : "transparent")
            Glyphe {
                anchors.centerIn: parent
                width: 20; height: 20
                nom: "i-alim"
                couleur: Theme.palette.onSurfaceVariant
            }
            HoverHandler { id: survolAlim; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: tapAlim
                onTapped: menuAlim.popup(boutonAlim, boutonAlim.width - menuAlim.implicitWidth,
                                         boutonAlim.height + 6)
            }
        }
    }

    Menu {
        id: menuAlim
        background: Verre {
            radius: Theme.rayonMenu
            implicitWidth: 220
        }
        Repeater {
            model: [
                { act: "verrouiller", nom: "Verrouiller", grave: false },
                { act: "deconnecter", nom: "Se déconnecter", grave: false },
                { act: "redemarrer", nom: "Redémarrer", grave: true },
                { act: "eteindre", nom: "Éteindre", grave: true }
            ]
            delegate: ArticleMenu {
                required property var modelData
                text: modelData.nom
                grave: modelData.grave
                onTriggered: {
                    tiroir.menu.close();
                    pont.session(modelData.act);
                }
            }
        }
    }

    // ── Les puces ───────────────────────────────────────────────────────────
    Row {
        id: puces
        x: 28
        y: barreRecherche.y + barreRecherche.height + 16
        spacing: 8
        visible: !tiroir.recherche
        Puce {
            texte: "Applications"
            glyphe: "i-grille"
            choisie: tiroir.menu.vue !== "dossiers"
            onClique: tiroir.menu.vue = "apps"
        }
        Puce {
            texte: "Dossiers"
            glyphe: "i-dossier"
            choisie: tiroir.menu.vue === "dossiers"
            onClique: tiroir.menu.vue = "dossiers"
        }
        Puce {
            texte: "Personnaliser"
            glyphe: "i-image"
            onClique: tiroir.hote.ouvrirPersonnaliser()
        }
    }

    // ── La grille ───────────────────────────────────────────────────────────
    GridView {
        id: grille
        objectName: "grilleTiroir"
        visible: tiroir.recherche || tiroir.menu.vue !== "dossiers"
        x: 28
        y: tiroir.recherche ? barreRecherche.y + barreRecherche.height + 18
                            : puces.y + puces.height + 16
        width: parent.width - 56
        height: parent.height - y - 16
        clip: true
        cacheBuffer: 0
        boundsBehavior: Flickable.StopAtBounds
        readonly property int colonnes: Math.max(1, Math.floor(width / 112))
        cellWidth: width / colonnes
        cellHeight: 112
        ScrollBar.vertical: ScrollBar { }
        // La recherche rend la liste filtree du menu, suggestions de secours
        // comprises ; sans recherche, toutes les applications par nom.
        model: tiroir.recherche ? tiroir.menu.filtrees() : tiroir.menu.alphabetique()
        delegate: AppA {
            required property var modelData
            width: grille.cellWidth
            height: grille.cellHeight
            app: modelData
        }
    }

    // ── Les dossiers, en liste Material ─────────────────────────────────────
    ListView {
        visible: !tiroir.recherche && tiroir.menu.vue === "dossiers"
        x: 28
        y: puces.y + puces.height + 16
        width: parent.width - 56
        height: parent.height - y - 16
        clip: true
        spacing: 4
        model: tiroir.hote.listeDossiers
        delegate: Rectangle {
            id: ligneDossier
            required property var modelData
            width: ListView.view.width
            height: 56
            radius: 16
            color: tapD.pressed ? Theme.verre3 : (survolD.hovered ? Theme.verre2 : "transparent")
            Rectangle {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: Theme.palette.secondaryContainer
                Glyphe {
                    anchors.centerIn: parent
                    width: 20; height: 20
                    nom: ligneDossier.modelData.ico || "i-dossier"
                    couleur: Theme.palette.onSecondaryContainer
                }
            }
            Text {
                x: 68
                anchors.verticalCenter: parent.verticalCenter
                text: ligneDossier.modelData.nom
                color: Theme.palette.onSurface
                font.family: Theme.police
                font.pixelSize: 15
            }
            HoverHandler { id: survolD; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: tapD
                onTapped: {
                    Session.bureau.dire(pont.ouvrirDossier(ligneDossier.modelData.chemin));
                    Session.menu.close();
                }
            }
        }
    }
}
