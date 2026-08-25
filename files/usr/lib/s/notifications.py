#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Le service de notifications de S — publie par la coquille elle-meme.

POURQUOI CE FICHIER EXISTE. Jusqu'au 2026-08-25, personne ne possedait le nom
« org.freedesktop.Notifications » dans une session de S. Le seul fournisseur
declare par l'image est org.kde.plasma.Notifications.service, dont l'Exec est
« plasma_waitforname org.freedesktop.Notifications » : il ATTEND que quelqu'un
publie ce nom. Le seul qui le publie est plasmashell, qui ne tourne pas ici
puisque la coquille est Constellation. « notify-send » attendait donc pour
toujours — et comme s_dire vit dans s-monde, que chaque couture charge par
source, la premiere phrase de n'importe quel geste gelait ce geste en entier.

Le correctif du matin a detache l'appel et l'a borne a cinq secondes : plus
rien ne gele. Mais les phrases de S partaient dans le vide. Une coquille qui ne
sait pas afficher une notification n'est pas finie ; ce fichier la finit.

CE QU'IL NE FAIT PAS, ET C'EST DELIBERE. Pas d'historique, pas de boutons
d'action, pas de son, pas d'images en ligne. Il declare donc « body » et rien
d'autre dans ses capacites : annoncer « actions » sans dessiner de boutons
ferait afficher aux applications des choix qui n'apparaissent nulle part — le
succes silencieux, transpose a l'interface.

POURQUOI dbus-python ET NON QtDBus, ALORS QUE TOUT LE RESTE DE LA COQUILLE EST
EN Qt. Trois formes ont ete essayees sur la machine, et la mesure a tranche :

  1. QDBusVirtualObject, l'XML d'introspection ecrit a la main. GetServerInfo
     rendait bien « ssss », mais la reponse de Notify sortait avec le mauvais
     type — un objet virtuel ne declare rien a Qt, qui devine d'apres la valeur
     Python, et un entier ne devient jamais un « u ». REJETE.
  2. Les slots exportes (QDBusConnection.ExportAllSlots). Notify, GetCapabilities
     et CloseNotification sont exacts. Mais Qt deduit la signature du type
     declare dans le slot, et un slot Python ne peut pas rendre QUATRE chaines
     separees : GetServerInformation sortait en « as » au lieu de « ssss ».
     REJETE — et c'est le piege de la journee, parce que ca a l'air de marcher :
     un appel direct de Notify repond « u 1 », tout semble bon. Mais libnotify
     interroge GetServerInformation AVANT d'afficher, et « notify-send » repond
     alors « Unexpected reply type » sans jamais rien montrer. Le seul client
     que S utilise partout etait le seul que cette forme cassait.
  3. QDBusContext et une reponse differee pour ce seul appel : ERREUR DE
     SEGMENTATION, reproduite deux fois. REJETE.

dbus-python, lui, prend la signature en argument : « out_signature="ssss" » et
« out_signature="u" » sont ecrits, pas devines.

