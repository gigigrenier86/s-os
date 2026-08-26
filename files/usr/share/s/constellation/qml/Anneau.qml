import QtQuick

// L'anneau d'une etoile ou d'une bulle.
//
// PLEIN = le logiciel a deja tourne ici, mesure.
// POINTILLE = il est pose dans l'image, jamais exerce.
//
// Sur Canvas et non sur Shape, pour la meme raison que Glyphe : un Shape se
// dessine par-dessus le decoupage de ses ancetres, et les anneaux des tuiles
// hors panneau debordaient sur le bureau.
Canvas {
    id: anneau

    property color couleur: "#ffffff"
    property bool pointille: false
    property real epaisseur: 2

    // LA JAUGE EST L'ANNEAU LUI-MEME. Un reglage de S se lit dans la meme
    // forme qu'une etoile — c'est ce qui fait qu'un panneau de reglages
    // ressemble encore au bureau et non a une boite de dialogue posee dessus.
    // 1 rend le cercle entier, donc rien ne change pour les etoiles.
    property real fraction: 1
    // Le reste du tour, en trait tres pale : sans lui, une jauge a 10 %
    // ressemble a un anneau casse plutot qu'a une mesure.
    property bool montrerReste: false

    onCouleurChanged: requestPaint()
    onFractionChanged: requestPaint()
    onMontrerResteChanged: requestPaint()
    onPointilleChanged: requestPaint()
    onEpaisseurChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var g = getContext("2d");
        g.reset();
        g.clearRect(0, 0, width, height);
        var r = Math.min(width, height) / 2 - epaisseur / 2;
        if (r <= 0) return;
        g.strokeStyle = anneau.couleur;
        g.lineWidth = anneau.epaisseur;
        g.lineCap = "round";
        // Les tirets sont donnes en multiples de l'epaisseur : l'anneau garde
        // le meme rythme quand l'etoile grossit avec l'usage.
        g.setLineDash(pointille ? [epaisseur * 2.4, epaisseur * 2.0] : []);

        var part = Math.max(0, Math.min(1, fraction));
        // On part du haut : une jauge qui commence a trois heures se lit mal,
        // parce que l'oeil cherche le zero en haut.
        var depart = -Math.PI / 2;

        if (montrerReste && part < 1) {
            g.save();
            g.globalAlpha = 0.18;
            g.beginPath();
            g.arc(width / 2, height / 2, r, 0, 6.2832);
            g.stroke();
            g.restore();
        }

        g.beginPath();
        if (part >= 1) {
            g.arc(width / 2, height / 2, r, 0, 6.2832);
        } else if (part > 0) {
            g.arc(width / 2, height / 2, r, depart, depart + part * 6.2832);
        }
        if (part > 0) g.stroke();
    }
}
