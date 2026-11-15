#!/usr/bin/env node
// Le banc du rapporteur de fenetres : charge fenetres.js avec un kwin de
// carton, puis joue un debranchement de HDMI.
//
// POURQUOI UN BANC POUR UN SCRIPT KWIN. fenetres.js ne tourne que DANS le
// compositeur : on ne peut pas le charger hors de kwin pour verifier qu'il
// repond aux signaux. Mais son contrat est ecrit — quel evenement produit
// quels appels — et ce contrat se joue a la main : un « workspace » de carton
// qui garde des fenetres, des signaux qui gardent leurs gestionnaires, et des
// assertions sur ce que le rapporteur doit faire quand l'ecran HDMI disparait.
// Meme esprit que les verifiers QML : la construction doit echouer ICI plutot
// que sur le bureau de l'utilisateur.
//
// Lance : node banc-fenetres.js /chemin/vers/fenetres.js
// Rend 0 si tout tient, 1 sinon — et dit pourquoi sur la sortie d'erreur.

"use strict";

const fs = require("fs");
const vm = require("vm");

const chemin = process.argv[2];
if (!chemin || !fs.existsSync(chemin)) {
    console.error("ECHEC : fenetres.js introuvable (" + chemin + ")");
    process.exit(1);
}
const source = fs.readFileSync(chemin, "utf8");

// ── Les pieces de carton ────────────────────────────────────────────────────

function signal() {
    const gestionnaires = [];
    return {
        connect(fn) { gestionnaires.push(fn); },
        feu(arg) { for (const fn of gestionnaires) fn(arg); }
    };
}

// Une fenetre de carton : les proprietes que le rapporteur lit, une geometrie
// qui se laisse ecrire, des signaux qui se laissent brancher — et l'ecran ou
// kwin l'a posee, que clientArea rend tel quel.
function fenetre(spec) {
    let geometrie = { x: spec.x, y: spec.y, width: spec.width, height: spec.height };
    const f = {
        internalId: spec.internalId,
        resourceClass: spec.resourceClass,
        caption: spec.caption,
        pid: spec.pid || 0,
        minimized: !!spec.minimized,
        fullScreen: !!spec.fullScreen,
        normalWindow: spec.normalWindow !== false,
        skipTaskbar: !!spec.skipTaskbar,
        noBorder: !!spec.noBorder,
        popupWindow: false, tooltip: false, notification: false,
        dock: false, splash: false, utility: false,
        dialog: false, modal: false,
        maximized: false, maximizeMode: 0,
        closed: signal(), captionChanged: signal(), minimizedChanged: signal(),
        skipTaskbarChanged: signal(), fullScreenChanged: signal(),
        noBorderChanged: signal(), decorationChanged: signal(),
        frameGeometryChanged: signal(), maximizedChanged: signal(),
        ecran: spec.ecran
    };
    Object.defineProperty(f, "frameGeometry", {
        get() { return geometrie; },
        set(r) {
            geometrie = { x: r.x, y: r.y, width: r.width, height: r.height };
            spec.ecritures.push({ id: f.internalId, r: Object.assign({}, geometrie) });
        }
    });
    return f;
}

// ── Le monde d'un essai : le HDMI est debranche ─────────────────────────────
// kwin a deplace toutes les fenetres vers l'ecran du portable (1280x800) EN
// GARDANT LEURS COORDONNEES ABSOLUES de l'ecran parti (1920x1080 pose a
// droite) : le bureau a perdu le plein ecran, la barre git au milieu du vide.
// C'est l'etat exact rapporte par l'utilisateur le 2026-11-14.

const PORTABLE = { x: 0, y: 0, width: 1280, height: 800 };