ET IL N'Y A PAS DEUX BOUCLES POUR AUTANT. Qt utilise QEventDispatcherGlib sous
Linux — mesure a l'execution, pas suppose : il fait donc deja tourner le
contexte principal de GLib, celui-la meme auquel DBusGMainLoop s'attache. Le
service est servi PAR la boucle de Qt, sans fil supplementaire et sans reveil
periodique. Le repli en fil separe ci-dessous ne sert que si Qt etait bati sans
GLib, ou lance avec QT_NO_GLIB — auquel cas le service se tairait en silence,
et se taire en silence est precisement ce que ce projet refuse.
"""

import threading

from PySide6.QtCore import QObject, Signal

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop


NOM = "org.freedesktop.Notifications"
CHEMIN = "/org/freedesktop/Notifications"

# Les raisons de fermeture, telles que la specification les numerote.
EXPIREE = 1
ECARTEE = 2
FERMEE_PAR_APPEL = 3


class Serveur(QObject):
    """Ce que la scene QML ecoute.

    Le service ne dessine rien : il traduit un appel du bus en un signal Qt, et
    la coquille decide de l'apparence. Meme separation que partout ailleurs
    dans S — le noyau lit la machine, le QML la montre.
    """

    # id, application, titre, corps, duree en millisecondes (0 = ne part pas
    # tout seul), urgence 0/1/2
    montrer = Signal(int, str, str, str, int, int)
    retirer = Signal(int)

    DUREE_PAR_DEFAUT = 5000
    # Une notification critique ne part pas toute seule : la specification le
    # demande, et c'est par elle que passe « Constellation n'a pas demarre ».
    DUREE_CRITIQUE = 0

    def __init__(self, parent=None):
        super().__init__(parent)
        self._suivant = 0
        self._vivantes = set()
        self._service = None

    def poser(self, application, remplace, titre, corps, indices, delai):
        ident = self._prochain_id(remplace)

        urgence = 1
        valeur = indices.get("urgency") if hasattr(indices, "get") else None
        if valeur is not None:
            try:
                urgence = int(valeur)
            except (TypeError, ValueError):
                urgence = 1

        try:
            delai = int(delai)
        except (TypeError, ValueError):
            delai = -1
        if delai < 0:
            duree = self.DUREE_CRITIQUE if urgence >= 2 else self.DUREE_PAR_DEFAUT
        else:
            duree = delai

        self._vivantes.add(ident)
        self.montrer.emit(ident, str(application or ""), str(titre or ""),
                          str(corps or ""), duree, urgence)
        return ident

    def fermer(self, ident, raison=ECARTEE):
        """Retire une notification et l'annonce a qui l'avait posee."""
        ident = int(ident)
        if ident not in self._vivantes:
            return False
        self._vivantes.discard(ident)
        self.retirer.emit(ident)
        if self._service is not None:
            self._service.NotificationClosed(ident, int(raison))
        return True

    def _prochain_id(self, remplace):
        if remplace:
            return int(remplace)
        self._suivant += 1
        # La specification interdit l'identifiant 0 : il signifie « aucune ».
        if self._suivant > 0x7FFFFFFF:
            self._suivant = 1
        return self._suivant


class Service(dbus.service.Object):
    """Le contrat, ecrit signature par signature."""

    def __init__(self, serveur, nom_bus, chemin=CHEMIN):
        super().__init__(nom_bus, chemin)
        self._serveur = serveur

    # L'ORDRE DES HUIT ARGUMENTS EST CELUI DE LA SPECIFICATION, et il n'est pas
    # devinable : un « app_icon » oublie decale tout le reste et fait afficher
    # le corps a la place du titre.
    @dbus.service.method(NOM, in_signature="susssasa{sv}i", out_signature="u")
    def Notify(self, app_name, replaces_id, app_icon, summary, body, actions,
               hints, expire_timeout):
        return self._serveur.poser(app_name, replaces_id, summary, body, hints,
                                   expire_timeout)

    @dbus.service.method(NOM, in_signature="u", out_signature="")
    def CloseNotification(self, id):
        self._serveur.fermer(id, FERMEE_PAR_APPEL)

    @dbus.service.method(NOM, in_signature="", out_signature="as")
    def GetCapabilities(self):
        # HONNETE PLUTOT QUE FLATTEUR : S affiche un titre et un corps.
        return ["body"]

    @dbus.service.method(NOM, in_signature="", out_signature="ssss")
    def GetServerInformation(self):
        # Le nom, l'editeur, la version, puis la version de la specification.
        return ("Constellation", "S", "1", "1.2")

    @dbus.service.signal(NOM, signature="uu")
    def NotificationClosed(self, id, reason):
        pass


def _boucle_de_secours():
    """Fait tourner GLib a part, si la boucle de Qt ne le fait pas.

    Cas rare — Qt bati sans GLib, ou QT_NO_GLIB=1 — mais il faut le couvrir :
    sans personne pour iterer le contexte, le service repondrait a personne et
    ne le dirait pas.
    """
    from gi.repository import GLib
    GLib.MainLoop().run()


def publier(application=None, parent=None):
    """Prend le nom sur le bus de session, et rend le serveur.

    Rend (serveur, None) si tout va bien, (None, phrase) sinon. La coquille
    doit pouvoir demarrer meme si le nom est deja pris : un bureau sans bulles
    reste un bureau, alors qu'un bureau qui refuse de s'ouvrir n'est rien.
    """
    DBusGMainLoop(set_as_default=True)

    try:
        bus = dbus.SessionBus()
    except dbus.DBusException as err:
        return None, "pas de bus de session (%s)" % err

    try:
        # do_not_queue : on ne se met pas en file d'attente derriere un autre
        # demon. Soit le nom est libre, soit on continue sans bulles.
        nom_bus = dbus.service.BusName(NOM, bus, do_not_queue=True)
    except dbus.exceptions.NameExistsException:
        return None, "%s est deja possede par un autre programme" % NOM
    except dbus.DBusException as err:
        return None, "le nom %s n'a pas pu etre pris (%s)" % (NOM, err)

    serveur = Serveur(parent)
    serveur._service = Service(serveur, nom_bus)
    # Le nom de bus est garde par le serveur : sans reference, Python le ramasse
    # et le nom est rendu au bus a la premiere passe du eboueur.
    serveur._nom_bus = nom_bus

    dispatcher = None
    if application is not None and application.eventDispatcher() is not None:
        dispatcher = application.eventDispatcher().metaObject().className()
    if dispatcher is not None and "Glib" not in dispatcher:
        fil = threading.Thread(target=_boucle_de_secours, daemon=True)
        fil.start()
        serveur._fil = fil

    return serveur, None
