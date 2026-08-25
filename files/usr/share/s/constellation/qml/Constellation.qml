import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Fonds.js" as Fonds

// ═══════════════════════════════════════════════════════════════════════════
// CONSTELLATION — le bureau de S, en client Wayland natif.
//
// CE QUI A CHANGE LE 2026-08-24, ET POURQUOI C'ETAIT NECESSAIRE. Constellation
// etait une page HTML servie en HTTP sur 127.0.0.1:7373 et affichee par Vivaldi
// lance en « --app ». Le bureau de S dependait donc d'un navigateur : son
// demarrage, ses mises a jour, son profil, sa memoire — et son menu contextuel,
// qui proposait « Recharger » et « Inspecter » la ou l'utilisateur cherchait
// « Epingler ». Ce n'est plus le cas : ce fichier est un client QtQuick, il
// parle au noyau de S dans son propre processus, et il n'y a plus ni port
// ouvert ni moteur de rendu web dans la session.
//
// LES TROIS DECISIONS DE LA PAGE SONT CONSERVEES, elles tenaient la promesse
// « ultra-faible en consommation » :
//   1. aucune boucle d'animation permanente — rien ne se redessine au repos ;
//   2. le fond est peint UNE FOIS dans son propre canevas ;
//   3. les etoiles sont des elements de scene composes par le GPU, jamais un
//      canevas redessine.
// ═══════════════════════════════════════════════════════════════════════════

