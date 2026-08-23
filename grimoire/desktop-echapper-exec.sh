#!/usr/bin/bash
# GRIMOIRE — écrire un chemin dans une ligne « Exec= » de .desktop, correctement
# PREUVE : 2026-08-23. Banc d'aller-retour, 6 chemins sur 6 relus à l'identique,
#          y compris « x/tout\a$b`c"d e/f.exe » qui porte les cinq caractères
#          pièges à la fois. Le décodeur du banc suit les règles de
#          g_shell_parse_argv, pas « shlex » de Python — voir plus bas.
# POUR   : tout script qui fabrique un lanceur pointant sur un chemin qu'il n'a
#          pas choisi : moisson de raccourcis Windows, export de conteneur,
#          AppImage rangée par l'utilisateur.
#
# CE QUI ÉTAIT FAUX, ET QUI A COÛTÉ UNE PANNE MUETTE
# « printf %q » semble fait pour ça et ne l'est pas. Sur « Program Files », il
# produit « Program\ Files ». Or la spécification Desktop Entry n'admet, dans
# une valeur de type string, QUE les séquences \s \n \t \r et \\ — « \ » suivi
# d'un espace n'en est pas une, et GLib rejette alors la valeur ENTIÈRE. Le
# lanceur existe, il s'affiche, et rien ne le lance. Trouvé dans s-menu-windows
# le 2026-08-23, sur un VLC installé qui n'apparaissait nulle part.
#
# LA RÈGLE RÉELLE EST À DEUX ÉTAGES, ET C'EST CE QUI LA REND PIÉGEUSE
#   1. Champ Exec : un argument à espaces se met entre guillemets doubles, et
#      les caractères " ` $ \ s'y protègent par une barre inverse.
#   2. Cette barre inverse vit dans une valeur de .desktop, où toute barre
#      inverse s'écrit DOUBLÉE.
# La spécification le dit elle-même : « to unambiguously represent a literal
# backslash character in a quoted argument requires the use of four successive
# backslash characters ». Une barre inverse du chemin ressort donc en quatre.
#
#   chemin        ->  dans le fichier
#   \             ->  \\\\
#   "             ->  \\"
#   $             ->  \\$
#   `             ->  \\`
#   espace        ->  rien (les guillemets suffisent)
#
# ET NE PAS VÉRIFIER AVEC « shlex » DE PYTHON : il n'applique pas les règles du
# shell dans les guillemets doubles (une barre inverse devant un accent grave y
# survit), et il ferait échouer un échappement correct. Le vrai découpeur est
# g_shell_parse_argv : dans des guillemets doubles, la barre inverse ne protège
# que $ ` " \ et le saut de ligne.

echapper_exec() {
    printf '%s' "$1" | sed -e 's/\\/\\\\\\\\/g' \
                           -e 's/"/\\\\"/g' \
                           -e 's/\$/\\\\$/g' \
                           -e 's/`/\\\\`/g'
}

# Usage :
#   printf 'Exec=%s "%s"\n' /usr/bin/mon-lanceur "$(echapper_exec "$chemin")"
#
# Le contrôle qui coûte une seconde et qui aurait évité la panne :
#   command -v desktop-file-validate >/dev/null && desktop-file-validate "$f"
