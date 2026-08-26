#!/usr/bin/bash
# SORTIR L'ICONE D'UN PROGRAMME WINDOWS, ET LA POSER LA OU S LA CHERCHE.
#
# DEMANDE DE L'UTILISATEUR, 2026-08-26. Tout lanceur pose par s-menu-windows
# portait « Icon=application-x-executable » : la meme icone grise pour PURPLE,
# pour Cursor et pour n'importe quel .exe. Le menu disait le GENRE et jamais
# LEQUEL — exactement le defaut deja corrige pour les etoiles le 2026-08-23,
# reste entier du cote Windows.
#
# L'ICONE EST DANS LE FICHIER. Tout binaire Windows la porte dans sa section de
# ressources : un RT_GROUP_ICON (type 14) qui liste les tailles, et un RT_ICON
# par taille. Ce n'est pas une convention de nommage, c'est le format PE.
#
# ON N'ECRIT PAS D'ANALYSEUR PE. « icoutils » le fait depuis vingt ans, il est
# deja sur cette machine (icoutils-0.32.3, /usr/bin/wrestool et /usr/bin/icotool)
# et il est dans Fedora. On ne reimplemente pas ce que l'amont maintient — la
# regle que ce projet a payee cinq jours.
#
# CE QUE CA NE PEUT PAS FAIRE, ET IL FAUT LE DIRE : un .exe qui ne CONTIENT pas
# d'icone n'en donnera pas. Mesure du 2026-08-26 : PURPLE en rend neuf tailles
# jusqu'a 256, Cursor deux jusqu'a 512, et les deux projets .NET de
# l'utilisateur en rendent zero — leur .csproj ne porte pas
# « <ApplicationIcon> ». Ce n'est pas un defaut de S, et le repli generique
# reste juste dans ce cas-la.

# Ou S cherche une icone par son nom — voir noyau.py, dossiers_icones().
S_ICONES="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"

# --------------------------------------------------------------------------
# s_icone_exe <chemin-du-exe> <identifiant>
#
# Rend l'identifiant sur la sortie standard si une icone a ete posee, rien
# sinon. L'appelant met ce qu'il recoit dans « Icon= » et garde son repli quand
# la sortie est vide.
# --------------------------------------------------------------------------
s_icone_exe() {
    local exe="$1" ident="$2" travail deja taille source cible
    [ -f "$exe" ] || return 1
    [ -n "$ident" ] || return 1
    command -v wrestool >/dev/null 2>&1 || return 1
    command -v icotool  >/dev/null 2>&1 || return 1

    # DEJA POSEE ET PLUS RECENTE QUE LE PROGRAMME : on ne refait rien.
    # Ce geste tourne apres CHAQUE lancement de .exe ; extraire a chaque fois
    # couterait une seconde pour rien. Mais on compare les dates plutot que la
    # simple existence : une mise a jour du logiciel change souvent son icone.
    deja="$(find "$S_ICONES" -name "$ident.png" -newer "$exe" -print -quit 2>/dev/null)"
    if [ -n "$deja" ]; then printf '%s' "$ident"; return 0; fi

    travail="$(mktemp -d)" || return 1
    # « -t 14 » : le groupe d'icones. C'est lui qui reference les tailles ; en
    # extrayant les RT_ICON un par un (type 3) on obtient des images orphelines
    # dont on ignore la palette.
    wrestool -x -t 14 -o "$travail" "$exe" 2>/dev/null
    icotool -x -o "$travail" "$travail"/*.ico 2>/dev/null

    # LA MEILLEURE IMAGE, ET « MEILLEURE » SE DEFINIT. icotool nomme ses
    # sorties « <base>_<n>_<L>x<H>x<profondeur>.png ». On trie sur la largeur
    # puis sur la profondeur de couleur : une icone 32x32 en 32 bits vaut mieux
    # qu'une 32x32 en 4 bits, et une 256 vaut mieux que les deux.
    source="$(ls "$travail"/*.png 2>/dev/null \
        | sed -E 's/.*_([0-9]+)x[0-9]+x([0-9]+)\.png$/\1 \2 &/' \
        | grep -E '^[0-9]+ [0-9]+ ' \
        | sort -k1,1nr -k2,2nr | head -1 | cut -d' ' -f3-)"

    if [ -z "$source" ] || [ ! -s "$source" ]; then
        rm -rf "$travail"; return 1
    fi

    taille="$(basename "$source" | sed -E 's/.*_([0-9]+)x[0-9]+x[0-9]+\.png$/\1/')"
    case "$taille" in ''|*[!0-9]*) taille=48 ;; esac

    cible="$S_ICONES/${taille}x${taille}/apps"
    mkdir -p "$cible"
    if install -m 0644 "$source" "$cible/$ident.png" 2>/dev/null; then
        rm -rf "$travail"
        printf '%s' "$ident"
        return 0
    fi
    rm -rf "$travail"
    return 1
}
