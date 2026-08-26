#!/usr/bin/bash
# GRIMOIRE — Wine : une police copiée n'existe pas tant qu'elle n'est pas déclarée
# PREUVE : 2026-08-26, 23 h 25, sur la machine de RyuRex. 26 polices copiées
#          dans C:\windows\Fonts : AUCUN changement à l'écran. Les mêmes,
#          déclarées au registre : toutes les icônes d'un logiciel WPF
#          apparaissent. Captures dans galerie/windows/.
# POUR    : tout prefixe Wine où un logiciel demande une police par son nom —
#           Segoe UI, Segoe Fluent Icons, Consolas, une police d'entreprise.
#
# LE PROBLÈME
# Déposer un .ttf dans C:\windows\Fonts semble suffire. Ça ne l'est pas, et
# l'échec est muet : le logiciel affiche des carrés vides (U+25A1) là où il
# attend ses glyphes, et rien nulle part ne dit pourquoi.
#
# « wineboot -u » n'y change rien non plus — relevé : 549 entrées de police au
# registre avant, 549 après.
#
# CE QU'IL FAUT, et c'est ce que fait winetricks dans w_register_font :
#     HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts
#     HKLM\Software\Microsoft\Windows\CurrentVersion\Fonts
#         "<Nom de famille> (TrueType)" = "<fichier.ttf>"
# Deux clés, pas une.
#
# ET LE PIÈGE PRINCIPAL EST LÀ : le nom ne se déduit PAS du fichier.
#     SegoeIcons.ttf  →  "Segoe Fluent Icons"
#     segmdl2.ttf     →  "Segoe MDL2 Assets"
#     seguisb.ttf     →  "Segoe UI Semibold"
#     cambria.ttc     →  "Cambria" ET "Cambria Math"   (une collection)
# Aucune règle ne relie les deux. Le nom vit dans la table « name » du fichier.
#
# LA LICENCE, ET ELLE N'EST PAS UN DÉTAIL
# Segoe appartient à Microsoft. Emprunter les polices du Windows installé SUR
# LA MÊME MACHINE, vers le prefixe du même utilisateur, ne redistribue rien.
# Les publier dans un dépôt, si. La recette se publie ; les polices, jamais.

declarer_polices() {
    # Usage : declarer_polices <prefixe-wine> <chemin-de-polices.py> <binaire-wine>
    local pfx="$1" lecteur="$2" wine="$3"
    local dossier="$pfx/drive_c/windows/Fonts" reg n
    [ -d "$dossier" ] || { echo "ECHEC : $dossier absent." >&2; return 1; }
    [ -f "$lecteur" ] || { echo "ECHEC : lecteur de noms absent." >&2; return 1; }

    reg="$(mktemp)"
    _lister() {
        python3 "$lecteur" "$dossier"/*.ttf "$dossier"/*.ttc "$dossier"/*.TTF 2>/dev/null \
            | while IFS=$'\t' read -r nom fichier; do
                  printf '"%s (TrueType)"="%s"\n' "$nom" "$fichier"
              done
    }
    {
        printf 'REGEDIT4\n\n'
        printf '[HKEY_LOCAL_MACHINE\\\\Software\\\\Microsoft\\\\Windows NT\\\\CurrentVersion\\\\Fonts]\n'
        _lister
        printf '\n[HKEY_LOCAL_MACHINE\\\\Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Fonts]\n'
        _lister
    } > "$reg"

    n=$(( $(grep -c '(TrueType)' "$reg") / 2 ))
    WINEPREFIX="$pfx" WINEDEBUG=-all "$wine" regedit "$reg" >/dev/null 2>&1
    rm -f "$reg"
    echo "  $n police(s) déclarée(s)"

    # LE REGISTRE VIT DANS LE SERVEUR, PAS SUR LE DISQUE. Vérifier system.reg
    # juste après regedit rend zéro : Wine ne l'écrit qu'à la sortie du
    # wineserver. « wineserver -k » force l'écriture — indispensable si la
    # vérification suit immédiatement.
    return 0
}

# Le lecteur de noms lui-même : voir files/usr/lib/s/polices.py dans ce dépôt.
# Trente lignes, aucune dépendance, gère les collections .ttc.
