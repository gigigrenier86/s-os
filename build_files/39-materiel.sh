#!/usr/bin/bash
# S — ne pas faire tourner des demons pour du materiel qui n'existe pas.
#
# TROIS SYMPTOMES RAPPORTES DU DEMARRAGE REEL, ET TROIS CAUSES DIFFERENTES.
# Ce script n'en traite que deux : la troisieme n'est pas une panne.
#
#   1. « asusd.service — ASUS Notebook Control » en echec, six fois de suite,
#      sur une machine Lenovo. Cause : le portail de la base (« ujust asus »)
#      a superpose asusctl a moitie. CE SCRIPT NE LE RETIRE PAS — il n'est pas
#      dans l'image de S, et le retirer d'ici serait masquer un service que S
#      n'a jamais pose. C'est le geste « s-nettoyer » qui l'enleve, sur la
#      machine. On pose seulement une condition materielle, D'AVANCE, pour que
#      le jour ou quelqu'un reinstalle asusctl sur une machine non-ASUS, le
#      service se taise au lieu d'echouer en boucle.
#
#   2. « cardwired.service — Cardwire Daemon » en echec. Celui-la vient bien de
#      l'image : Bazzite l'a integre le 2026-08-20, en remplacement de
#      switcheroo-control et supergfxctl. C'est un gestionnaire de GPU qui
#      masque une carte aux applications par des crochets eBPF. Sur une machine
#      a GPU integre UNIQUE, il n'a rien a masquer. On le desactive.
#
#   3. « Added device: zram0 » a chaque demarrage. Ce n'est pas une panne, et
#      ce script ne la « repare » donc pas — voir la section zram plus bas, qui
#      explique pourquoi c'est impossible et ce qu'on fait a la place.
set -euo pipefail

echo "=== 39-materiel : des demons pour le materiel present, et lui seul ==="

# ---------------------------------------------------------------------------
# 1. asusd — une condition materielle, posee d'avance
# ---------------------------------------------------------------------------
# POURQUOI UNE CONDITION ET PAS UN MASQUAGE. L'amont d'asusctl a bien prevu le
# probleme : il n'active PAS asusd par un « [Install] », il le fait declencher
# par une regle udev qui exige le vendeur DMI « ASUS* » ET le pilote
# « asus-nb-wmi ». Mais « asus-shutdown.service », lui, porte
# « WantedBy=multi-user.target » ET « Requires=asusd.service » : il tire donc
# asusd a chaque demarrage, meme la ou la regle udev ne l'aurait jamais fait.
# Avec « Restart=on-failure » et « StartLimitBurst=5 », cela donne exactement
# les six lignes en echec vues sur la photo du 2026-08-21.
#
# « ConditionFirmware=smbios-field(...) » lit /sys/class/dmi/id/sys_vendor et
# accepte un motif. C'est la MEME regle que celle d'udev cote amont, exprimee
# la ou elle manque. Une condition non remplie fait SAUTER l'unite en silence,
# sans la mettre en echec — c'est precisement ce qu'on veut.
#
# ATTENTION, PIEGE VERIFIE : dans systemd, plusieurs conditions sont combinees
# en ET, jamais en OU. On n'en pose donc qu'une seule, dont le motif « ASUS* »
# couvre a la fois « ASUS » et « ASUSTeK COMPUTER INC. ». Et on n'ecrit PAS de
# « ConditionFirmware= » vide en tete : cela effacerait toutes les conditions
# de l'unite d'origine, y compris celles que l'amont pourrait ajouter demain.
poser_condition_asus() {
    local unite="$1" racine="$2"
    install -d "${racine}/${unite}.d"
    cat > "${racine}/${unite}.d/10-s-materiel.conf" <<'CONF'
[Unit]
# Pose par S : ne demarrer que sur du vrai materiel ASUS.
# Sur toute autre machine, l'unite est SAUTEE (pas « en echec »).
ConditionFirmware=smbios-field(sys_vendor $= "ASUS*")
CONF
}

for unite in asusd.service asus-shutdown.service; do
    poser_condition_asus "$unite" /usr/lib/systemd/system
done
poser_condition_asus asusd-user.service /usr/lib/systemd/user

