#!/usr/bin/bash
# GRIMOIRE — Proton : lui demander ce qu'il a décidé, au lieu de le deviner
# PREUVE : 2026-08-26, 22 h 30, sur la machine de RyuRex. 32 variables
#          récoltées de UMU-Proton-10.0-4, dont le WINEDLLOVERRIDES qui active
#          DXVK. Le lancement direct qui les rejoue tourne en 0,109 s là où
#          umu-run en coûte 4,7 — même prefixe, même Proton.
# POUR   : quiconque veut exécuter un programme Windows SANS pressure-vessel
#          après que Proton a construit le prefixe, ou simplement savoir ce que
#          Proton pose comme environnement.
#
# LE PROBLÈME
# Proton compose à chaque lancement un environnement que le prefixe ne garde
# pas. La pièce maîtresse est WINEDLLOVERRIDES : c'est elle qui fait préférer
# le DXVK déposé dans system32 au d3d11 interne de Wine. Sans elle, le rendu 3D
# retombe silencieusement sur OpenGL — ça marche, et c'est lent et moche.
#
# LA TENTATION, ET POURQUOI ELLE EST MAUVAISE
# Lire le script `proton`, recopier sa liste de surcharges dans le nôtre. Elle
# change à chaque version, et une liste recopiée ne le dit jamais. C'est la
# faute qui a coûté cinq jours à ce projet sur `waydroid init`.
#
# CE QUI NE MARCHE PAS, ET IL FAUT LE SAVOIR AVANT D'ESSAYER
#   umu-run /usr/bin/env        → zéro ligne, code 0. pressure-vessel ne fait
#                                 pas remonter la sortie standard de façon
#                                 fiable. Succès silencieux dans sa forme pure.
#   PROTON_DUMP_DEBUG_COMMANDS  → absent de la construction umu-proton.
#
# CE QUI MARCHE : passer par un FICHIER, écrit depuis l'intérieur de Windows.

proton_capturer_env() {
    # Usage : proton_capturer_env <prefixe-steam-compat> <chemin-proton> <sortie>
    #
    # Le « prefixe-steam-compat » est ce qu'on donne à STEAM_COMPAT_DATA_PATH :
    # Proton fabrique le vrai prefixe dans « pfx/ » à l'intérieur.
    local compat="$1" proton="$2" sortie="$3"
    local pfx="$compat/pfx" brut

    [ -d "$pfx/drive_c" ] || { echo "ECHEC : $pfx/drive_c absent — prefixe pas construit." >&2; return 1; }
    brut="$pfx/drive_c/capture-env.txt"
    rm -f "$brut"

    WINEPREFIX="$compat" GAMEID="${GAMEID:-umu-0}" UMU_LOG=warn PROTONPATH="$proton" \
        umu-run "$pfx/drive_c/windows/system32/cmd.exe" \
                /c 'set > C:\capture-env.txt' >/dev/null 2>&1

    [ -s "$brut" ] || { echo "ECHEC : rien n'a été capturé." >&2; return 1; }

    # LE FILTRAGE EST OBLIGATOIRE, ET DEUX PIÈGES L'IMPOSENT.
    #
    # 1. « set » vide l'environnement de WINDOWS. Le PATH qu'on y lit vaut
    #    « C:\windows\system32;C:\windows;... ». Le rejouer côté Linux
    #    remplacerait le PATH du système : plus aucune commande ne répondrait.
    #
    # 2. LD_LIBRARY_PATH porte des chemins qui n'existent QUE dans le conteneur
    #    — /usr/lib/pressure-vessel/overrides/…, /ubuntu12_64/. Relevé réel :
    #    dix chemins à la capture, trois après nettoyage.
    tr -d '\r' < "$brut" | awk -F= '
        /^(WINE|PROTON|DXVK_|VKD3D|MEDIACONV_|GST_)/ && $1 != "PATH" {
            nom = $1; sub(/^[^=]*=/, "")
            if (nom == "LD_LIBRARY_PATH") next
            print nom "=" $0
        }
        /^LD_LIBRARY_PATH=/ {
            sub(/^LD_LIBRARY_PATH=/, "")
            n = split($0, m, ":"); garde = ""
            for (i = 1; i <= n; i++)
                if (system("test -d \"" m[i] "\"") == 0)
                    garde = garde (garde == "" ? "" : ":") m[i]
            if (garde != "") print "LD_LIBRARY_PATH=" garde
        }
    ' > "$sortie"
    rm -f "$brut"

    # Une capture sans les surcharges ne vaut rien : c'est ELLE qu'on venait
    # chercher. Mieux vaut le dire que garder un fichier trompeur.
    grep -q '^WINEDLLOVERRIDES=' "$sortie" \
        || { echo "ECHEC : la capture ne porte pas WINEDLLOVERRIDES." >&2; rm -f "$sortie"; return 1; }
    echo "  capturé : $(wc -l < "$sortie") variables dans $sortie"
    return 0
}

# REJOUER LA CAPTURE — et NON, « source » ne convient pas.
# WINEDLLOVERRIDES contient des « ; », que le shell lit comme des séparateurs
# de commandes. Un « . fichier » produit une volée de « commande introuvable »
# et une variable tronquée au premier point-virgule. Ligne à ligne, donc.
proton_charger_env() {
    local fichier="$1" ligne
    [ -s "$fichier" ] || return 1
    while IFS= read -r ligne; do
        [ -n "$ligne" ] || continue
        export "${ligne%%=*}=${ligne#*=}"
    done < "$fichier"
}

# ATTENTION, MESURÉ : umu-run ne peut PAS travailler pendant qu'un wineserver
# tient le prefixe. Proton prend « pfx.lock » et abandonne EN SILENCE —
# soixante secondes, aucune fenêtre, aucun message. Arrêter le serveur avant
# toute capture, et le relancer après.
