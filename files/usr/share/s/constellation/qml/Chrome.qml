import QtQuick
import QtQuick.Controls.Basic

// ═══════════════════════════════════════════════════════════════════════════
// LE CHROME DE S, EN SCENE A PART — barre, barre laterale, bulle.
//
// POURQUOI UNE SCENE A PART. Les trois pieces du chrome deviennent des
// surfaces de couche (zwlr_layer_shell_v1, voir les declarations
// LayerShell.Window dans chaque QML) : le compositeur les ancre lui-meme aux
// bords, plus de regle kwin, plus de rattrapage d'ecran. Mais l'integration
// layer-shell s'applique a TOUTES les fenetres d'un processus — et le bureau
// doit rester une fenetre ordinaire. Le chrome vit donc dans son propre
// processus (s-chrome), et cette scene est son point d'entree.
//
// CE QUI A CHANGE PAR RAPPORT A CONSTELLATION.QML : rien dans les trois QML
// eux-memes. Le cablage qui vivait dans la scene du bureau (les signaux
// onActivation, le flux de la bulle, le reglagesPrets) est reproduit ici,
// sur les ponts lointains — les memes noms, une autre rive. Voir
// /usr/lib/s/pont_lointain.py.
// ═══════════════════════════════════════════════════════════════════════════

Item {
    id: chrome

    // LE BUREAU, DANS LA CHAINE DE PORTEE — pas seulement en propriete de
    // contexte. Les delegues de la barre (epingles, tuiles) lisent « bureau. »
    // sans qualification : en production, ce nom est l'identifiant de la
    // racine de Constellation.qml, et il atteint les delegues PAR la chaine
    // de portee. Une propriete de contexte, elle, ne les atteint pas —
    // mesure 2026-11-14 : « bureau » y resolvait a null. Un alias pose sur la
    // racine remet le nom exactement la ou les delegues le cherchent.
    readonly property var bureau: bureauPont

    Component.onCompleted: {
        Session.bureau = bureau;
        // LE THEME SE CHARGE ICI AUSSI : les trois fenetres du chrome lisent
        // Theme.estWindows/estAndroid pour leur mise en page, et le reglage
        // vit dans le pont (le disque) — le bureau le pose de son cote, le
        // chrome du sien, chacun a son ouverture. Un changement de theme
        // cote bureau arrive par « BureauChange » : la relecture plus bas
        // recharge le theme en meme temps que les donnees.
        var r = pont.reglages();
        if (r) Theme.charger(r);
    }

    Connections {
        target: bureau
        function onDonneesChanged() {
            var r = pont.reglages();
            if (r) Theme.charger(r);
        }
    }

    Barre {
        id: barreTaches
        objectName: "barreTaches"

        veille: (typeof fenetres !== "undefined" && fenetres) ? fenetres.mode : "geler"
        inactives: (typeof fenetres !== "undefined" && fenetres) ? fenetres.inactives : 0
        // « plein » vient du rapporteur de kwin, seul a pouvoir le savoir.
        efface: (typeof fenetres !== "undefined" && fenetres) ? fenetres.plein : false

        onActivation: function (ident, estActive) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.activer(ident, estActive);
        }
        onFermeture: function (ident) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.fermer(ident);
        }
        onForcerFermeture: function (ident) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.forcerFermeture(ident);
        }
        onSommeil: function (ident) {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.endormir(ident);
        }
        onMenageDemande: function (jours) {
            if (typeof fenetres !== "undefined" && fenetres)
                bureau.dire(fenetres.fermerInactives(jours));
        }
        onVeilleChoisie: function (mode) {
            if (typeof fenetres !== "undefined" && fenetres)
                bureau.dire(fenetres.reglerMode(mode));
        }
        onInactivesDemandees: {
            if (typeof fenetres !== "undefined" && fenetres)
                fenetres.inactivesDepuis(barreTaches.joursInactivite);
        }
        onReglagesDemandes: {
            laterale.deploye = !laterale.deploye;
        }
        // LES GESTES QUI OUVRENT LES MENUS DU BUREAU. Le menu Demarrer, la
        // recherche et l'etagere des recents sont dessines dans la fenetre du
        // bureau — un autre processus. Le pont bureau les demande au service
        // /bureau, qui appelle la scene : « menuDemande » remonte le bureau
        // avant d'ouvrir, comme le faisait le cablage d'avant.
        onMenuDemande: bureau.menuDemande()
        onRechercheDemandee: bureau.rechercheDemandee()
        onBureauDemande: bureau.bureauDemande()
        onRetourDemande: bureau.retourDemande()
        onAccueilDemande: bureau.accueilDemande()
        onRecentsDemande: bureau.recentsDemande()
    }

    BarreLaterale {
        id: laterale
        objectName: "laterale"
        efface: (typeof fenetres !== "undefined" && fenetres) ? fenetres.plein : false
        onOuverte: pont.rafraichirReglages()
        onReglageBascule: function (cle, vers) {
            bureau.dire(pont.reglerRapide(cle, vers));
        }
        onReglageValeur: function (cle, valeur) {
            bureau.dire(pont.reglerRapide(cle, valeur));
        }
        onReglageChoix: function (cle, valeur) {
            bureau.dire(pont.reglerRapide(cle, valeur));
        }
        onReglageMuet: function (cle) {
            bureau.dire(pont.reglerRapide(cle + "-muet", true));
        }
        onReglageAction: function (cle) {
            if (cle === "verrouiller") { bureau.dire(pont.session("verrouiller")); return; }
            bureau.dire(pont.reglerRapide(cle, true));
        }
        onPersonnaliserDemande: bureau.ouvrirPersonnaliser()
    }

    Bulle {
        id: bulle
        objectName: "bulle"
        onActionChoisie: function (ident, cle) {
            // La bulle ne connait pas le serveur : le choix repart par le
            // pont, qui le remonte sur le bus.
            if (typeof notifications !== "undefined" && notifications)
                notifications.agir(ident, cle);
        }
    }

    Connections {
        target: typeof fenetres !== "undefined" ? fenetres : null
        function onChangees(liste) {
            barreTaches.ouvertures = JSON.parse(liste);
        }
    }

    Connections {
        target: typeof notifications !== "undefined" ? notifications : null
        function onMontrer(id, app, titre, corps, duree, urgence, appId, actions) {
            bulle.poser(id, app, titre, corps, duree, urgence, actions);
        }
        function onRetirer(id) {
            bulle.retirer(id);
        }
    }

    Connections {
        target: pont
        function onReglagesPrets(json) {
            laterale.reglages = JSON.parse(json);
        }
        function onReglageFait(dit) {
            bureau.dire(dit);
        }
        function onImageChoisie(chemin) {
            if (chemin !== "")
                bureau.choisirFond("image:" + chemin);
        }
    }
}

