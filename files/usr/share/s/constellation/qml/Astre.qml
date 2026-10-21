import QtQuick

// Une etoile : une application, posee dans le ciel de Constellation.
//
// CE QUE L'ANNEAU DIT, ET C'EST LA DISCIPLINE DU CARNET RENDUE VISIBLE :
//   sa COULEUR  -> le monde d'ou vient le logiciel (rouge/bleu/vert) ;
//   son TRAIT   -> plein si le logiciel a deja tourne ICI (compteur > 0),
//                  pointille s'il est seulement pose dans l'image.
// « Pose et jamais exerce » est ecrit partout dans ce depot ; ici il se voit
// sans un mot.
Item {
    id: astre

    property var app: ({})
    property real diametre: Theme.sphere
    property bool choisi: false
    property bool montrerNom: false
    // CONSTELLATION VIVANTE — l'etat d'activite, pousse par Constellation.qml
    // depuis le rapporteur de kwin (fenetres.js). Un halo plus discret que
    // celui du survol/de la selection : une etoile qu'on regarde doit
    // toujours se detacher plus qu'une etoile simplement en cours
    // d'execution, sinon le survol perd son sens.
    property bool actif: false
    property bool reduite: false

    signal ouvrir()
    signal menuDemande(real ex, real ey)
    signal deplacee(real nx, real ny)
    // LE CHOIX, SELON LE THEME — ajoute le 2026-10-20. Constellation garde son
    // geste : un clic bascule l'etoile, pour en choisir plusieurs sans touche.
    // Windows choisit UNE icone au clic et vide le reste, Ctrl+clic ajoute ;
    // Android ouvre au premier toucher, et seul Ctrl+clic choisit. C'est le
    // ciel (Constellation.qml) qui sait vider les autres : l'etoile demande.
    signal choixDemande(bool ajouter)
    // L'animation de lancement vit dans le visuel du theme ; l'etoile ne fait
    // que la declencher.
    signal lance()
    // DEPLACEMENT DE GROUPE EN DIRECT — correctif du 2026-10-20, releve par
    // l'utilisateur : « les etoiles se deplacent mal ». « deplacee » (ci-
    // dessus) ne tirait qu'AU LACHER : le reste d'une selection multiple
    // restait figee pendant tout le glissement, puis sautait d'un coup. Ces
    // deux signaux laissent Constellation.qml faire suivre les autres
    // etoiles choisies A CHAQUE IMAGE, au lieu d'un seul saut final.
    signal deplacementDebute()
    signal deplaceeEnDirect(real dx, real dy)
    // La position de depart de CE glissement precis — relue par
    // Constellation.qml pour calculer le delta a chaque image, et par les
    // AUTRES etoiles choisies pour savoir ou elles etaient avant de suivre.
    property real xDepart: 0
    property real yDepart: 0
    // EXPOSE A « ciel » POUR QUE relire() SACHE NE JAMAIS RECONSTRUIRE LE
    // CIEL PENDANT QU'UNE ETOILE EST TENUE PAR LA SOURIS — voir
    // Constellation.qml::relire(). Un alias, jamais une copie : il doit
    // rester vrai jusqu'a la derniere milliseconde du glissement.
    readonly property alias enGlissement: glisser.active

    // L'AIMANTAGE D'UNE GRILLE (Windows, Android) : l'icone lachee glisse
    // jusqu'a sa case au lieu d'y sauter. Ecrire « x » ici defait la liaison
    // au modele, exactement comme le DragHandler juste avant — la prochaine
    // relecture du ciel la rend, avec la position gardee.
    function allerA(nx, ny) {
        allerX.to = nx;
        allerY.to = ny;
        allerX.restart();
        allerY.restart();
    }
    NumberAnimation { id: allerX; target: astre; property: "x"; duration: Theme.dureeNormale; easing.type: Theme.courbe }
    NumberAnimation { id: allerY; target: astre; property: "y"; duration: Theme.dureeNormale; easing.type: Theme.courbe }

    readonly property color teinte: Theme.teinte(app.src || "linux")
    readonly property bool exerce: (app.ep || 0) > 0

    // EN CONSTELLATION, UNE SPHERE ; AILLEURS, UNE CASE DE GRILLE. La case
    // porte l'icone ET son nom : c'est elle qu'on glisse et qu'on choisit, comme
    // sur les deux systemes qu'on imite.
    width: Theme.estConstellation ? diametre : Theme.celluleL
    height: Theme.estConstellation ? diametre : Theme.celluleH

    // Micro-interaction tactile à 0 ms : compression à l'enfoncement (0.92),
    // éveil au survol (1.15), grossissement de sélection (1.20)
    // Windows ne grossit rien : la case choisie se surligne, c'est tout.
    scale: !Theme.estConstellation
           ? ((tapG.pressed && Theme.estAndroid) ? 0.94 : 1.0)
           : ((tapG.pressed || glisser.active) ? 0.92
              : (choisi ? 1.20 : (survol.hovered ? 1.15 : 1.0)))
    Behavior on scale {
        NumberAnimation {
            duration: (tapG.pressed || glisser.active) ? Theme.dureePression : Theme.dureeRapide
            easing.type: Easing.OutCubic
        }
    }
    Behavior on diametre { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    HoverHandler { id: survol; cursorShape: Qt.PointingHandCursor }

    // CONSTELLATION VIVANTE — la derive organique. UN OFFSET VISUEL ADDITIF,
    // JAMAIS UNE ECRITURE DE x/y : c'est astre.x/astre.y que le DragHandler
    // ecrit, que les traits de liaison lisent, que replacer() reconstruit
    // apres un glissement. Toucher a ces deux proprietes ici casserait tout
    // ca. Le contenu visuel est donc regroupe dans un Item separe, deplace
    // par un transform — l'Item racine (astre) reste la cible stable du
    // DragHandler et du hit-test des TapHandler, immobile.
    property real deriveX: 0
    property real deriveY: 0

    // LE DEPHASAGE DOIT ETRE DETERMINISTE, JAMAIS Math.random(). Le Repeater
    // du ciel (Constellation.qml, « model: { ... return sortie; } ») recree
    // TOUS ses delegues des que l'inventaire CHANGE (epinglage, suppression,
    // installation, lancement...) — un dephasage tire au hasard se retirerait
    // au sort a chaque fois, et donnerait des sauts visibles. Derive de app.id,
    // il redonne le meme dephasage apres recreation. Depuis le 2026-09-19 le
    // minuteur de quinze secondes ne recree plus rien tant que rien n'a change
    // (voir relire()) : avant, le ciel entier repartait a zero toutes les
    // quinze secondes.
    readonly property int dephasage: {
        var s = app.id || "";
        var somme = 0;
        for (var i = 0; i < s.length; i++) somme += s.charCodeAt(i);
        return somme % 5;
    }

    // ══ LE VISUEL, SELON LE THEME ══════════════════════════════════════════
    // TROIS VISUELS, UN SEUL D'INSTANCIE. Un Loader par theme plutot que trois
    // visuels caches : une etoile de Constellation porte deux canevas (l'anneau,
    // le glyphe) et une image de sphere — les garder vivants derriere une icone
    // Windows doublerait la memoire du bureau pour rien. Les gestes, eux,
    // restent sur l'etoile : ils ne dependent d'aucun visuel.
    Loader {
        anchors.fill: parent
        active: Theme.estConstellation
        sourceComponent: Component {
            Item {
                id: contenuVisuel
                anchors.fill: parent
                transform: Translate { x: astre.deriveX; y: astre.deriveY }

                // --- Le halo --------------------------------------------------
                // Pose SOUS le corps, agrandi : un rond flou de la couleur du monde. La
                // page le faisait avec box-shadow, qui n'existe pas ici.
                Rectangle {
                    anchors.centerIn: parent
                    width: astre.diametre * 1.5
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: astre.teinte
                    border.width: astre.diametre * 0.16
                    // HIERARCHIE D'INTENSITE : pressé (0.42) > survol/choisi (0.28) > actif (0.16) > repos (0)
                    opacity: (tapG.pressed || glisser.active) ? 0.42
                           : ((survol.hovered || astre.choisi) ? 0.28
                           : (astre.actif ? 0.16 : 0.0))
                    visible: opacity > 0
                    antialiasing: true
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                // Onde de lancement : pulsion lumineuse circulaire au double-clic
                Rectangle {
                    id: haloLancement
                    anchors.centerIn: parent
                    width: astre.diametre
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: astre.teinte
                    border.width: 2.5
                    opacity: 0
                    antialiasing: true
                }

                // --- Le corps de la sphere -------------------------------------------
                Image {
                    id: corps
                    anchors.fill: parent
                    source: "../glyphes/sphere.svg"
                    sourceSize.width: Math.max(4, Math.round(astre.diametre * 2))
                    sourceSize.height: Math.max(4, Math.round(astre.diametre * 2))
                    smooth: true
                }

                // --- L'anneau ---------------------------------------------------------
                Anneau {
                    anchors.fill: parent
                    couleur: astre.teinte
                    pointille: !astre.exerce
                    // « present mais en veille » : un peu plus fin qu'au repos normal,
                    // sans toucher a Anneau.qml lui-meme -- juste une epaisseur de plus.
                    epaisseur: astre.choisi ? 2.5 : (astre.reduite ? 1.5 : 2)
                }

                // --- Ce qu'elle porte : l'icone VRAIE, sinon le glyphe ----------------
                // L'icone du programme dit LEQUEL ; le glyphe ne dit que le genre. On
                // prefere donc toujours la premiere, et on ne retombe sur le second que
                // si la machine n'a aucun fichier d'icone pour cette application.
                Image {
                    id: vraieIcone
                    anchors.centerIn: parent
                    width: astre.diametre * 0.54
                    height: width
                    source: astre.app.img || ""
                    sourceSize.width: Math.max(8, Math.round(astre.diametre * 1.08))
                    sourceSize.height: Math.max(8, Math.round(astre.diametre * 1.08))
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source !== "" && status === Image.Ready
                }

                Glyphe {
                    anchors.centerIn: parent
                    width: astre.diametre * 0.47
                    height: width
                    nom: astre.app.ico || "i-boite"
                    couleur: astre.teinte
                    visible: !vraieIcone.visible
                }

                // --- Le compteur de lancements ---------------------------------------
                Rectangle {
                    visible: (astre.app.compte || 0) > 0
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: -5
                    anchors.topMargin: -5
                    height: 16
                    width: Math.max(16, compteur.implicitWidth + 8)
                    radius: height / 2
                    color: Theme.verre
                    border.color: Theme.bordVif
                    border.width: 1
                    Text {
                        id: compteur
                        anchors.centerIn: parent
                        text: (astre.app.compte || 0) > 99 ? "99+" : String(astre.app.compte || 0)
                        color: Theme.texte
                        font.family: Theme.policeMono
                        font.pixelSize: 10
                    }
                }

                // --- Le badge de notification ------------------------------------------
                // Coin OPPOSE du compteur d'usage, pour ne jamais les superposer.
                // Theme.fichier -- le jaune deja etabli pour « ceci n'appartient a aucun
                // monde » -- sert ici a dire « ceci demande attention », plutot que
                // d'inventer une sixieme couleur.
                Rectangle {
                    visible: (astre.app.badge || 0) > 0
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: -4
                    anchors.topMargin: -4
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.fichier
                    border.color: Theme.espace
                    border.width: 1.5
                }

                // --- L'etiquette ------------------------------------------------------
                // Au-dessus de l'etoile, jamais en dessous : les etoiles reposent pres
                // du bas du ciel, et un nom sous l'icone y sortirait de l'ecran ou se
                // ferait couvrir par la barre. Au-dessus, il reste toujours visible.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 8
                    text: astre.app.nom || ""
                    color: Theme.texte2
                    font.family: Theme.police
                    font.pixelSize: 11
                    opacity: (survol.hovered || astre.choisi || astre.montrerNom) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    // Le nom se lit sur un ciel sombre : une ombre portee evite qu'il
                    // disparaisse sur une nebuleuse claire.
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.9)
                }

            // Animation de lancement élastique et onde lumineuse style macOS/Fluent
            SequentialAnimation {
                id: animLancement
                ParallelAnimation {
                    NumberAnimation { target: contenuVisuel; property: "scale"; from: 1.0; to: 1.25; duration: 130; easing.type: Easing.OutQuad }
                    NumberAnimation { target: haloLancement; property: "opacity"; from: 0.85; to: 0.0; duration: 300; easing.type: Easing.OutQuad }
                    NumberAnimation { target: haloLancement; property: "scale"; from: 1.0; to: 2.2; duration: 300; easing.type: Easing.OutQuad }
                }
                NumberAnimation { target: contenuVisuel; property: "scale"; to: 1.0; duration: 180; easing.type: Easing.OutBounce }
            }
            Connections {
                target: astre
                function onLance() { animLancement.restart(); }
            }
            }
        }
    }

    // ── WINDOWS 11 : une icone, son nom en dessous, la case surlignee ──────
    Loader {
        anchors.fill: parent
        active: Theme.estWindows
        sourceComponent: Component {
            Item {
                id: caseW
                // LE SURLIGNAGE DE WINDOWS : un rectangle a peine teinte au
                // survol, franchement teinte quand l'icone est choisie, avec
                // un bord. Les deux ne se confondent jamais.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 4
                    color: astre.choisi ? Qt.rgba(0.60, 0.80, 1, 0.34)
                         : (survol.hovered ? Qt.rgba(0.80, 0.90, 1, 0.18) : "transparent")
                    border.width: astre.choisi ? 1 : 0
                    border.color: Qt.rgba(0.75, 0.88, 1, 0.70)
                    Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
                }
                IconeApp {
                    id: icoW
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    taille: Theme.iconeBureau
                    app: astre.app
                    opacity: astre.reduite ? 0.75 : 1
                }
                // L'activite : un petit trait sous l'icone, comme sur la
                // barre — le bureau de Windows n'en a pas, mais une icone
                // dont le programme tourne merite de le dire.
                Rectangle {
                    visible: astre.actif
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: icoW.y + icoW.height + 1
                    width: 14; height: 2; radius: 1
                    color: Theme.accent
                }
                Rectangle {
                    visible: (astre.app.badge || 0) > 0
                    x: icoW.x + icoW.width - 6
                    y: icoW.y - 3
                    width: 10; height: 10; radius: 5
                    color: Theme.accent
                    border.color: "#ffffff"
                    border.width: 1.5
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: icoW.y + icoW.height + 5
                    width: parent.width - 6
                    text: astre.app.nom || ""
                    color: Theme.texteBureau
                    font.family: Theme.police
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    // Deux lignes au repos, tout le nom une fois choisie :
                    // exactement ce que fait l'explorateur de Windows.
                    maximumLineCount: astre.choisi ? 4 : 2
                    elide: Text.ElideRight
                    style: Text.Raised
                    styleColor: Theme.ombreTexteBureau
                }
                SequentialAnimation {
                    id: lancementW
                    NumberAnimation { target: icoW; property: "opacity"; to: 0.55; duration: 90 }
                    NumberAnimation { target: icoW; property: "opacity"; to: 1.0; duration: 220 }
                }
                Connections {
                    target: astre
                    function onLance() { lancementW.restart(); }
                }
            }
        }
    }

    // ── ANDROID : une icone ronde sur sa pastille, le nom en dessous ───────
    Loader {
        anchors.fill: parent
        active: Theme.estAndroid
        sourceComponent: Component {
            Item {
                // LES ICONES « A THEME » DE MATERIAL YOU : chaque application
                // pose sa vraie icone sur une pastille ronde de la palette.
                // Les icones de Linux et de Windows n'ont pas de forme
                // commune ; la pastille leur en donne une, et c'est ce qui
                // rend un ecran d'accueil Android si calme.
                Rectangle {
                    id: pastille
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 6
                    width: Theme.iconeBureau
                    height: width
                    radius: width / 2
                    color: Theme.palette.surfaceContainerHighest
                    border.width: astre.choisi ? 3 : 0
                    border.color: Theme.palette.primary
                    antialiasing: true
                    scale: survol.hovered ? 1.06 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.dureeRapide; easing.type: Theme.courbe } }

                    IconeApp {
                        anchors.centerIn: parent
                        taille: parent.width * 0.62
                        app: astre.app
                        couleur: Theme.palette.primary
                    }
                }
                Rectangle {
                    visible: astre.actif
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: pastille.y + pastille.height + 3
                    width: 6; height: 6; radius: 3
                    color: Theme.palette.primary
                }
                Rectangle {
                    visible: (astre.app.badge || 0) > 0
                    x: pastille.x + pastille.width - 12
                    y: pastille.y - 1
                    width: 14; height: 14; radius: 7
                    color: Theme.palette.tertiary
                    border.color: Theme.palette.surface
                    border.width: 2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: pastille.y + pastille.height + 11
                    width: parent.width - 4
                    text: astre.app.nom || ""
                    color: Theme.texteBureau
                    font.family: Theme.police
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: astre.choisi ? 2 : 1
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    style: Text.Raised
                    styleColor: Theme.ombreTexteBureau
                }
                SequentialAnimation {
                    id: lancementA
                    NumberAnimation { target: pastille; property: "scale"; to: 0.86; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pastille; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack }
                }
                Connections {
                    target: astre
                    function onLance() { lancementA.restart(); }
                }
            }
        }
    }

    // CONSTELLATION VIVANTE — la derive elle-meme. Amplitude 2-3 px ("un peu",
    // selon le mot de l'utilisateur), periode desynchronisee 6-12 s par le
    // dephasage. Gate par Session.bureau.vivant : coupee net des qu'une
    // fenetre est plein ecran (voir Constellation.qml) -- personne ne voit le
    // ciel a ce moment-la, autant rendre au jeu le CPU/GPU que ces deux
    // animations en boucle auraient coute.
    // « reseau » (Constellation vivante, Signal 4) module la vitesse plutot
    // que d'ajouter un element visuel de plus -- un ciel plus eveille quand
    // des donnees circulent, sans cout supplementaire. 1.0 au repos.
    readonly property real vitesseDerive: Session.bureau ? Session.bureau.deriveVitesse : 1.0

    SequentialAnimation on deriveX {
        running: Theme.estConstellation && (Session.bureau ? Session.bureau.vivant : true)
        loops: Animation.Infinite
        NumberAnimation { to: 2.4; duration: (6000 + astre.dephasage * 1400) / astre.vitesseDerive; easing.type: Easing.InOutSine }
        NumberAnimation { to: -2.4; duration: (6000 + astre.dephasage * 1400) / astre.vitesseDerive; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on deriveY {
        running: Theme.estConstellation && (Session.bureau ? Session.bureau.vivant : true)
        loops: Animation.Infinite
        // Dephasage different en Y (decale de 2) pour que la derive ne
        // dessine pas une simple diagonale repetitive.
        NumberAnimation { to: -1.8; duration: (7200 + ((astre.dephasage + 2) % 5) * 1400) / astre.vitesseDerive; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.8; duration: (7200 + ((astre.dephasage + 2) % 5) * 1400) / astre.vitesseDerive; easing.type: Easing.InOutSine }
    }

    // --- Les gestes -------------------------------------------------------
    // UN DOUBLE-CLIC OUVRE, UN SIMPLE CLIC NE FAIT QUE CHOISIR. C'est la regle
    // de la page, et c'est ce qui permet de deplacer une etoile sans la lancer.
    //
    // SAUF EN ANDROID, OU LE PREMIER TOUCHER OUVRE — c'est le geste d'un ecran
    // d'accueil, et le contraire y paraitrait casse. Le choix y passe par
    // Ctrl+clic, et le cadre de selection du fond marche comme partout.
    TapHandler {
        id: tapG
        acceptedButtons: Qt.LeftButton
        onTapped: {
            var ctrl = (tapG.point.modifiers & Qt.ControlModifier) !== 0;
            if (Theme.estAndroid) {
                if (ctrl) { astre.choixDemande(true); return; }
                // Le second toucher d'un double toucher ne rouvre pas.
                if (tapG.tapCount > 1) return;
                astre.lance();
                astre.ouvrir();
                return;
            }
            if (Theme.estWindows) { astre.choixDemande(ctrl); return; }
            astre.choisi = !astre.choisi;
        }
        onDoubleTapped: {
            if (Theme.estAndroid) return;
            astre.lance();
            astre.ouvrir();
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: function (evenement) {
            var p = astre.mapToItem(null, evenement.position.x, evenement.position.y);
            astre.menuDemande(p.x, p.y);
            // SANS CECI, LE CIEL RECOIT LE MEME CLIC DROIT JUSTE APRES, ET
            // OUVRE menuDuFond PAR-DESSUS menuContextuel — releve par
            // l'utilisateur le 2026-08-28 : « les choix du clic droit sur le
            // bureau et sur les etoiles sont les memes ». Un TapHandler ne
            // consomme pas un point par defaut ; il faut le dire.
            evenement.accepted = true;
        }
    }

    DragHandler {
        id: glisser
        target: astre
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: {
            if (active) {
                // LE POINT DE DEPART DE CE GLISSEMENT-CI. « x »/« y » sont
                // deja les bons a cet instant : rien n'a encore ete deplace.
                astre.xDepart = astre.x;
                astre.yDepart = astre.y;
                astre.deplacementDebute();
            } else {
                astre.deplacee(astre.x, astre.y);
            }
        }
    }

    // LE DELTA DEPUIS « xDepart »/« yDepart », A CHAQUE IMAGE DU
    // GLISSEMENT — pas accumule pas-a-pas, pour qu'une image manquee ne
    // fasse jamais deriver le groupe de ce qu'il tient vraiment a l'ecran.
    onXChanged: if (glisser.active) astre.deplaceeEnDirect(astre.x - astre.xDepart, astre.y - astre.yDepart)
    onYChanged: if (glisser.active) astre.deplaceeEnDirect(astre.x - astre.xDepart, astre.y - astre.yDepart)

    // GLISSER-DEPOSE REEL VERS L'EXTERIEUR (2026-09-10). Jusqu'ici le
    // DragHandler ci-dessus ne faisait QUE deplacer astre.x/astre.y dans la
    // scene -- aucune session Wayland wl_data_device.start_drag n'etait
    // jamais emise, confirme par lecture du code le 2026-08-27. MESURE au
    // banc le 2026-09-10, sur une fenetre QtQuick jetable independante de ce
    // fichier : Drag.active suivant un DragHandler.active fait bien partir
    // un vrai start_drag, et le protocole va jusqu'a dnd_drop_performed().
    //
    // SEULS LES VRAIS FICHIERS ONT UN CONTENU A OFFRIR. app.chemin n'existe
    // que pour ce que fichiers_bureau()/composer_etoiles() posent depuis le
    // disque (noyau.py) -- jamais pour un lanceur d'application, qui porte
    // "fichier" (le .desktop), pas "chemin". Glisser une icone d'application
    // vers l'exterieur continue donc a ne faire QUE la deplacer dans le ciel,
    // exactement comme avant -- rien n'y avait de sens a offrir.
    property string cheminGlissable: app.chemin || ""
    Drag.active: glisser.active && astre.cheminGlissable !== ""
    Drag.dragType: Drag.Automatic
    Drag.mimeData: cheminGlissable !== ""
        ? { "text/uri-list": "file://" + encodeURI(cheminGlissable) }
        : ({})
}
