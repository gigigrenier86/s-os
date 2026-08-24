#!/usr/bin/bash
# S — un depot active dont la cle n'existe pas est une bombe a retardement.
#
# CE QUI A REVELE CE DEFAUT, ET IL VENAIT DE LOIN. La fabrication de l'ISO
# echouait ainsi :
#
#   Failed to retrieve GPG key for repo 'terra-mesa': Could not read a file://
#   file for file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra44-mesa
#
# En regardant l'image plutot qu'en supposant : le depot « terra-mesa » est le
# SEUL depot terra active (enabled=1), sa cle est declaree
# « RPM-GPG-KEY-terra$releasever-mesa » — donc terra44 sur une Fedora 44 — et
# /etc/pki/rpm-gpg ne contient que « RPM-GPG-KEY-terra42-mesa ». Un decalage de
# version chez l'amont : les cles livrees portent le numero d'une Fedora
# anterieure a celle du systeme.
#
# POURQUOI NOS PROPRES « dnf5 install » N'AVAIENT JAMAIS BRONCHE. dnf ne lit la
# cle d'un depot qu'au moment ou il doit verifier un paquet VENANT de ce depot.
# Aucun de nos huit logiciels n'en vient : la cle manquante n'a donc jamais ete
# demandee. bootc-image-builder, lui, resout ses dependances en validant TOUS
# les depots actifs d'un coup — et tombe dessus immediatement.
#
# C'est exactement la regle 2 du carnet, vue de l'autre bout : le defaut etait
# la depuis le premier jour, il ne cassait rien de visible, et il aurait casse
# le premier « rpm-ostree install » d'un paquet mesa sur la machine reelle.
#
# CE QU'ON FAIT, ET CE QU'ON NE FAIT PAS. On DESACTIVE le depot. On ne fabrique
# PAS la cle manquante en recopiant celle de terra42 sous le nom terra44 :
# ce serait affirmer qu'une cle de signature vaut pour une autre version, sans
# le savoir. Une signature qu'on renomme n'est plus une verification.
#
# Le traitement est GENERIQUE — tout depot actif dont la cle « file:// » est
# absente est desactive — parce que le meme decalage se reproduira a la
# prochaine Fedora, et qu'un correctif qui nomme « terra-mesa » en dur ne
# l'attraperait pas.
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
