#!/usr/bin/python3
# GRIMOIRE — parler a un Waydroid/Android EN MARCHE depuis l'hote, SANS root
#           et sans une ligne de l'outillage Python de Waydroid.
# PREUVE : 2026-08-29, sur `s`. Depuis une session utilisateur normale
#              (unconfined_u:unconfined_r:unconfined_t, pas de sudo) :
#                  sm.list_sync()                 -> [..., 'waydroidplatform', ...]
#                  getprop("sys.boot_completed")  -> '1'
#                  getAppsInfo()                  -> 19 applications lancables,
#                                                     nom + paquet + categories
#                  installApp(...)                -> reinstallation de F-Droid
#                                                     reelle, code 0, 100 ms
#                  launchApp("org.fdroid.fdroid") -> fenetre kwin
#                                                     « waydroid.org.fdroid.fdroid »,
#                                                     capture a l'appui
#              Employe pour de vrai dans S depuis cette date : voir
#              files/usr/lib/s/android_plateforme.py (version complete,
#              settings compris) et files/usr/bin/s-android-lancer.
# POUR    : toute couture qui doit lancer, installer, lister ou retirer une
#           application Android SANS demander de mot de passe. Remplace
#           entierement le besoin de lxc-attach pour ces quatre gestes —
#           voir android-piloter-sans-waydroid.sh (ce meme dossier) pour ce
#           qui reste VRAIMENT root (lire une base sqlite dans /data, par
#           exemple : s-play-store).
#
# LA PERLE. Le service binder « waydroidplatform » (interface
# « lineageos.waydroid.IPlatform ») est le code Java QUE TOUT L'OUTILLAGE
# PYTHON DE WAYDROID APPELAIT deja pour lancer/installer/lister — il vit
# DANS system.img, pas dans le paquet retire, et il repond depuis l'hote
# sans aucun privilege : /dev/binder est crw-rw-rw-, meme peripherique des
# deux cotes du bind-mount que fait android-lancer.sh. Chercher AVANT de
# forger a economise ici tout un pan de lxc-attach/pkexec.
#
# DEUX PIEGES DE CE gbinder (python3-gbinder 1.3.0), TOUS DEUX MESURES :
#
# 1. read_int32() REND UN TUPLE (statut, valeur) — « (True, 20) », pas un
#    entier nu. L'amont le deballe pareil (« status, apps =
#    reader.read_int32() ») ; s'y fier directement comme a un entier casse
#    silencieusement toute comparaison qui suit.
#
# 2. LIRE UNE CHAINE LA OU LE PARCEL N'EN PORTE PAS SEGFAUTE LE PROCESSUS
#    ENTIER — mesure deux fois sur ce banc, en lisant la suite d'une reponse
#    apres une exception Android jamais verifiee (settingsGetString/GetInt
#    sur un espace de noms errone, par exemple). LA GARDE EST OBLIGATOIRE :
#    ne jamais lire au-dela de l'int32 d'exception sans avoir teste
#    qu'il vaut 0.
#
# LE PROTOCOLE EST CELUI DE L'AMONT (tools/interfaces/IPlatform.py),
# traduit a l'identique — numeros de transaction et ordre des champs.

import gbinder

INTERFACE = "lineageos.waydroid.IPlatform"
NOM_SERVICE = "waydroidplatform"

TRANSACTION_getprop = 1
TRANSACTION_setprop = 2
TRANSACTION_getAppsInfo = 3
TRANSACTION_installApp = 5
TRANSACTION_launchApp = 7


def _valeur(lu):
    """Piege 1 : read_int32() rend (statut, valeur) sur ce gbinder."""
    return lu[-1] if isinstance(lu, tuple) else lu


def se_connecter():
    """Le gestionnaire de services, puis le client sur waydroidplatform.
    Rend None si Android ne tourne pas (ou pas encore assez loin dans son
    demarrage pour que system_server ait enregistre le service)."""
    try:
        sm = gbinder.ServiceManager("/dev/binder", "aidl3", "aidl3")
    except TypeError:
        sm = gbinder.ServiceManager("/dev/binder")
    if not sm.is_present():
        return None
    remote, _statut = sm.get_service_sync(NOM_SERVICE)
    if not remote:
        return None
    return gbinder.Client(remote, INTERFACE)


def getprop(client, cle, defaut=""):
    req = client.new_request()
    req.append_string16(cle)
    req.append_string16(defaut)
    rep, statut = client.transact_sync_reply(TRANSACTION_getprop, req)
    if statut or rep is None:
        return defaut
    lecteur = rep.init_reader()
    if _valeur(lecteur.read_int32()) != 0:      # PIEGE 2 : garder avant de lire
        return defaut
    return lecteur.read_string16()


def setprop(client, cle, valeur):
    req = client.new_request()
    req.append_string16(cle)
    req.append_string16(valeur)
    client.transact_sync_reply(TRANSACTION_setprop, req)


def applications(client):
    """Nom, paquet et categories de chaque application connue d'Android."""
    req = client.new_request()
    rep, statut = client.transact_sync_reply(TRANSACTION_getAppsInfo, req)
    if statut or rep is None:
        return []
    lecteur = rep.init_reader()
    if _valeur(lecteur.read_int32()) != 0:
        return []
    apps = []
    for _ in range(_valeur(lecteur.read_int32())):
        if _valeur(lecteur.read_int32()) != 1:   # « has_value »
            continue
        app = {
            "name": lecteur.read_string16(),
            "packageName": lecteur.read_string16(),
            "action": lecteur.read_string16(),
            "launchIntent": lecteur.read_string16(),
            "componentPackageName": lecteur.read_string16(),
            "componentClassName": lecteur.read_string16(),
            "categories": [],
        }
        for _ in range(_valeur(lecteur.read_int32())):
            app["categories"].append(lecteur.read_string16())
        apps.append(app)
    return apps


def lancer(client, paquet):
    """L'equivalent de « waydroid app launch » — SANS jamais poser
    « waydroid.active_apps = Waydroid » (la fenetre complete d'Android,
    lanceur et barre d'etat : c'est la SEULE facon dont elle apparait)."""
    setprop(client, "waydroid.active_apps", paquet)
    req = client.new_request()
    req.append_string16(paquet)
    client.transact_sync_reply(TRANSACTION_launchApp, req)


def installer(client, chemin_dans_android):
    """L'equivalent de « waydroid app install ». Prend un chemin DEJA VU
    par le conteneur (ex. /data/waydroid_tmp/base.apk, si le dossier de
    donnees hote est bind-monte sur /data) — pas un chemin de l'hote."""
    req = client.new_request()
    req.append_string16(chemin_dans_android)
    rep, statut = client.transact_sync_reply(TRANSACTION_installApp, req)
    if statut or rep is None:
        return None
    lecteur = rep.init_reader()
    if _valeur(lecteur.read_int32()) != 0:
        return None
    return _valeur(lecteur.read_int32())


if __name__ == "__main__":
    c = se_connecter()
    if c is None:
        print("Android ne repond pas.")
    else:
        print("boot_completed =", getprop(c, "sys.boot_completed"))
        for a in applications(c)[:5]:
            print(" ", a["packageName"], "-", a["name"])
