import QtQuick

// LE FOND FLOU DE WINDOWS 11 — le « Mica » de la barre, l'« acrylique » du menu.
//
// PAS DE SHADER, ET C'EST MESURE DANS CE DEPOT. MultiEffect ne dessine rien sans
// shaders (Glyphe.qml l'a paye le 2026-08-24), et le controle de construction
// tourne sans GPU. Le flou vient donc d'un detour qui marche partout : le fond
// est peint en TOUT PETIT — un quatorzieme de l'ecran, une centaine de pixels de
// large — puis agrandi avec lissage. Un agrandissement lineaire de quatorze fois
// EST un flou, et il coute quelques kilo-octets au lieu d'une passe de rendu par
// image.
//
// « ox » et « oy » sont la position de ce panneau sur l'ecran : on ne montre que
// la portion du fond qui se trouve DERRIERE lui, comme le vrai Mica.
Item {
    id: racine
    clip: true

    property real ox: 0
    property real oy: 0
    property real ecranL: 1920
    property real ecranH: 1080
    property int facteur: 14

    FondEcran {
        x: -racine.ox
        y: -racine.oy
        width: Math.max(1, Math.round(racine.ecranL / racine.facteur))
        height: Math.max(1, Math.round(racine.ecranH / racine.facteur))
        transformOrigin: Item.TopLeft
        scale: racine.facteur
        smooth: true
    }
}
