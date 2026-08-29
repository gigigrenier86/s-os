#!/usr/bin/python3
# S - une icone par application Android, au menu et au ciel, sans Waydroid.
#
# CE QUE CA REMPLACE. Le demon Python de Waydroid (tools/services/
# user_manager.py, « AppsService ») ecrivait un .desktop par application a
# chaque installation. Il est parti avec le paquet le 2026-08-29, et les 36
# lanceurs qu'il avait laisses dans ~/.local/share/applications portaient
# tous « Exec=waydroid app launch … » — un binaire mort. Les applications
# installees depuis n'avaient plus rien du tout.
#
# COMMENT, ET POURQUOI SANS ROOT. Les noms et les paquets viennent du service
# binder « waydroidplatform » (android_plateforme.py), joignable depuis la
# session. Les icones, c'est ANDROID LUI-MEME qui les ecrit, dans
# /data/icons/<paquet>.png — mesure le 2026-08-29 : 27 PNG datant tous du
# demarrage du conteneur, alors qu'aucun Python Waydroid ne tournait ; le
# demon amont ne faisait que les referencer, jamais les produire.
#
# DEUX SOURCES D'EVENEMENTS, ET C'EST VOULU :
#   1. le service « waydroidusermonitor » (interface IUserMonitor) que ce
#      demon enregistre sur /dev/binder, comme le presse-papiers enregistre
#      le sien : Android l'appelle a la fin du demarrage (userUnlocked) et a
#      chaque paquet installe/retire (packageStateChanged). C'est le patron
#      amont, verbatim — mais c'est une hypothese tant qu'Android ne l'a pas
#      appele sous nos yeux ;
#   2. une synchronisation complete toutes les 30 s tant que la plateforme
#      repond. Elle garantit le resultat meme si le rappel ne vient jamais,
#      et rattrape un conteneur demarre APRES ce demon (le cas normal a
#      l'ouverture de session).
#
# LE CIEL NE SE REMPLIT PAS DU PASSE, MAIS IL ACCUEILLE CE QU'ON AJOUTE
# (regle de s_placer_etoile, s-monde). Le premier passage reussi apres le
# demarrage de ce demon ecrit les lanceurs qui manquent SANS les placer au
# ciel — sinon les douze applications sans lanceur au 2026-08-29 tomberaient
# d'un coup sur le bureau. Ensuite, chaque paquet nouveau monte au ciel.
import logging
import os
import subprocess
import sys
import time

import gbinder
from gi.repository import GLib

sys.path.insert(0, os.environ.get("S_LIB") or "/usr/lib/s")
import android_plateforme as ap  # noqa: E402

INTERFACE_MONITEUR = "lineageos.waydroid.IUserMonitor"
NOM_MONITEUR = "waydroidusermonitor"
TRANSACTION_userUnlocked = 1
TRANSACTION_packageStateChanged = 2

INTERVALLE = 30
LANCEUR = "/usr/bin/s-android-lancer"
DOSSIER_LANCEURS = os.path.join(
    os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"),
    "applications")

# La liste amont des applications SYSTEME (user_manager.py, verbatim) :
# doublons LineageOS d'outils que S a deja (calculatrice, horloge,
# galerie...), le clavier, les services Google. NoDisplay=true, comme
# l'amont — et « Settings » avec, parce que l'utilisateur ne veut voir
# aucune interface d'Android qui ne soit pas une application a lui.
SYSTEME = {
    "com.android.calculator2", "com.android.camera2", "com.android.contacts",
    "com.android.deskclock", "com.android.documentsui", "com.android.email",
    "com.android.gallery3d", "com.android.inputmethod.latin",
    "com.android.settings", "com.google.android.gms", "org.lineageos.aperture",
    "org.lineageos.eleven", "org.lineageos.etar", "org.lineageos.jelly",
    "org.lineageos.recorder",
}


def chemin_lanceur(paquet):
    return os.path.join(DOSSIER_LANCEURS, "waydroid.%s.desktop" % paquet)


def ecrire_lanceur(app):
    """Ecrit (ou reecrit) le .desktop d'une application. Rend (nouveau,
    change) : nouveau = il n'existait pas avant, ce qui decide de l'etoile ;
    change = le fichier a ete ecrit, ce qui decide du rafraichissement."""
    paquet = app["packageName"]
    nom = (app.get("name") or paquet).replace("\n", " ").strip()
    chemin = chemin_lanceur(paquet)
    nouveau = not os.path.exists(chemin)
    lignes = [
        "[Desktop Entry]",
        "Type=Application",
        "Name=%s" % nom,
        "Exec=%s %s" % (LANCEUR, paquet),
        "Icon=%s" % os.path.join(ap.DOSSIER_ICONES, "%s.png" % paquet),
        # La classe de fenetre mesuree le 2026-08-29 (« waydroid.org.fdroid.
        # fdroid ») : c'est ce qui regroupe la fenetre et son icone.
        "StartupWMClass=waydroid.%s" % paquet,
        "Categories=X-S-Android;",
    ]
    if paquet in SYSTEME:
        lignes.append("NoDisplay=true")
    contenu = "\n".join(lignes) + "\n"
    try:
        with open(chemin, encoding="utf-8") as f:
            if f.read() == contenu:
                return False, False
    except OSError:
        pass
    os.makedirs(DOSSIER_LANCEURS, exist_ok=True)
    tmp = chemin + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(contenu)
    os.replace(tmp, chemin)
    return nouveau, True


