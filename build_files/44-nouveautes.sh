#!/usr/bin/bash
# Le resume de cette construction, pose une fois pour que s-nouveautes
# (files/usr/bin/s-nouveautes) ait quelque chose a dire au premier
# demarrage sur cette image.
#
# TROUVE PAR LE PEINTRE, 2026-09-05 : S se reconstruit et se met a jour
# chaque nuit, signe et verifie (CLAUDE.md, 2026-08-26) — et rien a l'ecran
# n'a jamais dit a l'utilisateur qu'une nouvelle version venait d'arriver.
#
# POURQUOI UN FICHIER, PAS UNE ETIQUETTE OCI LUE A CHAUD. Les etiquettes
# posees par build.yml (org.opencontainers.image.version, etc., voir
# CLAUDE.md 2026-08-26) ne se lisent que depuis L'EXTERIEUR de l'image — un
# registre, ou skopeo. Rien a l'interieur d'un conteneur en marche ne peut
# relire ses propres etiquettes OCI sans appeler le registre lui-meme, ce
# qu'une machine hors ligne ne pourrait pas faire. Un fichier pose a la
# construction, lui, est toujours la.
set -euo pipefail

echo "=== 44-nouveautes : le resume de cette construction ==="

DEST=/usr/share/s/version
mkdir -p "$DEST"

# « $S_RESUME » VIENT DE L'ARG DU CONTAINERFILE, LUI-MEME VENU DE build.yml
# (« git log -1 --format=%s » sur le runner, AVANT le build — .git n'entre
# jamais dans le contexte « ctx », voir le Containerfile : la seule chose
# qu'il copie est build_files/). Une construction locale (podman build sans
# --build-arg) le laisse vide ; s-nouveautes s'en accommode en affichant la
# version seule plutot qu'un resume absent.
printf '%s\n' "${S_RESUME:-}" > "$DEST/resume.txt"
echo "  resume pose   : $DEST/resume.txt (\"${S_RESUME:-<vide>}\")"

echo "=== 44-nouveautes : fait ==="
