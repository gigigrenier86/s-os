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

    // ── LA VEILLE DES FENETRES ────────────────────────────────────────────
    // Ce que la barre affiche du reglage. La valeur de depart est celle du
    // pont — « geler » — et elle est corrigee des que le pont parle, ce qu'il
    // fait a la premiere nouvelle du compositeur.
    property string veilleMode: (typeof fenetres !== "undefined" && fenetres)
                                ? fenetres.mode() : "geler"
    property int fenetresInactives: 0

    visible: true
    visibility: Window.FullScreen
    color: Theme.espace
    title: "Constellation"

    // --- L'etat, tel que le noyau le rend ---------------------------------
    property var donnees: ({ etoiles: [], usage: ({}), placees: ({}), epingles: [], fichiers: [] })
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
        // Les fichiers sont dans une liste a part — sinon ils monteraient dans
        // le menu Demarrer — mais le clic droit, lui, doit pouvoir les
        // retrouver par leur identifiant comme n'importe quelle etoile.
        var f = donnees.fichiers || [];
        for (var j = 0; j < f.length; j++)
            if (f[j].id === ident) return f[j];
        return null;
    }

    readonly property bool estFichier: false
    function estUnFichier(ident) { return String(ident).indexOf("fichier:") === 0; }

    // UNE ETOILE GROSSIT AVEC L'USAGE, et l'echelle est logarithmique : sans
    // cela, une application lancee cent fois ecraserait tout le ciel. Bornee
    // 30 a 60 pixels — la hierarchie se voit, rien ne devient illisible.
    function tailleDe(app) {
        // UN FICHIER NE GROSSIT PAS AVEC L'USAGE. L'echelle logarithmique dit
        // « ce logiciel sert souvent » ; appliquee a un fichier dont le
        // compteur vaut toujours zero, elle rendrait 30 px pour tous — les
        // etoiles jaunes seraient les plus petites du ciel alors que ce sont
        // celles qu'on vient d'y poser.
        if ((app.src || "") === "fichier") return Theme.sphere;
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
        // LE BUREAU SE DECLARE AVANT DE FAIRE QUOI QUE CE SOIT. Les delegues du
        // menu ne peuvent pas l'atteindre par son identifiant — voir Session.qml.
        Session.bureau = bureau;
        Session.menu = menuDemarrer;
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
            // Meme garde et meme temoin que les vignettes : c'est l'autre
            // appelant de Fonds.js, et rien ne dit lequel des deux a produit
            // les erreurs du 2026-08-25.
            if (!isFinite(width) || !isFinite(height) || width <= 0 || height <= 0) {
                console.warn("fond : dimensions refusees " + width + "x" + height);
                return;
            }
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

        // LE CLIC DROIT SUR LE VIDE NE FAISAIT RIEN, ET C'EST LA MOITIE
        // MANQUANTE DU GESTE. Le menu du 2026-08-24 ne s'ouvrait que sur une
        // etoile ; sur le fond, il ne se passait rien — alors que c'est
        // exactement la ou l'on cherche « creer un dossier » ou « ouvrir un
        // terminal ici ».
        //
        // IL EST POSE SUR LE CIEL ET NON SUR LE FOND parce que le ciel couvre
        // toute la scene. Les etoiles gardent la main : leur propre gestionnaire
        // de bouton droit consomme l'evenement avant qu'il ne remonte ici.
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: function (evenement) {
                // UNE ETOILE NE « GARDE PAS LA MAIN » TOUTE SEULE — c'etait
                // une hypothese, pas une mesure, et elle etait fausse.
                // Releve par l'utilisateur le 2026-08-28 : le clic droit sur
                // une etoile ouvrait quand meme ce menu-ci, exactement les
                // memes options que sur le fond. Ce TapHandler ecoute tout
                // le ciel, etoiles comprises, puisqu'une etoile est un
                // DESCENDANT du ciel — « evenement.accepted » sur le
                // TapHandler de l'etoile ne l'empeche pas de s'activer aussi.
                // On verifie donc soi-meme ce qu'il y a sous le point, plutot
                // que de compter sur une consommation d'evenement qui ne
                // marchait pas.
                var cible = ciel.childAt(evenement.position.x, evenement.position.y);
                if (cible && cible.app !== undefined) return;
                var p = ciel.mapToItem(null, evenement.position.x,
                                       evenement.position.y);
                menuDuFond.ouvrirA(p.x, p.y);
            }
        }

        // ── LE GLISSEMENT DE SELECTION, DEMANDE LE 2026-08-27 (reponse 16) ──
        // « clic gauche et glisser pour selectionner des icones », comme sur
        // n'importe quel bureau.
        //
        // « LES ETOILES GARDENT LA MAIN » ETAIT UNE HYPOTHESE, PAS UNE
        // MESURE — ET ELLE ETAIT FAUSSE. Trouve le 2026-08-28, apres que
        // l'utilisateur a mesure le meme defaut sur le clic droit : ce
        // DragHandler est pose sur « ciel », qui couvre TOUT — y compris les
        // etoiles, ses descendantes. Un glissement demarre sur une etoile
        // active donc CE poignee-ci EN MEME TEMPS que le DragHandler de
        // l'etoile (Astre.qml), et « ciel.choisirDans(null) » videnge la
        // selection au moment meme ou l'on tente de deplacer un groupe.
        // Mesure par l'utilisateur : « seulement celle que je deplace
        // bouge » — la selection etait deja vide quand onDeplacee lisait
        // « choisi ». On verifie donc explicitement, au depart du
        // glissement, ce qu'il y a sous le doigt.
        DragHandler {
            id: cadreGlissement
            target: null
            acceptedButtons: Qt.LeftButton
            property point depart: Qt.point(0, 0)
            // Vrai si CE glissement a demarre sur une etoile : dans ce cas,
            // toute la logique de selection ci-dessous se tait, au depart
            // comme a l'arrivee — c'est un deplacement, pas une selection.
            property bool surUneEtoile: false
            onActiveChanged: {
                if (active) {
                    depart = centroid.position;
                    var cible = ciel.childAt(depart.x, depart.y);
                    surUneEtoile = cible !== null && cible.app !== undefined;
                    if (!surUneEtoile) ciel.choisirDans(null);
                } else if (!surUneEtoile) {
                    ciel.choisirDans({
                        x: Math.min(depart.x, centroid.position.x),
                        y: Math.min(depart.y, centroid.position.y),
                        w: Math.abs(centroid.position.x - depart.x),
                        h: Math.abs(centroid.position.y - depart.y)
                    });
                }
            }
        }

        Rectangle {
            visible: cadreGlissement.active && !cadreGlissement.surUneEtoile
            x: Math.min(cadreGlissement.depart.x, cadreGlissement.centroid.position.x)
            y: Math.min(cadreGlissement.depart.y, cadreGlissement.centroid.position.y)
            width: Math.abs(cadreGlissement.centroid.position.x - cadreGlissement.depart.x)
            height: Math.abs(cadreGlissement.centroid.position.y - cadreGlissement.depart.y)
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Theme.bordVif
        }

        // Choisit (ou vide, si « rect » est nul) les etoiles que le cadre
        // touche. Vider AU DEPART du glissement plutot qu'a la fin : un
        // simple clic sur le vide doit deselectionner tout, comme sur
        // n'importe quel bureau — pas seulement un glissement qui aboutit.
        function choisirDans(rect) {
            for (var i = 0; i < ciel.children.length; i++) {
                var c = ciel.children[i];
                if (c.app === undefined) continue;
                c.choisi = rect ? (c.x < rect.x + rect.w && c.x + c.width > rect.x &&
                                    c.y < rect.y + rect.h && c.y + c.height > rect.y)
                                : false;
            }
        }

        Repeater {
            objectName: "repeaterCiel"
            model: {
                // DEUX REGLES OPPOSEES DANS LE MEME CIEL, ET C'EST VOULU.
                //
                // Une APPLICATION n'y monte que si on l'y a posee. Le reste
                // vit dans le menu : un bureau qui affiche cinquante-deux
                // icones n'est pas un bureau, c'est une liste.
                //
                // Un FICHIER y est parce qu'il est dans le dossier. C'est la
                // regle inverse, et c'est celle de tous les bureaux depuis
                // trente ans — s'en ecarter voudrait dire qu'un fichier
                // depose sur le bureau ne s'y verrait pas.
                var sortie = [];
                var places = bureau.donnees.placees;

                for (var ident in places) {
                    // Un fichier place a la main est servi par la boucle
                    // suivante, avec sa position. Le laisser passer ici aussi
                    // le dessinerait DEUX FOIS, l'un sur l'autre.
                    if (bureau.estUnFichier(ident)) continue;
                    var a = bureau.appParId(ident);
                    if (a) sortie.push({ app: a, pos: places[ident] });
                }

                // LA GRILLE DE DEPART. Un fichier qu'on n'a jamais deplace se
                // range comme dans n'importe quel gestionnaire : en colonnes,
                // depuis le coin haut-gauche. L'ordre vient du noyau — dossiers
                // d'abord, puis par nom — donc il ne bouge pas d'une session a
                // l'autre.
                var fs = bureau.donnees.fichiers || [];
                var largeur = ciel.width > 0 ? ciel.width : 1920;
                var hauteur = (ciel.height - 70) > 0 ? (ciel.height - 70) : 1010;
                var marge = 70, pasX = 108, pasY = 100;
                var parColonne = Math.max(1, Math.floor((hauteur - marge) / pasY));
                var col = 0, lig = 0;

                for (var i = 0; i < fs.length; i++) {
                    var f = fs[i];
                    // Un fichier epingle a la barre depuis un autre dossier est
                    // dans la liste pour que la barre le retrouve — il n'a rien
                    // a faire au ciel.
                    if ((f.bureau || 0) === 0) continue;
                    var p = places[f.id];
                    if (!p) {
                        p = { x: (marge + col * pasX) / largeur,
                              y: (marge + lig * pasY) / hauteur };
                        lig += 1;
                        if (lig >= parColonne) { lig = 0; col += 1; }
                    }
                    sortie.push({ app: f, pos: p });
                }
                return sortie;
            }

            delegate: Astre {
                required property var modelData
                app: modelData.app
                diametre: bureau.tailleDe(modelData.app)
                // LE NOM D'UN FICHIER EST TOUJOURS VISIBLE. Une application se
                // reconnait a son icone ; deux captures d'ecran du meme jour
                // portent la meme, et sans leur nom rien ne les distingue.
                montrerNom: bureau.nomsToujours
                            || (modelData.app.src || "") === "fichier"
                x: modelData.pos.x * ciel.width - diametre / 2
                y: modelData.pos.y * (ciel.height - 70) - diametre / 2

                // UN GLISSEMENT DETRUIT LES DEUX LIAISONS CI-DESSUS, ET IL
                // FAUT LES REPOSER A LA MAIN. Le DragHandler a « target:
                // astre » : il ECRIT dans x et y, et en QML une ecriture
                // remplace definitivement la liaison qu'elle recouvre. L'etoile
                // cesse alors de suivre sa position du modele.
                //
                // POURQUOI CELA N'AVAIT JAMAIS SAUTE AUX YEUX. Jusqu'ici tout
                // glissement se terminait par « pont.placer » : le modele
                // rendait exactement la position que la souris venait de poser,
                // donc la liaison morte et la liaison vivante donnaient le meme
                // pixel. Le jour ou un glissement ne memorise PAS la position —
                // celui qui epingle a la barre — l'etoile est restee la ou on
                // l'avait lachee, c'est-a-dire sous la barre et invisible.
                // Trouve par l'utilisateur a l'ecran, le 2026-08-26.
                function replacer() {
                    x = Qt.binding(function () {
                        return modelData.pos.x * ciel.width - diametre / 2;
                    });
                    y = Qt.binding(function () {
                        return modelData.pos.y * (ciel.height - 70) - diametre / 2;
                    });
                }

                onOuvrir: {
                    bureau.dire(pont.lancer(app.id));
                    bureau.relire();
                }
                onDeplacee: function (nx, ny) {
                    // GLISSER SUR LA BARRE EPINGLE, ET C'EST LE GESTE QUE TOUT
                    // LE MONDE ESSAIE EN PREMIER. Le clic droit le proposait
                    // deja ; personne ne cherche un menu pour faire ce qu'un
                    // glissement dit tout seul.
                    //
                    // LE CIEL COUVRE L'ECRAN ENTIER, BARRE COMPRISE : la barre
                    // est une fenetre posee PAR-DESSUS, elle ne prend pas de
                    // place au bureau. C'est donc ici, en coordonnees du ciel,
                    // qu'on sait si l'etoile a ete lachee sur elle — et non
                    // dans la barre, qui ne recoit jamais ce relachement
                    // puisque la souris est tenue par le ciel jusqu'au bout.
                    if (ny + diametre > ciel.height - barreTaches.hauteur) {
                        pont.epingler(app.id, true);
                        bureau.dire((app.nom || "") + " epinglee a la barre");
                        // On ne memorise PAS la position : l'etoile doit
                        // reprendre sa place au ciel, pas rester sous la barre.
                        replacer();
                        bureau.relire();
                        return;
                    }
                    // ON NE REPOSE PAS LA LIAISON ICI, ET C'EST TOUT LE
                    // CONTRAIRE DE LA BRANCHE CI-DESSUS. « pont.placer » vient
                    // d'enregistrer la nouvelle position, mais « modelData »
                    // porte encore l'ANCIENNE tant que « relire » n'a pas eu
                    // lieu : reposer la liaison maintenant ferait sauter
                    // l'etoile en arriere a chaque lacher. Mesure a l'ecran par
                    // l'utilisateur le 2026-08-26 — « plus du tout
                    // deplacables ». L'etoile reste donc ou la souris l'a mise,
                    // et la prochaine relecture lui rendra une liaison fraiche.
                    var avantX = modelData.pos.x * ciel.width - diametre / 2;
                    var avantY = modelData.pos.y * (ciel.height - 70) - diametre / 2;
                    var dx = nx - avantX, dy = ny - avantY;

                    pont.placer(app.id,
                                (nx + diametre / 2) / ciel.width,
                                (ny + diametre / 2) / (ciel.height - 70));

                    // DEPLACEMENT EN BLOC — demande de l'utilisateur le
                    // 2026-08-28 : selectionner plusieurs etoiles ne servait
                    // a rien tant qu'on ne pouvait pas les deplacer ensemble.
                    // Celle qu'on glisse porte le delta ; les autres etoiles
                    // CHOISIES le suivent, comparees par identifiant plutot
                    // que par reference — un objet JS recree a chaque
                    // « relire » ne serait jamais « === » a lui-meme.
                    if (choisi) {
                        for (var i = 0; i < ciel.children.length; i++) {
                            var c = ciel.children[i];
                            if (c.app === undefined || !c.choisi
                                || c.app.id === app.id) continue;
                            c.x += dx;
                            c.y += dy;
                            pont.placer(c.app.id,
                                        (c.x + c.diametre / 2) / ciel.width,
                                        (c.y + c.diametre / 2) / (ciel.height - 70));
                        }
                    }
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
        // Le mode de veille et le compte des fenetres oubliees descendent
        // d'ici : la barre affiche, elle ne mesure pas. Voir la Connections
        // plus bas, qui les rafraichit a chaque nouvelle du compositeur.
        veille: bureau.veilleMode
        inactives: bureau.fenetresInactives
        // Meme regle, et la meme source, que celle de la barre laterale
        // juste en dessous dans ce fichier : « plein » vient du rapporteur
        // de kwin, seul a pouvoir le savoir.
        efface: ouvertures.some(function (f) {
            return f.plein === true && f.reduite !== true;
        })

        onActivation: function (ident, estActive) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.activer(ident, estActive);
        }
        onFermeture: function (ident) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.fermer(ident);
        }
        onSommeil: function (ident) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.endormir(ident);
        }
        onMenageDemande: function (jours) {
            if (typeof fenetres !== "undefined" && fenetres)
                bureau.dire(fenetres.fermerInactives(jours));
        }
        onVeilleChoisie: function (mode) {
            if (typeof fenetres !== "undefined" && fenetres)
                bureau.dire(fenetres.reglerMode(mode));
        }
        onInactivesDemandees: {
            // A L'OUVERTURE DU MENU, ET NULLE PART AILLEURS. Le compte depend
            // de l'heure autant que de la liste — une fenetre franchit les dix
            // jours sans qu'aucun evenement ne le dise — donc le relire au
            // moment ou l'etiquette s'affiche est a la fois plus juste et
            // beaucoup moins cher que de le refaire a chaque frappe.
            if (typeof fenetres !== "undefined" && fenetres)
                bureau.fenetresInactives =
                    fenetres.inactivesDepuis(barreTaches.joursInactivite);
        }
        onMenuDemande: {
            // LE MENU EST DESSINE ICI, DANS LA FENETRE DU BUREAU, qui reste
            // derriere. On remonte donc le bureau avant d'ouvrir, sinon le
            // bouton aurait l'air casse : il ouvrirait un menu invisible.
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.activerBureau();
            menuDemarrer.visible ? menuDemarrer.close() : menuDemarrer.open();
        }
    }

    // ══ 3 bis. LA BARRE LATERALE ══════════════════════════════════════════
    BarreLaterale {
        id: laterale
        // Elle s'efface entierement pendant un jeu. « plein » vient du
        // rapporteur de kwin, seul a pouvoir le savoir : un client Wayland ne
        // voit pas l'etat des fenetres des autres.
        efface: barreTaches.ouvertures.some(function (f) {
            return f.plein === true && f.reduite !== true;
        })
        onOuverte: pont.rafraichirReglages()
        onReglageBascule: function (cle, vers) {
            bureau.dire(pont.reglerRapide(cle, vers));
        }
        onReglageValeur: function (cle, valeur) {
            bureau.dire(pont.reglerRapide(cle, valeur));
        }
        onReglageChoix: function (cle, valeur) {
            bureau.dire(pont.reglerRapide(cle, valeur));
        }
        onReglageAction: function (cle) {
            if (cle === "verrouiller") { bureau.dire(pont.session("verrouiller")); return; }
            bureau.dire(pont.reglerRapide(cle, true));
        }
    }

    Connections {
        target: pont
        function onReglagesPrets(json) {
            laterale.reglages = JSON.parse(json);
        }
    }

    Connections {
        target: typeof fenetres !== "undefined" ? fenetres : null
        function onChangees(liste) {
            barreTaches.ouvertures = JSON.parse(liste);
        }
        function onModeChange(mode) {
            bureau.veilleMode = mode;
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
                    width: Math.max(0, parent.width - 32)
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
                            Session.bureau.dire(pont.lancer(app.id));
                            Session.bureau.relire();
                            Session.menu.close();
                        }
                        onEpingler: function (oui) {
                            pont.epingler(app.id, oui);
                            Session.bureau.relire();
                            Session.bureau.dire(oui ? (app.nom + " epinglee")
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
                    // LA LARGEUR NEGATIVE, ET C'EST LA CAUSE DES ERREURS DE
                    // Fonds.js QUE LE CARNET DISAIT INCONNUES.
                    //
                    // Tant que la ScrollView n'a pas mesure, « parent.width »
                    // vaut 0. Les Column filles portaient « parent.width - 32 »
                    // pour compenser le padding : elles valaient donc -32. La
                    // Grid dessous heritait -32, son « columns » retombait a 1
                    // par le Math.max, et chaque vignette calculait
                    // (-32 - 0) / 1 = -32 de large, -20 de haut.
                    //
                    // Releve sur la machine le 2026-08-25 a 18 h, par le temoin
                    // pose le matin meme :
                    //     qml: vignette trois : dimensions refusees -32x-20
                    //
                    // ET C'EST POURQUOI LE BANC DU MATIN AVAIT REFUTE LA BONNE
                    // HYPOTHESE. Il avait essaye une taille NULLE, qui n'appelle
                    // jamais onPaint — vrai, et sans rapport. Une taille
                    // NEGATIVE, elle, appelle onPaint et passe des valeurs
                    // impossibles a createRadialGradient. Le banc mesurait le
                    // mauvais cas et rendait un verdict assure.
                    //
                    // Le Math.max borne la soustraction a sa source. Le garde et
                    // le temoin restent en place : ils ne coutent rien et ils
                    // viennent de prouver leur valeur.
                    spacing: 14

                    // ---- Dossiers ----
                    Column {
                        visible: menuDemarrer.vue === "dossiers"
                        width: Math.max(0, parent.width - 32)
                        spacing: 1
                        Repeater {
                            model: bureau.listeDossiers
                            delegate: Rangee {
                                required property var modelData
                                texte: modelData.nom
                                detail: modelData.detail
                                glyphe: modelData.ico
                                onChoisi: {
                                    Session.bureau.dire(pont.ouvrirDossier(modelData.chemin));
                                    Session.menu.close();
                                }
                            }
                        }
                    }

                    // ---- Reglages ----
                    Column {
                        visible: menuDemarrer.vue === "reglages"
                        width: Math.max(0, parent.width - 32)
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
                                    // « parent » est null a l'instant ou le
                                    // Repeater cree ce delegue — il ne
                                    // reparente qu'apres — et parent.width vaut
                                    // alors undefined, donc width vaut NaN.
                                    // Une taille NaN ne fait rien peindre du
                                    // tout, ce qui est pire qu'une erreur :
                                    // c'est une vignette vide sans un mot.
                                    width: parent
                                           ? (parent.width - 9 * (parent.columns - 1)) / parent.columns
                                           : 0
                                    height: width * 10 / 16
                                    Canvas {
                                        id: vignette
                                        anchors.fill: parent
                                        onPaint: {
                                            // GARDE ET TEMOIN. Le journal porte
                                            // depuis le 2026-08-25 trois
                                            // « createRadialGradient():
                                            // Incorrect arguments » venus de
                                            // Fonds.js, que Qt ne leve que sur
                                            // une valeur non finie. La cause
                                            // n'a PAS ete reproduite au banc :
                                            // une taille nulle n'appelle jamais
                                            // onPaint, donc l'hypothese « le
                                            // canevas peint avant d'avoir une
                                            // taille » est refutee. On refuse
                                            // donc de peindre l'impossible, ET
                                            // on ecrit ce qu'on a recu — la
                                            // prochaine occurrence nommera sa
                                            // cause au lieu de la cacher.
                                            if (!isFinite(width) || !isFinite(height)
                                                || width <= 0 || height <= 0) {
                                                console.warn("vignette " + modelData
                                                    + " : dimensions refusees "
                                                    + width + "x" + height);
                                                return;
                                            }
                                            var g = getContext("2d");
                                            Fonds.FONDS[modelData].peindre(g, width, height);
                                        }
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
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
                                            // NI « bureau » NI « Window.window »
                                            // ne portent ici — les deux ont ete
                                            // essayes et le journal les a
                                            // refutes. Voir Session.qml.
                                            Session.bureau.fondActuel = modelData;
                                            pont.reglerFond("fond", modelData);
                                            Session.bureau.dire(
                                                "fond : " + Fonds.FONDS[modelData].nom);
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
                        width: Math.max(0, parent.width - 32)
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
                                    Session.menu.close();
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

        // UN FICHIER ET UNE APPLICATION N'ONT PAS LES MEMES GESTES, ET LE MENU
        // LE DISAIT MAL. « Retirer du bureau » etait propose a un fichier :
        // pour lui, « placees » ne porte que sa POSITION, jamais sa presence —
        // le geste l'aurait remis en grille en pretendant l'enlever.
        readonly property bool estFichier: cible !== null &&
            String(cible.id || "").indexOf("fichier:") === 0
        readonly property bool estDossier: estFichier && (cible.dossier || 0) === 1

        // « Désinstaller », demande le 2026-08-29. PAS UN BOOLEEN DEVINE : le
        // pont sait, lui, si un vrai desinstalleur existe (Android le sait
        // toujours ; Windows seulement s'il en trouve un pres du .exe ;
        // aucune application Linux ce soir, voir noyau.py::desinstallable).
        // Se recalcule a chaque ouverture du menu, quand « cible » change.
        readonly property bool desinstallable: !estFichier && cible !== null &&
            pont.desinstallable(cible.id)

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
            // Sans objet pour un fichier : il EST sur le bureau parce qu'il est
            // dans le dossier, et rien dans ce menu ne peut l'en sortir sans le
            // deplacer pour de vrai.
            visible: !menuContextuel.estFichier
            height: visible ? implicitHeight : 0
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

        // ── « Executer en root », demandee le 2026-08-27 (reponse 16) ───────
        // Sans objet pour un fichier : lui n'a pas de commande a relancer, un
        // fichier s'ouvre par ce que le systeme choisit pour lui, jamais par
        // sa propre ligne Exec.
        SeparateurMenu { visible: !menuContextuel.estFichier
                         height: visible ? implicitHeight : 0 }
        ArticleMenu {
            visible: !menuContextuel.estFichier
            height: visible ? implicitHeight : 0
            text: "Executer en root"
            onTriggered: bureau.dire(pont.lancerEnRoot(menuContextuel.cible.id))
        }

        ArticleMenu {
            // Absent plutot que grise : un article qu'on ne peut jamais
            // cliquer n'apprend rien a l'utilisateur, il l'intrigue pour
            // rien. « desinstallable » est deja tranche par le pont — voir
            // noyau.py::desinstallable, un booleen, jamais une supposition.
            visible: !menuContextuel.estFichier && menuContextuel.desinstallable
            height: visible ? implicitHeight : 0
            grave: true
            text: "Desinstaller…"
            onTriggered: {
                bureau.dire(pont.desinstaller(menuContextuel.cible.id));
                bureau.relire();
            }
        }

        // ── Les gestes qui n'ont de sens que sur un fichier ─────────────────
        SeparateurMenu { visible: menuContextuel.estFichier
                         height: visible ? implicitHeight : 0 }

        ArticleMenu {
            visible: menuContextuel.estFichier
            height: visible ? implicitHeight : 0
            text: "Renommer\u2026"
            onTriggered: saisie.ouvrirPour(menuContextuel.cible)
        }

        ArticleMenu {
            visible: menuContextuel.estFichier
            height: visible ? implicitHeight : 0
            text: "Compresser\u2026"
            onTriggered: bureau.dire(pont.compresser(menuContextuel.cible.id))
        }

        ArticleMenu {
            visible: menuContextuel.estDossier
            height: visible ? implicitHeight : 0
            text: "Ouvrir un terminal ici"
            onTriggered: bureau.dire(pont.terminalIci(menuContextuel.cible.id))
        }

        ArticleMenu {
            visible: menuContextuel.estFichier
            height: visible ? implicitHeight : 0
            text: "Proprietes"
            // C'EST LA VRAIE BOITE DE KDE, celle de Dolphin, ouverte par
            // « kioclient openProperties ». En ecrire une ici voudrait dire
            // reimplementer la lecture des droits, des types MIME, des ACL et
            // des metadonnees — pour rendre moins bien ce que l'amont maintient.
            onTriggered: bureau.dire(pont.proprietes(menuContextuel.cible.id))
        }

        SeparateurMenu { visible: menuContextuel.estFichier
                         height: visible ? implicitHeight : 0 }

        ArticleMenu {
            visible: menuContextuel.estFichier
            height: visible ? implicitHeight : 0
            // « grave » teinte les gestes qu'on ne defait pas — la propriete
            // attendait ce jour depuis le 2026-08-24.
            grave: true
            text: "Mettre a la corbeille"
            // JAMAIS « rm ». La corbeille se defait ; une suppression, non. Un
            // bureau qui supprime pour de bon au clic droit est un bureau qu'on
            // n'ose plus utiliser.
            onTriggered: {
                bureau.dire(pont.corbeille(menuContextuel.cible.id));
                bureau.relire();
            }
        }
    }

    // ══ 5 ter. LE MENU DU FOND DU BUREAU ══════════════════════════════════
    // CE QUE DOLPHIN MET DANS LE SIEN, MOINS CE QUI N'A PAS DE SENS ICI. Son
    // menu de fond porte « Creer nouveau », « Coller », « Trier », « Affichage »,
    // « Actualiser », « Ouvrir un terminal ici » et « Proprietes ». Le tri et
    // l'affichage appartiennent a une LISTE de fichiers ; le ciel de S n'en est
    // pas une — on y pose les etoiles ou l'on veut. « Ranger les etoiles » les
    // remplace : il rend au bureau la grille dont on s'est ecarte.
    Menu {
        id: menuDuFond
        objectName: "menuDuFond"

        function ouvrirA(ex, ey) {
            x = Math.min(ex, bureau.width - width - 8);
            y = Math.min(ey, bureau.height - height - 8);
            open();
        }

        background: Verre {
            radius: 8
            implicitWidth: 244
        }

        ArticleMenu {
            text: "Nouveau dossier"
            onTriggered: saisie.creer(true)
        }

        ArticleMenu {
            text: "Nouveau document"
            onTriggered: saisie.creer(false)
        }

        SeparateurMenu { }

        ArticleMenu {
            text: "Ouvrir un terminal ici"
            // La chaine vide vise le dossier du bureau : le pont retombe sur
            // le dossier personnel quand l'identifiant n'est pas un fichier.
            onTriggered: bureau.dire(pont.terminalIci(""))
        }

        ArticleMenu {
            text: "Ouvrir le dossier Bureau"
            onTriggered: pont.ouvrirDossier(pont.dossierBureau())
        }

        SeparateurMenu { }

        // « RANGER LES ETOILES » A EXISTE UNE HEURE, ET IL EST RETIRE.
        // Il effacait les positions pour rendre la grille de depart. Deux
        // raisons de ne pas le garder, et la seconde est la vraie : l'alignement
        // en colonnes n'est pas ce qu'on veut d'un ciel — on y pose les etoiles
        // ou l'on veut, c'est sa nature ; et un geste qui defait d'un clic tout
        // ce qu'on a range a la main est un geste dont on se mefie.
        // La grille reste ce que le ciel dessine pour un fichier qu'on n'a
        // jamais deplace, et cela suffit.

        ArticleMenu {
            text: bureau.nomsToujours ? "Masquer les noms" : "Montrer les noms"
            onTriggered: {
                bureau.nomsToujours = !bureau.nomsToujours;
                pont.reglerFond("noms", bureau.nomsToujours);
            }
        }

        SeparateurMenu { }

        ArticleMenu {
            text: "Changer le fond\u2026"
            onTriggered: {
                if (typeof fenetres !== "undefined" && fenetres)
                    fenetres.activerBureau();
                menuDemarrer.vue = "reglages";
                menuDemarrer.open();
            }
        }
    }

    // ══ 5 bis. LA BOITE DE SAISIE ═════════════════════════════════════════
    // ELLE EST ECRITE ICI ET NON DELEGUEE, contrairement aux proprietes ou a la
    // compression. Il n'existe pas de « kioclient rename » ni de « kioclient
    // newfile » : ces deux gestes vivent dans l'interface de Dolphin, pas dans
    // un outil. C'est la seule piece de ce menu que l'amont ne fournit pas.
    //
    // UNE SEULE BOITE POUR LES DEUX, parce qu'elles ne different que par leur
    // titre et par ce qu'elles font du texte. En ecrire deux voudrait dire
    // maintenir deux fois le meme habillage — et ce depot repete depuis
    // « s-partage » que deux fichiers qui doivent rester d'accord finissent
    // toujours par diverger.
    Popup {
        id: saisie
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 380
        padding: 18
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var cible: null
        property string titre: ""
        property string bouton: ""
        // « renommer » | « dossier » | « fichier »
        property string quoi: "renommer"

        function ouvrirPour(app) {
            cible = app;
            quoi = "renommer";
            titre = "Renommer";
            bouton = "Renommer";
            champ.text = app.nom || "";
            open();
            champ.forceActiveFocus();
            // On ne selectionne pas l'extension : renommer « photo.png », c'est
            // presque toujours changer « photo », jamais « .png ». Dolphin fait
            // exactement cela, et pour la meme raison.
            var point = champ.text.lastIndexOf(".");
            if (point > 0) champ.select(0, point);
            else champ.selectAll();
        }

        function creer(estDossier) {
            cible = null;
            quoi = estDossier ? "dossier" : "fichier";
            titre = estDossier ? "Nouveau dossier" : "Nouveau document";
            bouton = "Creer";
            champ.text = estDossier ? "Nouveau dossier" : "Sans titre.txt";
            open();
            champ.forceActiveFocus();
            var point = champ.text.lastIndexOf(".");
            if (point > 0) champ.select(0, point);
            else champ.selectAll();
        }

        background: Verre { radius: Theme.rayon }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                text: saisie.titre
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 15
            }

            TextField {
                id: champ
                Layout.fillWidth: true
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 13
                selectByMouse: true
                background: Rectangle {
                    radius: 6
                    color: Theme.verre2
                    border.color: champ.activeFocus ? Theme.bordVif : Theme.bord
                    border.width: 1
                }
                onAccepted: saisie.valider()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                ArticleMenu {
                    text: "Annuler"
                    implicitWidth: 96
                    onTriggered: saisie.close()
                }
                ArticleMenu {
                    text: saisie.bouton
                    implicitWidth: 110
                    onTriggered: saisie.valider()
                }
            }
        }

        function valider() {
            var dit;
            if (quoi === "renommer") {
                if (!cible) { close(); return; }
                dit = pont.renommer(cible.id, champ.text);
            } else {
                dit = pont.creerSurLeBureau(champ.text, quoi === "dossier");
            }
            bureau.dire(dit);
            close();
            bureau.relire();
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

    // EFFACER LA SELECTION — demande de l'utilisateur le 2026-08-28, dans le
    // meme geste que le deplacement en bloc : une selection qui ne sait rien
    // faire d'autre qu'exister ne sert a rien. Un fichier part a la
    // corbeille (jamais « rm », voir noyau.corbeille) ; une application
    // choisie est retiree du bureau, jamais desinstallee — « effacer » un
    // raccourci n'efface pas le logiciel.
    Shortcut {
        sequence: "Delete"
        onActivated: {
            var n = 0;
            for (var i = 0; i < ciel.children.length; i++) {
                var c = ciel.children[i];
                if (c.app === undefined || !c.choisi) continue;
                if (bureau.estUnFichier(c.app.id)) pont.corbeille(c.app.id);
                else pont.retirerDuBureau(c.app.id);
                n += 1;
            }
            if (n > 0) {
                bureau.dire(n > 1 ? n + " etoiles retirees" : "etoile retiree");
                bureau.relire();
            }
        }
    }

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
                "glisser une etoile  la deplacer (et les choisies avec elle)",
                "glisser le fond  selectionner plusieurs etoiles",
                "Suppr  retirer les etoiles choisies",
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
