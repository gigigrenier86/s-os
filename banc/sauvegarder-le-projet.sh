#!/usr/bin/bash
# Rassemble TOUT le projet S en un seul dossier verifiable, depuis S lui-meme.
#
#   ./banc/sauvegarder-le-projet.sh [dossier de destination]
#
# C'est le pendant Linux de sauvegarder-le-projet.ps1, qui tournait sur la
# machine de developpement Windows. Depuis le 2026-08-25 le depot vit sur la
# machine ; la sauvegarde devait suivre.
#
# CE QUE CE SCRIPT SAUVE, ET POURQUOI CHAQUE MORCEAU
#
#   depot/           Le depot lui-meme, .git compris. Il est deja sur GitHub,
#                    mais un clone ne rend pas ce qui n'a jamais ete pousse.
#   depot.bundle     Toute l'histoire en un fichier, et ce fichier est CLONE
#                    pour de vrai avant qu'on le declare bon. Un bundle qu'on
#                    n'a pas ouvert n'est pas une sauvegarde, c'est un espoir.
#   S-vm/            Le banc : journaux, captures, scripts, cles. SANS les
#                    images disque, qui pesent des dizaines de gigaoctets et se
#                    refabriquent depuis l'image publiee.
#   claude/          La memoire, les skills et les transcriptions de Claude Code
#                    pour ce dossier. C'est le seul endroit ou vit le raisonnement
#                    qui a produit le code — le depot n'en garde que le resultat.
#   machine/         L'etat de la machine au moment de la sauvegarde : image
#                    demarree, regles kwin, configuration Waydroid, disques.
#                    Ce ne sont pas des fichiers a restaurer, ce sont des faits
#                    a relire quand on se demandera « c'etait quoi, deja ».
#   MANIFESTE.sha256 Une empreinte par fichier. « La copie est arrivee » doit
#                    etre une verification, pas une impression.
#
# ATTENTION, ET C'EST LA SEULE LIGNE DE CE FICHIER QUI COMPTE VRAIMENT :
# S-vm/ CONTIENT UNE CLE PRIVEE. Cette sauvegarde ne doit JAMAIS etre poussee
# sur un depot public, ni deposee sur un partage que d'autres lisent.
# C'est pour cette raison qu'elle ne se pose pas dans ~/Partage, que le monde
# Android lit — voir le choix de la destination plus bas.
set -uo pipefail

DEPOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUAND="$(date +%Y-%m-%d-%Hh%M)"
# ELLE NE VA PAS DANS ~/Partage, ET C'EST UNE DECISION, PAS UN DETAIL.
# Le dossier partage porte l'ACL « group:1023:rwx » — releve sur la machine —
# c'est-a-dire le groupe media_rw d'Android : TOUTE application Android
# autorisee au stockage peut y lire. Or cette sauvegarde contient la cle privee
# du banc. Elle va donc sur le grand disque, que seul Linux voit.
if [ -d "$HOME/Disque" ]; then
    DEFAUT="$HOME/Disque/S-sauvegardes/S-sauvegarde-$QUAND"
else
    DEFAUT="$HOME/S-sauvegardes/S-sauvegarde-$QUAND"
fi
CIBLE="${1:-$DEFAUT}"

dire() { printf 'sauvegarde : %s\n' "$*" >&2; }

command -v git >/dev/null || { dire "git absent"; exit 1; }
mkdir -p "$CIBLE" || { dire "impossible de creer $CIBLE"; exit 1; }
dire "destination : $CIBLE"

# --- 1. Le depot, tel quel --------------------------------------------------
dire "le depot…"
mkdir -p "$CIBLE/depot"
# --delete pour qu'une seconde sauvegarde dans le meme dossier ne garde pas les
# fichiers d'une passe precedente : une sauvegarde qui melange deux etats ment.
if command -v rsync >/dev/null; then
    rsync -a --delete "$DEPOT/" "$CIBLE/depot/"
else
    rm -rf "$CIBLE/depot" && cp -a "$DEPOT" "$CIBLE/depot"
fi

# --- 2. L'histoire, en un fichier, ET VERIFIEE ------------------------------
dire "l'histoire…"
git -C "$DEPOT" bundle create "$CIBLE/depot.bundle" --all >/dev/null 2>&1 \
    || { dire "le bundle a echoue"; exit 1; }
essai="$(mktemp -d)"
if git clone --quiet "$CIBLE/depot.bundle" "$essai/verif" >/dev/null 2>&1; then
    commits="$(git -C "$essai/verif" rev-list --count --all 2>/dev/null || echo 0)"
    tete="$(git -C "$essai/verif" rev-parse --short HEAD 2>/dev/null || echo '?')"
    dire "bundle relu : $commits commits, HEAD $tete"
