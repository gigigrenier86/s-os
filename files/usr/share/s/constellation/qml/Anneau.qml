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

    onCouleurChanged: requestPaint()
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
        g.beginPath();
        g.arc(width / 2, height / 2, r, 0, 6.2832);
        g.stroke();
    }
}
