#!/usr/bin/bash
# GRIMOIRE — peser les couches d'une image SANS la télécharger
# PREUVE : 2026-08-20, 23 h 50. A révélé le défaut de découpage de S : une
#          couche unique de 2,3 Go pour huit scripts. Après découpage, une
#          retouche de geste coûte 9,6 Mo. Relevé : 137 couches, 6,95 Go.
# POUR   : diagnostiquer le coût réel d'une mise à jour incrémentale.
#
# POURQUOI ÇA VAUT DE L'OR
# Mesurer le poids d'une couche par un « bootc upgrade » réel coûte une
# demi-heure de téléchargement dans un banc. Le manifeste donne la même réponse
# en UNE requête — et l'ordre des couches suit exactement l'ordre du
# Containerfile, si bien qu'on lit directement quelle instruction pèse quoi.
#
# LA RÈGLE QUE ÇA A FAIT NAÎTRE : une couche par étape. Et « COPY files/ / »
# doit descendre au plus près du seul script qui en dépend, sinon il invalide
# tout ce qui le suit à chaque virgule corrigée.

ghcr_couches() {
    # Usage : ghcr_couches <proprietaire>/<image> [tag]
    local img="$1" tag="${2:-latest}" tok man dig
    tok=$(curl -s "https://ghcr.io/token?scope=repository:${img}:pull&service=ghcr.io" \
          | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    [ -z "$tok" ] && { echo "Aucun jeton : image privée ?" >&2; return 1; }

    local ACC='application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.docker.distribution.manifest.v2+json'

    man=$(curl -s -H "Accept: ${ACC}" -H "Authorization: Bearer ${tok}" \
          "https://ghcr.io/v2/${img}/manifests/${tag}")

    # Un index multi-architecture renvoie une liste de manifestes : il faut
    # suivre vers amd64, sinon on pèse la liste et non l'image.
    if echo "$man" | grep -q '"manifests"'; then
        dig=$(echo "$man" | tr '{' '\n' | grep 'amd64' \
              | grep -o 'sha256:[a-f0-9]\{64\}' | head -1)
        if [ -z "$dig" ]; then
            dig=$(echo "$man" | tr '{' '\n' | grep -o 'sha256:[a-f0-9]\{64\}' | head -1)
        fi
        [ -n "$dig" ] && man=$(curl -s -H "Accept: ${ACC}" \
            -H "Authorization: Bearer ${tok}" \
            "https://ghcr.io/v2/${img}/manifests/${dig}")
    fi

    echo "$man" | tr '{' '\n' | grep '"size"' \
      | sed -n 's/.*"size":\([0-9]*\).*/\1/p' \
      | awk 'NR>1 { n++; mo = $1/1048576; total += mo;
                    printf "  couche %3d : %8.1f Mo\n", n, mo }
             END   { printf "  ---------------------------\n";
                     printf "  %d couches, %.2f Go\n", n, total/1024 }'
}
