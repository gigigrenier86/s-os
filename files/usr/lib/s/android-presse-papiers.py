#!/usr/bin/python3
# S - le pont presse-papiers Linux <-> Android, sans l'outillage Waydroid.
#
# Repris de /usr/lib/waydroid/tools/interfaces/IClipboard.py et
# tools/services/clipboard_manager.py, traduit tel quel : ce pont n'a jamais
# ete "dans" le paquet waydroid au sens ou s-android en dependait -- c'est un
# service binder cote HOTE, ecrit avec gbinder (paquet Fedora
# python3-gbinder, independant) et pyclip (python3-pyclip, independant aussi).
# Le code cote Android qui appelle ce service (interface
# "lineageos.waydroid.IClipboard") vit DANS system.img, pas dans le paquet
# Python -- il est deja present, on ne le touche pas.
#
# /dev/binder est le meme peripherique cote hote et cote conteneur (bind-mount
# direct dans android-lancer.sh), donc un service enregistre ici, sur le
# binder de l'hote, est visible par le code Android qui tourne dans le
# conteneur. Aucun rapport avec lxc-start ni avec le domaine SELinux
# s_android_t : ce script n'a besoin d'aucun privilege particulier, juste de
# lire/ecrire /dev/binder (crw-rw-rw-) et le presse-papiers Wayland de la
# session en cours.
import logging
import sys
import threading
import time

import gbinder
from gi.repository import GLib

try:
    import pyclip
    PEUT_COPIER = True
except Exception as err:
    logging.debug(str(err))
    PEUT_COPIER = False

INTERFACE = "lineageos.waydroid.IClipboard"
NOM_SERVICE = "waydroidclipboard"
BINDER_DRIVER = "binder"

TRANSACTION_ENVOYER = 1
TRANSACTION_LIRE = 2

arret_demande = False
boucle_courante = None
echec_signale = False
DELAI_REPRISE = 1


def ajouter_service():
    global boucle_courante, echec_signale
    try:
        gestionnaire = gbinder.ServiceManager("/dev/" + BINDER_DRIVER, "aidl3", "aidl3")
    except TypeError:
        gestionnaire = gbinder.ServiceManager("/dev/" + BINDER_DRIVER)

    def repondre(req, code, flags):
        logging.debug("%s: transaction recue: %s", NOM_SERVICE, code)
        lecteur = req.init_reader()
        reponse_locale = reponse.new_reply()
        if code == TRANSACTION_ENVOYER:
            valeur = lecteur.read_string16()
            if PEUT_COPIER:
                try:
                    pyclip.copy(valeur)
                except Exception as err:
                    logging.debug(str(err))
            reponse_locale.append_int32(0)
        elif code == TRANSACTION_LIRE:
            texte = ""
            if PEUT_COPIER:
                try:
                    texte = pyclip.paste()
                except Exception as err:
                    logging.debug(str(err))
            reponse_locale.append_int32(0)
            reponse_locale.append_string16(texte)
        else:
            return reponse_locale, -99999
        return reponse_locale, 0

    def presence():
        if gestionnaire.is_present():
            statut = gestionnaire.add_service_sync(NOM_SERVICE, reponse)
            if statut:
                logging.error("echec add_service %s: %s", NOM_SERVICE, statut)
                boucle_courante.quit()

    reponse = gestionnaire.new_local_object(INTERFACE, repondre)
    boucle_courante = GLib.MainLoop()
    presence()
    statut = gestionnaire.add_presence_handler(presence)
    if statut:
        echec_signale = False
        boucle_courante.run()
        gestionnaire.remove_handler(statut)
    else:
        # /dev/binder n'existe pas encore (binderfs ne se monte qu'avec
        # s-android.service) : sans cette pause, main() rappelle aussitot
        # cette fonction et la boucle tourne a plein processeur, sans fin sur
        # une machine ou Android ne demarre jamais. Le premier echec seul est
        # journalise.
        if not echec_signale:
            logging.error("echec add_presence_handler: %s -- nouvel essai chaque seconde", statut)
            echec_signale = True
        time.sleep(DELAI_REPRISE)


def main():
    logging.basicConfig(level=logging.INFO)
    if not PEUT_COPIER:
        logging.warning("pyclip indisponible -- presse-papiers Android inerte.")
        sys.exit(0)
    while not arret_demande:
        ajouter_service()


if __name__ == "__main__":
    main()
