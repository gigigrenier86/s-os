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
    }},
    aurore: { nom: "Cyber-Aurore", peindre: function (g, w, h) {
        g.fillStyle = "#030613"; g.fillRect(0, 0, w, h);
        var rMax = Math.max(w, h);
        var voiles = [
            [0.20, 0.40, 0.70, "38,240,165", 0.16],
            [0.55, 0.25, 0.65, "30,200,255", 0.14],
            [0.85, 0.45, 0.60, "175,55,255", 0.13],
            [0.40, 0.65, 0.50, "50,255,200", 0.10]
        ];
        for (var i = 0; i < voiles.length; i++) {
            var v = voiles[i];
            var d = g.createRadialGradient(w * v[0], h * v[1], 0, w * v[0], h * v[1], rMax * v[2]);
            d.addColorStop(0, "rgba(" + v[3] + "," + v[4] + ")");
            d.addColorStop(0.5, "rgba(" + v[3] + "," + (v[4] * 0.3) + ")");
            d.addColorStop(1, "rgba(" + v[3] + ",0)");
            g.fillStyle = d; g.fillRect(0, 0, w, h);
        }
        etoiles(g, w, h, 1.1);
    }},
    ambre: { nom: "Astrolabe", peindre: function (g, w, h) {
        var bg = g.createLinearGradient(0, h, 0, 0);
        bg.addColorStop(0, "#160a03"); bg.addColorStop(0.5, "#0b0507"); bg.addColorStop(1, "#040205");
        g.fillStyle = bg; g.fillRect(0, 0, w, h);
        var rMax = Math.max(w, h);
        var d1 = g.createRadialGradient(w * 0.3, h * 0.4, 0, w * 0.3, h * 0.4, rMax * 0.55);
        d1.addColorStop(0, "rgba(255,160,45,0.14)");
        d1.addColorStop(0.6, "rgba(220,80,30,0.03)");
        d1.addColorStop(1, "rgba(220,80,30,0)");
        g.fillStyle = d1; g.fillRect(0, 0, w, h);

        g.strokeStyle = "rgba(255,190,80,0.07)";
        g.lineWidth = 1;
        var cx = w * 0.72, cy = h * 0.38;
        var rayons = [rMax * 0.15, rMax * 0.28, rMax * 0.42];
        for (var r = 0; r < rayons.length; r++) {
            g.beginPath();
            g.arc(cx, cy, rayons[r], 0, 6.2832);
            g.stroke();
        }
        g.beginPath();
        g.moveTo(cx - rMax * 0.45, cy + rMax * 0.25);
        g.lineTo(cx + rMax * 0.45, cy - rMax * 0.25);
        g.stroke();
        etoiles(g, w, h, 0.85);
    }},
    neotokyo: { nom: "Neo-Tokyo", peindre: function (g, w, h) {
        g.fillStyle = "#030307"; g.fillRect(0, 0, w, h);
        var rMax = Math.max(w, h);
        var colonnes = [
            [0.18, "255,35,135", 0.12, 0.18],
            [0.38, "0,225,255",  0.10, 0.15],
            [0.68, "255,35,135", 0.09, 0.16],
            [0.84, "120,60,255", 0.11, 0.20]
        ];
        for (var i = 0; i < colonnes.length; i++) {
            var col = colonnes[i];
            var d = g.createRadialGradient(w * col[0], h * 0.5, 0, w * col[0], h * 0.5, rMax * col[3]);
            d.addColorStop(0, "rgba(" + col[1] + "," + col[2] + ")");
            d.addColorStop(0.6, "rgba(" + col[1] + ",0.02)");
            d.addColorStop(1, "rgba(" + col[1] + ",0)");
            g.fillStyle = d; g.fillRect(0, 0, w, h);
        }
        g.strokeStyle = "rgba(255,40,140,0.045)";
        g.lineWidth = 1;
        var vanY = h * 0.62;
        g.beginPath();
        for (var x = 0; x <= w; x += w / 8) {
            g.moveTo(w / 2, vanY);
            g.lineTo(x, h);
        }
        g.stroke();
        etoiles(g, w, h, 0.95);
    }},
    monolithe: { nom: "Monolithe", peindre: function (g, w, h) {
        var rMax = Math.max(w, h);
        var d = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, rMax * 0.75);
        d.addColorStop(0, "#131418");
        d.addColorStop(0.6, "#08090b");
        d.addColorStop(1, "#020204");
        g.fillStyle = d; g.fillRect(0, 0, w, h);

        g.strokeStyle = "rgba(255,255,255,0.06)";
        g.lineWidth = 1;
        var pas = 72;
        for (var px = pas; px < w; px += pas) {
            for (var py = pas; py < h; py += pas) {
                g.beginPath();
                g.moveTo(px - 3, py); g.lineTo(px + 3, py);
                g.moveTo(px, py - 3); g.lineTo(px, py + 3);
                g.stroke();
            }
        }
        etoiles(g, w, h, 0.6);
    }}
};

var ORDRE = ["nebuleuse", "aurore", "ambre", "neotokyo", "monolithe", "vide", "aube", "grille", "encre", "trois"];
