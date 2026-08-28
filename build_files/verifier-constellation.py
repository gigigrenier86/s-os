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

import io
import json
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QWindow
from PySide6.QtQml import QQmlApplicationEngine

QML = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/s/constellation/qml"

# LE CHEMIN S'AFFICHE, ET CE N'EST PAS DECORATIF. Le defaut vise /usr/share,
# ce qui est juste PENDANT la construction — « COPY files/ / » a deja eu lieu.
# Lance a la main sur la machine, sans argument, il verifie donc l'IMAGE
# INSTALLEE et non le depot qu'on vient de modifier : le controle rend alors un
# verdict sur un fichier qu'on n'a pas ecrit. Une heure a ete perdue ainsi le
# 2026-08-26, a comparer deux scenes differentes en les croyant identiques.
print("  scene verifiee : " + QML)

FAUSSES = [
    {"id": "a", "nom": "Une application", "src": "linux", "ico": "i-globe",
     "ep": 1, "epingle": 1, "img": "", "txt": "essai", "compte": 3},
    {"id": "b", "nom": "Une autre", "src": "windows", "ico": "i-manette",
     "ep": 0, "epingle": 0, "img": "", "txt": "essai", "compte": 0},
    {"id": "c", "nom": "Une troisieme", "src": "android", "ico": "i-tel",
     "ep": 1, "epingle": 1, "img": "", "txt": "essai", "compte": 1},
]

# LES ETOILES JAUNES DOIVENT ETRE DANS LE LEURRE, SINON LE CONTROLE NE LES
# EXERCE PAS. La scene protege ses acces par « donnees.fichiers || [] » : sans
# ces entrees, elle chargerait sans un avertissement et le controle rendrait 0
# en n'ayant jamais instancie une seule etoile jaune. Un banc qui ne peut pas
# echouer ne mesure rien.
#
# Les trois cas qui comptent y sont : un dossier, un fichier ordinaire, et un
# fichier DEJA PLACE a la main — celui-la verifie qu'il n'est pas dessine deux
# fois, une fois par la boucle des placees et une fois par celle des fichiers.
FAUX_FICHIERS = [
    {"id": "fichier:/tmp/s-essai/Dossier", "nom": "Dossier", "src": "fichier",
     "ico": "i-dossier", "ep": 1, "epingle": 0, "img": "",
     "txt": "/tmp/s-essai/Dossier", "compte": 0,
     "chemin": "/tmp/s-essai/Dossier", "dossier": 1, "bureau": 1},
    {"id": "fichier:/tmp/s-essai/note.txt", "nom": "note.txt", "src": "fichier",
     "ico": "i-notes", "ep": 1, "epingle": 0, "img": "",
     "txt": "/tmp/s-essai/note.txt", "compte": 0,
     "chemin": "/tmp/s-essai/note.txt", "dossier": 0, "bureau": 1},
    {"id": "fichier:/tmp/s-essai/place.png", "nom": "place.png", "src": "fichier",
     "ico": "i-image", "ep": 1, "epingle": 0, "img": "",
     "txt": "/tmp/s-essai/place.png", "compte": 0,
     "chemin": "/tmp/s-essai/place.png", "dossier": 0, "bureau": 1},
    # UN FICHIER EPINGLE DEPUIS UN AUTRE DOSSIER. Il est dans la liste pour que
    # la barre le retrouve par son identifiant, et il ne doit PAS monter au
    # ciel — sinon epingler un fichier de Documents le ferait apparaitre sur le
    # bureau, ou il n'a jamais ete.
    {"id": "fichier:/tmp/s-ailleurs/loin.txt", "nom": "loin.txt", "src": "fichier",
     "ico": "i-notes", "ep": 1, "epingle": 1, "img": "",
     "txt": "/tmp/s-ailleurs/loin.txt", "compte": 0,
     "chemin": "/tmp/s-ailleurs/loin.txt", "dossier": 0, "bureau": 0},
]


