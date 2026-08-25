#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Charger la scene de Constellation pendant la construction, et echouer si elle
ne tient pas debout.

POURQUOI CE CONTROLE EXISTE. Une faute dans un fichier QML ne se voit pas a la
construction : QML n'est pas compile, il est lu au moment ou la scene s'ouvre.
Une virgule de trop, une propriete mal nommee, un type absent — et le defaut
n'apparait qu'a la premiere connexion de l'utilisateur, sur un ecran noir, sur
une machine ou il n'a pas de seconde machine pour se depanner.

Le carnet a un nom pour ce genre de piege, et ce depot se l'interdit. On charge
donc la scene ICI, dans le conteneur, sans ecran et sans GPU, et la construction
s'arrete si le moteur QML sort le moindre avertissement.

LE PONT EST REMPLACE PAR UN LEURRE : le vrai lit les .desktop de la machine, et
le conteneur de construction n'est pas la machine. Le leurre rend des donnees de
la meme forme — c'est la scene qu'on verifie, pas l'inventaire.
"""

import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QObject, QTimer, QUrl, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

QML = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/s/constellation/qml"

FAUSSES = [
    {"id": "a", "nom": "Une application", "src": "linux", "ico": "i-globe",
     "ep": 1, "epingle": 1, "img": "", "txt": "essai", "compte": 3},
    {"id": "b", "nom": "Une autre", "src": "windows", "ico": "i-manette",
     "ep": 0, "epingle": 0, "img": "", "txt": "essai", "compte": 0},
    {"id": "c", "nom": "Une troisieme", "src": "android", "ico": "i-tel",
     "ep": 1, "epingle": 1, "img": "", "txt": "essai", "compte": 1},
]


class PontLeurre(QObject):
    @Slot(result="QVariant")
    def etoiles(self):
        return {"etoiles": FAUSSES, "usage": {"a": 3, "c": 1},
                "placees": {"a": {"x": 0.3, "y": 0.3}, "c": {"x": 0.6, "y": 0.5}},
                "epingles": ["a", "c"]}

    @Slot(result="QVariant")
    def dossiers(self):
        return [{"nom": "Dossier personnel", "chemin": "/root",
                 "ico": "i-maison", "detail": ""}]

    @Slot(str, result=str)
    def lancer(self, ident):
        return ident

    @Slot(str, bool)
    def epingler(self, ident, oui):
        pass

    @Slot(str, float, float)
    def placer(self, ident, x, y):
        pass

    @Slot(str)
    def retirerDuBureau(self, ident):
        pass

    @Slot(str, result=str)
    def session(self, action):
        return action

    @Slot(result="QVariant")
    def reglages(self):
        return {"fond": "nebuleuse", "noms": False}

    @Slot(str, "QVariant")
    def reglerFond(self, cle, valeur):
        pass

    @Slot(str, result=str)
    def ouvrirDossier(self, chemin):
        return chemin


def main():
    app = QGuiApplication(sys.argv[:1])
    moteur = QQmlApplicationEngine()
    plaintes = []
    moteur.warnings.connect(
        lambda ws: plaintes.extend(w.toString() for w in ws))
    pont = PontLeurre()
    moteur.rootContext().setContextProperty("pont", pont)
    # LE SERVICE DE NOTIFICATIONS EST NUL ICI, ET C'EST UN CAS REEL : la
    # coquille pose la meme valeur quand le nom du bus est deja pris. La scene
    # doit charger sans bulles comme elle charge avec.
    moteur.rootContext().setContextProperty("notifications", None)
    moteur.rootContext().setContextProperty("fenetres", None)
    moteur.load(QUrl.fromLocalFile(os.path.join(QML, "Constellation.qml")))

    if not moteur.rootObjects():
        print("ECHEC : la scene de Constellation n'a pas charge.", file=sys.stderr)
        for p in dict.fromkeys(plaintes):
            print("   " + p, file=sys.stderr)
        return 1

    racine = moteur.rootObjects()[0]
    racine.setProperty("visibility", 2)
    racine.setWidth(1600)
    racine.setHeight(900)

    # On ouvre le menu Demarrer : la moitie de la scene ne s'instancie qu'a ce
    # moment-la, et une faute qui n'y serait que la passerait sinon inapercue.
    def ouvrir():
        for enfant in racine.findChildren(QObject):
            try:
                if enfant.objectName() == "menuDemarrer":
                    enfant.setProperty("visible", True)
            except (RuntimeError, AttributeError):
                pass
        QTimer.singleShot(700, fini)

    code = {"valeur": 0}

    def fini():
        uniques = list(dict.fromkeys(plaintes))
        if uniques:
            print("ECHEC : le moteur QML se plaint (%d)." % len(uniques),
                  file=sys.stderr)
            for p in uniques:
                print("   " + p, file=sys.stderr)
            code["valeur"] = 1
        else:
            print("  scene QML     : chargee, menu ouvert, aucun avertissement")
        app.quit()

    QTimer.singleShot(900, ouvrir)
    app.exec()
    return code["valeur"]


if __name__ == "__main__":
    sys.exit(main())
