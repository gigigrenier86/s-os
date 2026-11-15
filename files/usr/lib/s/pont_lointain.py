#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Les ponts du chrome lointain — ce que s-chrome utilise hors du bureau.

POURQUOI CE FICHIER EXISTE. Le chrome (barre, barre laterale, bulle) quitte le
processus du bureau pour devenir des surfaces de couche (zwlr_layer_shell_v1,
voir les declarations LayerShell.Window dans les trois QML). L'integration
layer-shell s'applique a TOUTES les fenetres d'un processus — mesure dans
qwaylandlayersurface.cpp, une surface de couche est creee pour chaque fenetre —
et le bureau, lui, doit rester une fenetre ordinaire. Deux processus, donc, et
ce qui etait un appel de QObject en memoire devient un appel sur le bus :

  - FenetresLointain : la liste des fenetres et le droit d'en activer une.
    Le rapporteur kwin envoie deja la liste a org.s.Constellation (/fenetres) ;
    le pont la republie ici en signaux Qt, sous les memes noms que l'ancien
    objet en memoire — les QML du chrome n'ont pas change pour lui.
  - BureauLointain : l'etat du bureau (etoiles, epingles, badges). Il vit
    DANS noyau, sur disque : chaque processus lit les memes fichiers, et un
    appel « Relire » sur /bureau previent l'autre processus d'un changement.
  - NotificationLointaine : la bulle recoit ses notifications par des signaux
    D-Bus que le serveur (notifications.py) publie — il ne les publiait pas
    avant, puisqu'il n'y avait qu'un processus. « agir » repart par D-Bus.
"""

import json

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

import dbus
import dbus.mainloop.glib

FENETRES_BUS = ("org.s.Constellation", "/fenetres", "org.s.Constellation")
BUREAU_BUS = ("org.s.Constellation", "/bureau", "org.s.Constellation.Bureau")
NOTIF_BUS = ("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
             "org.freedesktop.Notifications")


def _bus():
    try:
        return dbus.SessionBus()
    except dbus.DBusException:
        return None


class FenetresLointain(QObject):
    """Le pont fenetres, vu du chrome : memes noms que l'objet en memoire."""

    changees = Signal(str)
    modeChange = Signal(str)
    vuesChangees = Signal()
    inactivesChange = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._service = None
        self._vues = []
        self._mode = "geler"
        self._inactives = 0
        self._branche = False
        self._essai = QTimer(self)
        self._essai.setInterval(2000)
        self._essai.timeout.connect(self._brancher)
        self._essai.start()

    # ---- La connexion, tentee jusqu'a ce que le bureau la reponde ----------
    def _brancher(self):
        if self._branche:
            return
        bus = _bus()
        if bus is None:
            return
        try:
            self._service = dbus.Interface(
                bus.get_object(*FENETRES_BUS[:2]), FENETRES_BUS[2])
            bus.add_signal_receiver(self._sur_vues, "Vues", FENETRES_BUS[2],
                                    FENETRES_BUS[0], FENETRES_BUS[1])
            bus.add_signal_receiver(self._sur_mode, "ModeChange", FENETRES_BUS[2],
                                    FENETRES_BUS[0], FENETRES_BUS[1])
            self._sur_vues(self._service.Liste())
            self._sur_mode(self._service.Mode())
            self._branche = True
            self._essai.stop()
        except dbus.DBusException:
            pass

    def _sur_vues(self, liste_json):
        try:
            vues = json.loads(liste_json)
        except (ValueError, TypeError):
            return
        if not isinstance(vues, list):
            return
        self._vues = vues
        self.changees.emit(json.dumps(vues))
        self.vuesChangees.emit()

    def _sur_mode(self, mode):
        self._mode = str(mode)
        self.modeChange.emit(self._mode)

    # ---- Ce que la scene lit ----------------------------------------------
    @Property(str, notify=modeChange)
    def mode(self):
        return self._mode

    @Property(int, notify=inactivesChange)
    def inactives(self):
        return self._inactives

    @Property(bool, notify=vuesChangees)
    def plein(self):
        # Un vrai plein ecran actif efface le chrome — meme calcul que celui
        # que Constellation faisait dans sa scene.
        for f in self._vues:
            if (f.get("plein") is True and f.get("reduite") is not True
                    and f.get("active") is True):
                return True
        return False

    @Slot(result="QVariant")
    def liste(self):
        return [dict(f) for f in self._vues]

    # ---- Ce que la scene demande ------------------------------------------
    @Slot(str, result=str)
    def reglerMode(self, valeur):
        if self._service is None:
            return "pas de pont fenetres"
        try:
            return str(self._service.ReglerMode(valeur))
        except dbus.DBusException as err:
            return str(err)

    @Slot(str, bool)
    def activer(self, ident, deja_active=False):
        if self._service is None:
            return
        try:
            self._service.Activer(ident, deja_active)
        except dbus.DBusException:
            pass

    @Slot(str)
    def fermer(self, ident):
        if self._service is None:
            return
        try:
            self._service.Fermer(ident)
        except dbus.DBusException:
            pass

    @Slot(str)
    def forcerFermeture(self, ident):
        if self._service is None:
            return
        try:
            self._service.ForcerFermeture(ident)
        except dbus.DBusException:
            pass

    @Slot(str)
    def endormir(self, ident):
        if self._service is None:
            return
        try:
            self._service.Endormir(ident)
        except dbus.DBusException:
            pass

    @Slot(int)
    def inactivesDepuis(self, jours):
        if self._service is None:
            return
        try:
            self._inactives = int(self._service.InactivesDepuis(jours))
            self.inactivesChange.emit()
        except dbus.DBusException:
            pass

    @Slot(int, result=str)
    def fermerInactives(self, jours):
        if self._service is None:
            return "pas de pont fenetres"
        try:
            return str(self._service.FermerInactives(jours))
        except dbus.DBusException as err:
            return str(err)

    @Slot()
    def activerBureau(self):
        if self._service is None:
            return
        try:
            self._service.ActiverBureau()
        except dbus.DBusException:
            pass

