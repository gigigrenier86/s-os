#!/usr/bin/bash
# GRIMOIRE — ostree : installer un RPM qui exige /opt
# PREUVE : 2026-08-20, Vivaldi 8.1.4087.68 et Zoom. Vérifié APRÈS redémarrage
#          sur le système installé : /var/opt/vivaldi -> /usr/lib/opt/vivaldi,
#          binaire exécutable, « Vivaldi 8.1.4087.68 stable » rendu.
# POUR   : les éditeurs qui empaquettent en dur vers /opt sans offrir de préfixe.
#
# DEUX CONTRAINTES SE CROISENT, ET AUCUNE N'EST UN BOGUE
#   1. /opt est un lien vers var/opt, et RPM REFUSE de dépaqueter à travers un
#      lien symbolique — durcissement délibéré contre une classe de failles :
#          [RPM] failed to open dir opt of /opt/: cpio: mkdir failed - File exists
#   2. /var n'entre pas dans une image bootc. Même en forçant, rien n'y serait.
#
# AVANT D'UTILISER CECI : VÉRIFIER QU'UN PRÉFIXE N'EXISTE PAS.
# Le détour n'a servi qu'à 2 logiciels sur 8. Partout ailleurs un levier
# existait : npm_config_prefix=/usr, code --extensions-dir, un RPM bien fait
# qui vise déjà /usr/bin. Le contrôle coûte une commande ; le détour appliqué
# inutilement ajoute du risque pour rien.
#
# ET LE RÉGLAGE RESTE LOCAL AU SCRIPT. Un « npm config set prefix -g » écrirait
# /etc/npmrc dans l'image et casserait le « npm i -g » de l'utilisateur après le
# démarrage — lui doit viser /usr/local, justement inscriptible une fois la
# machine installée. Ce qu'on force pour construire ne doit jamais devenir la
# configuration de la machine.

detour_opt() {
    # Usage : detour_opt <nom-du-dossier-dans-opt> <paquet> [paquet...]
    local nom="$1"; shift
    local cible

    # Relire la destination, ne JAMAIS la supposer : elle a déjà différé.
    cible="$(readlink /opt || echo var/opt)"

    rm -rf /opt && mkdir -p /opt          # un vrai dossier, le temps du dnf
    dnf5 install -y "$@" || return 1
    mkdir -p /usr/lib/opt
    mv "/opt/${nom}" "/usr/lib/opt/${nom}" || return 1
    rm -rf /opt && ln -s "${cible}" /opt  # remettre comme ostree l'attend

    # Le pont, refait à chaque démarrage. Sans lui, les chemins codés en dur
    # dans le logiciel (/opt/<nom>/...) ne mènent nulle part.
    mkdir -p /usr/lib/tmpfiles.d
    printf 'L  /var/opt/%s  -  -  -  -  /usr/lib/opt/%s\n' "$nom" "$nom" \
        > "/usr/lib/tmpfiles.d/detour-${nom}.conf"

    echo "  detour : /opt/${nom} -> /usr/lib/opt/${nom}, pont posé"
    return 0
}
