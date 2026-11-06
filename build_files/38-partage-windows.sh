#!/usr/bin/bash
# S — poser le service qui partage le disque Windows du double amorcage.
#
# CE QUE CETTE ETAPE FAIT, ET POURQUOI ELLE NE PEUT PAS FAIRE PLUS : la
# partition Windows n'existe pas au moment de la construction — c'est un
# disque d'une machine qui n'est pas celle-ci. Comme pour s-corriger-machine,
# cette etape ne fait que poser et activer le service qui la trouvera au
# demarrage (s-monter-windows), et preparer ce qui, lui, EST connu d'avance :
# le squelette de compte, et la syntaxe des gestes.
set -euo pipefail
echo "=== 38-partage-windows : le disque Windows depuis S ==="

chmod 0755 /usr/bin/s-monter-windows /usr/bin/s-fichiers-windows
bash -n /usr/bin/s-monter-windows
bash -n /usr/bin/s-fichiers-windows
echo "  syntaxe       : s-monter-windows et s-fichiers-windows analyses"

test -s /usr/lib/systemd/system/s-monter-windows.service \
    || { echo "ECHEC : s-monter-windows.service absent." >&2; exit 1; }
systemctl enable s-monter-windows.service
echo "  service       : s-monter-windows.service active"

test -s /usr/share/applications/s-fichiers-windows.desktop \
    || { echo "ECHEC : s-fichiers-windows.desktop absent." >&2; exit 1; }
echo "  etoile        : s-fichiers-windows.desktop present"

# Les comptes crees APRES ce deploiement heritent du lien tout seuls, par
# /etc/skel — les comptes DEJA crees, eux, ne le recevront que quand
# s-monter-windows tournera sur la machine reelle, au premier demarrage avec
# ce correctif. Meme limite que /etc/skel partout ailleurs dans ce depot.
ln -sfn /var/mnt/windows /etc/skel/Windows
echo "  /etc/skel     : le lien Windows sera pose pour chaque compte cree desormais"

# ---------------------------------------------------------------------------
# Le grand disque — meme principe, autre partition
# ---------------------------------------------------------------------------
# Decision de l'utilisateur du 2026-08-23 : la Seagate garde 500 Go pour la
# copie amorcable de Windows, et TOUT LE RESTE revient a S, en ext4.
#
# Windows ne sachant pas creer d'ext4, le partitionnement laisse cette
# partition VIERGE au bon type GPT. C'est S qui la formate — une seule fois,
# par « sudo s-grand-disque --preparer » — puis la monte a chaque demarrage.
# Encore une fois : ce qui n'existe qu'au moment du demarrage se decouvre au
# moment du demarrage, jamais a la construction.
chmod 0755 /usr/bin/s-grand-disque
bash -n /usr/bin/s-grand-disque
echo "  syntaxe       : s-grand-disque analyse"

test -s /usr/lib/systemd/system/s-grand-disque.service \
    || { echo "ECHEC : s-grand-disque.service absent." >&2; exit 1; }
systemctl enable s-grand-disque.service
echo "  service       : s-grand-disque.service active"

ln -sfn /var/mnt/disque /etc/skel/Disque
echo "  /etc/skel     : le lien Disque sera pose pour chaque compte cree desormais"

# --- Aucun dossier cache (demande du 2026-11-05) -----------------------------
# « S ne cache AUCUN dossier ». Un programme Windows envoie l'utilisateur dans
# C:/users/steamuser/AppData/..., qui vit sous ~/.local/share/ — cache par la
# convention Linux. Le lien « Disque C » (s-coquille) montre ce dossier-la ; ceci
# montre TOUT le reste : le gestionnaire de fichiers et les boites Ouvrir /
# Enregistrer de toutes les applications KDE affichent les dossiers caches.
#
# Trois endroits, parce qu'aucun ne couvre les deux autres :
#   - /etc/xdg/kdeglobals : boites Ouvrir/Enregistrer ; un compte qui a deja son
#     propre kdeglobals garde son choix (le fichier du compte l'emporte) ;
#   - /etc/xdg/dolphinrc : UNE vue commune a tous les dossiers — sans elle chaque
#     dossier garde son reglage a lui et « montrer les caches » ne tient nulle
#     part ;
#   - /etc/skel : le reglage de cette vue commune vit dans le dossier PERSONNEL
#     (~/.local/share/dolphin/...), donc seul un compte cree apres ceci le recoit.
kwriteconfig6 --file /etc/xdg/kdeglobals --group "KFileDialog Settings" --key "Show hidden files" true
kwriteconfig6 --file /etc/xdg/dolphinrc --group General --key GlobalViewProps true
install -d /etc/skel/.local/share/dolphin/view_properties/global
kwriteconfig6 --file /etc/skel/.local/share/dolphin/view_properties/global/.directory \
    --group Settings --key HiddenFilesShown true
grep -qx 'Show hidden files=true' /etc/xdg/kdeglobals \
    && grep -qx 'GlobalViewProps=true' /etc/xdg/dolphinrc \
    && grep -qx 'HiddenFilesShown=true' /etc/skel/.local/share/dolphin/view_properties/global/.directory \
    || { echo "ECHEC : les dossiers caches ne sont pas montres par defaut." >&2; exit 1; }
echo "  dossiers caches : montres par defaut (dialogues, Dolphin, nouveaux comptes)"

echo "=== 38-partage-windows : pose ==="
