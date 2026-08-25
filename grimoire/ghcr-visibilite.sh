#!/usr/bin/bash
# GRIMOIRE — ghcr.io : un paquet est-il VRAIMENT public ?
# PREUVE : 2026-08-20. Ce test a CORRIGÉ une conclusion fausse déjà consignée
#          au carnet (« 401 donc privé »). Relevé après bascule : 200.
#          2026-08-25 : corrigée d'un faux verdict à elle — elle répondait
#          « PRIVÉ » sur un paquet public, faute de demander le bon type de
#          manifeste. Ré-éprouvée dans quatre cas ce jour-là : paquet public
#          → 200 ; tag inexistant → 404 nommé comme tel, PAS comme un refus ;
#          dépôt inexistant → aucun jeton ; et `ghcr_digest` rend le digest
#          publié, ce qui sert à savoir si la CI a fini.
# POUR   : toute vérification de visibilité sur GitHub Container Registry.
#
# LE PIÈGE : ghcr.io renvoie HTTP 401 à toute requête sans jeton, publique ou
# privée. C'est son comportement NORMAL — il exige un jeton porteur dans tous
# les cas. Un curl anonyme direct sur le manifeste ne prouve donc RIEN, et la
# conclusion « 401 donc privé » est un faux positif garanti.
#
# Le vrai test tient en deux temps : le registre délivre-t-il un jeton à un
# anonyme, et ce jeton ouvre-t-il le manifeste.
#
# À SAVOIR : il n'existe pas d'API REST pour la visibilité d'un paquet
# conteneur. Ça se bascule à la main dans l'interface web, et la visibilité du
# DÉPÔT ne s'y propage pas.
#
# ============================================================================
# LE SECOND PIÈGE, TROUVÉ LE 2026-08-25 — ET CETTE RECETTE Y EST TOMBÉE
# ============================================================================
# Cette fonction a répondu « PRIVÉ » sur un paquet public. Pas une erreur de
# transport : un HTTP 404, rendu parce qu'elle ne demandait que des types
# d'INDEX — `oci.image.index.v1` et `docker.manifest.list.v2`.
#
# Or le manifeste publié par cette chaîne de construction est un
# `oci.image.manifest.v1` : une image unique, pas un index multi-architecture.
# Un registre qui n'a rien du type demandé répond 404, ce qui n'a rien à voir
# avec la permission.
#
# La recette écrite pour corriger un faux verdict de visibilité en rendait donc
# un autre, du même genre, à l'envers. C'est la faute que ce projet nomme
# ailleurs : **« je ne peux pas voir » n'est pas « il n'y a rien »** — et sa
# jumelle, un code d'erreur lu comme un refus alors qu'il dit « pas de cette
# forme-là ».
#
# On envoie désormais les QUATRE types, index et manifeste. Et on distingue le
# 404 du 401/403 dans la réponse, parce que les deux ne veulent pas dire la
# même chose et qu'aucun des deux ne veut dire « privé » à coup sûr.

ghcr_public() {
    # Usage : ghcr_public <proprietaire>/<image> [tag]
    local img="$1" tag="${2:-latest}" tok code
    tok=$(curl -s "https://ghcr.io/token?scope=repository:${img}:pull&service=ghcr.io" \
          | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    if [ -z "$tok" ]; then
        # Le registre refuse aussi le jeton pour un dépôt qui n'existe pas :
        # ces deux cas ne se distinguent pas d'ici, et prétendre le contraire
        # serait le faux verdict que cette recette existe pour empêcher.
        echo "PRIVÉ OU INEXISTANT : aucun jeton délivré à un anonyme pour ${img}."
        return 1
    fi
    code=$(curl -s -o /dev/null -w '%{http_code}' \
        -H "Accept: application/vnd.oci.image.index.v1+json" \
        -H "Accept: application/vnd.oci.image.manifest.v1+json" \
        -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        -H "Authorization: Bearer ${tok}" \
        "https://ghcr.io/v2/${img}/manifests/${tag}")
    case "$code" in
        200) echo "PUBLIC : ${img}:${tag} tirable sans authentification"; return 0 ;;
        404) echo "INTROUVABLE : ${img}:${tag} n'existe pas, ou aucun des types" \
                  "de manifeste demandés. Ce n'est PAS un verdict de visibilité." ; return 2 ;;
        401|403) echo "PRIVÉ : jeton obtenu mais manifeste refusé (HTTP ${code})"; return 1 ;;
        *)   echo "INDÉCIS : HTTP ${code} — ni 200, ni refus, ni absence."; return 3 ;;
    esac
}

# Le digest publié, sans rien télécharger. Sert à savoir si la CI a fini.
#   ghcr_digest gigigrenier86/s-os
ghcr_digest() {
    local img="$1" tag="${2:-latest}" tok
    tok=$(curl -s --max-time 20 "https://ghcr.io/token?scope=repository:${img}:pull&service=ghcr.io" \
          | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    [ -n "$tok" ] || { echo "aucun jeton délivré" >&2; return 1; }
    curl -sI --max-time 20 \
        -H "Accept: application/vnd.oci.image.index.v1+json" \
        -H "Accept: application/vnd.oci.image.manifest.v1+json" \
        -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        -H "Authorization: Bearer ${tok}" \
        "https://ghcr.io/v2/${img}/manifests/${tag}" \
      | grep -i '^docker-content-digest' | tr -d '\r' | awk '{print $2}'
}
