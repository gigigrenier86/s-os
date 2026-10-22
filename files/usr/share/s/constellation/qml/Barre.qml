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

    // LA FENETRE EST PLUS HAUTE QUE LA BARRE, ET C'EST LE MENU QUI L'EXIGE.
    // Mesure du 2026-08-27, sur cette machine : un menu ouvert dans sa PROPRE
    // fenetre (popupType: Popup.Window) reprend bien sa vraie hauteur, mais il
    // se pose tout a gauche de l'ecran. Les quatre facons de lui donner une
    // abscisse — popup(x, y), m.x avant open(), popup(parent, x, y), un objet
    // d'ancrage pose a la bonne place — rendent exactement la meme chose :
    //
    //     demande x = 600   ->   fenetre du popup a QRect(0, 0, 200, 360)
    //
    // C'est la meme loi que la barre laterale a rencontree le 2026-08-25 et
    // que « bornerLaterale » documente : UN CLIENT WAYLAND NE SE POSITIONNE
    // PAS LUI-MEME. La reponse est donc la meme : la fenetre garde une taille
    // qui contient tout ce qu'elle peut avoir a montrer, et c'est sa zone
    // SENSIBLE qui retrecit — « pont.bornerBarre », plus bas.
    //
    // Le menu redevient alors un Popup ordinaire, dessine DANS cette fenetre,
    // ou nos coordonnees sont exactes et ou personne ne le replace.
    property int placeMenu: 420

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

    // ══ LES TUILES SONT UN MODELE MIS A JOUR SUR PLACE, PAS UN TABLEAU REFAIT ═
    // « ouvertures » est remplace en entier a chaque nouvelle de kwin, et un
    // Repeater dont le tableau change — ne fut-ce que d'UN champ d'UNE fenetre —
    // detruit et recree TOUTES ses tuiles : icones rechargees, survol et echelle
    // remis a zero, animation coupee net. Or un navigateur change de titre a
    // chaque page et le focus change a chaque clic.
    //
    // MESURE DU 2026-09-19, banc de fluidite, vrai Barre.qml : 40 nouvelles de
    // kwin dont seul le titre d'une des six fenetres change → 240 tuiles creees
    // (40 x 6), le client a 17 % de CPU pendant la rafale. Une rafale de listes
    // strictement IDENTIQUES ne reconstruit rien : Qt compare les tableaux par
    // valeur — c'est ce qui a fait croire, un moment, que le defaut n'existait
    // pas. Le cas reel n'est jamais identique.
    //
    // Ici on compare par IDENTIFIANT et on ne touche que ce qui differe : une
    // fenetre qui s'ouvre est inseree, une qui se ferme est retiree, un titre
    // qui change n'est qu'une propriete reecrite dans la tuile qui existe deja.
    // Le champ s'appelle « wid » et non « id » : « id » est reserve par QML.
    ListModel { id: modeleOuvertures }

    function ligneDeTuile(f) {
        return {
            wid: String(f.id || ""),
            classe: String(f.classe || ""),
            titre: String(f.titre || ""),
            // « === true » : un champ absent doit valoir faux, pas provoquer
            // « Unable to assign [undefined] to bool » (releve dans le journal
            // du demarrage de la coquille).
            active: f.active === true,
            reduite: f.reduite === true
        };
    }

    // LA MISE A JOUR SUR PLACE, ECRITE UNE FOIS POUR LES DEUX MODELES — les
    // tuiles de Constellation (par fenetre) et les icones groupees de Windows
    // et d'Android (par application). « champ » est la cle qui dit qu'une
    // ligne est « la meme » d'une nouvelle de kwin a l'autre.
    function synchroniser(m, lignes, champ) {
        for (var i = 0; i < lignes.length; i++) {
            var ligne = lignes[i];
            var j = i;
            while (j < m.count && m.get(j)[champ] !== ligne[champ])
                j++;
            if (j === m.count) {
                m.insert(i, ligne);
                continue;
            }
            if (j !== i)
                m.move(j, i, 1);
            var actuelle = m.get(i);
            for (var cle in ligne)
                if (actuelle[cle] !== ligne[cle])
                    m.setProperty(i, cle, ligne[cle]);
        }
        while (m.count > lignes.length)
            m.remove(m.count - 1);
    }

    function synchroniserOuvertures() {
        synchroniser(modeleOuvertures, (barre.ouvertures || []).map(ligneDeTuile), "wid");
    }

    // ══ LES ICONES GROUPEES DE WINDOWS ET D'ANDROID ════════════════════════
    // UNE ICONE PAR APPLICATION, pas une tuile par fenetre : les epinglees
    // d'abord, puis ce qui tourne sans etre epingle. Une application ouverte
    // et epinglee n'a qu'UNE icone, qui porte le trait « ouvert » — c'est la
    // barre de Windows, et celle d'une tablette Android. Une fenetre qu'aucune
    // application connue ne revendique (un logiciel Windows : « steam_proton »
    // pour tous, voir Constellation.qml) garde son icone a elle.
    ListModel { id: modeleGroupes }

    function groupesVoulus() {
        var sortie = [], index = {};
        var ep = (bureau.donnees && bureau.donnees.epingles) ? bureau.donnees.epingles : [];
        for (var i = 0; i < ep.length; i++) {
            var a = bureau.appParId(ep[i]);
            if (!a) continue;
            var cleA = "app:" + a.id;
            if (index[cleA] !== undefined) continue;
            index[cleA] = sortie.length;
            sortie.push({ cle: cleA, appId: a.id, membres: [], epinglee: true });
        }
        var liste = barre.ouvertures || [];
        for (var j = 0; j < liste.length; j++) {
            var f = liste[j];
            var app = bureau.appParId(f.classe) || bureau.appParClasse(f.classe);
            var cleF = app ? "app:" + app.id : "fen:" + f.id;
            if (index[cleF] === undefined) {
                index[cleF] = sortie.length;
                sortie.push({ cle: cleF, appId: app ? app.id : "", membres: [], epinglee: false });
            }
            // « membres » ET NON « fenetres » : le controle de construction
            // cherche, dans le QML, les appels de methode sur le pont de kwin —
            // qui s'appelle « fenetres » — et ce nom-la l'aurait trompe.
            sortie[index[cleF]].membres.push(f);
        }
        return sortie.map(function (g) {
            var wids = [], actif = false, reduites = g.membres.length > 0, titre = "";
            for (var k = 0; k < g.membres.length; k++) {
                var fk = g.membres[k];
                wids.push(String(fk.id || ""));
                if (fk.active === true && fk.reduite !== true) actif = true;
                if (fk.reduite !== true) reduites = false;
                if (titre === "") titre = String(fk.titre || "");
            }
            // « === true » partout : un champ absent vaut faux, jamais
            // « Unable to assign [undefined] to bool ».
            return { cle: g.cle, appId: g.appId, wids: wids.join("\n"),
                     nb: g.membres.length, active: actif, reduite: reduites,
                     titre: titre, epinglee: g.epinglee === true };
        });
    }

    // HORS DE CONSTELLATION SEULEMENT : la barre de Constellation n'en a pas
    // besoin, et le calcul se refait a chaque nouvelle de kwin.
    function synchroniserGroupes() {
        if (Theme.estConstellation) {
            if (modeleGroupes.count > 0) modeleGroupes.clear();
            return;
        }
        synchroniser(modeleGroupes, groupesVoulus(), "cle");
    }

    function groupeDe(cle) {
        for (var i = 0; i < modeleGroupes.count; i++) {
            var g = modeleGroupes.get(i);
            if (g.cle === cle)
                return { appId: g.appId, nb: g.nb, active: g.active,
                         wids: g.wids === "" ? [] : g.wids.split("\n") };
        }
        return null;
    }

    // LE CLIC SUR UNE ICONE GROUPEE, comme chez Windows : rien d'ouvert, on
    // lance ; une fenetre, on l'affiche ou on la range ; plusieurs, on choisit.
    function cliquerGroupe(cle, ex) {
        var g = groupeDe(cle);
        if (!g) return;
        if (g.nb === 0) {
            if (g.appId !== "") {
                bureau.dire(pont.lancer(g.appId));
                pont.effacerBadge(g.appId);
                bureau.relire();
            }
            return;
        }
        if (g.nb === 1) {
            barre.activation(g.wids[0], g.active);
            return;
        }
        menuGroupe.ouvrirPour(cle, ex);
    }

    // LE CLIC DROIT : le menu d'une epinglee si rien n'est ouvert, sinon celui
    // de la fenetre active du groupe — il porte deja « Fermer », « Ranger » et
    // l'epinglage.
    function menuDuGroupe(cle, ex) {
        var g = groupeDe(cle);
        if (!g) return;
        if (g.nb === 0) {
            var a = bureau.appParId(g.appId);
            if (a) menuEpinglee.ouvrirPour(a, ex);
            return;
        }
        var cible = g.wids[0];
        for (var i = 0; i < barre.ouvertures.length; i++) {
            var f = barre.ouvertures[i];
            if (g.wids.indexOf(String(f.id)) >= 0 && f.active === true) {
                cible = String(f.id);
                break;
            }
        }
        menuFenetre.ouvrirPour({ id: cible }, ex);
    }

    onOuverturesChanged: {
        synchroniserOuvertures();
        synchroniserGroupes();
    }
    Connections {
        target: bureau
        function onDonneesChanged() { barre.synchroniserGroupes(); }
    }
    Connections {
        target: Theme
        function onNomChanged() { barre.synchroniserGroupes(); }
    }

    // ── L'HEURE, COMMUNE AUX TROIS BARRES ──────────────────────────────────
    // ELLE NE SE REVEILLE QU'AU CHANGEMENT DE MINUTE. L'affichage est
    // « HH:mm » : un tic par seconde reecrivait soixante fois le meme texte et
    // reveillait la coquille, donc le compositeur, pour rien. Apres chaque tic
    // on vise le debut de la minute suivante (+ 50 ms pour tomber franchement
    // APRES le changement, jamais avant).
    property string heure: "--:--"
    property string dateCourte: "--"
    property string dateNumerique: ""
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var maintenant = new Date();
            barre.heure = Qt.formatTime(maintenant, "HH:mm");
            barre.dateCourte = calendrier.formaterDateCourte(maintenant);
            barre.dateNumerique = Qt.formatDate(maintenant, "dd/MM/yyyy");
            interval = 60000 - (maintenant.getSeconds() * 1000
                                + maintenant.getMilliseconds()) + 50;
        }
    }

    // LE NOM D'UNE EPINGLEE S'AFFICHE AU-DESSUS D'ELLE, JAMAIS DESSUS.
    // L'infobulle de Qt se posait PAR-DESSUS la pastille — il n'y a pas la
    // place de la mettre en dessous, la barre touche le bas de l'ecran — et
    // elle arrivait assez vite pour intercepter le clic qu'on etait en train
    // de faire. Une etiquette qui empeche d'atteindre ce qu'elle nomme est
    // pire que pas d'etiquette du tout.
    property string nomSurvole: ""
    property real centreSurvole: 0

    width: Screen.width
    // ELLE NE MONTE QUE SI QUELQU'UN PEUT LA MASQUER. Sans masque, une fenetre
    // haute de 472 pixels posee au-dessus de tout avalerait les clics sur tout
    // le bas de l'ecran — bien pire que le defaut qu'on repare. Si le pont
    // manque, elle reste une barre de cinquante-deux pixels : le menu s'y
    // trouvera borne, ce qui est visible et reparable, au lieu d'un bureau qui
    // ne repond plus, qui ne l'est pas.
    height: (typeof pont !== "undefined" && pont && pont.bornerBarre)
            ? hauteur + placeMenu : hauteur
    visible: !efface
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

    // ELLE S'EFFACE ENTIEREMENT PENDANT UN VRAI PLEIN ECRAN — meme raison
    // que la barre laterale, plus bas dans ce meme depot (Constellation.qml).
    // « WindowStaysOnTopHint » + la regle kwin qui garde cette fenetre
    // au-dessus de tout la placent PAR-DESSUS n'importe quelle video ou jeu,
    // meme un « fullScreen=true » reel : mesure le 2026-08-30, une fenetre
    // en plein ecran restait contenue a 1028 px de haut plutot que les 1080
    // de l'ecran, precisement pour ne jamais passer sous cette barre. Une
    // barre visible par-dessus un plein ecran n'est pas mieux qu'une fenetre
    // qui s'arrete avant le bord — les deux montrent la barre pendant un
    // film. On la retire de l'ecran, pas seulement du dessus des autres.
    property bool efface: false
    // DIX JOURS, PARCE QUE L'UTILISATEUR A DIT DIX JOURS. Le nombre est ici et
    // dans l'etiquette du menu, jamais ecrit deux fois.
    property int joursInactivite: 10

    signal menuDemande()
    signal fermeture(string ident)
    // « Forcer l'arret », demande le 2026-08-30 — distinct de « fermeture »
    // ci-dessus, qui reste une demande polie. Voir fenetres.forcerFermeture()
    // pour le pourquoi.
    signal forcerFermeture(string ident)
    signal sommeil(string ident)
    signal menageDemande(int jours)
    signal veilleChoisie(string mode)
    // LE COMPTE DES OUBLIEES SE DEMANDE A L'OUVERTURE DU MENU, PAS EN CONTINU.
    // Il se refaisait a chaque nouvelle du compositeur — donc a chaque
    // changement de titre, donc plusieurs fois par seconde pendant qu'on tape
    // dans un terminal — pour une etiquette que personne ne regarde tant que
    // le menu est ferme.
    signal inactivesDemandees()
    property bool reglagesOuverts: false
    signal reglagesDemandes()
    // ELLE TRANSMET L'ETAT QU'ELLE AFFICHE, ET C'EST TOUT L'OBJET DU SECOND
    // ARGUMENT. Laisser kwin relire « quelle fenetre est active » au moment ou
    // le script tourne rend une reponse qui a pu changer depuis le clic : le
    // premier clic reactivait alors sans rien faire de visible, et il en
    // fallait deux pour reduire. La barre, elle, sait ce qu'elle vient de
    // montrer a l'utilisateur — c'est cette verite-la qu'il a cliquee.
    signal activation(string ident, bool estActive)
    // LA PASTILLE « RECHERCHER » ET LE COIN « AFFICHER LE BUREAU » DE WINDOWS.
    // La barre previent ; Constellation remonte le bureau et ouvre le menu.
    signal rechercheDemandee()
    signal bureauDemande()
    // LES TROIS BOUTONS DE NAVIGATION DE LA TABLETTE ANDROID. La barre
    // previent ; Constellation agit — meme patron que tous les signaux.
    signal retourDemande()
    signal accueilDemande()
    signal recentsDemande()

    // ── La zone sensible ──────────────────────────────────────────────────
    // Meme mecanisme que la barre laterale, meme raison : la fenetre est plus
    // grande que ce qu'elle montre, et sans masque elle avalerait les clics du
    // bas de l'ecran sur toute sa hauteur. « setMask » part en
    // « wl_surface.set_input_region » — voir pont.bornerBarre.
    // QUAND LE MENU EST OUVERT, TOUTE LA FENETRE DEVIENT SENSIBLE, et ce n'est
    // pas de la generosite : c'est le seul moyen qu'un clic A COTE du menu nous
    // parvienne. Le masque ne couvrait que la bande et le rectangle du menu ;
    // un clic dans le vide entre les deux tombait donc a la fenetre du dessous,
    // « CloseOnPressOutside » ne se declenchait jamais, et le menu restait
    // ouvert jusqu'au changement de fenetre. Releve par l'utilisateur le
    // 2026-08-27 : « la fenetre ne disparait que si je change d'onglet ».
    // LE MOTEUR NE DOIT JAMAIS PARAITRE. Vivaldi ecrit lui-meme son propre
    // nom en fin de titre de fenetre — « <page> - Vivaldi » — a l'interieur
    // du binaire, hors de portee d'un reglage de profil. Mesure le
    // 2026-09-07 sur une fenetre S Web reelle : le titre brut porte
    // exactement « ... - YouTube - Vivaldi ». On ne peut pas empecher
    // Vivaldi de l'ecrire ; on peut l'empecher de s'afficher.
    function titreAffiche(brut) {
        var s = String(brut || "");
        return s.replace(/ - Vivaldi$/, "");
    }

    function borner() {
        if (typeof pont === "undefined" || !pont || !pont.bornerBarre)
            return;
        pont.bornerBarre(barre, (menuFenetre.visible || menuEpinglee.visible
                                  || calendrier.visible || menuGroupe.visible)
                                ? barre.height : barre.hauteur);
    }

    onWidthChanged: borner()
    onHeightChanged: borner()
    onEffaceChanged: {
        if (efface) {
            if (typeof pont !== "undefined" && pont && pont.bornerBarre)
                pont.bornerBarre(barre, 0);
        } else {
            borner();
        }
    }
    Component.onCompleted: borner()

    // LA BANDE VISIBLE EST EN BAS, LE RESTE DE LA FENETRE EST DU VIDE. Ce vide
    // n'avale aucun clic : la zone sensible est posee par « pont.bornerBarre »
    // et ne couvre que cette bande — plus le menu quand il est ouvert.
    //
    // ELLE PORTE LA MISE EN PAGE DU THEME — une seule vivante a la fois, dans
    // un Loader — et, en commun aux trois, l'etiquette, les menus et le
    // calendrier : ceux-la se positionnent par rapport a la bande, et ne
    // changent pas de comportement avec le theme.
    Item {
        id: bande
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: barre.hauteur

        Loader {
            id: miseEnPage
            anchors.fill: parent
            sourceComponent: Theme.estWindows ? miseWindows
                           : (Theme.estAndroid ? miseAndroid : miseConstellation)
        }

        // ── Le nom de l'epinglee survolee ─────────────────────────────────
        Rectangle {
            id: etiquette
            visible: barre.nomSurvole !== ""
            // Bornee aux deux extremites : une epinglee tout a gauche ne doit
            // pas faire deborder son nom hors de l'ecran.
            x: Math.max(4, Math.min(parent.width - width - 4,
                                    barre.centreSurvole - width / 2))
            // EN CONSTELLATION ELLE TIENT DANS LA BANDE, au-dessus de
            // l'epinglee. AILLEURS ELLE MONTE AU-DESSUS DE LA BARRE, comme
            // l'infobulle de Windows : la zone que le masque laisse insensible
            // reste visible — elle n'avale aucun clic, elle se voit.
            y: Theme.estConstellation ? 2 : -34
            width: nomTexte.implicitWidth + (Theme.estConstellation ? 14 : 20)
            height: Theme.estConstellation ? 15 : 28
            radius: Theme.estConstellation ? 4 : (Theme.estAndroid ? 14 : 4)
            color: Theme.estConstellation ? Qt.rgba(1, 1, 1, 0.10)
                 : (Theme.estAndroid ? Theme.palette.inverseSurface
                                     : (Theme.sombre ? "#2c2c2c" : "#f9f9f9"))
            border.width: Theme.estWindows ? 1 : 0
            border.color: Theme.bord
            Text {
                id: nomTexte
                anchors.centerIn: parent
                text: barre.nomSurvole
                color: Theme.estAndroid ? Theme.palette.inverseOnSurface : Theme.texte
                font.family: Theme.police
                font.pixelSize: Theme.estConstellation ? 10 : 12
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

            // IL EST DESSINE DANS LA FENETRE DE LA BARRE, ET IL LUI FAUT DONC
            // DE LA PLACE. Un Popup est borne a sa fenetre hote : tant que
            // celle-ci ne faisait que cinquante-deux pixels, neuf articles
            // hauts de 360 rendaient « height 52 » — une ligne visible sur
            // neuf. La fenetre monte maintenant plus haut que la barre (voir
            // « placeMenu »), et il reprend sa taille sans rien demander au
            // compositeur.

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

            // « AJOUTER A LA CONSTELLATION » DEPUIS UNE FENETRE OUVERTE —
            // correctif du 2026-10-20. Le geste existait deja (menuContextuel
            // dans Constellation.qml, pour une etoile du ciel ou une tuile
            // du menu Demarrer) mais jamais depuis ICI, alors que c'est le
            // premier endroit ou on cherche a epingler un logiciel qu'on
            // vient d'ouvrir. « pont.placer »/« pont.retirerDuBureau » sont
            // deja generiques — rien a changer cote Python, seulement a
            // cabler ici. Sans objet si aucune etoile ne correspond a la
            // classe de cette fenetre : meme recherche qu'une tuile ouverte
            // emploie deja pour son icone, voir « tuile.app » plus haut.
            readonly property var cibleApp: cible !== null
                ? (bureau.appParId(cible.classe) || bureau.appParClasse(cible.classe))
                : null
            readonly property bool ciblePosee: cibleApp !== null &&
                Object.prototype.hasOwnProperty.call(bureau.donnees.placees, cibleApp.id)

            // Une fenetre qui disparait pendant que son menu est ouvert
            // laisserait un menu qui ne vise plus rien.
            onCibleChanged: if (cible === null && visible) close()

            // LA ZONE SENSIBLE SUIT LE MENU, SINON IL S'AFFICHE SANS SE
            // LAISSER CLIQUER. Il est dessine au-dessus de la bande, c'est-a-
            // dire dans la partie de la fenetre que le masque exclut.
            onVisibleChanged: barre.borner()
            onXChanged: barre.borner()
            onYChanged: barre.borner()
            onHeightChanged: barre.borner()
            onWidthChanged: barre.borner()

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
                radius: Theme.rayonMenu
                implicitWidth: 268

                // ON SE DETOURNE DU MENU AUSSI SOUVENT QU'ON CLIQUE A COTE, et
                // la fenetre de la barre ne couvre que le bas de l'ecran : un
                // clic plus haut ne lui parvient pas. Le survol, lui, se sait
                // toujours. Meme idiome que la barre laterale, meme raison.
                HoverHandler {
                    id: survolMenu
                    onHoveredChanged: {
                        if (hovered)
                            fermetureMenu.stop();
                        else if (menuFenetre.visible)
                            fermetureMenu.restart();
                    }
                }
            }

            ArticleMenu {
                text: menuFenetre.rangee ? "Afficher" : "Ranger"
                onTriggered: barre.activation(menuFenetre.cibleId,
                                              !menuFenetre.rangee)
            }

            ArticleMenu {
                visible: menuFenetre.cibleApp !== null
                height: visible ? implicitHeight : 0
                text: menuFenetre.ciblePosee
                      ? "Retirer de la Constellation" : "Ajouter a la Constellation"
                onTriggered: {
                    if (menuFenetre.ciblePosee) {
                        pont.retirerDuBureau(menuFenetre.cibleApp.id);
                    } else {
                        var p = bureau.placeLibre();
                        pont.placer(menuFenetre.cibleApp.id, p.x, p.y);
                    }
                    bureau.relire();
                }
            }

            // « EPINGLER A LA BARRE » DEPUIS LA FENETRE OUVERTE — ajoute le
            // 2026-10-20 avec les themes : sous Windows, c'est par la qu'on
            // epingle un logiciel qu'on vient d'ouvrir. Sans objet, comme
            // l'article d'au-dessus, si aucune application ne correspond.
            ArticleMenu {
                visible: menuFenetre.cibleApp !== null
                height: visible ? implicitHeight : 0
                readonly property bool epinglee: menuFenetre.cibleApp !== null
                                                 && (menuFenetre.cibleApp.epingle || 0) > 0
                text: epinglee ? "Retirer de la barre" : "Epingler a la barre"
                onTriggered: {
                    pont.epingler(menuFenetre.cibleApp.id, !epinglee);
                    bureau.relire();
                }
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

            // « Forcer l'arret » — DEMANDE LE 2026-08-30, ET CE CARNET EN AVAIT
            // DEJA LA PREUVE PLUSIEURS FOIS. « Fermer la fenetre » ci-dessus
            // envoie une DEMANDE ; un programme qui ne repond plus a ses
            // evenements (Cursor plante, Soul Land bloque, PURPLE en fenetre
            // noire) ne la recoit jamais. Celui-ci tue le processus directement
            // — voir fenetres.forcerFermeture().
            ArticleMenu {
                grave: true
                text: "Forcer l'arret"
                onTriggered: barre.forcerFermeture(menuFenetre.cibleId)
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
            // DEUX ARTICLES PLUTOT QU'UN SOUS-MENU. Le style « Basic » ne
            // peint rien de lui-meme (voir ArticleMenu.qml) : un sous-menu
            // demanderait d'habiller une seconde fois le fond, la fleche et
            // le survol, pour deux lignes qu'on lit d'un coup d'oeil.
            Repeater {
                model: [
                    { cle: "non", nom: "Veille : aucune" },
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

        // Un menu qu'on quitte des yeux se referme. Plus long que les 500 ms
        // de la barre laterale : on lit un menu, on ne fait pas que le
        // traverser.
        Timer {
            id: fermetureMenu
            interval: 900
            onTriggered: if (!survolMenu.hovered) menuFenetre.close()
        }

        // ── Le menu du clic droit sur une epinglee ────────────────────────
        // MEME PATRON QUE « menuFenetre » CI-DESSUS, POUR LA MEME RAISON :
        // dessine dans la fenetre de la barre (qui reste au-dessus), ouvert
        // vers le haut, borne par « pont.bornerBarre ». Une epinglee n'est
        // pas une fenetre ouverte — pas de « Ranger » ni de veille possible,
        // seulement relancer, relancer en administrateur, ou desepingler.
        Menu {
            id: menuEpinglee
            objectName: "menuEpinglee"
            property var cible: null

            onVisibleChanged: barre.borner()
            onXChanged: barre.borner()
            onYChanged: barre.borner()
            onHeightChanged: barre.borner()
            onWidthChanged: barre.borner()

            function ouvrirPour(app, ex) {
                cible = app;
                popup(Math.max(4, Math.min(barre.width - implicitWidth - 4,
                                           ex - implicitWidth / 2)),
                      -implicitHeight - 6);
            }

            background: Verre {
                radius: Theme.rayonMenu
                implicitWidth: 232
                HoverHandler {
                    id: survolMenuEp
                    onHoveredChanged: {
                        if (hovered)
                            fermetureMenuEp.stop();
                        else if (menuEpinglee.visible)
                            fermetureMenuEp.restart();
                    }
                }
            }

            ArticleMenu {
                text: "Ouvrir"
                onTriggered: {
                    bureau.dire(pont.lancer(menuEpinglee.cible.id));
                    pont.effacerBadge(menuEpinglee.cible.id);
                    bureau.relire();
                }
            }

            ArticleMenu {
                text: "Executer en root"
                onTriggered: bureau.dire(pont.lancerEnRoot(menuEpinglee.cible.id))
            }

            // « AJOUTER A LA CONSTELLATION » — correctif du 2026-10-20, meme
            // trou et meme correctif que « menuFenetre » plus haut dans ce
            // fichier. « cible » est deja l'objet app complet pour une
            // epinglee, donc rien a resoudre ici.
            ArticleMenu {
                readonly property bool posee: menuEpinglee.cible !== null &&
                    Object.prototype.hasOwnProperty.call(
                        bureau.donnees.placees, menuEpinglee.cible.id)
                text: posee ? "Retirer de la Constellation" : "Ajouter a la Constellation"
                onTriggered: {
                    if (posee) {
                        pont.retirerDuBureau(menuEpinglee.cible.id);
                    } else {
                        var p = bureau.placeLibre();
                        pont.placer(menuEpinglee.cible.id, p.x, p.y);
                    }
                    bureau.relire();
                }
            }

            SeparateurMenu { }

            ArticleMenu {
                grave: true
                text: "Retirer de la barre"
                onTriggered: {
                    pont.epingler(menuEpinglee.cible.id, false);
                    bureau.relire();
                }
            }
        }

        Timer {
            id: fermetureMenuEp
            interval: 900
            onTriggered: if (!survolMenuEp.hovered) menuEpinglee.close()
        }

        // ── Le menu d'une icone qui porte plusieurs fenetres ──────────────
        // WINDOWS MONTRE DES VIGNETTES ; ICI, LES TITRES. Une vignette demande
        // de capturer chaque fenetre, ce que kwin reserve a ses propres outils
        // (voir le carnet, 2026-08-25 : « NoAuthorized »). Le titre dit deja
        // laquelle est laquelle — c'est pour cela que la barre de
        // Constellation l'ecrit en toutes lettres.
        Menu {
            id: menuGroupe
            objectName: "menuGroupe"
            property string cle: ""
            readonly property var groupe: barre.groupeDe(cle)
            readonly property var fenetresDuGroupe: {
                var sortie = [];
                if (!groupe) return sortie;
                for (var i = 0; i < barre.ouvertures.length; i++)
                    if (groupe.wids.indexOf(String(barre.ouvertures[i].id)) >= 0)
                        sortie.push(barre.ouvertures[i]);
                return sortie;
            }

            onVisibleChanged: barre.borner()
            onXChanged: barre.borner()
            onYChanged: barre.borner()
            onHeightChanged: barre.borner()
            onWidthChanged: barre.borner()

            function ouvrirPour(c, ex) {
                cle = c;
                popup(Math.max(4, Math.min(barre.width - implicitWidth - 4,
                                           ex - implicitWidth / 2)),
                      -implicitHeight - 6);
            }

            background: Verre {
                radius: Theme.rayonMenu
                implicitWidth: 300
                HoverHandler {
                    id: survolMenuGroupe
                    onHoveredChanged: {
                        if (hovered)
                            fermetureMenuGroupe.stop();
                        else if (menuGroupe.visible)
                            fermetureMenuGroupe.restart();
                    }
                }
            }

            Repeater {
                model: menuGroupe.fenetresDuGroupe
                delegate: ArticleMenu {
                    required property var modelData
                    text: (modelData.active === true && modelData.reduite !== true ? "\u25CF  " : "     ")
                          + barre.titreAffiche(modelData.titre)
                    onTriggered: barre.activation(String(modelData.id), false)
                }
            }
            SeparateurMenu { }
            ArticleMenu {
                enabled: menuGroupe.groupe !== null && menuGroupe.groupe.appId !== ""
                text: "Ouvrir une nouvelle fenetre"
                onTriggered: {
                    bureau.dire(pont.lancer(menuGroupe.groupe.appId));
                    bureau.relire();
                }
            }
        }

        Timer {
            id: fermetureMenuGroupe
            interval: 900
            onTriggered: if (!survolMenuGroupe.hovered) menuGroupe.close()
        }

        // ── LE CALENDRIER, AU CLIC SUR L'HORLOGE ────────────────────────────
        // MEME PATRON QUE « menuEpinglee » : dessine dans la fenetre de la
        // barre, ouvert vers le haut, borne par « pont.bornerBarre ». Pas de
        // « Qt.labs.calendar » sur cette image — verifie le 2026-08-27,
        // aucun module « calendar » sous /usr/lib64/qt6/qml — donc une grille
        // ecrite a la main, sans dependance neuve.
        Popup {
            id: calendrier
            objectName: "calendrier"
            property date moisAffiche: new Date()

            onVisibleChanged: barre.borner()
            onXChanged: barre.borner()
            onYChanged: barre.borner()
            onHeightChanged: barre.borner()
            onWidthChanged: barre.borner()

            function ouvrirPour(ex) {
                // « popup(x, y) » N'EXISTE QUE SUR « Menu », PAS SUR « Popup ».
                // Copie du patron de menuEpinglee sans verifier que c'est une
                // methode de Menu, pas de la classe de base — chaque clic
                // rendait « ReferenceError: popup is not defined » dans le
                // journal, jamais ouvert. « Popup » se positionne par ses
                // propres x/y, puis « open() ».
                moisAffiche = new Date();
                x = Math.max(4, Math.min(barre.width - implicitWidth - 4,
                                         ex - implicitWidth / 2));
                y = -implicitHeight - 6;
                open();
            }

            function moisPrecedent() {
                moisAffiche = new Date(moisAffiche.getFullYear(), moisAffiche.getMonth() - 1, 1);
            }
            function moisSuivant() {
                moisAffiche = new Date(moisAffiche.getFullYear(), moisAffiche.getMonth() + 1, 1);
            }

            readonly property var nomsMois: [
                "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
                "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"
            ]
            readonly property var nomsJours: ["L", "M", "M", "J", "V", "S", "D"]
            readonly property var nomsJoursCourts: [
                "lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."
            ]

            // « HH:mm » evite tout depend sur la locale du systeme pour la
            // date affichee en permanence dans la barre — un format ecrit ici
            // une seule fois, jamais devine par Qt.formatDate selon la langue
            // active. LE MOIS EN TOUTES LETTRES, PAS TRONQUE A TROIS
            // CARACTERES — l'utilisateur l'a trouvee « incomplete » avec
            // « aoû » a la place d'« août ».
            function formaterDateCourte(quand) {
                return nomsJoursCourts[decalageLundi(quand.getDay())] + " "
                     + quand.getDate() + " " + nomsMois[quand.getMonth()].toLowerCase();
            }

            // Lundi = 0 ... Dimanche = 6 : la semaine francaise, pas celle de
            // JavaScript qui commence le dimanche (getDay() rend 0 pour
            // dimanche, 1 pour lundi...).
            function decalageLundi(jourJs) {
                return (jourJs + 6) % 7;
            }

            background: Verre {
                radius: Theme.estAndroid ? 20 : 8
                implicitWidth: 216
            }

            contentItem: Column {
                spacing: 10
                width: 216 - 24

                // ── En-tete : mois, annee, navigation ───────────────────
                Row {
                    width: parent.width
                    height: 22

                    Text {
                        text: "‹"
                        color: Theme.texte2
                        font.pixelSize: 16
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        TapHandler { onTapped: calendrier.moisPrecedent() }
                    }
                    Text {
                        width: parent.width - 48
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.texte
                        font.family: Theme.police
                        font.pixelSize: 12
                        text: calendrier.nomsMois[calendrier.moisAffiche.getMonth()]
                              + " " + calendrier.moisAffiche.getFullYear()
                    }
                    Text {
                        text: "›"
                        color: Theme.texte2
                        font.pixelSize: 16
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        TapHandler { onTapped: calendrier.moisSuivant() }
                    }
                }

                // ── Jours de la semaine ──────────────────────────────────
                Row {
                    width: parent.width
                    Repeater {
                        model: calendrier.nomsJours
                        delegate: Text {
                            required property string modelData
                            width: (216 - 24) / 7
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.texte3
                            font.family: Theme.policeMono
                            font.pixelSize: 10
                            text: modelData
                        }
                    }
                }

                // ── La grille des jours ───────────────────────────────────
                Grid {
                    width: parent.width
                    columns: 7

                    Repeater {
                        // 42 cases = six semaines completes, assez pour tout
                        // mois quel que soit son premier jour.
                        model: 42
                        delegate: Item {
                            required property int index
                            readonly property int premierJour: calendrier.decalageLundi(
                                new Date(calendrier.moisAffiche.getFullYear(),
                                         calendrier.moisAffiche.getMonth(), 1).getDay())
                            readonly property int joursDansMois: new Date(
                                calendrier.moisAffiche.getFullYear(),
                                calendrier.moisAffiche.getMonth() + 1, 0).getDate()
                            readonly property int numero: index - premierJour + 1
                            readonly property bool dansMois: numero >= 1 && numero <= joursDansMois
                            readonly property bool estAujourdhui: dansMois
                                && numero === new Date().getDate()
                                && calendrier.moisAffiche.getMonth() === new Date().getMonth()
                                && calendrier.moisAffiche.getFullYear() === new Date().getFullYear()

                            width: (216 - 24) / 7
                            height: 24

                            Rectangle {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                radius: 10
                                color: estAujourdhui ? Theme.accent : "transparent"
                                visible: dansMois

                                Text {
                                    anchors.centerIn: parent
                                    text: dansMois ? numero : ""
                                    color: estAujourdhui ? Theme.surAccent : Theme.texte2
                                    font.family: Theme.policeMono
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                HoverHandler {
                    id: survolCalendrier
                    onHoveredChanged: {
                        if (hovered)
                            fermetureCalendrier.stop();
                        else if (calendrier.visible)
                            fermetureCalendrier.restart();
                    }
                }
            }
        }

        Timer {
            id: fermetureCalendrier
            interval: 900
            onTriggered: if (!survolCalendrier.hovered) calendrier.close()
        }

    }

    // ══ LA BARRE DE CONSTELLATION — telle qu'elle etait ══════════════════
    Component {
        id: miseConstellation
        Rectangle {
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
                scale: tapNoyau.pressed ? 0.88 : (survolNoyau.hovered ? 1.08 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: tapNoyau.pressed ? Theme.dureePression : Theme.dureeRapide
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler { id: survolNoyau; cursorShape: Qt.PointingHandCursor }
                Rectangle {
                    anchors.centerIn: parent
                    width: tapNoyau.pressed ? 10 : 8
                    height: width
                    radius: width / 2
                    color: "#ffffff"
                    Behavior on width { NumberAnimation { duration: 100 } }
                }
                TapHandler { id: tapNoyau; onTapped: barre.menuDemande() }
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
                        id: itemEp
                        required property string modelData
                        readonly property var app: bureau.appParId(modelData)
                        visible: app !== null
                        width: visible ? 32 : 0
                        height: 32

                        scale: tapEp.pressed ? 0.88 : (survolEp.hovered ? 1.12 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: tapEp.pressed ? Theme.dureePression : Theme.dureeRapide
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: tapEp.pressed ? Theme.verre3 : "transparent"
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

                        // « parent », A L'INTERIEUR DE Connections, VAUT null.
                        // Contrairement a TapHandler/HoverHandler/DragHandler
                        // (des PointerHandler, qui exposent bien leur Item
                        // englobant), Connections est un simple QtObject -- il
                        // n'herite jamais de parent visuel. Mesure au banc :
                        // parent.app levait une TypeError silencieuse a CHAQUE
                        // survol, et barre.nomSurvole n'etait donc jamais ecrit
                        // -- ce mecanisme n'a probablement jamais fonctionne.
                        // itemEp, l'identifiant nomme, resout partout dans ce
                        // fichier, lui.
                        Connections {
                            target: survolEp
                            function onHoveredChanged() {
                                if (survolEp.hovered) {
                                    barre.nomSurvole = itemEp.app ? itemEp.app.nom : "";
                                    barre.centreSurvole = itemEp.mapToItem(
                                        null, itemEp.width / 2, 0).x;
                                } else if (barre.nomSurvole ===
                                           (itemEp.app ? itemEp.app.nom : "")) {
                                    barre.nomSurvole = "";
                                }
                            }
                        }

                        // Rebond de lancement style macOS Dock
                        SequentialAnimation {
                            id: animRebondEp
                            NumberAnimation { target: itemEp; property: "y"; to: -8; duration: 120; easing.type: Easing.OutQuad }
                            NumberAnimation { target: itemEp; property: "y"; to: 0; duration: 220; easing.type: Easing.OutBounce }
                        }

                        TapHandler {
                            id: tapEp
                            onTapped: {
                                animRebondEp.restart();
                                bureau.dire(pont.lancer(parent.app.id));
                                pont.effacerBadge(parent.app.id);
                                bureau.relire();
                            }
                        }

                        // ── LE CLIC DROIT, QUI N'EXISTAIT PAS NON PLUS ICI ─────
                        // Releve par l'utilisateur le 2026-08-27 (reponse 15) :
                        // « aucuns clic droit ne fonctionnent sur les apps
                        // epingles en bas ». Meme trou que celui ferme le
                        // 2026-08-26 sur les fenetres ouvertes (menuFenetre,
                        // plus bas) — jamais comble ici.
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: function (point) {
                                menuEpinglee.ouvrirPour(
                                    parent.app,
                                    parent.mapToItem(null, point.position.x, 0).x);
                            }
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
                anchors.right: horlogeEtDate.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                clip: true

                Repeater {
                    // Nomme pour que build_files/verifier-tuiles.py le retrouve et
                    // compte ses delegues : c'est le seul temoin fiable qu'une
                    // nouvelle de kwin ne reconstruit pas toutes les tuiles.
                    objectName: "tuilesOuvertes"
                    model: modeleOuvertures
                    delegate: Rectangle {
                        id: tuile
                        // Les roles du ListModel arrivent en proprietes requises :
                        // c'est ce qui laisse une tuile vivre pendant que sa fenetre
                        // change de titre ou de focus.
                        required property int index
                        required property string wid
                        required property string classe
                        required property string titre
                        required property bool active
                        required property bool reduite
                        // Par identifiant d'abord (le cas courant : la classe
                        // d'une fenetre est presque toujours l'id de son
                        // .desktop) — par classe partagee ensuite, pour les
                        // lanceurs qui reutilisent le meme moteur qu'un autre
                        // (S Web sur Vivaldi). Voir appParClasse.
                        readonly property var app: bureau.appParId(tuile.classe)
                                                    || bureau.appParClasse(tuile.classe)

                        // La largeur se partage, avec un plancher et un plafond :
                        // douze fenetres ouvertes ne doivent pas rendre les titres
                        // illisibles, et deux ne doivent pas occuper l'ecran.
                        width: Math.max(46, Math.min(210,
                            (ouvertes.width - (barre.ouvertures.length - 1) * 6)
                            / Math.max(1, barre.ouvertures.length)))
                        // LES TUILES GLISSENT AU LIEU DE SAUTER quand une fenetre
                        // s'ouvre ou se ferme : les voisines se partagent la place
                        // en une fraction de seconde, comme une riviere qui se
                        // repartit, plutot que de se redessiner d'un coup.
                        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        height: 34
                        radius: 8

                        // Une tuile nouvelle apparait en fondu.
                        opacity: 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Component.onCompleted: opacity = 1

                        scale: tapF.pressed ? 0.96 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: tapF.pressed ? Theme.dureePression : Theme.dureeRapide
                                easing.type: Easing.OutCubic
                            }
                        }

                        color: tapF.pressed ? Theme.verre3
                             : (tuile.active ? Theme.verre2
                                                 : (survolF.hovered ? Qt.rgba(1,1,1,0.045)
                                                                    : "transparent"))
                        border.color: tapF.pressed ? Theme.bordVif
                                    : (tuile.active ? Theme.bord : "transparent")
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }

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
                            opacity: tuile.active ? 1 : 0.55
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
                                    // « tuile.app », PAS UNE CHAINE DE « parent »
                                    // — nettoyage du 2026-10-20. Trois sauts de
                                    // parent (Image -> Item -> Row -> tuile)
                                    // fonctionnaient, mais casseraient en
                                    // silence (icones vides, sans avertissement)
                                    // au premier Item insere entre eux. L'id du
                                    // delegue, lui, resout partout dans ce bloc.
                                    source: tuile.app ? (tuile.app.img || "") : ""
                                    sourceSize.width: 34; sourceSize.height: 34
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: source !== "" && status === Image.Ready
                                }
                                Glyphe {
                                    anchors.fill: parent
                                    nom: tuile.app ? (tuile.app.ico || "i-boite") : "i-boite"
                                    couleur: Theme.texte2
                                    visible: !icoF.visible
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 17 - 7 - 18
                                text: barre.titreAffiche(tuile.titre)
                                color: tuile.active ? Theme.texte : Theme.texte2
                                font.family: Theme.police
                                font.pixelSize: 12
                                // Une fenetre reduite se lit en italique : c'est le
                                // seul etat qu'on ne devine pas en regardant l'ecran.
                                font.italic: tuile.reduite
                                elide: Text.ElideRight
                                visible: parent.parent.width > 90
                            }
                        }

                        HoverHandler { id: survolF; cursorShape: Qt.PointingHandCursor }
                        ToolTip.visible: survolF.hovered && width <= 90
                        ToolTip.text: barre.titreAffiche(tuile.titre)
                        ToolTip.delay: 400

                        TapHandler {
                            id: tapF
                            onTapped: barre.activation(tuile.wid, tuile.active)
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
                                    { id: tuile.wid },
                                    parent.mapToItem(null, point.position.x, 0).x);
                            }
                        }
                    }
                }
            }


            // ── L'heure ET LA DATE, TOUJOURS LES DEUX ───────────────────────────
            // Demande de l'utilisateur le 2026-08-27 : « je veux voir la date
            // tout le temps », pas seulement au clic. Deux lignes compactes —
            // l'heure au-dessus, la date en dessous, plus petite — dans le meme
            // espace qu'occupait l'heure seule.
            Column {
                id: horlogeEtDate
                // LARGEUR EXPLICITE, PAS DES ANCRES SUR LES ENFANTS — un Column
                // positionne ses enfants lui-meme (x=0, empiles verticalement) ;
                // « anchors.right » dessus est ignore en silence, aucun
                // avertissement pour le dire. C'est la MEME famille de piege que
                // l'ancrage casse trouve en testant ce correctif : deux enfants
                // de largeurs differentes se seraient retrouves alignes a
                // gauche l'un sous l'autre plutot qu'alignes a droite comme
                // prevu. La largeur se fixe une fois, sur le plus large des deux.
                width: Math.max(horloge.implicitWidth, dateDuJour.implicitWidth)
                anchors.right: etoileOption.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                scale: tapHorloge.pressed ? 0.94 : (survolHorloge.hovered ? 1.05 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: tapHorloge.pressed ? Theme.dureePression : Theme.dureeRapide
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler { id: survolHorloge; cursorShape: Qt.PointingHandCursor }

                Text {
                    id: horloge
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    color: Theme.texte
                    font.family: Theme.policeMono
                    font.pixelSize: 12
                    text: barre.heure
                }
                Text {
                    id: dateDuJour
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    // TEXTE2, PAS TEXTE3 — demande de l'utilisateur le
                    // 2026-08-28 : « la date est pratiquement invisible ». A
                    // 34 % d'opacite (texte3) sur fond sombre, a 9 px, elle
                    // l'etait. texte2 (62 %) et 10 px restent plus discrets que
                    // l'heure sans disparaitre.
                    color: Theme.texte2
                    font.family: Theme.policeMono
                    font.pixelSize: 10
                    text: barre.dateCourte
                }

                // UN CLIC GAUCHE OUVRE LE CALENDRIER — demande de l'utilisateur,
                // meme geste. HoverHandler existe deja partout dans ce fichier
                // pour le survol ; ici c'est un TapHandler, comme les etoiles et
                // les epinglees.
                TapHandler {
                    id: tapHorloge
                    acceptedButtons: Qt.LeftButton
                    onTapped: calendrier.ouvrirPour(
                        horlogeEtDate.x + horlogeEtDate.width / 2)
                }
            }

            // ── L'étoile option (réglages rapides) ──────────────────────────────
            // Placée à côté de l'heure, pile sous la colonne des réglages.
            // Un clic fait monter la barre de réglages au-dessus de la barre des tâches.
            //
            // SA COULEUR COULE QUAND ON L'APPROCHE, PAS TOUT LE TEMPS. Elle
            // parcourait bleu → rouge → vert → jaune en boucle infinie, sans
            // condition, pour toute la vie de la session. Or la barre est TOUJOURS
            // visible, et cette couleur alimente quatre liaisons ET un Glyphe — un
            // Canvas, repeint et renvoye au GPU a CHAQUE changement de couleur :
            // soixante repeints par seconde, jour et nuit, pour une etoile de 32
            // pixels que personne ne regarde. Mesure du 2026-09-19 sur le banc de
            // fluidite : c'est le plancher de 3,1 % de CPU qui restait meme avec un
            // jeu en plein ecran.
            //
            // La phase (0 a 4, une teinte par unite) est UNE seule propriete animee,
            // en pause tant que rien ne la regarde : une animation en pause n'est
            // pas cadencee, donc le compositeur n'est plus reveille. Elle repart la
            // ou elle s'etait arretee, sans saut. Le point de depart est tire au sort
            // — comme les couleurs de la barre laterale a chaque ouverture — pour
            // que l'etoile au repos ne soit pas toujours bleue.
            Rectangle {
                id: etoileOption
                width: 32
                height: 32
                radius: 16
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter

                readonly property var teintes: [Theme.windows, Theme.linux, Theme.android, Theme.fichier]
                readonly property real depart: Math.random() * 4
                property real phase: 0
                readonly property color teinteEtoile: {
                    var p = (phase + depart) % 4;
                    var i = Math.floor(p);
                    var t = p - i;
                    var a = teintes[i], b = teintes[(i + 1) % 4];
                    return Qt.rgba(a.r + (b.r - a.r) * t,
                                   a.g + (b.g - a.g) * t,
                                   a.b + (b.b - a.b) * t, 1);
                }

                NumberAnimation on phase {
                    from: 0; to: 4; duration: 10000
                    loops: Animation.Infinite
                    running: true
                    paused: !(survolOption.hovered || barre.reglagesOuverts)
                }

                color: tapOption.pressed ? Qt.rgba(teinteEtoile.r, teinteEtoile.g, teinteEtoile.b, 0.28)
                                         : (barre.reglagesOuverts ? Qt.rgba(teinteEtoile.r, teinteEtoile.g, teinteEtoile.b, 0.20)
                                                                  : (survolOption.hovered ? Qt.rgba(teinteEtoile.r, teinteEtoile.g, teinteEtoile.b, 0.14)
                                                                                          : Qt.rgba(teinteEtoile.r, teinteEtoile.g, teinteEtoile.b, 0.05)))
                border.color: tapOption.pressed ? teinteEtoile
                                                : (barre.reglagesOuverts ? teinteEtoile
                                                                         : (survolOption.hovered ? Qt.rgba(teinteEtoile.r, teinteEtoile.g, teinteEtoile.b, 0.60)
                                                                                                 : Qt.rgba(teinteEtoile.r, teinteEtoile.g, teinteEtoile.b, 0.22)))
                border.width: 1
                antialiasing: true

                scale: tapOption.pressed ? 0.90 : ((survolOption.hovered || barre.reglagesOuverts) ? 1.08 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: tapOption.pressed ? Theme.dureePression : Theme.dureeRapide
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler {
                    id: survolOption
                    cursorShape: Qt.PointingHandCursor
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: "transparent"
                    border.color: etoileOption.teinteEtoile
                    border.width: 1.5
                    opacity: barre.reglagesOuverts ? 0.95 : (survolOption.hovered ? 0.80 : 0.45)
                    Behavior on opacity { NumberAnimation { duration: Theme.dureeRapide } }
                }

                Glyphe {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    nom: "i-etincelle"
                    couleur: etoileOption.teinteEtoile
                }

                TapHandler {
                    id: tapOption
                    acceptedButtons: Qt.LeftButton
                    onTapped: barre.reglagesDemandes()
                }
            }
        }
    }

    // ══ L'ICONE D'UNE APPLICATION DANS LA BARRE — Windows et Android ═══════
    // UN SEUL DELEGUE POUR LES DEUX BARRES : la forme change avec le theme,
    // les gestes non. Ses roles viennent de « modeleGroupes », mis a jour sur
    // place — une nouvelle de kwin ne le recree jamais.
    Component {
        id: delegueTache
        Item {
            id: tache
            required property string cle
            required property string appId
            required property int nb
            required property bool active
            required property bool reduite
            required property string titre
            required property bool epinglee
            readonly property var app: appId !== "" ? bureau.appParId(appId) : null
            // Une fenetre qu'aucune application ne revendique : le glyphe d'une
            // fenetre, plutot qu'une boite vide.
            readonly property var appMontree: app ? app : ({ ico: "i-fenetre", src: "linux", img: "" })

            width: Theme.estAndroid ? 42 : 44
            height: Theme.estAndroid ? 42 : 44

            // ── Windows : le carre arrondi qui s'allume au survol ──
            Rectangle {
                visible: !Theme.estAndroid
                anchors.fill: parent
                anchors.margins: 2
                radius: 4
                color: tapTache.pressed ? Theme.verre3
                     : ((tache.active || survolTache.hovered) ? Theme.verre2 : "transparent")
                border.width: tache.active ? 1 : 0
                border.color: Theme.bord
                Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
            }
            // ── Android : la pastille ronde ──
            Rectangle {
                visible: Theme.estAndroid
                anchors.centerIn: parent
                width: 36; height: 36; radius: 18
                color: tache.active ? Theme.palette.primaryContainer
                                    : (survolTache.hovered ? Theme.verre2 : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
            }

            IconeApp {
                id: icoTache
                // Le rebond de lancement anime « saut », jamais l'ancrage
                // lui-meme : une animation sur « anchors.* » n'est pas garantie.
                property real saut: 0
                anchors.centerIn: parent
                anchors.verticalCenterOffset: (Theme.estAndroid ? 0 : -1) + saut
                taille: Theme.estAndroid ? 26 : 24
                app: tache.appMontree
                // Une fenetre qu'aucune application ne revendique n'a pas de
                // monde connu : la couleur du texte, jamais le rouge de Linux.
                couleur: Theme.estAndroid ? Theme.palette.primary
                       : (tache.app ? Theme.teinte(tache.app.src || "linux") : Theme.texte2)
                scale: tapTache.pressed ? 0.84 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.dureePression; easing.type: Theme.courbe } }
            }

            // LE TRAIT « OUVERT ». Gris et court pour une application qui tourne,
            // long et a l'accent pour celle qu'on regarde — la regle de Windows,
            // et le point de Material sous l'icone d'Android.
            Rectangle {
                visible: tache.nb > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.estAndroid ? -3 : 3
                width: Theme.estAndroid ? (tache.active ? 12 : 5) : (tache.active ? 16 : 6)
                height: Theme.estAndroid ? 4 : 3
                radius: height / 2
                color: tache.active ? Theme.accent : (Theme.estAndroid ? Theme.palette.onSurfaceVariant : Theme.texte3)
                Behavior on width { NumberAnimation { duration: Theme.dureeNormale; easing.type: Theme.courbe } }
            }

            // Le badge de notification, comme sur l'etoile.
            Rectangle {
                visible: tache.app !== null && (tache.app.badge || 0) > 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.estAndroid ? 1 : 5
                width: 9; height: 9; radius: 4.5
                color: Theme.estAndroid ? Theme.palette.tertiary : Theme.accent
            }

            HoverHandler { id: survolTache; cursorShape: Qt.PointingHandCursor }
            // « parent » est nul dans un Connections : on nomme l'icone. Voir
            // le meme piege, plus bas, sur les epinglees de Constellation.
            Connections {
                target: survolTache
                function onHoveredChanged() {
                    var nom = tache.nb === 1 ? barre.titreAffiche(tache.titre)
                                             : (tache.app ? tache.app.nom : barre.titreAffiche(tache.titre));
                    if (survolTache.hovered) {
                        barre.nomSurvole = nom;
                        barre.centreSurvole = tache.mapToItem(null, tache.width / 2, 0).x;
                    } else if (barre.nomSurvole === nom) {
                        barre.nomSurvole = "";
                    }
                }
            }

            SequentialAnimation {
                id: rebondTache
                NumberAnimation { target: icoTache; property: "saut"; to: -6; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: icoTache; property: "saut"; to: 0; duration: 240; easing.type: Easing.OutBounce }
            }

            TapHandler {
                id: tapTache
                onTapped: {
                    if (tache.nb === 0) rebondTache.restart();
                    barre.nomSurvole = "";
                    barre.cliquerGroupe(tache.cle, tache.mapToItem(bande, tache.width / 2, 0).x);
                }
            }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: barre.menuDuGroupe(tache.cle, tache.mapToItem(bande, tache.width / 2, 0).x)
            }
        }
    }

    // ══ LA BARRE DE WINDOWS 11 ══════════════════════════════════════════════
    // Centree : Demarrer, la recherche, puis les applications. A droite, les
    // icones qui ouvrent les reglages rapides, l'heure et la date, et le coin
    // « afficher le bureau ». Sous le tout, le Mica : le fond d'ecran flou,
    // voile de la teinte du mode — voir FondFloute.qml.
    Component {
        id: miseWindows
        Item {
            id: miseW

            FondFloute {
                anchors.fill: parent
                ox: 0
                oy: Screen.height - barre.hauteur
                ecranL: Screen.width
                ecranH: Screen.height
            }
            Rectangle { anchors.fill: parent; color: Theme.barreTeinte }
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.sombre ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
            }

            Row {
                id: centreW
                anchors.centerIn: parent
                spacing: 2

                // ── Demarrer : la marque de S, jamais le logo d'un autre ──
                Rectangle {
                    id: demarrerW
                    width: 44; height: 44
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 4
                    color: tapDemarrer.pressed ? Theme.verre3 : (survolDemarrer.hovered ? Theme.verre2 : "transparent")
                    Canvas {
                        id: marque
                        anchors.centerIn: parent
                        width: 26; height: 26
                        scale: tapDemarrer.pressed ? 0.84 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.dureePression; easing.type: Theme.courbe } }
                        property color haut: Theme.sombre ? Qt.lighter(Theme.accent, 1.15) : Qt.lighter(Theme.accent, 1.45)
                        property color bas: Theme.accent
                        onHautChanged: requestPaint()
                        onBasChanged: requestPaint()
                        onPaint: {
                            var g = getContext("2d");
                            g.reset();
                            var e = width / 24;
                            g.scale(e, e);
                            var d = g.createLinearGradient(0, 3, 0, 21);
                            d.addColorStop(0, String(haut));
                            d.addColorStop(1, String(bas));
                            g.strokeStyle = d;
                            g.lineWidth = 3.1;
                            g.lineCap = "round";
                            g.lineJoin = "round";
                            g.beginPath();
                            g.moveTo(17.4, 6.9);
                            g.bezierCurveTo(16.1, 5.0, 14.2, 4.2, 12.0, 4.2);
                            g.bezierCurveTo(8.9, 4.2, 6.9, 5.9, 6.9, 8.3);
                            g.bezierCurveTo(6.9, 10.9, 9.4, 11.6, 12.0, 12.2);
                            g.bezierCurveTo(14.8, 12.8, 17.3, 13.8, 17.3, 16.4);
                            g.bezierCurveTo(17.3, 18.7, 15.1, 20.0, 12.0, 20.0);
                            g.bezierCurveTo(9.6, 20.0, 7.6, 19.0, 6.6, 17.2);
                            g.stroke();
                        }
                    }
                    HoverHandler { id: survolDemarrer; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: tapDemarrer; onTapped: barre.menuDemande() }
                }

                // ── La recherche ──
                Rectangle {
                    id: rechercheW
                    width: 208; height: 36
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 18
                    color: Theme.sombre ? Qt.rgba(1, 1, 1, survolRecherche.hovered ? 0.10 : 0.06)
                                        : Qt.rgba(1, 1, 1, survolRecherche.hovered ? 0.95 : 0.72)
                    border.width: 1
                    border.color: Theme.bord
                    Glyphe {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        nom: "i-recherche"
                        couleur: Theme.texte2
                    }
                    Text {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Rechercher"
                        color: Theme.texte2
                        font.family: Theme.police
                        font.pixelSize: 13
                    }
                    HoverHandler { id: survolRecherche; cursorShape: Qt.IBeamCursor }
                    TapHandler { onTapped: barre.rechercheDemandee() }
                }

                Item { width: 6; height: 1 }

                Repeater {
                    objectName: "groupesBarre"
                    model: modeleGroupes
                    delegate: delegueTache
                }
            }

            // ── A droite : reglages rapides, heure, coin du bureau ──
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Rectangle {
                    id: iconesW
                    width: rangIcones.implicitWidth + 22
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 4
                    color: barre.reglagesOuverts ? Theme.verre3
                         : (tapIcones.pressed ? Theme.verre3 : (survolIcones.hovered ? Theme.verre2 : "transparent"))
                    Row {
                        id: rangIcones
                        anchors.centerIn: parent
                        spacing: 10
                        Glyphe { width: 16; height: 16; nom: "i-reseau"; couleur: Theme.texte }
                        Glyphe { width: 16; height: 16; nom: "i-son"; couleur: Theme.texte }
                    }
                    HoverHandler { id: survolIcones; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: tapIcones; onTapped: barre.reglagesDemandes() }
                }

                Rectangle {
                    id: horlogeW
                    width: colHeure.implicitWidth + 22
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 4
                    color: calendrier.visible ? Theme.verre3
                         : (tapHeure.pressed ? Theme.verre3 : (survolHeure.hovered ? Theme.verre2 : "transparent"))
                    Column {
                        id: colHeure
                        anchors.centerIn: parent
                        Text {
                            anchors.right: parent.right
                            text: barre.heure
                            color: Theme.texte
                            font.family: Theme.police
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.right: parent.right
                            text: barre.dateNumerique
                            color: Theme.texte
                            font.family: Theme.police
                            font.pixelSize: 12
                        }
                    }
                    HoverHandler { id: survolHeure; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: tapHeure
                        onTapped: calendrier.ouvrirPour(horlogeW.mapToItem(bande, horlogeW.width / 2, 0).x)
                    }
                }

                // LE COIN « AFFICHER LE BUREAU » : une lame de quelques pixels
                // tout au bout de la barre, comme chez Windows.
                Item {
                    width: 12
                    height: miseW.height
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1; height: 18
                        color: Theme.bordVif
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: barre.bureauDemande() }
                }
            }
        }
    }

    // ══ LA BARRE D'UNE TABLETTE ANDROID ════════════════════════════════════
    // Pas de bande pleine : un lanceur rond a gauche, un dock en pilule au
    // centre qui flotte sur le fond d'ecran, et l'etat (date, heure, reseau)
    // a droite — l'etagere des grands ecrans de Material You.
    Component {
        id: miseAndroid
        Item {
            id: miseA

            // ── Les trois boutons de navigation de la tablette ──
            // Retour, accueil, applications ouvertes — la barre d'Android. Des
            // formes simples, pas des icones : le triangle, le rond et le carre
            // sont la navigation, partout sur une tablette.
            Row {
                id: navA
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // Retour
                Rectangle {
                    id: navRetour
                    width: 40; height: 40; radius: 20
                    color: tapRetour.pressed ? Theme.verre3
                         : (survolRetour.hovered ? Theme.verre2 : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
                    Text {
                        anchors.centerIn: parent
                        text: "◀"
                        color: Theme.palette.onSurface
                        font.pixelSize: 17
                    }
                    HoverHandler { id: survolRetour; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: tapRetour; onTapped: barre.retourDemande() }
                }

                // Accueil (le rond plein)
                Rectangle {
                    id: navAccueil
                    width: 40; height: 40; radius: 20
                    color: tapAccueil.pressed ? Theme.verre3
                         : (survolAccueil.hovered ? Theme.verre2 : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 16; height: 16; radius: 8
                        color: Theme.palette.onSurface
                    }
                    HoverHandler { id: survolAccueil; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: tapAccueil; onTapped: barre.accueilDemande() }
                }

                // Applications ouvertes (le carre)
                Rectangle {
                    id: navRecents
                    width: 40; height: 40; radius: 20
                    color: tapRecents.pressed ? Theme.verre3
                         : (survolRecents.hovered ? Theme.verre2 : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14; height: 14; radius: 3
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.palette.onSurface
                    }
                    HoverHandler { id: survolRecents; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: tapRecents; onTapped: barre.recentsDemande() }
                }
            }

            Rectangle {
                id: dockA
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(60, rangDock.implicitWidth + 14)
                height: 48
                radius: 24
                color: Theme.palette.surfaceContainer
                Behavior on width { NumberAnimation { duration: Theme.dureeNormale; easing.type: Theme.courbe } }
                Ombre { z: -1; anchors.fill: parent; anchors.margins: -marge; marge: 18; rayon: 24; flou: 12; decalageY: 3 }
                Row {
                    id: rangDock
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        objectName: "groupesBarre"
                        model: modeleGroupes
                        delegate: delegueTache
                    }
                }
            }

            Rectangle {
                id: etatA
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: zoneHeure.width + zoneIcones.width + 8
                height: 40
                radius: 20
                color: Theme.palette.surfaceContainer
                Ombre { z: -1; anchors.fill: parent; anchors.margins: -marge; marge: 16; rayon: 20; flou: 10; decalageY: 2 }

                // La date et l'heure ouvrent le calendrier...
                Rectangle {
                    id: zoneHeure
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: rangHeure.implicitWidth + 24
                    height: 32
                    radius: 16
                    color: calendrier.visible ? Theme.palette.secondaryContainer
                         : (survolZoneHeure.hovered ? Theme.verre2 : "transparent")
                    Row {
                        id: rangHeure
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: barre.dateCourte
                            color: Theme.palette.onSurfaceVariant
                            font.family: Theme.police
                            font.pixelSize: 13
                        }
                        Text {
                            text: barre.heure
                            color: Theme.palette.onSurface
                            font.family: Theme.police
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }
                    HoverHandler { id: survolZoneHeure; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: calendrier.ouvrirPour(zoneHeure.mapToItem(bande, zoneHeure.width / 2, 0).x) }
                }
                // ... le reseau et le son ouvrent les reglages rapides.
                Rectangle {
                    id: zoneIcones
                    anchors.left: zoneHeure.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: rangIconesA.implicitWidth + 24
                    height: 32
                    radius: 16
                    color: barre.reglagesOuverts ? Theme.palette.primaryContainer
                         : (survolZoneIcones.hovered ? Theme.verre2 : "transparent")
                    Row {
                        id: rangIconesA
                        anchors.centerIn: parent
                        spacing: 10
                        Glyphe { width: 16; height: 16; nom: "i-reseau"; couleur: Theme.palette.onSurface }
                        Glyphe { width: 16; height: 16; nom: "i-son"; couleur: Theme.palette.onSurface }
                    }
                    HoverHandler { id: survolZoneIcones; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: barre.reglagesDemandes() }
                }
            }
        }
    }
}
