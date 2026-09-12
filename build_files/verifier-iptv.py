#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Charger la scene du lecteur IPTV pendant la construction, et echouer si
elle ne tient pas debout.

MEME RAISON D'ETRE QUE verifier-constellation.py : QML n'est pas compile, il
est lu au moment ou la fenetre s'ouvre. Une virgule de trop, une propriete
Layout mal posee, un Dialog dont le contentItem ne charge pas — et le defaut
n'apparaitrait qu'au premier clic de l'utilisateur, jamais a la construction.

LE PONT EST REMPLACE PAR UN LEURRE, meme principe : le vrai parle au reseau
et lance mpv, le leurre rend des donnees de la meme forme et journalise ce
qu'on lui demande — c'est la scene qu'on verifie, pas le reseau ni mpv.
"""

import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QObject, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

QML = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/s/iptv/qml"


class PontLeurre(QObject):
    chainesPretes = Signal("QVariant")
    erreurChargement = Signal(str)
    lectureChangee = Signal(bool, str)

    def __init__(self):
        super().__init__()
        self._playlists = [{"nom": "Demo", "url": "http://exemple.test/list.m3u"}]

    @Slot(result="QVariant")
    def playlists(self):
        return self._playlists

    @Slot(str, str)
    def ajouterM3U(self, nom, url):
        self._playlists.append({"nom": nom, "url": url})

    @Slot(str, str, str, str, str)
    def ajouterXtream(self, nom, serveur, port, utilisateur, motdepasse):
        pass

    @Slot(int)
    def supprimer(self, indice):
        pass

    @Slot(int)
    def demanderChaines(self, indice):
        # Reponse synchrone dans le leurre — le vrai Pont la donne par un
        # thread, mais la scene ne doit pas s'en soucier : elle ne fait que
        # reagir au signal, jamais au delai qui le precede.
        self.chainesPretes.emit([
            {"nom": "Chaine A", "groupe": "Sport", "logo": "", "tvg_id": "", "url": "http://x/a"},
            {"nom": "Chaine B", "groupe": "Sport", "logo": "", "tvg_id": "", "url": "http://x/b"},
            {"nom": "Chaine C", "groupe": "", "logo": "", "tvg_id": "", "url": "http://x/c"},
        ])

    @Slot(str, str)
    def lancer(self, url, titre):
        self.lectureChangee.emit(True, titre)

    @Slot()
    def arreter(self):
        self.lectureChangee.emit(False, "")


def main():
    app = QGuiApplication(sys.argv[:1])
    moteur = QQmlApplicationEngine()
    plaintes = []
    moteur.warnings.connect(lambda ws: plaintes.extend(w.toString() for w in ws))

    pont = PontLeurre()
    moteur.rootContext().setContextProperty("pont", pont)
    moteur.load(QUrl.fromLocalFile(os.path.join(QML, "Principal.qml")))

    if not moteur.rootObjects():
        print("ECHEC : Principal.qml n'a pas charge.", file=sys.stderr)
        for p in dict.fromkeys(plaintes):
            print("   " + p, file=sys.stderr)
        return 1

    racine = moteur.rootObjects()[0]

    pont.demanderChaines(0)
    app.processEvents()
    if len(racine.property("chaines") or []) != 3:
        print("ECHEC : les chaines emises par le pont ne se reflechissent pas "
              "dans la scene.", file=sys.stderr)
        return 1

    pont.lectureChangee.emit(True, "Chaine A")
    app.processEvents()
    if racine.property("enLecture") is not True:
        print("ECHEC : enLecture ne suit pas lectureChangee.", file=sys.stderr)
        return 1
    pont.lectureChangee.emit(False, "")
    app.processEvents()

    pont.erreurChargement.emit("panne simulee")
    app.processEvents()

    # Les deux boites de dialogue : la partie la moins triviale du fichier
    # (Dialog.contentItem avec TabBar + StackLayout imbriques).
    for nom in ("boiteAjout", "boiteErreur"):
        boite = racine.findChild(QObject, nom)
        if boite is None:
            print("ECHEC : %s introuvable dans la scene." % nom, file=sys.stderr)
            return 1
        boite.open()
        app.processEvents()
        if not boite.property("visible"):
            print("ECHEC : %s ne s'ouvre pas." % nom, file=sys.stderr)
            return 1
        boite.close()
        app.processEvents()

    if plaintes:
        print("ECHEC : la scene a produit des avertissements QML.", file=sys.stderr)
        for p in dict.fromkeys(plaintes):
            print("   " + p, file=sys.stderr)
        return 1

    print("scene IPTV     : chargee, chaines refletees, dialogues ouverts, aucun avertissement")
    return 0


if __name__ == "__main__":
    sys.exit(main())
