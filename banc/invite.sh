#!/usr/bin/bash
# Execute une commande dans l'invite, en root, sans terminal.
# « sudo -S » lit le mot de passe sur l'entree standard : c'est le seul moyen
# quand SSH n'alloue pas de tty.
cd /c/Users/Ghis/Desktop/S-vm
ssh -p 2222 -i ./cle-banc -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR liveuser@127.0.0.1 \
    "echo '119711' | sudo -S -p '' bash -c $(printf '%q' "$*") 2>&1" | grep -v 'usual lecture\|Respect the privacy\|Think before you type\|great responsibility\|password you type will not\|^\s*#[123])\|^$'
