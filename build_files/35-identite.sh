#!/usr/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------------
# La machine s'annonce S — jalon 6, premiere piece posee dans l'image
# --------------------------------------------------------------------------
# Tout ce qui affiche « Bazzite » le lit au meme endroit : /usr/lib/os-release,
# que /etc/os-release pointe. L'invite de console (agetty developpe \S en
# PRETTY_NAME), l'entree du chargeur d'amorcage (composee depuis PRETTY_NAME au
# deploiement — c'est elle qui dit « title Bazzite (ostree:0) » sur la Seagate),
# le centre d'information de KDE : une seule source, donc une seule retouche.
#
# ID reste « bazzite », a dessein : les recettes ujust et les scripts de
# l'amont testent l'identifiant, jamais le nom affiche. Changer ID casserait
# ce qu'on herite ; changer NAME ne casse rien.

echo "os-release avant :"
grep -E '^(NAME|PRETTY_NAME|ID|DEFAULT_HOSTNAME|HOME_URL)=' /usr/lib/os-release || true

sed -i \
  -e 's|^NAME=.*|NAME="S"|' \
  -e 's|^PRETTY_NAME=.*|PRETTY_NAME="S"|' \
  -e 's|^HOME_URL=.*|HOME_URL="https://github.com/gigigrenier86/s-os"|' \
  /usr/lib/os-release

# Le logo : l'icone s-logo entre par COPY dans hicolor, et LOGO= dit a KDE de
# l'afficher dans le centre d'information. La ligne peut exister ou non selon
# la base — on remplace si elle est la, on l'ajoute sinon.
if grep -q '^LOGO=' /usr/lib/os-release; then
  sed -i 's|^LOGO=.*|LOGO=s-logo|' /usr/lib/os-release
else
  echo 'LOGO=s-logo' >> /usr/lib/os-release
fi

# DEFAULT_HOSTNAME ne sert qu'aux machines dont personne ne choisit le nom ;
# celles deja baptisees — ThinkCentre720Q — ne sont pas touchees.
grep -q '^DEFAULT_HOSTNAME=' /usr/lib/os-release \
  && sed -i 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="s"|' /usr/lib/os-release \
  || true

# /etc/os-release doit rester un lien vers /usr/lib/os-release. S'il etait un
# vrai fichier, la retouche ci-dessus ne se verrait nulle part — le succes
# silencieux, exactement ce que ce depot s'interdit.
ls -l /etc/os-release
test -L /etc/os-release

echo "os-release apres :"
grep -E '^(NAME|PRETTY_NAME|ID|DEFAULT_HOSTNAME|HOME_URL|LOGO)=' /usr/lib/os-release

# Les assertions : une image qui ne s'annonce pas S ne sort pas d'ici,
# et ID n'a pas bouge — c'est la promesse faite aux scripts de l'amont.
grep -q '^NAME="S"$' /usr/lib/os-release
grep -q '^PRETTY_NAME="S"$' /usr/lib/os-release
grep -q '^ID=bazzite' /usr/lib/os-release
grep -q '^LOGO=s-logo$' /usr/lib/os-release

# --------------------------------------------------------------------------
# Foudre gelee devient le fond d'ecran par defaut
# --------------------------------------------------------------------------
# Plasma choisit le fond des NOUVELLES sessions dans le fichier « defaults »
# du paquet look-and-feel actif — bureau ET ecran de verrouillage y declarent
# chacun leur ligne Image=. On ne suppose pas quel paquet est actif : on
# retouche tous ceux que la base porte, et on ECRIT ce qu'on a trouve.
# Le PNG lui-meme entre plus tard par COPY ; ecrire son nom ici ne demande
# que le nom. Les comptes existants ne sont pas touches — un fond d'ecran
# deja choisi par l'utilisateur est un reglage, pas un defaut.
# LA BOUCLE D'AVANT NE TOUCHAIT QUE LES PAQUETS PORTANT DEJA « Image= », ET
# C'EST EXACTEMENT CELUI QUI COMPTE QU'ELLE SAUTAIT. Mesure du 2026-08-24 sur
# la machine : com.valve.vapor.desktop et com.valve.vgui.desktop n'ont AUCUNE
# ligne Image=, et /etc/xdg/kdeglobals de la base impose justement
# « LookAndFeelPackage=com.valve.vapor.desktop ». Le fond de S etait donc ecrit
# dans neuf paquets inertes et absent du seul qui sert — un succes silencieux
# parfait, invisible a la construction comme au controle de l'image.
#
# On POSE donc la section quand elle manque, au lieu de passer son chemin. La
# cle vit dans un groupe « [Wallpaper] » a elle : l'ajouter en fin de fichier
# la ferait tomber dans le dernier groupe rencontre, ou personne ne la lit.
trouve=0
pose=0
for d in /usr/share/plasma/look-and-feel/*/contents/defaults; do
  [ -f "$d" ] || continue
  paquet="$(basename "$(dirname "$(dirname "$d")")")"
  if grep -q '^Image=' "$d"; then
    sed -i 's|^Image=.*|Image=FoudreGelee|' "$d"
    echo "  $paquet : Image= remplacee"
    trouve=$((trouve + 1))
  else
    printf '\n[Wallpaper]\nImage=FoudreGelee\n' >> "$d"
    echo "  $paquet : section [Wallpaper] POSEE (elle manquait)"
    pose=$((pose + 1))
  fi
done

# L'ecran de demarrage de Plasma porte lui aussi un nom qui n'est pas le notre
# — « Theme=com.valve.vapor » chez la base. On le ramene sur Breeze, neutre :
# S n'a pas de paquet look-and-feel a lui, et inventer un nom de theme absent
# donnerait un ecran de demarrage casse au lieu d'un ecran sans marque.
sed -i 's|^Theme=com\.valve\..*|Theme=org.kde.breeze.desktop|' \
  /usr/share/plasma/look-and-feel/*/contents/defaults

echo "look-and-feel : $trouve remplacees, $pose posees"
# Aucun paquet touche = la structure de KDE a change sous nos pieds.
[ $((trouve + pose)) -gt 0 ] || { echo "ECHEC : aucun defaults de look-and-feel." >&2; exit 1; }

# L'ASSERTION QUI MANQUAIT : ce n'est pas « au moins un paquet » qui compte,
# c'est que TOUS portent le fond de S. Sans elle, la panne ci-dessus serait
# repassee inapercue une seconde fois.
for d in /usr/share/plasma/look-and-feel/*/contents/defaults; do
  [ -f "$d" ] || continue
  grep -q '^Image=FoudreGelee$' "$d" \
    || { echo "ECHEC : $d ne porte pas le fond de S." >&2; exit 1; }
done
echo "look-and-feel : tous les paquets portent Image=FoudreGelee"

# Et le paquet que la base impose par defaut ne doit plus s'appeler Valve.
# On ne supprime pas ses fichiers — un bureau arrache ne se remet pas d'un
# clic —, on cesse de le designer.
if [ -f /etc/xdg/kdeglobals ] && grep -q '^LookAndFeelPackage=com\.valve\.' /etc/xdg/kdeglobals; then
  sed -i 's|^LookAndFeelPackage=com\.valve\..*|LookAndFeelPackage=org.kde.breezedark.desktop|' \
    /etc/xdg/kdeglobals
  echo "kdeglobals   : LookAndFeelPackage ne designe plus Valve"
fi
