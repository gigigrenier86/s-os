#!/usr/bin/bash
# S — un depot actif dont la cle n'existe pas est une bombe a retardement.
#
# CE SCRIPT NE DESACTIVE RIEN AUJOURD'HUI, ET C'EST LE BON RESULTAT.
# Sur l'image du 2026-08-23 il rend « desactives : 0 ». Il reste parce que
# l'invariant qu'il tient vaut pour toutes les images a venir : aucun depot
# actif ne doit declarer une cle GPG locale absente. Le jour ou l'amont en
# reintroduira un, la construction echouera ici plutot que sur la machine de
# quelqu'un.
#
# CE QUI L'A FAIT NAITRE, ET L'ERREUR QU'IL A SERVI A CORRIGER. La fabrication
# de l'ISO echouait ainsi :
#
#   Failed to retrieve GPG key for repo 'terra-mesa': Could not read a file://
#   file for file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra44-mesa
#
# J'en ai conclu que la cle manquait de l'image, sur la foi d'une liste que
# j'avais moi-meme tronquee a vingt lignes — les cles terra y allaient jusqu'a
# terra43, et je n'ai pas vu que terra44 et terra45 suivaient. CE SCRIPT M'A
# DEMENTI : il a parcouru la vraie image et n'a trouve aucun depot a corriger.
#
# LA VRAIE CAUSE. bootc-image-builder resout ses dependances DANS SON PROPRE
# CONTENEUR. Il lit les fichiers de depot de l'image de S, mais un
# « gpgkey=file:///etc/pki/rpm-gpg/... » y designe SON systeme de fichiers a
# lui, ou aucune cle terra n'existe. Le chemin est valide dans l'image et
# introuvable la ou il est lu — exactement la meme famille de piege que
# pressure-vessel reservant « /usr », deja consignee au carnet.
#
# Le remede est donc dans l'ATELIER, pas dans l'image : .github/workflows/iso.yml
# extrait /etc/pki/rpm-gpg de l'image de S et le monte dans le conteneur de
# bootc-image-builder. On ne touche pas au depot terra : il est sain, et le
# desactiver aurait prive la machine reelle de ses mises a jour Mesa pour
# contourner une limite d'un outil de fabrication.
#
# CE QU'IL FAIT QUAND IL TROUVE QUELQUE CHOSE. Il desactive le depot, il ne
# fabrique PAS la cle manquante en recopiant celle d'une autre version sous le
# nom attendu : une signature qu'on renomme n'est plus une verification.
#
# Le traitement est GENERIQUE — jamais un nom de depot en dur — parce qu'un
# correctif qui nomme « terra-mesa » n'attraperait pas le suivant.
set -euo pipefail

echo "=== 44-depots : les depots actifs dont la cle a disparu ==="

command -v python3 >/dev/null || { echo "ECHEC : python3 absent de l'image." >&2; exit 1; }

python3 - <<'PY'
import glob, os, platform, re, sys

# $releasever et $basearch se lisent, ils ne se supposent pas : une image
# reconstruite sur la Fedora suivante changerait le premier.
releasever = ""
for ligne in open("/usr/lib/os-release", encoding="utf-8"):
    if ligne.startswith("VERSION_ID="):
        releasever = ligne.split("=", 1)[1].strip().strip('"')
basearch = platform.machine()
print(f"  releasever = {releasever}   basearch = {basearch}")
if not releasever:
    sys.exit("ECHEC : VERSION_ID introuvable dans os-release.")

def developper(chemin):
    for nom, val in (("releasever", releasever), ("basearch", basearch)):
        chemin = chemin.replace("$" + nom, val).replace("${" + nom + "}", val)
    return chemin

desactives, gardes, sans_cle_locale = [], [], 0

