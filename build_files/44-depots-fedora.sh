#!/usr/bin/bash
# S — rendre a /etc/yum.repos.d les depots que Fedora 45 a ranges ailleurs.
#
# CE QUI A CHANGE. Fedora 45 livre ses fichiers de depot dans
# /usr/share/dnf5/repos.d et laisse /etc/yum.repos.d sans AUCUN depot Fedora
# (fedora, fedora-updates...). Releve le 2026-11-13 sur l'image : seuls les COPR,
# negativo17 et tailscale s'y trouvaient. dnf5 lit bien les deux dossiers, donc
# rien n'a jamais paru casse sur la machine — mais bootc-image-builder, lui,
# resout les paquets de l'installateur avec /etc/yum.repos.d de l'image, et il
# est reparti avec :
#
#   missing packages: selinux-policy-targeted, coreutils, glibc, systemd, ...
#   (le run de l'ISO du 2026-11-13, 21:41 — l'etape « Construire l'ISO »)
#
# Un seul depot Fedora absent suffit : coreutils et glibc n'ont plus d'origine.
#
# LE REMEDE, releve chez d'autres projets confrontes au meme probleme : relier
# chaque fichier du dossier de l'amont sous le MEME NOM. dnf5 donne la priorite
# a /etc sur /usr pour un meme nom de fichier — il n'y a donc pas de depot
# declare deux fois. On n'ecrase jamais un fichier deja present.
#
# COPIE ET NON LIEN, DEPUIS LE 2026-11-13 (deuxieme essai de l'ISO). Un lien
# absolu vers /usr/share/dnf5/repos.d est resolu par bootc-image-builder dans
# SON systeme de fichiers, ou ce dossier n'existe pas : le lien y est casse et
# l'erreur etait identique (« missing packages: coreutils... »). Un fichier
# reel se lit partout. Contrepartie : il ne suit plus l'amont s'il change —
# acceptable, c'est reconstruit chaque nuit.
set -euo pipefail

SRC=/usr/share/dnf5/repos.d
DST=/etc/yum.repos.d

echo "=== 44-depots-fedora : depots de $SRC absents de $DST (copies) ==="

if [ ! -d "$SRC" ]; then
    echo "  $SRC absent : rien a relier (base anterieure a Fedora 45)."
    echo "=== 44-depots-fedora : fait ==="
    exit 0
fi

mkdir -p "$DST"
relies=0
for f in "$SRC"/*.repo; do
    [ -e "$f" ] || continue
    nom="$(basename "$f")"
    if [ -e "$DST/$nom" ] || [ -L "$DST/$nom" ]; then
        echo "  deja la : $nom"
        continue
    fi
    cp "$f" "$DST/$nom"
    echo "  copie   : $nom"
    relies=$((relies + 1))
done
echo "  fichiers copies : $relies"

# L'assertion : le depot Fedora lui-meme doit etre visible, sinon cette etape
# n'a servi a rien et l'ISO echouera de nouveau — vingt minutes plus tard.
if [ -e "$SRC/fedora.repo" ]; then
    [ -f "$DST/fedora.repo" ] && [ ! -L "$DST/fedora.repo" ] \
        || { echo "ECHEC : fedora.repo n'est pas un fichier reel dans $DST." >&2; exit 1; }
fi
echo "=== 44-depots-fedora : fait ==="
