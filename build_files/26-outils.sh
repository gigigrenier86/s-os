#!/usr/bin/bash
set -euxo pipefail
source /ctx/build_files/lib-opt.sh

# ==========================================================================
# Les outils de developpement, tous DANS l'image
# ==========================================================================
# Demande de l'utilisateur : « du pret au moment meme ou je me connecte pour
# la premiere fois ». C'est la regle degagee trois fois cette nuit — trois
# scripts de Bazzite pris en defaut parce qu'ils differaient leur travail a un
# premier demarrage. Ici, rien n'est differe.

# ---------------------------------------------------------------- VS Code --
# Depot Microsoft, signe GPG. ~690 Mo installes, dans /usr/share/code : pas de
# detour par /opt pour celui-ci.
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
# Necessaire a Gemini CLI, qui exige Node 18 ou plus. Claude Code, lui, n'en a
# plus besoin depuis son installateur natif.
dnf5 install -y nodejs npm

# --------------------------------------------------------- Gemini CLI -----
# Installation globale au moment de la construction : le module atterrit dans
# /usr/lib/node_modules, donc DANS l'image, et non dans un dossier utilisateur.
npm install -g @google/gemini-cli

# -------------------------------------------------------- Claude Code -----
# L'installateur natif verifie le SHA-256 du binaire avant de l'installer —
# la regle « aucun binaire sans origine certaine » est donc satisfaite.
#
# Il ecrit normalement dans ~/.local/bin. On lui donne un HOME jetable, puis on
# range le binaire dans l'image. CLAUDE_INSTALL_ALLOW_SUDO=1 lui dit qu'on sait
# ce qu'on fait en tant que root.
#
# Consequence a connaitre : le binaire de /usr/bin ne pourra pas se mettre a
# jour lui-meme, /usr etant en lecture seule. Ce n'est pas une perte — la
# reconstruction quotidienne de l'image s'en charge — et un utilisateur qui
# veut une version plus fraiche peut toujours lancer l'installateur pour son
# compte : son ~/.local/bin passe devant /usr/bin dans le PATH.
(
  export HOME=/tmp/installation-claude
  export CLAUDE_INSTALL_ALLOW_SUDO=1
  mkdir -p "$HOME"
  curl -fsSL https://claude.ai/install.sh | bash
  BIN="$(find "$HOME" -type f -name claude -perm -u+x | head -n1)"
  [[ -n "$BIN" ]] || { echo "ECHEC : binaire claude introuvable apres installation." >&2; find "$HOME" -maxdepth 4 >&2; exit 1; }
  install -Dm0755 "$BIN" /usr/bin/claude
  rm -rf "$HOME"
)

# -------------------------------------------------------- Antigravity ----
# RESERVE ASSUMEE, decidee par l'utilisateur le 2026-08-20 : ce depot impose
# « gpgcheck=0 » — les paquets ne sont PAS signes. Le transport est du HTTPS
# vers un domaine Google, donc le serveur est authentifie ; le contenu ne
# l'est pas. C'est le seul endroit de cette image ou un binaire entre sans
# signature, et c'est ecrit ici pour que ce soit un choix et non un oubli.
cat > /etc/yum.repos.d/antigravity.repo <<'REPO'
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
REPO
dnf5 install -y antigravity || {
    echo "AVERTISSEMENT : Antigravity n'a pas pu etre installe." >&2
    echo "                Les autres outils restent en place." >&2
}
rm -f /etc/yum.repos.d/antigravity.repo

# Antigravity peut s'installer dans /opt selon les versions : on range si c'est
# le cas, on ne fait rien sinon.
if [[ -d /opt && -n "$(ls -A /opt 2>/dev/null)" ]]; then
    echo "Contenu inattendu dans /opt apres Antigravity :"
    ls -la /opt
fi

# ---------------------------------------------------------- Verification --
manque=0
for b in /usr/bin/code /usr/bin/node /usr/bin/npm /usr/bin/claude; do
    [[ -x "$b" ]] || { echo "ABSENT : $b" >&2; manque=1; }
done
command -v gemini >/dev/null || { echo "ABSENT : gemini" >&2; manque=1; }
command -v antigravity >/dev/null || echo "AVERTISSEMENT : antigravity absent (depot non signe, echec tolere)" >&2
[[ "$manque" -eq 0 ]] || exit 1

echo "Outils poses :"
/usr/bin/code --version 2>/dev/null | head -1 | sed 's/^/  VS Code   /'
/usr/bin/node --version  | sed 's/^/  Node      /'
/usr/bin/claude --version 2>/dev/null | head -1 | sed 's/^/  Claude    /' || echo "  Claude    version non lue"
gemini --version 2>/dev/null | head -1 | sed 's/^/  Gemini    /' || echo "  Gemini    version non lue"