class BureauLointain(QObject):
    """Le bureau, vu du chrome : les memes fonctions que la racine QML.

    L'etat vient de noyau (le disque), pas du processus du bureau : chaque
    cote lit les memes fichiers. « relire » previent le bureau qu'un fichier
    a change, et « BureauChange » en retour fait relire le chrome — sans
    jamais boucler, puisque le pont ne republie que quand l'empreinte change.
    """

    donneesChanged = Signal()

    def __init__(self, pont, parent=None):
        super().__init__(parent)
        self._pont = pont
        self._relire_bus = None
        self._relire_bus_cherche = False
        self._donnees = self._lire()

    def _lire(self):
        vide = {"etoiles": [], "usage": {}, "placees": {},
                "epingles": [], "fichiers": []}
        if self._pont is None:
            return vide
        try:
            lu = self._pont.etoiles()
        except Exception:
            lu = None
        return lu if isinstance(lu, dict) else vide

    @Property("QVariant", notify=donneesChanged)
    def donnees(self):
        return self._donnees

    def _service_bureau(self):
        if not self._relire_bus_cherche:
            self._relire_bus_cherche = True
            bus = _bus()
            if bus is not None:
                try:
                    self._relire_bus = dbus.Interface(
                        bus.get_object(*BUREAU_BUS[:2]), BUREAU_BUS[2])
                except dbus.DBusException:
                    self._relire_bus = None
        return self._relire_bus

    def brancher(self):
        """Ecoute « BureauChange » : le bureau a change les fichiers d'etat."""
        bus = _bus()
        if bus is None:
            return
        try:
            bus.add_signal_receiver(self._sur_bureau_change, "BureauChange",
                                    BUREAU_BUS[2], BUREAU_BUS[0], BUREAU_BUS[1])
        except dbus.DBusException:
            pass

    def _sur_bureau_change(self, etoiles_json):
        self._relire(poker=False)

    @Slot()
    def relire(self):
        self._relire(poker=True)

    def _relire(self, poker):
        self._donnees = self._lire()
        self.donneesChanged.emit()
        if poker:
            service = self._service_bureau()
            if service is not None:
                try:
                    service.Relire()
                except dbus.DBusException:
                    pass

    # ---- Les fonctions de la racine QML, portees mot pour mot --------------
    @Slot(str, result="QVariant")
    def appParId(self, ident):
        for e in self._donnees.get("etoiles", []):
            if e.get("id") == ident:
                return e
        for f in self._donnees.get("fichiers", []):
            if f.get("id") == ident:
                return f
        return None

    @Slot(str, result="QVariant")
    def appParClasse(self, classe):
        for e in self._donnees.get("etoiles", []):
            if e.get("classe", e.get("src", "")) == classe:
                return e
        for f in self._donnees.get("fichiers", []):
            if f.get("classe", "") == classe:
                return f
        return None

    @Slot(str, str, result="QVariant")
    def appParNotification(self, app_id, nom_notif):
        # Meme regle que la racine QML : le nom Windows ou Linux ambigu ne
        # pose rien — voir le commentaire du flux de la bulle.
        for e in self._donnees.get("etoiles", []):
            if e.get("classe", e.get("src", "")) == app_id:
                return e
        for e in self._donnees.get("etoiles", []):
            if e.get("nom") == nom_notif:
                return e
        return None

    @Slot(str, result=bool)
    def estUnFichier(self, ident):
        return str(ident).startswith("fichier:")

    @Slot(result="QVariant")
    def placeLibre(self):
        # La meme grille que la racine QML : 8 lignes x 9 colonnes, un pas de
        # 0,11, et la premiere case qui n'est pas deja prise.
        prises = []
        for ident in self._donnees.get("placees", {}):
            prises.append(self._donnees["placees"][ident])
        pas = 0.11
        for ligne in range(8):
            for col in range(9):
                x = 0.08 + col * pas
                y = 0.10 + ligne * pas
                libre = True
                for p in prises:
                    if (abs(p.get("x", 0) - x) < pas * 0.8 and
                            abs(p.get("y", 0) - y) < pas * 0.8):
                        libre = False
                        break
                if libre:
                    return {"x": x, "y": y}
        return {"x": 0.5, "y": 0.5}

    @Slot(str)
    def dire(self, texte):
        # Le « mot fugace » vit dans le ciel du bureau ; le chrome le dit par
        # la bulle — le meme canal que s_dire.
        bus = _bus()
        if bus is None:
            return
        try:
            serveur = dbus.Interface(bus.get_object(*NOTIF_BUS[:2]), NOTIF_BUS[2])
            serveur.Notify("S", 0, "", "S", str(texte), [], {}, 4000)
        except dbus.DBusException:
            pass

    # ---- Les gestes qui ouvrent les menus DU BUREAU ------------------------
    # Le menu Demarrer, la recherche, l'etagere des recents et le panneau
    # Personnaliser sont dessines dans la fenetre du bureau — un autre
    # processus. Le chrome demande ici, le service /bureau passe au
    # PasseBureau (s-constellation), qui appelle la scene.
    def _geste(self, methode, *args):
        service = self._service_bureau()
        if service is None:
            return
        try:
            getattr(service, methode)(*args)
        except dbus.DBusException:
            pass

    @Slot()
    def menuDemande(self):
        self._geste("Menu")

    @Slot()
    def rechercheDemandee(self):
        self._geste("Rechercher")

    @Slot()
    def bureauDemande(self):
        self._geste("Bureau")

    @Slot()
    def retourDemande(self):
        self._geste("Retour")

    @Slot()
    def accueilDemande(self):
        self._geste("Accueil")

    @Slot()
    def recentsDemande(self):
        self._geste("Recents")

    @Slot()
    def ouvrirPersonnaliser(self):
        self._geste("Personnaliser")

    @Slot(str)
    def choisirFond(self, chemin):
        self._geste("ChoisirFond", str(chemin))

