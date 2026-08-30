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

# --- Traduction ARM (libhoudini), demandee et posee le 2026-08-30 -----------
#
# ANDROID N'A AUCUNE TRADUCTION ARM SUR CETTE MACHINE — mesure par
# android_plateforme.py avant d'ecrire une ligne : ro.product.cpu.abilist ne
# porte que « x86_64,x86 », ro.dalvik.vm.native.bridge vaut « 0 ». Toute
# application ou jeu qui n'expose que du code natif ARM (la grande majorite
# des jeux mobiles, dont un App Bundle installe le 2026-08-30 avec
# « INSTALL_FAILED_NO_MATCHING_ABIS ») echoue a l'installation, quel que soit
# le mecanisme employe — voir CLAUDE.md, 2026-08-30, apres-midi.
#
# CE MECANISME EST CELUI DE L'AMONT, PAS UNE INVENTION : ublue-os/waydroid_
# script (le meme depot que « ujust configure-waydroid » clone deja pour son
# option « configure ») porte stuff/houdini.py — la ou Bazzite envoie
# l'utilisateur, si on ne l'avait pas cherche. Les valeurs ci-dessous (URL,
# empreinte, contenu de houdini.rc, proprietes) sont RELEVEES DE CE FICHIER
# MOT POUR MOT le 2026-08-30 (extraites par ast.literal_eval, reverifiees par
# une comparaison d'egalite avant d'etre collees ici), jamais reecrites a
# l'aveugle.
#
# CODE NOIR NOMME, PAS CONTOURNE — voir CLAUDE.md, 2026-08-30. Le binaire est
# proprietaire (vendor Intel, republie par un mainteneur communautaire —
# « supremegamers » — sans licence documentee), verifie par MD5 seul (protege
# contre une corruption de telechargement, pas contre une substitution
# deliberee). DECISION PRISE AVEC L'UTILISATEUR, jamais a sa place — meme
# forme que le gpgcheck=0 assume pour Antigravity.
#
# L'ARCHIVE EST DANS L'IMAGE DEPUIS LE 2026-08-30 (build_files/21-android-
# arm.sh, /usr/lib/s/android/libhoudini.zip) — DECISION REPRISE AVEC
# L'UTILISATEUR, question posee deux fois : la premiere reponse voulait le
# binaire hors de l'image publique, la seconde l'a renversee sciemment («
# ce qui fonctionne ici doit fonctionner partout, sur tous les aspects »).
# S vise a servir d'autres que son seul utilisateur actuel ; distribuer le
# binaire, sous la signature de S, a quiconque tire l'image publique en est
# la consequence assumee. CE QUI RESTE UN GESTE, LUI, C'EST L'INSTALLATION
# : l'extraction dans /var/lib/waydroid/overlay et la pose des proprietes
# ne peuvent pas se faire a la construction (Android n'existe pas encore
# a cet instant) — seul « s-android --traduction-arm », sur la machine qui
# le demande, les declenche.
#
# SEULE LA VERSION ANDROID 13 EST CABLEE : c'est celle de cette image
# (LineageOS 20.0, sdk 33 — mesure par android_plateforme.py). Android 11
# demanderait un autre lien (dl_links["11"] chez l'amont), jamais eprouve ici.
S_HOUDINI_URL="https://github.com/supremegamers/vendor_intel_proprietary_houdini/archive/7e21ea3f63bd89e9e8af54e32da41bd8b65c93a1.zip"
S_HOUDINI_MD5="f8cf5db10e5fdb9b77e98e515a9b08c9"

# Vrai si libhoudini est deja pose — jamais de second telechargement.
s_android_traduction_arm_posee() {
    [ -f /var/lib/waydroid/overlay/system/lib64/libhoudini.so ]
}