# LES TROIS FORMES DE REGLAGE SONT TOUTES REPRESENTEES. Une barre qui ne
# recoit que des bascules ne prouve rien sur les glissieres ni sur les choix —
# et ce sont eux qui portent le plus de QML.
FAUX_REGLAGES = [
    {"cle": "volume", "nom": "Volume", "ico": "i-son", "type": "glissiere",
     "valeur": 62, "max": 150, "actif": True, "detail": "62 %"},
    {"cle": "luminosite", "nom": "Luminosite", "ico": "i-ecran",
     "type": "glissiere", "valeur": 60, "max": 100, "actif": True,
     "detail": "60 %"},
    # VERROUILLE DANS LE LEURRE, parce que c'est le cas REEL de cette machine :
    # le Wi-Fi y est la seule voie vers le reseau. Un leurre qui ne montrerait
    # que des reglages libres n'exercerait jamais cette branche.
    {"cle": "wifi", "nom": "Wi-Fi", "ico": "i-reseau", "type": "bascule",
     "actif": True, "verrouille": True, "detail": "Net gigi"},
    {"cle": "energie", "nom": "Energie", "ico": "i-alim", "type": "choix",
     "valeur": "balanced", "actif": True, "detail": "Equilibre",
     "choix": [{"cle": "balanced", "nom": "Equilibre"},
               {"cle": "perf", "nom": "Performance"}]},
    {"cle": "capture", "nom": "Capturer", "ico": "i-image", "type": "action",
     "actif": True, "detail": "selection"},
]


class PontLeurre(QObject):
    @Slot(result="QVariant")
    def etoiles(self):
        return {"etoiles": FAUSSES, "usage": {"a": 3, "c": 1},
                "placees": {"a": {"x": 0.3, "y": 0.3}, "c": {"x": 0.6, "y": 0.5},
                            "fichier:/tmp/s-essai/place.png": {"x": 0.8, "y": 0.2}},
                "epingles": ["a", "c", "fichier:/tmp/s-ailleurs/loin.txt"],
                "fichiers": FAUX_FICHIERS}

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

    @Slot(str, result=str)
    def lancerEnRoot(self, ident):
        return ident

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

    # LES GESTES DE FICHIERS SONT DANS LE LEURRE MEME S'ILS NE SONT PAS
    # APPELES ICI. Un slot absent du pont ne fait rien echouer au chargement :
    # il echoue AU CLIC, c'est-a-dire chez l'utilisateur et jamais en
    # construction. Le controle de concordance plus bas les compare un a un.
    @Slot(str, result=str)
    def proprietes(self, ident):
        return ident

    @Slot(str, result=str)
    def corbeille(self, ident):
        return ident

    @Slot(str, str, result=str)
    def renommer(self, ident, nom):
        return nom

    @Slot(str, result=str)
    def compresser(self, ident):
        return ident

    @Slot(str, result=str)
    def terminalIci(self, ident):
        return ident

    @Slot(str, bool, result=str)
    def creerSurLeBureau(self, nom, est_dossier):
        return nom

    @Slot(str, result=str)
    def cheminDe(self, ident):
        return ident

    @Slot(result=str)
    def dossierBureau(self):
        return "/tmp/s-essai"

    reglagesPrets = Signal(str)

    @Slot()
    def rafraichirReglages(self):
        # Le leurre repond TOUT DE SUITE et sans fil : le but du controle est
        # d'instancier la barre laterale avec des reglages des trois formes,
        # pas de mesurer la machine.
        self.reglagesPrets.emit(json.dumps(FAUX_REGLAGES))

    @Slot(str, "QVariant", result=str)
    def reglerRapide(self, cle, valeur):
        return cle

    @Slot(QWindow, int)
    def bornerBarre(self, fenetre, sensible):
        # Meme raison que bornerLaterale : le leurre ne masque rien, il DECLARE.
        pass

    @Slot(QWindow, bool)
    def bornerLaterale(self, fenetre, deploye):
        # Le leurre ne borne rien : le controle n'a pas de compositeur a qui
        # parler. Il doit seulement DECLARER le slot, sinon la barre laterale
        # appellerait dans le vide — au clic, chez l'utilisateur.
        pass