# Un « drop-in » qui vise une unite ABSENTE est simplement ignore par systemd.
# On peut donc le poser avant meme que le paquet existe — et c'est tout
# l'interet : il sera deja la si quelqu'un relance « ujust asus ».
echo "  asusd         : condition DMI posee d'avance (l'unite n'est pas dans l'image)"

# ---------------------------------------------------------------------------
# 2. cardwired — desactive, parce qu'il n'a rien a faire ici
# ---------------------------------------------------------------------------
# Il vient de l'image amont et son preset l'active partout, sans regarder le
# materiel. Il refuse par ailleurs de demarrer si /sys/kernel/security/lsm ne
# contient pas « bpf ». Quelle que soit la raison exacte de son echec sur cette
# machine, la conclusion est la meme : un seul GPU, rien a masquer, rien a
# gagner. Il n'existe aucune condition systemd honnete pour « cette machine a
# deux cartes graphiques » — la numerotation de /sys/class/drm n'est pas
# stable — donc on tranche par une desactivation, qui se defait d'une commande.
if [ -f /usr/lib/systemd/system/cardwired.service ]; then
    systemctl disable cardwired.service || true
    echo "  cardwired     : desactive (gestionnaire de GPU, sans objet sur un iGPU unique)"
else
    # S'il disparait de l'amont un jour, on veut le savoir plutot que de
    # laisser une ligne morte dans ce script.
    echo "  cardwired     : ABSENT de l'image amont — plus rien a desactiver"
fi

# ---------------------------------------------------------------------------
# 3. zram — ce qu'on ne repare pas, et pourquoi
# ---------------------------------------------------------------------------
# « Added device: zram0 » a chaque demarrage vient du NOYAU (zram_drv.c), pas
# de systemd. Un peripherique zram est un disque compresse EN MEMOIRE VIVE : il
# n'existe plus quand la machine s'eteint. Il est donc recree a chaque
# demarrage, par construction, et AUCUNE image ne peut le pre-cuire — ce serait
# pre-cuire de la RAM. Le cout est de l'ordre de la milliseconde.
#
# CE QU'ON PEUT FAIRE, ET QU'ON FAIT : que le reglage soit celui de S, decide
# ici, plutot qu'hérité de la base. Detail utile et peu connu : un fragment de
# « zram-generator.conf.d/ » l'emporte sur le fichier principal QUEL QUE SOIT
# son dossier — le .conf principal est lu en premier et a la priorite la plus
# BASSE. On bat donc le /etc/systemd/zram-generator.conf de Bazzite depuis
# /usr, sans jamais toucher a /etc, ce qui est exactement ce qu'il faut sur
# ostree.
#
# Le dimensionnement : la moitie de la memoire, plafonnee a 8 Gio. S vit sur un
# disque USB a plateaux, ou un swap sur disque serait catastrophique — le swap
# compresse en memoire n'est pas un luxe ici, c'est ce qui evite l'effondrement.
# Pour le couper un jour, « zram-size = 0 » suffit : les peripheriques de
# taille finale nulle sont ecartes, et plus aucune unite n'est engendree.
install -d /usr/lib/systemd/zram-generator.conf.d
cat > /usr/lib/systemd/zram-generator.conf.d/90-s-zram.conf <<'CONF'
# Pose par S. Un fragment conf.d l'emporte sur le fichier principal, quel que
# soit son dossier : ceci bat le reglage de la base sans toucher a /etc.
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
CONF
echo "  zram          : reglage de S pose (min(ram/2, 8 Gio), zstd) — le peripherique"
echo "                  reste recree a chaque demarrage, c'est de la RAM"

# ---------------------------------------------------------------------------
# Le controle du carnet : rien hors /usr
# ---------------------------------------------------------------------------
for f in /usr/lib/systemd/system/asusd.service.d/10-s-materiel.conf \
         /usr/lib/systemd/system/asus-shutdown.service.d/10-s-materiel.conf \
         /usr/lib/systemd/user/asusd-user.service.d/10-s-materiel.conf \
         /usr/lib/systemd/zram-generator.conf.d/90-s-zram.conf; do
    test -s "$f" || { echo "ECHEC : $f n'a pas ete pose." >&2; exit 1; }
done

echo "=== 39-materiel : fait ==="
