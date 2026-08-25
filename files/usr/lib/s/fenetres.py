#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""La barre des taches de S — ce que Constellation sait des fenetres ouvertes.

CE QUE CE FICHIER RESOUT. Une barre des taches a besoin de deux choses qu'un
client Wayland n'a pas le droit d'avoir : la liste des fenetres des autres, et
le pouvoir d'en activer une. Releve sur la machine le 2026-08-25, dans les
soixante-dix protocoles annonces par kwin :

    org_kde_plasma_window_management   ABSENT
    zwlr_foreign_toplevel_manager_v1   ABSENT

Les deux qui auraient servi ne sont pas la, et c'est une decision de securite
juste : une application qui enumere les fenetres des autres peut les espionner.

L'INTERFACE QUE KWIN OUVRE VOLONTAIREMENT, ELLE, EST SON MOTEUR DE SCRIPTS. Un
script kwin tourne DANS le compositeur — il sait tout — et « callDBus » lui
permet de le dire au dehors. C'est la porte prevue, pas une porte forcee.

DANS LES DEUX SENS, ET PAR DEUX CHEMINS DIFFERENTS :

  kwin -> S   un script resident (fenetres.js) appelle cet objet a chaque
              fenetre ouverte, fermee, activee, renommee ou reduite.

  S -> kwin   pour activer une fenetre, on ecrit un script d'une ligne qui
              porte l'identifiant, on le charge, on le lance, on le decharge.
              Un script kwin ne peut rien RECEVOIR — pas de service, pas de
              file d'attente, pas meme un fichier a relire. Le seul canal
              entrant est le chargement lui-meme, donc c'est celui qu'on prend.
              Mesure : l'aller-retour complet coute quelques dizaines de
              millisecondes, ce qui est sous le seuil du clic percu.
