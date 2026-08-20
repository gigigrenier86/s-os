#!/usr/bin/bash
# Envoie plusieurs lignes dans UNE SEULE connexion a la console serie, avec une
# pause entre chacune. Necessaire pour une sequence de connexion : reconnecter
# entre deux lignes ferait repartir l'invite de login a zero.
exec 3<>/dev/tcp/127.0.0.1/4446 || { echo "console injoignable"; exit 1; }
( timeout "${LIRE:-20}" cat <&3 | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\][0-9;]*[^\x07]*\x07//g' ) &
LECTEUR=$!
for ligne in "$@"; do
  printf '%s\n' "$ligne" >&3
  sleep "${PAUSE:-3}"
done
wait $LECTEUR
