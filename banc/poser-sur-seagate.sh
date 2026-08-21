#!/usr/bin/bash
# Ecrit S sur la Seagate physique, depuis l'interieur de la machine virtuelle.
#
# Derive de poser-sur-cle.sh, qui a fonctionne le 2026-08-21 sur la cle
# virtuelle. Les differences sont la taille de la cible et le fait que ce
# disque-ci est un plateau, non de la memoire flash.
#
# ASCII strict, comme tout script de banc.
set -o pipefail

CIBLE=/dev/vdb
# Relevee cote Windows le 2026-08-21 : (Get-Disk -Number 1).Size
# Surchargeable par l'environnement pour ne pas payer un cycle complet si QEMU
# presentait un compte legerement different -- le refus resterait un refus,
# mais il se leverait par une variable plutot que par une modification de code.
TAILLE_ATTENDUE="${TAILLE_ATTENDUE:-5000981077504}"
IMAGE=ghcr.io/gigigrenier86/s-os:latest

echo "=== Verification de la cible, juste avant d'ecrire ==="
# L'inventaire de l'appelant n'est jamais tenu pour acquis : un disque peut
# avoir ete debranche ou remplace entre le moment ou on l'a vu et maintenant.

if [ ! -b "$CIBLE" ]; then
    echo "ARRET : $CIBLE n'est pas un peripherique bloc." >&2
    exit 1
fi

TAILLE=$(blockdev --getsize64 "$CIBLE")
echo "  taille   : $TAILLE octets (attendu $TAILLE_ATTENDUE)"
if [ "$TAILLE" != "$TAILLE_ATTENDUE" ]; then
    echo "ARRET : ce n'est pas le disque attendu." >&2
    echo "        Si l'ecart vient de QEMU et non d'une erreur de cible," >&2
    echo "        relancer avec : TAILLE_ATTENDUE=$TAILLE bash \$0" >&2
    exit 1
fi

# La geometrie declaree par seagate.ps1 doit se retrouver ici. Ce n'est pas un
# garde-fou de securite mais de performance : si l'invite voit 512/512, les
# ecritures ne seront pas alignees sur les blocs physiques de 4 Kio et le SMR
# le paiera cher. On le dit plutot que de le decouvrir a la duree.
PHYS=$(blockdev --getpbsz "$CIBLE" 2>/dev/null || echo inconnu)
LOG=$(blockdev --getss "$CIBLE" 2>/dev/null || echo inconnu)
echo "  secteur  : logique $LOG / physique $PHYS"
if [ "$PHYS" != "4096" ]; then
    echo "  AVERTISSEMENT : secteur physique non declare a 4096." >&2
    echo "  L'ecriture aboutira, mais sera nettement plus lente sur un SMR." >&2
fi

RACINE=$(findmnt -n -o SOURCE / 2>/dev/null)
echo "  racine   : $RACINE"
case "$RACINE" in
    *vdb*) echo "ARRET : la cible porte la racine du systeme." >&2; exit 1 ;;
esac

if findmnt -n -S "$CIBLE" >/dev/null 2>&1 || findmnt -n -S "${CIBLE}1" >/dev/null 2>&1; then
    echo "ARRET : la cible porte un systeme de fichiers monte." >&2
    exit 1
fi
echo "  montage  : aucun"

