#!/usr/bin/bash
set -euxo pipefail

# --------------------------------------------------------------------------
# La langue
# --------------------------------------------------------------------------
# Les paquets de langue ne sont pas dans l'image de base : sans eux, les
# applications retombent en anglais meme quand la locale est correctement posee.
dnf5 install -y glibc-langpack-fr hunspell-fr

# --------------------------------------------------------------------------
# Pouvoir joindre la machine quand l'ecran ne repond plus
# --------------------------------------------------------------------------
# L'image de base n'active PAS OpenSSH sur TCP : mesure le 2026-08-20 sur un
# systeme installe, seuls « sshd-unix-local.socket » et « sshd-vsock.socket »
# ecoutent, tous deux poses par systemd-ssh-generator. Le port 22 ne repond a
# personne.
#
# Or « bootc install --root-ssh-authorized-keys » depose une cle pour root :
# la cle est la, et rien ne l'ecoute. Et surtout, une machine dont le bureau
# ne demarre pas — ce qui arrive des que l'accelaration 3D manque — devient
# irreparable si l'on ne peut pas l'atteindre autrement.
#
# On active donc la socket plutot que le service : sshd n'est lance qu'a la
# premiere connexion, ce qui ne coute rien au repos.
systemctl enable sshd.socket

# --------------------------------------------------------------------------
# Un filet, et non un piege, sur le service de configuration materielle
# --------------------------------------------------------------------------
# CORRECTION d'un diagnostic errone pose plus tot dans la meme nuit.
#
# « bazzite-hardware-setup.service » avait ete pris pour un service qui fige le
# demarrage. Il n'en est rien : au PREMIER demarrage apres installation, il
# lit le materiel, applique s'il y a lieu un argument noyau — ici
# « bluetooth.disable_ertm=1 » —, puis REDEMARRE LA MACHINE, a dessein. Cela
# lui prend 1 min 52 s, mesure. Aux demarrages suivants il trouve ses marqueurs
# dans /etc/bazzite/ et rend la main immediatement : le second demarrage prend
# 25 secondes en tout.
#
# Une limite a 120 s, telle qu'elle avait ete posee, aurait donc INTERROMPU un
# travail legitime a quelques secondes de sa fin. C'etait un piege, pas un
# filet.
#
# La limite est portee a quinze minutes : assez large pour ne jamais gener le
# fonctionnement normal, assez ferme pour qu'un vrai blocage — le defaut
# rapporte en amont sous ublue-os/bazzite#434 — ne rende pas la machine
# definitivement inaccessible.
install -d /usr/lib/systemd/system/bazzite-hardware-setup.service.d
cat > /usr/lib/systemd/system/bazzite-hardware-setup.service.d/10-s-limite.conf <<'CONF'
[Service]
TimeoutStartSec=900
CONF

# --------------------------------------------------------------------------
# Le seul service observe SANS AUCUNE LIMITE au demarrage reel
# --------------------------------------------------------------------------
# Releve sur la machine le 2026-08-21 au soir, console a l'appui :
#
#   fedora-atomic-desktop-mandb-update.service/start running (2min 58s / no limit)
#
# C'est exactement la forme de defaut que « bazzite-hardware-setup » avait
# semble avoir et n'avait pas : un travail long, place dans la transaction de
# demarrage, et sans borne. Ici la borne manque VRAIMENT — « no limit » est
# imprime par systemd lui-meme.
#
# CE QUE CETTE LIMITE FAISAIT, ET CE QU'ELLE NE FAISAIT PAS — corrige le
# 2026-08-23, mesure a l'appui sur la M720q : « systemd-analyze critical-chain »
# montrait multi-user.target attendant CE SERVICE precis, via un
# « Before=multi-user.target » que systemd ajoute tout seul des qu'une unite
# porte « WantedBy=multi-user.target » (sauf si DefaultDependencies=no). Sur
# cette machine, mandb a mis 2 min 51 s a lui seul — plus de la MOITIE des
# 4 min 49 s que prenait tout le demarrage jusqu'a l'invite de connexion.
#
# L'index des pages de manuel n'a besoin d'exister ni pour ouvrir une session
# ni pour utiliser un logiciel : rien ne justifie qu'il retienne le bureau.
# « DefaultDependencies=no » retire precisement ce Before= automatique — le
# service tourne toujours (WantedBy le garde tire), mais en parallele du reste
# du demarrage plutot qu'avant lui. TimeoutStartSec reste, en filet, au cas ou
# le disque USB le ferait vraiment deraper.
install -d /usr/lib/systemd/system/fedora-atomic-desktop-mandb-update.service.d
cat > /usr/lib/systemd/system/fedora-atomic-desktop-mandb-update.service.d/10-s-limite.conf <<'CONF'
[Unit]
DefaultDependencies=no

[Service]
TimeoutStartSec=600
CONF

# Le reste de l'identite — nom affiche, theme, ecran d'amorcage — attend le
# jalon 6.
