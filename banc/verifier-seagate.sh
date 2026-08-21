#!/usr/bin/bash
# Verifie ce que la Seagate porte VRAIMENT, avant de debrancher quoi que ce soit.
#
# POURQUOI CE SCRIPT EXISTE
# "bootc a rendu 0" ne veut pas dire "ce disque demarrera". Le projet a deja
# constate l'ecart deux fois : une CI verte dont l'image ne portait pas ce qu'on
# croyait, et une machine virtuelle qui semblait avoir perdu les coutures alors
# qu'elle tournait sur un deploiement anterieur. La seule reponse est d'ouvrir
# le disque et de regarder.
#
# Il ne modifie rien : montage en LECTURE SEULE, puis demontage.
# ASCII strict, comme tout script de banc.
set -o pipefail

CIBLE=/dev/vdb
POINT=/mnt/verif-seagate
FAUTES=0
NOTE=0

ok()    { echo "  [ok]    $*"; }
rate()  { echo "  [FAUTE] $*" >&2; FAUTES=$((FAUTES+1)); }
tiede() { echo "  [note]  $*"; NOTE=$((NOTE+1)); }

echo "=== 1. La table de partition ==="
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME "$CIBLE" 2>/dev/null || lsblk "$CIBLE"
for p in 1 2 3; do
    [ -b "${CIBLE}${p}" ] && ok "partition ${p} presente" || rate "partition ${p} ABSENTE"
done
echo

echo "=== 2. L'ESP, et le chemin de repli que F12 va chercher ==="
mkdir -p "$POINT"
if mount -o ro "${CIBLE}2" "$POINT" 2>/dev/null; then
    # C'est LE chemin qui compte sur un amovible : --generic-image n'ecrit
    # aucune variable de firmware, donc rien n'est enregistre au BIOS. La
    # machine ne trouvera ce disque QUE par \EFI\BOOT\BOOTX64.EFI.
    if [ -f "$POINT/EFI/BOOT/BOOTX64.EFI" ]; then
        ok "EFI/BOOT/BOOTX64.EFI present ($(stat -c%s "$POINT/EFI/BOOT/BOOTX64.EFI") octets)"
    else
        rate "EFI/BOOT/BOOTX64.EFI ABSENT -- F12 ne verra pas ce disque"
    fi
    [ -d "$POINT/EFI/fedora" ] && ok "EFI/fedora present (chargeur signe)" \
                               || tiede "EFI/fedora absent"
    echo "  contenu de l'ESP :"
    find "$POINT/EFI" -maxdepth 2 2>/dev/null | sed 's|'"$POINT"'|    |' | head -12
    umount "$POINT"
else
    rate "impossible de monter l'ESP (${CIBLE}2)"
fi
echo

