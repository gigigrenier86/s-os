#!/usr/bin/bash
# GRIMOIRE — éprouver une dépendance Python manquante SANS toucher à /usr,
#            sur un système atomique en lecture seule
# PREUVE : 2026-08-25, 17 h, sur `s` (S sur ThinkCentre M720q). Le presse-papiers
#          Linux↔Android de Waydroid était éteint faute du paquet
#          `python3-pyclip`. Le paquet a été déplié dans un dossier de travail
#          et injecté par PYTHONPATH dans une vraie session Waydroid : le pont
#          s'est armé, et du texte copié dans YouTube sous Android a été relu
#          sous Linux par `wl-paste`. L'image n'a été reconstruite qu'ENSUITE,
#          en sachant que le correctif marchait.
#          Les quatre fonctions ont été exercées le même jour, dans les deux
#          sens : `deplier_rpm` rend un site-packages importable ;
#          `controler_place_rpm` laisse passer un paquet sain et refuse un
#          paquet introuvable ; `verifier_injection` rend le chemin quand il y
#          en a un et sort en 1 quand il n'y en a pas ; `compter_fils` sort en 1
#          sur un PID mort.
#          NON EXERCÉ : `controler_place_rpm` face à un paquet qui se pose
#          réellement hors de /usr — aucun dépôt activé sur cette machine n'en
#          fournit. Seul le filtre a été éprouvé, sur une liste fabriquée
#          (/opt, /var et /usr/local attrapés ; /usr et /usr/lib laissés
#          passer). C'est écrit ici plutôt que passé sous silence.
# POUR   : toute fois où l'on soupçonne qu'un paquet Python manquant éteint une
#          fonction, sur une image bootc/ostree où l'on ne peut pas simplement
#          faire un `dnf install` pour voir.
#
# ============================================================================
# LE PROBLÈME QUE ÇA RÉSOUT, ET POURQUOI IL EST PROPRE À CE GENRE DE SYSTÈME
# ============================================================================
# Sur une machine ordinaire, on installe le paquet, on regarde, on désinstalle
# si c'était faux. Sur un système atomique, non : `/usr` est en lecture seule,
# et la seule voie officielle est de reconstruire l'image, la publier, la tirer,
# redémarrer. Vingt minutes et un redémarrage pour répondre à « est-ce que
# c'était ça ? » — et si c'était non, vingt minutes de plus.
#
# Le raccourci existe et il est propre : un RPM n'est qu'une archive. On le
# déplie n'importe où, et PYTHONPATH suffit à le faire voir par un interpréteur.
# Rien n'est installé, rien n'est modifié, et il n'y a rien à défaire.
#
# ============================================================================
# PIÈGE 1 — LE PROGRAMME VISÉ DOIT ÊTRE DU PYTHON, ET HÉRITER DE L'ENVIRONNEMENT
# ============================================================================
# PYTHONPATH ne traverse pas tout. Vérifier deux choses AVANT :
#
#   head -1 /usr/bin/<programme>          # un shebang python ?
#   tr '\0' '\n' < /proc/<pid>/environ | grep PYTHONPATH
#
# La seconde est la vraie : un programme relancé par systemd, par sudo, ou via
# un service D-Bus activable NE REÇOIT PAS votre environnement. Le relevé de
# /proc/<pid>/environ est la seule preuve que l'injection a atteint sa cible.
# Sans ce contrôle on mesure un banc qui n'a rien injecté, et on conclut à tort
# que la dépendance n'était pas la cause.
#
# ============================================================================
# PIÈGE 2 — « ÇA N'A PAS CHANGÉ » N'EST PAS UNE MESURE
# ============================================================================
# Une dépendance optionnelle s'annonce rarement. Le cas qui a motivé cette
# recette se sautait lui-même en niveau `debug` :
#
#     try:    import pyclip ; canClip = True
#     except: canClip = False
#     ...
#     logging.debug("Skipping clipboard manager service because of missing
#                    pyclip package")
#
# Invisible dans tous les journaux. Il faut donc un TÉMOIN OBSERVABLE de
# l'extérieur, et le plus fiable pour un service en fil est le nombre de fils du
# processus — un service armé en crée un, un service sauté n'en crée aucun.
#
# ET ON LE MESURE DES DEUX CÔTÉS. Un seul relevé ne prouve rien : c'est en
# refaisant tourner la chose SANS l'injection, puis AVEC de nouveau, que le
# chiffre devient une cause. Mesuré le 2026-08-25 : 7 fils avec, 6 sans, 7 au
# retour.
#
# ============================================================================
# PIÈGE 3 — REGARDER OÙ LE PAQUET SE POSE, AVANT DE S'EN RÉJOUIR
# ============================================================================
# Un paquet qui pose quoi que ce soit dans /var, /opt ou /usr/local ne peut pas
# entrer dans une image bootc : ces chemins sont des liens vers /var, que
# l'image ne transporte pas. La construction réussirait et livrerait du vide.
# `controler_place_rpm` répond avant qu'on écrive une ligne de Containerfile.