def concordance_des_slots():
    """Le leurre declare-t-il tout ce que le vrai pont declare ?

    POURQUOI CE CONTROLE EXISTE. Le leurre remplace le pont pendant la
    verification. Un slot present dans le pont mais ABSENT du leurre ne fait
    rien echouer : la scene charge, le menu s'ouvre, tout parait sain — et
    l'appel meurt AU CLIC, chez l'utilisateur, des mois plus tard. Mesure le
    2026-08-26 : sept gestes de fichiers etaient dans ce cas.

    On lit les decorateurs plutot que d'importer : importer le pont ferait
    tourner son code, et il ouvre un service D-Bus.
    """
    import re
    ici = os.path.dirname(os.path.abspath(__file__))
    candidats = [os.path.join(ici, "..", "files", "usr", "bin", "s-constellation"),
                 "/usr/bin/s-constellation"]
    pont = next((c for c in candidats if os.path.isfile(c)), None)
    if not pont:
        print("  slots         : pont introuvable, controle saute")
        return []
    motif = re.compile(r"@Slot\([^)]*\)\s*\n\s*def (\w+)")
    with io.open(pont, encoding="utf-8") as f:
        vrais = set(motif.findall(f.read()))
    with io.open(os.path.abspath(__file__), encoding="utf-8") as f:
        faux = set(motif.findall(f.read()))
    manquants = sorted(vrais - faux)
    if manquants:
        print("ECHEC : le leurre ne declare pas %d slot(s) du pont : %s"
              % (len(manquants), ", ".join(manquants)), file=sys.stderr)
    else:
        print("  slots         : %d au pont, tous declares par le leurre" % len(vrais))
    return manquants


def concordance_du_pont_fenetres():
    """Chaque « fenetres.machin(...) » du QML existe-t-il sur Fenetres ?

    POURQUOI UN SECOND CONTROLE PLUTOT QU'UN ELARGISSEMENT DU PREMIER. Il y a
    DEUX ponts vers QML : « pont » (s-constellation) et « fenetres »
    (fenetres.py). Le premier a un leurre, donc on compare deux declarations.
    Le second n'en a pas — la verification lui donne None, parce que
    l'instancier ouvrirait un service D-Bus — donc aucun de ses appels n'est
    exerce et une faute de frappe passerait verte jusqu'au clic. On compare
    donc les appels ECRITS DANS LE QML aux slots declares dans fenetres.py.

    C'est exactement le defaut que le premier controle reproche a l'absence de
    leurre : « il echoue AU CLIC, c'est-a-dire chez l'utilisateur et jamais en
    construction ».
    """
    import re
    ici = os.path.dirname(os.path.abspath(__file__))
    candidats = [os.path.join(ici, "..", "files", "usr", "lib", "s", "fenetres.py"),
                 "/usr/lib/s/fenetres.py"]
    source = next((c for c in candidats if os.path.isfile(c)), None)
    if not source:
        print("  pont fenetres : fenetres.py introuvable, controle saute")
        return []
    with io.open(source, encoding="utf-8") as f:
        declares = set(re.findall(r"@Slot\([^)]*\)\s*\n\s*def (\w+)", f.read()))
    appeles = set()
    for nom in sorted(os.listdir(QML)):
        if not nom.endswith(".qml"):
            continue
        with io.open(os.path.join(QML, nom), encoding="utf-8") as f:
            for appel in re.findall(r"\bfenetres\.(\w+)\s*\(", f.read()):
                appeles.add(appel)
    inconnus = sorted(appeles - declares)
    if inconnus:
        print("ECHEC : le QML appelle %d methode(s) que Fenetres ne declare "
              "pas : %s" % (len(inconnus), ", ".join(inconnus)), file=sys.stderr)
    else:
        print("  pont fenetres : %d appel(s) QML, tous declares sur Fenetres"
              % len(appeles))
    return inconnus


