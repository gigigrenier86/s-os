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


# --------------------------------------------------------------------------
# 3. Les surfaces graphiques — la ou la marque se voyait encore
# --------------------------------------------------------------------------
# AJOUTE LE 2026-08-24, APRES UN RELEVE SUR LA MACHINE. L'utilisateur voyait
# encore des images de la base « au reveil ou au demarrage ». Les deux etaient
# vraies, et aucune des deux n'etait traitee :
#
#   - AU REVEIL : la base livre /etc/xdg/kscreenlockerrc, qui pointe l'ecran de
#     verrouillage sur /usr/share/wallpapers/convergence.jxl — son image
#     maison. Rien dans S ne le recouvrait. Chaque verrouillage la montrait.
#   - AU DEMARRAGE : l'ecran d'amorcage graphique, traite par 43-amorcage.sh,
#     desormais branche dans le Containerfile.
#
# Ce qui suit ne touche qu'a des IMAGES et a des noms. Aucune fonctionnalite
# n'est retiree — c'est la difference entre depouiller et amputer.

FOND_S=/usr/share/wallpapers/FoudreGelee/contents/images/3840x2160.png
test -s "$FOND_S" || { echo "ECHEC : $FOND_S absent — le COPY a-t-il change ?" >&2; exit 1; }

# --- 3a. L'ecran de verrouillage, c'est-a-dire le reveil -------------------
# On REECRIT le fichier de la base plutot que d'esperer qu'un fragment le
# recouvre : c'est le meme raisonnement que 42-greeter.sh pour plasmalogin, et
# pour la meme raison — la cascade de fragments de KDE n'est pas fiable d'une
# version a l'autre, le fichier du constructeur l'est.
cat > /etc/xdg/kscreenlockerrc <<'CONF'
# Pose par S. Sans ce fichier, celui de la base s'applique et l'ecran de
# verrouillage affiche le fond d'ecran de l'amont a chaque reveil.
[Greeter]
WallpaperPlugin=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=/usr/share/wallpapers/FoudreGelee/
PreviewImage=/usr/share/wallpapers/FoudreGelee/contents/images/3840x2160.png
CONF
grep -q 'FoudreGelee' /etc/xdg/kscreenlockerrc \
    || { echo "ECHEC : kscreenlockerrc ne porte pas le fond de S." >&2; exit 1; }
echo "  verrouillage  : le reveil affiche la Foudre gelee"

# --- 3b. Le fond « par defaut » du systeme ---------------------------------
# /usr/share/backgrounds/default.jxl est un lien vers convergence.jxl. Tout ce
# qui demande « le fond par defaut » sans plus de precision y aboutit.
for lien in /usr/share/backgrounds/default.jxl /usr/share/backgrounds/default-dark.jxl; do
    if [ -e "$lien" ] || [ -L "$lien" ]; then
        rm -f "$lien"
        ln -s "$FOND_S" "$lien"
        echo "    $(basename "$lien") -> Foudre gelee"
    fi
done

# --- 3c. Les fonds d'ecran qui portent le nom de l'amont -------------------
# Ce sont des IMAGES : les retirer ne retire aucune fonctionnalite, seulement
# des entrees du selecteur de fond d'ecran. C'est la seule chose de tout ce
# depot qu'on supprime vraiment plutot que de masquer, et c'est parce qu'il
# n'existe aucun « NoDisplay » pour un fond d'ecran.
retires=0
for f in /usr/share/wallpapers/bazzite /usr/share/wallpapers/bazzite-*.png \
         /usr/share/wallpapers/convergence.jxl /usr/share/wallpapers/convergence.png; do
    if [ -e "$f" ]; then
        rm -rf "$f"
        echo "    retire : $(basename "$f")"
        retires=$((retires + 1))
    fi
done
echo "  fonds retires : $retires"

# Le fond de S, lui, doit etre reste. Le controle vaut d'exister : la boucle
# ci-dessus efface des dossiers, et un motif trop large aurait emporte le notre.
test -s "$FOND_S" || { echo "ECHEC : le fond de S a ete emporte." >&2; exit 1; }

# --- 3d. Deux entrees de menu que le filtre par NOM ne pouvait pas voir ----
# LE FILTRE DE LA SECTION 2 LIT « Name= », ET C'EST VOULU : lire la commande
# supprimerait le monde Windows en entier. Mais deux entrees de la base portent
# un nom TRADUIT qui ne dit plus la marque, alors qu'elles ne menent nulle part
# ailleurs que chez l'amont :
#
#   bazzite-documentation.desktop  « Documentation »  -> la doc de la base
#   discourse.desktop              « Discourse »      -> le forum de la base
#
# On les nomme donc une par une plutot que d'elargir le filtre. Une liste
# explicite se relit ; un motif plus large finirait par mordre sur du vrai.
#
# CE QU'ON NE MASQUE PAS, ET POURQUOI : bazzite-steam-bpm.desktop porte la
# marque dans son NOM DE FICHIER mais s'appelle « Mode Big Picture » et lance
# une vraie fonction de Steam. Le nom de fichier n'est pas un critere.
for base in bazzite-documentation discourse; do
    f="/usr/share/applications/${base}.desktop"
    if [ ! -f "$f" ]; then
        echo "    ABSENT : ${base}.desktop — l'amont l'a renommee, verifier" >&2
        continue
    fi
    if grep -q '^NoDisplay=' "$f"; then
        sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$f"
    else
        sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$f"
    fi
    echo "    $(basename "$f")  masquee (renvoie chez l'amont)"
done

# --- 3e. Le controle d'ensemble -------------------------------------------
# Ce qui suit n'est pas decoratif : c'est ce qui empeche la marque de revenir
# en silence a la prochaine mise a jour de la base.
reste="$(ls /usr/share/wallpapers/ 2>/dev/null | grep -icE 'bazzite|convergence|vapor' || true)"
[ "$reste" -eq 0 ] || { echo "ECHEC : $reste fond(s) de l'amont subsistent." >&2; exit 1; }
grep -q 'convergence' /etc/xdg/kscreenlockerrc \
    && { echo "ECHEC : le verrouillage pointe encore chez l'amont." >&2; exit 1; }
echo "  controle      : plus un seul fond de l'amont, verrouillage aux couleurs de S"

echo "=== 37-effacer-bazzite : pose ==="
