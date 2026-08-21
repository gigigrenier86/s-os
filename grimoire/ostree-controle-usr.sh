#!/usr/bin/bash
# GRIMOIRE — ostree : refuser une image creuse
# PREUVE : 2026-08-20, posé dans les huit scripts de construction de S.
#          Aucune image creuse livrée depuis.
# POUR   : tout Containerfile bâti sur une base atomique (bootc, ostree,
#          Fedora Silverblue/Kinoite, Bazzite, CentOS bootc).
#
# LE PROBLÈME, ET IL EST SOURNOIS
# Sur ostree, tout ce qui est modifiable est un lien vers /var :
#     /opt -> var/opt        /home -> var/home       /root -> var/roothome
#     /usr/local -> ../var/usrlocal                  /srv  -> var/srv
# et /var N'ENTRE PAS DANS L'IMAGE. Il est propre à la machine, recréé à
# l'installation.
#
# Conséquence : forcer une installation vers /opt ou /usr/local RÉUSSIT. La
# construction est verte, l'image est livrée, et elle ne contient rien. Le
# contenu se comporte comme un volume Docker — déversé à l'installation
# initiale seulement, figé à cette version, et totalement absent pour une
# machine qui se met à jour.
#
# Un échec bruyant se corrige. Celui-là se découvre trois mois plus tard.
#
# /etc est l'exception salutaire : ce n'est PAS un lien, il est stocké dans le
# commit sous /usr/etc et fusionné au déploiement. Emplacement sûr — d'où
# /etc/skel.

controler_hors_usr() {
    # Usage : controler_hors_usr paquet1 paquet2 ...
    local fautifs
    fautifs=$(rpm -ql "$@" 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/' || true)
    if [ -n "$fautifs" ]; then
        echo "ECHEC : ces fichiers sont hors /usr et /etc, ils ne survivront pas." >&2
        echo "$fautifs" | head -20 >&2
        echo "        voir grimoire/ostree-detour-opt.sh pour le contournement" >&2
        return 1
    fi
    echo "  controle : tout est dans /usr ou /etc"
    return 0
}

# Variante sans rpm — pour un dépliage manuel, un npm, une archive.
controler_arborescence() {
    # Usage : controler_arborescence   (après installation, avant la fin du RUN)
    local fautifs
    fautifs=$(find /opt /usr/local /var -mindepth 1 -maxdepth 3 \
                   -not -path '/var/cache/*' -not -path '/var/tmp/*' \
                   -not -path '/var/log/*' 2>/dev/null | head -20 || true)
    if [ -n "$fautifs" ]; then
        echo "ECHEC : du contenu a été posé hors /usr et /etc :" >&2
        echo "$fautifs" >&2
        return 1
    fi
    echo "  controle : /opt, /usr/local et /var sont vides"
    return 0
}
