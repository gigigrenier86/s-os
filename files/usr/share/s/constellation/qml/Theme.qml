pragma Singleton
import QtQuick
import "Couleurs.js" as C
import "Fonds.js" as F

// LES TROIS THEMES DE S — Constellation, Windows 11, et une tablette Android
// (Material You). Un seul endroit : si une couleur change, elle change partout.
//
// ═══ CE QUI CHANGE D'UN THEME A L'AUTRE, ET CE QUI NE CHANGE PAS ═════════════
//
// Les ROLES ne changent pas : « verre » est toujours le fond d'un panneau,
// « texte2 » toujours un texte secondaire, « accent » toujours ce qui dit « ici,
// c'est actif ». Chaque piece de la coquille lit ces roles, et c'est ce qui
// permet de changer de theme EN DIRECT, sans redemarrer quoi que ce soit : il
// suffit de poser « nom », et toutes les liaisons se reevaluent.
//
// En Constellation, chaque valeur est EXACTEMENT celle d'avant les themes,
// reprise des variables CSS de la page d'origine — le theme par defaut ne doit
// pas changer d'un pixel pour quelqu'un qui n'a rien demande.
//
// ═══ CE QUI EST EMPRUNTE, ET CE QUI NE L'EST PAS ═════════════════════════════
//
// Ni logo, ni fond d'ecran, ni police de Microsoft ou de Google n'entre dans
// cette image : le depot est public. Les fonds sont peints ici (Fonds.js), et
// les polices sont CHERCHEES sur la machine dans l'ordre de preference — Segoe
// UI si quelqu'un l'a installee chez lui, sinon Open Sans, dessinee par le meme
// typographe (Steve Matteson) et tres proche a l'oeil ; Google Sans si elle est
// la, sinon Roboto, la police d'Android.
QtObject {
    id: theme

    // ── L'ETAT, POSE PAR LE BUREAU A L'OUVERTURE ET A CHAQUE CHANGEMENT ──────
    // Rien ici ne lit le disque : Constellation.qml relit les reglages du pont
    // et les depose. Un singleton qui irait chercher lui-meme ses reglages
    // aurait deux sources de verite pour la meme chose.
    property string nom: "constellation"
    property string fondConstellation: "nebuleuse"
    property string fondWindows: "floraison"
    property string fondAndroid: "formes"
    property bool sombreWindows: false
    property bool sombreAndroid: false
    // Vide = automatique : l'accent vient du fond d'ecran.
    property string accentWindows: ""
    property string graineAndroid: ""
    // La couleur dominante d'une IMAGE choisie comme fond, mesuree une fois au
    // choix par le pont (voir Pont.analyserImage) et gardee dans les
    // reglages — la remesurer a chaque ouverture coute un decodage d'image.
    property string teinteWindows: ""
    property string teinteAndroid: ""
    // Et si cette image est CLAIRE dans l'ensemble — mesure en meme temps.
    property bool clairWindows: false
    property bool clairAndroid: false
    property bool cielVivant: true

    readonly property bool estWindows: nom === "windows"
    readonly property bool estAndroid: nom === "android"
    readonly property bool estConstellation: !estWindows && !estAndroid
    readonly property bool sombre: estConstellation ? true
                                 : (estWindows ? sombreWindows : sombreAndroid)

    // ── LE FOND COURANT ─────────────────────────────────────────────────────
    readonly property string fondId: estWindows ? fondWindows
                                   : (estAndroid ? fondAndroid : fondConstellation)
    readonly property bool fondEstImage: fondId.indexOf("image:") === 0
    readonly property string fondImage: fondEstImage ? fondId.substring(6) : ""
    readonly property var fondDecrit: F.FONDS[fondId] || null

    // ── LES COULEURS SOURCES ────────────────────────────────────────────────
    readonly property string graine: {
        if (graineAndroid !== "") return graineAndroid;
        if (fondEstImage && teinteAndroid !== "") return teinteAndroid;
        if (fondDecrit && fondDecrit.graine) return fondDecrit.graine;
        return "#6750A4";
    }
    readonly property var palette: C.schemaMaterial(graine, sombre)

    readonly property string accentBase: {
        if (accentWindows !== "") return accentWindows;
        if (fondEstImage && teinteWindows !== "") return teinteWindows;
        if (fondDecrit && fondDecrit.accent) return fondDecrit.accent;
        return "#0078D4";
    }
    readonly property string accentCalcule: C.accentWindows(accentBase, sombre)

    // Ce que les fonds peints recoivent pour se colorer : la graine d'Android,
    // l'accent de Windows, et le mode. Un objet, pour que le jour ou un fond
    // aura besoin d'une valeur de plus, aucune signature ne change.
    readonly property var optionsFond: ({
        sombre: sombre,
        graine: graine,
        accent: accentBase
    })

    // ── LES QUATRE COULEURS DE S ────────────────────────────────────────────
    // Elles disent D'OU vient un logiciel. Sur un fond clair, les memes teintes
    // un cran plus sombres : un liseré #4dff88 sur du blanc ne se voit plus.
    readonly property color linux:    sombre ? "#ff4d4d" : "#d32f2f"
    readonly property color windows:  sombre ? "#4da6ff" : "#1565c0"
    readonly property color android:  sombre ? "#4dff88" : "#2e7d32"
    // LE QUATRIEME N'EST PAS UN MONDE, ET C'EST POURQUOI IL FALLAIT UNE
    // COULEUR DE PLUS. Rouge, bleu et vert disent D'OU vient un logiciel. Le
    // jaune ne dit pas d'ou vient un fichier : il dit que ce n'en est pas un.
    // Meme famille que les trois autres — deux canaux hauts, un a 0x4d — pour
    // qu'il se lise comme un pair et non comme une alerte.
    readonly property color fichier:  sombre ? "#ffd24d" : "#b8860b"

    // ── LES ROLES ───────────────────────────────────────────────────────────
    readonly property color espace: estWindows ? (sombre ? "#202020" : "#f3f3f3")
                                  : (estAndroid ? palette.surface : "#050510")

    // Le fond des menus et des panneaux flottants.
    readonly property color verre: estWindows
        ? (sombre ? Qt.rgba(44 / 255, 44 / 255, 44 / 255, 0.97)
                  : Qt.rgba(249 / 255, 249 / 255, 249 / 255, 0.97))
        : (estAndroid ? palette.surfaceContainer
                      : Qt.rgba(12 / 255, 12 / 255, 20 / 255, 0.86))
    // Le fond d'un grand panneau : le menu Demarrer, le tiroir d'applications.
    readonly property color panneau: estWindows
        ? (sombre ? Qt.rgba(36 / 255, 36 / 255, 36 / 255, 0.86)
                  : Qt.rgba(238 / 255, 238 / 255, 238 / 255, 0.82))
        : (estAndroid ? palette.surfaceContainerLow : verre)
    // Une carte posee DANS un panneau (les sections du menu Windows, une tuile).
    readonly property color carte: estWindows
        ? (sombre ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.70))
        : (estAndroid ? palette.surfaceContainerHigh : Qt.rgba(1, 1, 1, 0.045))

    // Le survol (« verre2 ») et l'appui (« verre3 »). Material appelle cela des
    // « calques d'etat » : la couleur du texte, a 8 % et 12 %.
    readonly property color verre2: estWindows
        ? (sombre ? Qt.rgba(1, 1, 1, 0.0605) : Qt.rgba(0, 0, 0, 0.0373))
        : (estAndroid ? C.alpha(palette.onSurface, 0.08) : Qt.rgba(1, 1, 1, 0.045))
    readonly property color verre3: estWindows
        ? (sombre ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06))
        : (estAndroid ? C.alpha(palette.onSurface, 0.12) : Qt.rgba(1, 1, 1, 0.12))
    readonly property color bord: estWindows
        ? (sombre ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.0578))
        : (estAndroid ? palette.outlineVariant : Qt.rgba(1, 1, 1, 0.09))
    readonly property color bordVif: estWindows
        ? (sombre ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.16))
        : (estAndroid ? palette.outline : Qt.rgba(1, 1, 1, 0.22))

    readonly property color texte: estWindows
        ? (sombre ? "#ffffff" : Qt.rgba(0, 0, 0, 0.894))
        : (estAndroid ? palette.onSurface : "#eef0f6")
    readonly property color texte2: estWindows
        ? (sombre ? Qt.rgba(1, 1, 1, 0.786) : Qt.rgba(0, 0, 0, 0.606))
        : (estAndroid ? palette.onSurfaceVariant
                      : Qt.rgba(238 / 255, 240 / 255, 246 / 255, 0.62))
    readonly property color texte3: estWindows
        ? (sombre ? Qt.rgba(1, 1, 1, 0.544) : Qt.rgba(0, 0, 0, 0.446))
        : (estAndroid ? palette.outline
                      : Qt.rgba(238 / 255, 240 / 255, 246 / 255, 0.34))
    readonly property color lien: estConstellation ? Qt.rgba(1, 1, 1, 0.16) : bord
    readonly property color lienVif: estConstellation ? Qt.rgba(1, 1, 1, 0.55) : accent

    // CE QUI DIT « ICI, C'EST ACTIF ». En Constellation il n'y a pas d'accent :
    // le blanc voile fait ce travail depuis le premier jour (le jour courant du
    // calendrier, l'onglet choisi), on le garde.
    readonly property color accent: estWindows ? accentCalcule
                                  : (estAndroid ? palette.primary
                                                : Qt.rgba(1, 1, 1, 0.55))
    readonly property color surAccent: estWindows ? C.surCouleur(accentCalcule)
                                     : (estAndroid ? palette.onPrimary : "#050510")
    // Le fond doux d'un element choisi : un bouton allume, une tuile active.
    readonly property color accentDoux: estWindows
        ? C.alpha(accentCalcule, sombre ? 0.22 : 0.16)
        : (estAndroid ? palette.primaryContainer : Qt.rgba(1, 1, 1, 0.12))
    readonly property color surAccentDoux: estWindows ? texte
                                         : (estAndroid ? palette.onPrimaryContainer : texte)

    // LA BARRE DES TACHES. En Windows, une teinte posee sur le fond flou (le
    // « Mica ») ; en Android, rien — le dock flotte sur le fond d'ecran.
    readonly property color barreTeinte: estWindows
        ? (sombre ? Qt.rgba(32 / 255, 32 / 255, 32 / 255, 0.82)
                  : Qt.rgba(243 / 255, 243 / 255, 243 / 255, 0.80))
        : (estAndroid ? "transparent" : Qt.rgba(12 / 255, 12 / 255, 20 / 255, 0.97))
    // Les ombres portees. Constellation n'en a jamais eu : ses panneaux sont du
    // verre sur un ciel noir, une ombre n'y aurait rien a assombrir.
    readonly property color ombre: estConstellation ? "transparent"
        : (sombre ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(0, 0, 0, 0.16))

    // LE TEXTE DES ICONES DU BUREAU SE LIT SUR LE FOND D'ECRAN, pas sur un
    // panneau : il suit donc la clarte du FOND, pas le mode. Blanc ombre sur un
    // fond sombre ; presque noir, au halo clair, sur un fond clair — le blanc
    // de Windows y etait illisible, releve sur le rendu du 2026-10-20 (la
    // floraison claire). Un fond peint est clair quand le mode est clair ; une
    // image se juge a sa clarte moyenne, mesuree au choix (Pont.analyserImage).
    readonly property bool fondClair: {
        if (estConstellation) return false;
        if (fondEstImage) return estWindows ? clairWindows : clairAndroid;
        return !sombre;
    }
    readonly property color texteBureau: estConstellation ? texte2
        : (fondClair ? (estAndroid ? palette.onSurface : "#1c1c1c") : "#ffffff")
    readonly property color ombreTexteBureau: estConstellation ? Qt.rgba(0, 0, 0, 0.9)
        : (fondClair ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(0, 0, 0, 0.62))

    // ── LES FORMES ──────────────────────────────────────────────────────────
    readonly property int rayon:       estWindows ? 8 : (estAndroid ? 28 : 12)
    readonly property int rayonPetit:  estWindows ? 4 : (estAndroid ? 20 : 8)
    readonly property int rayonMenu:   estWindows ? 8 : (estAndroid ? 12 : 8)
    readonly property int hauteurArticle: estWindows ? 34 : (estAndroid ? 44 : 34)
    readonly property int taillePolice:  estAndroid ? 14 : 13
    readonly property int sphere:     40

    // Le bureau en grille, hors Constellation. « cellule » est la place d'une
    // icone et de son nom ; « origine » est le coin d'ou la grille part — plus
    // bas en Android, ou l'horloge et la recherche tiennent le haut de l'ecran.
    readonly property int celluleL:    estAndroid ? 104 : 84
    readonly property int celluleH:    estAndroid ? 112 : 96
    readonly property int iconeBureau: estAndroid ? 54 : 44
    readonly property int origineX:    estAndroid ? 40 : 6
    readonly property int origineY:    estAndroid ? 176 : 6

    // ── LE MOUVEMENT ────────────────────────────────────────────────────────
    // Constantes d'animation harmonisées (micro-interactions tactiles & fluidité)
    // Windows est vif et se pose net ; Material prend son temps et freine fort.
    readonly property int dureePression: estWindows ? 80 : (estAndroid ? 90 : 100)
    readonly property int dureeRapide:   estWindows ? 120 : (estAndroid ? 150 : 140)
    readonly property int dureeNormale:  estWindows ? 187 : (estAndroid ? 300 : 200)
    readonly property int dureeRessort:  estWindows ? 250 : (estAndroid ? 420 : 260)
    readonly property int courbe: estConstellation ? Easing.OutCubic : Easing.OutQuint

    // ── LES POLICES ─────────────────────────────────────────────────────────
    // Relevees une fois : la liste des polices ne change pas pendant la session.
    readonly property var familles: Qt.fontFamilies()
    function premiere(liste) {
        for (var i = 0; i < liste.length; i++)
            if (familles.indexOf(liste[i]) >= 0)
                return liste[i];
        return liste[liste.length - 1];
    }
    readonly property string policeWindows: premiere([
        "Segoe UI Variable Text", "Segoe UI Variable Display", "Segoe UI",
        "Selawik", "Open Sans", "Noto Sans"])
    readonly property string policeAndroid: premiere([
        "Google Sans Flex", "Google Sans Text", "Google Sans", "Product Sans",
        "Roboto Flex", "Roboto", "Noto Sans"])
    readonly property string police: estWindows ? policeWindows
                                   : (estAndroid ? policeAndroid : "IBM Plex Sans")
    readonly property string policeMono: estConstellation ? "IBM Plex Mono" : police

    // ── LES REGLAGES D'UN AUTRE THEME QUE LE COURANT ────────────────────────
    // Pour les apercus : la carte « Windows 11 » d'un bureau en Constellation
    // doit montrer le fond et les couleurs que Windows AURAIT, pas ceux du
    // theme qu'on regarde.
    function fondPour(cle) {
        return cle === "windows" ? fondWindows
             : (cle === "android" ? fondAndroid : fondConstellation);
    }
    function sombrePour(cle) {
        return cle === "windows" ? sombreWindows
             : (cle === "android" ? sombreAndroid : true);
    }
    function optionsPour(cle) {
        var fid = fondPour(cle);
        var image = fid.indexOf("image:") === 0;
        var f = F.FONDS[fid];
        var gr = graineAndroid !== "" ? graineAndroid
               : ((image && teinteAndroid !== "") ? teinteAndroid
               : ((f && f.graine) ? f.graine : "#6750A4"));
        var ac = accentWindows !== "" ? accentWindows
               : ((image && teinteWindows !== "") ? teinteWindows
               : ((f && f.accent) ? f.accent : "#0078D4"));
        return { sombre: sombrePour(cle), graine: gr, accent: ac };
    }

    // Les options d'une VIGNETTE de fond du theme courant : chaque fond peint
    // avec sa propre couleur, sauf si l'utilisateur en a impose une — alors
    // toutes les vignettes la prennent, et l'on voit d'avance ce qu'on aura.
    function optionsVignette(id) {
        var f = F.FONDS[id];
        var gr = graineAndroid !== "" ? graineAndroid : ((f && f.graine) ? f.graine : "#6750A4");
        var ac = accentWindows !== "" ? accentWindows : ((f && f.accent) ? f.accent : "#0078D4");
        return { sombre: sombre, graine: gr, accent: ac };
    }

    // ── LES DATES, EN FRANCAIS, SANS DEPENDRE DE LA LANGUE DU SYSTEME ───────
    // « Qt.formatDate » suit la locale du processus : le banc de construction
    // ecrivait « Tue 20 Oct ». Un format ecrit ici ne change pas avec elle —
    // meme choix que le calendrier de la barre.
    readonly property var joursCourts: ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
    readonly property var moisCourts: ["janv.", "févr.", "mars", "avr.", "mai", "juin",
                                       "juil.", "août", "sept.", "oct.", "nov.", "déc."]
    function dateCourteFr(d) {
        return joursCourts[d.getDay()] + " " + d.getDate() + " " + moisCourts[d.getMonth()];
    }

    // ── LES NOMS, POUR LE DIRE A L'UTILISATEUR ──────────────────────────────
    readonly property var themes: [
        { cle: "constellation", nom: "Constellation", detail: "le ciel de S" },
        { cle: "windows", nom: "Windows 11", detail: "barre centree, Mica" },
        { cle: "android", nom: "Tablette Android", detail: "Material You" }
    ]
    function nomDuTheme(cle) {
        for (var i = 0; i < themes.length; i++)
            if (themes[i].cle === cle) return themes[i].nom;
        return cle;
    }

    // Pose tout ce que le pont a rendu. Une valeur absente garde la sienne, une
    // valeur inconnue pour « theme » retombe sur Constellation : un fichier
    // bricole a la main ne doit jamais laisser le bureau sans theme.
    function charger(r) {
        if (!r) return;
        if (r.fond) fondConstellation = String(r.fond);
        if (r.fond_windows) fondWindows = String(r.fond_windows);
        if (r.fond_android) fondAndroid = String(r.fond_android);
        if (r.sombre_windows !== undefined) sombreWindows = r.sombre_windows === true;
        if (r.sombre_android !== undefined) sombreAndroid = r.sombre_android === true;
        if (r.accent_windows !== undefined) accentWindows = String(r.accent_windows || "");
        if (r.graine_android !== undefined) graineAndroid = String(r.graine_android || "");
        if (r.teinte_windows !== undefined) teinteWindows = String(r.teinte_windows || "");
        if (r.teinte_android !== undefined) teinteAndroid = String(r.teinte_android || "");
        if (r.clair_windows !== undefined) clairWindows = r.clair_windows === true;
        if (r.clair_android !== undefined) clairAndroid = r.clair_android === true;
        if (r.ciel_vivant !== undefined) cielVivant = r.ciel_vivant !== false;
        var t = String(r.theme || "constellation");
        nom = (t === "windows" || t === "android") ? t : "constellation";
    }

    // LES QUATRE COULEURS DE S, EN LISTE. Rouge Linux, bleu Windows, vert
    // Android, jaune fichier : c'est toute la palette du systeme, et la barre
    // laterale y pioche a chaque ouverture. Un reglage n'appartient a aucun
    // monde — il n'a donc pas de couleur PROPRE, et lui en donner une fixe
    // mentirait sur ce que la couleur veut dire partout ailleurs.
    readonly property var mondes: [linux, windows, android, fichier]

    // Un tirage qui EVITE LA REPETITION IMMEDIATE. Un aleatoire pur pose deux
    // fois la meme teinte cote a cote une fois sur quatre, et la colonne y perd
    // la lisibilite qu'on lui cherchait — deux ronds voisins de la meme couleur
    // se lisent comme un groupe, ce qu'ils ne sont pas.
    function tirage(combien) {
        var sortie = [];
        var precedente = -1;
        for (var i = 0; i < combien; i++) {
            var n = Math.floor(Math.random() * mondes.length);
            if (n === precedente) n = (n + 1 + Math.floor(Math.random() * 3))
                                     % mondes.length;
            precedente = n;
            sortie.push(mondes[n]);
        }
        return sortie;
    }

    // La couleur d'un monde. Elle dit d'ou vient un logiciel, et c'est la
    // seule information que l'utilisateur lit avant le nom.
    function teinte(src) {
        if (src === "windows") return windows;
        if (src === "android") return android;
        if (src === "fichier") return fichier;
        return linux;
    }
}
