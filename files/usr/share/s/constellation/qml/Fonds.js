.pragma library
.import "Couleurs.js" as C

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

// ═══════════════════════════════════════════════════════════════════════════
// LES FONDS DES DEUX AUTRES THEMES — ajoutes le 2026-10-20.
//
// AUCUNE IMAGE N'EST EMPRUNTEE. Le fond « Bloom » de Windows 11 et les fonds
// des Pixel appartiennent a Microsoft et a Google, et ce depot est public : on
// ne les copie pas, on peint dans leur langue. Des petales de lumiere, des
// rubans, des formes pleines aux couleurs d'une seule graine.
//
// ILS SE COLORENT EUX-MEMES. Chaque fond recoit « o » — le mode, l'accent de
// Windows, la graine de Material You (voir Theme.optionsFond) — et se peint
// avec : choisir un autre accent recolore la floraison, choisir une autre
// graine recolore les vagues. C'est ce que fait Android avec un fond qu'il n'a
// pas peint ; ici on peut faire mieux, puisqu'on le peint.
//
// « accent » et « graine » sont la couleur que le fond DONNE quand l'accent ou
// la palette sont automatiques. Ils sont peints une fois, comme les autres :
// rien de ceci ne tourne au repos.
// ═══════════════════════════════════════════════════════════════════════════

