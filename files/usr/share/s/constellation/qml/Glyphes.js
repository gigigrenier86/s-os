.pragma library

// Les glyphes de Constellation, en donnees de trace pures.
//
// POURQUOI PAS DES FICHIERS SVG TEINTES AU RENDU. La premiere version
// chargeait un SVG blanc par glyphe et lui appliquait MultiEffect pour le
// mettre a la couleur de son monde. Mesure au banc le 2026-08-24 : sous un
// rendu sans shaders, MultiEffect ne produit RIEN et l'etoile sort noire —
// une icone manquante, sans un message. Les anneaux, eux, sont des Shape et
// s'affichaient partout. On passe donc tout le dessin par Shape : la couleur
// devient une simple propriete, et il n'y a plus une seule dependance a un
// pipeline graphique particulier.
//
// Genere depuis les <symbol> de galerie/constellation/constellation.html.
// Les cercles, ellipses et rectangles y ont ete convertis en traces : un
// ShapePath ne connait que des chemins. Repere de 24 par 24, comme le viewBox
// d'origine — Glyphe.qml met a l'echelle.

var GLYPHES = {
    "i-alim": ["M12 3.5v8", "M7 6.3a8 8 0 1 0 10 0"],
    "i-boite": ["M20.5 8v8a2 2 0 0 1-1 1.7l-6.5 3.6a2 2 0 0 1-2 0L4.5 17.7a2 2 0 0 1-1-1.7V8a2 2 0 0 1 1-1.7l6.5-3.6a2 2 0 0 1 2 0l6.5 3.6A2 2 0 0 1 20.5 8z", "m3.8 7.2 8.2 4.5 8.2-4.5M12 20.8v-9.1"],
    "i-bulle": ["M20.5 11.5c0 4.1-3.8 7.5-8.5 7.5a9.7 9.7 0 0 1-2.7-.4L4 20.5l1.5-3.8A7.1 7.1 0 0 1 3.5 11.5C3.5 7.4 7.3 4 12 4s8.5 3.4 8.5 7.5z"],
    "i-cadenas": ["M6.5 10.5H17.5A2 2 0 0 1 19.5 12.5V18.5A2 2 0 0 1 17.5 20.5H6.5A2 2 0 0 1 4.5 18.5V12.5A2 2 0 0 1 6.5 10.5Z", "M8 10.5V7a4 4 0 0 1 8 0v3.5"],
    "i-code": ["m8 8-5 4 5 4M16 8l5 4-5 4M14 5l-4 14"],
    "i-disque": ["M4 6A8 3 0 1 1 20 6A8 3 0 1 1 4 6", "M4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"],
    // Trois glissieres de mixage a hauteurs differentes — l'icone commune
    // d'un egaliseur. Ajoute le 2026-08-30, pour l'etoile « Egaliseur ».
    "i-egaliseur": ["M6 4v16", "M12 4v16", "M18 4v16", "M3.5 9h5", "M9.5 15h5", "M15.5 7h5"],
    "i-doc": ["M6 3h8l4 4v14H6z", "M14 3v4h4M9 12h6M9 16h6"],
    "i-dossier": ["M3 7a2 2 0 0 1 2-2h4l2 2.5h8a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"],
    "i-ecran": ["M4.5 4H19.5A2 2 0 0 1 21.5 6V15A2 2 0 0 1 19.5 17H4.5A2 2 0 0 1 2.5 15V6A2 2 0 0 1 4.5 4Z", "M8.5 20.5h7M12 17v3.5"],
    "i-etincelle": ["M12 3.5 13.9 9 19.5 11l-5.6 2L12 18.5 10.1 13 4.5 11 10.1 9z", "M18.5 4.5v3M17 6h3"],
    "i-fenetre": ["M5 4.5H19A2 2 0 0 1 21 6.5V17.5A2 2 0 0 1 19 19.5H5A2 2 0 0 1 3 17.5V6.5A2 2 0 0 1 5 4.5Z", "M3 9h18M12 9v10.5"],
    "i-globe": ["M3 12A9 9 0 1 1 21 12A9 9 0 1 1 3 12", "M3 12h18M12 3c2.5 2.6 2.5 15.4 0 18M12 3c-2.5 2.6-2.5 15.4 0 18"],
    "i-grille": ["M5 3.5H9A1.5 1.5 0 0 1 10.5 5V9A1.5 1.5 0 0 1 9 10.5H5A1.5 1.5 0 0 1 3.5 9V5A1.5 1.5 0 0 1 5 3.5Z", "M15 3.5H19A1.5 1.5 0 0 1 20.5 5V9A1.5 1.5 0 0 1 19 10.5H15A1.5 1.5 0 0 1 13.5 9V5A1.5 1.5 0 0 1 15 3.5Z", "M5 13.5H9A1.5 1.5 0 0 1 10.5 15V19A1.5 1.5 0 0 1 9 20.5H5A1.5 1.5 0 0 1 3.5 19V15A1.5 1.5 0 0 1 5 13.5Z", "M15 13.5H19A1.5 1.5 0 0 1 20.5 15V19A1.5 1.5 0 0 1 19 20.5H15A1.5 1.5 0 0 1 13.5 19V15A1.5 1.5 0 0 1 15 13.5Z"],
    "i-image": ["M5 4.5H19A2 2 0 0 1 21 6.5V17.5A2 2 0 0 1 19 19.5H5A2 2 0 0 1 3 17.5V6.5A2 2 0 0 1 5 4.5Z", "M6.8 10A1.7 1.7 0 1 1 10.2 10A1.7 1.7 0 1 1 6.8 10", "m3.5 17 5-4.5 4 3.5 3-2.5 5 4"],
    "i-magasin": ["M4 8h16l-1 11a2 2 0 0 1-2 1.8H7A2 2 0 0 1 5 19z", "M8.5 8V6a3.5 3.5 0 0 1 7 0v2"],
    "i-maison": ["M3.5 10.5 12 3.5l8.5 7M6 9.5v10h12v-10"],
    "i-manette": ["M7 11h4M9 9v4M15.5 11h.01M18 13h.01", "M7.5 6.5H16.5A5.5 5.5 0 0 1 22 12V12A5.5 5.5 0 0 1 16.5 17.5H7.5A5.5 5.5 0 0 1 2 12V12A5.5 5.5 0 0 1 7.5 6.5Z"],
    "i-note-mus": ["M9 18V6l11-2v12", "M3 18A3 3 0 1 1 9 18A3 3 0 1 1 3 18", "M14 16A3 3 0 1 1 20 16A3 3 0 1 1 14 16"],
    "i-notes": ["M6 3h9l4.5 4.5V19a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z", "M14.5 3v5h5M8 13h8M8 17h5"],
    "i-recommence": ["M20.5 12a8.5 8.5 0 1 1-2.7-6.2", "M20.5 4v5h-5"],
    "i-reglages": ["M9 12A3 3 0 1 1 15 12A3 3 0 1 1 9 12", "M12 2.5v3M12 18.5v3M21.5 12h-3M5.5 12h-3M18.7 5.3 16.6 7.4M7.4 16.6l-2.1 2.1M18.7 18.7l-2.1-2.1M7.4 7.4 5.3 5.3"],
    "i-reseau": ["M2.5 9a14 14 0 0 1 19 0M6 12.5a9 9 0 0 1 12 0M9.5 16a4 4 0 0 1 5 0", "M10.8 19.5A1.2 1.2 0 1 1 13.2 19.5A1.2 1.2 0 1 1 10.8 19.5"],
    "i-son": ["M4 9.5h3.5L12 5.5v13L7.5 14.5H4z", "M15.5 9.5a4 4 0 0 1 0 5M18 7a7.5 7.5 0 0 1 0 10"],
    "i-sortie": ["M14.5 3.5H18a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2h-3.5M10 16l-4-4 4-4M6 12h10"],
    "i-tel": ["M8.5 2.5H15.5A2.5 2.5 0 0 1 18 5V19A2.5 2.5 0 0 1 15.5 21.5H8.5A2.5 2.5 0 0 1 6 19V5A2.5 2.5 0 0 1 8.5 2.5Z", "M10.5 18.5h3"],
    "i-telech": ["M12 3.5v11M7.5 10.5 12 15l4.5-4.5M4 19.5h16"],
    "i-terminal": ["M4.5 4H19.5A2 2 0 0 1 21.5 6V18A2 2 0 0 1 19.5 20H4.5A2 2 0 0 1 2.5 18V6A2 2 0 0 1 4.5 4Z", "m6.5 9.5 3 2.5-3 2.5M13 15h4.5"],
    "i-recherche": ["M11 4a7 7 0 1 0 4.4 12.4l4.6 4.6 1.4-1.4-4.6-4.6A7 7 0 0 0 11 4zm0 2a5 5 0 1 1 0 10 5 5 0 0 1 0-10z"],
    "i-video": ["M4.5 6H13.5A2 2 0 0 1 15.5 8V16A2 2 0 0 1 13.5 18H4.5A2 2 0 0 1 2.5 16V8A2 2 0 0 1 4.5 6Z", "m15.5 10.5 6-3.5v10l-6-3.5z"],
};
