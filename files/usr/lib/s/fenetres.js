// Le rapporteur de fenetres — charge dans kwin, il dit a Constellation ce qui
// est ouvert.
//
// POURQUOI PASSER PAR UN SCRIPT DE KWIN. Une barre des taches a besoin de la
// liste des fenetres et du droit d'en activer une. Sous Wayland, aucun client
// ne peut avoir ca : c'est le compositeur qui sait, et il ne le dit qu'a qui il
// veut. Releve sur la machine le 2026-08-25, la liste des protocoles annonces
// par kwin :
//
//   org_kde_plasma_window_management  ABSENT
//   zwlr_foreign_toplevel_manager_v1  ABSENT
//
// Les deux protocoles qui auraient servi ne sont pas la. Ce n'est pas un
// manque de kwin : c'est une decision de securite, et elle est juste — une
// application qui peut enumerer les fenetres des autres peut les espionner.
//
// Reste l'interface que kwin ouvre volontairement : ses scripts. Ils tournent
// DANS le compositeur, donc ils savent tout, et « callDBus » leur permet de le
// dire au dehors. C'est la porte prevue, pas une porte forcee.
//
// CE QUI SORT D'ICI EST DELIBEREMENT PAUVRE : un identifiant, une classe, un
// titre, deux etats. Pas de capture, pas de contenu, pas de geometrie.

// ═══ LA PLACE DE LA BARRE, RESERVEE A LA MAIN ═══════════════════════════════
//
// CE QUI MANQUE, ET POURQUOI ON EN EST LA. Un client Wayland ne reserve pas
// d'espace a l'ecran : cela demande zwlr_layer_shell_v1 ou org_kde_plasma_shell,
// que kwin annonce mais qu'aucune liaison Python de cette image ne sait parler.
// Une Konsole maximisee passait donc SOUS la barre, sa ligne de saisie cachee —
// c'est-a-dire inutilisable.
//
// CE SCRIPT TOURNE DEJA DANS LE COMPOSITEUR, ET LUI PEUT DEPLACER LES FENETRES.
// Il ne reserve pas l'espace au sens du protocole : il rattrape, apres coup,
// toute fenetre qui deborde sur les 52 derniers pixels. La difference se voit
// une fois, au moment de la maximisation, et jamais ensuite.
//
// LE VRAI PLEIN ECRAN N'EST PAS TOUCHE. Une video, un jeu, un diaporama
// prennent l'ecran entier — et une barre par-dessus un film serait pire que le
// defaut qu'on repare.
var HAUTEUR_BARRE = 52;
var enTrainDeBorner = false;

function basUtile(f) {
    var z = null;
    try {
        z = workspace.clientArea(KWin.MaximizeArea, f);
    } catch (e) {
        z = null;
    }
    if (!z) {
        try {
            z = workspace.clientArea(KWin.FullScreenArea, f);
        } catch (e2) {
            return -1;
        }
    }
    return z.y + z.height - HAUTEUR_BARRE;
}

function borner(f) {
    if (enTrainDeBorner) return;
    if (!f) return;
    // LA BARRE NE SE BORNE PAS ELLE-MEME. Mesure du 2026-08-25 : la premiere
    // version l'a remontee de 52 pixels, puisque son bas depassait la limite
    // qu'elle venait de poser. Un garde-fou qui s'applique a son propre garde
    // se mord la queue — et la barre flottait au-dessus du vide.
    if (String(f.resourceClass) === "s-constellation") return;
    // « normalWindow » est faux pour certaines fenetres de Waydroid, qui
    // n'annoncent pas de type xdg standard. On borne donc tout ce qui n'est ni
    // menu, ni infobulle, ni notification — releve sur la machine, ou YouTube
    // Android echappait au bornage.
    if (f.popupWindow || f.tooltip || f.notification || f.dock ||
        f.splash || f.utility) return;
    if (f.fullScreen) return;
    if (f.minimized) return;
    var bas = basUtile(f);
    if (bas < 0) return;
    var g = f.frameGeometry;
    if (!g || g.y + g.height <= bas) return;
    var hauteur = bas - g.y;
    // UNE FENETRE POSEE TRES BAS NE SE RACCOURCIT PAS A RIEN : on la remonte
    // plutot que de la reduire a un bandeau de titre.
    var y = g.y;
    if (hauteur < 120) {
        y = Math.max(0, bas - Math.min(g.height, 120));
        hauteur = bas - y;
    }
    if (hauteur <= 0) return;
    // Le drapeau evite la reentrance : changer la geometrie rappelle ce meme
    // gestionnaire, et sans lui kwin et ce script se renverraient la fenetre.
    enTrainDeBorner = true;
    f.frameGeometry = { x: g.x, y: y, width: g.width, height: hauteur };
    enTrainDeBorner = false;
}

