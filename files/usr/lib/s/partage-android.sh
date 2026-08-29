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

# --- Etat et execution du conteneur natif, sans l'outillage waydroid --------
#
# LE PAQUET « waydroid » A ETE RETIRE LE 2026-08-29 (rpm -qa le confirme
# absent, « which waydroid » ne rend rien) : sa CLI (status, shell, prop, app
# install/launch, show-full-ui) n'existe plus DU TOUT sur cette machine.
# Android tourne desormais par lxc-start direct (android-lancer.sh,
# s-android.service) — les gestes qui s'appuyaient encore sur cette CLI
# attendaient un binaire disparu, EN SILENCE (« command not found » sur
# stderr, avale par 2>/dev/null ; « grep -qi RUNNING » sur une sortie vide
# rend faux sans un mot) : cliquer « Android » bloquait deux minutes pour finir
# sur « Android n'a pas demarre ».
#
# LXCPATH N'EST PAS LE DEFAUT DE LXC. android-lancer.sh cree le conteneur
# dans /var/lib/waydroid/lxc (repris tel quel de l'ancien outillage, pour que
# les donnees existantes n'aient rien a bouger) — sans -P, lxc-info et
# lxc-attach repondent tous deux « android doesn't exist ».
S_ANDROID_LXCPATH=/var/lib/waydroid/lxc
S_ANDROID_PROP=/var/lib/waydroid/waydroid.prop

# RUNNING, STOPPED, ou une chaine vide si Android n'existe pas du tout ici.
#
# PAS lxc-info, ET C'EST UNE MESURE DU 2026-08-29 QUI A TUE LA PREMIERE
# FORME. « lxc-info -P .../lxc -n android » sans privilege repond
# « State: STOPPED » proprement quand le conteneur est ARRETE — mais des
# qu'il TOURNE, il repond « Insufficent privileges to control android » : le
# socket de commande du conteneur appartient a root. Un temoin qui ne
# fonctionne que dans l'etat qu'on ne cherche pas ne mesure rien — la
# premiere version de cette fonction attendait RUNNING sur une reponse qui
# ne pouvait jamais le dire, et « Android n'a pas demarre » tombait sur un
# Android parfaitement vivant (DHCP negocie, zygote en route).
#
# LE TEMOIN JUSTE EST SYSTEMD : s-android.service est desormais l'unique
# proprietaire de lxc-start (Type simple, ExecStart= est lxc-start lui-meme
# via android-lancer.sh), donc « active » = conteneur en marche, et
# « is-active » se lit sans aucun droit.
s_android_etat() {
    if systemctl is-active --quiet s-android.service 2>/dev/null; then
        printf 'RUNNING\n'
    elif [ -f /var/lib/waydroid/images/system.img ]; then
        printf 'STOPPED\n'
    fi
}

# Une commande a l'INTERIEUR du conteneur EN MARCHE — l'equivalent natif de
# « waydroid shell ». EXIGE ROOT, ET CE N'EST PAS SELINUX : lxc-attach doit
# faire setns(2) dans les espaces de noms d'un conteneur root sans
# lxc.idmap (verifie le 2026-08-29 : aucune regle de s_android.te ne bloque
# unconfined_t sur ce chemin — c'est CAP_SYS_ADMIN que seul root possede).
# Passe donc TOUJOURS par s_root, exactement comme l'ancien « waydroid shell »
# l'etait deja.
#
#   s_android_dans <commande...>                limite par defaut : 120 s
#   s_android_dans --limite 300 <commande...>   pour un install/pm plus long
s_android_dans() {
    local limite=120
    if [ "${1:-}" = "--limite" ]; then limite="$2"; shift 2; fi
    s_root --limite "$limite" lxc-attach -P "$S_ANDROID_LXCPATH" -n android -- "$@"
}

# Lit une propriete de DEMARRAGE (densite, mode fenetre, largeur/hauteur).
# SANS PRIVILEGE : le fichier est root:root en 0644 — verifie le 2026-08-29.
# C'EST CE FICHIER, ET PAS UN AUTRE, QU'ANDROID LIT VRAIMENT.
# android-lancer.sh le bind-monte tel quel dans le conteneur
# (« mount -o bind /var/lib/waydroid/waydroid.prop $ROOTFS/vendor/waydroid.prop »)
# — jamais waydroid.cfg (mort avec le paquet, plus rien ne le lit), jamais
# waydroid_base.prop (vestige de l'ancien outillage Python, present sur cette
# machine mais que android-lancer.sh ne monte nulle part).
s_android_prop_lire() {
    sed -n "s/^${1}=//p" "$S_ANDROID_PROP" 2>/dev/null | tail -1
}

