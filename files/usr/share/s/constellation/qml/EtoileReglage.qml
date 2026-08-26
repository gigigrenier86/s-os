import QtQuick

// Un reglage de S, dessine comme une etoile.
//
// POURQUOI UNE ETOILE ET NON UN INTERRUPTEUR. Demande de l'utilisateur le
// 2026-08-26 : « toujours sous forme d'etoiles comme le reste ». Ce n'est pas
// une coquetterie — un panneau de reglages fait d'interrupteurs plats est un
// panneau de reglages POSE SUR un bureau ; fait d'etoiles, il en fait partie.
// La regle 9 du carnet dit qu'une couture ne montre jamais son moteur ; celle-ci
// dit qu'elle ne montre pas non plus un autre bureau.
//
// L'ANNEAU PORTE L'ETAT, ET C'EST LE MEME LANGAGE QUE LE CIEL :
//   plein          -> la chose est allumee, ou l'action est disponible ;
//   pointille      -> elle est eteinte ;
//   arc partiel    -> une valeur, de 0 au maximum.
Item {
    id: etoile

    property var reglage: ({})
    property real diametre: 46

    // LE SURVOL SORT D'ICI, ET LA BARRE S'EN SERT POUR ECRIRE LE NOM A COTE.
    // Une infobulle de Qt aurait suffi ailleurs ; au bord droit de l'ecran elle
    // se poserait PAR-DESSUS la colonne qu'elle nomme — le defaut corrige sur
    // la barre des taches le 2026-08-25, ou l'etiquette empechait d'atteindre
    // ce qu'elle nommait.
    readonly property alias hovered: survol.hovered

    signal bascule()
    signal valeurDemandee(real v)
    signal choixDemande()
    signal glissiereDemandee()

    readonly property string forme: reglage.type || "bascule"
    readonly property bool allume: reglage.actif === true
    readonly property bool estJauge: forme === "glissiere"

    // LA JAUGE BOUGE AVANT QUE LA MACHINE AIT REPONDU, ET C'EST NECESSAIRE.
    // Une lecture de la luminosite coute pres d'une demi-seconde en I2C : tant
    // qu'elle n'est pas revenue, l'anneau montrait l'ANCIENNE valeur. Mesure du
    // 2026-08-26 : l'utilisateur a descendu luminosite et contraste a zero en
    // tournant la molette, faute de voir quoi que ce soit bouger.
    //
    // On affiche donc ce qu'on vient de demander, et la vraie valeur reprend la
    // main des qu'elle arrive.
    property real valeurLocale: -1
    onReglageChanged: valeurLocale = -1

    readonly property real valeurVue: valeurLocale >= 0 ? valeurLocale
                                                        : (reglage.valeur || 0)
    readonly property real fraction: {
        if (!estJauge) return 1;
        var m = reglage.max || 100;
        return m > 0 ? Math.max(0, Math.min(1, valeurVue / m)) : 0;
    }
    // LA COULEUR DIT L'IDENTITE, L'ANNEAU DIT L'ETAT — et il fallait les
    // separer. Un reglage n'appartient a aucun des quatre mondes : sa teinte
    // est tiree au sort a chaque ouverture de la barre, parmi les quatre
    // couleurs de S. Ce qui dit s'il est allume, c'est la FORME de l'anneau
    // (plein, pointille, ou arc de jauge) et la vivacite de la teinte, jamais
    // la teinte elle-meme.
    property color teinteImposee: "transparent"
    readonly property color teinte: {
        var base = (teinteImposee.a > 0) ? teinteImposee : Theme.texte;
        if (allume || estJauge) return base;
        // Eteint : la meme couleur, mais retenue. On garde la teinte pour que
        // l'oeil retrouve le reglage a sa place ; on baisse l'eclat pour que
        // « eteint » se voie sans lire.
        return Qt.rgba(base.r, base.g, base.b, 0.38);
    }

    implicitWidth: diametre
    implicitHeight: diametre

    scale: survol.hovered ? 1.10 : 1.0
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    HoverHandler { id: survol; cursorShape: Qt.PointingHandCursor }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: survol.hovered ? Theme.verre2 : "transparent"
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    Anneau {
        anchors.fill: parent
        couleur: etoile.teinte
        pointille: !etoile.allume && !etoile.estJauge
        fraction: etoile.fraction
        montrerReste: etoile.estJauge
        epaisseur: 2
    }

    Glyphe {
        anchors.centerIn: parent
        width: etoile.diametre * 0.44
        height: width
        nom: etoile.reglage.ico || "i-reglages"
        couleur: etoile.teinte
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            // CLIQUER SUR UNE JAUGE OUVRE UNE GLISSIERE, il ne bascule rien.
            // La molette seule ne suffisait pas : elle regle a l'aveugle et
            // sans repere, ce qui a mene la luminosite a zero le 2026-08-26.
            // Une barre qu'on voit et qu'on vise est le geste que tout le monde
            // connait.
            if (etoile.estJauge) etoile.glissiereDemandee();
            else if (etoile.forme === "choix") etoile.choixDemande();
            else etoile.bascule();
        }
    }

    // LA MOLETTE REGLE UNE JAUGE, ET C'EST LE GESTE QU'ON ESSAIE EN PREMIER
    // sur un rond qui affiche un pourcentage. Le pas de 5 est un compromis
    // mesure : sur la luminosite, chaque changement coute un aller-retour I2C
    // de pres d'une demi-seconde — un pas de 1 rendrait la molette inutilisable.
    WheelHandler {
        enabled: etoile.estJauge
        onWheel: function (evenement) {
            var m = etoile.reglage.max || 100;
            // LE PLANCHER EST AUSSI ICI, ET CE N'EST PAS UN DOUBLON INUTILE.
            // Le pont borne deja a dix pour cent : sans le meme plancher a
            // l'ecran, la jauge descendrait a zero pendant que la machine
            // reste a dix, et l'anneau mentirait jusqu'a la relecture.
            var plancher = (etoile.reglage.cle === "luminosite"
                            || etoile.reglage.cle === "contraste") ? 10 : 0;
            var pas = evenement.angleDelta.y > 0 ? 5 : -5;
            var v = Math.max(plancher, Math.min(m, etoile.valeurVue + pas));
            etoile.valeurLocale = v;
            etoile.valeurDemandee(v);
        }
    }
}
