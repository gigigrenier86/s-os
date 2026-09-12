// Principal.qml — la fenetre entiere du lecteur IPTV de S.
//
// Palette dupliquee depuis Theme.qml de Constellation (memes valeurs), pas
// partagee : cette fenetre vit hors de l'arbre QML du bureau, comme mpv
// lui-meme vivra hors de cette fenetre — un programme, une fenetre, gere
// comme n'importe quelle autre par la coquille.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: fenetre
    width: 980
    height: 620
    minimumWidth: 640
    minimumHeight: 420
    visible: true
    title: "S — Lecteur IPTV"
    color: cEspace

    readonly property color cEspace:  "#050510"
    readonly property color cVerre:   Qt.rgba(12 / 255, 12 / 255, 20 / 255, 0.92)
    readonly property color cVerre2:  Qt.rgba(1, 1, 1, 0.05)
    readonly property color cBord:    Qt.rgba(1, 1, 1, 0.09)
    readonly property color cTexte:   "#eef0f6"
    readonly property color cTexte2:  Qt.rgba(238 / 255, 240 / 255, 246 / 255, 0.62)
    readonly property color cAccent:  "#4dff88"

    property var listePlaylists: pont.playlists()
    property var chaines: []
    property var chainesFiltrees: []
    property string enCoursTitre: ""
    property bool enLecture: false
    property int playlistChoisie: -1
    property bool chargement: false

    function rafraichirPlaylists() { listePlaylists = pont.playlists() }

    function filtrer() {
        var q = champRecherche.text.toLowerCase()
        if (!q) { chainesFiltrees = chaines; return }
        chainesFiltrees = chaines.filter(function (c) {
            return c.nom.toLowerCase().indexOf(q) !== -1
        })
    }

    Connections {
        target: pont
        function onChainesPretes(liste) {
            chargement = false
            chaines = liste
            filtrer()
        }
        function onErreurChargement(msg) {
            chargement = false
            boiteErreur.texte = msg
            boiteErreur.open()
        }
        function onLectureChangee(actif, titre) {
            enLecture = actif
            enCoursTitre = titre
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 1

        // --- Colonne des playlists ------------------------------------
        Rectangle {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: cVerre

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Label {
                    text: "Playlists"
                    color: cTexte
                    font.pixelSize: 16
                    font.bold: true
                }

                Label {
                    visible: listePlaylists.length === 0
                    Layout.fillWidth: true
                    text: "Aucune. Ajoutez une playlist M3U ou un abonnement Xtream Codes."
                    color: cTexte2
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                }

                ListView {
                    id: listeListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: listePlaylists
                    delegate: ItemDelegate {
                        width: listeListView.width
                        highlighted: index === playlistChoisie
                        contentItem: RowLayout {
                            spacing: 4
                            Label {
                                text: modelData.nom
                                color: cTexte
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            ToolButton {
                                text: "✕"
                                implicitWidth: 26
                                implicitHeight: 26
                                onClicked: {
                                    pont.supprimer(index)
                                    rafraichirPlaylists()
                                    if (playlistChoisie === index) {
                                        playlistChoisie = -1
                                        chaines = []
                                        chainesFiltrees = []
                                    }
                                }
                            }
                        }
                        onClicked: {
                            playlistChoisie = index
                            chargement = true
                            chaines = []
                            chainesFiltrees = []
                            pont.demanderChaines(index)
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "+ Ajouter une playlist"
                    onClicked: boiteAjout.open()
                }
            }
        }

        // --- Colonne des chaines ----------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 10
                spacing: 8
                TextField {
                    id: champRecherche
                    Layout.fillWidth: true
                    placeholderText: "Rechercher une chaine..."
                    onTextChanged: filtrer()
                }
                Label {
                    visible: chargement
                    text: "Chargement..."
                    color: cTexte2
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: chainesFiltrees

                section.property: "groupe"
                section.criteria: ViewSection.FullString
                section.delegate: Rectangle {
                    width: ListView.view ? ListView.view.width : 0
                    height: 26
                    color: cVerre2
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        text: section.length ? section : "Sans categorie"
                        color: cTexte2
                        font.pixelSize: 12
                    }
                }

                delegate: ItemDelegate {
                    width: ListView.view ? ListView.view.width : 0
                    text: modelData.nom
                    onClicked: pont.lancer(modelData.url, modelData.nom)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 44
                color: cVerre
                visible: enLecture
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    Label {
                        text: "En cours : " + enCoursTitre
                        color: cAccent
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Button {
                        text: "Arreter"
                        onClicked: pont.arreter()
                    }
                }
            }
        }
    }

    Dialog {
        id: boiteAjout
        objectName: "boiteAjout"
        title: "Ajouter une playlist"
        modal: true
        anchors.centerIn: parent
        width: 420
        standardButtons: Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: 8

            TabBar {
                id: onglets
                Layout.fillWidth: true
                TabButton { text: "M3U" }
                TabButton { text: "Xtream Codes" }
            }

            StackLayout {
                Layout.fillWidth: true
                currentIndex: onglets.currentIndex

                ColumnLayout {
                    spacing: 6
                    TextField {
                        id: nomM3U
                        Layout.fillWidth: true
                        placeholderText: "Nom (ex : Mon fournisseur)"
                    }
                    TextField {
                        id: urlM3U
                        Layout.fillWidth: true
                        placeholderText: "Adresse de la playlist M3U"
                    }
                    Button {
                        Layout.fillWidth: true
                        text: "Ajouter"
                        enabled: urlM3U.text.length > 0
                        onClicked: {
                            pont.ajouterM3U(nomM3U.text, urlM3U.text)
                            rafraichirPlaylists()
                            nomM3U.text = ""
                            urlM3U.text = ""
                            boiteAjout.close()
                        }
                    }
                }

                ColumnLayout {
                    spacing: 6
                    TextField {
                        id: nomX
                        Layout.fillWidth: true
                        placeholderText: "Nom"
                    }
                    TextField {
                        id: serveurX
                        Layout.fillWidth: true
                        placeholderText: "Serveur (ex : http://exemple.com)"
                    }
                    TextField {
                        id: portX
                        Layout.fillWidth: true
                        placeholderText: "Port (optionnel)"
                    }
                    TextField {
                        id: userX
                        Layout.fillWidth: true
                        placeholderText: "Utilisateur"
                    }
                    TextField {
                        id: passX
                        Layout.fillWidth: true
                        placeholderText: "Mot de passe"
                        echoMode: TextInput.Password
                    }
                    Button {
                        Layout.fillWidth: true
                        text: "Ajouter"
                        enabled: serveurX.text.length > 0 && userX.text.length > 0
                        onClicked: {
                            pont.ajouterXtream(nomX.text, serveurX.text, portX.text,
                                                userX.text, passX.text)
                            rafraichirPlaylists()
                            nomX.text = ""
                            serveurX.text = ""
                            portX.text = ""
                            userX.text = ""
                            passX.text = ""
                            boiteAjout.close()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: boiteErreur
        objectName: "boiteErreur"
        property string texte: ""
        title: "Erreur"
        modal: true
        anchors.centerIn: parent
        width: 380
        standardButtons: Dialog.Ok
        contentItem: Label {
            text: boiteErreur.texte
            wrapMode: Text.WordWrap
            color: cTexte
        }
    }
}