echo "=== 3. La racine, le noyau et le deploiement ==="
if mount -o ro "${CIBLE}3" "$POINT" 2>/dev/null; then
    NOYAUX=$(find "$POINT/boot" -name "vmlinuz*" 2>/dev/null | wc -l)
    INITRD=$(find "$POINT/boot" -name 'initramfs*' 2>/dev/null | wc -l)
    [ "$NOYAUX" -ge 1 ] && ok "$NOYAUX noyau(x) dans /boot" || rate "AUCUN noyau dans /boot"
    [ "$INITRD" -ge 1 ] && ok "$INITRD initramfs dans /boot" || rate "AUCUN initramfs dans /boot"

    [ -d "$POINT/boot/loader/entries" ] && \
        ok "$(ls -1 "$POINT/boot/loader/entries" 2>/dev/null | wc -l) entree(s) d'amorcage" || \
        tiede "pas de /boot/loader/entries"

    # Le deploiement ostree : c'est lui qui porte /usr.
    # Meme lecon : on cherche le dossier qui PORTE un /usr, plutot que de
    # deviner le chemin. La structure reelle est
    # /ostree/deploy/<stateroot>/deploy/<somme>.0/
    RACINE=$(find "$POINT/ostree/deploy" -maxdepth 3 -mindepth 3 -type d 2>/dev/null              | while read -r d; do [ -d "$d/usr" ] && echo "$d" && break; done)
    if [ -n "$RACINE" ] && [ -d "$RACINE/usr" ]; then
        ok "deploiement trouve : ${RACINE#$POINT}"
    else
        rate "aucun deploiement ostree exploitable"
        umount "$POINT"; echo; echo "VERDICT : installation incomplete."; exit 1
    fi
    echo

    echo "=== 4. LE PIEGE QUI CASSERAIT UNE INSTALLATION NEUVE ==="
    # /etc/plasma-setup-done desarme l'assistant de creation de compte. S'il
    # etait la, ce disque demarrerait SANS compte utilisateur et sans moyen
    # d'en creer un -- et cela ne se verrait qu'a l'ecran d'apres.
    if [ -e "$RACINE/etc/plasma-setup-done" ] || [ -e "$RACINE/usr/etc/plasma-setup-done" ]; then
        rate "plasma-setup-done PRESENT -- aucun compte ne pourra etre cree"
    else
        ok "plasma-setup-done absent -- l'assistant de compte s'ouvrira"
    fi
    echo

    echo "=== 5. Les coutures de S ==="
    N=$(ls -1 "$RACINE"/usr/bin/s-* 2>/dev/null | wc -l)
    if [ "$N" -ge 8 ]; then
        ok "$N gestes s-* presents"
        ls -1 "$RACINE"/usr/bin/s-* 2>/dev/null | sed 's|.*/|    |'
    else
        rate "seulement $N gestes s-* (8 attendus)"
    fi

    PROTON="$RACINE/usr/lib/s/windows/proton.tar.gz"
    if [ -f "$PROTON" ]; then
        ok "Proton pre-cuit : $(stat -c%s "$PROTON") octets"
        [ -f "$RACINE/usr/lib/s/windows/proton.version" ] && \
            ok "version : $(cat "$RACINE/usr/lib/s/windows/proton.version")"
    else
        rate "archive Proton ABSENTE -- le monde Windows devrait tout retelecharger"
    fi

    APK="$RACINE/usr/share/s/apk/fdroid.apk"
    [ -f "$APK" ] && ok "F-Droid : $(stat -c%s "$APK") octets" || rate "F-Droid ABSENT"

    MIME="$RACINE/etc/xdg/mimeapps.list"
    [ -f "$MIME" ] && ok "$(grep -c '=' "$MIME" 2>/dev/null) associations declarees" \
                   || rate "mimeapps.list ABSENT -- double-clic mort sur .exe et .deb"
    echo

    echo "=== 6. Le noyau sait-il faire tourner Android ? ==="
    CFG=$(find "$RACINE/usr/lib/modules" -maxdepth 2 -name config 2>/dev/null | head -1)
    if [ -n "$CFG" ]; then
        grep -q '^CONFIG_ANDROID_BINDER_IPC=y' "$CFG" && ok "binder compile dans le noyau" \
            || rate "CONFIG_ANDROID_BINDER_IPC absent -- Waydroid ne peut pas tourner"
    else
        tiede "configuration du noyau introuvable"
    fi
    [ -x "$RACINE/usr/bin/waydroid-launcher" ] && ok "waydroid-launcher present" \
        || rate "waydroid-launcher ABSENT"
    echo

    echo "=== 7. bootc saura-t-il ou chercher ses mises a jour ? ==="
    # Sans target-imgref enregistre, "bootc upgrade" n'a nulle part ou aller,
    # et le systeme devient un cul-de-sac -- installe, mais plus jamais a jour.
    ORIGINE=$(find "$POINT/ostree/deploy" -maxdepth 3 -name '*.origin' 2>/dev/null | head -1)
    if [ -n "$ORIGINE" ]; then
        if grep -q 's-os' "$ORIGINE" 2>/dev/null; then
            ok "origine enregistree : $(grep -m1 'imgref\|container' "$ORIGINE" | cut -c1-90)"
        else
            rate "l'origine ne nomme pas s-os -- bootc upgrade sera perdu"
        fi
    else
        rate "aucun fichier .origin -- bootc upgrade ne saura pas ou aller"
    fi

    umount "$POINT"
else
    rate "impossible de monter la racine (${CIBLE}3)"
fi
rmdir "$POINT" 2>/dev/null

echo
echo "=== 8. Vider les caches jusqu'au plateau ==="
# Sur un disque USB derriere QEMU, "le programme a rendu la main" ne veut pas
# dire "le disque a tout ecrit" : il reste des donnees dans le cache du boitier.
# Debrancher a cet instant corromprait l'installation, et le symptome
# apparaitrait au demarrage, loin de sa cause.
sync
blockdev --flushbufs "$CIBLE" 2>/dev/null || true
sleep 3
sync
echo "  caches vides, deux fois, avec un delai entre les deux"

echo
if [ "$FAUTES" -eq 0 ]; then
    echo "VERDICT : la Seagate porte S en entier. $NOTE remarque(s) sans gravite."
    echo "          QEMU peut etre eteint, puis le disque debranche."
    exit 0
else
    echo "VERDICT : $FAUTES FAUTE(S). NE PAS DEBRANCHER, NE PAS CONCLURE." >&2
    exit 1
fi
