#!/usr/bin/bash
set -euxo pipefail

# ==========================================================================
# Les outils de developpement, tous DANS l'image
# ==========================================================================
# « Du pret au moment meme ou je me connecte pour la premiere fois. » Rien
# n'est differe a un premier demarrage : trois scripts de Bazzite ont ete pris
# en defaut sur ce point, tous parce qu'ils ecrivaient un marqueur qui les
# empechait ensuite de reessayer.
#
# REGLE GENERALE DE CE FICHIER, apprise a ses depens :
# sur ostree, /opt, /usr/local, /home, /root, /srv et /mnt sont des LIENS vers
# /var — et /var n'entre pas dans l'image. Un installateur qui y ecrit
# « reussit » en silence et ne livre rien. Quand un outil accepte un prefixe,
# on le vise sur /usr ; sinon seulement, on deplace apres coup.

# ---------------------------------------------------------------- VS Code --
# Depot Microsoft, signe. S'installe dans /usr/share/code : aucun detour.
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat > /etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
dnf5 install -y code
rm -f /etc/yum.repos.d/vscode.repo

# ------------------------------------------------------------- Node.js ----
# Fedora 44 versionne Node : le paquet s'appelle « nodejs20 », et ce sont
# « nodejs20-bin » et « nodejs20-npm-bin » qui posent les liens sans numero.
# On installe donc par le CHEMIN plutot que par le nom — ainsi le script
# survivra au passage a Node 22 ou 24 sans qu'on y touche.
dnf5 install -y /usr/bin/node /usr/bin/npm

# -------------------------------------------------------- Claude Code -----
# Il existe un depot RPM officiel et SIGNE — verifie le 2026-08-20 :
# repodata/repomd.xml et la cle PGP repondent tous deux en HTTP 200.
#
# On l'emploie plutot que l'installateur « curl | bash », qui ecrit dans
# $HOME : sur cette image HOME vaut /root, lien vers var/roothome, donc tout
# serait parti hors de l'image sans qu'aucune erreur ne le signale.
#
# L'installateur natif reste le bon outil APRES le demarrage, lance par
# l'utilisateur pour son compte : il pose dans ~/.local, qui est inscriptible
# et passe devant /usr/bin dans le PATH. L'image fournit un plancher.
rpm --import https://downloads.claude.ai/keys/claude-code.asc
cat > /etc/yum.repos.d/claude-code.repo <<'REPO'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
REPO
dnf5 install -y claude-code
rm -f /etc/yum.repos.d/claude-code.repo

# ---------------------------------------------------------- Verification --
# Le controle qui compte vraiment : rien n'a-t-il atterri hors de /usr et
# /etc ? Un fichier dans /var serait perdu au deploiement, sans le moindre
# message. C'est l'echec silencieux, le pire des deux.
if rpm -ql code claude-code 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : des fichiers ont ete poses hors de /usr et /etc." >&2
    exit 1
fi

manque=0
for b in /usr/bin/code /usr/bin/node /usr/bin/npm /usr/bin/claude; do
    [[ -e "$b" ]] || { echo "ABSENT : $b" >&2; manque=1; }
done
[[ "$manque" -eq 0 ]] || exit 1

# --------------------------------------------------------------------------
# Le rapport, et pourquoi il ne peut plus rien casser
# --------------------------------------------------------------------------
# La construction precedente a echoue ICI, alors que TOUT s'etait correctement
# installe : « code --version » lance en root sans --user-data-dir heurte le
# garde-fou de VS Code et sort en 1, ce que « set -e » a transforme en echec
# de construction.
#
# Deux corrections. Le drapeau est ajoute — c'est le seul qui leve ce
# garde-fou, l'enquete l'avait dit et je ne l'avais applique qu'a
# --install-extension. Et surtout, chaque ligne de rapport se termine
# desormais par « || true » : une ligne cosmetique ne doit JAMAIS pouvoir
# faire tomber une image qui, par ailleurs, est bonne.
echo "Outils poses :"
/usr/bin/code --user-data-dir /tmp/version-vscode --version 2>/dev/null | head -1 | sed 's/^/  VS Code      /' || true
rm -rf /tmp/version-vscode
/usr/bin/node   --version 2>/dev/null | sed 's/^/  Node         /' || true
/usr/bin/claude --version 2>/dev/null | head -1 | sed 's/^/  Claude Code  /' || true
