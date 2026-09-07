#!/usr/bin/bash
# GRIMOIRE — éprouver en direct les deux régressions corrigées le 2026-09-05
# dans fenetres.js (le chrome de S qui gardait l'activation à chaque clic, et
# le rattrapage qui empêchait de ranger la fenêtre déjà active) — contre le
# vrai script résident, jamais une simulation.
# PREUVE : 2026-09-06, sur S, contre le dépôt à HEAD (8a5431e). Rechargé à
#          chaud, les deux scénarios passent : SCENARIO-A rattrape=true,
#          SCENARIO-B minimisee=true pas_reactivee=true. Coût : ~6 secondes,
#          deux fenêtres Qt jetables, aucune fenêtre de l'utilisateur touchée.
# POUR   : toute modification de la logique windowActivated / estChromeS /
#          estBarreOuLaterale de files/usr/lib/s/fenetres.js. Recharger ce
#          fichier depuis le dépôt puis relancer ce banc avant de pousser.
#
# POURQUOI UNE VRAIE FENÊTRE PLUTÔT QU'UNE SIMULATION
#
# fenetres.js tourne DANS kwin comme script résident (chargé par
# s-coquille sous le nom "s-fenetres") ; on ne peut ni l'appeler de
# l'extérieur ni lui injecter un faux événement. La seule façon de
# l'exercer pour de vrai est de créer un VRAI client Wayland dont le titre
# et le resourceClass imitent la barre de S (Qt setDesktopFileName suivi
# d'un titre "S - barre"), puis de regarder si le gestionnaire
# windowActivated du script résident réagit comme prévu — exactement le
# patron D-Bus déjà établi par grimoire/kwin-capturer-la-coquille.sh.
#
# LE PIÈGE DE LA VRAIE BARRE, TROUVÉ EN CONSTRUISANT CE BANC
#
# Sur une machine qui fait tourner Constellation, la VRAIE barre des tâches
# porte EXACTEMENT le même titre et la même classe que la fenêtre jetable de
# ce banc — les deux se retrouvent listées côte à côte sous "S - barre",
# indistinguables par titre ou par resourceClass. Seul l'internalId les
# sépare, et celui de la vraie barre est stable d'un essai à l'autre tandis
# que celui du banc est neuf à chaque lancement. Le banc relève donc les
# internalId de toutes les fenêtres "S - barre" AVANT de poser la sienne, et
# cherche ensuite celle qui N'EST PAS dans cette liste — jamais l'inverse,
# qui daterait mal le jour où deux vraies barres existeraient (deux écrans).
#
# LE PIÈGE DU TÉMOIN D-BUS, DÉJÀ CONNU MAIS REDÉCOUVERT ICI
#
# dbus-monitor doit démarrer AVANT tout script kwin et porter
# "eavesdrop=true" — sans lui, rien n'est capté même si l'appel part
# réellement. Et lire le fichier de sortie moins d'une seconde après un
# unloadScript peut le trouver vide : dbus-monitor bufferise, il faut un
# délai après la décharge, pas seulement après le démarrage.
#
# LE PIÈGE DU PROCESSUS QUI SE TUE LUI-MÊME
#
# Un `pkill -f`/`pgrep -f` dont le motif de recherche apparaît dans SA
# PROPRE ligne de commande se fauche lui-même (et peut faucher des tâches
# voisines au passage) — payé plusieurs fois sur ce projet. Ce banc ne tue
# jamais par motif : il garde chaque PID lancé et le tue par exact ce PID.
set -uo pipefail

DEPOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FENETRES_JS="$DEPOT/files/usr/lib/s/fenetres.js"

[[ -f "$FENETRES_JS" ]] || { echo "ÉCHEC : $FENETRES_JS introuvable" >&2; exit 1; }
command -v busctl >/dev/null || { echo "ÉCHEC : busctl introuvable" >&2; exit 1; }

TRAVAIL="$(mktemp -d)"
PID_A=""
PID_CHROME=""
PID_MONITEUR=""

nettoyer() {
    [[ -n "$PID_A" ]] && kill "$PID_A" 2>/dev/null
    [[ -n "$PID_CHROME" ]] && kill "$PID_CHROME" 2>/dev/null
    [[ -n "$PID_MONITEUR" ]] && kill "$PID_MONITEUR" 2>/dev/null
    busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
        unloadScript s "banc-fenetres-relever" >/dev/null 2>&1
    busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
        unloadScript s "banc-fenetres-eprouver" >/dev/null 2>&1
    rm -rf "$TRAVAIL"
}
trap nettoyer EXIT

# --- le client Wayland jetable, réutilisé pour les deux fenêtres ---
cat > "$TRAVAIL/temoin-fenetre.py" <<'PY'
import sys
from PySide6.QtWidgets import QApplication, QLabel
titre = sys.argv[1]
app_id = sys.argv[2]
app = QApplication(sys.argv[:1])
app.setDesktopFileName(app_id)
w = QLabel(titre)
w.setWindowTitle(titre)
w.resize(400, 300)
w.show()
sys.exit(app.exec())
PY

# --- le témoin D-Bus, lancé avant tout le reste ---
: > "$TRAVAIL/temoin.log"
dbus-monitor --session "eavesdrop=true,interface='org.s.temoin'" \
    > "$TRAVAIL/temoin.log" 2>&1 &