for fichier in sorted(glob.glob("/etc/yum.repos.d/*.repo")):
    lignes = open(fichier, encoding="utf-8").read().splitlines()

    # Premiere passe : pour chaque section, son etat et sa cle.
    sections, courante = {}, None
    for i, l in enumerate(lignes):
        m = re.match(r"^\[(.+)\]\s*$", l)
        if m:
            courante = m.group(1)
            sections[courante] = {"debut": i, "enabled": None, "gpgkey": None}
        elif courante:
            if l.startswith("enabled="):
                sections[courante]["enabled"] = (i, l.split("=", 1)[1].strip())
            elif l.startswith("gpgkey="):
                sections[courante]["gpgkey"] = l.split("=", 1)[1].strip()

    modifie = False
    # DE LA FIN VERS LE DEBUT, et ce n'est pas un detail : inserer une ligne
    # « enabled=0 » decale tous les indices enregistres pour les sections
    # SUIVANTES du meme fichier. En remontant, on ne touche jamais qu'a des
    # lignes situees apres celles qu'on a deja lues.
    for nom, s in sorted(sections.items(), key=lambda kv: kv[1]["debut"], reverse=True):
        # Sans ligne enabled=, dnf considere le depot ACTIF. On traite donc
        # l'absence comme un « 1 », sinon la moitie des cas passerait a travers.
        actif = s["enabled"] is None or s["enabled"][1] == "1"
        cle = s["gpgkey"] or ""
        fichiers_cle = [developper(k)[len("file://"):]
                        for k in cle.split() if k.startswith("file://")]
        if not fichiers_cle:
            sans_cle_locale += 1
            continue
        manquants = [k for k in fichiers_cle if not os.path.exists(k)]
        if not manquants:
            gardes.append(nom)
            continue
        if not actif:
            # Deja inactif : rien a corriger, mais on le dit.
            print(f"  inactif et sans cle : {nom} -> {', '.join(manquants)}")
            continue
        print(f"  DESACTIVE : {nom}")
        for k in manquants:
            print(f"              cle declaree et absente : {k}")
        if s["enabled"] is not None:
            lignes[s["enabled"][0]] = "enabled=0"
        else:
            lignes.insert(s["debut"] + 1, "enabled=0")
        desactives.append(nom)
        modifie = True

    if modifie:
        open(fichier, "w", encoding="utf-8").write("\n".join(lignes) + "\n")

print(f"  depots actifs a cle locale valide : {len(gardes)}")
print(f"  depots a cle distante (non concernes) : {sans_cle_locale}")
print(f"  desactives : {len(desactives)}" + (f" -> {', '.join(desactives)}" if desactives else ""))
PY

# L'assertion : plus AUCUN depot actif ne doit declarer une cle locale absente.
# Sans elle, une prochaine version de la base pourrait en reintroduire un et le
# defaut repartirait pour un tour, invisible jusqu'a la fabrication d'une ISO.
python3 - <<'PY'
import glob, os, platform, re, sys

releasever = ""
for ligne in open("/usr/lib/os-release", encoding="utf-8"):
    if ligne.startswith("VERSION_ID="):
        releasever = ligne.split("=", 1)[1].strip().strip('"')
basearch = platform.machine()

def developper(c):
    return c.replace("$releasever", releasever).replace("$basearch", basearch)

restants = []
for fichier in sorted(glob.glob("/etc/yum.repos.d/*.repo")):
    courante, actif, cle = None, True, ""
    def juger():
        if courante and actif:
            for k in cle.split():
                if k.startswith("file://") and not os.path.exists(developper(k)[7:]):
                    restants.append((courante, developper(k)[7:]))
    for l in open(fichier, encoding="utf-8"):
        m = re.match(r"^\[(.+)\]\s*$", l.strip())
        if m:
            juger()
            courante, actif, cle = m.group(1), True, ""
        elif l.startswith("enabled="):
            actif = l.split("=", 1)[1].strip() == "1"
        elif l.startswith("gpgkey="):
            cle = l.split("=", 1)[1].strip()
    juger()

if restants:
    for nom, k in restants:
        print(f"ECHEC : {nom} est actif et sa cle {k} n'existe pas.", file=sys.stderr)
    sys.exit(1)
print("  assertion : aucun depot actif ne pointe sur une cle absente")
PY

echo "=== 44-depots : fait ==="
