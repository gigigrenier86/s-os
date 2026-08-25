.pragma library

// Les fonds de Constellation — portes MOT POUR MOT depuis la page d'origine
// (galerie/constellation/constellation.html, fonction FONDS).
//
// POURQUOI CE FICHIER EST UNE COPIE ET NON UNE REECRITURE. Le contexte 2D de
// QML Canvas expose la meme API que celui d'un navigateur : fillRect,
// createRadialGradient, createLinearGradient, arc, globalAlpha. Ces peintures
// avaient deja ete reglees a l'oeil ; les redessiner « proprement » en
// QtQuick.Shapes aurait change le rendu sans que personne ne l'ait demande.
//
// Le semis d'etoiles reste DETERMINISTE, et c'est la remarque du carnet : un
// ciel qui se redistribue a chaque redimensionnement de fenetre n'est pas un
// ciel, c'est du bruit.

function etoiles(g, w, h, densite) {
    var s = 20260821;
    var al = function () { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
    var n = Math.round((w * h) / 6000 * densite);
    for (var i = 0; i < n; i++) {
        var t = al();
        g.globalAlpha = 0.14 + al() * 0.55;
        g.fillStyle = "#fff";
        g.beginPath();
        g.arc(al() * w, al() * h, t < 0.88 ? 0.6 : (t < 0.985 ? 1.0 : 1.6), 0, 6.2832);
        g.fill();
    }
    g.globalAlpha = 1;
}

var FONDS = {
    nebuleuse: { nom: "Nebuleuse", peindre: function (g, w, h) {
        g.fillStyle = "#050510"; g.fillRect(0, 0, w, h);
        var taches = [
            [0.24, 0.30, 0.62, "77,110,255"], [0.76, 0.22, 0.50, "255,77,120"],
            [0.60, 0.78, 0.58, "60,220,180"], [0.12, 0.82, 0.42, "150,80,255"]
        ];
        for (var i = 0; i < taches.length; i++) {
            var px = taches[i][0], py = taches[i][1], pr = taches[i][2], c = taches[i][3];
            var r = Math.max(w, h) * pr;
            var d = g.createRadialGradient(w * px, h * py, 0, w * px, h * py, r);
            d.addColorStop(0, "rgba(" + c + ",0.17)");
            d.addColorStop(0.45, "rgba(" + c + ",0.05)");
            d.addColorStop(1, "rgba(" + c + ",0)");
            g.fillStyle = d; g.fillRect(0, 0, w, h);
        }
        etoiles(g, w, h, 1);
    }},
    vide: { nom: "Espace profond", peindre: function (g, w, h) {
        g.fillStyle = "#050510"; g.fillRect(0, 0, w, h);
        etoiles(g, w, h, 1.25);
    }},
    aube: { nom: "Aube", peindre: function (g, w, h) {
        var d = g.createLinearGradient(0, h, 0, 0);
        d.addColorStop(0, "#2a1230"); d.addColorStop(0.45, "#12102a"); d.addColorStop(1, "#04040c");
        g.fillStyle = d; g.fillRect(0, 0, w, h);
        etoiles(g, w, h, 0.7);
    }},
    grille: { nom: "Grille", peindre: function (g, w, h) {
        g.fillStyle = "#06070d"; g.fillRect(0, 0, w, h);
        g.strokeStyle = "rgba(255,255,255,0.045)"; g.lineWidth = 1;
        g.beginPath();
        for (var x = 0; x < w; x += 46) { g.moveTo(x + 0.5, 0); g.lineTo(x + 0.5, h); }
        for (var y = 0; y < h; y += 46) { g.moveTo(0, y + 0.5); g.lineTo(w, y + 0.5); }
        g.stroke();
        var d2 = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) * 0.7);
        d2.addColorStop(0, "rgba(0,0,0,0)"); d2.addColorStop(1, "rgba(0,0,0,0.75)");
        g.fillStyle = d2; g.fillRect(0, 0, w, h);
    }},
    encre: { nom: "Encre", peindre: function (g, w, h) {
        g.fillStyle = "#0a0a0c"; g.fillRect(0, 0, w, h);
        etoiles(g, w, h, 0.5);
    }},
    trois: { nom: "Trois mondes", peindre: function (g, w, h) {
        g.fillStyle = "#050510"; g.fillRect(0, 0, w, h);
        var t = [["255,77,77", 0.18, 0.30], ["77,166,255", 0.50, 0.22], ["77,255,136", 0.82, 0.32]];
        for (var i = 0; i < t.length; i++) {
            var c = t[i][0], px = t[i][1], py = t[i][2];
            var r = Math.max(w, h) * 0.52;
            var d = g.createRadialGradient(w * px, h * py, 0, w * px, h * py, r);
            d.addColorStop(0, "rgba(" + c + ",0.15)");
            d.addColorStop(0.5, "rgba(" + c + ",0.035)");
            d.addColorStop(1, "rgba(" + c + ",0)");
            g.fillStyle = d; g.fillRect(0, 0, w, h);
        }
        etoiles(g, w, h, 0.9);
    }}
};

var ORDRE = ["nebuleuse", "vide", "aube", "grille", "encre", "trois"];
