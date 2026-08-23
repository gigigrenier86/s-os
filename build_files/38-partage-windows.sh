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

echo "=== 38-partage-windows : pose ==="
