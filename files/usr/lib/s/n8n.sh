#!/usr/bin/bash
set -euo pipefail
# s-n8n — l'amorce de n8n, l'atelier d'automatisation de S.
#
# --lancer : genere la cle de chiffrement si absente, puis lance le serveur.
#            La cle vit dans ~/.local/share/s/n8n/.encryption-key, JAMAIS dans
#            l'image : quelqu'un qui installe S ne doit pas heriter de la cle
#            d'un autre (meme regle que le mot de passe RDP).
# --ouvrir  : ouvre le portail dans Vivaldi, en fenetre d'application.

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/s/n8n"
CLE="$DATA/.encryption-key"

case "${1:-}" in
  --lancer)
    mkdir -p "$DATA"
    if [[ ! -s "$CLE" ]]; then
      python3 -c 'import secrets; print(secrets.token_hex(32))' > "$CLE"
      chmod 600 "$CLE"
    fi
    N8N_ENCRYPTION_KEY="$(cat "$CLE")"
    export N8N_ENCRYPTION_KEY
    export N8N_USER_FOLDER="$DATA"
    # Lie au port de bouclage SEUL, jamais expose au reseau — meme choix que
    # s-sora (127.0.0.1:8613). Pour y acceder a distance, on passe par le RDP
    # deja en place, pas par un port ouvert.
    export N8N_HOST=127.0.0.1
    export N8N_PORT=5678
    export N8N_SECURE_COOKIE=false
    ZONE="$(readlink -f /etc/localtime 2>/dev/null | sed 's#^/usr/share/zoneinfo/##')"
    export GENERIC_TIMEZONE="${ZONE:-America/Montreal}"
    exec /usr/bin/n8n start
    ;;
  --ouvrir)
    exec /usr/bin/vivaldi --app="http://127.0.0.1:5678" &
    ;;
  *)
    echo "usage : s-n8n --lancer | --ouvrir" >&2
    exit 2
    ;;
esac
