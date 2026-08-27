#!/usr/bin/bash
# GRIMOIRE — trouver la vraie classe Wayland d'une fenêtre « vivaldi --app= »
# PREUVE : 2026-08-26, sur `s`. Deux lanceurs mesurés, processus frais ET
#          processus réutilisé confondus :
#              vivaldi --app=https://app.mews.com/           --class=RapidO
#                  -> vraie classe : vivaldi-app.mews.com__-Default
#              vivaldi --app=https://gemini.google.com/app   --class=Gemini
#                  -> vraie classe : vivaldi-gemini.google.com__app-Default
#          `--class=` était présent dans les deux .desktop depuis leur
#          création et n'a jamais eu le moindre effet — jamais mesuré jusqu'ici.
# POUR   : tout lanceur `.desktop` qui ouvre un site avec `vivaldi --app=` et
#          qui a besoin d'un `StartupWMClass` exact — pour une règle kwin, un
#          regroupement de barre des tâches, ou toute logique qui matche par
#          classe de fenêtre.
#
# CE QUI ÉTAIT SUPPOSÉ, ET QUI ÉTAIT FAUX
# `--class=NOM` est un vrai drapeau Chromium, mais il ne s'applique qu'à la
# session de navigation normale. En mode `--app=`, Vivaldi (comme Chromium)
# calcule lui-même l'identité Wayland de la fenêtre à partir de l'URL — pour
# que deux raccourcis vers le même site se regroupent, PWA ou pas — et ignore
# silencieusement le drapeau. Aucune erreur, aucun avertissement : la fenêtre
# s'ouvre normalement, et seule sa classe réelle diffère de celle qu'on croyait
# lui avoir donnée. Le succès silencieux dans sa forme habituelle.
#
# LA FORME OBSERVÉE, SUR DEUX POINTS DE MESURE SEULEMENT
#     vivaldi-<hôte>__<premier segment du chemin, ou rien>-<nom du profil>
# Deux points ne suffisent pas à garantir la formule pour un chemin à
# plusieurs segments ou une requête — NE PAS EN DÉDUIRE UNE FONCTION DE
# CALCUL. La seule chose fiable est de MESURER, ci-dessous.
#
# CE QUI NE CHANGE RIEN À LA MESURE, ET C'ÉTAIT UNE VRAIE QUESTION
# Un processus Vivaldi déjà lancé (le cas courant : Vivaldi tourne presque
# toujours) donne « Ouverture dans une session de navigateur existante » et
# réutilise le processus. Un `--user-data-dir` isolé, donc un processus
# entièrement frais, donne LA MÊME classe. Ce n'est donc pas une histoire de
# partage de processus — Vivaldi calcule cette identité de la même façon dans
# les deux cas.
#
# LA MÉCANIQUE DE MESURE : UN SCRIPT KWIN NE REND RIEN, LE BUS SERT DE TÉMOIN
# Un script kwin chargé sur le bus de session peut lire `workspace.windowList()`
# mais n'a aucun canal de sortie vers l'appelant — ni valeur de retour, ni
# `print` qui ressort dans un journal lisible. On lui fait donc appeler une
# méthode sur un nom de bus que personne ne possède, avec la classe et le
# titre de chaque fenêtre en argument : l'appel échoue sans conséquence, mais
# un `dbus-monitor` posé à côté le voit passer. Même patron que
# `kwin-capturer-la-coquille.sh`, appliqué à lister plutôt qu'à activer.

lister_fenetres_reelles() {
    local sortie="${1:-/dev/stdout}"
    for outil in busctl dbus-monitor; do
        command -v "$outil" >/dev/null 2>&1 || {
            echo "lister_fenetres_reelles : $outil absent" >&2
            return 1
        }
    done

    local script_js temoin_log id
    script_js="$(mktemp /tmp/s-lister-fenetres-XXXXXX.js)"
    temoin_log="$(mktemp /tmp/s-temoin-fenetres-XXXXXX.log)"
    trap 'rm -f "$script_js" "$temoin_log"' RETURN

    cat > "$script_js" <<'EOF'
var lst = workspace.windowList();
for (var i = 0; i < lst.length; i++) {
    var w = lst[i];
    callDBus("org.s.temoin.liste", "/temoin", "org.s.temoin", "fenetre",
        String(w.resourceClass), String(w.caption));
}
EOF

    id=$(busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
         loadScript s "$script_js" 2>/dev/null | awk '{print $2}')
    [[ -n "$id" ]] || { echo "lister_fenetres_reelles : échec du chargement" >&2; return 1; }

    dbus-monitor --session "interface='org.s.temoin'" > "$temoin_log" 2>&1 &
    local moniteur=$!
    sleep 1
    busctl --user call org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script run >/dev/null 2>&1
    sleep 1
    kill "$moniteur" 2>/dev/null

    grep -A2 "member=fenetre" "$temoin_log" | grep "string" \
        | sed 's/^\s*string "//; s/"$//' \
        | paste -d'\t' - - > "$sortie"
}

# Usage :
#   source grimoire/vivaldi-classe-reelle-app.sh
#   lister_fenetres_reelles                    # imprime classe<TAB>titre, une par ligne
#   lister_fenetres_reelles /tmp/fenetres.tsv  # ou vers un fichier
#
# Lance le lanceur `.desktop` à mesurer AVANT d'appeler cette fonction — elle
# ne fait que lire ce qui est déjà ouvert.
