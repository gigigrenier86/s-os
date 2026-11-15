#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Les tuiles de la barre survivent aux nouvelles de kwin — et le ciel ne
bouge que s'il est regarde.

POURQUOI CE CONTROLE EXISTE. verifier-constellation.py prouve que la scene
CHARGE ; il ne dit rien de ce qu'elle FAIT quand kwin parle. Or deux defauts
n'apparaissent qu'a l'usage, et un « aucun avertissement » ne les voit pas :

  1. Une nouvelle de kwin dont UN champ d'UNE fenetre change (un titre de page,
     le focus qui passe d'une fenetre a l'autre) reinitialisait le modele du
     Repeater : toutes les tuiles detruites et recreees, icones rechargees,
     survol et animations remis a zero. Mesure du 2026-09-19 : 40 changements de
     titre sur six fenetres → 240 tuiles creees.

  3. La barre laterale : chaque ouverture relance les sondes et remplacait la
     liste des reglages en entier — un volume de 131 a 130 recreait toutes les
     etoiles, au moment ou l'on commence a s'en servir.

  2. La garde « vivant » ne coupait la derive des etoiles que pour un VRAI plein
     ecran. Trois fenetres maximisees devant le ciel le laissaient animer ses 46
     etoiles a soixante images par seconde : 8,8 % de CPU contre 0,0 % une fois
     corrige.

Il ne mesure pas de temps — un temps depend de la machine qui construit — il
COMPTE : des delegues crees, un booleen lu. Un compte est le meme partout.

UN CONTROLE QUI NE TROUVE PAS SA CIBLE REND VERT SANS RIEN MESURER, comme le
dit verifier-constellation.py du compteur d'etoiles. Ici, si le Repeater des
tuiles est introuvable, on ECHOUE.
"""

import json
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

import importlib.util

ICI = os.path.dirname(os.path.abspath(__file__))
QML = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/s/constellation/qml"

# On reutilise le leurre du pont du controle voisin plutot que de le recopier :
# deux faux ponts finiraient par diverger.
_spec = importlib.util.spec_from_file_location(
    "verif", os.path.join(ICI, "verifier-constellation.py"))
verif = importlib.util.module_from_spec(_spec)
_argv = sys.argv
sys.argv = [_argv[0], QML]
_spec.loader.exec_module(verif)
sys.argv = _argv

from PySide6.QtCore import QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
# Sans cet import le type « QQuickItem* » du signal itemAdded n'est pas
# enregistre : la connexion echoue a chaque emission, en silence pour le
# controle — qui compterait alors zero creation et rendrait vert.
from PySide6.QtQuick import QQuickItem  # noqa: F401


class FenetresLeurre(QObject):
    changees = Signal(str)
    modeChange = Signal(str)

    @Slot(result=str)
    def mode(self):
        return "non"


def fen(ident, titre, active=False, reduite=False):
    return {"id": ident, "classe": "app-" + ident, "titre": titre,
            "active": active, "reduite": reduite, "pid": 0, "plein": False,
            "montrable": True}


def main():
    app = QGuiApplication(sys.argv[:1])
    moteur = QQmlApplicationEngine()
    plaintes = []
    moteur.warnings.connect(lambda ws: plaintes.extend(w.toString() for w in ws))
    leurre = FenetresLeurre()
    # UNE REFERENCE PYTHON EST OBLIGATOIRE : un leurre cree en ligne est ramasse
    # par le ramasse-miettes et la propriete de contexte devient « null ».
    pont = verif.PontLeurre()
    moteur.rootContext().setContextProperty("pont", pont)
    moteur.rootContext().setContextProperty("notifications", None)
    moteur.rootContext().setContextProperty("fenetres", leurre)
    moteur.load(QUrl.fromLocalFile(os.path.join(QML, "Constellation.qml")))
    if not moteur.rootObjects():
        print("ECHEC : la scene n'a pas charge.", file=sys.stderr)
        return 1
    racine = moteur.rootObjects()[0]

    echecs = []

    def envoyer(liste):
        leurre.changees.emit(json.dumps(liste))
        app.processEvents()

    def verifier(cond, texte):
        if not cond:
            echecs.append(texte)

    def deroule():
        # LE CIEL. « vivant » : vrai quand rien ne le cache, faux des qu'une
        # fenetre non reduite est ouverte — pas seulement en plein ecran.
        # Depuis le 2026-11-14, la liste vient des nouvelles du rapporteur de
        # kwin, nourries dans « ouvertures » par la Connections de la scene —
        # les tuiles, elles, vivent dans le chrome (verifier-chrome.py).
        envoyer([])
        verifier(racine.property("vivant") is True,
                 "le ciel devrait vivre quand aucune fenetre n'est ouverte")
        envoyer([fen("a", "Alpha", active=True)])
        verifier(racine.property("vivant") is False,
                 "le ciel anime alors qu'une fenetre non reduite le cache")
        envoyer([fen("a", "Alpha", reduite=True)])
        verifier(racine.property("vivant") is True,
                 "une fenetre reduite ne cache rien : le ciel devrait vivre")

        # Aucun champ absent ne doit produire d'avertissement de type.
        envoyer([{"id": "x", "classe": "x", "titre": "sans champs booleens"}])

        for e in echecs:
            print("ECHEC : " + e, file=sys.stderr)
        for p in dict.fromkeys(plaintes):
            print("ECHEC : avertissement QML : " + p, file=sys.stderr)
        if not echecs and not plaintes:
            print("  ciel vivant   : vrai sans fenetre, faux derriere une fenetre, "
                  "vrai si elle est reduite")
        app.exit(1 if (echecs or plaintes) else 0)

    QTimer.singleShot(400, deroule)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
