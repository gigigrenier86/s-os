#!/usr/bin/bash
# Envoie une ligne a la console serie de l'invite et rend ce qui revient.
# Chaque appel ouvre une connexion neuve : la session shell, elle, vit cote
# invite et survit aux deconnexions.
DELAI="${DELAI:-3}"
exec 3<>/dev/tcp/127.0.0.1/4446 || { echo "console serie injoignable"; exit 1; }
printf '%s\n' "$*" >&3
sleep "$DELAI"
timeout 4 cat <&3 | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\][0-9;]*[^\x07]*\x07//g'
