#!/usr/bin/bash
# LE WINDOWS DE S EST UNE SESSION, PAS UN LANCEUR.
#
# CE QUI ETAIT FAUX, ET LA MESURE QUI L'A DIT (2026-08-26, sur cette machine) :
#
#   umu-run cmd /c exit   1er : 6,65 s   2e : 5,06 s   3e : 5,13 s
#
# Un programme qui ne fait RIEN coutait cinq secondes, et le deuxieme lancement
# coutait autant que le premier. Il n'y avait aucun chemin chaud : chaque
# double-clic faisait renaitre un Windows entier — conteneur pressure-vessel,
# runtime sniper de 797 Mo, wineserver, session Windows — puis le detruisait.
# s-ouvrir-exe appelait meme « umu-run wineserver -w » ensuite, ce qui montait
# un SECOND conteneur complet pour attendre quelque chose qui n'existait plus :
# 3,97 s de plus, et il sortait en code 1.
#
# Windows ne fait pas ca. Windows demarre UNE fois, et les programmes entrent
# dans un systeme deja vivant.
#
#   wine direct sur l'hote, serveur froid     1,66 s
#   wine direct + wineserver resident         0,24 s
#
# Vingt fois plus rapide que le chemin actuel, et c'est la meme machine, le
# meme Proton, le meme prefixe.
#
# CE QUE LE CONTENEUR SERT VRAIMENT A FAIRE, ET C'EST LA CLE DE VOUTE :
# pressure-vessel existe pour donner a un jeu Steam un environnement de
# bibliotheques stable. Il ne sert PAS a executer le programme — il sert a
# CONSTRUIRE le prefixe. C'est le script « proton » qui, a la creation, copie
# DXVK et VKD3D-Proton dans system32 et compose les surcharges de DLL.
#
#   proton CONSTRUIT le Windows.  wine le FAIT TOURNER.
#
# Verifie sur cette machine : drive_c/windows/system32/d3d11.dll fait 3,9 Mo et
# porte la signature DXVK ; ce n'est pas un lien vers Proton, c'est un vrai
# fichier depose dans le prefixe. Le prefixe est donc autonome.
#
# LE PIEGE QUI RESTAIT, ET IL EST SERIEUX : les surcharges qui font PREFERER ce
# DXVK au d3d11 interne de Wine ne sont PAS dans le registre. Elles vivent dans
# WINEDLLOVERRIDES, une variable d'environnement que « proton » compose a
# chaque lancement. Sans elle, Wine ignore le DXVK pose a cote et retombe sur
# son propre rendu OpenGL. Le chemin rapide serait alors rapide et laid.
#
# ON NE RECOPIE PAS CETTE LISTE. C'est exactement la faute que ce projet a
# payee cinq jours sur s-android — reecrire une ligne de l'amont en laissant
# tomber des arguments. On la LUI DEMANDE :
#
#   umu-run cmd /c 'set > C:\capture-env.txt'
#
# Proton compose son environnement, le passe a Wine, Wine le passe au processus
# Windows, et cmd l'ecrit dans un fichier DEPUIS L'INTERIEUR. Aucun correctif
# applique a Proton, aucune liste devinee : sa propre decision, relue sur le
# disque. Une capture par version de Proton, et elle se refait toute seule
# quand la version change.

# ---------------------------------------------------------------------------
# Chemins
# ---------------------------------------------------------------------------
# Proton fabrique le VRAI prefixe dans « pfx/ » a l'interieur de ce qu'on lui
# donne — meme correction que dans s-partage et s-lien-windows, meme raison.
# ATTENTION : « pfx » est un LIEN VERS LE DOSSIER LUI-MEME (pfx -> .), pose par
# umu. Les deux chemins designent donc le meme prefixe, et un processus peut
# porter l'un ou l'autre dans son environnement selon qui l'a lance. Tout ce qui
# COMPARE des chemins ici doit accepter les deux, sinon la comparaison echoue
# sans bruit — et une comparaison qui echoue sans bruit est exactement ce que ce
# projet appelle un succes silencieux.
S_WIN_PFX="$S_PREFIXE/pfx"
S_WIN_ENV="$S_ETAT/windows-env"           # la capture, une par version
S_WIN_VERSION="$S_ETAT/windows-proton"    # la version qui l'a produite
S_WIN_CACHE="$S_DATA/windows-cache"       # caches de shaders, hors du prefixe

