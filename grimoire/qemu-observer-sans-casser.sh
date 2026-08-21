#!/usr/bin/bash
# GRIMOIRE — regarder un QEMU bloqué sans aggraver son cas
# PREUVE : 2026-08-21. Les deux pièges ci-dessous ont été commis dans l'ordre,
#          par moi, pendant le diagnostic d'un halt réel. Le troisième point
#          est celui qui a donné la réponse.
# POUR   : tout diagnostic de machine virtuelle QEMU qui « fige ».
#
# ============================================================================
# PIÈGE 1 — NE JAMAIS SONDER UN PORT « server,nowait » POUR VOIR S'IL RÉPOND
# ============================================================================
# « -monitor tcp:...,server,nowait » et « -serial tcp:...,server,nowait »
# n'acceptent QU'UNE connexion à la fois. Un simple test de port — le
# Test-NetConnection de PowerShell, un telnet, un nc -z — consomme cette
# unique place et laisse la socket en CLOSE_WAIT côté QEMU.
#
# Le port continue d'apparaître LISTENING dans netstat, et toute connexion
# ultérieure est refusée. On croit avoir constaté une panne alors qu'on vient
# de la créer.
#
# Mesuré : après trois Test-NetConnection sur 2222/4445/4446, netstat montrait
# les trois en LISTENING avec chacun un CLOSE_WAIT pendant, et le moniteur
# était devenu inaccessible pour le reste de la session.
#
# LA RÈGLE : on ne teste pas un port de contrôle, ON S'EN SERT. La connexion
# utile est elle-même le test.
#
# ============================================================================
# PIÈGE 2 — CAPTURER PAR COORDONNÉES D'ÉCRAN MENT
# ============================================================================
# SetForegroundWindow échoue SILENCIEUSEMENT quand l'appelant n'est pas au
# premier plan : Windows refuse le vol de focus et rend simplement $false.
# Une capture par CopyFromScreen photographie alors la fenêtre qui se trouvait
# là — dans mon cas l'éditeur de code.
#
# Le pire : deux captures ainsi prises ont des empreintes DIFFÉRENTES, ce qui
# se lit « l'écran a changé, donc ça progresse ». Conclusion inverse de la
# vérité. Une capture par coordonnées ne prouve rien sans vérifier QUI est
# devant.
#
# Si capture il faut : passer par le moniteur QEMU (« screendump fichier.ppm »),
# qui photographie le framebuffer de l'invité et ignore complètement le
# bureau — d'où le piège 1, qui interdit de gâcher ce port.
#
# ============================================================================
# CE QUI A DONNÉ LA RÉPONSE : LA PENTE DU COMPTEUR CPU
# ============================================================================
# Aucune image n'était nécessaire. Deux lectures du CPU cumulé du processus,
# espacées, tranchent sans ambiguïté :
#
#   0 s consommée sur 75 s   -> l'invité n'exécute RIEN. Arrêt franc.
#   ~100 % d'un cœur, 0 E/S  -> la spirale zram (voir linux-couper-zram.sh).
#   CPU qui monte + E/S      -> ça travaille, c'est seulement lent.
#
# Trois signatures, trois causes distinctes, et « figé » les confond toutes.
#
# LE TABLEAU À AVOIR EN TÊTE
#   | CPU      | E/S disque | Verdict                                   |
#   |----------|------------|-------------------------------------------|
#   | 0 %      | 0          | invité halté : interruption, firmware, bloc |
#   | ~100 %   | 0          | spirale zram, ou boucle en espace noyau   |
#   | variable | > 0        | travail réel, mesurer le débit             |
#   | 0 %      | > 0        | E/S bloquante côté hôte, regarder le disque|

qemu_pente_cpu() {
    # Usage : qemu_pente_cpu <pid> [secondes]
    # Sous Linux. L'équivalent Windows est plus bas.
    local pid="$1" duree="${2:-30}" t1 t2
    t1=$(awk '{print $14+$15}' "/proc/$pid/stat") || return 1
    sleep "$duree"
    t2=$(awk '{print $14+$15}' "/proc/$pid/stat") || return 1
    local hz; hz=$(getconf CLK_TCK)
    awk -v a="$t1" -v b="$t2" -v d="$duree" -v hz="$hz" \
        'BEGIN { printf "  CPU sur %d s : %.2f s  soit %.1f %% d un coeur\n",
                 d, (b-a)/hz, ((b-a)/hz/d)*100 }'
}

# --- L'équivalent Windows, éprouvé le 2026-08-21 ---------------------------
#
#   $p = Get-Process -Id <pid>
#   $c1 = $p.CPU
#   Start-Sleep -Seconds 75
#   $p.Refresh()                      # SANS Refresh, .CPU reste figé : le
#   $c2 = $p.CPU                      # cache de l objet ment, pas le processus
#   "CPU consomme : $([math]::Round($c2-$c1,2)) s"
#
# Et l'état des threads, qui confirme :
#   $p.Threads | Group-Object ThreadState,WaitReason
#   -> tous en « Wait » = rien ne tourne, ce n'est pas une E/S en cours.
#
# Et les compteurs d'E/S du PROCESSUS, plus fiables que ceux du disque
# physique quand on cherche à savoir si QEMU fait quelque chose :
#   Get-CimInstance Win32_Process -Filter "ProcessId=<pid>" |
#     Select-Object ReadTransferCount,WriteTransferCount,OtherOperationCount
