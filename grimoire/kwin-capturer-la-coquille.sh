#!/usr/bin/bash
# GRIMOIRE — capturer une fenêtre précise sous kwin_wayland, sans interface
#            et sans déranger les fenêtres ouvertes
# PREUVE : 2026-08-25, 12 h 23, sur `s` (Intel UHD 630, pilote i915). La coquille
#          Constellation a été photographiée en 1920 × 1080 alors qu'une konsole
#          et un éditeur la recouvraient. Aucune fenêtre n'a été réduite, aucune
#          n'a bougé. L'image est entrée à la Galerie le jour même.
#          2026-08-26, 07 h 20, même machine : la fenêtre d'un programme Windows
#          (PcBoostApp, 1028 × 733) capturée depuis un shell SANS session
#          graphique — ni `XDG_RUNTIME_DIR`, ni `WAYLAND_DISPLAY`. C'est ce que
#          les trois correctifs datés de ce jour ont rendu possible.
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

# Photographie une fenêtre choisie par sa classe de ressource OU par son titre.
#
#   capturer_fenetre <motif> <fichier.png> [secondes-de-pose]
#
#   capturer_fenetre constellation /tmp/bureau.png
#   capturer_fenetre konsole       /tmp/terminal.png 2
#   capturer_fenetre "PC Boost"    /tmp/windows.png     <-- par le titre
#
# Rend 0 et écrit le chemin. Rend 1 — SANS créer de fichier — si aucune fenêtre
# ne porte ce motif, plutôt que de photographier celle qui passait par là.
#
# ============================================================================
# PIÈGE 5 — TOUS LES PROGRAMMES WINDOWS DE S PORTENT LA MÊME CLASSE
# ============================================================================
# MESURÉ LE 2026-08-26. La fenêtre de PcBoostApp ne s'appelle pas
# « PcBoostApp » : sa classe de ressource est **steam_proton**, et c'est celle
# de TOUS les programmes lancés dans le préfixe — c'est Proton qui la pose, pas
# le programme. Chercher par le nom du programme ne rendait donc jamais rien,
# et la clause de garde ci-dessus faisait correctement son travail : elle
# refusait de photographier au hasard. Elle ne disait simplement pas pourquoi.
#
# D'où le titre comme second critère. `steam_proton` désigne le monde Windows ;
# le titre (« PC Boost ») désigne le programme dedans. Sans lui, deux programmes
# Windows ouverts ensemble ne sont pas distinguables.
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

    # ========================================================================
    # PIÈGE 4 — UN SHELL SANS SESSION GRAPHIQUE FAIT TAIRE SPECTACLE
    # ========================================================================
    # MESURÉ LE 2026-08-26, et ça a coûté une nuit à quelqu'un d'autre : la
    # capture à trente secondes de PcBoostApp n'aboutissait pas, et le carnet
    # avait conclu « elle n'a pas abouti » sans savoir pourquoi.
    #
    # Les deux manques ne se ressemblent pas, et aucun ne se nomme :
    #
    #   XDG_RUNTIME_DIR vide   spectacle attend, SANS ERREUR, SANS FICHIER.
    #                          Trente secondes de silence. Succès silencieux.
    #   WAYLAND_DISPLAY vide   spectacle AVORTE (SIGABRT), sans un mot utile.
    #
    # Et `DISPLAY=:0` ne remplace pas le second : mesuré, spectacle échoue
    # quand même — sous cette session il parle wayland, pas X.
    #
    # Un shell de banc — tmux, unité systemd, `ssh`, un agent — n'a
    # généralement ni l'un ni l'autre. Mais LES DEUX SE DÉDUISENT de
    # /run/user/<uid>, qui est là de toute façon. On déduit plutôt que
    # d'exiger : la recette doit marcher d'où on l'appelle.
    if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
        if [[ -d "/run/user/$(id -u)" ]]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        else
            echo "capturer_fenetre : XDG_RUNTIME_DIR est vide et" \
                 "/run/user/$(id -u) n'existe pas — aucune session à photographier." >&2
            return 1
        fi
    fi
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        local _socle
        _socle="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' \
                    ! -name '*.lock' -printf '%f\n' 2>/dev/null | sort | head -1)"
        if [[ -n "$_socle" ]]; then
            export WAYLAND_DISPLAY="$_socle"
        else
            echo "capturer_fenetre : aucun socle wayland dans $XDG_RUNTIME_DIR" \
                 "— il n'y a pas de session graphique ici." >&2
            return 1
        fi
    fi

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
    var classe = f.resourceClass ? String(f.resourceClass) : "";
    var titre  = f.caption       ? String(f.caption)       : "";
    if (classe.indexOf("$motif") !== -1 || titre.indexOf("$motif") !== -1) {
        workspace.activeWindow = f;
        callDBus("org.s.temoin", "/temoin", "org.s.temoin", "trouve",
                 classe + " / " + titre);
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
        echo "capturer_fenetre : aucune fenêtre dont la classe ou le titre" \
             "contient « $motif ». Rien n'a été capturé." >&2
        return 1
    fi
    # « tr -d ' "' » rendait « stringsteam_proton » : dbus-monitor préfixe la
    # valeur par son type, et le nettoyage collait le type au contenu. Un nom
    # faux dans un message d'échec envoie chercher au mauvais endroit.
    local classe
    classe="$(grep -A1 "member=trouve" "$temoin" \
              | sed -n 's/^[[:space:]]*string "\(.*\)"$/\1/p' | tail -1)"
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