// Un tirage deterministe, comme « etoiles » : un fond qui changerait a chaque
// redimensionnement ne serait plus un fond.
function semeur(graine) {
    var s = graine >>> 0;
    return function () { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
}

function teinteDe(hex, defaut) {
    return C.hexVersOklch(hex || defaut).h;
}

// Un petale : une goutte allongee, la pointe vers -y, posee a l'origine.
function petale(g, largeur, longueur) {
    g.beginPath();
    g.moveTo(0, 0);
    g.bezierCurveTo(largeur * 0.95, -longueur * 0.22, largeur * 0.62, -longueur * 0.86, 0, -longueur);
    g.bezierCurveTo(-largeur * 0.62, -longueur * 0.86, -largeur * 0.95, -longueur * 0.22, 0, 0);
    g.closePath();
}

// Une forme de Material 3 : un cercle festonne (le « cookie »), n lobes.
function festonne(g, cx, cy, r, lobes, profondeur, depart) {
    g.beginPath();
    var pas = 160;
    for (var i = 0; i <= pas; i++) {
        var a = depart + i / pas * 6.2832;
        var rr = r * (1 + profondeur * Math.cos(lobes * a));
        var x = cx + rr * Math.cos(a), y = cy + rr * Math.sin(a);
        if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
    }
    g.closePath();
}

// Une pilule : un rectangle aux bouts entierement ronds.
function pilule(g, cx, cy, longueur, epaisseur, angle) {
    g.save();
    g.translate(cx, cy);
    g.rotate(angle);
    var r = epaisseur / 2;
    g.beginPath();
    g.moveTo(-longueur / 2 + r, -r);
    g.lineTo(longueur / 2 - r, -r);
    g.arc(longueur / 2 - r, 0, r, -Math.PI / 2, Math.PI / 2, false);
    g.lineTo(-longueur / 2 + r, r);
    g.arc(-longueur / 2 + r, 0, r, Math.PI / 2, Math.PI * 1.5, false);
    g.closePath();
    g.restore();
}

// Une ligne de crete lisse, de gauche a droite, sous laquelle on remplit.
function crete(g, w, h, base, amplitude, frequence, phase, pointes) {
    g.beginPath();
    g.moveTo(-10, h + 10);
    g.lineTo(-10, base);
    var pas = 96;
    for (var i = 0; i <= pas; i++) {
        var x = i / pas * (w + 20) - 10;
        var t = i / pas;
        var y = base - amplitude * (0.62 * Math.sin(t * frequence * 6.2832 + phase)
                                  + 0.38 * Math.sin(t * frequence * 2.7 * 6.2832 + phase * 1.7)
                                  * (pointes || 0.5));
        g.lineTo(x, y);
    }
    g.lineTo(w + 10, h + 10);
    g.closePath();
}

// ── WINDOWS 11 ──────────────────────────────────────────────────────────────

FONDS.floraison = { nom: "Floraison", theme: "windows", accent: "#0078D4",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var hb = teinteDe(o.accent, "#0078D4");
    var m = Math.min(w, h);

    var d = g.createRadialGradient(w * 0.5, h * 0.64, 0, w * 0.5, h * 0.64, Math.max(w, h) * 0.78);
    if (sombre) {
        d.addColorStop(0, C.ton(hb, 0.09, 24));
        d.addColorStop(0.55, C.ton(hb, 0.06, 11));
        d.addColorStop(1, C.ton(hb, 0.03, 5));
    } else {
        d.addColorStop(0, C.ton(hb, 0.05, 90));
        d.addColorStop(0.6, C.ton(hb, 0.035, 94));
        d.addColorStop(1, C.ton(hb, 0.02, 97));
    }
    g.fillStyle = d; g.fillRect(0, 0, w, h);

    var cx = w * 0.5, cy = h * 0.70;
    // TROIS COURONNES, de l'arriere vers l'avant : les petales du fond plus
    // larges et plus sombres, ceux du devant plus fins et plus clairs. C'est la
    // superposition, pas un dessin precis, qui donne la profondeur.
    // LES POINTES TIRENT VERS LE CYAN (« dh » negatif) : c'est ce qui donne au
    // bleu sa lumiere. Tirees vers le violet, elles rendaient une fleur mauve.
    var couronnes = [
        { n: 7, lon: 0.70, lar: 0.42, tPied: sombre ? 20 : 46, tPointe: sombre ? 40 : 66, a: sombre ? 0.82 : 0.72, dec: 0.0, dh: 10 },
        { n: 7, lon: 0.60, lar: 0.32, tPied: sombre ? 32 : 40, tPointe: sombre ? 60 : 76, a: sombre ? 0.80 : 0.80, dec: 0.45, dh: 0 },
        { n: 6, lon: 0.46, lar: 0.23, tPied: sombre ? 50 : 46, tPointe: sombre ? 84 : 90, a: 0.84, dec: 0.18, dh: -10 }
    ];
    for (var k = 0; k < couronnes.length; k++) {
        var c = couronnes[k];
        for (var i = 0; i < c.n; i++) {
            var angle = (i + c.dec) / c.n * 6.2832 - 1.5708;
            g.save();
            g.translate(cx, cy);
            g.rotate(angle + 1.5708);
            var L = m * c.lon * (0.92 + 0.16 * Math.sin(i * 2.1 + k));
            // UNE OMBRE SOUS CHAQUE PETALE : c'est elle qui fait passer les
            // couronnes l'une devant l'autre au lieu de se melanger.
            //
            // JAMAIS « shadowBlur » — MESURE LE 2026-10-20 : le flou d'ombre du
            // canevas est calcule en logiciel, et une floraison plein ecran
            // mettait VINGT-TROIS SECONDES a se peindre (1600 x 900, banc
            // offscreen), le ruban dix-neuf ; tous les autres fonds, moins de
            // deux. La coquille entiere attendait. L'ombre est donc la meme
            // forme, peinte trois fois en dessous, un peu plus bas et plus
            // pale a chaque fois : un flou en marches, qui coute trois
            // remplissages au lieu d'une convolution.
            var ombrePetale = sombre ? "#000000" : C.ton(hb, 0.10, 25);
            for (var o3 = 3; o3 >= 1; o3--) {
                g.save();
                g.translate(0, m * 0.005 * o3);
                g.globalAlpha = (sombre ? 0.16 : 0.07) / o3;
                g.fillStyle = ombrePetale;
                petale(g, m * c.lar * 0.5 + m * 0.004 * o3, L + m * 0.004 * o3);
                g.fill();
                g.restore();
            }
            var lg = g.createLinearGradient(0, 0, 0, -L);
            lg.addColorStop(0, C.ton(hb + c.dh, 0.17, c.tPied));
            lg.addColorStop(0.7, C.ton(hb + c.dh - 10, 0.14, (c.tPied + c.tPointe) / 2 + 6));
            lg.addColorStop(1, C.ton(hb + c.dh - 22, 0.10, c.tPointe));
            g.globalAlpha = c.a;
            g.fillStyle = lg;
            petale(g, m * c.lar * 0.5, L);
            g.fill();
            // LA NERVURE : un trait de lumiere au milieu du petale, a peine.
            g.globalAlpha = sombre ? 0.10 : 0.16;
            g.strokeStyle = "#ffffff";
            g.lineWidth = Math.max(1, m * 0.0016);
            g.beginPath(); g.moveTo(0, -L * 0.08); g.quadraticCurveTo(L * 0.02, -L * 0.5, 0, -L * 0.94); g.stroke();
            g.restore();
        }
    }
    g.globalAlpha = 1;
    var coeur = g.createRadialGradient(cx, cy, 0, cx, cy, m * 0.22);
    coeur.addColorStop(0, sombre ? C.alpha(C.ton(hb - 20, 0.08, 92), 0.9) : "rgba(255,255,255,0.95)");
    coeur.addColorStop(0.35, sombre ? C.alpha(C.ton(hb - 10, 0.12, 70), 0.35) : "rgba(255,255,255,0.45)");
    coeur.addColorStop(1, "rgba(255,255,255,0)");
    g.fillStyle = coeur; g.fillRect(0, 0, w, h);
}};

