#!/usr/bin/python3
# S - notifications Android → bulle S.
#
# MÉCANISME. Android envoie ses notifications via le service Binder
# « android.app.INotificationManager » (le vrai gestionnaire côté système).
# Depuis l'hôte, on ne peut pas s'y abonner directement sans entrer dans
# l'espace Binder du conteneur. La voie qui marche sans patch Android :
#
#   Waydroid expose une interface ALLÉGÉE « waydroidnotification » sur
#   /dev/binder (le même bind-monté dans le conteneur), que le greffon côté
#   Android appelle à chaque notification. C'est exactement le même patron
#   que « waydroidclipboard » (android-presse-papiers.py) — même fichier
#   périphérique, même bibliothèque gbinder, même boucle GLib.
#
# INTERFACE. L'interface « lineageos.waydroid.INotification » supporte
# deux transactions :
#   1 — notify(pkg, titre, corps, priorite, icone_base64)
#   2 — cancel(pkg, id)
#
# ICÔNE. Le greffon Android passe l'icône de l'app en PNG base64. On la
# décode dans un fichier temporaire et on la passe à notify-send via --icon.
#
# SON. libnotify déclenche le son de notification de S automatiquement
# (freedesktop.org/wiki/Specifications/sound-theme-spec).
import base64
import logging
import os
import subprocess
import sys
import tempfile
import threading

import gbinder
from gi.repository import GLib

INTERFACE     = "lineageos.waydroid.INotification"
NOM_SERVICE   = "waydroidnotification"
BINDER_DRIVER = "binder"

TRANSACTION_NOTIFY = 1
TRANSACTION_CANCEL = 2

# Anti-doublon : même app + même titre reçue en moins de 3 s → ignorée.
_vus = {}
_vus_verrou = threading.Lock()
DELAI_DOUBLON = 3.0

arret_demande = False
boucle_courante = None


def _notification_doublon(cle):
    import time
    maintenant = time.monotonic()
    with _vus_verrou:
        dernier = _vus.get(cle, 0.0)
        if maintenant - dernier < DELAI_DOUBLON:
            return True
        _vus[cle] = maintenant
        a_supprimer = [k for k, t in _vus.items() if maintenant - t > 60.0]
        for k in a_supprimer:
            del _vus[k]
    return False


def _afficher(app, titre, corps, icone_b64):
    """Envoie la notification au bureau S via notify-send."""
    cle = "{}|{}".format(app, titre)
    if _notification_doublon(cle):
        logging.debug("doublon ignoré : %s", cle)
        return

    nom_app = app.rsplit(".", 1)[-1].replace("_", " ").title()

    cmd = [
        "notify-send",
        "--app-name", nom_app,
        "--urgency", "normal",
        "--category", "im.received",
    ]

    icone_tmp = None
    if icone_b64:
        try:
            donnees = base64.b64decode(icone_b64)
            fd, icone_tmp = tempfile.mkstemp(suffix=".png", prefix="s-android-notif-")
            os.write(fd, donnees)
            os.close(fd)
            cmd += ["--icon", icone_tmp]
        except Exception as err:
            logging.debug("décodage icône raté : %s", err)
            icone_tmp = None
    else:
        cmd += ["--icon", "phone"]

    corps_affiche = (corps[:197] + "…") if len(corps) > 200 else corps

    if titre:
        cmd += [titre, corps_affiche]
    else:
        cmd += [nom_app, corps_affiche]

    try:
        subprocess.run(cmd, check=False, timeout=3)
    except Exception as err:
        logging.debug("notify-send raté : %s", err)
    finally:
        if icone_tmp:
            try:
                os.unlink(icone_tmp)
            except OSError:
                pass


def ajouter_service():
    global boucle_courante
    try:
        gestionnaire = gbinder.ServiceManager("/dev/" + BINDER_DRIVER, "aidl3", "aidl3")
    except TypeError:
        gestionnaire = gbinder.ServiceManager("/dev/" + BINDER_DRIVER)

    def repondre(req, code, flags):
        logging.debug("%s: transaction reçue: %s", NOM_SERVICE, code)
        lecteur = req.init_reader()
        rep = reponse.new_reply()

        if code == TRANSACTION_NOTIFY:
            try:
                app       = lecteur.read_string16() or ""
                titre     = lecteur.read_string16() or ""
                corps     = lecteur.read_string16() or ""
                _         = lecteur.read_int32()
                icone_b64 = ""
                try:
                    icone_b64 = lecteur.read_string16() or ""
                except Exception:
                    pass
                threading.Thread(
                    target=_afficher, args=(app, titre, corps, icone_b64),
                    daemon=True
                ).start()
            except Exception as err:
                logging.debug("lecture notify raté : %s", err)
            rep.append_int32(0)

        elif code == TRANSACTION_CANCEL:
            try:
                app = lecteur.read_string16() or ""
                with _vus_verrou:
                    a_sup = [k for k in _vus if k.startswith(app + "|")]
                    for k in a_sup:
                        del _vus[k]
            except Exception:
                pass
            rep.append_int32(0)

        else:
            return rep, -99999

        return rep, 0

    def presence():
        if gestionnaire.is_present():
            statut = gestionnaire.add_service_sync(NOM_SERVICE, reponse)
            if statut:
                logging.error("échec add_service %s: %s", NOM_SERVICE, statut)
                boucle_courante.quit()

    reponse = gestionnaire.new_local_object(INTERFACE, repondre)
    boucle_courante = GLib.MainLoop()
    presence()
    statut = gestionnaire.add_presence_handler(presence)
    if statut:
        boucle_courante.run()
        gestionnaire.remove_handler(statut)
    else:
        logging.error("échec add_presence_handler: %s", statut)


def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s"
    )
    logging.info("S - service notifications Android démarré")
    while not arret_demande:
        ajouter_service()


if __name__ == "__main__":
    main()