ApplicationWindow {
    id: bureau

    visible: true
    visibility: Window.FullScreen
    color: Theme.espace
    title: "Constellation"

    // --- L'etat, tel que le noyau le rend ---------------------------------
    property var donnees: ({ etoiles: [], usage: ({}), placees: ({}), epingles: [] })
    property string fondActuel: "nebuleuse"
    property bool nomsToujours: false
    // Relevee une fois : la liste des dossiers personnels ne bouge pas
    // pendant une session, et une liaison la redemanderait sans cesse.
    property var listeDossiers: []

    readonly property int maxUsage: {
        var m = 0;
        for (var i = 0; i < donnees.etoiles.length; i++)
            m = Math.max(m, donnees.etoiles[i].compte || 0);
        return m;
    }

    function relire() {
        donnees = pont.etoiles();
        liens.requestPaint();
    }

    function appParId(ident) {
        for (var i = 0; i < donnees.etoiles.length; i++)
            if (donnees.etoiles[i].id === ident) return donnees.etoiles[i];
        return null;
    }

    // UNE ETOILE GROSSIT AVEC L'USAGE, et l'echelle est logarithmique : sans
    // cela, une application lancee cent fois ecraserait tout le ciel. Bornee
    // 30 a 60 pixels — la hierarchie se voit, rien ne devient illisible.
    function tailleDe(app) {
        if (maxUsage <= 0) return Theme.sphere;
        var t = Math.log(1 + (app.compte || 0)) / Math.log(1 + maxUsage);
        return 30 + t * 30;
    }

    function dire(texte) {
        mot.text = texte;
        mot.vu = true;
        chrono.restart();
    }

    Component.onCompleted: {
        relire();
        listeDossiers = pont.dossiers();
        // Les reglages AVANT tout le reste : sans cela le fond par defaut se
        // peindrait une premiere fois, puis serait remplace — un clignotement
        // a chaque ouverture de session.
        var r = pont.reglages();
        if (r) {
            if (r.fond) fondActuel = r.fond;
            nomsToujours = r.noms === true;
        }
    }

    // Le noyau est relu regulierement : une application installee pendant la
    // session doit finir par apparaitre au ciel sans qu'on se deconnecte.
    Timer {
        interval: 15000; running: true; repeat: true
        onTriggered: bureau.relire()
    }

    // ══ 1. LE FOND ════════════════════════════════════════════════════════
    Canvas {
        id: fond
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var g = getContext("2d");
            var p = Fonds.FONDS[bureau.fondActuel] || Fonds.FONDS.nebuleuse;
            p.peindre(g, width, height);
        }
        // Repeint SEULEMENT quand le fond change ou que l'ecran change de
        // taille. Au repos, ce canevas ne coute rien.
        Connections {
            target: bureau
            function onFondActuelChanged() { fond.requestPaint(); }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // ══ 2. LE CIEL : les etoiles posees sur le bureau ═════════════════════
    Canvas {
        id: liens
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var g = getContext("2d");
            g.clearRect(0, 0, width, height);
            // Les liens relient chaque etoile posee a sa plus proche voisine.
            // C'est ce qui fait une constellation plutot qu'un tas d'icones.
            var pts = [];
            for (var i = 0; i < ciel.children.length; i++) {
                var c = ciel.children[i];
                if (c.app === undefined) continue;
                pts.push({ x: c.x + c.width / 2, y: c.y + c.height / 2 });
            }
            if (pts.length < 2) return;
            g.strokeStyle = "rgba(255,255,255,0.16)";
            g.lineWidth = 1;
            g.beginPath();
            for (var a = 0; a < pts.length; a++) {
                var meilleur = -1, d2 = Infinity;
                for (var b = 0; b < pts.length; b++) {
                    if (a === b) continue;
                    var dx = pts[a].x - pts[b].x, dy = pts[a].y - pts[b].y;
                    var d = dx * dx + dy * dy;
                    if (d < d2) { d2 = d; meilleur = b; }
                }
                if (meilleur >= 0) {
                    g.moveTo(pts[a].x, pts[a].y);
                    g.lineTo(pts[meilleur].x, pts[meilleur].y);
                }
            }
            g.stroke();
        }
    }

    Item {
        id: ciel
        anchors.fill: parent

        Repeater {
            model: {
                // Seules les etoiles POSEES sont au ciel. Le reste vit dans le
                // menu : un bureau qui affiche cinquante-deux icones n'est pas
                // un bureau, c'est une liste.
                var sortie = [];
                for (var ident in bureau.donnees.placees) {
                    var a = bureau.appParId(ident);
                    if (a) sortie.push({ app: a, pos: bureau.donnees.placees[ident] });
                }
                return sortie;
            }

            delegate: Astre {
                required property var modelData
                app: modelData.app
                diametre: bureau.tailleDe(modelData.app)
                montrerNom: bureau.nomsToujours
                x: modelData.pos.x * ciel.width - diametre / 2
                y: modelData.pos.y * (ciel.height - 70) - diametre / 2

                onOuvrir: {
                    bureau.dire(pont.lancer(app.id));
                    bureau.relire();
                }
                onDeplacee: function (nx, ny) {
                    pont.placer(app.id,
                                (nx + diametre / 2) / ciel.width,
                                (ny + diametre / 2) / (ciel.height - 70));
                    liens.requestPaint();
                }
                onMenuDemande: function (ex, ey) { menuContextuel.ouvrirPour(app, ex, ey); }
            }
        }
    }

    // ══ 3. LA BARRE ═══════════════════════════════════════════════════════
    // ELLE N'EST PLUS DANS CETTE SCENE, ET C'EST LE CHANGEMENT DU 2026-08-25.
    // Elle y etait, en pilule flottante, et elle disparaissait donc sous la
    // premiere fenetre ouverte — le bureau reste derriere, c'est sa place.
    // Une barre des taches qu'il faut degager pour voir n'en est pas une.
    // Elle vit maintenant dans une fenetre a elle, posee au-dessus des autres
    // par une regle kwin. Voir Barre.qml.
    Barre {
        id: barreTaches
        onMenuDemande: {
            // LE MENU EST DESSINE ICI, DANS LA FENETRE DU BUREAU, qui reste
            // derriere. On remonte donc le bureau avant d'ouvrir, sinon le
            // bouton aurait l'air casse : il ouvrirait un menu invisible.
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.activerBureau();
            menuDemarrer.visible ? menuDemarrer.close() : menuDemarrer.open();
        }
    }

    Connections {
        target: typeof fenetres !== "undefined" ? fenetres : null
        function onChangees(liste) {
            barreTaches.fenetres = JSON.parse(liste);
        }
    }

    // ══ 4. LE MENU DEMARRER ═══════════════════════════════════════════════
    Popup {
        id: menuDemarrer
        objectName: "menuDemarrer"
        x: (bureau.width - width) / 2
        y: bureau.height - height - 84
        width: Math.min(560, bureau.width - 32)
        height: Math.min(640, bureau.height - 130)
        modal: false
        focus: true
        padding: 0

        background: Verre { radius: Theme.rayon }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 220 }
        }

        clip: true
        onOpened: { recherche.text = ""; recherche.forceActiveFocus(); }

        property string vue: "apps"

        contentItem: ColumnLayout {
            spacing: 0

            // --- La recherche ---
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                TextField {
                    id: recherche
                    anchors.fill: parent
                    anchors.margins: 14
                    anchors.bottomMargin: 12
                    placeholderText: "Chercher une application, un dossier, un reglage"
                    placeholderTextColor: Theme.texte3
                    color: Theme.texte
                    font.family: Theme.police
                    font.pixelSize: 13
                    background: Rectangle {
                        radius: 8
                        color: Theme.verre2
                        border.width: 1
                        border.color: recherche.activeFocus ? Theme.bordVif : Theme.bord
                    }
                    // Entree lance la premiere reponse : chercher puis viser a
                    // la souris ce qu'on vient de nommer est un geste de trop.
                    onAccepted: {
                        var l = menuDemarrer.filtrees();
                        if (l.length > 0) {
                            bureau.dire(pont.lancer(l[0].id));
                            bureau.relire();
                            menuDemarrer.close();
                        }
                    }
                }
            }

            // --- Les onglets ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: "transparent"
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: Theme.bord
                }
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.bottom: parent.bottom
                    spacing: 2
                    Repeater {
                        model: [
                            { cle: "apps",     nom: "Applications",  ico: "i-grille" },
                            { cle: "dossiers", nom: "Dossiers",      ico: "i-dossier" },
                            { cle: "reglages", nom: "Reglages",      ico: "i-reglages" },
                            { cle: "alim",     nom: "Alimentation",  ico: "i-alim" }
                        ]
                        delegate: Item {
                            required property var modelData
                            readonly property bool actif: menuDemarrer.vue === modelData.cle
                            width: contenuOnglet.width + 24
                            height: 37
                            HoverHandler { id: survolOnglet; cursorShape: Qt.PointingHandCursor }
                            Row {
                                id: contenuOnglet
                                anchors.centerIn: parent
                                spacing: 7
                                Glyphe {
                                    width: 14; height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    nom: modelData.ico
                                    couleur: actif ? Theme.texte
                                                   : (survolOnglet.hovered ? Theme.texte2 : Theme.texte3)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.nom
                                    font.family: Theme.police
                                    font.pixelSize: 12
                                    color: actif ? Theme.texte
                                                 : (survolOnglet.hovered ? Theme.texte2 : Theme.texte3)
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width; height: 2
                                color: actif ? Theme.texte : "transparent"
                            }
                            TapHandler { onTapped: menuDemarrer.vue = modelData.cle }
                        }
                    }
                }
            }

            // --- Le corps, partie APPLICATIONS ---
            //
            // UNE GridView, ET PAS UN Repeater DANS UN Flickable. C'est une
            // correction mesuree au banc le 2026-08-24, et elle vaut d'etre
            // ecrite parce qu'elle n'a rien d'evident.
            //
            // Un Repeater fabrique TOUTES ses tuiles, y compris celles qui
            // tombent bien en dessous du panneau. Pour du texte et des images,
            // cela ne se voit pas : le decoupage du Flickable les ecarte.
            // Mais les anneaux et les glyphes de Constellation sont des Shape,
            // et un Shape NE RESPECTE PAS le decoupage de ses ancetres —
            // verifie sur le rendu logiciel ET sur le vrai pipeline GPU. Les
            // anneaux des tuiles hors panneau se dessinaient donc par-dessus le
            // bureau, sous la barre des taches.
            //
            // Une GridView ne construit que ce qui est visible ; « cacheBuffer:
            // 0 » lui interdit d'en preparer au-dela, et la hauteur calee sur
            // un multiple de la cellule, avec SnapToRow, garantit qu'aucune
            // rangee n'est jamais a cheval sur le bord. Il n'existe alors plus
            // une seule tuile hors du panneau — le defaut n'est pas masque,
            // il n'a plus de quoi se produire.
            Item {
                id: cadreApps
                visible: menuDemarrer.vue === "apps"
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grilleApps
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    width: parent.width - 32
                    height: Math.max(cellHeight,
                                     Math.floor((parent.height - 22) / cellHeight) * cellHeight)
                    clip: true
                    cacheBuffer: 0
                    snapMode: GridView.SnapToRow
                    boundsBehavior: Flickable.StopAtBounds

                    readonly property int colonnes: Math.max(1, Math.floor(width / 88))
                    cellWidth: width / colonnes
                    cellHeight: 96

                    ScrollBar.vertical: ScrollBar { }

                    model: menuDemarrer.vue === "apps" ? menuDemarrer.filtrees() : []

                    delegate: Tuile {
                        required property var modelData
                        app: modelData
                        width: grilleApps.cellWidth - 6
                        height: grilleApps.cellHeight - 6
                        onOuvrir: {
                            bureau.dire(pont.lancer(app.id));
                            bureau.relire();
                            menuDemarrer.close();
                        }
                        onEpingler: function (oui) {
                            pont.epingler(app.id, oui);
                            bureau.relire();
                            bureau.dire(oui ? (app.nom + " epinglee")
                                            : (app.nom + " retiree de la barre"));
                        }
                        onMenuDemande: function (ex, ey) { menuContextuel.ouvrirPour(app, ex, ey); }
                    }
                }
            }

            // --- Le corps, LES AUTRES ONGLETS ---
            // Ils tiennent sans defiler (mesure : 77, 324 et 155 pixels pour
            // une hauteur utile de 542), donc aucune tuile hors cadre ici.
            Flickable {
                visible: menuDemarrer.vue !== "apps"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: corps.height
                clip: true
                ScrollBar.vertical: ScrollBar { }

                Column {
                    id: corps
                    width: parent.width
                    padding: 16
                    spacing: 14

                    // ---- Dossiers ----
                    Column {
                        visible: menuDemarrer.vue === "dossiers"
                        width: parent.width - 32
                        spacing: 1
                        Repeater {
                            model: bureau.listeDossiers
                            delegate: Rangee {
                                required property var modelData
                                texte: modelData.nom
                                detail: modelData.detail
                                glyphe: modelData.ico
                                onChoisi: {
                                    bureau.dire(pont.ouvrirDossier(modelData.chemin));
                                    menuDemarrer.close();
                                }
                            }
                        }
                    }

                    // ---- Reglages ----
                    Column {
                        visible: menuDemarrer.vue === "reglages"
                        width: parent.width - 32
                        spacing: 14

                        Text {
                            text: "FOND D'ECRAN"
                            color: Theme.texte3
                            font.family: Theme.policeMono
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }
                        Grid {
                            width: parent.width
                            columns: Math.max(1, Math.floor(width / 113))
                            spacing: 9
                            Repeater {
                                model: Fonds.ORDRE
                                delegate: Item {
                                    required property string modelData
                                    width: (parent.width - 9 * (parent.columns - 1)) / parent.columns
                                    height: width * 10 / 16
                                    Canvas {
                                        id: vignette
                                        anchors.fill: parent
                                        onPaint: {
                                            var g = getContext("2d");
                                            Fonds.FONDS[modelData].peindre(g, width, height);
                                        }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        radius: 8
                                        border.width: 1.5
                                        border.color: bureau.fondActuel === modelData
                                                      ? Theme.texte : Theme.bord
                                    }
                                    Text {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 5
                                        text: Fonds.FONDS[modelData].nom
                                        color: Theme.texte2
                                        font.family: Theme.police
                                        font.pixelSize: 10
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            bureau.fondActuel = modelData;
                                            pont.reglerFond("fond", modelData);
                                            bureau.dire("fond : " + Fonds.FONDS[modelData].nom);
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "BUREAU"
                            color: Theme.texte3
                            font.family: Theme.policeMono
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }
                        Rangee {
                            width: parent.width
                            texte: "Toujours afficher les noms"
                            detail: bureau.nomsToujours ? "oui" : "non"
                            glyphe: "i-doc"
                            onChoisi: {
                                bureau.nomsToujours = !bureau.nomsToujours;
                                pont.reglerFond("noms", bureau.nomsToujours);
                            }
                        }
                        Rangee {
                            width: parent.width
                            texte: "Vider le bureau"
                            detail: Object.keys(bureau.donnees.placees).length + " posees"
                            glyphe: "i-grille"
                            onChoisi: {
                                for (var ident in bureau.donnees.placees)
                                    pont.retirerDuBureau(ident);
                                bureau.relire();
                                bureau.dire("bureau vide");
                            }
                        }
                    }

                    // ---- Alimentation ----
                    Column {
                        visible: menuDemarrer.vue === "alim"
                        width: parent.width - 32
                        spacing: 1
                        Repeater {
                            model: [
                                { act: "verrouiller", nom: "Verrouiller",  ico: "i-cadenas",    grave: false },
                                { act: "deconnecter", nom: "Se deconnecter", ico: "i-sortie",   grave: false },
                                { act: "redemarrer",  nom: "Redemarrer",   ico: "i-recommence", grave: true },
                                { act: "eteindre",    nom: "Eteindre",     ico: "i-alim",       grave: true }
                            ]
                            delegate: Rangee {
                                required property var modelData
                                texte: modelData.nom
                                glyphe: modelData.ico
                                grave: modelData.grave
                                onChoisi: {
                                    menuDemarrer.close();
                                    pont.session(modelData.act);
                                }
                            }
                        }
                    }
                }
            }
        }

        // La recherche filtre sur le nom ET sur le commentaire : « navigateur »
        // doit trouver Vivaldi meme si le mot n'est pas dans son nom.
        function filtrees() {
            var q = recherche.text.toLowerCase().trim();
            if (q === "") return bureau.donnees.etoiles;
            var sortie = [];
            for (var i = 0; i < bureau.donnees.etoiles.length; i++) {
                var e = bureau.donnees.etoiles[i];
                if (e.nom.toLowerCase().indexOf(q) >= 0 ||
                    (e.txt || "").toLowerCase().indexOf(q) >= 0)
                    sortie.push(e);
            }
            return sortie;
        }
    }

    // ══ 5. LE MENU DU CLIC DROIT ══════════════════════════════════════════
    // C'EST LA PIECE QUI N'EXISTAIT PAS. Sur la page, le clic droit tombait sur
    // le menu du navigateur — « Recharger », « Enregistrer sous », « Inspecter »
    // — au lieu des gestes du bureau. Il n'y avait aucun moyen d'epingler une
    // application ni de la poser sur le bureau autrement qu'en la glissant.
    Menu {
        id: menuContextuel
        objectName: "menuContextuel"
        property var cible: null

        function ouvrirPour(app, ex, ey) {
            cible = app;
            x = Math.min(ex, bureau.width - width - 8);
            y = Math.min(ey, bureau.height - height - 8);
            open();
        }

        readonly property bool posee: cible !== null &&
            Object.prototype.hasOwnProperty.call(bureau.donnees.placees, cible.id)
        readonly property bool epinglee: cible !== null && (cible.epingle || 0) > 0

        background: Verre {
            radius: 8
            implicitWidth: 232
        }

        ArticleMenu {
            text: "Ouvrir"
            onTriggered: {
                bureau.dire(pont.lancer(menuContextuel.cible.id));
                bureau.relire();
            }
        }

        SeparateurMenu { }

        ArticleMenu {
            text: menuContextuel.epinglee ? "Retirer de la barre" : "Epingler a la barre"
            onTriggered: {
                pont.epingler(menuContextuel.cible.id, !menuContextuel.epinglee);
                bureau.relire();
            }
        }

        ArticleMenu {
            text: menuContextuel.posee ? "Retirer du bureau" : "Placer sur le bureau"
            onTriggered: {
                if (menuContextuel.posee) {
                    pont.retirerDuBureau(menuContextuel.cible.id);
                } else {
                    // On pose la ou il y a de la place, pas toujours au meme
                    // point : deux applications placees de suite se
                    // superposeraient sinon, et la seconde cacherait la premiere.
                    var p = bureau.placeLibre();
                    pont.placer(menuContextuel.cible.id, p.x, p.y);
                }
                bureau.relire();
            }
        }
    }

    // Cherche un point du ciel qui ne soit pas deja occupe. Balayage en
    // spirale grossiere : suffisant pour quelques dizaines d'etoiles, et sans
    // le cout d'un vrai placement de graphe.
    function placeLibre() {
        var prises = [];
        for (var ident in donnees.placees) prises.push(donnees.placees[ident]);
        var pas = 0.11;
        for (var ligne = 0; ligne < 8; ligne++) {
            for (var col = 0; col < 9; col++) {
                var x = 0.08 + col * pas, y = 0.10 + ligne * pas;
                var libre = true;
                for (var i = 0; i < prises.length; i++) {
                    if (Math.abs(prises[i].x - x) < pas * 0.8 &&
                        Math.abs(prises[i].y - y) < pas * 0.8) { libre = false; break; }
                }
                if (libre) return { x: x, y: y };
            }
        }
        return { x: 0.5, y: 0.5 };
    }

    // ══ 6. LE MOT FUGACE ══════════════════════════════════════════════════
    Verre {
        id: mot
        property alias text: motTexte.text
        property bool vu: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 92
        radius: 7
        width: motTexte.implicitWidth + 26
        height: motTexte.implicitHeight + 12
        opacity: vu ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 240 } }
        Text {
            id: motTexte
            anchors.centerIn: parent
            color: Theme.texte2
            font.family: Theme.policeMono
            font.pixelSize: 11
        }
    }
    Timer { id: chrono; interval: 2600; onTriggered: mot.vu = false }

    // ══ 6 bis. LA BULLE DE NOTIFICATION ═══════════════════════════════════
    // Elle vit dans une FENETRE A ELLE, pas dans cette scene, parce que ce
    // bureau reste derriere les autres fenetres — c'est ce qu'on attend d'un
    // bureau, et c'est ce qui rendrait une bulle invisible pile quand elle
    // sert. Voir Bulle.qml pour ce qui a ete mesure.
    Bulle { id: bulle }

    // « notifications » est nul quand le nom du bus etait deja pris. Un
    // Connections sans cible ne fait rien, et le bureau s'ouvre quand meme :
    // un bureau sans bulles reste un bureau.
    Connections {
        target: typeof notifications !== "undefined" ? notifications : null
        function onMontrer(id, app, titre, corps, duree, urgence) {
            bulle.poser(id, app, titre, corps, duree, urgence);
        }
        function onRetirer(id) {
            bulle.retirer(id);
        }
    }

    // ══ 7. LES RACCOURCIS CLAVIER ═════════════════════════════════════════
    Shortcut {
        sequences: [StandardKey.Open, "Meta"]
        onActivated: menuDemarrer.visible ? menuDemarrer.close() : menuDemarrer.open()
    }
    Shortcut {
        sequence: "N"
        onActivated: {
            bureau.nomsToujours = !bureau.nomsToujours;
            pont.reglerFond("noms", bureau.nomsToujours);
        }
    }
    Shortcut { sequence: "Escape"; onActivated: menuDemarrer.close() }

    // ══ 8. L'AIDE ═════════════════════════════════════════════════════════
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        // LA BARRE DES TACHES OCCUPE MAINTENANT LES 52 PIXELS DU BAS, et elle
        // est posee AU-DESSUS de cette fenetre : l'aide y disparaissait.
        anchors.bottomMargin: 74
        spacing: 2
        visible: bureau.width > 760
        Repeater {
            model: [
                "clic droit  epingler, poser sur le bureau",
                "double-clic sur une etoile  ouvrir",
                "glisser une etoile  la deplacer",
                "N  noms toujours visibles"
            ]
            delegate: Text {
                required property string modelData
                text: modelData
                horizontalAlignment: Text.AlignRight
                width: 260
                color: Theme.texte3
                font.family: Theme.policeMono
                font.pixelSize: 10
            }
        }
    }
}
