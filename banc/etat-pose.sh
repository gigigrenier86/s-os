#!/usr/bin/bash
# Rend l'etat de la pose en UNE ligne, plus le detail si c'est termine.
# Le code de sortie porte le verdict, pour qu'une veille sache s'arreter :
#   0  en cours    10 termine    11 echec    12 disparu sans marqueur
#
# Le cas 12 est le plus important : sans lui, un processus tue laisserait la
# veille silencieuse, et le silence se lit exactement comme "ca travaille".

GIO=$(awk '/vdb / {printf "%.2f", $10*512/1073741824}' /proc/diskstats 2>/dev/null)
[ -z "$GIO" ] && GIO="?"

if grep -q '=== TERMINE' /root/pose.log 2>/dev/null; then
    echo "TERMINE -- ${GIO} Gio ecrits sur la Seagate"
    tail -8 /root/pose.log
    exit 10
fi

if grep -q '=== ECHEC' /root/pose.log 2>/dev/null; then
    echo "ECHEC -- ${GIO} Gio ecrits"
    tail -15 /root/pose.log
    exit 11
fi

if pgrep -f 'bootc install' >/dev/null 2>&1; then
    DERNIERE=$(tail -1 /root/pose.log 2>/dev/null | cut -c1-90)
    echo "en cours : ${GIO} Gio ecrits | ${DERNIERE}"
    exit 0
fi

echo "PROCESSUS DISPARU sans marqueur de fin -- ${GIO} Gio ecrits"
tail -15 /root/pose.log 2>/dev/null
exit 12
