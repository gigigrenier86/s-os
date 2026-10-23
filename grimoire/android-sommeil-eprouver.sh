#!/usr/bin/bash
# GRIMOIRE — éprouver le sommeil profond d'Android sans geler le vrai conteneur
# PREUVE : la logique de détection et de minuteurs de fenetres.py.
# POUR   : toute modification de la partie « sommeil profond » de fenetres.py
#          ou de files/usr/bin/s-android-sommeil.
#
# POURQUOI PAS UN ESSAI DIRECT. Geler le conteneur Android réel arrêterait la
# session Android de l'utilisateur, et « lxc-freeze » exige root. Ce banc
# attaque la logique par en dessous : il construit un Fenetres() dépayse,
# intercepte les appels de gel/dégel/arrêt, et vérifie ce que la machine
# DÉCIDE — jamais ce que le noyau ferait.
set -uo pipefail

DEPOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$DEPOT/files/usr/lib/s"

[[ -f "$LIB/fenetres.py" ]] || { echo "ÉCHEC : $LIB/fenetres.py introuvable" >&2; exit 1; }

cd "$LIB" || exit 1
python3 - <<'PYFIN'
import os, sys, tempfile, time
sys.path.insert(0, ".")
from PySide6.QtCore import QCoreApplication
QCoreApplication([])
import fenetres

# Dépayser l'état, comme veille-eprouver-le-gel.sh : le banc ne doit pas
# écrire dans les fichiers de la vraie session.
fenetres.ETAT = tempfile.mkdtemp(prefix="s-banc-android-")
fenetres.FICHIER_VUES = os.path.join(fenetres.ETAT, "fenetres-vues.json")
fenetres.FICHIER_GELES = os.path.join(fenetres.ETAT, "fenetres-gelees.json")

rates = []

def verifier(vrai, quoi):
    if not vrai:
        rates.append(quoi)
    print("  %-58s %s" % (quoi, bool(vrai)))

# Les appels de gel/dégel/arrêt sont interceptés : le banc ne touche jamais au
# vrai conteneur.
demandes = []
arrets = []
fenetres.subprocess.run = lambda cmd, **kw: (arrets.append(cmd), None)[1]
f = fenetres.Fenetres()
f._android_demander = lambda verbe: (demandes.append(verbe), True)[1]

def fen(id_, classe, active=False, reduite=False):
    return {"id": id_, "classe": classe, "titre": "x", "active": active,
            "reduite": reduite, "pid": 0, "montrable": True}

print("LA DÉTECTION")
# Une fenêtre waydroid.* non réduite est « visible » ; une native non.
f._toutes = [fen("a", "org.kde.konsole")]
verifier(not f._android_visible(), "une fenêtre native n'est pas Android")
f._toutes = [fen("b", "waydroid.ca.koho", active=True)]
verifier(f._android_visible(), "une fenêtre waydroid.* active est visible")
f._toutes = [fen("b", "waydroid.ca.koho", reduite=True)]
verifier(not f._android_visible(), "une fenêtre waydroid.* réduite n'est pas visible")

print("LES MINUTEURS")
# Jamais vu Android -> rien ne part.
f._android_vu = 0.0
f._toutes = [fen("a", "org.kde.konsole")]
f._android_suivre()
verifier(not f._android_sommeil.isActive() and not f._android_arret.isActive(),
         "Android jamais vu -> minuteurs muets")

# Vu, puis plus visible -> les deux minuteurs partent.
f._toutes = [fen("b", "waydroid.ca.koho", active=True)]
f._android_suivre()
vu = f._android_vu
verifier(vu > 0, "fenêtre Android visible -> horodatée")
f._toutes = []
f._android_suivre()
verifier(f._android_vu == vu, "plus de fenêtre -> l'horodatage est conservé")
verifier(f._android_sommeil.isActive() and f._android_arret.isActive(),
         "plus de fenêtre -> les deux minuteurs partent")

# De retour -> minuteurs stoppés, dégel demandé.
demandes.clear()
f._android_gel = True
f._toutes = [fen("b", "waydroid.ca.koho", active=True)]
f._android_suivre()
verifier(not f._android_sommeil.isActive() and not f._android_arret.isActive(),
         "fenêtre visible -> minuteurs stoppés")
verifier("degeler" in demandes and not f._android_gel,
         "fenêtre visible -> dégel demandé")

print("GELER / DÉGELER / ARRÊTER")
demandes.clear()
f._android_gel = False
f._android_geler()
f._android_geler()
verifier(demandes == ["geler"] and f._android_gel,
         "geler demandé une seule fois (idempotent)")
demandes.clear()
f._android_reveiller()
f._android_reveiller()
verifier(demandes == ["degeler"] and not f._android_gel,
         "dégeler demandé une seule fois (idempotent)")

demandes.clear()
arrets.clear()
f._android_gel = True
f._android_arreter()
verifier("degeler" in demandes, "arrêt long -> dégel d'abord")
verifier(any("stop" in a for a in arrets) and not f._android_gel,
         "arrêt long -> systemctl stop demandé")

print()
if rates:
    print("ÉCHEC : %d contrôle(s) — %s" % (len(rates), " ; ".join(rates)),
          file=sys.stderr)
    raise SystemExit(1)
print("TOUT PASSE")
PYFIN
