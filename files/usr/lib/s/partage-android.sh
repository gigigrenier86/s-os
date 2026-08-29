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

# --- Le service : le seul privilege qui reste ------------------------------
#
# start / stop / restart de s-android.service. Sans mot de passe grace a
# /usr/share/polkit-1/rules.d/50-s-android.rules (wheel actif, cette unite,
# ces trois verbes) ; repli sur pkexec si la regle manque — une machine qui
# n'a pas encore l'image demande alors un mot de passe, comme avant, au lieu
# d'echouer en silence. « --no-ask-password » fait echouer la premiere forme
# TOUT DE SUITE quand polkit refuse, plutot que d'ouvrir une seconde demande
# par l'agent avant celle de pkexec.
s_android_service() {
    local verbe="$1"
    systemctl --no-ask-password "$verbe" s-android.service 2>/dev/null && return 0
    s_root systemctl "$verbe" s-android.service
}

# --- Installer et lancer : PAR LE SERVICE BINDER, PLUS PAR lxc-attach --------
#
# CE QUI A CHANGE LE 2026-08-29 AU SOIR, ET POURQUOI. La version precedente
# de ces deux verbes passait par lxc-attach (pm install -S en flux, cmd
# package resolve-activity + setprop + am start) — donc par pkexec, un mot de
# passe par clic. Le service binder « waydroidplatform » de system.img (celui
# que l'outillage Python de Waydroid appelait pour EXACTEMENT ces gestes)
# repond depuis la session sans aucun privilege : voir
# /usr/lib/s/android_plateforme.py et s-android-lancer. Les mesures de
# l'ancienne forme (le tiret refuse par pm, le code 0 d'am start, la
# propriete waydroid.active_apps lue par hwcomposer) restent vraies et sont
# gardees au Grimoire (android-piloter-sans-waydroid.sh) pour le jour ou
# lxc-attach serait de nouveau le seul chemin.
#
# IL N'Y A PLUS DE « s_android_accueil » : c'etait la seule fonction de S
# qui ouvrait l'interface complete d'Android (waydroid.active_apps=Waydroid),
# et l'utilisateur ne veut plus voir cette fenetre. Aucun geste ne doit la
# recreer.
s_android_installer() {
    "${S_BIN:-/usr/bin}/s-android-lancer" --installer "$1" 2>/dev/null \
        || /usr/bin/s-android-lancer --installer "$1"
}

s_android_lancer() {
    "${S_BIN:-/usr/bin}/s-android-lancer" "$1" 2>/dev/null \
        || /usr/bin/s-android-lancer "$1"
}
