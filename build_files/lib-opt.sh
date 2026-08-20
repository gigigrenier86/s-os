#!/usr/bin/bash
# Outils pour les paquets qui s'installent dans /opt.
#
# Deux contraintes se croisent sur une image bootc, et aucune n'est un bogue :
#
#   1. « /opt » est un lien vers « var/opt » sur un systeme ostree, et RPM
#      REFUSE de depaqueter a travers un lien symbolique — durcissement
#      delibere contre une classe de failles.
#   2. « /var » n'entre pas dans une image bootc : il est propre a la machine
#      et recree a l'installation. Meme en forcant, les fichiers n'y seraient
#      pas.
#
# D'ou un detour en trois temps, a encadrer chaque installation concernee.
# Decouvert sur Vivaldi le 2026-08-20, puis reutilise pour Zoom.

opt_preparer() {
    # Retenir la cible reelle plutot que de la supposer : elle pourrait
    # changer d'une version de Fedora a l'autre.
    OPT_CIBLE="$(readlink /opt || echo var/opt)"
    export OPT_CIBLE
    rm -rf /opt
    mkdir -p /opt
}

# $1 : nom du dossier cree sous /opt par le paquet (« vivaldi », « zoom »…)
opt_ranger() {
    local nom="$1"
    [[ -d "/opt/${nom}" ]] || { echo "opt_ranger : /opt/${nom} absent" >&2; return 1; }
    mkdir -p /usr/lib/opt
    mv "/opt/${nom}" "/usr/lib/opt/${nom}"
    # Le pont, refait a chaque demarrage : sans lui, les liens de /usr/bin qui
    # visent /opt/<nom>/... ne resoudraient rien.
    install -d /usr/lib/tmpfiles.d
    printf 'L  /var/opt/%s  -  -  -  -  /usr/lib/opt/%s\n' "${nom}" "${nom}" \
        > "/usr/lib/tmpfiles.d/s-opt-${nom}.conf"
    echo "opt_ranger : ${nom} range dans /usr/lib/opt, pont tmpfiles pose."
}

opt_restaurer() {
    rm -rf /opt
    ln -s "${OPT_CIBLE:-var/opt}" /opt
}