# --- La cible accepte-t-elle vraiment qu'on ecrive dessus ? -----------------
# Cote Linux, "aucun montage" ne prouve rien : le volume peut etre monte cote
# WINDOWS, invisible d'ici, et Windows refuse alors toute ecriture par handle
# de disque sur les secteurs de la partition. bootc ecrirait la table
# (secteurs 0-2047, hors partition, donc autorisee) puis mourrait en erreur
# d'E/S sur l'ESP -- APRES le telechargement, en laissant le disque sans table
# et sans systeme. Le refus doit tomber maintenant, pas dans quarante minutes.
#
# La sonde reecrit a l'identique le secteur qu'elle vient de lire : elle ne
# detruit rien. Elle vise le secteur 2048, premier secteur que bootc ecrira,
# et le dernier, ou va l'en-tete GPT de secours.
sonder_ecriture() {
    SECTEUR="$1"
    ETIQ="$2"
    if ! dd if="$CIBLE" of=/tmp/sonde.bin bs=512 count=1 skip="$SECTEUR" \
            iflag=direct status=none 2>/tmp/sonde.err; then
        echo "ARRET : lecture impossible du secteur $SECTEUR ($ETIQ)." >&2
        cat /tmp/sonde.err >&2
        return 1
    fi
    if ! dd if=/tmp/sonde.bin of="$CIBLE" bs=512 count=1 seek="$SECTEUR" \
            oflag=direct conv=fsync status=none 2>/tmp/sonde.err; then
        echo "ARRET : la cible refuse l'ecriture ($ETIQ)." >&2
        cat /tmp/sonde.err >&2
        echo >&2
        echo "Cote Windows, un volume est encore monte sur le disque 1." >&2
        echo "Retirer la lettre ne demonte PAS le volume : il faut SUPPRIMER LA" >&2
        echo "PARTITION avant de lancer QEMU. C'est ce que fait seagate.ps1 par" >&2
        echo "Clear-Disk -- le relancer, puis relancer celui-ci." >&2
        rm -f /tmp/sonde.bin /tmp/sonde.err
        return 1
    fi
    rm -f /tmp/sonde.bin /tmp/sonde.err
    return 0
}

DERNIER=$(( TAILLE / 512 - 1 ))
sonder_ecriture 2048 "debut de partition, la ou ira l'ESP" || exit 1
sonder_ecriture "$DERNIER" "dernier secteur, la ou ira le GPT de secours" || exit 1
echo "  ecriture : autorisee (secteurs 2048 et $DERNIER)"

# --- Y a-t-il la place de deposer l'image ? --------------------------------
# Le pull paie DEUX fois sur le meme systeme de fichiers : les blobs compresses
# (~7 Gio) restent dans $TMPDIR pendant tout le depot, et les couches
# decompressees vont dans le magasin. Le deploiement ostree aplati pese 16 Gio,
# ce qui est le plancher du magasin ; le pic mesure tient entre 23 et 26,5 Gio.
# On exige 28 Gio, marge systeme incluse.
#
# Cet echec exact figure deja au journal du projet -- S-vm/bootc-install.log,
# "no space left on device" a la couche 84 sur 137, meme image. Il avait coute
# le telechargement entier.
LIBRE=$(df -B1 --output=avail /var/lib/containers | tail -1)
if podman image exists "$IMAGE" 2>/dev/null; then
    # L'image est deja au magasin : plus rien a tirer ni a decompresser, donc
    # la contrainte tombe. Ne pas distinguer les deux cas ferait refuser une
    # reprise qui, elle, ne demande rien.
    REQUIS=2147483648
    echo "  image    : deja au magasin, aucun telechargement"
else
    REQUIS=30064771072
    echo "  image    : absente du magasin, il faudra la tirer"
fi
echo "  place    : $LIBRE octets libres, $REQUIS requis"
if [ "$LIBRE" -lt "$REQUIS" ]; then
    echo "ARRET : pas assez de place dans la VM pour deposer l'image." >&2
    echo "        Il manque $(( (REQUIS - LIBRE) / 1048576 )) Mio." >&2
    echo "        Rien n'a ete ecrit sur la Seagate." >&2
    echo "        Liberer /var avant de relancer : ostree admin cleanup," >&2
    echo "        rpm-ostree cleanup -bmp, et le residu de test dans" >&2
    echo "        /var/home/Ghis/.local/share (Steam, containers, umu, S)." >&2
    exit 1
fi

echo "  verdict  : cible confirmee, ecriture autorisee, place suffisante"
echo

