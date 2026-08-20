#!/usr/bin/bash
# Execute une commande dans l'invite, en root, sans terminal.
# « sudo -S » lit le mot de passe sur l'entree standard : c'est le seul moyen
# quand SSH n'alloue pas de tty.
#
# Le mot de passe ne vit PAS dans ce fichier : le depot est public. Il se passe
# par l'environnement, et le script refuse de partir sans lui plutot que de
# tenter une connexion muette qui echouerait sans dire pourquoi.
#   export MDP_BANC='...'   puis   ./invite.sh <commande>
MDP="${MDP_BANC:?exporter MDP_BANC avant d appeler invite.sh}"
cd /c/Users/Ghis/Desktop/S-vm
ssh -p 2222 -i ./cle-banc -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR liveuser@127.0.0.1 \
    "echo '${MDP}' | sudo -S -p '' bash -c $(printf '%q' "$*") 2>&1" | grep -v 'usual lecture\|Respect the privacy\|Think before you type\|great responsibility\|password you type will not\|^\s*#[123])\|^$'