# Ecrit une ou plusieurs proprietes de demarrage, cle=valeur. EXIGE ROOT (le
# fichier appartient a root) — mais JAMAIS de lxc-attach : une propriete de
# demarrage est une simple ecriture de fichier hote, pas un dialogue avec le
# conteneur. NE PREND EFFET QU'AU PROCHAIN DEMARRAGE DU CONTENEUR — mesure du
# 2026-08-25, toujours vraie ici puisque rien ne relit ce fichier a chaud.
# L'appelant decide s'il redemarre le service ensuite.
#
#   s_android_prop_ecrire "ro.sf.lcd_density=140" "persist.waydroid.multi_windows=false"
s_android_prop_ecrire() {
    s_root /usr/bin/python3 - "$S_ANDROID_PROP" "$@" <<'PY' 2>/dev/null
import os
import sys

chemin = sys.argv[1]
paires = dict(a.split("=", 1) for a in sys.argv[2:])

try:
    with open(chemin, encoding="utf-8") as f:
        brutes = f.read().splitlines()
except FileNotFoundError:
    brutes = []

lignes = []
vues = set()
for ligne in brutes:
    cle = ligne.split("=", 1)[0] if "=" in ligne else None
    if cle in paires:
        lignes.append("%s=%s" % (cle, paires[cle]))
        vues.add(cle)
    else:
        lignes.append(ligne)
for cle, valeur in paires.items():
    if cle not in vues:
        lignes.append("%s=%s" % (cle, valeur))

tmp = chemin + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write("\n".join(lignes) + "\n")
os.replace(tmp, chemin)
PY
}

# --- Installer et lancer, forges depuis les outils AOSP standards -----------
#
# « waydroid app install » et « waydroid app launch »/« show-full-ui »
# n'avaient rien de magique cote Android : ils appelaient deja les memes
# outils qu'on rappelle ici directement — pm, am, cmd — livres par
# system.img, jamais touches par le retrait du paquet waydroid. FORGE LE
# 2026-08-29, JAMAIS EPROUVE SUR CETTE MACHINE : la syntaxe exacte peut
# demander un reglage au premier essai reel.

# Installe un APK SANS le faire quitter l'hote : « pm install -S <taille> »
# SANS argument de chemin lit le paquet depuis son entree standard, ce qui
# evite d'avoir a rendre le fichier visible dans l'espace de montage du
# conteneur. PAS de « - » final : mesure du 2026-08-29 sur cette image
# (Android 13/LineageOS 20), le parseur de pm le rejette — « Unknown
# option - » — la ou « -S <taille> » seul va jusqu'a parser les octets
# recus. C'est la meme forme que celle d'« adb install » en flux.
s_android_installer() {
    local apk="$1" taille
    taille="$(stat -c%s "$apk")" || return 1
    s_root --limite 180 /usr/bin/sh -c \
        "lxc-attach -P '$S_ANDROID_LXCPATH' -n android -- pm install -S '$taille'" \
        < "$apk"
}

# Lance une application par son paquet — l'equivalent de « waydroid app
# launch ». Deux gestes indissociables, mesures dans le binaire du
# compositeur le 2026-08-29 (« strings » sur hwcomposer.waydroid.so extrait
# de vendor.img : « waydroid.active_apps » y est en clair) :
#
#   1. setprop waydroid.active_apps <paquet> — c'est CETTE propriete que
#      hwcomposer lit pour decider QUELLE fenetre Wayland creer (ses modes :
#      closed / single_window / multi_window / full_ui). Sans elle, une
#      activite peut tourner au premier plan d'Android SANS qu'aucune
#      fenetre n'apparaisse a l'ecran — conteneur RUNNING, ecran vide,
#      exactement le symptome qu'on repare. L'ancien outillage la posait a
#      chaque « app launch » ; on la pose pareil.
#   2. am start — met vraiment l'activite au premier plan.
#
# UN SEUL lxc-attach pour le tout, et ce n'est pas une optimisation
# gratuite : chaque s_android_dans est un pkexec, donc UNE demande de mot de
# passe — des appels separes en feraient plusieurs d'affilee pour un clic.
# Le paquet passe en argument positionnel du sh interne, jamais interpole
# dans le texte du script : rien de ce qui vient du dehors n'y entre.
# « am start » SORT EN 0 MEME QUAND IL ECHOUE — mesure du 2026-08-29 :
# « Error: Activity not started, unable to resolve Intent », code 0. Le
# verdict se lit donc dans sa SORTIE, pas dans son code : toute ligne
# « Error » fait rendre 1.
s_android_lancer() {
    s_android_dans sh -c '
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

# L'interface complete d'Android (lanceur, barre d'etat) — l'equivalent de
# « waydroid show-full-ui ». La valeur sentinelle « Waydroid » est celle que
# l'ancien outillage posait pour ce mode ; hwcomposer bascule alors en
# full_ui_mode au lieu de single_window.
s_android_accueil() {
    s_android_dans sh -c '
        setprop waydroid.active_apps Waydroid
        exec am start -a android.intent.action.MAIN -c android.intent.category.HOME
    '
}
