#!/usr/bin/bash
# GRIMOIRE — ghcr.io : un paquet est-il VRAIMENT public ?
# PREUVE : 2026-08-20. Ce test a CORRIGÉ une conclusion fausse déjà consignée
#          au carnet (« 401 donc privé »). Relevé après bascule : 200.
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

ghcr_public() {
    # Usage : ghcr_public <proprietaire>/<image> [tag]
    local img="$1" tag="${2:-latest}" tok code
    tok=$(curl -s "https://ghcr.io/token?scope=repository:${img}:pull&service=ghcr.io" \
          | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    if [ -z "$tok" ]; then
        echo "PRIVÉ : aucun jeton délivré à un anonyme."
        return 1
    fi
    code=$(curl -s -o /dev/null -w '%{http_code}' \
        -H "Accept: application/vnd.oci.image.index.v1+json" \
        -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
        -H "Authorization: Bearer ${tok}" \
        "https://ghcr.io/v2/${img}/manifests/${tag}")
    case "$code" in
        200) echo "PUBLIC : ${img}:${tag} tirable sans authentification"; return 0 ;;
        *)   echo "PRIVÉ : jeton obtenu mais manifeste refusé (HTTP ${code})"; return 1 ;;
    esac
}