// ═══ UNE FENETRE NEUVE S'OUVRE EN GRAND, PAS PETITE DANS UN COIN ═══════════
//
// Demande de l'utilisateur, 2026-08-29 : Vivaldi et VS Code, entre autres,
// ouvraient une fenetre neuve toute petite, coincee en bas a droite. Ce
// n'est pas kwin qui decide cette position : chaque application garde SA
// PROPRE geometrie souvenue (Vivaldi dans ses Preferences, VS Code dans son
// storage), et elle la redemande a chaque nouvelle fenetre — y compris
// quand cette geometrie date d'un autre ecran ou d'un vieux glissement
// accidentel vers un coin. Le compositeur n'a pas a corriger cette memoire
// pour que S se comporte comme l'utilisateur le veut : il agit une fois,
// a la naissance de la fenetre, comme « borner » le fait deja pour
// l'inverse (une fenetre trop grande).
//
// CE QUI EST EXCLU, ET POURQUOI. Les trois fenetres de Constellation ont
// deja leur position et leur taille FORCEES par kwinrulesrc (voir
// regles-kwin.py) — les toucher ici referait un travail deja fait, pour le
// meme resultat. Les fenetres Android (« waydroid.* ») ont une taille
// choisie exprès par regles-kwin.py::taille_android — un rapport
// long/court precis, mesure le 2026-08-25/26, qui evite le mode Android
// « une seule colonne ». Les maximiser ecraserait ce choix. La fenetre
// systeme « Waydroid » est deja geree par cacherAndroidSysteme ci-dessus.
function estAgrandissable(f) {
    if (!f) return false;
    if (!f.normalWindow) return false;
    if (f.dialog || f.modal || f.popupWindow || f.tooltip ||
        f.notification || f.dock || f.splash || f.utility) return false;
    if (f.fullScreen) return false;
    var classe = String(f.resourceClass || "");
    if (classe === "s-constellation") return false;
    if (classe === "Waydroid") return false;
    if (classe.indexOf("waydroid.") === 0) return false;
    return true;
}

function agrandir(f) {
    if (!estAgrandissable(f)) return;
    // Meme plafond que « borner » : le bas de l'ecran utile, jamais sous la
    // barre. Meme source, jamais deux calculs qui pourraient diverger.
    var bas = basUtile(f);
    if (bas < 0) return;
    var z;
    try {
        z = workspace.clientArea(KWin.FullScreenArea, f);
    } catch (e) {
        return;
    }
    if (!z) return;
    enTrainDeBorner = true;
    f.frameGeometry = { x: z.x, y: z.y, width: z.width, height: bas - z.y };
    enTrainDeBorner = false;
}

