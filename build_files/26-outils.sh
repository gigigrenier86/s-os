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

# Gemini CLI exige Node 18 ou plus : on le verifie au lieu de l'esperer.
NODE_MAJEUR="$(node --version | sed 's/^v//; s/\..*//')"
[[ "${NODE_MAJEUR}" -ge 18 ]] || { echo "ECHEC : Node ${NODE_MAJEUR} < 18." >&2; exit 1; }

# --------------------------------------------------------- Gemini CLI -----
# Le prefixe global par defaut de npm est /usr/local, qui est un LIEN : d'ou
# « ENOTDIR: not a directory, mkdir '/usr/local' » au premier essai. On force
# le prefixe sur /usr — les modules vont dans /usr/lib/node_modules et les
# binaires dans /usr/bin, donc dans l'image.
#
# Le reglage reste LOCAL a cette commande. Un « npm config set prefix -g »
# ecrirait dans /etc/npmrc, serait livre dans l'image, et casserait le
# « npm i -g » de l'utilisateur apres le demarrage — lui doit viser
# /usr/local, qui est inscriptible une fois la machine installee.
#
# HOME est redirige : par defaut il vaut /root, lien vers var/roothome, donc
# le cache et les journaux de npm partiraient hors de l'image.
env HOME=/tmp/npm-maison \
    npm_config_prefix=/usr \
    npm_config_cache=/tmp/npm-cache \
    npm_config_fund=false \
    npm_config_audit=false \
    npm_config_update_notifier=false \
    npm install -g @google/gemini-cli
rm -rf /tmp/npm-maison /tmp/npm-cache

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

# -------------------------------------------------------- Antigravity ----
# RESERVE ASSUMEE, decidee par l'utilisateur le 2026-08-20 : ce depot impose
# « gpgcheck=0 » — les paquets ne sont PAS signes. Le transport est du HTTPS
# vers un domaine Google, donc le serveur est authentifie ; le contenu ne
# l'est pas. C'est le SEUL endroit de cette image ou un binaire entre sans
# signature, et c'est ecrit ici pour que ce soit un choix et non un oubli.
cat > /etc/yum.repos.d/antigravity.repo <<'REPO'
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
REPO
if dnf5 install -y antigravity; then
    ANTIGRAVITY_POSE=1
else
    ANTIGRAVITY_POSE=0
    echo "AVERTISSEMENT : Antigravity non installe. Les autres outils restent." >&2
fi
rm -f /etc/yum.repos.d/antigravity.repo

# ---------------------------------------------------------- Verification --
# Le controle qui compte vraiment : rien n'a-t-il atterri hors de /usr et
# /etc ? Un fichier dans /var serait perdu au deploiement, sans le moindre
# message. C'est l'echec silencieux, le pire des deux.
if rpm -ql code claude-code 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : des fichiers ont ete poses hors de /usr et /etc." >&2
    exit 1
fi

manque=0
for b in /usr/bin/code /usr/bin/node /usr/bin/npm /usr/bin/claude /usr/bin/gemini; do
    [[ -e "$b" ]] || { echo "ABSENT : $b" >&2; manque=1; }
done
[[ -d /usr/lib/node_modules/@google/gemini-cli ]] || { echo "ABSENT : le module gemini-cli" >&2; manque=1; }
[[ "$manque" -eq 0 ]] || exit 1

echo "Outils poses :"
/usr/bin/code   --version 2>/dev/null | head -1 | sed 's/^/  VS Code      /'
/usr/bin/node   --version                        | sed 's/^/  Node         /'
/usr/bin/claude --version 2>/dev/null | head -1 | sed 's/^/  Claude Code  /' || echo "  Claude Code  version non lue"
echo "  Gemini CLI   $(ls -d /usr/lib/node_modules/@google/gemini-cli >/dev/null && echo present)"
echo "  Antigravity  $([[ "${ANTIGRAVITY_POSE}" -eq 1 ]] && echo 'pose (depot non signe)' || echo 'absent')"