# Les processus que Windows tient EN PERMANENCE. Ils ne comptent pas quand on
# demande « est-ce que le programme a fini ». Sous Windows ce sont des
# services ; ici ce sont des processus Linux ordinaires, et c'est ce qui rend
# la question repondable du dehors.
S_WIN_SERVICES="services.exe explorer.exe rpcss.exe winedevice.exe plugplay.exe svchost.exe wineserver tabtip.exe conhost.exe start.exe winemenubuilder.exe"

# ---------------------------------------------------------------------------
# Quelle version de Proton, et ou est-elle depliee
# ---------------------------------------------------------------------------
s_windows_version() {
    cat /usr/lib/s/windows/proton.version 2>/dev/null || echo inconnue
}

s_windows_proton() {
    printf '%s/%s' "$S_PROTON_RACINE" "$(s_windows_version)"
}

# ---------------------------------------------------------------------------
# Le Windows de S est-il construit, et a jour ?
# ---------------------------------------------------------------------------
# Trois conditions, et il faut les trois. Une capture qui a survecu a une mise
# a jour de Proton est pire qu'une capture absente : elle pointerait vers un
# dossier qui n'existe plus, et wine echouerait sans dire pourquoi.
s_windows_pret() {
    [ -d "$S_WIN_PFX/drive_c" ]                      || return 1
    [ -s "$S_WIN_ENV" ]                              || return 1
    [ -x "$(s_windows_proton)/files/bin/wine64" ]    || return 1
    [ "$(cat "$S_WIN_VERSION" 2>/dev/null)" = "$(s_windows_version)" ] || return 1
    return 0
}

# ---------------------------------------------------------------------------
# Deplier Proton depuis l'image
# ---------------------------------------------------------------------------
s_windows_deplier() {
    local version dest
    version="$(s_windows_version)"
    dest="$S_PROTON_RACINE/$version"
    [ -d "$dest" ] && return 0
    [ -f "$S_PROTON_ARCHIVE" ] || return 1
    mkdir -p "$S_PROTON_RACINE"
    tar xzf "$S_PROTON_ARCHIVE" -C "$S_PROTON_RACINE"
}

# ---------------------------------------------------------------------------
# LA CAPTURE — demander a Proton ce qu'il a decide
# ---------------------------------------------------------------------------
# On ne lit pas la sortie standard : pressure-vessel ne la fait pas remonter de
# facon fiable (mesure du 2026-08-26 : « umu-run /usr/bin/env » rend zero ligne
# avec un code 0, ce qui est le succes silencieux dans sa forme pure). On passe
# donc par un FICHIER, ecrit depuis l'interieur de Windows, dans le prefixe.
s_windows_capturer() {
    local brut="$S_WIN_PFX/drive_c/capture-env.txt" reprise
    rm -f "$brut"
    reprise="$(s_windows_pause)"

    WINEPREFIX="$S_PREFIXE" \
    GAMEID="${GAMEID:-umu-0}" \
    UMU_LOG="${UMU_LOG:-warn}" \
    PROTONPATH="$(s_windows_proton)" \
        umu-run "$S_WIN_PFX/drive_c/windows/system32/cmd.exe" \
                /c 'set > C:\capture-env.txt' >/dev/null 2>&1

    s_windows_reprendre "$reprise"
    [ -s "$brut" ] || return 1

    # LE FILTRAGE N'EST PAS UNE PRECAUTION, C'EST UNE NECESSITE, et deux pieges
    # l'imposent — tous deux mesures sur la capture reelle du 2026-08-26 :
    #
    #   1. « set » vide l'environnement de WINDOWS, pas celui d'Unix. Le PATH
    #      qu'on y lit vaut « C:\windows\system32;C:\windows;... ». Le rejouer
    #      cote Linux remplacerait le PATH du systeme par un chemin Windows :
    #      plus aucune commande ne repondrait.
    #
    #   2. LD_LIBRARY_PATH contient des chemins qui N'EXISTENT QUE DANS LE
    #      CONTENEUR — /usr/lib/pressure-vessel/overrides/..., /ubuntu12_64/.
    #      Hors du conteneur ils ne designent rien.
    #
    # D'ou une liste blanche par prefixe de nom, et un nettoyage de
    # LD_LIBRARY_PATH qui ne garde que les dossiers qui existent vraiment.
    tr -d '\r' < "$brut" | awk -F= '
        /^(WINE|PROTON|DXVK_|VKD3D|MEDIACONV_|GST_)/ && $1 != "PATH" {
            nom = $1
            sub(/^[^=]*=/, "")
            if (nom == "LD_LIBRARY_PATH") next
            print nom "=" $0
        }
        /^LD_LIBRARY_PATH=/ {
            sub(/^LD_LIBRARY_PATH=/, "")
            n = split($0, morceaux, ":")
            garde = ""
            for (i = 1; i <= n; i++) {
                cmd = "test -d \"" morceaux[i] "\""
                if (system(cmd) == 0) garde = garde (garde == "" ? "" : ":") morceaux[i]
            }
            if (garde != "") print "LD_LIBRARY_PATH=" garde
        }
    ' > "$S_WIN_ENV"

    rm -f "$brut"
    # Sans la surcharge des DLL, la capture ne vaut rien : c'est ELLE qui fait
    # preferer DXVK au rendu interne de Wine. Une capture sans elle est une
    # capture ratee, et il vaut mieux le dire que la garder.
    grep -q '^WINEDLLOVERRIDES=' "$S_WIN_ENV" || { rm -f "$S_WIN_ENV"; return 1; }
    s_windows_version > "$S_WIN_VERSION"
    return 0
}