# ---------------------------------------------------------------------------
# Déplier un RPM dans un dossier de travail. Rend le chemin site-packages.
#   deplier_rpm python3-pyclip /tmp/essai
# ---------------------------------------------------------------------------
deplier_rpm() {
    local paquet="${1:-}" dossier="${2:-}"
    if [[ -z "$paquet" || -z "$dossier" ]]; then
        echo "deplier_rpm <paquet> <dossier-de-travail>" >&2
        return 2
    fi
    for outil in dnf5 rpm2cpio cpio; do
        command -v "$outil" >/dev/null || { echo "deplier_rpm : $outil absent" >&2; return 2; }
    done

    mkdir -p "$dossier" || return 1
    # --destdir plutôt qu'un chemin deviné : le nom exact du fichier dépend de
    # l'architecture et de la révision, et le deviner est la faute d'à côté.
    dnf5 download "$paquet" --destdir="$dossier" >/dev/null 2>&1 \
        || { echo "deplier_rpm : téléchargement de $paquet impossible" >&2; return 1; }

    local rpm
    rpm="$(find "$dossier" -maxdepth 1 -name '*.rpm' -print -quit)"
    [[ -n "$rpm" ]] || { echo "deplier_rpm : aucun .rpm téléchargé" >&2; return 1; }

    ( cd "$dossier" && rpm2cpio "$rpm" | cpio -idm --quiet ) || return 1

    # Le nom du dossier porte la version de Python de l'image, qui change ; on
    # le cherche au lieu de l'écrire.
    local sp
    sp="$(find "$dossier/usr/lib" "$dossier/usr/lib64" -maxdepth 2 -type d \
              -name 'site-packages' -print -quit 2>/dev/null)"
    [[ -n "$sp" ]] || { echo "deplier_rpm : pas de site-packages dans $paquet" >&2; return 1; }
    echo "$sp"
}

# ---------------------------------------------------------------------------
# La règle 1 du projet, appliquée à un paquet qu'on n'a pas installé.
#   controler_place_rpm python3-pyclip
# ---------------------------------------------------------------------------
controler_place_rpm() {
    local paquet="${1:-}"
    [[ -n "$paquet" ]] || { echo "controler_place_rpm <paquet>" >&2; return 2; }

    # LE DEFAUT QUE CE BLOC REPARE, ET IL ETAIT DANS CETTE RECETTE MEME.
    # Premiere version, le 2026-08-25 : on filtrait la liste des fichiers et,
    # ne trouvant rien, on repondait « tout est dans /usr ». Essayee sur
    # « vivaldi-stable » — le paquet qui, dans ce projet, se pose justement dans
    # /opt et a coute un detour entier — elle a repondu OK. Parce que le paquet
    # n'est pas dans les depots actives ici : repoquery a rendu une liste VIDE,
    # le grep n'a rien trouve, et l'absence de mauvaise nouvelle a ete lue comme
    # une bonne. Le succes silencieux, commis dans l'outil ecrit pour le
    # detecter. « Je ne peux pas voir » n'est pas « il n'y a rien ».
    local liste
    liste="$(dnf5 -q repoquery -l "$paquet" 2>/dev/null || true)"
    if [[ -z "$liste" ]]; then
        echo "controler_place_rpm : $paquet ne rend AUCUN fichier —" >&2
        echo "  paquet absent des depots actives, ou nom errone. On ne peut" >&2
        echo "  rien conclure, et surtout pas que tout va bien." >&2
        return 2
    fi
    local hors
    hors="$(printf '%s\n' "$liste" | grep -E '^/(var|opt)/|^/usr/local/' || true)"
    if [[ -n "$hors" ]]; then
        echo "controler_place_rpm : $paquet pose des fichiers hors de /usr —" >&2
        echo "$hors" >&2
        echo "  il ne peut PAS entrer dans une image bootc en l'état." >&2
        return 1
    fi
    echo "$paquet : tout est dans /usr — il peut entrer dans l'image."
}

# ---------------------------------------------------------------------------
# Le témoin : combien de fils tourne ce processus. À relever des DEUX côtés.
#   compter_fils "$pid"
# ---------------------------------------------------------------------------
compter_fils() {
    local pid="${1:-}"
    [[ -n "$pid" && -d "/proc/$pid/task" ]] || { echo 0; return 1; }
    ls "/proc/$pid/task" 2>/dev/null | wc -l
}

# ---------------------------------------------------------------------------
# Le contrôle du piège 1 : l'injection a-t-elle vraiment atteint la cible.
#   verifier_injection "$pid"
# ---------------------------------------------------------------------------
verifier_injection() {
    local pid="${1:-}"
    [[ -n "$pid" && -r "/proc/$pid/environ" ]] \
        || { echo "verifier_injection : /proc/$pid/environ illisible" >&2; return 1; }
    local vu
    vu="$(tr '\0' '\n' < "/proc/$pid/environ" | sed -n 's/^PYTHONPATH=//p')"
    if [[ -z "$vu" ]]; then
        echo "verifier_injection : le processus $pid n'a AUCUN PYTHONPATH." >&2
        echo "  Il a probablement été relancé par systemd, sudo ou un service" >&2
        echo "  D-Bus activable — tout ce qui suit mesurerait un banc vide." >&2
        return 1
    fi
    echo "$vu"
}
