#!/usr/bin/bash
# S - lance Android nativement (lxc-start), sans l'outillage Python Waydroid.
#
# UN SEUL fichier, execute par UNE SEULE ligne ExecStart= : c'est voulu, pas
# du style. La politique SELinux de waydroid-selinux (waydroid.te) ne fait
# basculer un processus lance par systemd (init_t) dans le domaine waydroid_t
# -- celui qui a le droit d'executer lxc-start et waydroid-net.sh -- que pour
# UN SEUL fichier au monde : /usr/lib/waydroid/waydroid.py. Verifie le
# 2026-08-28 : `semanage fcontext -l | grep waydroid` ne montre que cette
# etiquette-la. Ce script est mappe sur le meme type (waydroid_exec_t) via
# `semanage fcontext -a`, donc CE fichier precis doit rester l'unique point
# d'entree -- le decouper en plusieurs ExecStartPre=/ExecStart= casserait la
# transition (mesure le 2026-08-28 : "Failed at step EXEC" sur waydroid-net.sh
# quand il etait appele depuis une ligne separee, scontext=init_t).
set -euo pipefail

SRC=/usr/lib/s/android
# Sous /var/lib/waydroid/, pas /var/lib/s-android/ : waydroid.te etiquette
# tout ce sous-arbre en waydroid_data_t via une regle de chemin
# (/var/lib/waydroid(.*)?), donc un simple mkdir ici herite deja du bon
# type. Un autre chemin exigerait une regle semanage de plus.
# Mesure le 2026-08-28 : "Permission non accordee" en var_lib_t generique
# avant ce changement.
DST=/var/lib/waydroid/lxc/android
UID_CIBLE=$(id -u RyuRex)
RUNTIME_DIR="/run/user/$UID_CIBLE"

# --- 1. config LXC : statique copiee, session regeneree ---
mkdir -p "$DST"
cp -f "$SRC/config_static" "$DST/config"

if [ ! -d "$RUNTIME_DIR" ]; then
    echo "android-lancer: pas de session graphique pour uid $UID_CIBLE ($RUNTIME_DIR absent)" >&2
    exit 1
fi

# PAS de find/readdir ici : waydroid_t a seulement le droit de "search" sur
# user_tmp_t (userdom_search_user_tmp_dirs dans waydroid.te), pas "read" --
# ouvrir un chemin connu marche, lister le dossier non. Mesure le 2026-08-28 :
# `avc: denied { read } ... tcontext=user_tmp_t tclass=dir` en listant
# /run/user/1000 depuis ce domaine. On teste donc des noms connus plutot que
# de scanner.
WAYLAND_SOCKET=""
for essai in wayland-0 wayland-1; do
    if [ -S "$RUNTIME_DIR/$essai" ]; then
        WAYLAND_SOCKET="$essai"
        break
    fi
done
if [ -z "$WAYLAND_SOCKET" ]; then
    echo "android-lancer: aucun socle wayland (wayland-0/1) dans $RUNTIME_DIR -- pas de session graphique." >&2
    exit 1
fi

{
    echo "lxc.mount.entry = tmpfs /run/xdg none create=dir 0 0"
    echo "lxc.mount.entry = $RUNTIME_DIR/$WAYLAND_SOCKET run/xdg/$WAYLAND_SOCKET none rbind,create=file 0 0"
    if [ -S "$RUNTIME_DIR/pulse/native" ]; then
        echo "lxc.mount.entry = $RUNTIME_DIR/pulse/native run/xdg/pulse/native none rbind,create=file 0 0"
    fi
    # Meme dossier de donnees que Waydroid : les comptes/apps deja installes
    # se retrouvent tels quels, rien a reinstaller.
    echo "lxc.mount.entry = /var/home/RyuRex/.local/share/waydroid/data data none rbind 0 0"
} > "$DST/config_session"

# --- 2. le pont reseau : script amont, reutilise tel quel ---
# android-net.sh gere lui-meme la reinitialisation du pont perime (voir
# android-net.sh pour la mesure et la vraie raison : le fichier temoin
# appartient au domaine container_runtime_t, pas au notre, on ne peut pas le
# supprimer d'ici meme en root -- SELinux, pas une permission Unix).
/usr/lib/s/android-net.sh start