# ---------------------------------------------------------------------------
# Charger l'environnement capture
# ---------------------------------------------------------------------------
s_windows_charger() {
    local ligne nom
    [ -s "$S_WIN_ENV" ] || return 1
    while IFS= read -r ligne; do
        nom="${ligne%%=*}"
        [ -n "$nom" ] || continue
        export "$nom=${ligne#*=}"
    done < "$S_WIN_ENV"

    # Ce que la capture ne peut pas donner, parce que ca ne depend pas de
    # Proton mais de la facon dont on l'appelle.
    export WINEPREFIX="$S_WIN_PFX"
    export WINELOADER="$(s_windows_proton)/files/bin/wine64"
    export WINESERVER="$(s_windows_proton)/files/bin/wineserver"
    export WINEDEBUG="${WINEDEBUG:--all}"

    # LE CACHE DE SHADERS, ET C'EST LA MOITIE DU MOT « BROUILLON ».
    # Sans cache persistant, DXVK recompile ses pipelines a chaque lancement :
    # l'image saccade les premieres secondes, a CHAQUE fois, et l'utilisateur
    # appelle ca « ca marche a moitie ». Le cache le paie une fois.
    mkdir -p "$S_WIN_CACHE/dxvk" "$S_WIN_CACHE/mesa"
    export DXVK_STATE_CACHE_PATH="$S_WIN_CACHE/dxvk"
    export MESA_SHADER_CACHE_DIR="$S_WIN_CACHE/mesa"
    export MESA_SHADER_CACHE_MAX_SIZE="${MESA_SHADER_CACHE_MAX_SIZE:-2G}"
    return 0
}

# ---------------------------------------------------------------------------
# Le serveur resident
# ---------------------------------------------------------------------------
# On demande a systemd plutot que de lancer le serveur nous-memes, et ce n'est
# pas de la ceremonie : un wineserver demarre depuis un script meurt avec le
# groupe de processus de ce script. Mesure du 2026-08-26 : lance a la main avec
# « -p », il servait trois lancements a 0,24 s puis disparaissait entre deux
# commandes. Une unite utilisateur, elle, survit a son lanceur — c'est la seule
# facon d'obtenir un serveur qui tient toute la session.
s_windows_serveur_vivant() {
    pgrep -u "$(id -u)" -x wineserver >/dev/null 2>&1
}

