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

    // ── UN POPUP BLOQUANT EST OUVERT ──────────────────────────────────────
    // LE CIEL ET L'ACCUEIL SE DESACTIVENT TANT QU'IL L'EST — correctif du
    // 2026-10-21, apres que « modal: true » n'a RIEN change chez
    // l'utilisateur. Mesure au banc (vrais clics QTest dans la vraie scene) :
    // un TapHandler ne prend qu'une prise PASSIVE a l'appui, et le point
    // continue sa route jusqu'aux gestionnaires du ciel et des etoiles poses
    // DESSOUS, Overlay modal ou pas. D'ou les deux symptomes, une seule cause :
    // un onglet clique dans le menu Demarrer de Constellation atteignait le
    // TapHandler gauche du ciel, qui referme le menu (pile JS relevee :
    // Constellation.qml « if (menuDemarrer.visible) menuDemarrer.close() ») ;
    // et en Android, une tuile du tiroir lancait son application ET l'etoile
    // posee juste en dessous (« lancer b », puis « lancer a », un seul clic).
    // Un item desactive ne recoit plus rien : on ne parie plus sur la
    // propagation. Le clic HORS du popup le ferme toujours — c'est l'Overlay
    // modal (closePolicy) qui s'en charge, pas le ciel.
    readonly property bool surcouche: menuDemarrer.visible || personnaliser.visible
                                      || saisie.visible || ouvrirAvec.visible
    // Un item desactive perd le focus ; le ciel le reprend des que le popup
    // part, sinon taper sur le bureau n'ouvrirait plus le menu.
    onSurcoucheChanged: if (!surcouche) ciel.forceActiveFocus()

    // ── CONSTELLATION VIVANTE — L'INTERRUPTEUR COMMUN ─────────────────────
    // Tout mouvement CONTINU du chantier vivant (derive des etoiles,
    // respiration du fond, reaction au son) se gate sur ce seul booleen. Un
    // seul endroit a lire pour savoir si « vivant » doit bouger.
    //
    // LE CIEL NE VIT QUE S'IL EST REGARDE — c'est-a-dire quand AUCUNE fenetre
    // n'est ouverte devant lui. La garde d'avant ne le coupait que pour une
    // fenetre en VRAI plein ecran : or fenetres.js agrandit toute fenetre des sa
    // naissance sans la passer en plein ecran, donc un navigateur, un
    // terminal ou un logiciel Windows cachaient le ciel entier pendant que ses
    // 46 etoiles continuaient de derive a soixante images par seconde — deux
    // animations par etoile, dans une fenetre plein ecran que kwin doit
    // recomposer a chaque image. Mesure du 2026-09-19, banc de fluidite, vrai
    // ciel de cette machine : 8,9 % de CPU avec le ciel visible, 8,8 % avec
    // trois fenetres devant (rien ne changeait), 3,1 % avec un plein ecran.
    // Une fenetre REDUITE ne cache rien : elle ne compte pas.
    readonly property bool vivant: !barreTaches.ouvertures.some(function (f) {
        return f.reduite !== true;
    })

    visible: true
    visibility: Window.FullScreen
    color: Theme.espace
    title: "Constellation"

    // --- L'etat, tel que le noyau le rend ---------------------------------
    property var donnees: ({ etoiles: [], usage: ({}), placees: ({}), epingles: [], fichiers: [] })
    // LE FOND DE CONSTELLATION VIT DANS LE THEME DEPUIS LE 2026-10-20 — chaque
    // theme garde le sien (voir Theme.qml). Ce nom reste, en lecture, pour ce
    // qui le lisait deja.
    readonly property string fondActuel: Theme.fondConstellation
    property bool nomsToujours: false
    // Relevee une fois : la liste des dossiers personnels ne bouge pas
    // pendant une session, et une liaison la redemanderait sans cesse.
    property var listeDossiers: []

    // ── CONSTELLATION VIVANTE — le pouls du systeme ───────────────────────
    // « heureFraction » n'est PAS une liaison automatique : new Date() n'a
    // aucune dependance reactive en QML, une propriete calculee avec ne se
    // reevaluerait qu'une seule fois, a la creation. On la pose donc a la
    // main, au meme rythme que pont.pouls() -- un seul Timer pour les deux.
    property var pouls: ({ charge: 0, reseau: 0 })
    property real heureFraction: 0
    // « reseau » ne cree aucun element visuel propre : il module la vitesse
    // de la derive des etoiles (voir Astre.qml) plutot que d'ajouter un
    // signal a l'ecran -- moins d'elements, moins de cout, et une lecture
    // coherente : « le ciel est plus eveille quand ca circule ».
    readonly property real deriveVitesse: 1.0 + Math.min(1.0, pouls.reseau) * 0.6

    Timer {
        // 4 s, DELIBEREMENT plus lent que le plafond deja accepte du projet
        // (l'horloge de la barre, 1000 ms) : une ambiance n'a pas besoin de
        // bouger a la seconde. « triggeredOnStart » garantit que pont.pouls()
        // est exerce au moins une fois -- y compris pendant
        // verifier-constellation.py, dont la fenetre de verification est
        // courte et n'atteindrait jamais un intervalle de 4 s autrement.
        interval: 4000; running: bureau.vivant; repeat: true; triggeredOnStart: true
        onTriggered: {
            bureau.pouls = pont.pouls();
            var d = new Date();
            bureau.heureFraction = (d.getHours() * 60 + d.getMinutes()) / 1440;
        }
    }

    readonly property int maxUsage: {
        var m = 0;
        for (var i = 0; i < donnees.etoiles.length; i++)
            m = Math.max(m, donnees.etoiles[i].compte || 0);
        return m;
    }

    // L'INVENTAIRE N'EST REASSIGNE QUE S'IL A CHANGE. « donnees » alimente les
    // Repeater du ciel et de la barre : lui donner un nouvel objet, meme
    // identique, leur fait detruire et recreer leurs delegues — les 46 etoiles
    // et leurs animations toutes les quinze secondes, avec le survol et
    // l'echelle remis a zero. Le compte se fait sur le JSON : Qt compare les
    // objets par identite, pas par valeur.
    property string empreinteDonnees: ""
    property string empreinteOuvertures: ""
    function relire() {
        // NE JAMAIS RECONSTRUIRE LE CIEL PENDANT UN GLISSEMENT — correctif
        // du 2026-10-20, releve par l'utilisateur : « les etoiles se
        // deplacent mal ». Toute etoile deja affichee perd son identite de
        // delegue des que « donnees » change (voir le commentaire
        // au-dessus) : le Repeater detruit et recree TOUT. Le propre
        // glissement de l'utilisateur ecrit deja dans placees.json
        // (pont.placer, voir Astre.onDeplacee plus bas) SANS appeler
        // relire() lui-meme, pour ne pas se faire ramener en arriere au
        // lacher — mais la PROCHAINE relecture (ce minuteur de 15 s, ou
        // n'importe quelle autre action qui appelle relire()) voit alors
        // toujours une difference, et reconstruit tout le ciel au moment ou
        // elle survient. Si cette difference survient PENDANT qu'une etoile
        // est encore tenue par la souris, cette reconstruction detruit le
        // delegue que le DragHandler tient en ce moment meme — l'etoile
        // saute en arriere a sa derniere position persistee, sous le
        // pointeur. On refuse donc de reconstruire tant qu'un glissement
        // est actif ; le minuteur de 15 s rattrapera la relecture de
        // lui-meme, une fois le glissement termine.
        for (var g = 0; g < ciel.children.length; g++) {
            var astreG = ciel.children[g];
            if (astreG.app !== undefined && astreG.enGlissement === true)
                return;
        }
        var nouvelles = pont.etoiles();
        var empreinte = JSON.stringify(nouvelles);
        if (empreinte === empreinteDonnees)
            return;
        empreinteDonnees = empreinte;
        donnees = nouvelles;
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

    // LA CLASSE REELLE D'UNE FENETRE OUVERTE, DISTINCTE DE SON IDENTIFIANT DE
    // MENU. Reservee a « ouvertures » dans Barre.qml — jamais a appParId,
    // qui sert aussi le ciel et les notifications, ou un « ident » designe
    // toujours un vrai identifiant de .desktop, jamais une classe de fenetre.
    //
    // TROUVE LE 2026-09-07. S Web et le lanceur Vivaldi masque partagent la
    // meme StartupWMClass, « vivaldi-stable » — c'est le meme binaire, donc
    // la meme classe, quel que soit le lanceur qui l'a ouvert. Le lanceur
    // epingle portait deja la bonne icone ; la fenetre OUVERTE, elle,
    // retombait sans correspondance et s'affichait comme un Vivaldi
    // generique — exactement ce que la demande du soir voulait faire
    // disparaitre.
    //
    // Une classe portee par PLUSIEURS etoiles visibles ne choisit pas :
    // absent plutot que faux, meme regle qu'appParNotification plus haut.
    function appParClasse(classe) {
        if (!classe) return null;
        var trouve = null;
        for (var i = 0; i < donnees.etoiles.length; i++) {
            if (donnees.etoiles[i].wmclass && donnees.etoiles[i].wmclass === classe) {
                if (trouve) return null;
                trouve = donnees.etoiles[i];
            }
        }
        return trouve;
    }

    // CONSTELLATION VIVANTE — badge de notification. « appId » est
    // l'identifiant EXACT quand la source le fournit (aujourd'hui : Android
    // seul, via le hint x-s-app-id, deja dans la meme forme que l'id de
    // l'etoile). « nomNotif » est le repli — le seul champ que Linux natif
    // fournit (le « summary » du D-Bus Notify), jamais fiable a 100 % : on
    // n'accepte une correspondance PAR NOM que si elle est unique. Une
    // correspondance ambigue ne pose jamais de badge — absent plutot que
    // faux, plutot que de deviner entre deux applications de meme nom.
    function appParNotification(appId, nomNotif) {
        if (appId) {
            var parId = appParId(appId);
            if (parId) return parId;
        }
        if (!nomNotif) return null;
        var bas = nomNotif.toLowerCase();
        var candidats = donnees.etoiles.filter(function (e) {
            return (e.nom || "").toLowerCase() === bas;
        });
        return candidats.length === 1 ? candidats[0] : null;
    }

    // CONSTELLATION VIVANTE — l'etat d'activite, deja live cote kwin.
    // « fenetres.js » pousse « classe », « active », « reduite » a chaque
    // bascule (un vrai signal Qt, jamais une scrutation) — voir
    // « barreTaches.ouvertures », rempli par « Connections { onChangees }
    // plus bas. L'appariement fenetre -> etoile se fait par « classe », deja
    // prouve pour Linux (le .desktop = resourceClass, Barre.qml l'utilise
    // deja) et pour Android (android-applications.py pose
    // « StartupWMClass=waydroid.<paquet> », mesure le 2026-08-29). Windows
    // n'a rien de tel — toute fenetre y porte « steam_proton », seul le
    // titre distingue un programme, et un rapprochement flou risquerait un
    // faux positif avec deux jeux ouverts en meme temps. Absent plutot que
    // faux : aucun halo d'activite pour Windows dans cette passe, cohérent
    // avec une limitation deja acceptee ailleurs (l'icone de barre des
    // taches manque deja pour Windows).
    function fenetresPour(app) {
        if (!app || !app.id) return [];
        return barreTaches.ouvertures.filter(function (f) {
            return f.classe === app.id;
        });
    }
    function estActive(app) {
        return fenetresPour(app).some(function (f) {
            return f.active === true && f.reduite !== true;
        });
    }
    function estReduite(app) {
        var fs = fenetresPour(app);
        return fs.length > 0 && fs.every(function (f) { return f.reduite === true; });
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
            Theme.charger(r);
            nomsToujours = r.noms === true;
        }
    }

    // ══ LES THEMES ════════════════════════════════════════════════════════
    // CHANGER DE THEME NE REDEMARRE RIEN. Le singleton Theme porte les roles
    // (couleurs, formes, polices) et chaque piece de la coquille les lit : poser
    // « Theme.nom » suffit, toutes les liaisons se reevaluent, et les Loader
    // remplacent la barre, le menu et le panneau de reglages par ceux du
    // nouveau theme. Ceux de l'ancien sont detruits : un seul theme vit a la
    // fois, c'est ce qui garde la memoire de la coquille la ou elle etait.
    function appliquerTheme(cle) {
        if (cle !== "windows" && cle !== "android") cle = "constellation";
        if (Theme.nom === cle) return;
        ciel.choisirDans(null);
        Theme.nom = cle;
        pont.reglerFond("theme", cle);
        Qt.callLater(liens.requestPaint);
        dire("theme : " + Theme.nomDuTheme(cle));
    }

    // LE FOND DU THEME COURANT — un fond peint, ou « image:<chemin> ». Une image
    // est mesuree UNE FOIS ici (sa couleur dominante donne l'accent de Windows
    // et la palette d'Android quand ils sont automatiques), puis gardee dans les
    // reglages : la remesurer a chaque ouverture couterait un decodage.
    function choisirFond(id) {
        var cle = Theme.estWindows ? "fond_windows"
                : (Theme.estAndroid ? "fond_android" : "fond");
        if (Theme.estWindows) Theme.fondWindows = id;
        else if (Theme.estAndroid) Theme.fondAndroid = id;
        else Theme.fondConstellation = id;
        pont.reglerFond(cle, id);
        if (id.indexOf("image:") === 0 && !Theme.estConstellation) {
            // La mesure s'ecrit MEME VIDE : une teinte vide veut dire « pas de
            // couleur franche, prends le defaut », et garder celle de l'image
            // d'avant collerait sa couleur sur celle-ci.
            var mesure = pont.analyserImage(id.substring(6));
            if (mesure) {
                var teinte = String(mesure.teinte || "");
                var clair = mesure.clair === true;
                if (Theme.estWindows) {
                    Theme.teinteWindows = teinte;
                    Theme.clairWindows = clair;
                    pont.reglerFond("teinte_windows", teinte);
                    pont.reglerFond("clair_windows", clair);
                } else {
                    Theme.teinteAndroid = teinte;
                    Theme.clairAndroid = clair;
                    pont.reglerFond("teinte_android", teinte);
                    pont.reglerFond("clair_android", clair);
                }
            }
        }
        var f = Fonds.FONDS[id];
        dire("fond : " + (f ? f.nom : id.substring(id.lastIndexOf("/") + 1)));
    }

    // Un reglage du theme — mode, accent, graine, ciel vivant — pose et garde.
    function reglerTheme(cle, valeur) {
        if (cle === "sombre_windows") Theme.sombreWindows = valeur === true;
        else if (cle === "sombre_android") Theme.sombreAndroid = valeur === true;
        else if (cle === "accent_windows") Theme.accentWindows = String(valeur || "");
        else if (cle === "graine_android") Theme.graineAndroid = String(valeur || "");
        else if (cle === "ciel_vivant") Theme.cielVivant = valeur === true;
        else return;
        pont.reglerFond(cle, valeur);
    }

    function ouvrirMenuContextuel(app, ex, ey) {
        menuContextuel.ouvrirPour(app, ex, ey);
    }

    // LA BOITE DE PERSONNALISATION VIT DANS LA FENETRE DU BUREAU, qui reste
    // derriere les autres : on la remonte d'abord, sinon la boite s'ouvrirait
    // sous la fenetre d'ou on l'a demandee — le piege du menu Demarrer.
    function ouvrirPersonnaliser() {
        if (typeof fenetres !== "undefined" && fenetres)
            fenetres.activerBureau();
        if (menuDemarrer.visible) menuDemarrer.close();
        laterale.deploye = false;
        personnaliser.open();
    }

    // ══ LA GRILLE DU BUREAU — Windows et Android ══════════════════════════
    // CONSTELLATION POSE SES ETOILES OU L'ON VEUT ; les deux autres themes
    // rangent leurs icones en cases, comme les systemes qu'ils imitent. Les
    // positions gardees restent LES MEMES pour les trois (une fraction de
    // l'ecran, le centre de l'icone) : la grille ne fait que les aimanter a la
    // case la plus proche, et revenir en Constellation rend le ciel tel qu'il
    // etait.
    function grilleColonnes() {
        return Math.max(1, Math.floor((ciel.width - Theme.origineX * 2) / Theme.celluleL));
    }
    function grilleLignes() {
        return Math.max(1, Math.floor((ciel.height - barreTaches.hauteur - Theme.origineY - 8)
                                      / Theme.celluleH));
    }
    function centreCellule(c, r) {
        return { x: Theme.origineX + c * Theme.celluleL + Theme.celluleL / 2,
                 y: Theme.origineY + r * Theme.celluleH + Theme.celluleH / 2 };
    }
    // La case qui contient ce point — ou, si elle est prise, la case libre la
    // plus proche, cherchee en anneaux autour d'elle. Deux icones ne se
    // superposent jamais, comme sur un vrai bureau.
    function celluleLibre(px, py, occupe) {
        var cols = grilleColonnes(), lignes = grilleLignes();
        var c0 = Math.max(0, Math.min(cols - 1, Math.floor((px - Theme.origineX) / Theme.celluleL)));
        var r0 = Math.max(0, Math.min(lignes - 1, Math.floor((py - Theme.origineY) / Theme.celluleH)));
        if (!occupe[c0 + "," + r0]) return { c: c0, r: r0 };
        for (var d = 1; d < cols + lignes; d++) {
            var meilleur = null, dmin = Infinity;
            for (var dc = -d; dc <= d; dc++) {
                for (var dr = -d; dr <= d; dr++) {
                    if (Math.max(Math.abs(dc), Math.abs(dr)) !== d) continue;
                    var c = c0 + dc, r = r0 + dr;
                    if (c < 0 || r < 0 || c >= cols || r >= lignes) continue;
                    if (occupe[c + "," + r]) continue;
                    var dist = dc * dc + dr * dr;
                    if (dist < dmin) { dmin = dist; meilleur = { c: c, r: r }; }
                }
            }
            if (meilleur) return meilleur;
        }
        // TOUT EST PLEIN : on superpose plutot que de perdre une icone.
        return { c: c0, r: r0 };
    }
    // La premiere case libre en colonnes depuis le coin haut-gauche : la place
    // d'un fichier qu'on n'a jamais deplace, comme sur n'importe quel bureau.
    function prochaineCellule(occupe) {
        var cols = grilleColonnes(), lignes = grilleLignes();
        for (var c = 0; c < cols; c++)
            for (var r = 0; r < lignes; r++)
                if (!occupe[c + "," + r]) return { c: c, r: r };
        return { c: 0, r: 0 };
    }
    // APRES UN GLISSEMENT, chaque icone lachee glisse jusqu'a la case libre la
    // plus proche, et c'est cette case qui est gardee — pas l'endroit exact du
    // lacher, qu'une relecture ferait sinon sauter quinze secondes plus tard.
    function aimanter(liste) {
        var largeur = ciel.width, hauteur = ciel.height - ciel.margeBasCiel;
        if (largeur <= 0 || hauteur <= 0) return;
        var occupe = {};
        for (var i = 0; i < ciel.children.length; i++) {
            var c = ciel.children[i];
            if (c.app === undefined || liste.indexOf(c) >= 0) continue;
            var k = celluleLibre(c.x + c.width / 2, c.y + c.height / 2, {});
            occupe[k.c + "," + k.r] = true;
        }
        for (var j = 0; j < liste.length; j++) {
            var a = liste[j];
            var cel = celluleLibre(a.x + a.width / 2, a.y + a.height / 2, occupe);
            occupe[cel.c + "," + cel.r] = true;
            var p = centreCellule(cel.c, cel.r);
            a.allerA(p.x - a.width / 2, p.y - a.height / 2);
            pont.placer(a.app.id, p.x / largeur, p.y / hauteur);
        }
    }

    // Le noyau est relu regulierement : une application installee pendant la
    // session doit finir par apparaitre au ciel sans qu'on se deconnecte.
    Timer {
        interval: 15000; running: true; repeat: true
        onTriggered: bureau.relire()
    }

    // ══ 1. LE FOND ════════════════════════════════════════════════════════
    // Peint une fois (Fonds.js), ou une image de l'utilisateur : voir
    // FondEcran.qml, qui sert aussi aux vignettes et au flou de Windows.
    FondEcran {
        id: fond
        anchors.fill: parent

        // LE REGARD DU CIEL VIVANT. Pose sur le fond, qui couvre tout l'ecran :
        // un HoverHandler ne bloque pas le survol des etoiles au-dessus.
        HoverHandler { id: pointeurBureau }
    }

    // ══ 1 ter. LE CIEL VIVANT (Constellation seulement) ═══════════════════
    // Voir CielVivant.qml. Charge seulement en Constellation et si l'on n'a
    // pas coupe le reglage : sinon il n'existe pas du tout, et ne coute rien.
    Loader {
        id: chargeCiel
        anchors.fill: parent
        active: Theme.estConstellation && Theme.cielVivant
        sourceComponent: Component {
            CielVivant {
                actif: bureau.vivant
                pointeur: pointeurBureau.point.position
                survole: pointeurBureau.hovered
            }
        }
    }

    // ══ 1 bis. L'AMBIANCE VIVANTE ═════════════════════════════════════════
    // Une couche SUPERPOSEE au Canvas « fond », jamais dedans -- il continue
    // de ne peindre qu'une fois, l'invariant du depot reste vrai a la
    // lettre. Degrades lineaires natifs de Rectangle uniquement (jamais
    // QtQuick.Shapes ni Qt5Compat.GraphicalEffects, absents du reste de ce
    // depot) -- une respiration, jamais une repeinture. Coupee net en plein
    // ecran comme tout le reste du chantier vivant.
    Item {
        id: ambiance
        anchors.fill: parent
        visible: bureau.vivant && Theme.estConstellation

        // Plus froide la nuit (bleu sourd), plus chaude au jour (ambre
        // sourd) -- SANS JAMAIS remplacer le fond choisi par l'utilisateur,
        // qui reste entierement dessous : un fond qui change de lui-meme
        // serait lu comme un bug, pas comme une ambiance.
        property color teinteHeure:
            (heureFraction < 0.25 || heureFraction > 0.79) ? "#1a2a6c" : "#ff9d3d"
        Behavior on teinteHeure { ColorAnimation { duration: 4000 } }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1.0; color: ambiance.teinteHeure }
            }
            // « charge » module l'intensite de la respiration -- jamais plus
            // que l'alpha deja utilise par le fond « aube » (~0.05-0.17,
            // voir Fonds.js) : une ambiance, jamais une repeinture.
            opacity: 0.02 + Math.min(1.0, bureau.pouls.charge) * 0.06
            Behavior on opacity { NumberAnimation { duration: 2600; easing.type: Easing.InOutSine } }
        }
    }

    // ══ 2. LE CIEL : les etoiles posees sur le bureau ═════════════════════
    Canvas {
        id: liens
        anchors.fill: parent
        visible: Theme.estConstellation
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var g = getContext("2d");
            g.clearRect(0, 0, width, height);
            if (!Theme.estConstellation) return;
            // Les liens relient chaque etoile posee a sa plus proche voisine.
            // C'est ce qui fait une constellation plutot qu'un tas d'icones.
            var pts = [];
            for (var i = 0; i < ciel.children.length; i++) {
                var c = ciel.children[i];
                if (c.app === undefined) continue;
                var t = c.teinte;
                pts.push({ x: c.x + c.width / 2, y: c.y + c.height / 2,
                           r: Math.round(t.r * 255), v: Math.round(t.g * 255),
                           b: Math.round(t.b * 255) });
            }
            if (pts.length < 2) return;
            // UN LIEN PREND LES COULEURS DES DEUX MONDES QU'IL RELIE — ajoute le
            // 2026-10-20. Rouge vers bleu entre Konsole et un logiciel Windows,
            // et blanc voile au milieu : le ciel dit d'un coup d'oeil quels
            // mondes on a poses cote a cote. Chaque paire n'est tracee qu'une
            // fois, meme si chacune est la plus proche voisine de l'autre.
            var vus = {};
            g.lineWidth = 1.1;
            for (var a = 0; a < pts.length; a++) {
                var meilleur = -1, d2 = Infinity;
                for (var b = 0; b < pts.length; b++) {
                    if (a === b) continue;
                    var dx = pts[a].x - pts[b].x, dy = pts[a].y - pts[b].y;
                    var d = dx * dx + dy * dy;
                    if (d < d2) { d2 = d; meilleur = b; }
                }
                if (meilleur < 0) continue;
                var cle = Math.min(a, meilleur) + "-" + Math.max(a, meilleur);
                if (vus[cle]) continue;
                vus[cle] = true;
                var p = pts[a], q = pts[meilleur];
                var dg = g.createLinearGradient(p.x, p.y, q.x, q.y);
                dg.addColorStop(0, "rgba(" + p.r + "," + p.v + "," + p.b + ",0.34)");
                dg.addColorStop(0.5, "rgba(255,255,255,0.12)");
                dg.addColorStop(1, "rgba(" + q.r + "," + q.v + "," + q.b + ",0.34)");
                g.strokeStyle = dg;
                g.beginPath();
                g.moveTo(p.x, p.y);
                g.lineTo(q.x, q.y);
                g.stroke();
            }
        }
    }

    Item {
        id: ciel
        anchors.fill: parent
        focus: true
        enabled: !bureau.surcouche

        // LE NOMBRE MAGIQUE « 70 », NOMME — nettoyage du 2026-10-20. Six
        // occurrences, en cinq endroits, utilisaient le meme litteral pour
        // convertir la fraction Y [0,1] d'une etoile en pixels, DISTINCT de
        // « barreTaches.hauteur » (52, la vraie hauteur de la barre, deja
        // utilisee plus bas pour detecter un lacher sur elle). On ne les
        // unifie pas ici : chaque etoile deja placee a sa position ecrite
        // sur cette base-la, et changer la valeur deplacerait d'un coup
        // tout ce qui est deja pose, un changement qui merite d'etre vu a
        // l'ecran avant d'etre fait. Seule la lisibilite est corrigee.
        readonly property real margeBasCiel: 70

        // Capture universelle du clavier sur le bureau :
        // Quand l'utilisateur tape sur le clavier n'importe où sur le bureau,
        // sans avoir préalablement cliqué sur un champ ou un menu, on ouvre
        // directement le menu démarrer et on injecte le texte tapé dans la recherche.
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                if (menuDemarrer.visible) menuDemarrer.close();
                event.accepted = true;
                return;
            }
            if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) {
                menuDemarrer.saisir(event.text);
                event.accepted = true;
            }
        }

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
            acceptedButtons: Qt.LeftButton
            onTapped: function (evenement) {
                var cible = ciel.childAt(evenement.position.x, evenement.position.y);
                if (cible && cible.app !== undefined) return;
                ciel.forceActiveFocus();
                ciel.choisirDans(null);
                if (menuDemarrer.visible) menuDemarrer.close();
                if (laterale.deploye) laterale.deploye = false;
            }
        }

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
        // LA VRAIE CORRECTION DU 2026-08-28 NE SUFFISAIT PAS, ET PERSONNE NE
        // L'AVAIT ESSAYEE AU DOIGT. « cadreGlissement » est pose sur « ciel »,
        // l'ANCETRE de toute etoile — et sur un vrai glissement, c'est LUI
        // qui gagne la prise exclusive, jamais le DragHandler de l'etoile
        // (Astre.qml). « surUneEtoile », verifie dans onActiveChanged,
        // n'empechait que la SELECTION de se vider — il etait deja trop tard
        // pour que l'etoile bouge : elle n'avait jamais eu la prise. Releve
        // par l'utilisateur le 2026-10-21, tous themes confondus : « les
        // icones ne sont pas deplacables, comme verrouillees ».
        //
        // CE QUE CE CORRECTIF FAISAIT ETAIT FAUX, ET C'EST MESURE — le
        // 2026-10-21, au banc, trace des prises a l'appui. Un PointHandler
        // devait desactiver ce cadre quand l'appui tombait sur une etoile, en
        // lisant « point.pressed » — qui N'EXISTE PAS sur un point de
        // gestionnaire : il valait « undefined », la garde ne s'est jamais
        // declenchee, et le PointHandler est parti. Ce que la trace montre :
        // l'etoile prend la prise exclusive, avance de 20 px, puis ce cadre la
        // lui REPREND (annulation, puis prise exclusive du cadre) — l'etoile
        // se fige pour tout le reste du geste. Le vrai garde est donc du cote
        // de l'etoile : son DragHandler n'APPROUVE plus qu'on lui reprenne la
        // prise (Astre.qml, « grabPermissions »). Et comme une etoile, plus
        // profonde que le ciel, voit le mouvement AVANT lui, c'est toujours
        // elle qui franchit le seuil la premiere.
        DragHandler {
            id: cadreGlissement
            target: null
            acceptedButtons: Qt.LeftButton
            property point depart: Qt.point(0, 0)
            onActiveChanged: {
                if (active) {
                    depart = centroid.position;
                    ciel.choisirDans(null);
                } else {
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
            // « cadreGlissement » ne peut plus prendre la prise d'une etoile
            // (voir « grabPermissions » dans Astre.qml).
            visible: cadreGlissement.active
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

                // EN GRILLE, HORS CONSTELLATION — voir « LA GRILLE DU BUREAU »
                // plus haut. Les memes positions gardees, aimantees a leur case :
                // une application d'abord, puis un fichier deja place, puis les
                // fichiers jamais deplaces, dans les cases qui restent.
                if (!Theme.estConstellation) {
                    var larg = ciel.width > 0 ? ciel.width : 1920;
                    var haut = (ciel.height - ciel.margeBasCiel) > 0
                               ? (ciel.height - ciel.margeBasCiel) : 1010;
                    var occupe = {};
                    var poser = function (fx, fy) {
                        var k = bureau.celluleLibre(fx * larg, fy * haut, occupe);
                        occupe[k.c + "," + k.r] = true;
                        var centre = bureau.centreCellule(k.c, k.r);
                        return { x: centre.x / larg, y: centre.y / haut };
                    };
                    for (var idG in places) {
                        if (bureau.estUnFichier(idG)) continue;
                        var appG = bureau.appParId(idG);
                        if (appG) sortie.push({ app: appG, pos: poser(places[idG].x, places[idG].y) });
                    }
                    var fsG = bureau.donnees.fichiers || [];
                    var enAttente = [];
                    for (var iG = 0; iG < fsG.length; iG++) {
                        var fG = fsG[iG];
                        if ((fG.bureau || 0) === 0) continue;
                        var pG = places[fG.id];
                        if (pG) sortie.push({ app: fG, pos: poser(pG.x, pG.y) });
                        else enAttente.push(fG);
                    }
                    for (var jG = 0; jG < enAttente.length; jG++) {
                        var libre = bureau.prochaineCellule(occupe);
                        occupe[libre.c + "," + libre.r] = true;
                        var cG = bureau.centreCellule(libre.c, libre.r);
                        sortie.push({ app: enAttente[jG], pos: { x: cG.x / larg, y: cG.y / haut } });
                    }
                    return sortie;
                }

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
                var hauteur = (ciel.height - ciel.margeBasCiel) > 0 ? (ciel.height - ciel.margeBasCiel) : 1010;
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
                id: astreCiel
                required property var modelData
                app: modelData.app
                diametre: bureau.tailleDe(modelData.app)
                actif: bureau.estActive(modelData.app)
                reduite: bureau.estReduite(modelData.app)
                // LE NOM D'UN FICHIER EST TOUJOURS VISIBLE. Une application se
                // reconnait a son icone ; deux captures d'ecran du meme jour
                // portent la meme, et sans leur nom rien ne les distingue.
                montrerNom: bureau.nomsToujours
                            || (modelData.app.src || "") === "fichier"
                // LE CENTRE DE L'ETOILE, PAS SON COIN — avec « width » et « height »
                // plutot que le diametre, depuis que la case d'une icone Windows
                // ou Android n'est plus carree. En Constellation les deux valent
                // le diametre : rien n'y change.
                x: modelData.pos.x * ciel.width - width / 2
                y: modelData.pos.y * (ciel.height - ciel.margeBasCiel) - height / 2

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
                        return modelData.pos.x * ciel.width - width / 2;
                    });
                    y = Qt.binding(function () {
                        return modelData.pos.y * (ciel.height - ciel.margeBasCiel) - height / 2;
                    });
                }

                // LE CHOIX A LA FACON DE WINDOWS : un clic choisit cette icone
                // seule, Ctrl+clic l'ajoute aux autres. Voir Astre.choixDemande.
                onChoixDemande: function (ajouter) {
                    if (ajouter) { choisi = !choisi; return; }
                    ciel.choisirDans(null);
                    choisi = true;
                }

                onOuvrir: {
                    bureau.dire(pont.lancer(app.id));
                    pont.effacerBadge(app.id);
                    bureau.relire();
                }
                // DEPLACEMENT DE GROUPE EN DIRECT — correctif du 2026-10-20,
                // releve par l'utilisateur : « les etoiles se deplacent
                // mal ». Avant, le reste de la selection restait figee
                // pendant tout le glissement et ne sautait qu'au lacher,
                // d'un coup (voir onDeplacee ci-dessous). Astre.qml emet
                // maintenant ce signal au tout DEBUT du glissement : chaque
                // etoile choisie memorise ici sa propre position de depart,
                // pour pouvoir suivre le delta de celle qu'on tient a
                // chaque image plutot qu'au lacher seulement.
                onDeplacementDebute: {
                    if (!choisi) return;
                    for (var i = 0; i < ciel.children.length; i++) {
                        var c = ciel.children[i];
                        if (c.app === undefined || !c.choisi) continue;
                        c.xDepart = c.x;
                        c.yDepart = c.y;
                    }
                }
                onDeplaceeEnDirect: function (dx, dy) {
                    if (!choisi) return;
                    for (var i = 0; i < ciel.children.length; i++) {
                        var c = ciel.children[i];
                        if (c.app === undefined || !c.choisi
                            || c.app.id === app.id) continue;
                        c.x = c.xDepart + dx;
                        c.y = c.yDepart + dy;
                    }
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
                    if (ny + height > ciel.height - barreTaches.hauteur) {
                        pont.epingler(app.id, true);
                        bureau.dire((app.nom || "") + " epinglee a la barre");
                        // On ne memorise PAS la position : l'etoile doit
                        // reprendre sa place au ciel, pas rester sous la barre.
                        replacer();
                        // LE RESTE DU GROUPE A SUIVI EN DIRECT (voir
                        // onDeplaceeEnDirect) MEME SI CE N'EST QUE CELLE-CI
                        // QU'ON EPINGLE : sa position n'a jamais ete
                        // persistee. On la remet donc EXACTEMENT ou elle
                        // etait avant de relire — sinon « relire() » la
                        // laisserait un instant a un endroit que rien n'a
                        // jamais enregistre.
                        if (choisi) {
                            for (var k = 0; k < ciel.children.length; k++) {
                                var cEp = ciel.children[k];
                                if (cEp.app === undefined || !cEp.choisi
                                    || cEp.app.id === app.id) continue;
                                cEp.replacer();
                            }
                        }
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
                    // EN GRILLE, L'ICONE GLISSE JUSQU'A SA CASE, et c'est la case
                    // qui est gardee — pour elle et pour celles qui la suivaient.
                    if (!Theme.estConstellation) {
                        var groupe = [astreCiel];
                        if (choisi) {
                            for (var g2 = 0; g2 < ciel.children.length; g2++) {
                                var cg = ciel.children[g2];
                                if (cg.app === undefined || !cg.choisi
                                    || cg.app.id === app.id) continue;
                                groupe.push(cg);
                            }
                        }
                        bureau.aimanter(groupe);
                        return;
                    }
                    pont.placer(app.id,
                                (nx + width / 2) / ciel.width,
                                (ny + height / 2) / (ciel.height - ciel.margeBasCiel));

                    // DEPLACEMENT EN BLOC — demande de l'utilisateur le
                    // 2026-08-28 : selectionner plusieurs etoiles ne servait
                    // a rien tant qu'on ne pouvait pas les deplacer ensemble.
                    // Celle qu'on glisse porte le delta ; les autres etoiles
                    // CHOISIES le suivent, comparees par identifiant plutot
                    // que par reference — un objet JS recree a chaque
                    // « relire » ne serait jamais « === » a lui-meme.
                    //
                    // LE GROUPE A DEJA SUIVI EN DIRECT PENDANT LE GLISSEMENT
                    // (onDeplaceeEnDirect, plus haut) — correctif du
                    // 2026-10-20. On ne fait plus ICI que PERSISTER la
                    // position que chaque etoile choisie occupe DEJA a
                    // l'ecran ; lui rajouter encore « dx »/« dy » la ferait
                    // sauter une seconde fois, au-dela d'ou elle vient
                    // d'etre lachee.
                    if (choisi) {
                        for (var i = 0; i < ciel.children.length; i++) {
                            var c = ciel.children[i];
                            if (c.app === undefined || !c.choisi
                                || c.app.id === app.id) continue;
                            pont.placer(c.app.id,
                                        (c.x + c.width / 2) / ciel.width,
                                        (c.y + c.height / 2) / (ciel.height - ciel.margeBasCiel));
                        }
                    }
                    liens.requestPaint();
                }
                onMenuDemande: function (ex, ey) { menuContextuel.ouvrirPour(app, ex, ey); }
            }
        }
    }

    // ══ 2 bis. L'ACCUEIL D'ANDROID ════════════════════════════════════════
    // L'horloge en grand et la recherche, en haut de l'ecran d'accueil, comme
    // sur une tablette. Au-dessus du ciel pour recevoir ses clics, et dans la
    // bande que la grille des icones laisse libre (Theme.origineY).
    Loader {
        anchors.fill: parent
        active: Theme.estAndroid
        // Meme garde que le ciel, meme raison : il est pose PAR-DESSUS lui.
        enabled: !bureau.surcouche
        sourceComponent: Component { AccueilAndroid { } }
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
            return f.plein === true && f.reduite !== true && f.active === true;
        })

        onActivation: function (ident, estActive) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.activer(ident, estActive);
        }
        onFermeture: function (ident) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.fermer(ident);
        }
        onForcerFermeture: function (ident) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.forcerFermeture(ident);
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
            // TOUJOURS OUVRIR, JAMAIS BASCULER DEPUIS CE BOUTON — correctif
            // du 2026-10-20. « menuDemarrer.visible » reste vrai tant que le
            // menu n'a pas ete explicitement ferme, meme quand la course
            // cote Python (voir le correctif de _corriger_bureau dans
            // fenetres.py) a laisse la vraie fenetre le recouvrir sans que
            // personne ne le voie : un second clic lisait alors ce
            // « visible » perime et REFERMAIT un menu que personne n'avait
            // jamais vu — d'ou « il faut cliquer deux fois ». Fermer reste
            // possible : un clic sur le ciel vide le fait deja
            // explicitement, un peu plus bas dans ce fichier.
            menuDemarrer.open();
        }
        reglagesOuverts: laterale.deploye
        onReglagesDemandes: {
            laterale.deploye = !laterale.deploye;
        }
        // LA PASTILLE « RECHERCHER » DE WINDOWS : le menu s'ouvre sur sa
        // recherche, le curseur deja dedans.
        onRechercheDemandee: {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.activerBureau();
            menuDemarrer.ouvrirRecherche();
        }
        // LE COIN « AFFICHER LE BUREAU » DE WINDOWS, tout au bout de la barre.
        onBureauDemande: {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.activerBureau();
        }
    }

    // ══ 3 bis. LA BARRE LATERALE ══════════════════════════════════════════
    BarreLaterale {
        id: laterale
        // Elle s'efface entierement pendant un jeu. « plein » vient du
        // rapporteur de kwin, seul a pouvoir le savoir : un client Wayland ne
        // voit pas l'etat des fenetres des autres.
        efface: barreTaches.ouvertures.some(function (f) {
            return f.plein === true && f.reduite !== true && f.active === true;
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
        // LA BASCULE DU SON — correctif du 2026-10-20. « cle » vaut
        // "volume" (la cle de la glissiere) ; le dispatch Python attend
        // "volume-muet" (reglages.py::regler), separe de "volume" pour ne
        // jamais confondre un pourcentage et une bascule.
        onReglageMuet: function (cle) {
            bureau.dire(pont.reglerRapide(cle + "-muet", true));
        }
        onReglageAction: function (cle) {
            if (cle === "verrouiller") { bureau.dire(pont.session("verrouiller")); return; }
            bureau.dire(pont.reglerRapide(cle, true));
        }
        onPersonnaliserDemande: bureau.ouvrirPersonnaliser()
    }

    Connections {
        target: pont
        function onReglagesPrets(json) {
            laterale.reglages = JSON.parse(json);
        }
        // Un reglage lent a rendu « en cours » tout de suite ; sa vraie
        // phrase arrive ici, quand il a fini.
        function onReglageFait(dit) {
            bureau.dire(dit);
        }
        // LE CHOIX D'UNE IMAGE PASSE PAR LA BOITE DE KDE, dans un fil : la
        // reponse arrive ici, vide si l'on a annule.
        function onImageChoisie(chemin) {
            if (chemin !== "")
                bureau.choisirFond("image:" + chemin);
        }
    }

    Connections {
        target: typeof fenetres !== "undefined" ? fenetres : null
        function onChangees(liste) {
            // Python ne renvoie deja plus une liste identique ; ce test tient
            // quand meme : un « ouvertures » reassigne reevalue « vivant », les
            // menus et chaque liaison qui le lit.
            if (liste === bureau.empreinteOuvertures)
                return;
            bureau.empreinteOuvertures = liste;
            barreTaches.ouvertures = JSON.parse(liste);
        }
        function onModeChange(mode) {
            bureau.veilleMode = mode;
        }
    }

    // ══ 4. LE MENU DEMARRER ═══════════════════════════════════════════════
    // UN SEUL POPUP POUR LES TROIS THEMES — depuis le 2026-10-20. Ce qu'on y
    // MONTRE change avec le theme (DemarrerConstellation, DemarrerWindows,
    // TiroirAndroid, un seul charge a la fois) ; ce qu'on y FAIT ne change
    // pas, et vit ici une seule fois : la requete, la liste filtree, ce que
    // veut dire « Entree ». Trois menus qui recopieraient chacun cette logique
    // finiraient par diverger — ce depot le repete depuis « s-partage ».
    Popup {
        id: menuDemarrer
        objectName: "menuDemarrer"
        // MODAL, MEME SANS ASSOMBRIR L'ECRAN — corrige le 2026-10-21, deux
        // bugs releves par l'utilisateur d'un coup : le menu se fermait a
        // CHAQUE clic, meme ceux portes sur son propre contenu ; et en
        // Android, toucher une tuile du tiroir ouvrait l'application posee
        // JUSTE EN DESSOUS sur le ciel. Meme cause : « modal: false » ne
        // pose aucune barriere, donc le TapHandler de « ciel » (plus bas,
        // clic gauche) ET celui de l'etoile sous le point RECOIVENT eux
        // aussi le clic — un Popup ne consomme pas l'evenement pour le
        // reste de la scene a moins qu'on le lui dise. « modal: true »
        // pose la vraie barriere de Qt Quick Controls (l'Overlay intercepte
        // tout en dehors du popup) ; le fond transparent garde l'apparence
        // d'un menu flottant, jamais un ecran assombri.
        modal: true
        Overlay.modal: Rectangle { color: "transparent" }
        focus: true
        padding: 0

        // Ce qu'on cherche, ecrit par le champ du menu courant.
        property string requete: ""
        // Le champ de recherche du menu courant : chaque mise en page l'expose.
        readonly property var champ: contenuMenu.item ? contenuMenu.item.champRecherche : null
        property string vue: "apps"
        // LE DECALAGE QU'ON ANIME, PAS « y ». La position reste une liaison au
        // theme et a l'ecran ; l'animation d'ouverture ne fait que s'y ajouter.
        property real decalage: 0

        readonly property real largeurVoulue: Theme.estWindows ? 642
            : (Theme.estAndroid ? Math.min(1060, bureau.width * 0.64) : 560)
        readonly property real hauteurVoulue: Theme.estWindows ? 726
            : (Theme.estAndroid ? bureau.height * 0.84 : 640)
        width: Math.min(largeurVoulue, bureau.width - 32)
        height: Math.min(hauteurVoulue, bureau.height - (Theme.estConstellation ? 130 : 88))
        x: (bureau.width - width) / 2
        readonly property real yOuvert: bureau.height - height
            - (Theme.estConstellation ? 84 : (Theme.estWindows ? 64 : 68))
        y: yOuvert + decalage

        // LE FOND : du verre en Constellation ; l'acrylique de Windows (le fond
        // flou derriere une teinte) ; une surface Material, floue elle aussi,
        // pour le tiroir d'Android. Voir Panneau.qml.
        background: Panneau {
            rayon: Theme.rayon
            teinte: Theme.panneau
            flou: !Theme.estConstellation
            ox: menuDemarrer.x
            oy: menuDemarrer.y
            ecranL: bureau.width
            ecranH: bureau.height
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Theme.dureeNormale; easing.type: Theme.courbe }
                NumberAnimation { property: "scale"; from: Theme.estConstellation ? 0.96 : 1.0; to: 1.0; duration: Theme.dureeNormale; easing.type: Theme.courbe }
                NumberAnimation {
                    property: "decalage"
                    from: Theme.estConstellation ? 20 : (Theme.estWindows ? 40 : 72)
                    to: 0
                    duration: Theme.dureeNormale + (Theme.estAndroid ? 80 : 0)
                    easing.type: Theme.courbe
                }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: Theme.dureeRapide; easing.type: Easing.InQuad }
                NumberAnimation { property: "scale"; from: 1.0; to: Theme.estConstellation ? 0.97 : 1.0; duration: Theme.dureeRapide; easing.type: Easing.InQuad }
                NumberAnimation { property: "decalage"; from: 0; to: Theme.estConstellation ? 0 : 28; duration: Theme.dureeRapide; easing.type: Easing.InQuad }
            }
        }

        onOpened: if (champ) champ.forceActiveFocus()
        onClosed: vider()

        contentItem: Loader {
            id: contenuMenu
            sourceComponent: Theme.estWindows ? menuWindows
                           : (Theme.estAndroid ? menuAndroid : menuConstellation)
        }
        Component { id: menuConstellation; DemarrerConstellation { menu: menuDemarrer; hote: bureau } }
        Component { id: menuWindows; DemarrerWindows { menu: menuDemarrer; hote: bureau } }
        Component { id: menuAndroid; TiroirAndroid { menu: menuDemarrer; hote: bureau } }

        // Taper au clavier sur le bureau ouvre le menu et ecrit dans sa
        // recherche — le geste de la page d'origine, pour les trois themes.
        function saisir(texte) {
            if (!visible) {
                open();
                if (champ) champ.text = texte;
            } else if (champ && !champ.activeFocus) {
                champ.text = champ.text + texte;
            }
            if (champ) {
                champ.forceActiveFocus();
                champ.cursorPosition = champ.text.length;
            }
        }

        function vider() {
            if (champ) champ.text = "";
            requete = "";
        }

        // Le menu sur sa recherche — la pastille « Rechercher » de Windows,
        // celle de l'accueil d'Android.
        function ouvrirRecherche() {
            vue = "apps";
            if (!visible) open();
            if (champ) champ.forceActiveFocus();
        }

        function lancerApp(app) {
            if (!app) return;
            bureau.dire(pont.lancer(app.id));
            pont.effacerBadge(app.id);
            bureau.relire();
            close();
        }

        // Entree lance la premiere reponse ou bascule sur commande/Google
        function valider() {
            var q = requete.trim();
            if (q === "") return;
            if (q.startsWith("#") || q.startsWith("sudo ") || q.startsWith("pkexec ")) {
                bureau.dire(pont.lancer("cmd_root:" + q));
                close();
                return;
            }
            if (q.startsWith("$") || q.startsWith(">")) {
                bureau.dire(pont.lancer("cmd:" + q));
                close();
                return;
            }
            var l = filtrees();
            // BOGUE PREEXISTANT, TROUVE LE 2026-09-01 EN TESTANT LE REPLI POUR
            // DE VRAI : filtrees() ajoute TOUJOURS trois entrees de secours
            // (cmd:, cmd_root:, recherche:) des que le texte n'est pas vide —
            // meme quand AUCUNE vraie application ne correspond. « l.length > 0 »
            // etait donc TOUJOURS vrai, et l[0] tombait alors sur
            // « cmd:<le texte tape tel quel> » : n'importe quelle phrase libre
            // partait dans un terminal comme commande shell — « ouvre vivladi »
            // executait litteralement « ouvre vivladi ». Ce repli n'avait
            // jamais ete atteint une seule fois. On ne peut prendre l[0] a
            // l'aveugle que s'il s'agit d'une VRAIE correspondance — jamais
            // d'une suggestion de secours.
            if (l.length > 0 && l[0].id.indexOf("cmd:") !== 0
                    && l[0].id.indexOf("cmd_root:") !== 0
                    && l[0].id.indexOf("recherche:") !== 0) {
                bureau.dire(pont.lancer(l[0].id));
                bureau.relire();
                close();
            } else {
                // Rien de connu ne matche : repli direct sur une
                // recherche Google.
                bureau.dire(pont.lancer("recherche:" + q));
                close();
            }
        }

        // TOUTES LES APPLICATIONS, PAR ORDRE ALPHABETIQUE — la liste de Windows
        // et le tiroir d'Android. Le francais trie « Éditeur » avec les E.
        function alphabetique() {
            return bureau.donnees.etoiles.slice().sort(function (a, b) {
                return (a.nom || "").localeCompare(b.nom || "", "fr", { sensitivity: "base" });
            });
        }

        // LES EPINGLEES DU MENU DE WINDOWS : celles de la barre d'abord, puis les
        // plus lancees, jusqu'a « combien ». Un menu qui n'aurait que trois
        // epinglees laisserait un grand vide la ou Windows montre une grille.
        function epinglees(combien) {
            var sortie = [], vus = {};
            var ep = bureau.donnees.epingles || [];
            for (var i = 0; i < ep.length && sortie.length < combien; i++) {
                var a = bureau.appParId(ep[i]);
                if (a && !bureau.estUnFichier(a.id) && !vus[a.id]) { sortie.push(a); vus[a.id] = true; }
            }
            var parUsage = bureau.donnees.etoiles.slice().sort(function (a, b) {
                return (b.compte || 0) - (a.compte || 0);
            });
            for (var j = 0; j < parUsage.length && sortie.length < combien; j++) {
                if (!vus[parUsage[j].id]) { sortie.push(parUsage[j]); vus[parUsage[j].id] = true; }
            }
            return sortie;
        }

        // La recherche universelle classe par pertinence et usage : commandes root/console,
        // correspondance exacte, debut de nom, corps du nom, description/commentaire,
        // monde, catalogue unifie, et en repli les commandes directes et la recherche Web Google.
        function filtrees() {
            var q = requete.toLowerCase().trim();
            if (q === "") return bureau.donnees.etoiles;

            // Détection explicite de commande root (#, sudo, pkexec)
            if (q.startsWith("#") || q.startsWith("sudo ") || q.startsWith("pkexec ")) {
                var cmdR = requete.trim().replace(/^[#]|^(sudo\s+)|^(pkexec\s+)/, "").trim();
                return [{
                    id: "cmd_root:" + cmdR,
                    nom: "Exécuter en root : " + cmdR,
                    src: "linux",
                    ico: "i-terminal",
                    img: "",
                    txt: "Lancer la commande avec les privilèges administrateur (pkexec)",
                    action: "",
                    compte: 99999,
                    catalogue: 0
                }];
            }

            // Détection explicite de commande console ($, >)
            if (q.startsWith("$") || q.startsWith(">")) {
                var cmdU = requete.trim().substring(1).trim();
                return [{
                    id: "cmd:" + cmdU,
                    nom: "Exécuter : " + cmdU,
                    src: "linux",
                    ico: "i-terminal",
                    img: "",
                    txt: "Lancer la commande dans la console",
                    action: "",
                    compte: 99999,
                    catalogue: 0
                }];
            }

            var parUsage = function (a, b) {
                return (b.compte || 0) - (a.compte || 0);
            };

            var exacts = [];
            var debutNom = [];
            var contientNom = [];
            var contientDesc = [];
            var contientMonde = [];

            for (var i = 0; i < bureau.donnees.etoiles.length; i++) {
                var e = bureau.donnees.etoiles[i];
                var nomMin = (e.nom || "").toLowerCase();
                var descMin = (e.txt || "").toLowerCase();
                var srcMin = (e.src || "").toLowerCase();

                if (nomMin === q) {
                    exacts.push(e);
                } else if (nomMin.startsWith(q)) {
                    debutNom.push(e);
                } else if (nomMin.indexOf(q) >= 0) {
                    contientNom.push(e);
                } else if (descMin.indexOf(q) >= 0) {
                    contientDesc.push(e);
                } else if (srcMin.indexOf(q) >= 0) {
                    contientMonde.push(e);
                }
            }

            exacts.sort(parUsage);
            debutNom.sort(parUsage);
            contientNom.sort(parUsage);
            contientDesc.sort(parUsage);
            contientMonde.sort(parUsage);

            // Suggestions du catalogue unifie pour applications non installees
            var catalogueRecommandes = [];
            if (bureau.donnees.catalogue && bureau.donnees.catalogue.length > 0) {
                var nomsInstalles = exacts.concat(debutNom).concat(contientNom).map(function(item) {
                    return (item.nom || "").toLowerCase();
                });
                for (var j = 0; j < bureau.donnees.catalogue.length; j++) {
                    var cat = bureau.donnees.catalogue[j];
                    var catNomMin = (cat.nom || "").toLowerCase();
                    var catDescMin = (cat.txt || "").toLowerCase();
                    if (nomsInstalles.indexOf(catNomMin) < 0) {
                        if (catNomMin.indexOf(q) >= 0 || catDescMin.indexOf(q) >= 0) {
                            catalogueRecommandes.push(cat);
                        }
                    }
                }
            }

            var resultat = exacts.concat(debutNom).concat(contientNom).concat(contientDesc).concat(contientMonde).concat(catalogueRecommandes);

            // Options de commande console, commande root et recherche Web
            if (q !== "") {
                resultat.push({
                    id: "cmd:" + requete.trim(),
                    nom: "Exécuter : " + requete.trim(),
                    src: "linux",
                    ico: "i-terminal",
                    img: "",
                    txt: "Lancer dans la console",
                    action: "",
                    compte: 0,
                    catalogue: 0
                });
                resultat.push({
                    id: "cmd_root:" + requete.trim(),
                    nom: "Exécuter en root : " + requete.trim(),
                    src: "linux",
                    ico: "i-terminal",
                    img: "",
                    txt: "Lancer avec les droits administrateur (pkexec)",
                    action: "",
                    compte: 0,
                    catalogue: 0
                });
                resultat.push({
                    id: "recherche:" + q,
                    nom: "Rechercher sur Google",
                    src: "linux",
                    ico: "i-recherche",
                    img: "",
                    txt: "Lancer la recherche « " + requete.trim() + " » dans le navigateur",
                    action: "",
                    compte: 0,
                    catalogue: 0
                });
            }

            return resultat;
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

        // « SUGGESTION DU CATALOGUE », PAS ENCORE INSTALLEE — correctif du
        // 2026-10-20. noyau.py pose « catalogue: 1 » sur ces entrees-la
        // (voir composer_etoiles) ; « Epingler »/« Placer sur le bureau »
        // ecrivaient alors un identifiant « catalogue:<cle> » dans
        // epingles.json/placees.json, et comme ni noyau.etoiles() ni ce
        // menu ne connaissent cet id, le clic ne faisait jamais RIEN de
        // visible — une entree orpheline en silence, pour toujours. Meme
        // principe que « desinstallable » juste au-dessus : absent plutot
        // que grise.
        readonly property bool estCatalogue: cible !== null &&
            (cible.catalogue || 0) === 1

        // « Désinstaller », demande le 2026-08-29. PAS UN BOOLEEN DEVINE : le
        // pont sait, lui, si un vrai desinstalleur existe (Android le sait
        // toujours ; Windows seulement s'il en trouve un pres du .exe ;
        // aucune application Linux ce soir, voir noyau.py::desinstallable).
        // Se recalcule a chaque ouverture du menu, quand « cible » change.
        readonly property bool desinstallable: !estFichier && cible !== null &&
            pont.desinstallable(cible.id)

        background: Verre {
            radius: Theme.rayonMenu
            implicitWidth: Theme.estAndroid ? 248 : 232
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Theme.dureeRapide; easing.type: Theme.courbe }
                NumberAnimation { property: "scale"; from: Theme.estWindows ? 0.98 : 0.94; to: 1.0; duration: Theme.dureeRapide; easing.type: Theme.courbe }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 100 }
        }

        ArticleMenu {
            text: "Ouvrir"
            onTriggered: {
                bureau.dire(pont.lancer(menuContextuel.cible.id));
                bureau.relire();
            }
        }

        // ── « Ouvrir avec… », demandee le 2026-08-30 ────────────────────────
        // Sans objet pour une application : elle N'A qu'une commande, ouvrir
        // « avec autre chose » n'a pas de sens pour elle. La liste des
        // candidates est demandee ICI, a l'ouverture du menu, jamais recalculee
        // en direct — meme raison que « inactivesDemandees » pour la barre :
        // un appel de fonction nu dans une liaison QML ne se reevalue jamais
        // tout seul, seule une propriete qui change le declenche.
        ArticleMenu {
            visible: menuContextuel.estFichier
            height: visible ? implicitHeight : 0
            text: "Ouvrir avec…"
            onTriggered: ouvrirAvec.ouvrirPour(menuContextuel.cible)
        }

        SeparateurMenu { }

        ArticleMenu {
            // Sans objet pour une suggestion du catalogue : voir estCatalogue.
            visible: !menuContextuel.estCatalogue
            height: visible ? implicitHeight : 0
            text: menuContextuel.epinglee ? "Retirer de la barre" : "Epingler a la barre"
            onTriggered: {
                pont.epingler(menuContextuel.cible.id, !menuContextuel.epinglee);
                bureau.relire();
            }
        }

        ArticleMenu {
            // Sans objet pour un fichier : il EST sur le bureau parce qu'il est
            // dans le dossier, et rien dans ce menu ne peut l'en sortir sans le
            // deplacer pour de vrai. Sans objet non plus pour une suggestion du
            // catalogue : voir estCatalogue.
            visible: !menuContextuel.estFichier && !menuContextuel.estCatalogue
            height: visible ? implicitHeight : 0
            // LIBELLE HARMONISE AVEC « menuFenetre »/« menuEpinglee » DANS
            // Barre.qml — correctif du 2026-10-20, les trois menus posaient
            // le meme geste sous deux noms differents.
            text: menuContextuel.posee ? "Retirer de la Constellation" : "Ajouter a la Constellation"
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

        // \u00ab Copier \u00bb / \u00ab Couper \u00bb, le geste le plus commun de tout
        // gestionnaire de fichiers, absent d'ici jusqu'au 2026-08-30. Le
        // presse-papiers ne retient qu'UNE cible (voir Pont.__init__ dans
        // s-constellation) \u2014 marquer un second fichier remplace le premier,
        // exactement comme sur n'importe quel bureau.
        ArticleMenu {
            visible: menuContextuel.estFichier
            height: visible ? implicitHeight : 0
            text: "Copier"
            onTriggered: pont.marquerPressePapiers(menuContextuel.cible.id, false)
        }

        ArticleMenu {
            visible: menuContextuel.estFichier
            height: visible ? implicitHeight : 0
            text: "Couper"
            onTriggered: pont.marquerPressePapiers(menuContextuel.cible.id, true)
        }

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

        // DEMANDE ICI, PAS LIEE EN DIRECT — meme raison que « inactivesDemandees »
        // pour la barre des taches : « pont.pressePapiersActif() » est un appel
        // de fonction nu, QML ne le reevalue jamais tout seul. On le relit donc
        // a l'instant precis ou le menu s'ouvre, la seule fois ou ca compte.
        property bool collerDisponible: false

        function ouvrirA(ex, ey) {
            collerDisponible = pont.pressePapiersActif();
            x = Math.min(ex, bureau.width - width - 8);
            y = Math.min(ey, bureau.height - height - 8);
            open();
        }

        background: Verre {
            radius: Theme.rayonMenu
            implicitWidth: Theme.estAndroid ? 256 : 244
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Theme.dureeRapide; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: Theme.dureeRapide; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 100 }
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

        // « Coller », le pendant du « Copier »/« Couper » du menu contextuel.
        // Absent plutot que grise a vide : un article qu'on ne peut jamais
        // cliquer n'apprend rien, il intrigue pour rien — meme regle deja
        // ecrite pour « Desinstaller » plus haut dans ce fichier.
        ArticleMenu {
            visible: menuDuFond.collerDisponible
            height: visible ? implicitHeight : 0
            text: "Coller"
            onTriggered: {
                bureau.dire(pont.coller());
                bureau.relire();
            }
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

        // LES NOMS NE SE CACHENT QU'EN CONSTELLATION. Sous Windows et Android
        // une icone porte toujours son nom, comme sur les systemes qu'on imite :
        // proposer de le masquer serait proposer un geste qui n'y existe pas.
        ArticleMenu {
            visible: Theme.estConstellation
            height: visible ? implicitHeight : 0
            text: bureau.nomsToujours ? "Masquer les noms" : "Montrer les noms"
            onTriggered: {
                bureau.nomsToujours = !bureau.nomsToujours;
                pont.reglerFond("noms", bureau.nomsToujours);
            }
        }

        SeparateurMenu { }

        // « CHANGER LE FOND… » EST DEVENU « PERSONNALISER… » le 2026-10-20 : le
        // fond n'est plus qu'une des choses qu'on y choisit, avec le theme, ses
        // couleurs, et une image a soi.
        ArticleMenu {
            text: "Personnaliser\u2026"
            onTriggered: bureau.ouvrirPersonnaliser()
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

    // ══ 5 quater. « OUVRIR AVEC… » ═════════════════════════════════════════
    // UNE BOITE CENTREE, PAS UN SOUS-MENU EN CASCADE — et ce n'est pas un
    // pis-aller. Ce depot a paye plusieurs fois le prix d'un Popup positionne
    // a la main sous ce compositeur (« un client Wayland ne se positionne pas
    // lui-meme », voir bornerBarre() dans s-constellation) ; un sous-menu en
    // cascade ajouterait exactement ce risque pour un gain cosmetique. Une
    // boite centree, dans le style deja eprouve de « saisie » juste au-dessus,
    // est aussi le choix de GNOME Fichiers pour ce meme geste — ce n'est pas
    // une boite de secours, c'est une convention a part entiere.
    Popup {
        id: ouvrirAvec
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 340
        padding: 18
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var cible: null
        property var candidats: []

        function ouvrirPour(app) {
            cible = app;
            candidats = pont.applicationsPour(app.id);
            open();
        }

        background: Verre { radius: Theme.rayon }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            Text {
                text: "Ouvrir avec"
                color: Theme.texte
                font.family: Theme.police
                font.pixelSize: 15
            }

            Text {
                visible: ouvrirAvec.candidats.length === 0
                Layout.fillWidth: true
                text: "Aucune application ne declare savoir ouvrir ce type de fichier."
                color: Theme.texte3
                font.family: Theme.police
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: ouvrirAvec.candidats
                delegate: ArticleMenu {
                    required property var modelData
                    Layout.fillWidth: true
                    // Le coche marque l'associee ACTUELLE — meme convention
                    // que les deux modes de veille du menu des fenetres.
                    text: (modelData.defaut ? "✓  " : "     ") + modelData.nom
                    onTriggered: {
                        bureau.dire(pont.ouvrirAvec(ouvrirAvec.cible.id, modelData.fichier));
                        ouvrirAvec.close();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                ArticleMenu {
                    text: "Fermer"
                    implicitWidth: 96
                    onTriggered: ouvrirAvec.close()
                }
            }
        }
    }

    // ══ 5 quinquies. PERSONNALISER ════════════════════════════════════════
    // Le theme, le fond (peint ou une image a soi), les couleurs. Voir
    // Personnaliser.qml — son contenu n'existe que pendant qu'elle est ouverte.
    Personnaliser { id: personnaliser }

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
    // En Android, c'est un « snackbar » de Material : la surface inversee,
    // sombre sur un theme clair. Ailleurs, le verre du theme.
    Verre {
        id: mot
        property alias text: motTexte.text
        property bool vu: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.estConstellation ? 92 : 78
        radius: Theme.estAndroid ? 8 : (Theme.estWindows ? 6 : 7)
        color: Theme.estAndroid ? Theme.palette.inverseSurface : Theme.verre
        border.color: Theme.estAndroid ? "transparent" : Theme.bord
        width: motTexte.implicitWidth + (Theme.estConstellation ? 26 : 36)
        height: motTexte.implicitHeight + (Theme.estConstellation ? 12 : 22)
        opacity: vu ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 240 } }
        Text {
            id: motTexte
            anchors.centerIn: parent
            color: Theme.estAndroid ? Theme.palette.inverseOnSurface
                                    : (Theme.estConstellation ? Theme.texte2 : Theme.texte)
            font.family: Theme.policeMono
            font.pixelSize: Theme.estConstellation ? 11 : 13
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
        function onMontrer(id, app, titre, corps, duree, urgence, appId) {
            bulle.poser(id, app, titre, corps, duree, urgence);
            // CONSTELLATION VIVANTE — le badge. Une notification qui ne peut
            // pas etre rattachee a une etoile (Windows, ou un nom Linux
            // ambigu) ne pose rien : voir appParNotification().
            var cible = bureau.appParNotification(appId, app);
            if (cible) {
                pont.incrementerBadge(cible.id);
                bureau.relire();
            }
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
        sequence: "Ctrl+N"
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
        // Ces gestes sont ceux du ciel : sous Windows et Android, ceux du
        // systeme qu'on imite s'appliquent, et chacun les connait deja.
        visible: bureau.width > 760 && Theme.estConstellation
        Repeater {
            model: [
                "clic droit  epingler, poser sur le bureau",
                "double-clic sur une etoile  ouvrir",
                "glisser une etoile  la deplacer (et les choisies avec elle)",
                "glisser le fond  selectionner plusieurs etoiles",
                "Suppr  retirer les etoiles choisies",
                "Ctrl+N  noms toujours visibles"
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