# Pose libhoudini dans l'overlay systeme d'Android, et les proprietes qui lui
# disent de s'en servir. NE PREND EFFET QU'AU PROCHAIN DEMARRAGE DU
# CONTENEUR — meme regle que s_android_prop_ecrire, pour la meme raison :
# Android lit ses .rc et ses proprietes au boot, jamais a chaud.
s_android_traduction_arm_installer() {
    if s_android_traduction_arm_posee; then
        return 0
    fi

    local travail="$S_ETAT/houdini"
    rm -rf "$travail"
    mkdir -p "$travail"

    # PRE-CUIT DANS L'IMAGE DEPUIS LE 2026-08-30 (build_files/21-android-arm.sh)
    # — meme principe que Proton (41-windows.sh) : le reseau ne sert que si
    # l'image ne porte pas deja l'archive (une image plus ancienne, ou un
    # essai lance depuis le depot par S_LIB). On COPIE ce que l'image porte
    # plutot que d'y pointer directement, pour ne jamais toucher a un fichier
    # qui vit sous /usr — meme s'il ne serait ici que lu.
    local precuit="/usr/lib/s/android/libhoudini.zip"
    if [ -f "$precuit" ]; then
        cp "$precuit" "$travail/libhoudini.zip"
    elif ! curl -fsSL --retry 3 -o "$travail/libhoudini.zip" "$S_HOUDINI_URL"; then
        echo "telechargement de libhoudini echoue" >&2
        rm -rf "$travail"
        return 1
    fi

    # LE CONDENSAT PUBLIE PAR L'AMONT FAIT FOI, MEME DISCIPLINE QUE PARTOUT
    # AILLEURS DANS CE DEPOT (voir 41-windows.sh, F-Droid dans 40-coutures.sh) :
    # jamais un octet installe sans qu'il corresponde — que l'archive vienne
    # de l'image ou du reseau, la meme verification s'applique aux deux.
    local md5_obtenu
    md5_obtenu="$(md5sum "$travail/libhoudini.zip" | cut -d' ' -f1)"
    if [ "$md5_obtenu" != "$S_HOUDINI_MD5" ]; then
        echo "libhoudini.zip : empreinte differente de celle publiee ($md5_obtenu != $S_HOUDINI_MD5)" >&2
        rm -rf "$travail"
        return 1
    fi

    # UNE SEULE ELEVATION, POUR UNE SEULE RAISON : extraire, copier dans
    # l'overlay systeme (root:root), poser houdini.rc, regler les
    # permissions — jamais un lxc-attach, ce sont des fichiers HOTE (le
    # dossier overlay est lu par android-lancer.sh au montage, pas par le
    # conteneur en marche). Le telechargement et la verification restent
    # dans le compte de l'utilisateur, au-dessus.
    if ! s_root /usr/bin/python3 - "$travail" <<'PY'
import os
import sys
import zipfile
import shutil

travail = sys.argv[1]
overlay_system = "/var/lib/waydroid/overlay/system"

RC_CONTENT = '\non early-init\n    mount binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc\n\non property:ro.enable.native.bridge.exec=1\n    exec -- /system/bin/sh -c "echo \':arm_exe:M::\\\\x7f\\\\x45\\\\x4c\\\\x46\\\\x01\\\\x01\\\\x01\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x02\\\\x00\\\\x28::/system/bin/houdini:P\' > /proc/sys/fs/binfmt_misc/register"\n    exec -- /system/bin/sh -c "echo \':arm_dyn:M::\\\\x7f\\\\x45\\\\x4c\\\\x46\\\\x01\\\\x01\\\\x01\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x03\\\\x00\\\\x28::/system/bin/houdini:P\' >> /proc/sys/fs/binfmt_misc/register"\n    exec -- /system/bin/sh -c "echo \':arm64_exe:M::\\\\x7f\\\\x45\\\\x4c\\\\x46\\\\x02\\\\x01\\\\x01\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x02\\\\x00\\\\xb7::/system/bin/houdini64:P\' >> /proc/sys/fs/binfmt_misc/register"\n    exec -- /system/bin/sh -c "echo \':arm64_dyn:M::\\\\x7f\\\\x45\\\\x4c\\\\x46\\\\x02\\\\x01\\\\x01\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x00\\\\x03\\\\x00\\\\xb7::/system/bin/houdini64:P\' >> /proc/sys/fs/binfmt_misc/register"\n'

# TOUT LE TRAVAIL EST DANS CE try, ET LE finally NETTOIE DANS TOUS LES CAS —
# MESURE EN DIRECT LE 2026-08-30 : l'EXTRACTION tourne ici, en root, donc
# CHAQUE FICHIER qu'elle cree devient root:root dans un dossier que
# L'UTILISATEUR a cree. Le « rm -rf » de l'appelant (non privilegie, apres
# cette elevation) ne peut alors plus rien effacer — permission refusee sur
# chaque fichier, un a un. Seul root peut nettoyer ce que root a extrait.
try:
    with zipfile.ZipFile(os.path.join(travail, "libhoudini.zip")) as z:
        z.extractall(os.path.join(travail, "unpack"))

    racines = [d for d in os.listdir(os.path.join(travail, "unpack"))
               if d.startswith("vendor_intel_proprietary_houdini-")]
    if not racines:
        print("archive : dossier attendu absent apres extraction", file=sys.stderr)
        sys.exit(1)
    prebuilts = os.path.join(travail, "unpack", racines[0], "prebuilts")

    shutil.copytree(prebuilts, overlay_system, dirs_exist_ok=True)

    init_dir = os.path.join(overlay_system, "etc", "init")
    os.makedirs(init_dir, exist_ok=True)
    with open(os.path.join(init_dir, "houdini.rc"), "w", encoding="utf-8") as f:
        f.write(RC_CONTENT)

    # LE MEME SCHEMA DE PERMISSIONS QUE L'AMONT (stuff/general.py::set_path_perm) :
    # bin/ appartient au groupe 2000 (shell Android), le reste a root:root.
    for racine, dossiers, fichiers in os.walk(overlay_system):
        for nom in dossiers + fichiers:
            chemin = os.path.join(racine, nom)
            dans_bin = "bin" in chemin.split(os.sep)
            gid = 2000 if dans_bin else 0
            if os.path.isdir(chemin):
                mode = 0o777 if dans_bin else 0o755
            else:
                mode = 0o755 if dans_bin else 0o644
            os.chown(chemin, 0, gid)
            os.chmod(chemin, mode)
finally:
    shutil.rmtree(travail, ignore_errors=True)
PY
    then
        echo "installation de libhoudini refusee ou echouee" >&2
        return 1
    fi

    # LES PROPRIETES QUI DISENT A ANDROID DE S'EN SERVIR — meme fonction que
    # pour la densite ou la taille de fenetre, meme regle : ne prend effet
    # qu'au prochain demarrage du conteneur.
    s_android_prop_ecrire \
        "ro.product.cpu.abilist=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi" \
        "ro.product.cpu.abilist32=x86,armeabi-v7a,armeabi" \
        "ro.product.cpu.abilist64=x86_64,arm64-v8a" \
        "ro.dalvik.vm.native.bridge=libhoudini.so" \
        "ro.enable.native.bridge.exec=1" \
        "ro.dalvik.vm.isa.arm=x86" \
        "ro.dalvik.vm.isa.arm64=x86_64"
}
