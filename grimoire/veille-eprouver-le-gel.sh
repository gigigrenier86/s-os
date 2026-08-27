#!/usr/bin/bash
# GRIMOIRE — éprouver la veille des fenêtres sans toucher à la session
# PREUVE : 2026-08-26, sur S. Onze contrôles passés, dont les cinq garde-fous
#          (s-constellation, kwin_wayland, plasmashell, Xwayland, wineserver
#          refusent tous le gel) et le rattrapage après plantage. Coût : deux
#          secondes. A trouvé deux défauts réels avant qu'ils entrent dans
#          l'image — voir plus bas.
# POUR   : toute modification de files/usr/lib/s/veille.py ou de la partie
#          « veille » de files/usr/lib/s/fenetres.py.
#
# POURQUOI CE BANC EXISTE PLUTÔT QU'UN ESSAI À L'ÉCRAN
#
# Constellation est relancé en boucle par s-coquille (« while true » avec un
# témoin de sortie). On ne peut donc pas l'arrêter pour lui substituer une
# version du dépôt : la coquille rouvre aussitôt celle de l'image, et les deux
# se disputent le nom D-Bus « org.s.Constellation ». Éprouver la veille en
# direct veut dire redémarrer la session de l'utilisateur — inacceptable quand
# il travaille, et impossible à distance.
#
# Ce banc contourne le problème en attaquant la logique par en dessous : il
# fabrique une PORTÉE JETABLE avec systemd-run, invente une liste de fenêtres
# qui la désigne, et vérifie ce que le noyau fait vraiment. Aucune fenêtre de
# l'utilisateur n'est touchée.
#
# LE PIÈGE DU NOM DE LA PORTÉE, TROUVÉ ICI
#
# La première version du banc créait « s-banc-veille.scope » et s'étonnait que
# rien ne gèle. C'était le garde-fou qui faisait son travail : veille.py ne
# gèle QUE les portées « app-*.scope » (voir son en-tête). Un banc dont l'unité
# ne porte pas ce préfixe mesure le refus, pas le gel.
#
# LE PIÈGE DES DEUX FICHIERS, TROUVÉ ICI AUSSI ET PLUS COÛTEUX
#
# « cgroup.freeze » est la DEMANDE et vaut 1 dès l'écriture rendue.
# « cgroup.events » est l'ÉTAT et retarde d'une fraction de milliseconde.
# Le banc lisait l'état juste après la demande et rendait « ça n'a pas marché »
# sur un gel parfaitement appliqué. D'où la petite attente de « etat() ».
set -uo pipefail

DEPOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$DEPOT/files/usr/lib/s"
UNITE=app-s-banc-veille

[[ -f "$LIB/veille.py" ]] || { echo "ÉCHEC : $LIB/veille.py introuvable" >&2; exit 1; }

nettoyer() { systemctl --user stop "$UNITE.scope" >/dev/null 2>&1 || true; }
trap nettoyer EXIT

nettoyer
systemd-run --user --scope --unit="$UNITE" -q -- sleep 400 &
sleep 1.5

cd "$LIB" || exit 1
python3 - "$UNITE" <<'PYFIN'
import os, sys, time
sys.path.insert(0, ".")
from PySide6.QtCore import QCoreApplication
QCoreApplication([])
import veille, fenetres

unite = sys.argv[1]
C = os.path.join(veille.app_slice() or "", unite + ".scope")
if not os.path.isdir(C):
    print("ÉCHEC : la portée jetable %s n'existe pas" % C, file=sys.stderr)
    raise SystemExit(1)
pid = int(open(os.path.join(C, "cgroup.procs")).read().split()[0])
if veille.portee(pid) != C:
    print("ÉCHEC : veille.portee() ne reconnaît pas la portée du banc",
          file=sys.stderr)
    raise SystemExit(1)
print("banc            : pid=%d, portée reconnue" % pid)

rates = []

def etat(attendu, quoi):
    # On laisse au noyau le temps d'ATTEINDRE l'état : voir le second piège de
    # l'en-tête de veille.py. Sans cette attente le banc rend faux sur un gel
    # qui fonctionne.
    t0 = time.time()
    while time.time() - t0 < 1.0 and veille.gelee(C) != attendu:
        time.sleep(0.002)
    obtenu = veille.gelee(C)
    if obtenu != attendu:
        rates.append(quoi)
    print("  %-52s %-5s (attendu %s)" % (quoi, obtenu, attendu))

