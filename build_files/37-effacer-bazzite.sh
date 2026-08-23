#!/usr/bin/bash
# S — effacer les traces de Bazzite et Fedora, sans retirer une seule
# fonctionnalite.
#
# DEUX GESTES DISTINCTS, POUR DEUX RAISONS DIFFERENTES :
#
#   1. « sudo ne fonctionne plus » et « choisir S a chaque connexion » sont
#      deux pannes qui ne peuvent PAS se corriger ici : le compte n'existe pas
#      encore au moment de la construction. Cette etape ne fait que poser et
#      activer le service qui les corrigera au demarrage — s-corriger-machine.
#
#   2. Le menu d'applications, lui, EST connu au moment de la construction :
#      c'est celui de l'image de base. On y masque toute entree dont le nom
#      porte la marque de l'amont — meme regle, memes mots-cles que le
#      filtrage deja fait pour le ciel de Constellation (s-etoiles, TAIRE).
#      MASQUER N'EST PAS DESINSTALLER : NoDisplay=true retire l'icone du
#      menu, jamais le paquet, jamais la fonctionnalite. C'est la regle 9 du
#      carnet — une couture ne montre jamais son moteur — appliquee au menu
#      entier, pas seulement au ciel de Constellation.
#
# CE QUI N'EST PAS FAIT ICI, ET POURQUOI : les applications posees APRES
# l'installation par le portail de la base (ujust, Homebrew, rpm-ostree
# layering — asusctl, CoolerControl, Boxtron, DaVinci Resolve, Bazaar dans les
# observations du 2026-08-22) n'existent pas dans cette image : les deviner
# ici serait masquer a l'aveugle, et plusieurs d'entre elles sont de vraies
# fonctionnalites dont la panne vient du portail, pas du logiciel lui-meme.
# Le carnet est clair sur ce point : c'est `rpm-ostree reset`, sur la machine,
# qui les retire toutes d'un coup — pas une regle devinee dans ce script.
set -euo pipefail
echo "=== 37-effacer-bazzite : sudo, session par defaut, menu ==="

# --------------------------------------------------------------------------
# 1. Le service qui corrige le compte au demarrage
# --------------------------------------------------------------------------
chmod 0755 /usr/bin/s-corriger-machine
bash -n /usr/bin/s-corriger-machine
echo "  syntaxe       : s-corriger-machine analyse"

test -s /usr/lib/systemd/system/s-corriger-machine.service \
    || { echo "ECHEC : s-corriger-machine.service absent." >&2; exit 1; }
systemctl enable s-corriger-machine.service
echo "  service       : s-corriger-machine.service active"

# --------------------------------------------------------------------------
# 2. Le menu : masquer les entrees de marque, jamais les desinstaller
# --------------------------------------------------------------------------
# Les memes mots-cles que TAIRE dans files/usr/bin/s-etoiles — si l'un des
# deux change, verifier l'autre. Correspondance sur le NOM affiche
# uniquement, jamais sur la commande : c'est ce qui evite de masquer Steam ou
# un jeu dont l'executable, lui, passe par Proton.
MOTS=(bazzite fedora ublue plasma "kde " waydroid distrobox "steam linux runtime" proton wine)

echo "  menu trouve   : $(ls /usr/share/applications/*.desktop 2>/dev/null | wc -l) entrees"
masquees=0
FICHIERS_MASQUES=()
for f in /usr/share/applications/*.desktop; do
    [[ -f "$f" ]] || continue
    grep -q '^NoDisplay=true' "$f" && continue

    nom="$(grep -m1 '^Name=' "$f" | cut -d= -f2- | tr '[:upper:]' '[:lower:]')"
    [[ -n "$nom" ]] || continue

    for mot in "${MOTS[@]}"; do
        if [[ "$nom" == *"$mot"* ]]; then
            if grep -q '^NoDisplay=' "$f"; then
                sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f"
            else
                sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$f"
            fi
            echo "    $(basename "$f")  masquee (mot-cle : $mot)"
            FICHIERS_MASQUES+=("$f")
            masquees=$((masquees + 1))
            break
        fi
    done
done
echo "  entrees masquees : $masquees"

# Garde-fou : si le filet a mordu sur quelque chose qui n'a rien a voir avec
# la marque de l'amont, mieux vaut faire echouer la construction que livrer
# un menu ampute d'une vraie fonctionnalite en silence.
#
# Ne rescanne QUE les fichiers que la boucle ci-dessus vient de masquer, pas
# tout /usr/share/applications : un editeur peut deja livrer un .desktop
# NoDisplay=true par conception (ex. un gestionnaire d'URL cache), et ce
# script n'y est pour rien. Rescanner tout le systeme fait accuser ce script
# d'un choix qui n'est pas le sien — c'est exactement ce qui a casse la
# premiere construction : « Antigravity - URL Handler », deja cache par
# Antigravity lui-meme, jamais touche par la boucle ci-dessus.
for f in "${FICHIERS_MASQUES[@]}"; do
    nom="$(grep -m1 '^Name=' "$f" | cut -d= -f2-)"
    bas="$(echo "$nom" | tr '[:upper:]' '[:lower:]')"
    # « steam » seul, jamais en sous-chaine : « Steam Linux Runtime » DOIT
    # rester masque, c'est le but du mot-cle « steam linux runtime » plus haut.
    case "$bas" in
        steam|*retroarch*|*vivaldi*|*zoom*|*"code"*|*claude*|*gemini*|*antigravity*)
            echo "ECHEC : « $nom » a ete masque par erreur — le filtre est trop large." >&2
            exit 1
            ;;
    esac
done
echo "  garde-fou     : aucune fonctionnalite connue n'a ete masquee"

echo "=== 37-effacer-bazzite : pose ==="
