#!/usr/bin/bash
set -euo pipefail
# EXIGER LA SIGNATURE DE S, ET PAS SEULEMENT LA POSER.
#
# CE QUE CE SCRIPT CHANGE, EN UNE PHRASE : jusqu'ici la machine amorcait et
# mettait a jour ce que « ghcr.io/gigigrenier86/s-os:latest » designait, sans
# qu'aucune signature soit exigee. « rpm-ostree status » le disait lui-meme :
# « ostree-unverified-registry ». Apres ce script, une image non signee par la
# cle de S est REFUSEE au telechargement.
#
# POURQUOI UNE CLE ET NON LA SIGNATURE SANS CLE. La construction signe DEUX
# fois. La signature sans cle prouve davantage — ce depot, ce fichier de
# workflow, cette branche, ce commit — mais AUCUNE MACHINE NE PEUT L'EXIGER :
# « containers/image » impose « subjectEmail » avec « fulcio », et le
# certificat d'une identite GitHub Actions n'en porte pas. Mesure du
# 2026-08-26 : « Required email ... not found (got []) ». C'est pour cette
# raison que l'amont epingle « ublue-os.pub », et on suit son patron.
#
# CE QUI SE PASSE SI LA SIGNATURE MANQUE UN JOUR : la mise a jour ECHOUE, la
# machine garde l'image qu'elle a, et elle demarre normalement — policy.json
# n'est consulte qu'au TELECHARGEMENT, jamais a l'amorcage. Et /etc reste
# inscriptible sur un systeme ostree : il y a toujours une porte de sortie.

POLITIQUE=/etc/containers/policy.json
CLE=/etc/pki/containers/s-os.pub
DECLARATION=/etc/containers/registries.d/gigigrenier86.yaml
DEPOT=ghcr.io/gigigrenier86

# LES DEUX FICHIERS VIENNENT DU « COPY files/ / », QUI EST PLUS HAUT DANS LE
# CONTAINERFILE. S'ils manquent, on echoue ICI plutot que de livrer une image
# qui exige une signature qu'elle ne saura pas verifier — c'est-a-dire une
# machine qui refuse ses propres mises a jour, et qui ne le dira qu'au premier
# « bootc upgrade », loin d'ici.
for f in "$CLE" "$DECLARATION"; do
    [ -s "$f" ] || { echo "ECHEC : $f manque — le COPY ne l'a pas pose."; exit 1; }
done
grep -q 'BEGIN PUBLIC KEY' "$CLE" \
    || { echo "ECHEC : $CLE n'est pas un PEM de cle publique."; exit 1; }
echo "  cle presente     : $CLE"
echo "  declaration      : $DECLARATION"

# On MODIFIE la politique livree par containers-common, on ne la remplace pas :
# elle porte les entrees de Red Hat, de toolbx et d'ublue-os, et les perdre
# rendrait S moins sur qu'avant.
python3 - "$POLITIQUE" "$CLE" "$DEPOT" << 'PY'
import json, sys
chemin, cle, depot = sys.argv[1], sys.argv[2], sys.argv[3]
with open(chemin, encoding="utf-8") as f:
    politique = json.load(f)
docker = politique.setdefault("transports", {}).setdefault("docker", {})
# « matchRepository » et non « matchExact » : une signature cosign ne porte que
# le depot, jamais l'etiquette. C'est ce que la page de manuel dit, et c'est ce
# que l'entree d'ublue-os emploie.
docker[depot] = [{
    "type": "sigstoreSigned",
    "keyPath": cle,
    "signedIdentity": {"type": "matchRepository"},
}]
# Les cles d'un objet JSON n'ont pas d'ordre, mais un fichier relu par un humain
# en a un : on remet l'entree fourre-tout a la fin, la ou containers-common la
# met, pour que le diff reste lisible.
if "" in docker:
    fourre = docker.pop("")
    docker[""] = fourre
with open(chemin, "w", encoding="utf-8") as f:
    json.dump(politique, f, indent=4, ensure_ascii=False)
    f.write("\n")
PY

# LE CONTROLE EST LA MOITIE DU TRAVAIL. Un « json.dump » qui reussit ne prouve
# pas que l'entree est la ou il faut : on relit le fichier ECRIT.
python3 - "$POLITIQUE" "$CLE" "$DEPOT" << 'PY'
import json, sys
chemin, cle, depot = sys.argv[1], sys.argv[2], sys.argv[3]
politique = json.load(open(chemin, encoding="utf-8"))
entree = politique["transports"]["docker"].get(depot)
assert entree, "l'entree %s est absente de la politique relue" % depot
assert entree[0]["type"] == "sigstoreSigned", entree[0]["type"]
assert entree[0]["keyPath"] == cle, entree[0]["keyPath"]
assert politique["transports"]["docker"].get("") is not None, "l'entree par defaut a disparu"
assert politique["transports"]["docker"].get("ghcr.io/ublue-os"), "l'entree ublue-os a disparu"
print("  politique relue  : %s exige une signature sigstore" % depot)
print("  ublue-os         : intact")
PY
