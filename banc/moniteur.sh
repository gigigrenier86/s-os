#!/usr/bin/bash
# Envoie une commande au moniteur QEMU et rend sa reponse.
# Le moniteur renvoie en echo chaque caractere tape : on nettoie.
exec 3<>/dev/tcp/127.0.0.1/4445 || { echo "moniteur injoignable"; exit 1; }
printf '%s\n' "$*" >&3
sleep 2
timeout 3 cat <&3 | sed 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r//g' | tail -n +2
