#!/usr/bin/bash
# GRIMOIRE — piloter un Android LXC natif (etat, commande, installation,
#            lancement) sans une ligne de l'outillage Python Waydroid.
# PREUVE : 2026-08-29, sur `s`. Chaine complete eprouvee a l'ecran :
#              etat_android            -> STOPPED puis RUNNING, les deux mesures
#              dans_android settings   -> reglages poses (via s-android)
#              installer_android       -> « Success », F-Droid 12 Mo pose en
#                                         flux stdin, verifie par pm path
#              lancer_android          -> « Starting: Intent { cmp=org.fdroid.
#                                         fdroid/.views.main.MainActivity } »,
#                                         fenetre kwin passee de « Waydroid »
#                                         a « waydroid.org.fdroid.fdroid |
#                                         F-Droid », catalogue rendu, capture
#                                         a l'appui (android-fdroid.png)
# POUR   : toute couture qui parle au conteneur `android` de s-android.service
#          — c'est la copie de reference des fonctions de
#          files/usr/lib/s/partage-android.sh, avec les quatre pieges payes.
#
# LES QUATRE PIEGES, CHACUN MESURE LE 2026-08-29 :
#
# 1. « lxc-info » SANS PRIVILEGE NE MARCHE QUE CONTENEUR ARRETE. Arrete, il
#    repond « State: STOPPED » proprement ; EN MARCHE, il repond « Insufficent
#    privileges to control » — le socket de commande appartient a root. Un
#    temoin qui ne fonctionne que dans l'etat qu'on ne cherche pas ne mesure
#    rien : la premiere version attendait RUNNING sur une reponse qui ne
#    pouvait jamais le dire. Le temoin juste est systemd (« is-active » se lit
#    sans droit, et le service est l'unique proprietaire de lxc-start).
#
# 2. « lxc-attach » CHOWNE SON STDOUT — deja documente dans s-monde le
#    2026-08-26 pour « waydroid shell » (qui l'appelait), re-paye deux fois
#    sur le banc de cette passe : le fichier de capture du banc est devenu
#    root:0600 en un appel. TOUJOURS un tuyau (« | cat », « | s_tee »),
#    JAMAIS une redirection vers un fichier qu'on veut garder.
#
# 3. « pm install -S <taille> - » : LE TIRET FINAL EST REFUSE sur cette image
#    (Android 13 / LineageOS 20) — « Unknown option - ». La forme flux est
#    « pm install -S <taille> » SEUL, l'APK sur l'entree standard (la meme
#    que « adb install » emploie). L'APK ne quitte jamais l'hote.
#
# 4. « am start » SORT EN 0 MEME QUAND IL ECHOUE (« Error: Activity not
#    started », code 0). Le verdict se lit dans sa sortie. Et il ne suffit
#    pas : hwcomposer.waydroid.so ne cree une fenetre Wayland que d'apres la
#    propriete « waydroid.active_apps » (lue dans sa table des symboles,
#    extraite de vendor.img par debugfs sans montage) — sans « setprop
#    waydroid.active_apps <paquet> », une activite peut tourner au premier
#    plan SANS aucune fenetre a l'ecran. Valeur sentinelle « Waydroid » =
#    interface complete.
#
# NOTE : « monkey », le lanceur classique d'AOSP, est un wrapper bash INERTE
# sur cette image (il rend « bash arg: ... » sans rien lancer) — ne pas s'y
# fier.

LXCPATH_ANDROID=/var/lib/waydroid/lxc

# RUNNING / STOPPED / vide. Aucun privilege.
etat_android() {
    if systemctl is-active --quiet s-android.service 2>/dev/null; then
        printf 'RUNNING\n'
    elif [ -f /var/lib/waydroid/images/system.img ]; then
        printf 'STOPPED\n'
    fi
}

# Une commande dans le conteneur EN MARCHE. Exige root (CAP_SYS_ADMIN pour
# setns dans un conteneur non user-namespace — pas SELinux, verifie zero AVC).
dans_android() {
    pkexec lxc-attach -P "$LXCPATH_ANDROID" -n android -- "$@"
}

# Un APK depuis l'hote, en flux. Piege 3.
installer_android() {
    local apk="$1" taille
    taille="$(stat -c%s "$apk")" || return 1
    pkexec /usr/bin/sh -c \
        "lxc-attach -P '$LXCPATH_ANDROID' -n android -- pm install -S '$taille'" \
        < "$apk"
}

# Lancer par paquet. Pieges 4 (active_apps + verdict par la sortie).
lancer_android() {
    dans_android sh -c '
        paquet="$1"
        resolu="$(cmd package resolve-activity --brief "$paquet" 2>/dev/null | tail -1)"
        case "$resolu" in
            */*) ;;
            *) echo "aucune activite de lancement pour $paquet" >&2; exit 1 ;;
        esac
        setprop waydroid.active_apps "$paquet"
        sortie="$(am start -n "$resolu" 2>&1)"
        printf "%s\n" "$sortie"
        case "$sortie" in *Error*) exit 1 ;; esac
        exit 0
    ' lanceur "$1"
}
