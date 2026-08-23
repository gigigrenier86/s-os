#!/usr/bin/bash
# GRIMOIRE — lire la cible d'un raccourci Windows (.lnk) sans bibliothèque
# PREUVE : 2026-08-23. Banc sur trois fichiers : un .lnk portant le chemin en
#          ANSI et en UTF-16 (rendu correct), un ne le portant qu'en UTF-16
#          (rendu correct — c'est le cas que le seul motif ANSI manquerait),
#          un fichier de 200 octets nuls (rien rendu, aucune erreur).
# POUR   : moissonner ce qu'un installateur Windows a posé, quand on ne peut
#          pas compter sur winemenubuilder — Proton le désactive couramment,
#          et alors applications/wine/ reste vide.
#
# POURQUOI ON NE PARSE PAS LE FORMAT
# « Shell Link (.LNK) » a une demi-douzaine de structures optionnelles, chaînées
# par un champ de drapeaux : LinkTargetIDList, LinkInfo, StringData, ExtraData.
# La cible peut vivre dans LinkInfo.LocalBasePath, dans sa variante Unicode, ou
# seulement dans une liste d'identifiants de shell qu'il faudrait interpréter.
# Écrire tout cela pour en tirer un chemin serait beaucoup de code, et du code
# qui casse sur la variante qu'on n'avait pas prévue.
#
# CE QU'ON FAIT À LA PLACE, ET CE QUE ÇA VAUT
# On cherche dans les octets bruts un chemin absolu se terminant par « .exe »,
# dans les deux encodages, et on garde LE PLUS LONG — c'est le chemin complet
# plutôt qu'un fragment de nom de dossier. Ce n'est pas exact au sens du format,
# c'est exact au sens du résultat sur ce que produisent de vrais installateurs.
#
# LA LIMITE, NOMMÉE : un .lnk dont la cible n'existerait QUE sous forme de
# LinkTargetIDList ne rendra rien. Le geste appelant doit donc compter ce qu'il
# a ignoré et le dire, jamais se taire — c'est le silence, pas l'échec, qui a
# rendu la panne de VLC introuvable.

lire_cible_lnk() {
    python3 - "$1" <<'PY' 2>/dev/null
import re
import sys

try:
    donnees = open(sys.argv[1], "rb").read()
except OSError:
    sys.exit(0)

trouves = set()

motif = (rb'[A-Za-z]:\\(?:[^\x00-\x1f\\/:*?"<>|]+\\)*'
         rb'[^\x00-\x1f\\/:*?"<>|]+\.[eE][xX][eE]')
for m in re.finditer(motif, donnees):
    trouves.add(m.group().decode("latin-1"))

# La meme chose en UTF-16LE : un octet nul apres chaque caractere.
motif16 = rb'[A-Za-z]\x00:\x00\\\x00(?:[^\x00]\x00)+?\.\x00[eE]\x00[xX]\x00[eE]\x00'
for m in re.finditer(motif16, donnees):
    try:
        trouves.add(m.group().decode("utf-16-le"))
    except (UnicodeDecodeError, ValueError):
        pass

if trouves:
    print(max(trouves, key=len))
PY
}

# Chemin Windows -> chemin Linux, par la table que Wine tient lui-même. Vaut
# pour TOUS les lecteurs mappés, pas seulement C:.
#   BARRE=$(printf '\134\134')   # doublée : « tr » interprète les échappements
vers_linux_wine() {
    local prefixe="$1" win="$2" lettre reste barre
    barre=$(printf '\134\134')
    lettre="$(printf '%s' "${win:0:1}" | tr 'A-Z' 'a-z')"
    reste="$(printf '%s' "${win:3}" | tr "$barre" '/')"
    printf '%s/dosdevices/%s:/%s' "$prefixe" "$lettre" "$reste"
}