FONDS.ruban = { nom: "Rubans", theme: "windows", accent: "#8764B8",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var hb = teinteDe(o.accent, "#8764B8");
    var bg = g.createLinearGradient(0, 0, w, h);
    if (sombre) {
        bg.addColorStop(0, C.ton(hb, 0.05, 10)); bg.addColorStop(1, C.ton(hb + 40, 0.04, 5));
    } else {
        bg.addColorStop(0, C.ton(hb, 0.03, 96)); bg.addColorStop(1, C.ton(hb + 40, 0.04, 88));
    }
    g.fillStyle = bg; g.fillRect(0, 0, w, h);

    // CINQ RUBANS, du fond vers l'avant. Chacun est la bande entre deux
    // courbes de Bezier qui traversent l'ecran ; son degrade va d'une teinte a
    // sa voisine, et une ombre douce le detache de celui qu'il recouvre.
    var rubans = 5;
    for (var i = 0; i < rubans; i++) {
        var t = i / (rubans - 1);
        var y0 = h * (0.30 + t * 0.34);
        var ep = h * (0.10 + 0.05 * Math.sin(i * 1.3 + 0.4));
        var lg = g.createLinearGradient(0, 0, w, 0);
        var tons = sombre ? [26 + i * 9, 44 + i * 8] : [52 + i * 6, 76 + i * 4];
        lg.addColorStop(0, C.ton(hb - 30 + i * 18, 0.15, tons[0]));
        lg.addColorStop(0.55, C.ton(hb + i * 14, 0.16, (tons[0] + tons[1]) / 2));
        lg.addColorStop(1, C.ton(hb + 40 + i * 10, 0.12, tons[1]));
        // L'OMBRE EN MARCHES, comme sous les petales de la floraison — jamais
        // « shadowBlur », qui mettait dix-neuf secondes a peindre ce fond.
        for (var o4 = 3; o4 >= 0; o4--) {
            g.save();
            if (o4 > 0) {
                g.translate(0, h * 0.006 * o4);
                g.globalAlpha = (sombre ? 0.22 : 0.08) / o4;
                g.fillStyle = sombre ? "#000000" : "#2a1f4a";
            } else {
                g.globalAlpha = 0.94;
                g.fillStyle = lg;
            }
            g.beginPath();
            g.moveTo(-w * 0.1, y0 + h * 0.10);
            g.bezierCurveTo(w * 0.28, y0 - h * 0.30, w * 0.62, y0 + h * 0.34, w * 1.1, y0 - h * 0.12);
            g.lineTo(w * 1.1, y0 - h * 0.12 + ep);
            g.bezierCurveTo(w * 0.62, y0 + h * 0.34 + ep * 1.25, w * 0.28, y0 - h * 0.30 + ep * 1.6, -w * 0.1, y0 + h * 0.10 + ep);
            g.closePath();
            g.fill();
            g.restore();
        }
    }
    g.globalAlpha = 1;
}};