function jouer(bloquerPleinEcran) {
    const ecritures = [];
    const dbusAppels = [];
    const fenetres = [
        fenetre({
            internalId: "b", resourceClass: "s-constellation",
            caption: "Constellation", fullScreen: false,
            x: 1280, y: 0, width: 1920, height: 1080,
            ecran: PORTABLE, ecritures
        }),
        fenetre({
            internalId: "t", resourceClass: "s-constellation",
            caption: "S - barre", fullScreen: false, skipTaskbar: true,
            x: 1280, y: 1028, width: 1920, height: 472,
            ecran: PORTABLE, ecritures
        }),
        fenetre({
            internalId: "l", resourceClass: "s-constellation",
            caption: "S - barre laterale", fullScreen: false, skipTaskbar: true,
            x: 2560, y: 0, width: 360, height: 1080,
            ecran: PORTABLE, ecritures
        }),
        fenetre({
            internalId: "n", resourceClass: "s-constellation",
            caption: "S - notification (bas)", fullScreen: false, skipTaskbar: true,
            x: 2844, y: 756, width: 364, height: 220,
            ecran: PORTABLE, ecritures
        }),
        fenetre({
            internalId: "v", resourceClass: "vivaldi-stable",
            caption: "Vivaldi", fullScreen: false,
            // Posee assez haut pour que le bornage ordinaire (la barre
            // reserve ses 52 derniers pixels, comportement de longue date)
            // n'ait pas a la raccourcir : le banc doit mesurer le
            // rattrapage de l'ecran, pas re-mesurer le bornage.
            x: 1300, y: 40, width: 1000, height: 600,
            ecran: PORTABLE, ecritures
        })
    ];
    if (bloquerPleinEcran) {
        // Un kwin qui n'offre pas l'ecriture de fullScreen : le rapporteur
        // doit alors remplir la zone de l'ecran a la main.
        Object.defineProperty(fenetres[0], "fullScreen", {
            get() { return false; }
        });
    }
    const screensChanged = signal();
    const workspace = {
        windowList() { return fenetres.slice(); },
        activeWindow: null,
        clientArea(zone, f) { return f.ecran; },
        raiseWindow() {},
        windowActivated: signal(), windowAdded: signal(),
        windowRemoved: signal(), screensChanged
    };
    const contexte = {
        workspace,
        KWin: { FullScreenArea: 1, MaximizeArea: 2 },
        callDBus(service, cheminBus, interfaceBus, methode, arg) {
            dbusAppels.push({
                service, cheminBus, interfaceBus, methode,
                arg: arg !== undefined ? String(arg) : ""
            });
        },
        console
    };
    vm.runInNewContext(source, contexte, { filename: chemin });
    screensChanged.feu();
    return { fenetres, ecritures, dbusAppels };
}

// ── Les assertions ──────────────────────────────────────────────────────────

function geometrieDe(essai, id) {
    const poses = essai.ecritures.filter(function (e) { return e.id === id; });
    return poses.length ? poses[poses.length - 1].r : null;
}

function presque(r, x, y, l, h) {
    return !!r && r.x === x && r.y === y && r.width === l && r.height === h;
}

const echecs = [];
function rater(phrase) {
    echecs.push(phrase);
    console.error("ECHEC : " + phrase);
}

function verifierUnDebranchement(bloquerPleinEcran, nom) {
    const essai = jouer(bloquerPleinEcran);

    // Le bureau reprend le plein ecran — par le drapeau si kwin l'offre,
    // par la geometrie sinon. Jamais les deux : la geometrie forcee n'a de
    // sens que si le drapeau ne prend pas.
    const bureau = essai.fenetres[0];
    if (bloquerPleinEcran) {
        if (bureau.fullScreen)
            rater(nom + " : le bureau ne devrait pas etre plein ecran (kwin muet)");
        if (!presque(geometrieDe(essai, "b"), 0, 0, 1280, 800))
            rater(nom + " : le bureau ne remplit pas l'ecran restant a la main");
    } else {
        if (bureau.fullScreen !== true)
            rater(nom + " : le bureau n'a pas repris le plein ecran");
        if (geometrieDe(essai, "b") !== null)
            rater(nom + " : le bureau n'avait pas besoin d'une geometrie forcee");
    }

    // LE CHROME NE SE REPOSITIONNE PLUS — depuis le 2026-11-14, la barre, la
    // barre laterale et la bulle sont des surfaces de couche (s-chrome) : le
    // compositeur les re-ancre lui-meme quand un ecran change. Le script ne
    // doit donc plus ecrire LEUR geometrie, jamais.
    for (const id of ["t", "l", "n"]) {
        if (geometrieDe(essai, id) !== null)
            rater(nom + " : la fenetre " + id + " du chrome a ete deplacee — "
                  + "les surfaces de couche se re-ancrent toutes seules");
    }

    // Une vraie fenetre n'est jamais touchee par le rattrapage de la coquille.
    if (geometrieDe(essai, "v") !== null)
        rater(nom + " : la fenetre Vivaldi a ete deplacee par le rattrapage");

    // Le pont est prevenu de reposer les regles pour la nouvelle taille —
    // il ne reste que la fenetre Android a centrer par regle.
    const note = essai.dbusAppels.filter(function (a) { return a.methode === "Ecran"; });
    if (note.length !== 1)
        rater(nom + " : aucun callDBus Ecran apres le debranchement");
    else {
        let lu = null;
        try { lu = JSON.parse(note[0].arg); } catch (e) { /* laisse lu a null */ }
        if (!lu || lu.largeur !== 1280 || lu.hauteur !== 800)
            rater(nom + " : la note Ecran ne porte pas la taille de l'ecran restant (" + note[0].arg + ")");
    }

    // Le rapporteur parle encore au pont une fois le chrome repose.
    const vues = essai.dbusAppels.filter(function (a) { return a.methode === "Fenetres"; });
    if (vues.length === 0)
        rater(nom + " : le rapporteur n'a plus rien envoye apres le debranchement");
}

verifierUnDebranchement(false, "debranchement, kwin qui obeit");
verifierUnDebranchement(true, "debranchement, kwin muet sur fullScreen");

if (echecs.length) {
    console.error("banc fenetres : " + echecs.length + " echec(s)");
    process.exit(1);
}
console.log("banc fenetres : le debranchement est rattrape, les deux kwin");

