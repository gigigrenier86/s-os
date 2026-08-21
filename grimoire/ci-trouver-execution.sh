#!/usr/bin/bash
# GRIMOIRE — retrouver la bonne exécution de CI quand « paths-ignore » est actif
# PREUVE : 2026-08-20. Une chaîne de vérification a abandonné au bout de quinze
#          minutes alors que l'image voulue était construite depuis longtemps —
#          sous le commit PRÉCÉDENT.
# POUR   : tout workflow portant « paths-ignore », et toute automatisation qui
#          attend « le CI du dernier commit ».
#
# LE FILTRE FAIT EXACTEMENT CE QU'ON LUI DEMANDE, ET SURPREND DEUX FOIS
#
#   1. Le premier push d'une branche neuve ne déclenche RIEN. Il n'y a pas de
#      commit précédent auquel comparer les chemins. Le workflow_dispatch sert
#      alors de rattrapage.
#
#   2. Un commit qui ne touche que de la documentation n'a AUCUNE exécution.
#      Évident après coup — mais une automatisation qui attend « le CI de HEAD »
#      attend indéfiniment.
#
# LA RÈGLE : chercher l'exécution par le SHA du dernier commit qui touche le
# CODE, jamais par celui de HEAD.

dernier_commit_de_code() {
    # Usage : dernier_commit_de_code [motifs-a-ignorer...]
    # Rend le SHA du dernier commit ayant touché autre chose que la doc.
    local ignore=("${@:-*.md}")
    local sha
    for sha in $(git rev-list -n 50 HEAD); do
        local touches
        touches=$(git show --name-only --format='' "$sha")
        local reste=0 f
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            local ignore_ce=0 m
            for m in "${ignore[@]}"; do
                case "$f" in $m) ignore_ce=1; break ;; esac
            done
            [ "$ignore_ce" -eq 0 ] && { reste=1; break; }
        done <<< "$touches"
        if [ "$reste" -eq 1 ]; then echo "$sha"; return 0; fi
    done
    echo "Aucun commit de code dans les 50 derniers." >&2
    return 1
}

execution_du_commit() {
    # Usage : execution_du_commit <depot> [sha]
    # Demande à l'API GitHub l'exécution attachée à ce SHA précis.
    local depot="$1"
    local sha="${2:-$(dernier_commit_de_code)}"
    [ -z "$sha" ] && return 1
    echo "commit de code : $sha"
    gh api "repos/${depot}/actions/runs?head_sha=${sha}" \
       --jq '.workflow_runs[] | "\(.status)\t\(.conclusion)\t\(.html_url)"' 2>/dev/null \
      || echo "gh absent ou non authentifié — ouvrir l'exécution à la main." >&2
}
