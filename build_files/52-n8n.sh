#!/usr/bin/bash
set -euxo pipefail

# ==========================================================================
# n8n — l'atelier d'automatisation, pose NATIF dans /usr
# ==========================================================================
# POURQUOI NATIF, PAS UN CONTENEUR. n8n est une application Node ; hors
# conteneur, son installation officielle est « npm install -g n8n », qui pose
# dans /usr/lib/node_modules. Le conteneur, lui, ne se « pre-cuit » PAS dans
# une image bootc : l'image du conteneur atterrit dans /var/lib/containers, et
# /var n'entre pas dans l'image (regle de 26-outils.sh). Un conteneur ne
# serait donc disponible qu'apres un premier « podman pull » — un mecanisme de
# premier demarrage, exactement ce que ce depot refuse.

# Les dependances natives de n8n (better-sqlite3, ...) se compilent a
# l'installation si aucun binaire pre-compile ne correspond a la plateforme.
# On fournit la chaine de construction, puis on la retire — patron de
# llama.cpp (2026-08-30), qui faisait deja ce geste.
dnf5 install -y gcc-c++ make python3-devel

# On force le prefixe /usr : Fedora regle deja npm ainsi, mais la regle de ce
# depot est de VERIFIER plutot que de supposer — le controle est plus bas.
NPM_CONFIG_PREFIX=/usr npm install -g n8n

# Retirer la chaine de construction : elle ne doit pas rester dans l'image.
dnf5 remove -y gcc-c++ make python3-devel

# ---------------------------------------------------------- Verification --
# Le controle qui compte vraiment : rien n'a-t-il atterri hors de /usr ?
# Un npm qui poserait dans /usr/local ecrirait dans /var (lien ostree) et
# « reussirait » en silence — l'echec le pire des deux.
RACINE="$(NPM_CONFIG_PREFIX=/usr npm root -g)"
case "$RACINE" in
  /usr/*) : ;;
  *) echo "ECHEC : node_modules global hors de /usr ($RACINE)." >&2; exit 1 ;;
esac

[[ -x /usr/bin/n8n ]] || { echo "ABSENT : /usr/bin/n8n" >&2; exit 1; }

N8N_BIN="$(readlink -f /usr/bin/n8n)"
case "$N8N_BIN" in
  /usr/*) : ;;
  *) echo "ECHEC : /usr/bin/n8n pointe hors de /usr ($N8N_BIN)." >&2; exit 1 ;;
esac

# Une ligne cosmetique ne doit JAMAIS faire tomber une image bonne par ailleurs.
/usr/bin/n8n --version 2>/dev/null | sed 's/^/  n8n         /' || true
