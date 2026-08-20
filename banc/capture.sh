#!/usr/bin/bash
# Prend une capture par le moniteur et la convertit en PNG lisible.
P="${1:-ecran}"
rm -f "$P.ppm" "$P.png"
exec 3<>/dev/tcp/127.0.0.1/4445 || { echo "moniteur injoignable"; exit 1; }
printf 'screendump C:/Users/Ghis/Desktop/S-vm/%s.ppm\n' "$P" >&3
sleep 3
exec 3<&-
[ -f "$P.ppm" ] && echo "capture : $(stat -c%s "$P.ppm") octets" || echo "echec capture"