PID_MONITEUR=$!
sleep 0.5

lire_evenements() {
    grep -a "member=evenement" -A1 "$TRAVAIL/temoin.log" \
        | sed -n 's/^[[:space:]]*string "\(.*\)"$/\1/p'
}

# --- recharger fenetres.js à chaud depuis le dépôt : on éprouve ce qui est
#     écrit là, pas ce qui traînait déjà en mémoire ---
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
    unloadScript s "s-fenetres" >/dev/null 2>&1
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
    loadScript ss "$FENETRES_JS" "s-fenetres" >/dev/null
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting start >/dev/null
sleep 0.5

# --- relever les vraies barres AVANT de poser la nôtre ---
cat > "$TRAVAIL/relever.js" <<'JS'
var l = workspace.windowList();
var ids = [];
for (var i = 0; i < l.length; i++) {
    if (String(l[i].caption) === "S - barre") ids.push(String(l[i].internalId));
}
callDBus("org.s.temoin", "/temoin", "org.s.temoin", "evenement", "AVANT:" + ids.join(","));
JS
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
    loadScript ss "$TRAVAIL/relever.js" "banc-fenetres-relever" >/dev/null
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting start >/dev/null
sleep 0.5
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
    unloadScript s "banc-fenetres-relever" >/dev/null 2>&1
sleep 0.5

AVANT="$(lire_evenements | grep '^AVANT:' | tail -1 | sed 's/^AVANT://')"

# --- poser les deux fenêtres jetables ---
python3 "$TRAVAIL/temoin-fenetre.py" "S-TEST-A" "s-banc-fenetres-eprouver" \
    > "$TRAVAIL/a.log" 2>&1 &
PID_A=$!
python3 "$TRAVAIL/temoin-fenetre.py" "S - barre" "s-constellation" \
    > "$TRAVAIL/chrome.log" 2>&1 &
PID_CHROME=$!
sleep 2

if ! kill -0 "$PID_A" 2>/dev/null || ! kill -0 "$PID_CHROME" 2>/dev/null; then
    echo "ÉCHEC : une des deux fenêtres jetables n'a pas survécu au lancement" >&2
    exit 1
fi

# --- le script d'assertion, avec la liste d'exclusion substituée en dur ---
: > "$TRAVAIL/temoin.log"
cat > "$TRAVAIL/eprouver.js" <<JS
var AVANT = "${AVANT}".length ? "${AVANT}".split(",") : [];
function trouver(caption, exclure) {
    var l = workspace.windowList();
    for (var i = 0; i < l.length; i++) {
        if (String(l[i].caption) === caption &&
            (!exclure || AVANT.indexOf(String(l[i].internalId)) === -1)) {
            return l[i];
        }
    }
    return null;
}
function rapporter(msg) {
    callDBus("org.s.temoin", "/temoin", "org.s.temoin", "evenement", msg);
}
var a = trouver("S-TEST-A", false);
var chrome = trouver("S - barre", true);
if (!a || !chrome) {
    rapporter("ECHEC-SETUP a=" + (a ? "ok" : "absent") + " chrome=" + (chrome ? "ok" : "absent"));
} else {
    // SCÉNARIO A : le chrome ne doit jamais garder l'activation réelle.
    workspace.activeWindow = a;
    workspace.raiseWindow(a);
    workspace.activeWindow = chrome;
    rapporter("SCENARIO-A rattrape=" + (workspace.activeWindow === a));

    // SCÉNARIO B : cliquer sur la fenêtre déjà active la range — le
    // rattrapage ne doit JAMAIS la réactiver, même si kwin transite par le
    // chrome au moment du rangement (regression du 2026-09-05, fix #2).
    a.minimized = false;
    workspace.activeWindow = a;
    workspace.raiseWindow(a);
    a.minimized = true;
    workspace.activeWindow = chrome;
    rapporter("SCENARIO-B minimisee=" + a.minimized +
              " pas_reactivee=" + (workspace.activeWindow !== a));
    a.minimized = false;
}
JS

busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
    loadScript ss "$TRAVAIL/eprouver.js" "banc-fenetres-eprouver" >/dev/null
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting start >/dev/null
sleep 1.5
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
    unloadScript s "banc-fenetres-eprouver" >/dev/null 2>&1
sleep 1

RESULTATS="$(lire_evenements)"
echo "$RESULTATS"

ECHEC=0
if echo "$RESULTATS" | grep -q '^ECHEC-SETUP'; then
    echo "ÉCHEC : la mise en place n'a pas trouvé les deux fenêtres" >&2
    ECHEC=1
fi
echo "$RESULTATS" | grep -q '^SCENARIO-A rattrape=true' || {
    echo "ÉCHEC : scénario A — le chrome garde l'activation" >&2
    ECHEC=1
}
echo "$RESULTATS" | grep -q 'minimisee=true pas_reactivee=true' || {
    echo "ÉCHEC : scénario B — le rattrapage casse le rangement" >&2
    ECHEC=1
}

[[ $ECHEC -eq 0 ]] && { echo "TOUT PASSE"; exit 0; }
exit 1