function suivreGeometrie(f) {
    if (!f) return;
    // ON REGAGNE LES DEUX OU TROIS PREMIERS CHANGEMENTS DE GEOMETRIE, PAS
    // SEULEMENT L'INSTANT DE LA NAISSANCE. Mesure du 2026-08-30 : « agrandir »
    // au « windowAdded » tient parfois et se fait ecraser d'autres fois, un
    // instant plus tard, par l'application elle-meme qui restaure sa PROPRE
    // position memorisee (Vivaldi dans ses Preferences, VS Code dans son
    // storage) — apres sa creation, pas au meme instant. Aucun minuteur
    // n'existe dans ce moteur de script (« typeof setTimeout » mesure
    // « undefined » ici, sur cette machine) : on regagne donc la course par
    // le NOMBRE de changements plutot que par le temps. Les premiers sont
    // l'application qui s'installe ; les suivants sont l'utilisateur qui
    // deplace ou redimensionne pour de vrai, et ceux-la on les laisse faire.
    var essaisRestants = 3;
    var reagir = function () {
        // Sans cette garde, l'ecriture d'« agrandir » ci-dessous rappellerait
        // ce meme gestionnaire — kwin et ce script se renverraient la
        // fenetre tant qu'il reste des essais.
        if (enTrainDeBorner) return;
        if (essaisRestants > 0 && estAgrandissable(f)) {
            essaisRestants -= 1;
            // NE REGAGNER LA COURSE QUE SI LA FENETRE EST VRAIMENT PETITE.
            //
            // BOGUE TROUVE LE 2026-08-30, RAPPORTE PAR L'UTILISATEUR : passer
            // une video en plein ecran ne devenait JAMAIS reellement plein
            // ecran — la barre disparaissait (le correctif « efface »
            // marchait), mais le contenu restait coince a la hauteur utile.
            // Cause : un vrai passage en plein ecran CHANGE AUSSI
            // frameGeometry, et ce changement peut arriver avant que
            // « f.fullScreen » lui-meme ne soit passe a vrai — « estAgran-
            // dissable » ne l'excluait donc pas encore, et « agrandir »
            // clouait la fenetre a « basUtile() » (sous la barre) au moment
            // meme ou elle grandissait vers l'ecran ENTIER. On ne regagne
            // donc que ce qui est reellement petit : une fenetre deja proche
            // de la taille utile n'a besoin de rien, et la laisser tranquille
            // laisse un vrai plein ecran se terminer.
            // « borner() » N'EST PAS APPELE NON PLUS DANS CETTE BRANCHE : une
            // fenetre qui a deja depasse la hauteur utile a cet instant precis
            // peut etre en train de grandir vers un vrai plein ecran (1080),
            // et « borner » la ramenerait aussitot a la hauteur utile (1028)
            // — exactement le clouage qu'on evite. Ne rien faire laisse la
            // transition se terminer ; si elle echoue vraiment a devenir
            // plein ecran, le prochain changement de geometrie ou
            // « fullScreenChanged »/« maximizedChanged » la rattrapera.
            var g = f.frameGeometry;
            var z = null;
            try { z = workspace.clientArea(KWin.FullScreenArea, f); } catch (e0) { }
            if (z && g && g.width >= z.width - 4 &&
                g.height >= (basUtile(f) - z.y) - 4) {
                return;
            }
            agrandir(f);
        } else {
            borner(f);
        }
    };
    try {
        f.frameGeometryChanged.connect(reagir);
    } catch (e) {
    }
    try {
        f.maximizedChanged.connect(function () { borner(f); });
    } catch (e2) {
    }
    try {
        f.fullScreenChanged.connect(function () { borner(f); });
    } catch (e3) {
    }
    borner(f);
}

function estMontrable(f) {
    if (!f) return false;
    if (!f.normalWindow) return false;
    if (f.skipTaskbar) return false;
    // Le bureau lui-meme n'a rien a faire dans sa propre barre des taches.
    if (String(f.resourceClass) === "s-constellation") return false;
    return true;
}

function decrire(f, montrable) {
    return {
        id: String(f.internalId),
        // CE QUE LA BARRE MONTRE, ET CE QUE LA VEILLE DOIT VOIR, NE SONT PAS
        // LA MEME LISTE. Le rapporteur n'envoyait que le montrable, et la
        // veille se retrouvait aveugle aux fenetres ecartees — mini-lecteur,
        // panneau utilitaire, surface au type inhabituel. Or elles partagent
        // la portee cgroup de la fenetre principale : geler celle-ci figeait
        // a l'ecran une surface visible que plus aucun clic ne reveillait. On
        // envoie donc tout, avec l'etiquette, et le tri se fait cote Python.
        montrable: (montrable === true),
        classe: String(f.resourceClass || ""),
        titre: String(f.caption || ""),
        active: (workspace.activeWindow === f),
        reduite: (f.minimized === true),
        // LE PID SORT D'ICI POUR LA VEILLE, ET LUI SEUL PEUT LE DIRE. Pour
        // endormir le programme d'une fenetre rangee, il faut remonter de la
        // fenetre au processus, puis du processus a sa portee cgroup. Le
        // premier pas n'appartient qu'au compositeur : un client Wayland ne
        // sait meme pas que les fenetres des autres existent.
        //
        // IL VAUT ZERO PLUS SOUVENT QU'ON NE CROIT, et le code qui le lit doit
        // le supporter : une fenetre X11 sans _NET_WM_PID, une surface posee
        // par un intermediaire. Zero veut dire « on ne sait pas », donc « on
        // n'y touche pas » — jamais « c'est le processus 0 ».
        pid: (f.pid || 0),
        // LE PLEIN ECRAN SORT D'ICI PARCE QUE PERSONNE D'AUTRE NE PEUT LE
        // SAVOIR. Un client Wayland ne voit pas l'etat des fenetres des
        // autres — c'est la raison meme de ce script. La barre laterale s'en
        // sert pour ne pas surgir par-dessus un jeu : une languette qui
        // s'ouvre au bord de l'ecran pendant une partie est exactement ce
        // qu'on ne veut pas.
        plein: (f.fullScreen === true)
    };
}

