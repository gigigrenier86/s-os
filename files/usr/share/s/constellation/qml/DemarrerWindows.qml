import QtQuick
import QtQuick.Controls.Basic

// ═══════════════════════════════════════════════════════════════════════════
// LE MENU DEMARRER, A LA FACON DE WINDOWS 11.
//
// Ce qu'on y retrouve, et a la meme place : la recherche en haut, les
// « Epingle » en grille de six, les « Recommande » en dessous (les derniers
// fichiers ouverts), « Toutes les applications » par ordre alphabetique, et en
// bas le compte et le bouton d'alimentation.
//
// CE QU'IL NE REECRIT PAS : la recherche elle-meme, ce que veut dire « Entree »,
// le lancement. Tout cela vit dans le Popup du menu (Constellation.qml) et
// s'atteint par demarrer.menu — le meme pour les trois themes. Les gestes du
// clic droit sont ceux du bureau : demarrer.hote.ouvrirMenuContextuel.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: demarrer

    // LE MENU ET LE BUREAU ARRIVENT EN PROPRIETES, posees par Constellation.qml
    // a la creation — et non lus dans Session : ce menu nait AVANT que le bureau
    // ne remplisse Session (son Component.onCompleted passe apres celui de ses
    // enfants), et une liaison sur demarrer.menu y tombait sur « null ». Les
    // delegues de ce fichier les atteignent par l'identifiant de sa racine.
    property var menu: Session.menu
    property var hote: Session.bureau
    property alias champRecherche: champ

    // Trois etats, comme celui de Windows : l'accueil, toutes les applications,
    // et la recherche des qu'on tape quoi que ce soit.
    readonly property string mode: demarrer.menu.requete.trim() !== "" ? "recherche"
                                 : (demarrer.menu.vue === "toutes" ? "toutes" : "accueil")
    property var recents: []
    property var moi: ({ nom: "", avatar: "" })

    // CE QUE WINDOWS ECRIT SOUS UN RESULTAT : le genre, pas la ligne de
    // commande. Une application Android sans description portait son Exec
    // (« /usr/bin/s-android-lancer com.google… ») — vrai, et illisible.
    function decrire(e) {
        if (!e) return "";
        var t = String(e.txt || "");
        if (t !== "" && t.charAt(0) !== "/") return t;
        if (e.src === "android") return "Application Android";
        if (e.src === "windows") return "Application Windows";
        if (e.src === "fichier") return t;
        return "Application";
    }

    function relireRecents() {
        recents = pont.recents(6);
    }

    Component.onCompleted: {
        relireRecents();
        moi = pont.utilisateur();
    }
    Connections {
        target: demarrer.menu
        // Les recommandations se relisent a chaque ouverture : un fichier
        // ouvert il y a une minute doit y etre.
        function onOpened() { demarrer.relireRecents(); }
        // Windows rouvre toujours son menu sur l'accueil.
        function onClosed() { demarrer.menu.vue = "apps"; }
    }

    // ── Les petites pieces ──────────────────────────────────────────────────

    // Une tuile epinglee : l'icone, le nom en dessous, le survol de Windows.
    component TuileW: Item {
        id: tuileW
        property var app: null
        HoverHandler { id: survolT; cursorShape: Qt.PointingHandCursor }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 4
            color: tapT.pressed ? Theme.verre3 : (survolT.hovered ? Theme.verre2 : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
        }
        IconeApp {
            id: icoT
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            taille: 32
            app: tuileW.app
            scale: tapT.pressed ? 0.88 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.dureePression; easing.type: Theme.courbe } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: icoT.y + icoT.height + 9
            width: parent.width - 8
            text: tuileW.app ? (tuileW.app.nom || "") : ""
            color: Theme.texte
            font.family: Theme.police
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        TapHandler { id: tapT; onTapped: Session.menu.lancerApp(tuileW.app) }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: function (e) {
                var p = tuileW.mapToItem(null, e.position.x, e.position.y);
                Session.bureau.ouvrirMenuContextuel(tuileW.app, p.x, p.y);
            }
        }
    }

    // Une ligne de liste : l'icone a gauche, le nom, et un detail en dessous.
    component LigneW: Item {
        id: ligneW
        property var entree: null
        property real taille: 32
        property string detail: ""
        signal choisie()
        HoverHandler { id: survolL; cursorShape: Qt.PointingHandCursor }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 4
            color: tapL.pressed ? Theme.verre3 : (survolL.hovered ? Theme.verre2 : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
        }
        IconeApp {
            id: icoL
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            taille: ligneW.taille
            app: ligneW.entree
            couleur: Theme.accent
        }
        Column {
            anchors.left: icoL.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: ligneW.entree ? (ligneW.entree.nom || "") : ""
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: ligneW.detail
                color: Theme.texte2
                font.family: Theme.police
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        TapHandler { id: tapL; onTapped: ligneW.choisie() }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: function (e) {
                if (!ligneW.entree || !ligneW.entree.id) return;
                var p = ligneW.mapToItem(null, e.position.x, e.position.y);
                Session.bureau.ouvrirMenuContextuel(ligneW.entree, p.x, p.y);
            }
        }
    }

    // Le petit bouton a fleche de Windows (« Toutes les applications › »).
    component BoutonW: Rectangle {
        id: boutonW
        property string texte: ""
        signal clique()
        width: libelle.implicitWidth + 26
        height: 26
        radius: 4
        color: tapB.pressed ? Theme.verre3 : (survolB.hovered ? Theme.verre2 : Theme.carte)
        border.width: 1
        border.color: Theme.bord
        Text {
            id: libelle
            anchors.centerIn: parent
            text: boutonW.texte
            color: Theme.texte
            font.family: Theme.police
            font.pixelSize: 12
        }
        HoverHandler { id: survolB; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tapB; onTapped: boutonW.clique() }
    }

    // Un bouton rond du pied de menu : un glyphe, rien d'autre.
    component IconeBouton: Rectangle {
        id: iconeBouton
        property string glyphe: "i-reglages"
        property string aide: ""
        signal clique()
        width: 40; height: 40
        radius: 4
        color: tapI.pressed ? Theme.verre3 : (survolI.hovered ? Theme.verre2 : "transparent")
        Glyphe {
            anchors.centerIn: parent
            width: 17; height: 17
            nom: iconeBouton.glyphe
            couleur: Theme.texte
        }
        HoverHandler { id: survolI; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tapI; onTapped: iconeBouton.clique() }
        ToolTip.visible: survolI.hovered && aide !== ""
        ToolTip.text: aide
        ToolTip.delay: 600
    }

    // ── La recherche ────────────────────────────────────────────────────────
    TextField {
        id: champ
        x: 32
        y: 26
        width: parent.width - 64
        height: 38
        leftPadding: 42
        rightPadding: 14
        placeholderText: "Rechercher des applications, des fichiers, le Web"
        placeholderTextColor: Theme.texte3
        color: Theme.texte
        font.family: Theme.police
        font.pixelSize: 13
        selectByMouse: true
        background: Rectangle {
            radius: 19
            color: Theme.sombre ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.86)
            border.width: 1
            border.color: Theme.bord
            // LA LIGNE D'ACCENT DE WINDOWS sous un champ qui a le focus.
            Rectangle {
                visible: champ.activeFocus
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * parent.radius
                height: 2
                radius: 1
                color: Theme.accent
            }
        }
        Glyphe {
            x: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            nom: "i-recherche"
            couleur: Theme.texte2
        }
        onTextChanged: demarrer.menu.requete = text
        onAccepted: demarrer.menu.valider()
    }

    // ── Le corps : accueil, toutes les applications, ou la recherche ────────
    Item {
        id: corps
        x: 0
        y: 84
        width: parent.width
        height: parent.height - y - pied.height
        clip: true

        Loader {
            anchors.fill: parent
            sourceComponent: demarrer.mode === "recherche" ? vueRecherche
                           : (demarrer.mode === "toutes" ? vueToutes : vueAccueil)
        }
    }

    Component {
        id: vueAccueil
        Item {
            id: accueil
            readonly property real largeurCase: (width - 72) / 6

            Text {
                x: 52; y: 4
                text: "Épinglé"
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            BoutonW {
                anchors.right: parent.right
                anchors.rightMargin: 44
                y: 0
                texte: "Toutes les applications  ›"
                onClique: demarrer.menu.vue = "toutes"
            }
            Grid {
                x: 36
                y: 34
                columns: 6
                Repeater {
                    objectName: "epinglesDemarrer"
                    model: demarrer.menu.epinglees(18)
                    delegate: TuileW {
                        required property var modelData
                        app: modelData
                        width: accueil.largeurCase
                        height: 86
                    }
                }
            }

            Text {
                x: 52
                y: 34 + 3 * 86 + 22
                text: "Recommandé"
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            // LES DERNIERS FICHIERS OUVERTS, lus dans le journal que KDE et GTK
            // tiennent deja (recently-used.xbel) — voir Pont.recents. Sans
            // recents, les dossiers de l'utilisateur prennent leur place :
            // Windows ne laisse jamais cette moitie du menu vide.
            Grid {
                x: 36
                y: 34 + 3 * 86 + 54
                columns: 2
                columnSpacing: 8
                rowSpacing: 4
                Repeater {
                    model: demarrer.recents.length > 0 ? demarrer.recents
                                                       : demarrer.hote.listeDossiers.slice(0, 6)
                    delegate: LigneW {
                        required property var modelData
                        width: (accueil.width - 80) / 2
                        height: 54
                        entree: modelData
                        detail: modelData.detail || ""
                        onChoisie: {
                            if (modelData.id) demarrer.hote.dire(pont.lancer(modelData.id));
                            else demarrer.hote.dire(pont.ouvrirDossier(modelData.chemin));
                            demarrer.menu.close();
                        }
                    }
                }
            }
        }
    }

    Component {
        id: vueToutes
        Item {
            id: toutes
            Text {
                x: 52; y: 4
                text: "Toutes les applications"
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            BoutonW {
                anchors.right: parent.right
                anchors.rightMargin: 44
                y: 0
                texte: "‹  Retour"
                onClique: demarrer.menu.vue = "apps"
            }
            // LES LETTRES SONT DES LIGNES DE LA LISTE, PAS DES « sections » de
            // ListView : celles-ci exigent un role de modele, et la liste des
            // applications est un simple tableau. On intercale donc soi-meme
            // un en-tete a chaque nouvelle initiale.
            ListView {
                id: liste
                x: 32
                y: 36
                width: parent.width - 64
                height: parent.height - 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }
                model: {
                    var apps = demarrer.menu.alphabetique();
                    var sortie = [], derniere = "";
                    for (var i = 0; i < apps.length; i++) {
                        var n = (apps[i].nom || "?").normalize("NFD")
                                    .replace(/[̀-ͯ]/g, "").charAt(0).toUpperCase();
                        if (!/[A-Z]/.test(n)) n = "#";
                        if (n !== derniere) { sortie.push({ entete: n }); derniere = n; }
                        sortie.push({ app: apps[i] });
                    }
                    return sortie;
                }
                delegate: Item {
                    id: ligneToutes
                    required property var modelData
                    width: liste.width
                    height: modelData.entete !== undefined ? 34 : 38
                    Text {
                        visible: ligneToutes.modelData.entete !== undefined
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: ligneToutes.modelData.entete || ""
                        color: Theme.texte
                        font.family: Theme.police
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    LigneW {
                        visible: ligneToutes.modelData.app !== undefined
                        anchors.fill: parent
                        taille: 24
                        entree: ligneToutes.modelData.app || null
                        onChoisie: demarrer.menu.lancerApp(ligneToutes.modelData.app)
                    }
                }
            }
        }
    }

    Component {
        id: vueRecherche
        Item {
            id: recherche
            readonly property var resultats: demarrer.menu.filtrees()
            Text {
                x: 52; y: 4
                text: "Meilleure correspondance"
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            // LA MEILLEURE CORRESPONDANCE EST CE QUE « ENTREE » LANCERA — sauf
            // quand ce n'est qu'une suggestion de secours (commande, Google) :
            // voir demarrer.menu.valider().
            Rectangle {
                id: meilleure
                x: 36
                y: 34
                width: parent.width - 72
                height: 78
                radius: 6
                color: Theme.accentDoux
                border.width: 1
                border.color: Theme.bord
                visible: recherche.resultats.length > 0
                LigneW {
                    anchors.fill: parent
                    taille: 44
                    entree: recherche.resultats.length > 0 ? recherche.resultats[0] : null
                    detail: recherche.resultats.length > 0 ? demarrer.decrire(recherche.resultats[0]) : ""
                    onChoisie: demarrer.menu.lancerApp(recherche.resultats[0])
                }
            }
            Text {
                x: 52
                y: meilleure.y + meilleure.height + 18
                text: "Autres résultats"
                visible: recherche.resultats.length > 1
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            ListView {
                x: 36
                y: meilleure.y + meilleure.height + 48
                width: parent.width - 72
                height: parent.height - y - 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }
                model: recherche.resultats.slice(1)
                delegate: LigneW {
                    required property var modelData
                    width: ListView.view.width
                    height: 46
                    taille: 26
                    entree: modelData
                    detail: demarrer.decrire(modelData)
                    onChoisie: demarrer.menu.lancerApp(modelData)
                }
            }
        }
    }

    // ── Le pied : le compte, les dossiers, l'alimentation ──────────────────
    Item {
        id: pied
        anchors.bottom: parent.bottom
        width: parent.width
        height: 64
        clip: true

        // LE FOND DU PIED N'EST ARRONDI QU'EN BAS. Un rectangle arrondi qui
        // depasse au-dessus du decoupage : ses coins du haut sont coupes, ceux
        // du bas restent — sans masque ni shader.
        Rectangle {
            width: parent.width
            height: parent.height + Theme.rayon
            y: -Theme.rayon
            radius: Theme.rayon
            color: Theme.sombre ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0, 0, 0, 0.035)
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.bord
        }

        Row {
            x: 48
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            // L'AVATAR, ROND SANS MASQUE : un canevas qui decoupe l'image a
            // un cercle. Sans image, l'initiale sur l'accent, comme Windows.
            Item {
                width: 32; height: 32
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Theme.accent
                    visible: demarrer.moi.avatar === ""
                    Text {
                        anchors.centerIn: parent
                        text: (demarrer.moi.nom || "S").charAt(0).toUpperCase()
                        color: Theme.surAccent
                        font.family: Theme.police
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
                Canvas {
                    id: avatar
                    anchors.fill: parent
                    visible: demarrer.moi.avatar !== ""
                    property string source: demarrer.moi.avatar
                    onSourceChanged: if (source !== "") loadImage(source)
                    onImageLoaded: requestPaint()
                    onPaint: {
                        var g = getContext("2d");
                        g.reset();
                        if (source === "" || !isImageLoaded(source)) return;
                        g.save();
                        g.beginPath();
                        g.arc(width / 2, height / 2, width / 2, 0, 6.2832);
                        g.clip();
                        g.drawImage(source, 0, 0, width, height);
                        g.restore();
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: demarrer.moi.nom || ""
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 13
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 44
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            // LES DOSSIERS A COTE DU BOUTON D'ALIMENTATION — les deux premiers
            // qui existent sur cette machine (voir Pont.dossiers), comme ceux
            // que Windows laisse y epingler.
            Repeater {
                model: demarrer.hote.listeDossiers.filter(function (d) {
                    return d.ico === "i-doc" || d.ico === "i-telech" || d.ico === "i-image";
                }).slice(0, 3)
                delegate: IconeBouton {
                    required property var modelData
                    glyphe: modelData.ico
                    aide: modelData.nom
                    onClique: {
                        demarrer.hote.dire(pont.ouvrirDossier(modelData.chemin));
                        demarrer.menu.close();
                    }
                }
            }
            IconeBouton {
                glyphe: "i-reglages"
                aide: "Personnaliser"
                onClique: demarrer.hote.ouvrirPersonnaliser()
            }
            IconeBouton {
                id: boutonAlim
                glyphe: "i-alim"
                aide: "Alimentation"
                onClique: menuAlim.popup(boutonAlim, -menuAlim.implicitWidth + boutonAlim.width,
                                         -menuAlim.implicitHeight - 6)
            }
        }

        Menu {
            id: menuAlim
            background: Verre {
                radius: Theme.rayonMenu
                implicitWidth: 210
            }
            Repeater {
                model: [
                    { act: "verrouiller", nom: "Verrouiller", grave: false },
                    { act: "deconnecter", nom: "Se déconnecter", grave: false },
                    { act: "redemarrer", nom: "Redémarrer", grave: true },
                    { act: "eteindre", nom: "Arrêter", grave: true }
                ]
                delegate: ArticleMenu {
                    required property var modelData
                    text: modelData.nom
                    grave: modelData.grave
                    onTriggered: {
                        demarrer.menu.close();
                        pont.session(modelData.act);
                    }
                }
            }
        }
    }
}