# --- 2.5 monter system.img/vendor.img : c'est CA qui fournit /init ---
# Mesure le 2026-08-28 : lxc-start echouait sur "Failed to exec /init" --
# /var/lib/waydroid/rootfs est un squelette VIDE tant que rien n'y est monte.
# Waydroid le fait dans tools/helpers/images.py::mount_rootfs(), jamais
# appele puisqu'on saute tout son Python. Sequence reprise telle quelle
# (memes options, meme contexte SELinux waydroid_rootfs_t), traduite en
# mount(8) direct -- ce ne sont que des mount(2), rien de "Waydroid manager".
ROOTFS=/var/lib/waydroid/rootfs
IMAGES=/var/lib/waydroid/images
OVERLAY=/var/lib/waydroid/overlay
OVERLAY_RW=/var/lib/waydroid/overlay_rw
OVERLAY_WORK=/var/lib/waydroid/overlay_work
CTX='context="system_u:object_r:s_android_rootfs_t:s0"'

# On repart toujours d'un rootfs propre plutot que de deviner s'il est deja
# monte -- mesure le 2026-08-28 : des verifications mountpoint/findmnt
# individuelles ont fini par empiler deux fois le meme overlay apres deux
# essais rates, et un overlay monte sur lui-meme casse (bad superblock).
# C'est exactement ce que fait Waydroid pour ce premier montage
# (mount(..., umount=True)) : jeter, pas verifier.
umount -R "$ROOTFS" 2>/dev/null || true

mount -o "$CTX,ro" "$IMAGES/system.img" "$ROOTFS"

mkdir -p "$OVERLAY" "$OVERLAY_RW/system" "$OVERLAY_WORK/system"
mount -t overlay -o "$CTX,ro,lowerdir=$OVERLAY:$ROOTFS,upperdir=$OVERLAY_RW/system,workdir=$OVERLAY_WORK/system,xino=off" overlay "$ROOTFS"

mount -o "$CTX,ro" "$IMAGES/vendor.img" "$ROOTFS/vendor"

mkdir -p "$OVERLAY/vendor" "$OVERLAY_RW/vendor" "$OVERLAY_WORK/vendor"
mount -t overlay -o "$CTX,ro,lowerdir=$OVERLAY/vendor:$ROOTFS/vendor,upperdir=$OVERLAY_RW/vendor,workdir=$OVERLAY_WORK/vendor,xino=off" overlay "$ROOTFS/vendor"

# Pilotes GPU/odm du hote, seulement s'ils existent (ils n'existent pas sur
# un bureau Linux normal -- ces chemins sont Android, pas Fedora -- gardes
# la, comme chez Waydroid, au cas ou).
for egl in /vendor/lib/egl /vendor/lib64/egl; do
    [ -d "$egl" ] && ! mountpoint -q "$ROOTFS$egl" && {
        mkdir -p "$ROOTFS$egl"
        mount -o bind "$egl" "$ROOTFS$egl"
    }
done
if mountpoint -q /odm; then
    mkdir -p "$ROOTFS/odm_extra"
    mountpoint -q "$ROOTFS/odm_extra" || mount -o bind /odm "$ROOTFS/odm_extra"
elif [ -d /vendor/odm ]; then
    mkdir -p "$ROOTFS/odm_extra"
    mountpoint -q "$ROOTFS/odm_extra" || mount -o bind /vendor/odm "$ROOTFS/odm_extra"
fi

# waydroid.prop : deja genere par une session precedente (GPU, densite,
# resolution -- toutes mesurees sur cette machine), reutilise tel quel.
# PAS de touch : vendor.img fournit deja ce fichier (19 octets, place-holder
# depuis la construction de l'image) -- l'overlay vendor est "ro", un touch
# dessus echoue (mesure le 2026-08-28). Le bind remplace juste ce qui est
# deja la, aucune ecriture requise dans l'overlay.
mountpoint -q "$ROOTFS/vendor/waydroid.prop" || mount -o bind /var/lib/waydroid/waydroid.prop "$ROOTFS/vendor/waydroid.prop"

# Cinq entrees "tmpfs -> <nom>" du config statique n'ont pas create=dir :
# elles exigent que le dossier cible existe deja dans le rootfs monte
# ci-dessus (system.img les fournit peut-etre deja -- mkdir -p est un
# no-op si oui). A faire ICI, APRES le montage : avant, elles se seraient
# fait cacher par le mount de system.img par-dessus $ROOTFS.
mkdir -p "$ROOTFS/dev" "$ROOTFS/mnt_extra" "$ROOTFS/tmp" "$ROOTFS/var" \
         "$ROOTFS/run" "$ROOTFS/data"

# --- 3. le conteneur : exec, pas fork -- systemd doit suivre CE PID ---
exec /usr/bin/lxc-start -F -P /var/lib/waydroid/lxc -n android -- /init
