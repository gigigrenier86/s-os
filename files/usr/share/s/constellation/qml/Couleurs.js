.pragma library

// LES COULEURS CALCULEES DES TROIS THEMES — l'accent de Windows, la palette
// Material You d'Android.
//
// POURQUOI OKLab ET NON HSL. Material You tire toute une gamme de « tons » d'une
// seule couleur de depart : le ton 40 sert aux boutons, le ton 90 aux fonds
// doux, le ton 98 a la surface. Un ton est une CLARTE PERCUE, pas une valeur de
// HSL : en HSL, un jaune et un bleu de meme « lightness » n'ont pas du tout la
// meme clarte a l'oeil, et une palette batie ainsi rendrait un texte illisible
// sur la moitie des teintes. Google emploie CAM16/HCT ; OKLab (Bjorn Ottosson,
// 2020) donne une clarte percue tout aussi uniforme pour une fraction du code —
// trois matrices et une racine cubique, rien qui merite une dependance.
//
// LE TON EST LA CLARTE L* DE CIELAB, comme dans Material : on le convertit en
// luminance Y, puis en L d'OKLab (pour un gris, L_ok = racine cubique de Y). Une
// teinte trop saturee pour l'ecran a ce ton perd de la chroma jusqu'a y tenir,
// jamais de la clarte — c'est la clarte qui garantit le contraste.
//
// TOUT CE FICHIER REND DES CHAINES « #rrggbb » ou « #aarrggbb », jamais des
// objets color de QML : une bibliotheque « .pragma library » n'a pas a dependre
// du moteur de rendu, et QML accepte ces deux formes partout ou il attend une
// couleur.

function versLineaire(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function versSrgb(c) {
    return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
}

function hexVersRgb(hex) {
    var h = String(hex || "").replace("#", "");
    // « #aarrggbb » : QML ecrit l'alpha en tete, on ne garde que la couleur.
    if (h.length === 8) h = h.substring(2);
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    if (h.length !== 6 || isNaN(n)) return [0.5, 0.5, 0.5];
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

function deuxChiffres(v) {
    var x = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
    return x.length < 2 ? "0" + x : x;
}

function rgbVersHex(r, g, b) {
    return "#" + deuxChiffres(r) + deuxChiffres(g) + deuxChiffres(b);
}

// Une couleur avec son opacite, dans la forme que QML lit : « #aarrggbb ».
function alpha(hex, a) {
    var c = hexVersRgb(hex);
    return "#" + deuxChiffres(a) + deuxChiffres(c[0]) + deuxChiffres(c[1]) + deuxChiffres(c[2]);
}

// Le melange lineaire de deux couleurs, t = 0 rend « a », t = 1 rend « b ».
function melange(a, b, t) {
    var x = hexVersRgb(a), y = hexVersRgb(b);
    return rgbVersHex(x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t,
                      x[2] + (y[2] - x[2]) * t);
}

function rgbVersOklab(r, g, b) {
    r = versLineaire(r); g = versLineaire(g); b = versLineaire(b);
    var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s];
}

function oklabVersLineaire(L, a, b) {
    var l = L + 0.3963377774 * a + 0.2158037573 * b;
    var m = L - 0.1055613458 * a - 0.0638541728 * b;
    var s = L - 0.0894841775 * a - 1.2914855480 * b;
    l = l * l * l; m = m * m * m; s = s * s * s;
    return [ 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s];
}

// La teinte (degres) et la chroma d'une couleur, en OKLCH.
function hexVersOklch(hex) {
    var c = hexVersRgb(hex);
    var lab = rgbVersOklab(c[0], c[1], c[2]);
    var h = Math.atan2(lab[2], lab[1]) * 180 / Math.PI;
    if (h < 0) h += 360;
    return { L: lab[0], c: Math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]), h: h };
}

// Le ton L* de CIELAB rendu en L d'OKLab, pour un gris de meme luminance.
function clarteDeTon(t) {
    var f = (t + 16) / 116;
    var y = t > 8 ? f * f * f : t / 903.2963;
    return Math.cbrt(Math.max(0, y));
}

function dansLeGamut(L, c, hr) {
    var v = oklabVersLineaire(L, c * Math.cos(hr), c * Math.sin(hr));
    var e = 1e-4;
    return v[0] >= -e && v[0] <= 1 + e && v[1] >= -e && v[1] <= 1 + e
        && v[2] >= -e && v[2] <= 1 + e;
}

// UNE TEINTE, UNE CHROMA, UN TON — rend la couleur de l'ecran la plus proche.
// La chroma recule par dichotomie jusqu'a tenir dans sRGB ; la clarte, jamais.
function ton(h, c, t) {
    var L = clarteDeTon(Math.max(0, Math.min(100, t)));
    var hr = h * Math.PI / 180;
    var garde = c;
    if (!dansLeGamut(L, c, hr)) {
        var bas = 0, haut = c;
        garde = 0;
        for (var i = 0; i < 16; i++) {
            var milieu = (bas + haut) / 2;
            if (dansLeGamut(L, milieu, hr)) { garde = milieu; bas = milieu; }
            else haut = milieu;
        }
    }
    var v = oklabVersLineaire(L, garde * Math.cos(hr), garde * Math.sin(hr));
    return rgbVersHex(versSrgb(v[0]), versSrgb(v[1]), versSrgb(v[2]));
}