FONDS.lueur = { nom: "Lueur", theme: "windows", accent: "#00B7C3",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var hb = teinteDe(o.accent, "#00B7C3");
    g.fillStyle = sombre ? C.ton(hb, 0.012, 7) : C.ton(hb, 0.01, 96);
    g.fillRect(0, 0, w, h);
    var rMax = Math.max(w, h);
    var taches = [
        [0.30, 0.38, 0.55, hb, sombre ? 46 : 74, 0.85],
        [0.70, 0.30, 0.48, hb + 55, sombre ? 40 : 78, 0.75],
        [0.58, 0.78, 0.52, hb - 60, sombre ? 36 : 70, 0.70]
    ];
    for (var i = 0; i < taches.length; i++) {
        var t = taches[i];
        var d = g.createRadialGradient(w * t[0], h * t[1], 0, w * t[0], h * t[1], rMax * t[2]);
        var c = C.ton(t[3], 0.16, t[4]);
        d.addColorStop(0, C.alpha(c, t[5]));
        d.addColorStop(0.5, C.alpha(c, t[5] * 0.30));
        d.addColorStop(1, C.alpha(c, 0));
        g.fillStyle = d; g.fillRect(0, 0, w, h);
    }
    // UN ANNEAU DE VERRE, a peine visible : il donne au flou un objet sur
    // lequel l'oeil se pose.
    g.strokeStyle = sombre ? "rgba(255,255,255,0.10)" : "rgba(255,255,255,0.65)";
    g.lineWidth = Math.max(1.5, Math.min(w, h) * 0.004);
    g.beginPath();
    g.arc(w * 0.5, h * 0.52, Math.min(w, h) * 0.30, 0, 6.2832);
    g.stroke();
    g.globalAlpha = sombre ? 0.05 : 0.25;
    g.lineWidth = Math.min(w, h) * 0.06;
    g.stroke();
    g.globalAlpha = 1;
}};

FONDS.dunes = { nom: "Dunes", theme: "windows", accent: "#CA5010",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var ciel = g.createLinearGradient(0, 0, 0, h);
    if (sombre) {
        ciel.addColorStop(0, "#0d0a1e"); ciel.addColorStop(0.55, "#2a1636"); ciel.addColorStop(1, "#5a2a3c");
    } else {
        ciel.addColorStop(0, "#fde7cf"); ciel.addColorStop(0.55, "#fbc9a0"); ciel.addColorStop(1, "#f29a6e");
    }
    g.fillStyle = ciel; g.fillRect(0, 0, w, h);
    var m = Math.min(w, h);
    var sx = w * 0.64, sy = h * 0.50;
    var halo = g.createRadialGradient(sx, sy, 0, sx, sy, m * 0.55);
    halo.addColorStop(0, sombre ? "rgba(255,190,170,0.35)" : "rgba(255,248,232,0.95)");
    halo.addColorStop(1, "rgba(255,240,220,0)");
    g.fillStyle = halo; g.fillRect(0, 0, w, h);
    g.fillStyle = sombre ? "#f4d7c8" : "#fff6e8";
    g.beginPath(); g.arc(sx, sy, m * 0.085, 0, 6.2832); g.fill();
    var couches = sombre
        ? ["#4b2238", "#3a1a2f", "#2a1325", "#1b0c19"]
        : ["#eb9a72", "#d77850", "#b85a3c", "#8c3f2d"];
    for (var i = 0; i < couches.length; i++) {
        crete(g, w, h, h * (0.60 + i * 0.09), h * (0.06 - i * 0.008), 0.9 + i * 0.35, i * 1.9 + 0.6, 0.6);
        g.fillStyle = couches[i];
        g.fill();
    }
}};

// ── TABLETTE ANDROID (MATERIAL YOU) ─────────────────────────────────────────
// Chaque fond est peint avec les tons de SA graine — ou de celle que
// l'utilisateur a choisie a la place.

