import QtQuick
import "Glyphes.js" as G

// Un glyphe generique, peint sur un Canvas.
//
// TROIS IMPLEMENTATIONS ONT ETE ESSAYEES, ET SEULE LA TROISIEME TIENT :
//
//   1. SVG blanc + MultiEffect pour la teinte. Ne dessine rien sans shaders :
//      l'etoile sortait vide, sans le moindre message.
//   2. QtQuick.Shapes. Dessine partout, mais un Shape NE RESPECTE PAS le
//      decoupage de ses ancetres — verifie au rendu logiciel ET sur le vrai
//      pipeline GPU. Les glyphes des tuiles situees sous le bas du menu se
//      peignaient par-dessus le bureau.
//   3. Canvas. Il produit une texture, laquelle est decoupee comme n'importe
//      quelle image. C'est celle-ci.
//
// Le contexte 2D de QML accepte un chemin SVG en clair (« ctx.path = "M..." »),
// ce qui permet de reprendre les traces d'origine sans les convertir.
Canvas {
    id: racine

    property string nom: "i-boite"
    property color couleur: "#ffffff"
    // 1,7 dans le repere de 24 du viewBox d'origine.
    property real epaisseur: 1.7

    readonly property var traces: G.GLYPHES[nom] || G.GLYPHES["i-boite"]

    // Rien ne se repeint tant que rien ne change — la regle 1 de Constellation.
    onNomChanged: requestPaint()
    onCouleurChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var g = getContext("2d");
        g.reset();
        g.clearRect(0, 0, width, height);
        var e = Math.min(width, height) / 24;
        if (e <= 0) return;
        g.scale(e, e);
        g.strokeStyle = racine.couleur;
        g.fillStyle = "transparent";
        g.lineWidth = racine.epaisseur;
        g.lineCap = "round";
        g.lineJoin = "round";
        g.path = racine.traces.join(" ");
        g.stroke();
    }
}