class NotificationLointaine(QObject):
    """La bulle, nourrie par les signaux D-Bus du serveur de notifications."""

    montrer = Signal(int, str, str, str, int, int, str, list)
    retirer = Signal(int)

    def __init__(self, bureau, pont, parent=None):
        super().__init__(parent)
        self._bureau = bureau
        self._pont = pont
        self._bus = None
        self._essai = QTimer(self)
        self._essai.setInterval(2000)
        self._essai.timeout.connect(self._brancher)
        self._essai.start()

    def _brancher(self):
        if self._bus is not None:
            return
        bus = _bus()
        if bus is None:
            return
        try:
            bus.add_signal_receiver(self._sur_montrer, "SNotification",
                                    NOTIF_BUS[2], NOTIF_BUS[0], NOTIF_BUS[1])
            bus.add_signal_receiver(self._sur_retirer, "NotificationClosed",
                                    NOTIF_BUS[2], NOTIF_BUS[0], NOTIF_BUS[1])
            self._bus = bus
            self._essai.stop()
        except dbus.DBusException:
            pass

    def _sur_montrer(self, ident, app, titre, corps, actions_json, duree,
                     urgence):
        try:
            actions = json.loads(actions_json)
        except (ValueError, TypeError):
            actions = []
        if not isinstance(actions, list):
            actions = []
        self.montrer.emit(int(ident), str(app), str(titre), str(corps),
                          int(duree), int(urgence), str(app), actions)
        # LE BADGE, le meme flux que la racine QML : une notification qui ne
        # se rattache a aucune etoile ne pose rien.
        if self._bureau is not None and self._pont is not None:
            cible = self._bureau.appParNotification(app, app)
            if cible is not None:
                try:
                    self._pont.incrementerBadge(cible.get("id"))
                except Exception:
                    pass
                self._bureau.relire()

    def _sur_retirer(self, ident, raison):
        self.retirer.emit(int(ident))

    @Slot(int, str)
    def agir(self, ident, cle):
        bus = self._bus if self._bus is not None else _bus()
        if bus is None:
            return
        try:
            service = dbus.Interface(bus.get_object(*NOTIF_BUS[:2]), NOTIF_BUS[2])
            service.SInvokeAction(int(ident), str(cle))
        except dbus.DBusException:
            pass