FONDS.formes = { nom: "Formes", theme: "android", graine: "#6750A4",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var hg = teinteDe(o.graine, "#6750A4");
    var m = Math.min(w, h);
    g.fillStyle = sombre ? C.ton(hg, 0.03, 12) : C.ton(hg, 0.04, 92);
    g.fillRect(0, 0, w, h);
    // Le grand cercle tertiaire, a demi hors de l'ecran.
    g.fillStyle = sombre ? C.ton(hg + 60, 0.07, 30) : C.ton(hg + 60, 0.07, 82);
    g.beginPath(); g.arc(w * 0.80, h * 0.24, m * 0.40, 0, 6.2832); g.fill();
    // Le « cookie » primaire.
    g.fillStyle = sombre ? C.ton(hg, 0.11, 42) : C.ton(hg, 0.12, 68);
    festonne(g, w * 0.26, h * 0.70, m * 0.30, 9, 0.065, 0.2); g.fill();
    // La pilule secondaire, couchee en travers.
    g.fillStyle = sombre ? C.ton(hg, 0.045, 24) : C.ton(hg, 0.05, 84);
    pilule(g, w * 0.68, h * 0.82, m * 0.95, m * 0.24, -0.42); g.fill();
    // Deux petites formes pour casser la symetrie.
    g.fillStyle = sombre ? C.ton(hg, 0.10, 60) : C.ton(hg, 0.11, 52);
    g.beginPath(); g.arc(w * 0.47, h * 0.36, m * 0.045, 0, 6.2832); g.fill();
    g.fillStyle = sombre ? C.ton(hg + 60, 0.08, 52) : C.ton(hg + 60, 0.09, 62);
    festonne(g, w * 0.92, h * 0.66, m * 0.07, 4, 0.12, 0.4); g.fill();
}};

FONDS.vagues = { nom: "Vagues", theme: "android", graine: "#006A6A",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var hg = teinteDe(o.graine, "#006A6A");
    var ciel = g.createLinearGradient(0, 0, 0, h);
    ciel.addColorStop(0, sombre ? C.ton(hg, 0.03, 8) : C.ton(hg, 0.03, 97));
    ciel.addColorStop(1, sombre ? C.ton(hg, 0.05, 18) : C.ton(hg, 0.05, 88));
    g.fillStyle = ciel; g.fillRect(0, 0, w, h);
    var tons = sombre ? [24, 32, 40, 50, 62] : [84, 74, 64, 52, 40];
    for (var i = 0; i < tons.length; i++) {
        var teinte = (i % 2 === 0) ? hg : hg + 60;
        crete(g, w, h, h * (0.46 + i * 0.105), h * (0.045 + i * 0.006), 1.15 + i * 0.22, i * 2.3, 0.35);
        g.fillStyle = C.ton(teinte, 0.07 + i * 0.012, tons[i]);
        g.fill();
    }
}};

FONDS.galets = { nom: "Galets", theme: "android", graine: "#8B5000",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var hg = teinteDe(o.graine, "#8B5000");
    var m = Math.min(w, h);
    g.fillStyle = sombre ? C.ton(hg, 0.025, 13) : C.ton(hg, 0.03, 94);
    g.fillRect(0, 0, w, h);
    var al = semeur(20261020);
    var couleurs = sombre
        ? [C.ton(hg, 0.09, 40), C.ton(hg, 0.04, 28), C.ton(hg + 60, 0.07, 46), C.ton(hg, 0.06, 56)]
        : [C.ton(hg, 0.10, 70), C.ton(hg, 0.05, 82), C.ton(hg + 60, 0.08, 76), C.ton(hg, 0.08, 58)];
    // UNE GRILLE LACHE, puis chaque galet derive un peu de sa case : assez
    // d'ordre pour que l'oeil se repose, assez de desordre pour que ce ne soit
    // pas un carrelage.
    var pas = m * 0.27;
    for (var y = -pas * 0.3; y < h + pas; y += pas * 0.86) {
        for (var x = -pas * 0.3; x < w + pas; x += pas) {
            // Une case sur trois reste vide : le vide fait respirer le reste.
            if (al() < 0.33) continue;
            var r = pas * (0.20 + al() * 0.22);
            var px = x + (al() - 0.5) * pas * 0.5;
            var py = y + (al() - 0.5) * pas * 0.5;
            g.fillStyle = couleurs[Math.floor(al() * couleurs.length) % couleurs.length];
            if (al() < 0.5) {
                g.beginPath(); g.arc(px, py, r, 0, 6.2832); g.fill();
            } else {
                pilule(g, px, py, r * 2.3, r * 1.5, (al() - 0.5) * 1.6);
                g.fill();
            }
        }
    }
}};

