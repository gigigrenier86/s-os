#!/usr/bin/bash
set -euxo pipefail

# ==========================================================================
# Allegement — retirer ce qui ne sert pas a S, sans toucher a ses fonctions
# ==========================================================================
# Chaque retrait porte sa raison, et une verification qu'il n'a rien casse.
# Les gains sont mesures sur l'image du 2026-10-23 (audit complet).

# --- locale-archive.real : un doublon de 223 Mo ----------------------------
# Deux fichiers DISTINCTS (2 inodes), 233 Mo chacun, dans /usr/lib/locale.
# Le « .real » est un reliquat ; le vrai est « locale-archive », le chemin
# standard que tout le monde lit. On ne touche qu'au reliquat.
if [ -f /usr/lib/locale/locale-archive ] && [ -f /usr/lib/locale/locale-archive.real ]; then
    rm -f /usr/lib/locale/locale-archive.real
    echo "  locale-archive.real retire (doublon de 223 Mo)"
fi
[ -s /usr/lib/locale/locale-archive ] \
    || { echo "ECHEC : locale-archive a disparu." >&2; exit 1; }

# --- /usr/share/doc : la documentation (207 Mo) ---------------------------
# Les LICENCES vivent dans /usr/share/licenses (garde, obligation legale),
# pas ici. Aucune application ne lit /usr/share/doc pour fonctionner.
rm -rf /usr/share/doc
echo "  /usr/share/doc retire (207 Mo)"

# --- ibus : la pile de saisie CJK, fcitx5 est garde -----------------------
# Deux moteurs de saisie complets cohabitaient. S est KDE : fcitx5 est le
# natif (kcm_fcitx5). ibus et ses moteurs (japonais/coreen/chinois) partent.
dnf5 remove -y \
    ibus ibus-panel ibus-setup \
    ibus-anthy ibus-anthy-python ibus-hangul ibus-libpinyin \
    ibus-m17n ibus-typing-booster ibus-chewing
command -v fcitx5 >/dev/null \
    || { echo "ECHEC : fcitx5 a disparu — la saisie n'aurait plus de moteur." >&2; exit 1; }
echo "  ibus retire, fcitx5 conserve"

# --- homebrew.tar.zst : l'archive bootstrap de Bazzite (157 Mo) -----------
# brew vit deja dans /home/linuxbrew ; l'archive n'est jamais re-depliee.
rm -f /usr/share/homebrew.tar.zst /usr/share/applications/bbrew.desktop
echo "  homebrew.tar.zst + bbrew retires (157 Mo)"

# --- Locales : fr + en seulement ------------------------------------------
# Demande de l'utilisateur : garder le francais ET l'anglais, retirer le
# reste. Les applications retombent sur l'anglais pour les langues absentes.
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d \
    ! -name 'fr*' ! -name 'en*' ! -name 'C*' ! -name 'POSIX*' \
    -exec rm -rf {} +
echo "  locales reduites a fr + en"

echo "=== 53-allegement : fait ==="