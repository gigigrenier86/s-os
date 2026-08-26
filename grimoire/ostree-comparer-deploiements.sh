#!/usr/bin/bash
# GRIMOIRE — ostree : savoir ce qu'un rollback coûte, avant de le faire
# PREUVE : 2026-08-25 19 h 55, sur S (M720q). A nommé, fichier par fichier, les
#          trois correctifs perdus par le rollback de 19 h 49 — pyclip absent,
#          Constellation.qml:408 revenu au bogue, s-android amputé du mode
#          fenêtre unique. Sortie complète en pied de fichier.
# POUR   : toute base atomique où deux déploiements coexistent (bootc, ostree,
#          Fedora Silverblue/Kinoite, Bazzite, CentOS bootc).
#
# LE PROBLÈME
# « Revenir en arrière » est le filet de sécurité d'un OS immuable, et c'est
# aussi le geste dont on ignore le prix au moment de le poser : deux images
# portent le même tag, la même version, souvent le même noyau. Le numéro ne
# dit rien de ce qui change.
#
# Or les deux arborescences sont DÉJÀ SUR LE DISQUE, en clair, lisibles sans
# root et sans redémarrer :
#     /ostree/deploy/<os>/deploy/<checksum>.0/usr/...
# On peut donc lire l'image d'en face au lieu de la supposer.
#
# LE FAUX TÉMOIN, ET IL EST CONVAINCANT
# Le réflexe pour savoir quel déploiement a démarré est de lire l'argument
# `ostree=` du noyau. IL NE DISTINGUE PAS LES DÉPLOIEMENTS. Sa forme est
#     ostree=/ostree/boot.<version>/<os>/<bootcsum>/<serial>
# et `bootcsum` est l'empreinte du NOYAU, partagée par tout déploiement qui
# embarque le même. Relevé le 2026-08-25 : deux démarrages successifs, sur
# deux images différentes, portaient le même `ostree=` au caractère près.
#
# Ce qui identifie vraiment le déploiement booté est l'étoile d'
# `ostree admin status`, ou le rond de `rpm-ostree status`. Rien d'autre.

# Rend une ligne par déploiement : rang<TAB>role<TAB>checksum<TAB>chemin
deploiements_ostree() {
    local os="${1:-default}" rang=0 csum role
    while read -r csum; do
        [ -z "$csum" ] && continue
        case $rang in 0) role="booté" ;; 1) role="rollback" ;; *) role="rang $rang" ;; esac
        printf '%d\t%s\t%s\t/ostree/deploy/%s/deploy/%s.0\n' "$rang" "$role" "$csum" "$os" "$csum"
        rang=$((rang + 1))
    done < <(ostree admin status 2>/dev/null \
             | grep -E "(^\*| ) *${os} " \
             | grep -oE '[0-9a-f]{64}' )
}

# printf pade en octets, pas en colonnes — « booté » vaut 6 octets pour 5
# signes. On complete donc a la main, sur le nombre de SIGNES.
aligner() { local n=${#1}; printf '%*s' $(( 8 - n > 0 ? 8 - n : 0 )) ''; }

# Usage : comparer_deploiements usr/bin/s-android usr/share/s/.../X.qml ...
# Pour chaque chemin, dit ce que le booté et le rollback en portent.
# Rend 1 si au moins un chemin diffère — donc utilisable comme garde.
comparer_deploiements() {
    local -a chemins=("$@") racines=() roles=()
    local rang role csum racine c diff=0

    while IFS=$'\t' read -r rang role csum racine; do
        racines+=("$racine"); roles+=("$role")
    done < <(deploiements_ostree)

    if [ "${#racines[@]}" -lt 2 ]; then
        echo "un seul déploiement — rien à comparer, et donc aucun retour possible" >&2
        return 2
    fi

    for c in "${chemins[@]}"; do
        c="${c#/}"
        local a="${racines[0]}/$c" b="${racines[1]}/$c" ea eb
        [ -e "$a" ] && ea="présent" || ea="ABSENT"
        [ -e "$b" ] && eb="présent" || eb="ABSENT"
        if [ -f "$a" ] && [ -f "$b" ]; then
            if cmp -s "$a" "$b"; then
                printf '  =  %s\n' "$c"
                continue
            fi
            ea="$(wc -c <"$a") o"; eb="$(wc -c <"$b") o"
        fi
        diff=1
        printf '  ≠  %s\n' "$c"
        printf '       %s%s : %s\n' "${roles[0]}" "$(aligner "${roles[0]}")" "$ea"
        printf '       %s%s : %s\n' "${roles[1]}" "$(aligner "${roles[1]}")" "$eb"
    done
    return $diff
}

# Ce que porte l'image d'en face pour UN fichier — le lire plutôt que le deviner.
lire_dans_rollback() {
    # Usage : lire_dans_rollback usr/bin/s-android [lignes]
    local c="${1#/}" n="${2:-40}" racine
    racine=$(deploiements_ostree | awk -F'\t' '$2=="rollback"{print $4}')
    [ -z "$racine" ] && { echo "aucun déploiement de rollback" >&2; return 2; }
    head -n "$n" "$racine/$c"
}

# ── Sortie de la PREUVE, 2026-08-25 19 h 55 ─────────────────────────────────
#
# $ comparer_deploiements usr/lib/python3.14/site-packages/pyclip \
#       usr/share/s/constellation/qml/Constellation.qml usr/bin/s-android
#   ≠  usr/lib/python3.14/site-packages/pyclip
#        booté    : ABSENT
#        rollback : présent
#   ≠  usr/share/s/constellation/qml/Constellation.qml
#        booté    : 36451 o
#        rollback : 38118 o
#   ≠  usr/bin/s-android
#        booté    : 9166 o
#        rollback : 20876 o
#   code de retour : 1
#
# Et l'autre sens, sur deux gestes que la nouvelle image ne touche pas :
# $ comparer_deploiements usr/bin/s-play-store usr/bin/s-ouvrir-flatpak
#   =  usr/bin/s-play-store
#   =  usr/bin/s-ouvrir-flatpak
#   code de retour : 0