def main():
    app = QGuiApplication(sys.argv[:1])
    moteur = QQmlApplicationEngine()
    plaintes = []
    moteur.warnings.connect(
        lambda ws: plaintes.extend(w.toString() for w in ws))
    manquants = concordance_des_slots() + concordance_du_pont_fenetres()
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
    # LE MENU DU CLIC DROIT DE LA BARRE EST OUVERT ICI, ET IL A SA RAISON.
    # Ses articles sont poses par un Repeater a l'interieur d'un Menu — un
    # montage qui charge sans une plainte meme s'il n'instancie RIEN, parce
    # qu'un Menu vide est un Menu valide. Sans ce controle, « fermer la
    # fenetre » aurait pu n'exister que dans le fichier : la scene se serait
    # verifiee verte, et le menu se serait ouvert vide chez l'utilisateur.
    # NEUF, ET LE COMPTE INCLUT LES SEPARATEURS : quatre articles ecrits a la
    # main (ranger, veille immediate, fermer, menage), TROIS poses par le
    # Repeater — les modes de veille, la partie qu'on verifie vraiment — et
    # deux traits. « count » compte tout ce que le Menu porte.
    ARTICLES_ATTENDUS = 9
    manque_articles = {"valeur": 0, "trouve": False}
    # La hauteur du menu une fois ouvert, et celle qu'il demande. Voir le
    # controle plus bas : c'est la mesure qui manquait le 2026-08-26.
    articles = {"haut": 0.0, "implicite": 0.0}

    def ouvrir():
        for enfant in racine.findChildren(QObject):
            try:
                if enfant.objectName() == "menuDemarrer":
                    enfant.setProperty("visible", True)
                elif enfant.objectName() == "menuFenetre":
                    # « cible » est desormais calcule depuis la liste des
                    # ouvertures : on pose l'identifiant, comme le fait
                    # ouvrirPour().
                    enfant.setProperty(
                        "cibleId", "{00000000-0000-0000-0000-000000000000}")
                    enfant.setProperty("visible", True)
                    manque_articles["trouve"] = True
                    articles["haut"] = float(enfant.property("height") or 0)
                    articles["implicite"] = float(
                        enfant.property("implicitHeight") or 0)
                    # « count », PAS « contentData ». Mesure du 2026-08-26 :
                    # contentData rend une liste vide sur un Menu pourtant
                    # peuple — c'est la propriete par defaut, pas l'inventaire
                    # des articles. Le controle rendait donc zero article sur
                    # un menu complet, ce qui aurait fait echouer la
                    # construction pour un defaut inexistant.
                    manque_articles["valeur"] = int(
                        enfant.property("count") or 0)
            except (RuntimeError, AttributeError):
                pass
        QTimer.singleShot(700, fini)

    code = {"valeur": 0}

    def fini():
        # COMPTER LES ASTRES, PARCE QUE « AUCUN AVERTISSEMENT » N'EST PAS
        # « QUELQUE CHOSE S'EST DESSINE ». La scene chargeait deja sans une
        # plainte quand le pont ne rendait aucun fichier — le controle rendait
        # 0 en n'ayant instancie aucune etoile jaune. Ici on compte.
        #
        # DEUX applications placees + TROIS fichiers du bureau = CINQ.
        #   Six  -> le fichier deja place est dessine deux fois, une fois par la
        #           boucle des placees et une fois par celle des fichiers ;
        #   Six  -> ou bien le fichier epingle depuis un AUTRE dossier est monte
        #           au ciel, alors qu'il n'y a jamais ete.
        # UN CONTROLE QUI NE TROUVE PAS SA CIBLE REND VERT SANS RIEN MESURER,
        # et c'est la faute que ce fichier reproche deja au compteur d'astres.
        if not manque_articles["trouve"]:
            print("ECHEC : le menu du clic droit de la barre est introuvable "
                  "dans la scene (objectName « menuFenetre »).", file=sys.stderr)
            code["valeur"] = 1
        elif manque_articles["valeur"] != ARTICLES_ATTENDUS:
            # « != » ET NON « < ». Le controle n'attrapait que le menu vide :
            # une edition qui duplique le Repeater ou laisse un article errant
            # passait a dix, douze ou vingt sans le moindre signal. Un compte
            # attendu qui n'est pas atteint PAR LE HAUT est un defaut autant
            # que par le bas.
            print("ECHEC : le menu du clic droit de la barre porte %d article(s), "
                  "%d attendus." % (manque_articles["valeur"], ARTICLES_ATTENDUS),
                  file=sys.stderr)
            code["valeur"] = 1
        # LA HAUTEUR, PARCE QUE COMPTER LES ARTICLES NE DIT PAS QU'ON LES VOIT.
        # Mesure du 2026-08-27 : le menu portait bien ses neuf articles et
        # demandait 360 pixels, mais s'ouvrait a 52 — la hauteur de la fenetre
        # de la barre, qui borne tout Popup mis en page en elle. Neuf articles
        # dont un seul visible passaient ce controle en vert.
        elif articles["haut"] + 0.5 < articles["implicite"]:
            print("ECHEC : le menu du clic droit s'ouvre a %d px alors qu'il en "
                  "demande %d — il est borne par la fenetre de la barre. Voir "
                  "« popupType » dans Barre.qml."
                  % (articles["haut"], articles["implicite"]), file=sys.stderr)
            code["valeur"] = 1
        else:
            print("  menu barre    : %d articles instancies, %d attendus, "
                  "%d px ouverts pour %d demandes"
                  % (manque_articles["valeur"], ARTICLES_ATTENDUS,
                     articles["haut"], articles["implicite"]))
        attendu = 5
        # ON DEMANDE AU REPEATER, PAS A L'ARBRE D'OBJETS. Compter les enfants
        # par leur objectName rendait ZERO alors que le modele en portait cinq :
        # findChildren ne descend pas dans les delegues instancies par un
        # Repeater. Le compteur mentait, pas le ciel — et sans cette
        # verification le controle aurait fait echouer une scene correcte.
        vus = -1
        for enfant in racine.findChildren(QObject):
            try:
                if enfant.objectName() == "repeaterCiel":
                    vus = int(enfant.property("count"))
                    break
            except (RuntimeError, AttributeError, TypeError, ValueError):
                pass
        if vus < 0:
            plaintes.append("le Repeater du ciel est introuvable")
            vus = 0
        if vus != attendu:
            print("ECHEC : %d etoiles au ciel, %d attendues." % (vus, attendu),
                  file=sys.stderr)
            plaintes.append("compte d'etoiles : %d au lieu de %d" % (vus, attendu))

        for m in manquants:
            plaintes.append("slot absent du leurre : " + m)

        uniques = list(dict.fromkeys(plaintes))
        if uniques:
            print("ECHEC : le moteur QML se plaint (%d)." % len(uniques),
                  file=sys.stderr)
            for p in uniques:
                print("   " + p, file=sys.stderr)
            code["valeur"] = 1
        else:
            print("  scene QML     : chargee, menu ouvert, aucun avertissement")
            print("  ciel          : %d etoiles instanciees, dont 3 jaunes" % vus)
        app.quit()

    QTimer.singleShot(900, ouvrir)
    app.exec()
    return code["valeur"]


if __name__ == "__main__":
    sys.exit(main())