function envoyer() {
    var liste = workspace.windowList();
    var vues = [];
    for (var i = 0; i < liste.length; i++) {
        vues.push(decrire(liste[i], estMontrable(liste[i])));
    }
    callDBus("org.s.Constellation", "/fenetres", "org.s.Constellation",
             "Fenetres", JSON.stringify(vues));
}

// LA FENETRE SYSTEME D'ANDROID, MINIMISEE DES SA NAISSANCE — AJOUTE LE
// 2026-08-29 AU SOIR, PARCE QUE LA REGLE PERSISTANTE (kwinrulesrc,
// « minimize »/« minimizerule ») N'A PAS SUFFI. Mesure sur cette machine :
// la regle est bien ecrite et rechargee (reconfigure), et la fenetre
// « Waydroid » — celle que hwcomposer.waydroid.so cree TOUJOURS au
// demarrage, en reecrivant lui-meme « waydroid.active_apps » a « Waydroid »
// quel que soit ce que S avait pose avant (chaine trouvee en dur dans le
// binaire vendor, extrait de vendor.img par debugfs — rien cote S ne peut
// gagner cette course contre un binaire ferme) — reste PLEINE au premier
// demarrage silencieux, capture d'ecran a l'appui : la regle passive
// n'agit pas assez tot sur le tout premier rendu. Un script kwin, lui,
// AGIT plutot que de decrire une intention : « f.minimized = true », pose
// des l'evenement « windowAdded » — le tout premier instant ou kwin
// connait la fenetre — l'a fait disparaitre du rendu (verifie deux fois de
// suite par capture d'ecran complete). La regle kwinrulesrc reste posee en
// filet (skiptaskbar/skippager/skipswitcher fonctionnent, eux, par regle).
function cacherAndroidSysteme(f) {
    if (!f) return;
    if (String(f.resourceClass) !== "Waydroid") return;
    if (f.minimized) return;
    try {
        f.minimized = true;
    } catch (e) {
    }
}

// UN TITRE QUI CHANGE EST UN EVENEMENT DE BARRE DES TACHES : un navigateur qui
// change d'onglet ne cree pas de fenetre, il renomme la sienne. Sans ce
// branchement, la barre afficherait le titre de la premiere page pour toujours.
function suivre(f) {
    if (!f) return;
    cacherAndroidSysteme(f);
    agrandir(f);
    suivreGeometrie(f);
    try {
        f.captionChanged.connect(envoyer);
        f.minimizedChanged.connect(envoyer);
        f.skipTaskbarChanged.connect(envoyer);
    } catch (e) {
        // Une propriete absente dans une version de kwin ne doit pas emporter
        // le reste du branchement : on garde ce qui a marche.
    }
}

var deja = workspace.windowList();
for (var i = 0; i < deja.length; i++) suivre(deja[i]);

workspace.windowAdded.connect(function (f) { suivre(f); envoyer(); });
workspace.windowRemoved.connect(envoyer);

