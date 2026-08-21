#!/usr/bin/bash
# GRIMOIRE — savoir AVANT d'engager si un disque acceptera l'écriture
# PREUVE : 2026-08-20/21. A intercepté le mur nº 3 (volume Windows encore monté)
#          avant le téléchargement, là où l'échec serait survenu 40 minutes plus
#          tard en laissant le disque sans table ET sans système.
# POUR   : toute écriture brute sur un disque physique, en particulier depuis
#          une machine virtuelle qui ne voit pas ce que l'hôte tient ouvert.
#
# LE PIÈGE, ET IL ÉCHOUE À MOITIÉ — C'EST LE PIRE CAS
# Côté Linux, « aucun montage » ne prouve rien : le volume peut être monté côté
# WINDOWS, invisible d'ici. Windows refuse alors toute écriture par handle de
# DISQUE sur les secteurs couverts par ce volume — mais AUTORISE les secteurs
# 0 à 2047, qui sont hors partition.
#
# Résultat sans sonde : la table de partition s'écrit, puis l'écriture de l'ESP
# est refusée. Après le téléchargement. Le disque reste sans table et sans
# système, et Windows l'annonce « non initialisé ».
#
# Et retirer la lettre ne démonte PAS le volume : ça enlève le point de montage,
# pas le montage. Mesuré, QEMU tenant déjà le disque ouvert : mountvol annonçait
# « Aucun point de montage » tandis que Get-Volume rendait encore un système de
# fichiers sain avec son espace libre vivant. Il faut SUPPRIMER LA PARTITION.
#
# LA SONDE NE DÉTRUIT RIEN : elle relit un secteur et le réécrit à l'identique.

sonder_ecriture() {
    # Usage : sonder_ecriture <peripherique> <secteur> <etiquette>
    local cible="$1" secteur="$2" etiq="$3"
    local tmp; tmp=$(mktemp)

    if ! dd if="$cible" of="$tmp" bs=512 count=1 skip="$secteur" \
            iflag=direct status=none 2>"${tmp}.err"; then
        echo "ARRET : lecture impossible du secteur $secteur ($etiq)." >&2
        cat "${tmp}.err" >&2; rm -f "$tmp" "${tmp}.err"; return 1
    fi
    if ! dd if="$tmp" of="$cible" bs=512 count=1 seek="$secteur" \
            oflag=direct conv=fsync status=none 2>"${tmp}.err"; then
        echo "ARRET : la cible refuse l'écriture ($etiq)." >&2
        cat "${tmp}.err" >&2
        echo "Un volume est probablement encore monté côté hôte." >&2
        rm -f "$tmp" "${tmp}.err"; return 1
    fi
    rm -f "$tmp" "${tmp}.err"
    return 0
}

sonder_disque() {
    # Usage : sonder_disque <peripherique>
    # Vise les deux secteurs qui comptent : le premier que l'installateur
    # écrira, et le dernier, où va l'en-tête GPT de secours.
    local cible="$1" taille dernier
    taille=$(blockdev --getsize64 "$cible") || return 1
    dernier=$(( taille / 512 - 1 ))
    sonder_ecriture "$cible" 2048      "début de partition, là où ira l'ESP" || return 1
    sonder_ecriture "$cible" "$dernier" "dernier secteur, GPT de secours"    || return 1
    echo "  écriture : autorisée (secteurs 2048 et $dernier)"
    return 0
}

# --- Et pour identifier la cible sans se tromper de disque -----------------
# Trois preuves indépendantes valent mieux qu'un nom de périphérique, qui bouge
# entre deux branchements. La taille à l'octet est la plus forte : deux disques
# de modèles différents ne la partagent jamais par accident.
identifier_cible() {
    # Usage : identifier_cible <peripherique> <taille_attendue_en_octets>
    local cible="$1" attendue="$2" taille racine
    [ -b "$cible" ] || { echo "ARRET : $cible n'est pas un périphérique bloc." >&2; return 1; }

    taille=$(blockdev --getsize64 "$cible")
    if [ "$taille" != "$attendue" ]; then
        echo "ARRET : taille $taille, attendu $attendue. Ce n'est pas la cible." >&2
        return 1
    fi

    racine=$(findmnt -n -o SOURCE / 2>/dev/null)
    case "$racine" in
        *"${cible#/dev/}"*) echo "ARRET : la cible porte la racine du système." >&2; return 1 ;;
    esac

    if findmnt -n -S "$cible" >/dev/null 2>&1 || findmnt -n -S "${cible}1" >/dev/null 2>&1; then
        echo "ARRET : la cible porte un système de fichiers monté." >&2
        return 1
    fi
    echo "  cible : $cible, $taille octets, non montée, ne porte pas la racine"
    return 0
}
