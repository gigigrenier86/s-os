#!/usr/bin/bash
# S — joindre la machine depuis un telephone, sans rien y laisser de secret.
#
# CE QUE CE SCRIPT NE FAIT PAS, ET C'EST LE PLUS IMPORTANT.
# Il ne pose AUCUNE cle SSH, AUCUNE cle d'authentification Tailscale, AUCUN
# identifiant. Le depot est public : tout ce qui entre ici est lisible par
# n'importe qui. L'appairage du telephone est un geste de l'utilisateur, fait
# une seule fois sur la machine, et son etat vit dans « /var/lib/tailscale » —
# qui survit aux « bootc upgrade » puisque /var est propre a la machine et
# n'entre jamais dans l'image. C'est ici la bonne moitie de la regle 1 : ce
# qui est PERSONNEL doit rester dans /var, ce qui doit TENIR va dans /usr.
#
# POURQUOI TAILSCALE PLUTOT QU'UNE REDIRECTION DE PORT.
# Releve sur la machine le 2026-08-25 : elle est en Wi-Fi sur
# 192.168.40.149/24, une adresse privee. Depuis l'exterieur elle n'existe pas.
# Les deux voies sont d'ouvrir le port 22 sur la box — c'est-a-dire exposer un
# sshd a l'Internet entier, et ce projet ne fera pas ca — ou de monter un
# reseau prive. Tailscale est DEJA dans l'image de base (tailscale-1.102.3,
# mesure, pas suppose), chiffre de bout en bout par WireGuard, et ne demande
# aucune configuration de routeur.
#
# CE QU'IL FAUT SAVOIR SUR « tailscaled » ET « bootc ».
# Le paquet livre l'unite « disabled ». Un « systemctl enable » tape a la main
# sur la machine ne survivrait pas — c'est la regle du carnet, et elle a deja
# coute assez cher ailleurs. On l'active donc ICI, ou l'activation devient un
# lien dans /etc que le deploiement emporte. Meme geste que « sshd.socket »
# dans 10-base.sh, et pour la meme raison.
#
# MOSH, ET POURQUOI CE N'EST PAS UN LUXE SUR UN TELEPHONE.
# Un telephone change de reseau sans arret : Wi-Fi de la maison, 4G dans la
# rue, Wi-Fi ailleurs. Chaque changement d'adresse IP TUE une session SSH —
# elle gele, puis tombe, et le travail en cours avec elle. Mosh survit au
# changement d'adresse ET a la mise en veille de l'ecran, parce qu'il ne tient
# aucune connexion TCP : il rejoue l'etat du terminal en UDP. C'est la
# difference exacte entre « je peux travailler depuis mon telephone » et « je
# peux travailler depuis mon telephone tant que je ne bouge pas ».
#
# CE QUE CE SCRIPT REFUSE DE FAIRE SEMBLANT DE REGLER.
# Releve le 2026-08-25 : la machine ne s'endort jamais — « powerdevil » ne
# tourne pas (la coquille est Constellation, pas Plasma), « IdleAction » vaut
# « ignore », zero veille depuis l'allumage. Mais RIEN NE LE DECIDE : c'est
# l'absence de gestionnaire d'energie qui le produit, pas un choix. Et un
# fragment « logind.conf.d » n'y changerait rien, car PowerDevil n'endort pas
# la machine par « IdleAction » : il appelle « Suspend() » directement, que ce
# reglage ne gouverne pas. Poser un garde ici serait poser un garde qui ne
# garde rien — le faux temoin que ce carnet collectionne depuis le 2026-08-20.
# C'est donc consigne au carnet plutot que faussement corrige.
set -euo pipefail

echo "=== 45-telephone : joindre S depuis l'exterieur ==="

# ---------------------------------------------------------------------------
# 1. Tailscale — verifier avant d'activer
# ---------------------------------------------------------------------------
# Meme regle que 20-android.sh face a « waydroid-launcher » : on ne
# reimplemente pas ce que l'amont maintient, MAIS on fait echouer la
# construction le jour ou l'amont le retire — plutot que de livrer une image
# dont l'acces distant s'est evapore en silence.
test -x /usr/bin/tailscale || {
    echo "ECHEC : /usr/bin/tailscale absent — la base ne fournit plus Tailscale." >&2
    echo "        L'acces depuis le telephone reposait dessus." >&2
    exit 1
}
test -f /usr/lib/systemd/system/tailscaled.service || {
    echo "ECHEC : tailscaled.service absent de /usr/lib/systemd/system." >&2
    exit 1
}

systemctl enable tailscaled.service
echo "  tailscale     : $(/usr/bin/tailscale version 2>/dev/null | head -1) — unite activee"

# ---------------------------------------------------------------------------
# 2. Mosh — la session qui survit au trajet
# ---------------------------------------------------------------------------
dnf5 install -y mosh

# Le controle de la regle 2 : le pire resultat n'est pas l'echec, c'est le
# succes silencieux. Un paquet qui se poserait dans /var ou /opt donnerait une
# image creuse, et ca ne se verrait qu'a l'usage, sur une autre machine.
if rpm -ql mosh | grep -qE '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : mosh pose des fichiers hors /usr et /etc." >&2
    rpm -ql mosh | grep -E '^/(var|opt)/|^/usr/local/' >&2
    exit 1
fi
echo "  mosh          : $(rpm -q --qf '%{VERSION}' mosh 2>/dev/null) — tout dans /usr"

# ---------------------------------------------------------------------------
# 3. Ce qui n'est PAS fait ici, et pourquoi on l'ecrit dans le journal
# ---------------------------------------------------------------------------
# Convention du depot : un script qui decouvre quelque chose l'ecrit. Ces deux
# lignes sont ce qui separe une image prete d'une machine joignable, et elles
# ne peuvent pas etre faites a la construction.
echo "  reste a faire : « sudo tailscale up --ssh » UNE FOIS sur la machine —"
echo "                  il faut un humain connecte a son compte, et aucune cle"
echo "                  d'authentification n'entrera dans ce depot public."

# ---------------------------------------------------------------------------
# Le controle du carnet
# ---------------------------------------------------------------------------
test -L /etc/systemd/system/multi-user.target.wants/tailscaled.service || {
    echo "ECHEC : tailscaled n'a pas ete active — le lien n'existe pas." >&2
    exit 1
}
command -v mosh-server >/dev/null || {
    echo "ECHEC : mosh-server introuvable apres installation." >&2
    exit 1
}

echo "=== 45-telephone : fait ==="