// LA BULLE VOLE L'ACTIVATION, MALGRE « Qt.WindowDoesNotAcceptFocus ». Mesure
// sur cette machine le 2026-08-30, avant/apres, VS Code deja actif :
//
//   avant notify-send :  activeWindow = code
//   1 s apres          :  activeWindow = s-constellation (la bulle)
//
// Le drapeau Qt empeche le vrai focus CLAVIER ; il n'empeche pas kwin de
// considerer la bulle comme la « fenetre activee » au sens du scripting —
// et c'est CE sens-la que la barre lit pour savoir qui surligner
// (« decrire() », plus haut : active = workspace.activeWindow === f). Chaque
// notification effacait donc le surlignage de la vraie fenetre en cours,
// et l'utilisateur la voyait « descendre » dans la barre.
//
// On ne corrige pas la bulle elle-meme — son drapeau est deja le bon geste,
// et Constellation n'a pas d'autre levier sur ce que kwin appelle
// « activee ». On rattrape ici : des que la fenetre qui vient de s'activer
// appartient a Constellation (bulle, bureau ou barre — aucune n'est une
// application), l'activation repart vers la derniere VRAIE fenetre.
var derniereFenetreReelle = null;

function estConstellation(f) {
    return !!f && String(f.resourceClass) === "s-constellation";
}

// SEULE LA BULLE VOLE LE FOCUS, PAS LES AUTRES FENETRES DE CONSTELLATION —
// ET LES CONFONDRE ETAIT LE BOGUE, TROUVE LE 2026-08-30 EN REJOUANT LE
// SCRIPT EN DIRECT SUR CETTE MACHINE, PAS EN RELISANT LE CODE.
//
// « estConstellation(f) » seul matche AUSSI le bureau, la barre et la barre
// laterale — les quatre fenetres partagent le meme resourceClass
// « s-constellation ». Le titre les distingue ; « TITRE_BULLE » dans
// regles-kwin.py est la meme chaine, recopiee ici a la main puisque deux
// scripts kwin independants (l'un en Python, l'autre en JS) ne partagent
// rien.
function estBulleNotification(f) {
    return estConstellation(f) && String(f.caption) === "S - notification";
}

workspace.windowActivated.connect(function (f) {
    // AVANT CE SOIR, LE GARDE PORTAIT SUR « estConstellation », PAS SUR LA
    // BULLE SEULE. Consequence mesuree en direct : « activerBureau() »
    // (le geste « montrer le bureau », et le menu Demarrer qui en depend)
    // pose « workspace.activeWindow = bureau », ce qui declenche CE MEME
    // gestionnaire avec f = le bureau — matche par « estConstellation »,
    // annule aussitot vers « derniereFenetreReelle ». Le bureau redevenait
    // donc inactif dans l'instant meme ou on demandait de l'activer :
    // « impossible d'aller sur la Constellation ».
    //
    // MEME MECANISME POUR LES FENETRES QUI NE SE MINIMISENT PLUS. Reduire la
    // fenetre active fait parfois transiter l'activation par le bureau, le
    // temps que kwin choisisse la suivante — un instant assez court pour ne
    // rien montrer a l'ecran, assez long pour que ce gestionnaire le voie et
    // rebascule vers « derniereFenetreReelle », c'est-a-dire la fenetre
    // qu'on venait justement de demander de ranger. Vu sur cette machine :
    // « avant=false » puis « apres=false » sur une demande de minimiser,
    // alors que le meme script rejoue seul, sans ce gestionnaire, minimise
    // pour de vrai.
    if (estBulleNotification(f)) {
        if (derniereFenetreReelle) {
            try {
                workspace.activeWindow = derniereFenetreReelle;
            } catch (e) {
                // La fenetre remembree a pu fermer entre-temps : rien a
                // rattraper, la prochaine vraie activation la remplacera.
            }
        }
        return;
    }
    // « derniereFenetreReelle » NE DOIT JAMAIS POINTER SUR UNE FENETRE DE
    // CONSTELLATION — sinon un jour ou la bulle vole vraiment le focus, on la
    // rebasculerait vers le bureau ou la barre plutot que vers une vraie
    // application. Le bureau et la barre, eux, ont quand meme le droit
    // d'etre actives ; on laisse juste passer l'evenement sans les retenir.
    if (!estConstellation(f)) {
        derniereFenetreReelle = f;
    }
    envoyer();
});

envoyer();
