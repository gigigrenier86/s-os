#!/usr/bin/bash
# S-Constellation : S cesse d'etre une base habillee et devient une session.
#
# CE QUE CETTE ETAPE CHANGE, ET IL FAUT LE DIRE NETTEMENT :
# jusqu'ici Constellation etait une page ouverte dans une fenetre, par-dessus
# le bureau de la base. Elle devient LA session — le greeter propose « S », et
# ce que S lance n'est plus la coquille de l'amont mais la sienne.
#
# CE QUE CETTE ETAPE NE CHANGE PAS : le compositeur. Voir s-session pour le
# raisonnement — c'est la seule piece d'un bureau que personne ne voit jamais.
#
# Rien ici ne desinstalle quoi que ce soit. Une image atomique se repare par
# « bootc rollback », mais un bureau arrache ne se remet pas d'un clic : on
# MASQUE la session d'origine, on ne la supprime pas, et on en garde une entree
# de secours explicitement nommee.
set -euo pipefail
echo "=== 36-constellation : la session S ==="

# --- Ce dont la coquille depend, verifie plutot que suppose ----------------
# Chacune de ces trois lignes a deja ete une panne ailleurs dans ce projet :
# un chemin absent (vivaldi-stable), un binaire renomme, un interprete manquant.
# Une construction qui echoue ici coute neuf minutes ; une image qui sort sans
# eux coute une machine sans bureau.
COMPOSITEUR=""
for essai in kwin_wayland labwc; do
    if command -v "$essai" >/dev/null 2>&1; then COMPOSITEUR="$essai"; break; fi
done
[[ -n "$COMPOSITEUR" ]] || { echo "ECHEC : aucun compositeur Wayland dans la base." >&2; exit 1; }
echo "  compositeur   : $(command -v "$COMPOSITEUR")"

command -v python3 >/dev/null 2>&1 \
    || { echo "ECHEC : python3 absent — le pont ne peut pas tourner." >&2; exit 1; }
echo "  interprete    : $(python3 --version)"

# Le moteur de rendu de la coquille. On vise le chemin de l'IMAGE : c'est
# precisement /usr/bin/vivaldi-stable qui a manque sur la machine reelle le
# 2026-08-21, ce lien dependant d'un pont /var refait a chaque demarrage.
[[ -x /usr/lib/opt/vivaldi/vivaldi ]] \
    || { echo "ECHEC : /usr/lib/opt/vivaldi/vivaldi absent — la coquille n'a pas de moteur." >&2; exit 1; }
echo "  moteur        : /usr/lib/opt/vivaldi/vivaldi"

# --- Les polices de la coquille, posees plutot que telechargees -----------
# La page tire « IBM Plex » de fonts.googleapis.com. Pour une maquette c'est
# sans consequence ; pour un bureau, cela ferait une requete vers Google a
# chaque ouverture de session et un ecran sans polices hors ligne. On pose les
# memes familles dans l'image, et s-etoiles retire les liens distants en
# servant la page.
dnf5 install -y ibm-plex-sans-fonts ibm-plex-mono-fonts
# Regle 2 du carnet : une installation qui atterrit hors de /usr livrerait une
# image creuse sans que rien ne le dise.
if rpm -ql ibm-plex-sans-fonts ibm-plex-mono-fonts | grep -qE '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : une police est posee hors de /usr." >&2
    exit 1
fi
# Regle 5 : une ligne de rapport ne fait jamais tomber une image saine.
# « grep -c » sort en 1 quand il ne compte rien, et pipefail en ferait un
# echec de construction pour une simple ligne d'information.
echo "  polices       : $(fc-list 2>/dev/null | grep -ci 'IBM Plex' || true) fichiers IBM Plex" || true

# --- Les gestes de la session ---------------------------------------------
# Le bit d'execution ne survit pas a un depot edite sous Windows ; on le repose
# plutot que de dependre de ce que git a bien voulu enregistrer.
chmod 0755 /usr/bin/s-session /usr/bin/s-coquille /usr/bin/s-etoiles

# Une faute de syntaxe dans le pont ne se verrait qu'au premier ouverture de
# session, c'est-a-dire sur un ecran noir. Elle se voit ici en une seconde.
bash -n /usr/bin/s-session
bash -n /usr/bin/s-coquille
python3 -m py_compile /usr/bin/s-etoiles
rm -rf /usr/bin/__pycache__ /root/.cache 2>/dev/null || true
echo "  syntaxe       : session, coquille et pont analyses"

# La page que le pont sert entre par COPY, plus haut dans le Containerfile.
# Sans elle, la session demarrerait sur du vide.
PAGE=/usr/share/s/constellation/constellation.html
[[ -s "$PAGE" ]] || { echo "ECHEC : $PAGE absente." >&2; exit 1; }
grep -q '__S_ETOILES__' "$PAGE" \
    || { echo "ECHEC : le repere d'injection a disparu de la page — le pont servirait la vitrine." >&2; exit 1; }
echo "  page          : $(stat -c%s "$PAGE") octets, repere d'injection present"

# --- Le greeter ne propose plus que S -------------------------------------
# On ne montre plus les sessions de l'amont. NoDisplay les retire de la liste
# sans les effacer du disque : « S — bureau de secours » les rejoue si besoin.
echo "  sessions trouvees :"
masquees=0
for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    case "$base" in
        s.desktop|s-secours.desktop) echo "    $base  (gardee)"; continue ;;
    esac
    grep -q '^NoDisplay=true' "$f" || printf 'NoDisplay=true\n' >> "$f"
    echo "    $base  masquee"
    masquees=$((masquees + 1))
done
echo "  sessions masquees : $masquees"

# Nos deux entrees doivent exister, et la principale doit pointer sur un
# fichier reellement executable — un TryExec qui ne resout pas ferait
# disparaitre « S » de la liste sans un mot.
for s in /usr/share/wayland-sessions/s.desktop /usr/share/wayland-sessions/s-secours.desktop; do
    [[ -s "$s" ]] || { echo "ECHEC : $s absente." >&2; exit 1; }
done
test -x /usr/bin/s-session
grep -q '^Name=S$' /usr/share/wayland-sessions/s.desktop

# Le bureau de secours n'a de sens que si son binaire existe. S'il a change de
# nom dans l'amont, mieux vaut le savoir maintenant que le jour ou on en a besoin.
if [[ ! -x /usr/bin/startplasma-wayland ]]; then
    echo "  ATTENTION : /usr/bin/startplasma-wayland absent — le bureau de secours ne demarrera pas." >&2
fi

# --- Ce qui porte encore un nom qui n'est pas le notre ---------------------
# On l'ECRIT dans le journal plutot que de laisser croire que tout est fait.
# Le fond d'ecran du greeter et l'ecran d'amorcage graphique restent a peindre :
# le premier est un theme, le second exige de refaire l'initramfs.
echo "  reste a peindre :"
echo "    greeter  : $(ls /usr/share/sddm/themes 2>/dev/null | tr '\n' ' ' || echo 'aucun theme sddm')"
echo "    amorcage : $(plymouth-set-default-theme 2>/dev/null || echo 'plymouth non interrogeable')"

echo "=== 36-constellation : la session S est posee ==="
