#!/usr/bin/bash
# GRIMOIRE — capturer une fenêtre précise sous kwin_wayland, sans interface
#            et sans déranger les fenêtres ouvertes
# PREUVE : 2026-08-25, 12 h 23, sur `s` (Intel UHD 630, pilote i915). La coquille
#          Constellation a été photographiée en 1920 × 1080 alors qu'une konsole
#          et un éditeur la recouvraient. Aucune fenêtre n'a été réduite, aucune
#          n'a bougé. L'image est entrée à la Galerie le jour même.
# POUR   : photographier le bureau, une coquille, ou n'importe quelle fenêtre,
#          depuis un script, sur une session Wayland tenue par kwin.
#
# ============================================================================
# PIÈGE 1 — L'API DE CAPTURE DE KWIN EST RÉSERVÉE, ET LE DIT MAL
# ============================================================================
# kwin publie « org.kde.KWin.ScreenShot2 » sur le bus de session. L'interface
# est complète et alléchante : CaptureWorkspace, CaptureScreen, CaptureWindow,
# le tout rendu en pixels bruts dans un tube. Elle est aussi FERMÉE.
#
# Un appel depuis un script Python rend :
#
#     org.kde.KWin.ScreenShot2.Error.NoAuthorized:
#     The process is not authorized to take a screenshot
#
# kwin vérifie l'exécutable de l'appelant et n'accepte qu'une courte liste
# (spectacle, le portail xdg-desktop-portal-kde, et deux ou trois autres).
# Ce n'est pas contournable proprement, et c'est bien : une session où
# n'importe quel processus photographie l'écran n'a plus de vie privée.
#
# LA RÈGLE, QUI EST CELLE DU PROJET : on ne réimplémente pas ce que l'amont
# maintient. spectacle est déjà dans l'image, il est déjà autorisé, et il a un
# mode sans interface. C'est lui qu'on appelle.
#
# ============================================================================
# PIÈGE 2 — « MONTRER LE BUREAU » NE SURVIT PAS À LA CAPTURE
# ============================================================================
# Le réflexe pour dégager l'écran est d'appeler :
#
#     busctl --user call org.kde.KWin /KWin org.kde.KWin showDesktop b true
#
# Ça marche — pendant une seconde. Dès que spectacle démarre, kwin voit une
# nouvelle activation et SORT du mode « bureau montré ». Mesuré : juste après
# la capture, la propriété « showingDesktop » valait déjà `false`, et l'image
# obtenue montrait la konsole par-dessus le bureau.
#
# On a donc une capture qui a l'air d'avoir marché et qui montre autre chose
# que ce qu'on croyait cadrer. C'est le succès silencieux, en version image —
# et ce dossier s'est déjà fait avoir deux fois par une capture qui mentait.
#
# ============================================================================
# CE QUI MARCHE : ACTIVER LA FENÊTRE, PUIS CAPTURER « LA FENÊTRE ACTIVE »
# ============================================================================
# spectacle -a photographie la fenêtre active. Reste à choisir laquelle, sans
# souris et sans clic : kwin accepte qu'on lui charge un script JavaScript sur
# le bus et qu'on le lance. Trois lignes suffisent pour poser l'activation.
#
# L'ordre est le tout : script d'activation → délai → spectacle -a. Le délai
# n'est pas décoratif — kwin doit avoir fini de relever la pile avant que
# spectacle demande « qui est devant ».
#
# AVANTAGE SUR LA RÉDUCTION DES FENÊTRES : rien n'est réduit, donc rien n'est à
# restaurer, donc on ne peut pas rendre à l'utilisateur un bureau différent de
# celui qu'il avait laissé. La fenêtre visée passe devant, on la prend, on la
# laisse. Une capture ne doit pas réorganiser la session pour se réussir.

