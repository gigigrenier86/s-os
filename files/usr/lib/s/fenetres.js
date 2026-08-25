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

function estMontrable(f) {
    if (!f) return false;
    if (!f.normalWindow) return false;
    if (f.skipTaskbar) return false;
    // Le bureau lui-meme n'a rien a faire dans sa propre barre des taches.
    if (String(f.resourceClass) === "s-constellation") return false;
    return true;
}

function decrire(f) {
    return {
        id: String(f.internalId),
        classe: String(f.resourceClass || ""),
        titre: String(f.caption || ""),
        active: (workspace.activeWindow === f),
        reduite: (f.minimized === true)
    };
}

function envoyer() {
    var liste = workspace.windowList();
    var vues = [];
    for (var i = 0; i < liste.length; i++) {
        if (estMontrable(liste[i])) vues.push(decrire(liste[i]));
    }
    callDBus("org.s.Constellation", "/fenetres", "org.s.Constellation",
             "Fenetres", JSON.stringify(vues));
}

// UN TITRE QUI CHANGE EST UN EVENEMENT DE BARRE DES TACHES : un navigateur qui
// change d'onglet ne cree pas de fenetre, il renomme la sienne. Sans ce
// branchement, la barre afficherait le titre de la premiere page pour toujours.
function suivre(f) {
    if (!f) return;
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
workspace.windowActivated.connect(envoyer);

envoyer();