def placer_etoile(ident):
    """La meme mecanique que s_placer_etoile (s-monde) : une position
    stable derivee de l'identifiant, ecrite dans placees.json de noyau."""
    try:
        import noyau
    except ImportError:
        return
    graine = int(subprocess.run(["cksum"], input=ident.encode(),
                                capture_output=True).stdout.split()[0])
    x = float("0.%d" % (20 + graine % 60))
    y = float("0.%d" % (20 + (graine // 60) % 55))
    placees = noyau.charger_placees()
    if ident in placees:
        return
    placees[ident] = {"x": x, "y": y}
    noyau.sauver_placees(placees)


def rafraichir_menu():
    subprocess.run(["update-desktop-database", DOSSIER_LANCEURS],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class Synchroniseur:
    def __init__(self):
        self.premier_passage = True
        self.plateforme = None

    def _plateforme(self):
        if self.plateforme is not None:
            try:
                if self.plateforme.pret():
                    return self.plateforme
            except Exception:  # binder mort avec le conteneur
                pass
            self.plateforme = None
        if not ap.service_actif():
            return None
        self.plateforme = ap.obtenir(0)
        return self.plateforme

    def tout(self):
        p = self._plateforme()
        if p is None:
            return
        try:
            apps = p.applications_lancables()
        except ap.ErreurAndroid as err:
            logging.warning("liste des applications : %s", err)
            self.plateforme = None
            return
        change = False
        for app in apps:
            nouveau, ecrit = ecrire_lanceur(app)
            change = change or ecrit
            if nouveau and not self.premier_passage and app["packageName"] not in SYSTEME:
                placer_etoile("waydroid.%s" % app["packageName"])
                logging.info("nouvelle application : %s", app["packageName"])
        # Ce qui n'est plus installe (ou n'a plus d'icone de lanceur) part —
        # meme regle que l'amont.
        lancables = {a["packageName"] for a in apps}
        try:
            for nom in os.listdir(DOSSIER_LANCEURS):
                if not (nom.startswith("waydroid.") and nom.endswith(".desktop")):
                    continue
                paquet = nom[len("waydroid."):-len(".desktop")]
                if paquet not in lancables:
                    os.remove(os.path.join(DOSSIER_LANCEURS, nom))
                    change = True
        except OSError:
            pass
        if change:
            rafraichir_menu()
        if self.premier_passage:
            logging.info("%d applications Android au menu", len(apps))
        self.premier_passage = False

    def un(self, paquet, etat):
        p = self._plateforme()
        if p is None:
            return
        try:
            app = p.getAppInfo(paquet)
        except ap.ErreurAndroid:
            app = None
        if app is None or not any(c.strip() == ap.CATEGORIE_LANCEUR for c in app["categories"]):
            chemin = chemin_lanceur(paquet)
            if os.path.exists(chemin):
                os.remove(chemin)
                rafraichir_menu()
            return
        nouveau, ecrit = ecrire_lanceur(app)
        if nouveau and paquet not in SYSTEME:
            placer_etoile("waydroid.%s" % paquet)
            logging.info("nouvelle application : %s", paquet)
        if ecrit:
            rafraichir_menu()


def servir(sync):
    gestionnaire = ap.gestionnaire()
    boucle = GLib.MainLoop()

    def repondre(req, code, flags):
        lecteur = req.init_reader()
        reponse_locale = objet.new_reply()
        if code == TRANSACTION_userUnlocked:
            uid = ap._valeur(lecteur.read_int32())
            logging.info("Android pret pour l'utilisateur %s", uid)
            GLib.idle_add(sync.tout)
            reponse_locale.append_int32(0)
        elif code == TRANSACTION_packageStateChanged:
            uid = ap._valeur(lecteur.read_int32())
            paquet = lecteur.read_string16()
            etat = ap._valeur(lecteur.read_int32())
            logging.info("paquet %s : etat %s", paquet, etat)
            GLib.idle_add(lambda: sync.un(paquet, etat) or False)
            reponse_locale.append_int32(0)
        else:
            return reponse_locale, -99999
        return reponse_locale, 0

    def presence():
        if gestionnaire.is_present():
            statut = gestionnaire.add_service_sync(NOM_MONITEUR, objet)
            if statut:
                logging.error("echec add_service %s : %s", NOM_MONITEUR, statut)
                boucle.quit()
            else:
                logging.info("service %s enregistre", NOM_MONITEUR)

    def periodique():
        sync.tout()
        return True

    objet = gestionnaire.new_local_object(INTERFACE_MONITEUR, repondre)
    presence()
    poignee = gestionnaire.add_presence_handler(presence)
    GLib.timeout_add_seconds(INTERVALLE, periodique)
    GLib.idle_add(lambda: sync.tout() or False)
    if poignee:
        boucle.run()
        gestionnaire.remove_handler(poignee)
    else:
        logging.error("echec add_presence_handler")
        time.sleep(INTERVALLE)


def main():
    logging.basicConfig(level=logging.INFO, format="android-applications: %(message)s")
    sync = Synchroniseur()
    while True:
        servir(sync)


if __name__ == "__main__":
    main()
