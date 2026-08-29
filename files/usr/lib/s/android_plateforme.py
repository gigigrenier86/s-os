#!/usr/bin/python3
# S - parler a Android depuis l'hote, sans root et sans l'outillage Waydroid.
#
# LA PERLE, MESUREE LE 2026-08-29. Le service binder « waydroidplatform »
# (interface « lineageos.waydroid.IPlatform ») vit DANS system.img — c'est
# le code Java que TOUT le Python de Waydroid appelait pour lancer, lister,
# installer et regler — et il repond depuis l'hote, dans la session
# utilisateur, sans aucun privilege : /dev/binder est en crw-rw-rw- et c'est
# le meme peripherique des deux cotes (bind direct dans android-lancer.sh).
# Exactement le mecanisme d'android-presse-papiers.py, dans l'autre sens.
#
#   sm.list_sync()                   -> [..., 'waydroidclipboard', 'waydroidplatform', ...]
#   getprop("sys.boot_completed")    -> '1'
#   getAppsInfo()                    -> 20 applications, nom + paquet + categories
#
# CE QUE CA CHANGE : plus AUCUN pkexec pour lancer une application, en
# installer une, lire ou poser une propriete vivante, regler la veille. Le
# seul privilege qui reste dans le monde Android est « systemctl start/stop
# s-android.service », et une regle polkit (50-s-android.rules) le rend sans
# mot de passe. « lxc-attach » (s_android_dans) ne sert plus qu'a ce qui est
# vraiment root — lire une base sqlite d'Android, par exemple.
#
# LE PROTOCOLE EST CELUI DE L'AMONT, tools/interfaces/IPlatform.py, traduit
# tel quel (numeros de transaction, ordre des champs du parcel). Deux pieges
# de CE gbinder (python3-gbinder 1.3.0), tous deux mesures :
#
#   1. read_int32() rend un TUPLE (statut, valeur) — « (True, 20) » — pas un
#      entier. L'amont le deballe pareil (« status, apps = reader.read_int32() »).
#      read_string16() rend la chaine directement.
#   2. Lire une chaine la ou le parcel n'en porte pas SEGFAUTE le processus
#      entier (deux fois sur le banc, en lisant un resultat apres une
#      exception Android non verifiee). D'ou la garde systematique : on ne
#      lit la suite d'une reponse QUE si l'exception vaut 0.
#
# Ce module ne fait rien en s'important : ni connexion, ni ecriture.
import os
import subprocess
import time

import gbinder

INTERFACE = "lineageos.waydroid.IPlatform"
NOM_SERVICE = "waydroidplatform"
BINDER = "/dev/binder"

TRANSACTION_getprop = 1
TRANSACTION_setprop = 2
TRANSACTION_getAppsInfo = 3
TRANSACTION_getAppInfo = 4
TRANSACTION_installApp = 5
TRANSACTION_removeApp = 6
TRANSACTION_launchApp = 7
TRANSACTION_getAppName = 8
TRANSACTION_settingsPutString = 9
TRANSACTION_settingsGetString = 10
TRANSACTION_settingsPutInt = 11
TRANSACTION_settingsGetInt = 12
TRANSACTION_launchIntent = 13

# Les espaces de noms de Settings, tels que le service Java les numerote.
# MESURES LE 2026-08-29 avec settingsGetInt sur les trois : « screen_off_
# timeout » (un reglage System) ne repond que dans l'espace 1 (60000, la
# valeur a neuf) et -1 dans 0 et 2 ; l'amont ecrit « policy_control » (un
# reglage Global) dans l'espace 2. Reste 0 pour Secure.
# settingsGetString sur une cle ABSENTE segfaute (chaine nulle dans le
# parcel) : ne lire en chaine que ce qu'on sait present.
SETTINGS_SECURE = 0
SETTINGS_SYSTEM = 1
SETTINGS_GLOBAL = 2

SERVICE_SYSTEMD = "s-android.service"
CATEGORIE_LANCEUR = "android.intent.category.LAUNCHER"

# Le dossier de donnees d'Android, vu de l'hote (android-lancer.sh le
# bind-monte sur /data). Il appartient a l'utilisateur (drwxrwx--x RyuRex),
# ce qui est ce qui permet d'y deposer un APK a installer et d'y lire les
# icones qu'Android ecrit lui-meme dans data/icons/<paquet>.png.
DOSSIER_DONNEES = os.path.join(
    os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"),
    "waydroid", "data")
DOSSIER_ICONES = os.path.join(DOSSIER_DONNEES, "icons")
IMAGE_SYSTEME = "/var/lib/waydroid/images/system.img"


def _valeur(lu):
    """read_int32 rend (statut, valeur) ici — voir l'en-tete."""
    if isinstance(lu, tuple):
        return lu[-1]
    return lu


class ErreurAndroid(Exception):
    pass


def gestionnaire():
    try:
        return gbinder.ServiceManager(BINDER, "aidl3", "aidl3")
    except TypeError:
        return gbinder.ServiceManager(BINDER)