# ============================================================================
# PIÈGE 3 — « spectacle -a » RÉUSSIT TOUJOURS, MÊME QUAND ON A VISÉ LE VIDE
# ============================================================================
# La première version de cette recette a été écrite, puis essayée avec un motif
# de classe qui n'existe pas. Elle a rendu une image, et le code 0.
#
# Évidemment : le script d'activation ne trouve rien, n'active rien, et
# « spectacle -a » photographie la fenêtre qui se trouvait active — le terminal
# depuis lequel on tape. On obtient un fichier, un succès, et le sentiment
# d'avoir photographié ce qu'on demandait. C'est le succès silencieux, commis
# ici même, dans la recette censée l'éviter.
#
# IL FAUT DONC SAVOIR SI L'ACTIVATION A TROUVÉ SA CIBLE, et un script kwin ne
# rend rien à l'appelant : pas de valeur de retour, et son « print » ne ressort
# ni dans le journal utilisateur ni dans le journal système — vérifié.
#
# LE PASSAGE : « callDBus » existe dans les scripts kwin. Le script appelle donc,
# quand il a trouvé, une méthode sur un nom que PERSONNE ne possède. L'appel
# échoue côté bus, ce qui est sans conséquence — mais un « dbus-monitor » lancé
# à côté le voit passer, avec la classe trouvée en argument.
#
# On se sert du bus comme d'un témoin, pas comme d'un transport. Rien à
# installer, rien à faire tourner en permanence, et l'information manquante
# traverse.

# Photographie une fenêtre choisie par sa classe de ressource.
#
#   capturer_fenetre <motif-de-classe> <fichier.png> [secondes-de-pose]
#
#   capturer_fenetre constellation /tmp/bureau.png
#   capturer_fenetre konsole       /tmp/terminal.png 2
#
# Rend 0 et écrit le chemin. Rend 1 — SANS créer de fichier — si aucune fenêtre
# ne porte ce motif, plutôt que de photographier celle qui passait par là.
capturer_fenetre() {
    local motif="$1" sortie="$2" pose="${3:-1}"
    local nom="s-capture-$$"

    if [[ -z "$motif" || -z "$sortie" ]]; then
        echo "capturer_fenetre <motif-de-classe> <fichier.png> [pose]" >&2
        return 1
    fi
    for outil in spectacle busctl dbus-monitor; do
        if ! command -v "$outil" >/dev/null 2>&1; then
            echo "capturer_fenetre : $outil absent" >&2
            return 1
        fi
    done

    local script temoin
    script="$(mktemp --suffix=.js)" || return 1
    temoin="$(mktemp)" || { rm -f "$script"; return 1; }

    # LE SCRIPT NE RÉDUIT RIEN ET NE DÉPLACE RIEN : il pose une activation, et
    # signale sa trouvaille sur un nom de bus que personne ne possède. L'appel
    # échoue, le témoin le voit — c'est tout ce qu'on lui demande.
    cat > "$script" <<JS
var liste = workspace.windowList();
for (var i = 0; i < liste.length; i++) {
    var f = liste[i];
    if (f.resourceClass && String(f.resourceClass).indexOf("$motif") !== -1) {
        workspace.activeWindow = f;
        callDBus("org.s.temoin", "/temoin", "org.s.temoin", "trouve",
                 String(f.resourceClass));
        break;
    }
}
JS

    timeout 8 dbus-monitor --session "interface='org.s.temoin'" \
        > "$temoin" 2>&1 &
    local guetteur=$!
    sleep 1   # le témoin doit être en place AVANT que le script parle

    busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
        loadScript ss "$script" "$nom" >/dev/null 2>&1
    busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
        start >/dev/null 2>&1
    sleep "$pose"

    kill "$guetteur" 2>/dev/null
    wait "$guetteur" 2>/dev/null
    busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting \
        unloadScript s "$nom" >/dev/null 2>&1
    rm -f "$script"

    if ! grep -q "member=trouve" "$temoin"; then
        rm -f "$temoin"
        echo "capturer_fenetre : aucune fenêtre dont la classe contient" \
             "« $motif ». Rien n'a été capturé." >&2
        return 1
    fi
    local classe
    classe="$(grep -A1 "member=trouve" "$temoin" | tail -1 | tr -d ' "')"
    rm -f "$temoin"

    rm -f "$sortie"
    # -b sans interface, -n sans notification (aucun démon ne l'afficherait de
    # toute façon), -e sans décoration, -S sans ombre : on veut les pixels de la
    # fenêtre, pas le cadre que kwin dessine autour.
    timeout 30 spectacle -b -n -a -e -S -o "$sortie" >/dev/null 2>&1

    if [[ ! -s "$sortie" ]]; then
        echo "capturer_fenetre : « $classe » a bien été activée, mais spectacle" \
             "n'a rien écrit dans $sortie." >&2
        return 1
    fi
    echo "$sortie"
}

# Le cas courant : la coquille de S, plein écran, telle qu'elle s'affiche.
capturer_constellation() {
    capturer_fenetre constellation "${1:-constellation.png}" "${2:-1}"
}