"""

import json
import os

from PySide6.QtCore import QObject, Signal, Slot

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop


NOM = "org.s.Constellation"
CHEMIN = "/fenetres"

KWIN = ("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting")

# « loadScript » EXISTE EN DEUX VERSIONS SUR LE BUS — loadScript(s) et
# loadScript(ss) — et dbus-python choisit la premiere qu'il trouve dans
# l'introspection, puis se plaint que Python lui donne deux arguments. On lui
# impose donc la signature. Sans cela, la barre s'ouvre vide et le journal
# parle de « Fewer items found in D-Bus signature », ce qui ne ressemble en
# rien au probleme reel.
RESIDENT = "/usr/lib/s/fenetres.js"


class Fenetres(QObject):
    """La liste, telle que QML la lit."""

    changees = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._liste = []
        self._bus = None
        self._compteur = 0

    # ---- Ce que la scene demande -----------------------------------------
    @Slot(result="QVariant")
    def liste(self):
        return self._liste

    @Slot(str)
    def activer(self, ident):
        """Met la fenetre au premier plan, ou la reduit si elle y est deja.

        C'est le comportement d'une barre des taches, et il n'est pas
        decoratif : sans le repli, cliquer sur la fenetre courante ne ferait
        rien du tout et l'utilisateur croirait le clic perdu.
        """
        if not ident or self._bus is None:
            return
        script = os.path.join(
            os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "s-activer.js")
        # L'IDENTIFIANT EST INTERPOLE DANS DU JAVASCRIPT : il vient de kwin
        # lui-meme, jamais de l'exterieur, mais on le reduit malgre tout aux
        # caracteres d'un UUID. Une chaine qui traverse un langage doit etre
        # bornee la ou elle entre, pas la ou on espere qu'elle est sure.
        propre = "".join(c for c in str(ident) if c in
                         "0123456789abcdefABCDEF-{}")
        with open(script, "w", encoding="utf-8") as sortie:
            sortie.write(
                'var l = workspace.windowList();\n'
                'for (var i = 0; i < l.length; i++) {\n'
                '    if (String(l[i].internalId) === "%s") {\n'
                '        if (workspace.activeWindow === l[i] && !l[i].minimized) {\n'
                '            l[i].minimized = true;\n'
                '        } else {\n'
                '            l[i].minimized = false;\n'
                '            workspace.activeWindow = l[i];\n'
                '        }\n'
                '        break;\n'
                '    }\n'
                '}\n' % propre)
        self._compteur += 1
        nom = "s-activer-%d" % self._compteur
        try:
            objet = self._bus.get_object(*KWIN[:2])
            face = dbus.Interface(objet, KWIN[2])
            face.loadScript(script, nom, signature="ss")
            face.start()
            face.unloadScript(nom)
        except dbus.DBusException:
            # kwin peut etre en train de se reconfigurer. Une fenetre non
            # activee n'est pas une panne ; un bureau qui tombe pour ca en
            # serait une.
            pass

    @Slot()
    def activerBureau(self):
        """Ramene Constellation devant.

        Le menu Demarrer est dessine dans la fenetre du bureau, qui reste
        DERRIERE les autres — c'est ce qu'on attend d'un bureau. Ouvrir le menu
        depuis la barre sans remonter le bureau afficherait donc un menu
        invisible, et le bouton aurait l'air casse.
        """
        if self._bus is None:
            return
        script = os.path.join(
            os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "s-bureau.js")
        with open(script, "w", encoding="utf-8") as sortie:
            sortie.write(
                'var l = workspace.windowList();\n'
                'for (var i = 0; i < l.length; i++) {\n'
                '    if (String(l[i].resourceClass) === "s-constellation" &&\n'
                '        l[i].fullScreen) {\n'
                '        l[i].minimized = false;\n'
                '        workspace.activeWindow = l[i];\n'
                '        break;\n'
                '    }\n'
                '}\n')
        self._compteur += 1
        nom = "s-bureau-%d" % self._compteur
        try:
            objet = self._bus.get_object(*KWIN[:2])
            face = dbus.Interface(objet, KWIN[2])
            face.loadScript(script, nom, signature="ss")
            face.start()
            face.unloadScript(nom)
        except dbus.DBusException:
            pass

    # ---- Ce que kwin raconte ---------------------------------------------
    def recevoir(self, texte):
        try:
            self._liste = json.loads(texte)
        except (ValueError, TypeError):
            return
        self.changees.emit(texte)


class Service(dbus.service.Object):
    def __init__(self, fenetres, nom_bus):
        super().__init__(nom_bus, CHEMIN)
        self._fenetres = fenetres

    @dbus.service.method(NOM, in_signature="s", out_signature="")
    def Fenetres(self, liste_json):
        self._fenetres.recevoir(liste_json)


def publier(parent=None, script=RESIDENT):
    """Prend le nom, charge le rapporteur dans kwin, et rend l'objet.

    Rend (fenetres, None) ou (None, phrase). Comme pour les notifications, un
    echec ici ne doit pas empecher le bureau de s'ouvrir : une barre sans
    fenetres reste une barre, et les etoiles marchent toujours.
    """
    DBusGMainLoop(set_as_default=True)
    try:
        bus = dbus.SessionBus()
    except dbus.DBusException as err:
        return None, "pas de bus de session (%s)" % err

    try:
        nom_bus = dbus.service.BusName(NOM, bus, do_not_queue=True)
    except dbus.exceptions.NameExistsException:
        return None, "%s est deja possede par un autre programme" % NOM
    except dbus.DBusException as err:
        return None, "le nom %s n'a pas pu etre pris (%s)" % (NOM, err)

    fenetres = Fenetres(parent)
    fenetres._bus = bus
    fenetres._service = Service(fenetres, nom_bus)
    fenetres._nom_bus = nom_bus

    if not os.path.isfile(script):
        return fenetres, "le rapporteur %s est absent — barre sans fenetres" % script

    # LE RAPPORTEUR SE DECHARGE AVANT DE SE CHARGER. Une session rouverte sans
    # que kwin ait redemarre garderait sinon deux exemplaires branches sur les
    # memes signaux, et chaque fenetre ouverte serait annoncee deux fois.
    try:
        objet = bus.get_object(*KWIN[:2])
        face = dbus.Interface(objet, KWIN[2])
        try:
            face.unloadScript("s-fenetres")
        except dbus.DBusException:
            pass
        face.loadScript(script, "s-fenetres", signature="ss")
        face.start()
    except dbus.DBusException as err:
        return fenetres, "kwin n'a pas charge le rapporteur (%s)" % err

    return fenetres, None
