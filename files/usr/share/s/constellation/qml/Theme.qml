pragma Singleton
import QtQuick

// La palette de Constellation, reprise a l'identique des variables CSS de la
// page d'origine. Un seul endroit : si une couleur change, elle change partout.
QtObject {
    readonly property color linux:    "#ff4d4d"
    readonly property color windows:  "#4da6ff"
    readonly property color android:  "#4dff88"
    // LE QUATRIEME N'EST PAS UN MONDE, ET C'EST POURQUOI IL FALLAIT UNE
    // COULEUR DE PLUS. Rouge, bleu et vert disent D'OU vient un logiciel. Le
    // jaune ne dit pas d'ou vient un fichier : il dit que ce n'en est pas un.
    // Meme famille que les trois autres — deux canaux hauts, un a 0x4d — pour
    // qu'il se lise comme un pair et non comme une alerte.
    readonly property color fichier:  "#ffd24d"

    readonly property color espace:   "#050510"
    readonly property color verre:    Qt.rgba(12 / 255, 12 / 255, 20 / 255, 0.86)
    readonly property color verre2:   Qt.rgba(1, 1, 1, 0.045)
    readonly property color bord:     Qt.rgba(1, 1, 1, 0.09)
    readonly property color bordVif:  Qt.rgba(1, 1, 1, 0.22)
    readonly property color texte:    "#eef0f6"
    readonly property color texte2:   Qt.rgba(238 / 255, 240 / 255, 246 / 255, 0.62)
    readonly property color texte3:   Qt.rgba(238 / 255, 240 / 255, 246 / 255, 0.34)
    readonly property color lien:     Qt.rgba(1, 1, 1, 0.16)
    readonly property color lienVif:  Qt.rgba(1, 1, 1, 0.55)

    readonly property int rayon:      12
    readonly property int sphere:     40

    readonly property string police:     "IBM Plex Sans"
    readonly property string policeMono: "IBM Plex Mono"

    // La couleur d'un monde. Elle dit d'ou vient un logiciel, et c'est la
    // seule information que l'utilisateur lit avant le nom.
    // LES QUATRE COULEURS DE S, EN LISTE. Rouge Linux, bleu Windows, vert
    // Android, jaune fichier : c'est toute la palette du systeme, et la barre
    // laterale y pioche a chaque ouverture. Un reglage n'appartient a aucun
    // monde — il n'a donc pas de couleur PROPRE, et lui en donner une fixe
    // mentirait sur ce que la couleur veut dire partout ailleurs.
    readonly property var mondes: [linux, windows, android, fichier]

    // Un tirage qui EVITE LA REPETITION IMMEDIATE. Un aleatoire pur pose deux
    // fois la meme teinte cote a cote une fois sur quatre, et la colonne y perd
    // la lisibilite qu'on lui cherchait — deux ronds voisins de la meme couleur
    // se lisent comme un groupe, ce qu'ils ne sont pas.
    function tirage(combien) {
        var sortie = [];
        var precedente = -1;
        for (var i = 0; i < combien; i++) {
            var n = Math.floor(Math.random() * mondes.length);
            if (n === precedente) n = (n + 1 + Math.floor(Math.random() * 3))
                                     % mondes.length;
            precedente = n;
            sortie.push(mondes[n]);
        }
        return sortie;
    }

    function teinte(src) {
        if (src === "windows") return windows;
        if (src === "android") return android;
        if (src === "fichier") return fichier;
        return linux;
    }
}