class Plateforme:
    def __init__(self, remote):
        self.client = gbinder.Client(remote, INTERFACE)

    # --- le socle : une transaction, une reponse verifiee --------------------
    def _appel(self, code, *args):
        """Envoie args (str -> string16, int -> int32) ; rend le lecteur
        positionne APRES l'exception, ou leve ErreurAndroid."""
        req = self.client.new_request()
        for a in args:
            if isinstance(a, bool):
                req.append_int32(1 if a else 0)
            elif isinstance(a, int):
                req.append_int32(a)
            else:
                req.append_string16("" if a is None else str(a))
        rep, statut = self.client.transact_sync_reply(code, req)
        if statut or rep is None:
            raise ErreurAndroid("transaction %d : envoi refuse (%s)" % (code, statut))
        lecteur = rep.init_reader()
        exception = _valeur(lecteur.read_int32())
        if exception != 0:
            # NE PAS lire plus loin : c'est le segfault de l'en-tete.
            raise ErreurAndroid("transaction %d : exception Android %s" % (code, exception))
        return lecteur

    # --- les methodes de l'amont, une par transaction ------------------------
    def getprop(self, cle, defaut=""):
        return self._appel(TRANSACTION_getprop, cle, defaut).read_string16()

    def setprop(self, cle, valeur):
        self._appel(TRANSACTION_setprop, cle, valeur)

    def _lire_app(self, lecteur):
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
        return app

    def getAppsInfo(self):
        lecteur = self._appel(TRANSACTION_getAppsInfo)
        apps = []
        for _ in range(_valeur(lecteur.read_int32())):
            if _valeur(lecteur.read_int32()) == 1:
                apps.append(self._lire_app(lecteur))
        return apps

    def getAppInfo(self, paquet):
        lecteur = self._appel(TRANSACTION_getAppInfo, paquet)
        if _valeur(lecteur.read_int32()) == 1:
            return self._lire_app(lecteur)
        return None

    def installApp(self, chemin_android):
        return _valeur(self._appel(TRANSACTION_installApp, chemin_android).read_int32())

    def removeApp(self, paquet):
        return _valeur(self._appel(TRANSACTION_removeApp, paquet).read_int32())

    def launchApp(self, paquet):
        self._appel(TRANSACTION_launchApp, paquet)

    def getAppName(self, paquet):
        return self._appel(TRANSACTION_getAppName, paquet).read_string16()

    def settingsPutString(self, espace, cle, valeur):
        self._appel(TRANSACTION_settingsPutString, espace, cle, valeur)

    def settingsGetString(self, espace, cle):
        return self._appel(TRANSACTION_settingsGetString, espace, cle).read_string16()

    def settingsPutInt(self, espace, cle, valeur):
        self._appel(TRANSACTION_settingsPutInt, espace, cle, int(valeur))

    def settingsGetInt(self, espace, cle):
        return _valeur(self._appel(TRANSACTION_settingsGetInt, espace, cle).read_int32())

    def launchIntent(self, action, uri):
        return self._appel(TRANSACTION_launchIntent, action, uri).read_string16()

    # --- ce que S en fait ----------------------------------------------------
    def applications_lancables(self):
        """Les applications qui ont une icone de lanceur, comme l'amont les
        filtrait avant d'ecrire un .desktop."""
        return [a for a in self.getAppsInfo()
                if any(c.strip() == CATEGORIE_LANCEUR for c in a["categories"])]

    def pret(self):
        try:
            return self.getprop("sys.boot_completed", "0").strip() == "1"
        except ErreurAndroid:
            return False


# --- se connecter, en attendant ce qu'il faut attendre -----------------------

def obtenir(delai=0.0):
    """La plateforme, ou None si elle n'a pas repondu dans « delai » secondes.

    Trois attentes successives, chacune bornee par le meme delai global :
    le gestionnaire de services binder (« servicemanager » d'Android, qui
    n'existe que conteneur en marche), puis le service waydroidplatform
    (system_server, quelques secondes apres), puis sys.boot_completed —
    « RUNNING » cote lxc veut dire « /init a demarre », pas « Android repond »
    (la course mesuree le 2026-08-29 : pm list 3 s apres /init, « Can't
    find service: package »). Aucun privilege sur tout ce chemin."""
    fin = time.monotonic() + delai
    sm = gestionnaire()
    while True:
        if sm.is_present():
            remote, _statut = sm.get_service_sync(NOM_SERVICE)
            if remote:
                plateforme = Plateforme(remote)
                while True:
                    if plateforme.pret():
                        return plateforme
                    if time.monotonic() >= fin:
                        return None
                    time.sleep(1)
        if time.monotonic() >= fin:
            return None
        time.sleep(1)


# --- le service systemd : l'unique privilege qui reste ----------------------

def service_actif():
    return subprocess.run(["systemctl", "is-active", "--quiet", SERVICE_SYSTEMD],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def images_presentes():
    return os.path.isfile(IMAGE_SYSTEME)


def service_commander(verbe, delai=60):
    """start / stop / restart, SANS mot de passe grace a 50-s-android.rules
    (polkit autorise ces trois verbes sur cette seule unite pour un membre
    actif de wheel). Repli sur pkexec si la regle manque — la machine qui
    n'a pas encore l'image demandera alors un mot de passe, comme avant,
    plutot que d'echouer en silence."""
    for commande in (["systemctl", verbe, SERVICE_SYSTEMD],
                     ["pkexec", "systemctl", verbe, SERVICE_SYSTEMD]):
        try:
            r = subprocess.run(commande, stdout=subprocess.DEVNULL,
                               stderr=subprocess.PIPE, timeout=delai)
        except (OSError, subprocess.TimeoutExpired):
            continue
        if r.returncode == 0:
            return True
    return False
