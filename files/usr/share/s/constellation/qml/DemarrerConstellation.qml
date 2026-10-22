import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "Fonds.js" as Fonds

// LE MENU DEMARRER DE CONSTELLATION — la recherche, les applications, les
// dossiers, les reglages, l'alimentation.
//
// DEPLACE ICI TEL QUEL LE 2026-10-20, depuis Constellation.qml, quand les
// themes sont arrives : chaque theme a maintenant SON menu (DemarrerWindows,
// TiroirAndroid), charge dans le meme Popup, et un seul est vivant a la fois.
// Ce qui est commun aux trois — ce qu'on cherche, ce que veut dire « Entree »,
// la liste filtree — est reste dans le Popup (Constellation.qml, menuDemarrer)
// et s'atteint par « menu », que le Popup pose a la creation (voir plus bas).
ColumnLayout {
    id: demarrerC
    spacing: 0

    // LE MENU ET LE BUREAU ARRIVENT EN PROPRIETES, posees par Constellation.qml
    // a la creation — et non lus dans Session : ce menu nait AVANT que le bureau
    // ne remplisse Session (son Component.onCompleted passe apres celui de ses
    // enfants), et une liaison sur Session.menu y tombait sur « null ». Les
    // delegues de ce fichier les atteignent par l'identifiant de sa racine.
    property var menu: Session.menu
    property var hote: Session.bureau
    // Le champ que le menu met au point et remplit quand on tape sur le bureau.
    property alias champRecherche: recherche

    // --- La recherche ---
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 60

        TextField {
            id: recherche
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 14
            anchors.bottomMargin: 12
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            placeholderText: "Chercher une application ou lancer une recherche Google"
            placeholderTextColor: Theme.texte3
            color: Theme.texte
            font.family: Theme.police
            font.pixelSize: 13
            background: Rectangle {
                radius: 8
                color: Theme.verre2
                border.width: 1
                border.color: recherche.activeFocus ? Theme.bordVif : Theme.bord
            }
            // LA REQUETE VIT DANS LE MENU, PAS ICI — depuis le 2026-10-20. Les
            // trois themes ont chacun leur champ de recherche ; un seul endroit
            // sait ce qu'on cherche et ce que veut dire « Entree » (le menu,
            // Constellation.qml), sinon les trois finiraient par diverger.
            onTextChanged: demarrerC.menu.requete = text
            onAccepted: demarrerC.menu.valider()
        }
    }

    // --- Les onglets ---
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        color: "transparent"
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Theme.bord
        }
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.bottom: parent.bottom
            spacing: 2
            Repeater {
                model: [
                    { cle: "apps",     nom: "Applications",  ico: "i-grille" },
                    { cle: "dossiers", nom: "Dossiers",      ico: "i-dossier" },
                    { cle: "reglages", nom: "Reglages",      ico: "i-reglages" },
                    { cle: "alim",     nom: "Alimentation",  ico: "i-alim" }
                ]
                delegate: Item {
                    required property var modelData
                    readonly property bool actif: demarrerC.menu.vue === modelData.cle
                    width: contenuOnglet.width + 24
                    height: 37
                    scale: tapOnglet.pressed ? 0.95 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: tapOnglet.pressed ? Theme.dureePression : Theme.dureeRapide
                            easing.type: Easing.OutCubic
                        }
                    }
                    HoverHandler { id: survolOnglet; cursorShape: Qt.PointingHandCursor }
                    Row {
                        id: contenuOnglet
                        anchors.centerIn: parent
                        spacing: 7
                        Glyphe {
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            nom: modelData.ico
                            couleur: actif ? Theme.texte
                                           : (tapOnglet.pressed ? Theme.texte : (survolOnglet.hovered ? Theme.texte2 : Theme.texte3))
                            Behavior on couleur { ColorAnimation { duration: Theme.dureeRapide } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.nom
                            font.family: Theme.police
                            font.pixelSize: 12
                            color: actif ? Theme.texte
                                         : (tapOnglet.pressed ? Theme.texte : (survolOnglet.hovered ? Theme.texte2 : Theme.texte3))
                            Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 2
                        radius: 1
                        color: actif ? Theme.texte : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dureeRapide } }
                    }
                    TapHandler {
                        id: tapOnglet
                        onTapped: Session.menu.vue = modelData.cle
                    }
                }
            }
        }
    }

    // --- Le corps, partie APPLICATIONS ---
    //
    // UNE GridView, ET PAS UN Repeater DANS UN Flickable. C'est une
    // correction mesuree au banc le 2026-08-24, et elle vaut d'etre
    // ecrite parce qu'elle n'a rien d'evident.
    //
    // Un Repeater fabrique TOUTES ses tuiles, y compris celles qui
    // tombent bien en dessous du panneau. Pour du texte et des images,
    // cela ne se voit pas : le decoupage du Flickable les ecarte.
    // Mais les anneaux et les glyphes de Constellation sont des Shape,
    // et un Shape NE RESPECTE PAS le decoupage de ses ancetres —
    // verifie sur le rendu logiciel ET sur le vrai pipeline GPU. Les
    // anneaux des tuiles hors panneau se dessinaient donc par-dessus le
    // bureau, sous la barre des taches.
    //
    // Une GridView ne construit que ce qui est visible ; « cacheBuffer:
    // 0 » lui interdit d'en preparer au-dela, et la hauteur calee sur
    // un multiple de la cellule, avec SnapToRow, garantit qu'aucune
    // rangee n'est jamais a cheval sur le bord. Il n'existe alors plus
    // une seule tuile hors du panneau — le defaut n'est pas masque,
    // il n'a plus de quoi se produire.
    Item {
        id: cadreApps
        visible: demarrerC.menu.vue === "apps"
        Layout.fillWidth: true
        Layout.fillHeight: true

        GridView {
            id: grilleApps
            objectName: "grilleAppsConstellation"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14
            width: Math.max(0, parent.width - 32)
            height: Math.max(cellHeight,
                             Math.floor((parent.height - 22) / cellHeight) * cellHeight)
            clip: true
            cacheBuffer: 0
            snapMode: GridView.SnapToRow
            boundsBehavior: Flickable.StopAtBounds

            readonly property int colonnes: Math.max(1, Math.floor(width / 88))
            cellWidth: width / colonnes
            cellHeight: 96

            ScrollBar.vertical: ScrollBar { }

            model: demarrerC.menu.vue === "apps" ? demarrerC.menu.filtrees() : []

            delegate: Tuile {
                required property var modelData
                app: modelData
                width: grilleApps.cellWidth - 6
                height: grilleApps.cellHeight - 6
                onOuvrir: Session.menu.lancerApp(app)
                onEpingler: function (oui) {
                    pont.epingler(app.id, oui);
                    Session.bureau.relire();
                    Session.bureau.dire(oui ? (app.nom + " epinglee")
                                            : (app.nom + " retiree de la barre"));
                }
                onMenuDemande: function (ex, ey) { Session.bureau.ouvrirMenuContextuel(app, ex, ey); }
            }
        }
    }

    // --- Le corps, LES AUTRES ONGLETS ---
    // Ils tiennent sans defiler (mesure : 77, 324 et 155 pixels pour
    // une hauteur utile de 542), donc aucune tuile hors cadre ici.
    Flickable {
        visible: demarrerC.menu.vue !== "apps"
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: corps.height
        clip: true
        ScrollBar.vertical: ScrollBar { }

        Column {
            id: corps
            width: parent.width
            padding: 16
            // LA LARGEUR NEGATIVE, ET C'EST LA CAUSE DES ERREURS DE
            // Fonds.js QUE LE CARNET DISAIT INCONNUES.
            //
            // Tant que la ScrollView n'a pas mesure, « parent.width »
            // vaut 0. Les Column filles portaient « parent.width - 32 »
            // pour compenser le padding : elles valaient donc -32. La
            // Grid dessous heritait -32, son « columns » retombait a 1
            // par le Math.max, et chaque vignette calculait
            // (-32 - 0) / 1 = -32 de large, -20 de haut.
            //
            // Releve sur la machine le 2026-08-25 a 18 h, par le temoin
            // pose le matin meme :
            //     qml: vignette trois : dimensions refusees -32x-20
            //
            // ET C'EST POURQUOI LE BANC DU MATIN AVAIT REFUTE LA BONNE
            // HYPOTHESE. Il avait essaye une taille NULLE, qui n'appelle
            // jamais onPaint — vrai, et sans rapport. Une taille
            // NEGATIVE, elle, appelle onPaint et passe des valeurs
            // impossibles a createRadialGradient. Le banc mesurait le
            // mauvais cas et rendait un verdict assure.
            //
            // Le Math.max borne la soustraction a sa source. Le garde et
            // le temoin restent en place : ils ne coutent rien et ils
            // viennent de prouver leur valeur.
            spacing: 14

            // ---- Dossiers ----
            Column {
                visible: demarrerC.menu.vue === "dossiers"
                width: Math.max(0, parent.width - 32)
                spacing: 1
                Repeater {
                    model: demarrerC.hote.listeDossiers
                    delegate: Rangee {
                        required property var modelData
                        texte: modelData.nom
                        detail: modelData.detail
                        glyphe: modelData.ico
                        onChoisi: {
                            Session.bureau.dire(pont.ouvrirDossier(modelData.chemin));
                            Session.menu.close();
                        }
                    }
                }
            }

            // ---- Reglages ----
            Column {
                id: colReglages
                visible: demarrerC.menu.vue === "reglages"
                width: Math.max(0, parent.width - 32)
                spacing: 14

                Text {
                    text: "THEME"
                    color: Theme.texte3
                    font.family: Theme.policeMono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                // LES TROIS THEMES, A PORTEE DU MENU — ajoute le 2026-10-20. Un
                // theme qu'il faudrait chercher dans un sous-panneau serait un
                // theme que personne n'essaie. Le clic l'applique en direct.
                Row {
                    spacing: 10
                    Repeater {
                        model: Theme.themes
                        delegate: CarteTheme {
                            required property var modelData
                            width: Math.max(4, Math.floor((Math.max(0, colReglages.width) - 20) / 3))
                            cle: modelData.cle
                            nom: modelData.nom
                            detail: modelData.detail
                            onChoisie: Session.bureau.appliquerTheme(modelData.cle)
                        }
                    }
                }

                Text {
                    text: "FOND D'ECRAN"
                    color: Theme.texte3
                    font.family: Theme.policeMono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                Grid {
                    width: parent.width
                    columns: Math.max(1, Math.floor(width / 113))
                    spacing: 9
                    Repeater {
                        model: Fonds.ordre("constellation")
                        delegate: Item {
                            required property string modelData
                            // « parent » est null a l'instant ou le
                            // Repeater cree ce delegue — il ne
                            // reparente qu'apres — et parent.width vaut
                            // alors undefined, donc width vaut NaN.
                            // Une taille NaN ne fait rien peindre du
                            // tout, ce qui est pire qu'une erreur :
                            // c'est une vignette vide sans un mot.
                            width: parent
                                   ? (parent.width - 9 * (parent.columns - 1)) / parent.columns
                                   : 0
                            height: width * 10 / 16
                            FondEcran {
                                anchors.fill: parent
                                fondId: modelData
                                theme: "constellation"
                                options: ({ sombre: true })
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 8
                                border.width: 1.5
                                border.color: Theme.fondConstellation === modelData
                                              ? Theme.texte : Theme.bord
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 5
                                text: Fonds.FONDS[modelData].nom
                                color: Theme.texte2
                                font.family: Theme.police
                                font.pixelSize: 10
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: Session.bureau.choisirFond(modelData)
                            }
                        }
                    }
                }

                Text {
                    text: "BUREAU"
                    color: Theme.texte3
                    font.family: Theme.policeMono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
                Rangee {
                    width: parent.width
                    texte: "Ciel vivant"
                    detail: Theme.cielVivant ? "oui" : "non"
                    glyphe: "i-etincelle"
                    onChoisi: demarrerC.hote.reglerTheme("ciel_vivant", !Theme.cielVivant)
                }
                Rangee {
                    width: parent.width
                    texte: "Toujours afficher les noms"
                    detail: demarrerC.hote.nomsToujours ? "oui" : "non"
                    glyphe: "i-doc"
                    onChoisi: {
                        demarrerC.hote.nomsToujours = !demarrerC.hote.nomsToujours;
                        pont.reglerFond("noms", demarrerC.hote.nomsToujours);
                    }
                }
                Rangee {
                    width: parent.width
                    texte: "Vider le bureau"
                    detail: Object.keys(demarrerC.hote.donnees.placees).length + " posees"
                    glyphe: "i-grille"
                    onChoisi: {
                        for (var ident in demarrerC.hote.donnees.placees)
                            pont.retirerDuBureau(ident);
                        demarrerC.hote.relire();
                        demarrerC.hote.dire("bureau vide");
                    }
                }
                Rangee {
                    width: parent.width
                    texte: "Personnaliser…"
                    detail: "fonds, couleurs, images"
                    glyphe: "i-image"
                    onChoisi: demarrerC.hote.ouvrirPersonnaliser()
                }
            }

            // ---- Alimentation ----
            Column {
                visible: demarrerC.menu.vue === "alim"
                width: Math.max(0, parent.width - 32)
                spacing: 1
                Repeater {
                    model: [
                        { act: "verrouiller", nom: "Verrouiller",  ico: "i-cadenas",    grave: false },
                        { act: "deconnecter", nom: "Se deconnecter", ico: "i-sortie",   grave: false },
                        { act: "redemarrer",  nom: "Redemarrer",   ico: "i-recommence", grave: true },
                        { act: "eteindre",    nom: "Eteindre",     ico: "i-alim",       grave: true }
                    ]
                    delegate: Rangee {
                        required property var modelData
                        texte: modelData.nom
                        glyphe: modelData.ico
                        grave: modelData.grave
                        onChoisi: {
                            Session.menu.close();
                            pont.session(modelData.act);
                        }
                    }
                }
            }
        }
    }
}
