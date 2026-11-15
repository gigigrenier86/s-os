#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Charger la scene du chrome pendant la construction, et echouer si elle ne
tient pas debout.

POURQUOI CE CONTROLE EXISTE. Le chrome (barre, barre laterale, bulle) quitte
la scene du bureau pour son propre processus (s-chrome), ou il devient des
surfaces de couche. Une faute dans cette scene ne se verrait qu'au premier
clic sur la barre, chez l'utilisateur. On charge donc Chrome.qml ICI, sans
ecran et sans bus, avec des ponts leurres — les memes noms que les ponts
lointains — et on joue les trois gestes qui ne doivent pas casser : une
nouvelle de kwin (la liste des fenetres), une notification (la bulle), et le
changement de reglages (la barre laterale).

LE MODULE LAYER-SHELL EST LA CONDITION DU TOUT : les declarations
LayerShell.Window doivent se charger meme hors Wayland (verifie sur la
machine, elles rendent alors « not a wayland window » sans casser la scene).
"""

import json
import os
import subprocess
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
# L'IMPORT DE QQuickItem EST NECESSAIRE : sans lui, shiboken ne sait pas
# convertir le QQuickItem* du signal itemAdded du Repeater, et le comptage
# des tuiles echoue (meme piege que verifier-tuiles.py, qui le documente).
from PySide6.QtQuick import QQuickItem  # noqa: F401
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

QML = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/s/constellation/qml"
print("  chrome verifie : " + QML)


class LeurreFenetres(QObject):
    """Meme forme que pont-lointain.FenetresLointain, sans bus."""

    changees = Signal(str)
    modeChange = Signal(str)
    vuesChangees = Signal()
    inactivesChange = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._vues = []
        self._mode = "geler"
        self._inactives = 0

    @Slot(str)
    def publier(self, liste_json):
        self._vues = json.loads(liste_json)
        self.changees.emit(liste_json)
        self.vuesChangees.emit()

    # Les proprietes que la scene lit — de vraies proprietes QML, pas des
    # methodes : « fenetres.mode » doit rendre une valeur.
    @Property(str, notify=modeChange)
    def mode(self):
        return self._mode

    @Property(int, notify=inactivesChange)
    def inactives(self):
        return self._inactives

    @Property(bool, notify=vuesChangees)
    def plein(self):
        for f in self._vues:
            if (f.get("plein") is True and f.get("reduite") is not True
                    and f.get("active") is True):
                return True
        return False

    @Slot(result="QVariant")
    def liste(self):
        return [dict(f) for f in self._vues]

    @Slot(str, result=str)
    def reglerMode(self, valeur):
        self._mode = valeur
        self.modeChange.emit(valeur)
        return "geler"

    @Slot(str, bool)
    def activer(self, ident, deja_active=False):
        pass

    @Slot(str)
    def fermer(self, ident):
        pass

    @Slot(str)
    def forcerFermeture(self, ident):
        pass

    @Slot(str)
    def endormir(self, ident):
        pass

    @Slot(int)
    def inactivesDepuis(self, jours):
        self._inactives = 2
        self.inactivesChange.emit()

    @Slot(int, result=str)
    def fermerInactives(self, jours):
        return "deux fenetres oubliees fermees"

    @Slot()
    def activerBureau(self):
        pass

class LeurreBureau(QObject):
    """Meme forme que pont-lointain.BureauLointain, avec un etat de carton."""

    donneesChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        # TROIS EPINGLEES, comme le leurre du verificateur de la scene du
        # bureau : c'est ce que les groupes de la barre (Windows/Android)
        # attendent — trois applications distinctes, aucune fenetre ouverte.
        self._donnees = {
            "etoiles": [{"id": "a", "nom": "Alpha", "classe": "a", "src": "linux"},
                        {"id": "b", "nom": "Beta", "classe": "b", "src": "linux"},
                        {"id": "c", "nom": "Gamma", "classe": "c", "src": "linux"},
                        {"id": "f", "nom": "Un fichier", "classe": "fichier"}],
            "usage": {}, "placees": {}, "epingles": ["a", "b", "c"],
            "fichiers": []}

    @Property("QVariant", notify=donneesChanged)
    def donnees(self):
        return self._donnees

    @Slot(str, result="QVariant")
    def appParId(self, ident):
        for e in self._donnees["etoiles"]:
            if e.get("id") == ident:
                return e
        return None

    @Slot(str, result="QVariant")
    def appParClasse(self, classe):
        for e in self._donnees["etoiles"]:
            if e.get("classe", e.get("src", "")) == classe:
                return e
        return None

    @Slot(str, str, result="QVariant")
    def appParNotification(self, app_id, nom_notif):
        return self.appParClasse(app_id)

    @Slot(str, result=bool)
    def estUnFichier(self, ident):
        return str(ident).startswith("fichier:")

    @Slot(result="QVariant")
    def placeLibre(self):
        return {"x": 0.08, "y": 0.10}

    @Slot(str)
    def dire(self, texte):
        pass

    @Slot()
    def ouvrirPersonnaliser(self):
        pass

    @Slot(str)
    def choisirFond(self, chemin):
        pass


class LeurrePont(QObject):
    """Le Pont du bureau, en carton : ce que la scene du chrome appelle."""

    reglagesPrets = Signal(str)
    reglageFait = Signal(str)
    imageChoisie = Signal(str)

    @Slot(result="QVariant")
    def etoiles(self):
        return {"etoiles": [], "usage": {}, "placees": {}, "epingles": [],
                "fichiers": []}

    @Slot(result="QVariant")
    def dossiers(self):
        return []

    @Slot(result="QVariant")
    def reglages(self):
        # Le chrome charge le theme au demarrage (Chrome.qml) : le leurre
        # rend le theme demande par l'environnement, comme la vraie reglages.
        return {"theme": os.environ.get("S_VERIF_THEME", "constellation")}

    @Slot(str, result=str)
    def lancer(self, ident):
        return ""

    @Slot(str, result=str)
    def lancerEnRoot(self, ident):
        return ""

    @Slot(str, bool)
    def epingler(self, ident, oui):
        pass

    @Slot(str, float, float)
    def placer(self, ident, x, y):
        pass

    @Slot(str, str)
    def deposer(self, ident, chemin):
        pass

    @Slot(str)
    def effacerBadge(self, ident):
        pass

    @Slot(str)
    def incrementerBadge(self, ident):
        pass

    @Slot(str)
    def retirerDuBureau(self, ident):
        pass

    @Slot()
    def rafraichirReglages(self):
        self.reglagesPrets.emit(json.dumps([{"cle": "volume", "valeur": 40}]))

    @Slot(str, object, result=str)
    def reglerRapide(self, cle, valeur):
        return "reglage applique"

    @Slot(str, result=str)
    def session(self, action):
        return "session"

    @Slot(QObject, int)
    def bornerBarre(self, fenetre, sensible):
        pass

    @Slot(QObject, bool)
    def bornerLaterale(self, fenetre, deploye):
        pass


class LeurreNotifications(QObject):
    montrer = Signal(int, str, str, str, int, int, str, list)
    retirer = Signal(int)

    @Slot(int, str)
    def agir(self, ident, cle):
        pass

def main():
    # SANS THEME DONNE, UN PASSAGE PAR THEME, chacun dans son propre
    # processus — meme patron que verifier-constellation.py : un moteur QML
    # neuf par theme, comme a l'ouverture d'une session. Les gestes complets
    # (tuiles, menu, bulle) se jouent sur le theme Constellation ; Windows et
    # Android verifient leurs pieces propres (les groupes de la barre).
    if not os.environ.get("S_VERIF_THEME"):
        codes = []
        for theme in ("constellation", "windows", "android"):
            print("  --- theme %s" % theme)
            sys.stdout.flush()
            env = dict(os.environ, S_VERIF_THEME=theme)
            codes.append(subprocess.run(
                [sys.executable, os.path.abspath(__file__), QML],
                env=env).returncode)
        return 0 if all(c == 0 for c in codes) else 1
    return verifier_un_theme()


def verifier_un_theme():
    theme_ici = os.environ.get("S_VERIF_THEME", "constellation")
    app = QGuiApplication(sys.argv)
    fenetres = LeurreFenetres()
    bureau = LeurreBureau()
    pont = LeurrePont()
    notifications = LeurreNotifications()

    moteur = QQmlApplicationEngine()
    moteur.rootContext().setContextProperty("pont", pont)
    # Le chrome pose lui-meme l'alias « bureau » (Chrome.qml) : la propriete
    # de contexte s'appelle « bureauPont », comme dans s-chrome.
    moteur.rootContext().setContextProperty("bureauPont", bureau)
    moteur.rootContext().setContextProperty("fenetres", fenetres)
    moteur.rootContext().setContextProperty("notifications", notifications)
    moteur.load(QUrl.fromLocalFile(os.path.join(QML, "Chrome.qml")))

    racines = moteur.rootObjects()
    if not racines:
        print("ECHEC : la scene du chrome n'a pas charge.", file=sys.stderr)
        return 1
    racine = racines[0]
    # LES TROIS FENETRES SONT DES ENFANTS DE LA RACINE, pas des racines :
    # meme patron que verifier-constellation.py (findChildren).
    from PySide6.QtGui import QWindow
    fenetres_ouvertes = racines[0].findChildren(QWindow)

    barres = [r for r in fenetres_ouvertes if r.title() == "S - barre"]
    if len(barres) != 1:
        print("ECHEC : la barre des taches n'a pas d'instance.", file=sys.stderr)
        return 1
    barre = barres[0]

    # LES PIECES PROPRES AUX THEMES WINDOWS ET ANDROID : les groupes de la
    # barre (trois epinglees du leurre, aucune fenetre ouverte). Les gestes
    # complets ne se jouent que sur Constellation — la bulle y porte son
    # titre de base, et le menu du clic droit ses onze articles.
    if theme_ici != "constellation":
        groupes = next((o for o in racine.findChildren(QObject)
                        if o.objectName() == "groupesBarre"), None)
        if groupes is None:
            print("ECHEC : les groupes de la barre (objectName "
                  "« groupesBarre ») sont introuvables (theme %s)." % theme_ici,
                  file=sys.stderr)
            return 1
        compte_g = int(groupes.property("count") or 0)
        if compte_g != 3:
            print("ECHEC : groupesBarre porte %d element(s), 3 attendus "
                  "(theme %s)." % (compte_g, theme_ici), file=sys.stderr)
            return 1
        print("  chrome (%s) : groupesBarre %d elements"
              % (theme_ici, compte_g))
        return 0

    # ── Le geste 1 : une nouvelle de kwin remplit les tuiles ────────────────
    fenetres.publier(json.dumps([
        {"id": "1", "titre": "Vivaldi", "classe": "vivaldi-stable",
         "montrable": True, "active": True, "reduite": False, "plein": False},
        {"id": "2", "titre": "Code", "classe": "code",
         "montrable": True, "active": False, "reduite": False, "plein": False},
    ]))
    from PySide6.QtQml import QJSValue
    ouvertures = barre.property("ouvertures")
    if isinstance(ouvertures, QJSValue):
        ouvertures = ouvertures.toVariant()
    if not isinstance(ouvertures, list) or len(ouvertures) != 2:
        print("ECHEC : la nouvelle de kwin n'a pas rempli les tuiles.",
              file=sys.stderr)
        return 1

    # ── Le geste 2 : une notification montre la bulle ───────────────────────
    bulles = [r for r in fenetres_ouvertes
              if r.title() == "S - notification"]
    if len(bulles) != 1:
        print("ECHEC : la bulle n'a pas d'instance.", file=sys.stderr)
        return 1
    bulle = bulles[0]
    notifications.montrer.emit(7, "S", "essai", "un corps", 5000, 1, "S", [])
    app.processEvents()
    # La preuve que la notification est arrivee : la carte courante porte
    # l'identifiant 7. « visible » est le rendu, et il appartient au
    # compositeur — le verifier ici serait mesurer Qt, pas la scene.
    courante = bulle.property("courante")
    if isinstance(courante, QJSValue):
        courante = courante.toVariant()
    if not isinstance(courante, dict) or courante.get("id") != 7:
        print("ECHEC : la notification n'a pas atteint la bulle.",
              file=sys.stderr)
        return 1

    # ── Le geste 3 : les reglages arrivent a la barre laterale ──────────────
    laterales = [r for r in fenetres_ouvertes
                 if r.title() == "S - barre laterale"]
    if len(laterales) != 1:
        print("ECHEC : la barre laterale n'a pas d'instance.", file=sys.stderr)
        return 1
    pont.rafraichirReglages()
    app.processEvents()
    reglages = laterales[0].property("reglages")
    if isinstance(reglages, QJSValue):
        reglages = reglages.toVariant()
    if not isinstance(reglages, list) or len(reglages) != 1:
        print("ECHEC : les reglages ne sont pas arrives a la barre laterale.",
              file=sys.stderr)
        return 1

    # ── Le geste 4 : les tuiles survivent aux nouvelles de kwin ─────────────
    # Meme mesure que verifier-tuiles.py autrefois, sur la scene du bureau :
    # la barre vit ici maintenant, ses tuiles aussi.
    tuiles = next((o for o in racine.findChildren(QObject)
                   if o.objectName() == "tuilesOuvertes"), None)
    if tuiles is None:
        print("ECHEC : le Repeater des tuiles (objectName « tuilesOuvertes ») "
              "est introuvable dans le chrome.", file=sys.stderr)
        return 1
    ajouts = {"n": 0}
    tuiles.itemAdded.connect(
        lambda i, it: ajouts.__setitem__("n", ajouts["n"] + 1))

    def fen_t(ident, titre, active=False, reduite=False):
        return {"id": ident, "classe": "app-" + ident, "titre": titre,
                "active": active, "reduite": reduite, "pid": 0,
                "plein": False, "montrable": True}

    fenetres.publier(json.dumps([fen_t("a", "Alpha", active=True),
                                 fen_t("b", "Beta"), fen_t("c", "Gamma")]))
    if int(tuiles.property("count")) != 3:
        print("ECHEC : trois fenetres devraient donner trois tuiles.",
              file=sys.stderr)
        return 1
    cree = ajouts["n"]
    for k in range(10):
        fenetres.publier(json.dumps([fen_t("a", "Alpha", active=True),
                                     fen_t("b", "Beta page %d" % k),
                                     fen_t("c", "Gamma")]))
    if ajouts["n"] != cree:
        print("ECHEC : 10 changements de titre ont recree des tuiles — le "
              "modele est reinitialise a chaque nouvelle de kwin.",
              file=sys.stderr)
        return 1
    fenetres.publier(json.dumps([fen_t("a", "Alpha"), fen_t("c", "Gamma")]))
    if int(tuiles.property("count")) != 2 or ajouts["n"] != cree:
        print("ECHEC : la fermeture d'une fenetre devait retirer UNE tuile "
              "sans rien recreer.", file=sys.stderr)
        return 1
    fenetres.publier(json.dumps([fen_t("a", "Alpha"), fen_t("c", "Gamma"),
                                 fen_t("d", "Delta", active=True)]))
    if int(tuiles.property("count")) != 3 or ajouts["n"] != cree + 1:
        print("ECHEC : l'ouverture d'une fenetre devait creer exactement "
              "1 tuile.", file=sys.stderr)
        return 1

    # ── Le geste 5 : le menu du clic droit de la barre ──────────────────────
    # Onze articles (avec separateurs), et une hauteur qui ne doit pas etre
    # bornee a 52 px — les deux mesures de verifier-constellation.py,
    # demenagees avec la barre.
    menu_fenetre = next((o for o in racine.findChildren(QObject)
                         if o.objectName() == "menuFenetre"), None)
    if menu_fenetre is None:
        print("ECHEC : le menu du clic droit (objectName « menuFenetre ») est "
              "introuvable dans le chrome.", file=sys.stderr)
        return 1
    menu_fenetre.setProperty(
        "cibleId", "{00000000-0000-0000-0000-000000000000}")
    menu_fenetre.setProperty("visible", True)
    app.processEvents()
    compte = int(menu_fenetre.property("count") or 0)
    if compte != 11:
        print("ECHEC : le menu du clic droit porte %d article(s), 11 "
              "attendus." % compte, file=sys.stderr)
        return 1
    haut = float(menu_fenetre.property("height") or 0)
    implicite = float(menu_fenetre.property("implicitHeight") or 0)
    if haut + 0.5 < implicite:
        print("ECHEC : le menu du clic droit s'ouvre a %d px alors qu'il en "
              "demande %d — il est borne par la fenetre de la barre."
              % (haut, implicite), file=sys.stderr)
        return 1

    # ── Le geste 6 : les etoiles de reglage de la barre laterale ────────────
    # Six sondages a valeur changee ne doivent pas recreer les etoiles —
    # meme mesure qu'autrefois, demenagee avec la barre laterale.
    reglages = next((o for o in racine.findChildren(QObject)
                     if o.objectName() == "repeaterReglages"), None)
    if reglages is None:
        print("ECHEC : le Repeater des reglages (objectName "
              "« repeaterReglages ») est introuvable dans le chrome.",
              file=sys.stderr)
        return 1
    crees = {"n": 0}
    reglages.itemAdded.connect(
        lambda i, it: crees.__setitem__("n", crees["n"] + 1))
    base_reglages = [
        {"cle": "volume", "nom": "Volume", "valeur": 40, "detail": "40 %",
         "forme": "glissiere"},
        {"cle": "webcam", "nom": "Webcam", "valeur": False, "detail": "",
         "forme": "bascule"},
        {"cle": "theme", "nom": "Theme", "valeur": "constellation",
         "detail": "", "forme": "choix", "choix": ["constellation"]},
    ]
    pont.reglagesPrets.emit(json.dumps(base_reglages))
    app.processEvents()
    premiere = crees["n"]
    if premiere != len(base_reglages):
        print("ECHEC : la premiere liste de reglages devait creer %d "
              "etoiles, %d creees." % (len(base_reglages), premiere),
              file=sys.stderr)
        return 1
    for k in range(6):
        variante = json.loads(json.dumps(base_reglages))
        variante[0]["valeur"] = 60 - k
        variante[0]["detail"] = "%d %%" % (60 - k)
        pont.reglagesPrets.emit(json.dumps(variante))
        app.processEvents()
    if crees["n"] != premiere:
        print("ECHEC : 6 changements de valeur ont recree des etoiles de "
              "reglage.", file=sys.stderr)
        return 1

    print("  chrome         : scene chargee, barre nourrie, bulle montree, "
          "reglages lus, tuiles stables, menu complet")
    return 0


if __name__ == "__main__":
    sys.exit(main())


