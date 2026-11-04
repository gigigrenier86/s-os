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
#
# HOME vaut /root dans l'image, lien vers /var/roothome — un lien MORT pendant
# la construction. npm ecrit son cache et ses journaux dans $HOME/.npm ; sans
# cette redirection, il meurt sur « ENOTDIR: mkdir '/root' » (mesure sur le
# build 39895389676). /tmp est un tmpfs monte par le Containerfile : rien n'y
# fuit dans l'image.
# LA VERSION EST EPINGLEE, ET C'EST UNE REPONSE A UNE PANNE MESUREE.
# « npm install -g n8n » prenait « latest ». Le 2026-11-02 elle valait 2.45.7 et
# la construction passait ; le 2026-11-03 elle valait 2.46.4 et TOUTES les
# constructions tombent ici, y compris le passage nocturne :
#
#   npm error code EBADPLATFORM
#   npm error notsup Unsupported platform for @napi-rs/canvas-linux-arm64-musl@1.0.11:
#       wanted {"os":"linux","cpu":"arm64","libc":"musl"} (current: x64, glibc)
#
# Ce paquet n'est qu'une dependance OPTIONNELLE de @napi-rs/canvas, que npm
# devrait ignorer sur une autre plateforme ; 2.46.4 le rend exigible. Cause
# amont, non cherchee plus loin. Sans epingle, une regression d'amont casse
# l'image entiere un matin au hasard, et plus aucune mise a jour n'arrive.
#
# POUR DESEPINGLER : essayer « npm install -g n8n@latest » dans un conteneur
# fedora jetable (podman run --rm registry.fedoraproject.org/fedora:44) ; si
# EBADPLATFORM a disparu, monter la version ici.
N8N_VERSION=2.45.7
HOME=/tmp NPM_CONFIG_PREFIX=/usr npm install -g "n8n@${N8N_VERSION}"

# Retirer la chaine de construction : elle ne doit pas rester dans l'image.
dnf5 remove -y gcc-c++ make python3-devel

# ---------------------------------------------------------- Verification --
# Le controle qui compte vraiment : rien n'a-t-il atterri hors de /usr ?
# Un npm qui poserait dans /usr/local ecrirait dans /var (lien ostree) et
# « reussirait » en silence — l'echec le pire des deux.
RACINE="$(HOME=/tmp NPM_CONFIG_PREFIX=/usr npm root -g)"
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
HOME=/tmp /usr/bin/n8n --version 2>/dev/null | sed 's/^/  n8n         /' || true