# --- Couper le zram, qui a fait echouer l'essai du 2026-08-21 a 00h30 -------
# Le swap de cette image est un zram : un swap COMPRESSE EN MEMOIRE VIVE, pas
# sur disque. Quand bootc deploie son arborescence de 16 Go, la memoire se
# remplit, le noyau evacue des pages vers le zram -- qui consomme lui-meme de
# la RAM pour les stocker compressees. Chaque page evacuee aggrave la penurie
# qui l'a causee. Spirale.
#
# L'unite a arreter est "dev-zram0.swap", PAS "systemd-zram-setup@zram0".
# "swapoff -a" seul desactive le swap une seconde, puis systemd le REACTIVE.
# D'ou l'ordre : arreter l'unite, la masquer, PUIS swapoff -- et verifier
# APRES un delai, parce qu'un controle pris trop tot ment.
echo "=== Memoire ==="
echo "  avant  : $(free -m | awk '/^Mem:/ {print $7}') Mio disponibles, swap $(free -m | awk '/^Swap:/ {print $2}') Mio"
systemctl stop dev-zram0.swap 2>/dev/null || true
systemctl mask dev-zram0.swap 2>/dev/null || true
swapoff -a 2>/dev/null || true
sleep 2
RESTE=$(swapon --show --noheadings 2>/dev/null | wc -l)
echo "  apres  : $(free -m | awk '/^Mem:/ {print $7}') Mio disponibles, swap $(free -m | awk '/^Swap:/ {print $2}') Mio"
if [ "$RESTE" -ne 0 ]; then
    echo "AVERTISSEMENT : un swap est encore actif, le risque de blocage demeure." >&2
    swapon --show >&2
else
    echo "  swap     : aucun, verifie apres coup"
fi
echo

echo "=== Ecriture ==="
echo "  Debut : $(date '+%H:%M:%S')"
# ext4 plutot que btrfs : nettement plus sobre en memoire et en metadonnees.
# L'argument "btrfs use la flash pour rien" ne vaut plus ici -- c'est un
# plateau -- mais celui de la sobriete tient, et on ne perd rien : le retour
# arriere de bootc repose sur ostree, pas sur les instantanes du systeme de
# fichiers.
#
# --generic-image fait deux choses indispensables ici :
#   - il installe TOUS les types de chargeur, et non le seul que la machine
#     courante utilise. On installe depuis du virtio, ca demarrera sur du xHCI.
#   - il n'ecrit AUCUNE variable de firmware. Sans lui, bootc ajouterait une
#     entree de demarrage dans la NVRAM de QEMU, ce qui n'a aucun sens. Le
#     disque reste amorcable par le chemin de repli \EFI\BOOT\BOOTX64.EFI,
#     qui est justement celui que F12 va chercher sur un amovible. Verifie le
#     2026-08-21 : la cle virtuelle a demarre par ce chemin.
#
# --target-imgref n'est pas facultative : sans elle, "bootc upgrade" ne sait
# pas ou aller chercher la suite une fois le disque demarre.
#
# PAS de --root-ssh-authorized-keys, et ce n'est pas un renoncement : le
# montage --volume n'est pas visible la ou bootc lit le fichier (essai du
# 2026-08-20, "Reading /tmp/cle.pub: No such file or directory"), et surtout
# l'option ne servirait a rien -- ce disque demarre sur la machine de Ghis,
# celle-la meme depuis laquelle je travaille. Quand S tourne, Windows est
# eteint et je n'ai aucune machine d'ou me connecter.
podman run --rm --privileged --pid=host \
    -v /dev:/dev \
    -v /var/lib/containers:/var/lib/containers \
    --security-opt label=type:unconfined_t \
    "$IMAGE" \
    bootc install to-disk \
        --wipe \
        --generic-image \
        --filesystem ext4 \
        --target-imgref "$IMAGE" \
        "$CIBLE"

CODE=$?
echo
echo "  Fin   : $(date '+%H:%M:%S')"
if [ "$CODE" -eq 0 ]; then
    echo "=== TERMINE : la Seagate porte S ==="
    lsblk "$CIBLE"
    echo
    # Vider le cache d'ecriture jusqu'au plateau. Sur un disque USB derriere
    # QEMU, "le programme a rendu la main" ne veut pas dire "le disque a
    # tout ecrit" : il reste des donnees dans le cache du boitier. Debrancher
    # a cet instant precis corromprait l'installation, et le symptome
    # apparaitrait au demarrage, loin de sa cause.
    echo "Vidage des caches vers le plateau..."
    sync
    blockdev --flushbufs "$CIBLE" 2>/dev/null || true
    echo "Caches vides. L'arret de QEMU peut avoir lieu."
else
    echo "=== ECHEC, code $CODE ===" >&2
fi
exit "$CODE"