FONDS.soleil = { nom: "Soleil", theme: "android", graine: "#B3261E",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var hg = teinteDe(o.graine, "#B3261E");
    var m = Math.min(w, h);
    var ciel = g.createLinearGradient(0, 0, 0, h);
    ciel.addColorStop(0, sombre ? C.ton(hg + 60, 0.04, 9) : C.ton(hg + 60, 0.04, 96));
    ciel.addColorStop(1, sombre ? C.ton(hg + 30, 0.06, 20) : C.ton(hg + 30, 0.07, 86));
    g.fillStyle = ciel; g.fillRect(0, 0, w, h);
    var cx = w * 0.5, cy = h * 0.66, r = m * 0.34;
    var disque = g.createLinearGradient(0, cy - r, 0, cy + r);
    disque.addColorStop(0, sombre ? C.ton(hg + 40, 0.12, 70) : C.ton(hg + 40, 0.14, 80));
    disque.addColorStop(1, sombre ? C.ton(hg, 0.15, 44) : C.ton(hg, 0.17, 56));
    g.fillStyle = disque;
    g.beginPath(); g.arc(cx, cy, r, 0, 6.2832); g.fill();
    // LES BANDES QUI COUPENT LE BAS DU DISQUE — la couleur du ciel a cet
    // endroit, de plus en plus epaisses vers l'horizon.
    for (var i = 0; i < 6; i++) {
        var by = cy + r * (0.12 + i * 0.16);
        var ep = r * (0.025 + i * 0.016);
        var tt = (by - 0) / h;
        g.fillStyle = sombre ? C.ton(hg + 30 + (1 - tt) * 30, 0.06, 9 + tt * 11)
                             : C.ton(hg + 30 + (1 - tt) * 30, 0.07, 96 - tt * 10);
        g.fillRect(cx - r - 2, by, 2 * r + 4, ep);
    }
    g.fillStyle = sombre ? C.ton(hg, 0.05, 14) : C.ton(hg, 0.06, 78);
    g.fillRect(0, h * 0.86, w, h * 0.14);
}};

FONDS.collines = { nom: "Collines", theme: "android", graine: "#386A20",
    peindre: function (g, w, h, o) {
    o = o || {};
    var sombre = o.sombre === true;
    var hg = teinteDe(o.graine, "#386A20");
    var m = Math.min(w, h);
    var ciel = g.createLinearGradient(0, 0, 0, h);
    ciel.addColorStop(0, sombre ? C.ton(hg + 60, 0.03, 8) : C.ton(hg + 60, 0.03, 96));
    ciel.addColorStop(1, sombre ? C.ton(hg + 60, 0.05, 22) : C.ton(hg + 60, 0.05, 86));
    g.fillStyle = ciel; g.fillRect(0, 0, w, h);
    g.fillStyle = sombre ? C.ton(hg + 60, 0.06, 80) : C.ton(hg + 60, 0.08, 92);
    g.beginPath(); g.arc(w * 0.26, h * 0.30, m * 0.11, 0, 6.2832); g.fill();
    var tons = sombre ? [30, 25, 20, 15, 10] : [84, 72, 60, 48, 36];
    for (var i = 0; i < tons.length; i++) {
        crete(g, w, h, h * (0.52 + i * 0.095), h * (0.07 - i * 0.008), 0.55 + i * 0.28, i * 1.4 + 2.1, 0.45);
        g.fillStyle = C.ton(hg, 0.06 + i * 0.012, tons[i]);
        g.fill();
    }
}};

var ORDRE_WINDOWS = ["floraison", "ruban", "lueur", "dunes"];
var ORDRE_ANDROID = ["formes", "vagues", "galets", "soleil", "collines"];

// Les fonds proposes pour un theme, dans l'ordre ou on les montre.
function ordre(theme) {
    if (theme === "windows") return ORDRE_WINDOWS;
    if (theme === "android") return ORDRE_ANDROID;
    return ORDRE;
}

// Peint un fond par son identifiant, avec les options du theme. Un identifiant
// inconnu rend le premier fond du theme plutot qu'un ecran noir.
function peindreFond(g, id, w, h, o, theme) {
    var p = FONDS[id] || FONDS[ordre(theme || "constellation")[0]];
    p.peindre(g, w, h, o || {});
}
