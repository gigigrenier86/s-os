# Trouver le /sdcard de Waydroid, et savoir dire POURQUOI on ne le trouve pas.
#
# CE FICHIER EXISTE PARCE QUE LA MEME LOGIQUE VIVAIT EN DEUX EXEMPLAIRES, ET
# QU'ILS ONT DIVERGE. Le 2026-08-25, le raisonnement « les donnees vivent a cote
# de la configuration » a ete corrige dans le mode root de s-partage — et pas
# dans s-monde, que le mode utilisateur appelle. Le service posait donc le
# montage au demarrage, et le geste lance a la main repondait « Waydroid pas
# encore initialise » sur la meme machine, a la meme seconde. s-partage porte en
# tete le commentaire « deux fichiers qui doivent rester d'accord finissent
# toujours par diverger » : c'etait vrai, et il en etait un.
#
# Rien n'est pose ici, aucun dossier n'est cree : ce fichier se source des deux
# cotes du privilege, et sourcer ne doit jamais avoir d'effet.

# Le chemin du /sdcard, ou rien. Prend la maison a examiner en argument, parce
# que root ne peut pas se fier a son propre $HOME.
s_android_media() {
    local maison="${1:-$HOME}" cfg declaree base
    local candidats=()

    # 1. LA TABLE DE MONTAGE D'ABORD, ET C'EST LE POINT DE TOUTE CETTE PASSE.
    #
    # Le dossier de donnees est en 0770 et appartient a un UID d'Android qui
    # n'existe pas sur l'hote — releve sur la machine : « drwxrwx--- ? ? ». Un
    # « test -d .../data/media/0 » lance par l'utilisateur repond donc FAUX,
    # non pas parce que le dossier manque, mais parce qu'on n'a pas le droit
    # de regarder. Le script en concluait « pas encore initialise » : une
    # cause fausse, affirmee avec aplomb, sur une machine ou tout marchait.
    #
    # /proc/self/mountinfo, lui, se lit sans aucun droit sur ce qu'il decrit.
    # Si le montage est la, il porte la reponse et la preuve d'un coup.
    base="$(awk '$5 ~ /\/media\/0\/Partage$/ { sub(/\/Partage$/, "", $5); print $5; exit }' \
        /proc/self/mountinfo 2>/dev/null)"
    [ -n "$base" ] && { printf '%s\n' "$base"; return 0; }

    # 2. Une clef data_path ecrite garde le dernier mot : c'est une decision
    #    explicite, et elle prime sur ce qu'on devine.
    for cfg in /var/lib/waydroid/waydroid.cfg \
               "$maison/.local/share/waydroid/waydroid.cfg"; do
        [ -f "$cfg" ] || continue
        declaree="$(sed -n 's/^[[:space:]]*data_path[[:space:]]*=[[:space:]]*//p' "$cfg" | head -1)"
        [ -n "$declaree" ] && candidats+=("$declaree")
    done

    # 3. Puis les deux endroits ou waydroid 1.6 les pose vraiment. L'ordre
    #    compte : /var/lib/waydroid/data n'existe pas sur cette machine, et
    #    c'etait le seul candidat que l'ancienne deduction savait former.
    candidats+=("$maison/.local/share/waydroid/data" "/var/lib/waydroid/data")

    for base in "${candidats[@]}"; do
        [ -d "$base/media/0" ] && { printf '%s\n' "$base/media/0"; return 0; }
    done
    return 1
}

# Vrai si le montage lie est en place. Se repond depuis la table de montage,
# donc sans aucun droit sur le dossier decrit.
s_android_lie() {
    awk '$5 ~ /\/media\/0\/Partage$/ { trouve = 1; exit } END { exit !trouve }' \
        /proc/self/mountinfo 2>/dev/null
}

# Vrai si Android a bien deplie ses donnees mais qu'on n'a pas le droit d'y
# regarder. C'est le cas normal pour l'utilisateur : le dossier « media » est en
# 0770 sous un UID d'Android. La distinction vaut un message honnete — « je ne
# peux pas voir » n'est pas « il n'y a rien ».
s_android_illisible() {
    local maison="${1:-$HOME}" base
    for base in "$maison/.local/share/waydroid/data" /var/lib/waydroid/data; do
        [ -d "$base" ] || continue
        [ -r "$base/media" ] && [ -x "$base/media" ] && continue
        return 0
    done
    return 1
}