A = "{aaaaaaaa-0000-0000-0000-000000000001}"
B = "{bbbbbbbb-0000-0000-0000-000000000002}"
f = fenetres.Fenetres()
f._liste = [
    {"id": A, "titre": "Le banc", "active": False, "reduite": True, "pid": pid},
    {"id": B, "titre": "Sans pid", "active": True, "reduite": False, "pid": 0},
]

print("\nLA VEILLE")
f._geler({A});   etat(True,  "fenêtre rangée -> endormie")
f._reveiller(A); etat(False, "on la remonte -> réveillée")

# Deux fenêtres du même programme : geler la rangée arrêterait celle qu'on
# regarde. C'est le cas que deux Konsole produisent tous les jours.
f._liste[1]["pid"] = pid
f._geler({A});   etat(False, "portée partagée avec l'active -> intacte")
f._liste[1]["pid"] = 0

f._liste[0]["reduite"] = False
f._geler({A});   etat(False, "fenêtre remontée entre-temps -> intacte")
f._liste[0]["reduite"] = True

f._mode = "reduire"
f._geler({A});   etat(False, "mode « reduire » -> ne gèle rien")
f._mode = "geler"

f._geler({A});   etat(True,  "ré-endormie")
f.arreter();     etat(False, "arrêt de Constellation -> tout relâché")

print("\nLE RATTRAPAGE APRÈS PLANTAGE")
veille.geler(C)
if C not in veille.portees_gelees():
    rates.append("le balayage ne retrouve pas la portée gelée")
    print("  %-52s %s" % ("une portée gelée est retrouvée au démarrage", False))
else:
    print("  %-52s %s" % ("une portée gelée est retrouvée au démarrage", True))
fenetres.Fenetres()          # ce que fait un démarrage de Constellation
etat(False, "un nouveau Constellation la relâche")

print("\nLES DIX JOURS")
f._noter(f._liste)
for seuil, attendu, quoi in ((10, 0, "vues à l'instant, seuil 10 j"),):
    obtenu = f.inactivesDepuis(seuil)
    if obtenu != attendu:
        rates.append(quoi)
    print("  %-52s %d (attendu %d)" % (quoi, obtenu, attendu))
f._vues[A]["actif"] = time.time() - 11 * 86400
f._vues[B]["actif"] = time.time() - 3 * 86400
for seuil, attendu, quoi in ((10, 1, "une à 11 jours, l'autre à 3, seuil 10 j"),
                             (2,  2, "même état, seuil 2 j")):
    obtenu = f.inactivesDepuis(seuil)
    if obtenu != attendu:
        rates.append(quoi)
    print("  %-52s %d (attendu %d)" % (quoi, obtenu, attendu))
f._liste = [f._liste[0]]
f._noter(f._liste)
oublie = B not in f._vues
if not oublie:
    rates.append("une fenêtre fermée n'est pas oubliée")
print("  %-52s %s" % ("une fenêtre fermée est oubliée", oublie))

print("\nLES GARDE-FOUS")
# CE BLOC EST LE PLUS IMPORTANT DU BANC. Geler le compositeur figerait l'écran
# entier sans que rien puisse le dégeler, puisque le dégel viendrait d'un clic.
import subprocess
for nom in ("s-constellation", "kwin_wayland", "plasmashell", "Xwayland",
            "wineserver"):
    r = subprocess.run(["pgrep", "-f", nom], capture_output=True, text=True)
    if not r.stdout.strip():
        print("  %-52s (absent)" % ("« %s »" % nom))
        continue
    p = int(r.stdout.split()[0])
    sur = veille.portee(p) is None
    if not sur:
        rates.append("« %s » PEUT être gelé" % nom)
    print("  %-52s %s" % ("« %s » ne peut pas être gelé" % nom, sur))

print()
if rates:
    print("ÉCHEC : %d contrôle(s) — %s" % (len(rates), " ; ".join(rates)),
          file=sys.stderr)
    raise SystemExit(1)
print("TOUT PASSE")
PYFIN
