import QtQuick

// ═══════════════════════════════════════════════════════════════════════════
// LE CIEL VIVANT — demande de l'utilisateur le 2026-10-20 : « embellis la
// constellation ». Des etoiles qui scintillent, trois profondeurs qui glissent
// au gre de la souris, et de temps en temps une etoile filante.
//
// CE QU'IL COUTE, ET POURQUOI C'EST PEU. La regle de la page d'origine tient :
// le fond reste peint une fois. Ce ciel-ci est fait de petits elements de scene
// — quelques centaines de ronds de un a trois pixels, regroupes en SIX groupes
// — et ce sont les GROUPES qu'on anime, jamais les etoiles une a une :
//   - scintillement : l'opacite de six groupes, pas de deux cents etoiles ;
//   - profondeur    : la position de trois couches ;
//   - filante       : un seul element, quelques fois par minute.
// Une dizaine d'animations en tout, et pas une texture plein ecran de plus.
//
// UNE SEULE HORLOGE, A VINGT TEMPS PAR SECONDE. La premiere version animait
// derive et scintillement a 60 images/s : la scene changeait partout a chaque
// image, donc l'ecran entier se redessinait sans arret — mesure du 2026-10-21
// sur le banc logiciel, 12,8 % de CPU avant le ciel vivant, 66,7 % avec. Une
// derive de quelques pixels en trente secondes n'a que faire de 60 images :
// tout se calcule maintenant depuis « temps », avance par un minuteur de 50 ms,
// et les couches se posent AU PIXEL PRES — entre deux pixels, rien ne change,
// donc rien ne se redessine. Seule l'etoile filante, rare et rapide, garde
// une vraie animation.
//
// LE SCINTILLEMENT EST QUANTIFIE AU SEIZIEME. C'etait lui, presque tout le
// cout restant : chaque changement d'opacite d'un groupe redessine toutes ses
// etoiles. Arrondie au seizieme, l'opacite ne change qu'un tic sur trois ou
// quatre, et l'oeil ne voit pas la marche — une etoile qui scintille est
// faite pour vaciller. Mesure du 2026-10-21, banc logiciel 1920x1080, vraies
// applications de la machine, ciel visible, 10 s de repos :
//   Constellation d'avant les themes             15,2 %   150 Mo
//   la nouvelle, ciel vivant coupe               14,9 %   159 Mo
//   ciel vivant, premier jet a 60 images/s       66,7 %
//   ciel vivant retenu (20 Hz, pixel, seizieme)  20,5 %   164 Mo
//   n'importe lequel, cache par une fenetre       0,0 %
// Rendu LOGICIEL : sur le GPU de la machine, ces chiffres n'ont PAS ete
// mesures — c'est la premiere chose a relever apres un vrai demarrage.
//
// IL NE VIT QUE S'IL EST REGARDE — « actif » est « bureau.vivant », le meme
// interrupteur que la derive des etoiles : des qu'une fenetre non reduite cache
// le ciel, l'horloge s'arrete et les animations se mettent en PAUSE (rien
// n'est plus cadence, donc rien ne reveille la coquille ni le compositeur),
// et tout repart la ou il s'etait arrete, sans saut. Mesure du 2026-09-19 sur le banc : c'est ce qui
// fait tomber le ciel de 8,8 % de CPU a 0,0 % derriere une fenetre.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: ciel

    property bool actif: true
    // La position du pointeur sur l'ecran, et s'il y est.
    property point pointeur: Qt.point(width / 2, height / 2)
    property bool survole: false

    // LA PARALLAXE SUIT LA SOURIS AVEC RETARD, comme un regard qui suit, pas
    // comme un curseur. -1 a 1 sur chaque axe, 0 quand la souris est partie.
    readonly property real cibleX: survole && width > 0 ? (pointeur.x / width - 0.5) * 2 : 0
    readonly property real cibleY: survole && height > 0 ? (pointeur.y / height - 0.5) * 2 : 0
    property real regardX: cibleX
    property real regardY: cibleY
    Behavior on regardX { enabled: ciel.actif; NumberAnimation { duration: 1600; easing.type: Easing.OutCubic } }
    Behavior on regardY { enabled: ciel.actif; NumberAnimation { duration: 1600; easing.type: Easing.OutCubic } }

    // Un hasard DETERMINISTE : le meme ciel a chaque ouverture de session. Une
    // etoile qui changerait de place a chaque redemarrage ne serait pas une
    // etoile, ce serait du bruit — meme remarque que Fonds.js.
    // Le temps du ciel, en secondes. Il s'arrete avec lui, et repart d'ou il
    // en etait : aucun saut au retour.
    property real temps: 0
    Timer {
        interval: 50
        repeat: true
        running: ciel.actif && ciel.width > 0
        onTriggered: ciel.temps += 0.05
    }

    function hasard(n) {
        var x = Math.sin(n * 12.9898 + 78.233) * 43758.5453;
        return x - Math.floor(x);
    }

    // TROIS PROFONDEURS. La plus lointaine bouge le moins et brille le moins ;
    // la plus proche porte les quelques grosses etoiles a halo.
    readonly property var couches: [
        { n: 150, taille: 0.9, eclat: 0.50, ampleur: 5,  graine: 11, derive: 70000 },
        { n: 76,  taille: 1.4, eclat: 0.72, ampleur: 12, graine: 23, derive: 52000 },
        { n: 26,  taille: 2.1, eclat: 0.95, ampleur: 24, graine: 37, derive: 38000 }
    ]

    Repeater {
        model: ciel.couches
        delegate: Item {
            id: couche
            required property var modelData
            required property int index
            readonly property real ampleur: modelData.ampleur
            // Un aller-retour lent : de 0 a 1, puis -1, puis 0, sur deux fois
            // « derive » millisecondes — la courbe de l'ancienne animation.
            readonly property real derive: Math.sin(2 * Math.PI * ciel.temps
                                                    / (2 * modelData.derive / 1000))

            // La couche deborde de l'ecran de quoi glisser sans jamais montrer
            // son bord. Arrondie au pixel : voir l'en-tete.
            width: ciel.width + ampleur * 4
            height: ciel.height + ampleur * 4
            x: Math.round(-ampleur * 2 - ciel.regardX * ampleur + derive * ampleur * 0.7)
            y: Math.round(-ampleur * 2 - ciel.regardY * ampleur * 0.6)

            // DEUX GROUPES PAR COUCHE, qui scintillent a contretemps : c'est
            // assez pour que l'oeil voie un ciel qui respire, et ca reste deux
            // animations au lieu de cent cinquante.
            Repeater {
                model: 2
                delegate: Item {
                    id: groupe
                    required property int index
                    anchors.fill: parent
                    // Entre 0,30 et 1, chaque groupe sur sa periode et son
                    // dephasage — les memes que l'ancienne animation.
                    readonly property real periode: (5200 + couche.index * 1600 + groupe.index * 2000) / 1000
                    readonly property real phase: (groupe.index * 1300 + couche.index * 700) / 1000
                    opacity: Math.round((0.65 + 0.35 * Math.cos(2 * Math.PI * (ciel.temps - phase)
                                                                / periode)) * 16) / 16

                    Repeater {
                        model: Math.floor(couche.modelData.n / 2)
                        delegate: Item {
                            id: etoile
                            required property int index
                            readonly property int rang: couche.modelData.graine * 1000
                                                        + groupe.index * 500 + index
                            readonly property real r1: ciel.hasard(rang)
                            readonly property real r2: ciel.hasard(rang + 0.37)
                            readonly property real r3: ciel.hasard(rang + 0.71)
                            readonly property real r4: ciel.hasard(rang + 1.13)
                            // Une sur douze est un peu plus grosse : c'est elle
                            // qu'on remarque, et le reste devient du fond.
                            readonly property real taille: couche.modelData.taille
                                                           * (r3 > 0.92 ? 2.0 : (0.65 + r3 * 0.7))
                            // Quelques bleues, quelques chaudes, le reste blanc :
                            // la couleur des etoiles, pas celle des mondes.
                            readonly property color teinte: r4 < 0.16 ? "#cfe0ff"
                                                          : (r4 > 0.90 ? "#ffe4c2" : "#ffffff")
                            x: r1 * couche.width
                            y: r2 * couche.height
                            width: taille
                            height: taille

                            // LE HALO, pour les grosses de la couche proche
                            // seulement : un rond tres pale, deux fois et demie
                            // la taille. Aucun flou, aucun shader.
                            // Deux ronds tres pales, l'un dans l'autre : un
                            // halo en deux marches se lit comme une lueur, un
                            // seul comme un disque.
                            Rectangle {
                                visible: couche.index === 2 && etoile.r3 > 0.62
                                anchors.centerIn: parent
                                width: etoile.taille * 6
                                height: width
                                radius: width / 2
                                color: Qt.rgba(etoile.teinte.r, etoile.teinte.g, etoile.teinte.b, 0.035)
                                antialiasing: true
                            }
                            Rectangle {
                                visible: couche.index === 2 && etoile.r3 > 0.62
                                anchors.centerIn: parent
                                width: etoile.taille * 3
                                height: width
                                radius: width / 2
                                color: Qt.rgba(etoile.teinte.r, etoile.teinte.g, etoile.teinte.b, 0.07)
                                antialiasing: true
                            }
                            // LA CROIX DE DIFFRACTION, pour les plus brillantes —
                            // ce qui fait qu'une etoile photographiee ressemble a
                            // une etoile.
                            Rectangle {
                                visible: couche.index === 2 && etoile.r3 > 0.86
                                anchors.centerIn: parent
                                width: etoile.taille * 9
                                height: 1
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                            Rectangle {
                                visible: couche.index === 2 && etoile.r3 > 0.86
                                anchors.centerIn: parent
                                width: 1
                                height: etoile.taille * 9
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: etoile.teinte
                                opacity: couche.modelData.eclat * (0.55 + etoile.r1 * 0.45)
                                antialiasing: true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── L'ETOILE FILANTE ────────────────────────────────────────────────────
    // Une trainee qui s'eteint en allant, une fois toutes les dix a vingt-cinq
    // secondes — assez rare pour qu'on la remarque, jamais assez pour qu'elle
    // distraie. Elle ne part que si le ciel est regarde.
    Item {
        id: filante
        width: 190
        height: 2
        visible: false
        opacity: 0
        transformOrigin: Item.Right

        Rectangle {
            anchors.fill: parent
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.75; color: Qt.rgba(0.85, 0.92, 1, 0.45) }
                GradientStop { position: 1.0; color: "#ffffff" }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: -2
            width: 4; height: 4; radius: 2
            color: "#ffffff"
            antialiasing: true
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: -6
            width: 12; height: 12; radius: 6
            color: Qt.rgba(0.8, 0.9, 1, 0.18)
            antialiasing: true
        }
    }

    ParallelAnimation {
        id: vol
        property real departX: 0
        property real departY: 0
        property real arriveeX: 0
        property real arriveeY: 0
        NumberAnimation { target: filante; property: "x"; from: vol.departX; to: vol.arriveeX; duration: 1100; easing.type: Easing.InQuad }
        NumberAnimation { target: filante; property: "y"; from: vol.departY; to: vol.arriveeY; duration: 1100; easing.type: Easing.InQuad }
        SequentialAnimation {
            NumberAnimation { target: filante; property: "opacity"; from: 0; to: 1; duration: 180 }
            PauseAnimation { duration: 520 }
            NumberAnimation { target: filante; property: "opacity"; to: 0; duration: 400 }
        }
        onStopped: filante.visible = false
    }

    Timer {
        id: prochaine
        interval: 9000
        repeat: true
        running: ciel.actif && ciel.width > 0
        onTriggered: {
            interval = 10000 + Math.random() * 15000;
            // Toujours dans le tiers haut, toujours en descendant vers la
            // droite ou la gauche : une etoile filante qui monte se lit comme
            // une fusee.
            var versDroite = Math.random() < 0.6;
            var angle = (18 + Math.random() * 20) * Math.PI / 180;
            var longueur = ciel.width * (0.16 + Math.random() * 0.12);
            var x0 = ciel.width * (versDroite ? 0.08 + Math.random() * 0.5
                                              : 0.42 + Math.random() * 0.5);
            var y0 = ciel.height * (0.04 + Math.random() * 0.30);
            var dx = Math.cos(angle) * longueur * (versDroite ? 1 : -1);
            var dy = Math.sin(angle) * longueur;
            filante.rotation = versDroite ? angle * 180 / Math.PI
                                          : 180 - angle * 180 / Math.PI;
            vol.departX = x0 - filante.width;
            vol.departY = y0;
            vol.arriveeX = x0 - filante.width + dx;
            vol.arriveeY = y0 + dy;
            filante.visible = true;
            vol.restart();
        }
    }
}
