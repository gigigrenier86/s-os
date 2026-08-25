pragma Singleton
import QtQuick

// La palette de Constellation, reprise a l'identique des variables CSS de la
// page d'origine. Un seul endroit : si une couleur change, elle change partout.
QtObject {
    readonly property color linux:    "#ff4d4d"
    readonly property color windows:  "#4da6ff"
    readonly property color android:  "#4dff88"

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
    function teinte(src) {
        if (src === "windows") return windows;
        if (src === "android") return android;
        return linux;
    }
}
