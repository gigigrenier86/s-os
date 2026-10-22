#!/usr/bin/bash
# GRIMOIRE — construction : eprouver les controles par motif AVANT de construire
# PREUVE : 2026-08-26, 01 h 30. Une construction de quarante minutes venait de
#          tomber sur « ECHEC : s-ouvrir-exe ne recense pas les protocoles ».
#          Ce balayage, en deux secondes, a designe le meme controle et lui
#          seul — dix autres etaient verts.
# POUR    : tout depot dont les scripts de construction verifient le contenu
#           des fichiers livres par « grep -q '<motif>' <chemin-dans-l-image> ».
#
# LE PROBLEME, ET IL EST INSIDIEUX DANS LES DEUX SENS
#
# Un controle qui cherche une chaine dans un fichier de l'image se desynchronise
# des qu'on reecrit ce fichier. Il tombe alors dans un des deux pieges :
#
#   FAUX NEGATIF  le motif ne matche plus alors que le code est juste, et la
#                 construction echoue sans que rien ne soit casse. Vecu le
#                 2026-08-26 : le geste appelait
#                 « "$S_GESTES/s-lien-windows" --recenser » quand le controle
#                 cherchait « s-lien-windows --recenser ». Un GUILLEMET
#                 FERMANT au milieu, et la sous-chaine n'existait plus.
#
#   FAUX POSITIF  le motif matche une PHRASE DE COMMENTAIRE et le controle
#                 passe alors que l'appel a disparu. Vecu deux fois dans ce
#                 depot : le garde-fou de plasma_waitforname lisait sa propre
#                 documentation, et un controle sur « s-partage » a survecu au
#                 demenagement de l'appel qu'il surveillait.
#
# LE MOYEN LE PLUS COURT DE LES ATTRAPER : rejouer chaque motif contre le
# fichier que l'image livrera VRAIMENT, avant de construire quoi que ce soit.
#
# ET LA LECON QUI VA AVEC : le jour ou ce controle est tombe, un rejeu ciblé
# avait ete fait — mais il ne rejouait que le bloc AJOUTE, jamais le fichier
# entier. Un rejeu partiel ne prouve que la partie qu'il rejoue.

eprouver_les_motifs() {
    # Usage : eprouver_les_motifs <dossier-des-scripts> <racine-des-fichiers>
    #   ex.  eprouver_les_motifs build_files files
    # « racine » est le dossier dont le contenu sera copie a la racine de
    # l'image : files/usr/bin/x correspond a /usr/bin/x dans l'image.
    local scripts="${1:-build_files}" racine="${2:-files}"
    local total=0 rates=0

    while IFS= read -r ligne; do
        local motif cible drapeaux local_f
        motif=$(printf '%s' "$ligne" | sed -E "s/.*'([^']+)'.*/\1/")
        cible=$(printf '%s' "$ligne" | grep -oE '/usr/(bin|lib|share|libexec)/[^ ;]+')
        drapeaux=$(printf '%s' "$ligne" | grep -oE 'grep -q[a-zA-Z]*' | sed 's/grep -q//')
        local_f="$racine$cible"

        # Un chemin absent de « racine » vient de la base ou d'un paquet : ce
        # balayage n'a rien a en dire, et le passer sous silence vaut mieux que
        # de crier au loup.
        [ -f "$local_f" ] || continue
        total=$((total + 1))

        if grep -q${drapeaux} -- "$motif" "$local_f" 2>/dev/null; then
            printf '  OK  %-30s <- %.46s\n' "$(basename "$cible")" "$motif"
        else
            printf '  !!  %-30s <- %.46s   ECHOUERAIT\n' "$(basename "$cible")" "$motif"
            rates=$((rates + 1))
        fi
    done < <(grep -hoE "grep -q[a-zA-Z]* (--)? *'[^']+' +/usr/(bin|lib|share|libexec)/[^ ;]+" \
                 "$scripts"/*.sh 2>/dev/null | sort -u)

    if [ "$rates" -gt 0 ]; then
        echo "  $rates controle(s) sur $total tomberaient a la construction." >&2
        return 1
    fi
    echo "  $total controle(s) par motif, tous verts."
    return 0
}

# CE QUE CE BALAYAGE NE VOIT PAS, et il faut le savoir :
#   - les controles ecrits avec des guillemets DOUBLES ;
#   - ceux dont le chemin est dans une variable ;
#   - « test -s », « command -v », et tout ce qui ne cherche pas une chaine ;
#   - un motif JUSTE qui matche un commentaire — le faux positif reste a la
#     charge de qui ecrit le controle : ancrer sur « ^\s* » et sur l'appel.