// LE TON D'UNE COULEUR DONNEE — la meme teinte et la meme chroma, une autre
// clarte. Sert aux fonds d'ecran, qui ont besoin de nuances de leur graine.
function tonDe(hex, t, chroma) {
    var o = hexVersOklch(hex);
    return ton(o.h, chroma === undefined ? o.c : chroma, t);
}

// ── MATERIAL YOU : la palette « tonal spot » ─────────────────────────────────
//
// C'est le schema par defaut d'Android 12 et suivants. Cinq gammes tirees d'une
// seule graine : primaire (la teinte de la graine, chroma moderee), secondaire
// (meme teinte, a peine coloree), tertiaire (la teinte tournee de 60 degres),
// neutre et neutre variante (presque grises, juste teintees). Les CHROMAS sont
// celles de Material (36, 16, 24, 6 et 8 en CAM16), ramenees en OKLCH.
//
// LES ROLES SONT CEUX DE MATERIAL 3, mot pour mot, avec les tons que la
// specification leur donne en clair et en sombre — un « primaryContainer » est
// le ton 90 en clair et le ton 30 en sombre, partout.
function schemaMaterial(graine, sombre) {
    var o = hexVersOklch(graine);
    var h = o.h;
    // UNE GRAINE GRISE N'A PAS DE TEINTE A DONNER. atan2 de presque zero rend
    // un angle au hasard : on garde alors une palette volontairement neutre
    // plutot qu'une couleur que personne n'a choisie.
    var neutre = o.c < 0.02;
    var cP = neutre ? 0.012 : Math.min(0.15, Math.max(0.085, o.c));
    var cS = neutre ? 0.008 : 0.038;
    var cT = neutre ? 0.010 : 0.058;
    var hT = (h + 60) % 360;
    var cN = neutre ? 0.004 : 0.011;
    var cNV = neutre ? 0.006 : 0.020;
    function P(t) { return ton(h, cP, t); }
    function S(t) { return ton(h, cS, t); }
    function T(t) { return ton(hT, cT, t); }
    function N(t) { return ton(h, cN, t); }
    function NV(t) { return ton(h, cNV, t); }
    if (!sombre) {
        return {
            primary: P(40), onPrimary: P(100), primaryContainer: P(90), onPrimaryContainer: P(10),
            secondary: S(40), onSecondary: S(100), secondaryContainer: S(90), onSecondaryContainer: S(10),
            tertiary: T(40), onTertiary: T(100), tertiaryContainer: T(90), onTertiaryContainer: T(10),
            surface: N(98), surfaceDim: N(87), surfaceBright: N(98),
            surfaceContainerLowest: N(100), surfaceContainerLow: N(96), surfaceContainer: N(94),
            surfaceContainerHigh: N(92), surfaceContainerHighest: N(90),
            onSurface: N(10), onSurfaceVariant: NV(30), outline: NV(50), outlineVariant: NV(80),
            inverseSurface: N(20), inverseOnSurface: N(95), inversePrimary: P(80)
        };
    }
    return {
        primary: P(80), onPrimary: P(20), primaryContainer: P(30), onPrimaryContainer: P(90),
        secondary: S(80), onSecondary: S(20), secondaryContainer: S(30), onSecondaryContainer: S(90),
        tertiary: T(80), onTertiary: T(20), tertiaryContainer: T(30), onTertiaryContainer: T(90),
        surface: N(6), surfaceDim: N(6), surfaceBright: N(24),
        surfaceContainerLowest: N(4), surfaceContainerLow: N(10), surfaceContainer: N(12),
        surfaceContainerHigh: N(17), surfaceContainerHighest: N(22),
        onSurface: N(90), onSurfaceVariant: NV(80), outline: NV(60), outlineVariant: NV(30),
        inverseSurface: N(90), inverseOnSurface: N(20), inversePrimary: P(40)
    };
}

// ── WINDOWS 11 : l'accent selon le mode ──────────────────────────────────────
//
// Windows ne peint jamais l'accent tel quel. En mode clair, les boutons et les
// indicateurs prennent une variante plus sombre de la couleur choisie
// (« SystemAccentColorDark1 ») ; en mode sombre, une variante beaucoup plus
// claire (« SystemAccentColorLight2 ») — c'est ce qui rend le bleu d'origine,
// #0078D4, presque cyan sur un menu sombre. On rend la meme logique par le ton :
// 42 en clair, 78 en sombre, la teinte et la chroma de la couleur choisie.
//
// LES BLEUS GLISSENT VERS LE CYAN EN SOMBRE, comme chez Windows : le bleu
// d'origine #0078D4 y devient #60CDFF, une vingtaine de degres plus loin sur le
// cercle. On ne reproduit ce glissement que dans les bleus — applique a un rouge,
// il le tirerait vers le rose sans que personne l'ait demande.
function accentWindows(base, sombre) {
    var o = hexVersOklch(base);
    if (o.c < 0.02) return sombre ? ton(o.h, 0, 78) : ton(o.h, 0, 38);
    if (!sombre) return ton(o.h, Math.max(0.06, Math.min(o.c, 0.17)), 42);
    var h = (o.h > 200 && o.h < 285) ? o.h - 20 : o.h;
    return ton(h, Math.min(o.c, 0.14), 79);
}

// Le texte pose sur un accent : noir sur un accent clair, blanc sur un sombre.
// Le seuil est sur la clarte percue, pas sur une moyenne des canaux.
function surCouleur(hex) {
    return hexVersOklch(hex).L > 0.70 ? "#000000" : "#ffffff";
}