# LE CONTENEUR ET LE SERVEUR RESIDENT NE PEUVENT PAS COHABITER.
#
# MESURE DU 2026-08-26, ET ELLE A FAILLI PASSER INAPERCUE. PcBoostApp lance par
# umu-run pendant que le serveur resident tournait : AUCUNE FENETRE apres
# soixante secondes, aucun message d'erreur, et un code de sortie qui ne dit
# rien. Le meme lancement, serveur arrete, ouvre sa fenetre en cinq secondes.
#
# La cause est le verrou : Proton prend « pfx.lock » et suppose qu'il possede
# le prefixe. Un wineserver deja en place le lui refuse, et il abandonne en
# silence.
#
# CE QUE CA AURAIT COUTE SANS CETTE MESURE : le filet de secours de
# s-ouvrir-exe — celui qui rejoue par umu-run quand le chemin direct echoue —
# aurait echoue lui aussi, en silence, exactement dans le cas ou l'utilisateur
# compte dessus. Un filet qui ne rattrape rien est pire qu'aucun filet : il
# donne l'illusion d'un recours.
#
# D'ou cette paire. Tout ce qui passe par umu-run l'encadre.
s_windows_pause() {
    if systemctl --user is-active --quiet s-windows.service 2>/dev/null; then
        systemctl --user stop s-windows.service 2>/dev/null
        printf '1'
    else
        s_windows_serveur_vivant && { "${WINESERVER:-$(s_windows_proton)/files/bin/wineserver}" -k 2>/dev/null; printf '1'; return; }
        printf '0'
    fi
    # Le serveur ecrit le registre en sortant : sans cette attente, la capture
    # ou l'installation qui suit lirait un registre d'avant.
    local i
    for i in $(seq 20); do s_windows_serveur_vivant || break; sleep 0.25; done
}

s_windows_reprendre() {
    [ "${1:-0}" = "1" ] || return 0
    systemctl --user start s-windows.service 2>/dev/null || true
}

s_windows_serveur() {
    s_windows_serveur_vivant && return 0
    systemctl --user start s-windows.service 2>/dev/null || return 1
    # Le serveur repond en moins d'une seconde ; on lui en laisse dix, et on
    # VERIFIE au lieu de dormir un temps fixe en esperant.
    local i
    for i in $(seq 40); do
        s_windows_serveur_vivant && return 0
        sleep 0.25
    done
    return 1
}

# ---------------------------------------------------------------------------
# « Est-ce que Windows s'est calme ? » — ce qui remplace wineserver -w
# ---------------------------------------------------------------------------
# ON NE PEUT PLUS APPELER « wineserver -w » : il attend que le SERVEUR sorte, et
# le notre est fait pour ne jamais sortir. L'appeler ici bloquerait pour
# toujours — le correctif aurait cree une panne pire que celle qu'il repare.
#
# La vraie question n'a jamais ete « le serveur est-il sorti » mais « le
# programme a-t-il fini d'ecrire ». Un installateur Windows pose ses raccourcis
# dans ses dernieres secondes, apres que son processus principal est sorti :
# c'est pour ca que VLC, installe le 2026-08-23, n'apparaissait nulle part.
#
# On compte donc les processus du prefixe qui ne sont PAS des services
# permanents. Sous Wine, un programme Windows est un processus Linux ordinaire
# dont l'environnement porte WINEPREFIX : la question se repond du dehors, sans
# rien demander a Wine.
s_windows_calme() {
    local pid comm reste=0
    for pid in $(pgrep -u "$(id -u)" . 2>/dev/null); do
        [ -r "/proc/$pid/environ" ] || continue
        grep -qz -e "^WINEPREFIX=$S_WIN_PFX" -e "^WINEPREFIX=$S_PREFIXE" \
             "/proc/$pid/environ" 2>/dev/null || continue
        comm="$(cat "/proc/$pid/comm" 2>/dev/null)"
        case " $S_WIN_SERVICES " in
            *" $comm "*) continue ;;
        esac
        reste=1
        break
    done
    [ "$reste" -eq 0 ]
}

s_windows_attendre_calme() {
    local limite="${1:-25}" i
    for i in $(seq "$((limite * 2))"); do
        s_windows_calme && return 0
        sleep 0.5
    done
    return 1
}
