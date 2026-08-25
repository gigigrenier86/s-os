#!/usr/bin/bash
# Ou en sont les trois mondes de S, sur CETTE machine, maintenant.
#
# CE QUE CE SCRIPT N'EST PAS : un rapport d'intention. Il ne dit pas ce que S
# est cense faire, il releve ce qui est reellement pose et reellement en marche.
# Chaque ligne est une mesure ; « pose » et « en marche » ne sont jamais
# confondus, c'est la regle du carnet.
set -uo pipefail

vert=$'\033[32m'; rouge=$'\033[31m'; jaune=$'\033[33m'; gris=$'\033[90m'; nu=$'\033[0m'
dire() { printf '  %-34s %s\n' "$1" "$2"; }
oui()  { printf '%s%s%s\n' "$vert" "$1" "$nu"; }
non()  { printf '%s%s%s\n' "$rouge" "$1" "$nu"; }
tiede(){ printf '%s%s%s\n' "$jaune" "$1" "$nu"; }
titre(){ printf '\n%s── %s %s\n' "$gris" "$1" "$nu"; }

present() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- LINUX ----
titre "LINUX"
dire "systeme"            "$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-?} — ${IMAGE_ID:-?}")"
dire "session"            "${XDG_SESSION_DESKTOP:-?} (${XDG_SESSION_TYPE:-?})"
if [ "$(systemctl --user is-active graphical-session.target 2>/dev/null)" = "active" ]; then
    dire "session vue par systemd" "$(oui 'active')"
else
    dire "session vue par systemd" "$(non 'INACTIVE — portail, gvfs et le gestionnaire de fichiers resteront muets')"
fi
portail=$(systemctl --user is-active xdg-desktop-portal.service 2>/dev/null)
[ "$portail" = "active" ] && dire "portail XDG" "$(oui 'actif')" || dire "portail XDG" "$(non "$portail")"

# -------------------------------------------------------------- WINDOWS ----
titre "WINDOWS"
if present umu-run; then dire "moteur umu" "$(oui "$(command -v umu-run)")"; else dire "moteur umu" "$(non 'absent')"; fi
if [ -f /usr/lib/s/windows/proton.tar.gz ]; then
    dire "Proton dans l'image" "$(oui "$(cat /usr/lib/s/windows/proton.version 2>/dev/null || echo present) — aucun telechargement")"
else
    dire "Proton dans l'image" "$(tiede 'absent — umu le telechargera (~800 Mo)')"
fi
PFX="$HOME/.local/share/S/windows"
[ -f "$PFX/pfx/user.reg" ] && PFX="$PFX/pfx"
if [ -d "$PFX/drive_c" ]; then
    dire "prefixe" "$(oui "$PFX")"
    n=$(ls -d "$PFX/drive_c/Program Files"/* "$PFX/drive_c/Program Files (x86)"/* 2>/dev/null | wc -l)
    dire "programmes installes" "$n"
    if [ -f /usr/lib/s/registre.py ] || [ -f files/usr/lib/s/registre.py ]; then
        reg=$([ -f /usr/lib/s/registre.py ] && echo /usr/lib/s/registre.py || echo files/usr/lib/s/registre.py)
        p=$(python3 "$reg" --liste "$PFX" 2>/dev/null | tr '\n' ' ')
        dire "protocoles enregistres" "${p:-aucun}"
    fi
else
    dire "prefixe" "$(tiede 'pas encore cree — ouvre un .exe une premiere fois')"
fi
h=$(xdg-mime query default x-scheme-handler/cursor 2>/dev/null)
[ -n "$h" ] && dire "retour de connexion (cursor://)" "$(oui "$h")" \
            || dire "retour de connexion (cursor://)" "$(tiede 'non declare')"

# -------------------------------------------------------------- ANDROID ----
titre "ANDROID"
if grep -q '^CONFIG_ANDROID_BINDER_IPC=[ym]' /usr/lib/modules/*/config 2>/dev/null; then
    dire "binder dans le noyau" "$(oui 'oui — le risque principal du projet est leve')"
else
    dire "binder dans le noyau" "$(non 'NON — Waydroid ne pourra pas demarrer')"
fi
mountpoint -q /dev/binderfs 2>/dev/null \
    && dire "binderfs monte" "$(oui '/dev/binderfs')" \
    || dire "binderfs monte" "$(non 'non — le conteneur ne peut pas s ouvrir')"
e=$(systemctl is-enabled waydroid-container.service 2>/dev/null)
[ "$e" = "enabled" ] && dire "conteneur au demarrage" "$(oui 'active')" || dire "conteneur au demarrage" "$(non "${e:-?} — c'est ce qui a bloque Android cinq jours")"
if [ -f /var/lib/waydroid/waydroid.cfg ]; then
    dire "image Android" "$(oui 'installee')"
    dire "session" "$(waydroid status 2>/dev/null | grep -i session | head -1 || echo '?')"
else
    dire "image Android" "$(tiede 'jamais telechargee — lance s-android (~1 Go, une fois)')"
fi

# ------------------------------------------------------------- COUTURES ----
titre "LES COUTURES"
for g in s-partage s-lien-windows s-menu-windows s-fichiers-windows s-android s-constellation; do
    present "$g" && dire "$g" "$(oui 'pose')" || dire "$g" "$(tiede 'pas dans cette image')"
done
P="${S_PARTAGE:-$HOME/Partage}"
if [ -d "$P" ]; then
    w=$([ -L "$PFX/dosdevices/p:" ] && echo "P:\\" || echo "—")
    # Le /sdcard ne vit pas toujours au meme endroit : waydroid 1.6 pose les
    # donnees de session dans ~/.local/share/waydroid/data, la configuration
    # restant dans /var/lib/waydroid. Ce releve visait le second et rendait
    # « — » alors que le montage lie etait bel et bien pose (2026-08-25).
    # Deux corrections d'un coup, mesurees le 2026-08-25 :
    #   1. le /sdcard ne vit pas toujours au meme endroit — waydroid 1.6 pose
    #      les donnees de session dans ~/.local/share/waydroid/data, la
    #      configuration restant dans /var/lib/waydroid ;
    #   2. « mountpoint » ne peut pas repondre ici : media/0 appartient au
    #      groupe 1023 d'Android et l'utilisateur ne peut pas le traverser.
    #      Il rendait « — » sur un montage parfaitement pose.
    # On lit donc la table des montages, qui n'exige aucun droit de passage.
    a="—"
    for base in "$HOME/.local/share/waydroid/data" /var/lib/waydroid/data; do
        grep -q " ${base}/media/0/Partage " /proc/self/mountinfo 2>/dev/null &&
            { a="/sdcard/Partage"; break; }
    done
    dire "dossier partage" "$(oui "$P")  |  windows: $w  |  android: $a"
else
    dire "dossier partage" "$(tiede 'pas encore cree — lance s-partage')"
fi
printf '\n'
