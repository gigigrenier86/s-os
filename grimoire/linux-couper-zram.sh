#!/usr/bin/bash
# GRIMOIRE — couper le zram avant une grosse écriture
# PREUVE : 2026-08-21. A débloqué l'installation de S, figée 29 minutes.
#          Le correctif d'abord écrit était FAUX (mauvaise unité) et seul le
#          banc l'a montré.
# POUR   : toute opération qui déploie une grosse arborescence sur un système
#          où le swap est un zram — Fedora, Bazzite, la plupart des atomiques.
#
# LA SPIRALE
# Le zram est un swap COMPRESSÉ EN MÉMOIRE VIVE, pas sur disque. Quand un
# déploiement de 16 Go remplit la mémoire, le noyau évacue des pages vers le
# zram — qui consomme lui-même de la RAM pour les stocker compressées. Chaque
# page évacuée aggrave la pénurie qui l'a causée.
#
# SIGNATURE À RECONNAÎTRE : 101 % d'un cœur en continu, ZÉRO E/S sur les
# disques, sshd incapable de répondre. Le « zéro E/S » est le point qui tranche :
# un swap sur disque aurait produit des écritures, le zram non. Libérer de la
# mémoire côté hôte n'y change rien — le problème est DANS l'invité.
#
# DEUX ERREURS À NE PAS REFAIRE
#   1. L'unité à arrêter est « dev-zram0.swap », PAS
#      « systemd-zram-setup@zram0.service ». « swapoff -a » seul désactive le
#      swap une seconde, puis systemd le RÉACTIVE : l'unité .swap reste active
#      et il la remet en service.
#   2. UN CONTRÔLE PRIS TROP TÔT MENT. Le script affichait « swap 0 Mio » juste
#      après le swapoff, et swapon --show rendait de nouveau /dev/zram0 trois
#      minutes plus tard. On vérifie APRÈS un délai.
#
# Sans swap du tout, une pénurie tue le programme franchement au lieu de figer
# la machine. Un échec rapide et lisible vaut mieux qu'un blocage d'une
# demi-heure.

couper_zram() {
    echo "  avant : $(free -m | awk '/^Mem:/ {print $7}') Mio dispo, swap $(free -m | awk '/^Swap:/ {print $2}') Mio"

    # L'ordre compte : arrêter l'unité, la masquer, PUIS swapoff.
    systemctl stop dev-zram0.swap 2>/dev/null || true
    systemctl mask dev-zram0.swap 2>/dev/null || true
    swapoff -a 2>/dev/null || true

    sleep 2   # sans ce délai, le contrôle qui suit ment

    local reste
    reste=$(swapon --show --noheadings 2>/dev/null | wc -l)
    echo "  après : $(free -m | awk '/^Mem:/ {print $7}') Mio dispo, swap $(free -m | awk '/^Swap:/ {print $2}') Mio"
    if [ "$reste" -ne 0 ]; then
        echo "AVERTISSEMENT : un swap est encore actif, le risque de blocage demeure." >&2
        swapon --show >&2
        return 1
    fi
    echo "  swap  : aucun, vérifié après coup"
    return 0
}

rendre_zram() {
    systemctl unmask dev-zram0.swap 2>/dev/null || true
    systemctl start  dev-zram0.swap 2>/dev/null || true
}