else
    dire "LE BUNDLE NE SE CLONE PAS — sauvegarde incomplete"
    rm -rf "$essai"; exit 1
fi
rm -rf "$essai"

# --- 3. Le banc, sans les images disque -------------------------------------
if [ -d "$HOME/S-vm" ]; then
    dire "le banc…"
    mkdir -p "$CIBLE/S-vm"
    if command -v rsync >/dev/null; then
        rsync -a --delete --exclude='*.qcow2' --exclude='*.img' \
              --exclude='*.raw' --exclude='*.vhdx' "$HOME/S-vm/" "$CIBLE/S-vm/"
    else
        (cd "$HOME" && tar cf - --exclude='*.qcow2' --exclude='*.img' S-vm) \
            | (cd "$CIBLE/.." && tar xf -)
    fi
fi

# --- 4. Le raisonnement, pas seulement le resultat --------------------------
dire "la memoire et les transcriptions…"
mkdir -p "$CIBLE/claude"
for morceau in skills settings.json; do
    [ -e "$HOME/.claude/$morceau" ] && cp -a "$HOME/.claude/$morceau" "$CIBLE/claude/"
done
# Le dossier de projet encode le chemin : on le prend en entier, memoire comprise.
for d in "$HOME/.claude/projects"/*; do
    [ -d "$d" ] || continue
    mkdir -p "$CIBLE/claude/projects"
    cp -a "$d" "$CIBLE/claude/projects/"
done

# --- 5. L'etat de la machine, pour memoire ----------------------------------
dire "l'etat de la machine…"
mkdir -p "$CIBLE/machine"
{
    echo "# Releve du $QUAND, sur $(hostname)"
    echo
    echo "## Image demarree"
    rpm-ostree status 2>/dev/null | sed -n '1,12p'
    echo
    echo "## Depot"
    echo "HEAD        : $(git -C "$DEPOT" rev-parse HEAD 2>/dev/null)"
    echo "branche     : $(git -C "$DEPOT" branch --show-current 2>/dev/null)"
    echo "distant     : $(git -C "$DEPOT" remote get-url origin 2>/dev/null)"
    echo "non commite : $(git -C "$DEPOT" status --porcelain 2>/dev/null | wc -l) fichier(s)"
    echo
    echo "## Disques"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null
    echo
    echo "## Materiel"
    echo "$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null) $(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
    grep -m1 'model name' /proc/cpuinfo 2>/dev/null
    lspci 2>/dev/null | grep -iE 'vga|3d' | head -2
} > "$CIBLE/machine/releve.md" 2>/dev/null
for f in "$HOME/.config/kwinrulesrc" /var/lib/waydroid/waydroid.cfg; do
    [ -r "$f" ] && cp -a "$f" "$CIBLE/machine/" 2>/dev/null
done

# --- 6. Le mode d'emploi ----------------------------------------------------
cat > "$CIBLE/LISEZ-MOI.md" <<'MD'
# Sauvegarde du projet S

## Reprendre le travail ailleurs

```bash
git clone depot.bundle S          # toute l'histoire, sans reseau
cd S && git remote set-url origin git@github.com:gigigrenier86/s-os.git
```

Le dossier `depot/` porte le meme contenu, `.git` compris — il sert si le
bundle pose probleme, ou pour lire sans cloner.

## Ce qu'il y a dedans

| | |
|---|---|
| `depot/` | le depot, arbre de travail et `.git` |
| `depot.bundle` | toute l'histoire en un fichier, **clone pour de vrai** avant d'etre declare bon |
| `S-vm/` | le banc QEMU, sans les images disque |
| `claude/` | memoire, skills et transcriptions de Claude Code |
| `machine/` | l'etat de la machine au moment de la sauvegarde |
| `MANIFESTE.sha256` | une empreinte par fichier |

## Verifier que la copie est arrivee entiere

```bash
sha256sum -c MANIFESTE.sha256
```

## Une ligne qui compte

`S-vm/` contient une **cle privee**. Cette sauvegarde ne va sur aucun depot
public, ni sur un partage que d'autres lisent.
MD

# --- 7. L'empreinte, en dernier ---------------------------------------------
dire "les empreintes…"
( cd "$CIBLE" && find . -type f ! -name 'MANIFESTE.sha256' -print0 \
    | sort -z | xargs -0 sha256sum > MANIFESTE.sha256 ) 2>/dev/null

fichiers="$(wc -l < "$CIBLE/MANIFESTE.sha256" 2>/dev/null || echo 0)"
poids="$(du -sh "$CIBLE" 2>/dev/null | cut -f1)"
dire "$fichiers fichiers, $poids"
printf '%s\n' "$CIBLE"
