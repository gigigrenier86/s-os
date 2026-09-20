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

    tuiles = next((o for o in racine.findChildren(QObject)
                   if o.objectName() == "tuilesOuvertes"), None)
    if tuiles is None:
        print("ECHEC : le Repeater des tuiles (objectName « tuilesOuvertes ») "
              "est introuvable — rien n'a ete mesure.", file=sys.stderr)
        return 1

    ajouts = {"n": 0}
    tuiles.itemAdded.connect(lambda i, it: ajouts.__setitem__("n", ajouts["n"] + 1))
    echecs = []

    def envoyer(liste):
        leurre.changees.emit(json.dumps(liste))
        app.processEvents()

    def verifier(cond, texte):
        if not cond:
            echecs.append(texte)

    def deroule():
        # Trois fenetres : la premiere fois, trois tuiles sont creees.
        base = [fen("a", "Alpha", active=True), fen("b", "Beta"), fen("c", "Gamma")]
        envoyer(base)
        verifier(int(tuiles.property("count")) == 3,
                 "trois fenetres devraient donner trois tuiles (%s)" % tuiles.property("count"))
        cree = ajouts["n"]
        verifier(cree == 3, "la premiere liste devrait creer 3 tuiles, %d creees" % cree)

        # UN titre change, dix fois de suite : rien ne doit etre recree.
        for k in range(10):
            envoyer([fen("a", "Alpha", active=True), fen("b", "Beta page %d" % k),
                     fen("c", "Gamma")])
        verifier(ajouts["n"] == cree,
                 "10 changements de titre ont recree %d tuile(s) — le modele est "
                 "reinitialise a chaque nouvelle de kwin" % (ajouts["n"] - cree))

        # Le focus passe de a a c : idem.
        envoyer([fen("a", "Alpha"), fen("b", "Beta page 9"), fen("c", "Gamma", active=True)])
        verifier(ajouts["n"] == cree, "un changement de focus a recree des tuiles")

        # Une fenetre se ferme : le nombre baisse, rien n'est recree.
        envoyer([fen("a", "Alpha"), fen("c", "Gamma", active=True)])
        verifier(int(tuiles.property("count")) == 2 and ajouts["n"] == cree,
                 "la fermeture d'une fenetre n'a pas retire UNE tuile sans rien recreer")

        # Une fenetre s'ouvre : UNE tuile de plus, pas trois.
        envoyer([fen("a", "Alpha"), fen("c", "Gamma"), fen("d", "Delta", active=True)])
        verifier(int(tuiles.property("count")) == 3 and ajouts["n"] == cree + 1,
                 "l'ouverture d'une fenetre devait creer exactement 1 tuile (%d)"
                 % (ajouts["n"] - cree))

        # LE CIEL. « vivant » : vrai quand rien ne le cache, faux des qu'une
        # fenetre non reduite est ouverte — pas seulement en plein ecran.
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

        # LA BARRE LATERALE. Chaque ouverture relance les sondes et remplace la
        # liste des reglages en entier : un volume qui passe de 131 a 130 ne doit
        # pas detruire les etoiles — la glissiere ouverte visait une etoile qui
        # n'existait plus.
        reglages = next((o for o in racine.findChildren(QObject)
                         if o.objectName() == "repeaterReglages"), None)
        if reglages is None:
            echecs.append("le Repeater des reglages (objectName « repeaterReglages ») "
                          "est introuvable — rien n'a ete mesure")
        else:
            crees = {"n": 0}
            reglages.itemAdded.connect(
                lambda i, it: crees.__setitem__("n", crees["n"] + 1))
            base = json.loads(json.dumps(verif.FAUX_REGLAGES))
            pont.reglagesPrets.emit(json.dumps(base))
            app.processEvents()
            premiere = crees["n"]
            verifier(premiere == len(base),
                     "la premiere liste devrait creer %d etoiles de reglage, %d "
                     "creees" % (len(base), premiere))
            for k in range(6):
                variante = json.loads(json.dumps(base))
                variante[0]["valeur"] = 60 - k
                variante[0]["detail"] = "%d %%" % (60 - k)
                pont.reglagesPrets.emit(json.dumps(variante))
                app.processEvents()
            verifier(crees["n"] == premiere,
                     "6 changements de valeur ont recree %d etoile(s) de reglage — "
                     "le Repeater est reinitialise a chaque sondage"
                     % (crees["n"] - premiere))

        for e in echecs:
            print("ECHEC : " + e, file=sys.stderr)
        for p in dict.fromkeys(plaintes):
            print("ECHEC : avertissement QML : " + p, file=sys.stderr)
        if not echecs and not plaintes:
            print("  tuiles barre  : 3 creees, puis 10 titres + 1 focus + 1 fermeture "
                  "+ 1 ouverture = 1 seule creation de plus")
            print("  ciel vivant   : vrai sans fenetre, faux derriere une fenetre, "
                  "vrai si elle est reduite")
            print("  reglages      : %d etoiles creees, puis 6 sondages a valeur "
                  "changee = 0 recreation" % len(verif.FAUX_REGLAGES))
        app.exit(1 if (echecs or plaintes) else 0)

    QTimer.singleShot(400, deroule)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
