#!/usr/bin/bash
set -euxo pipefail

# ==========================================================================
# Telechargements — video (yt-dlp), acceleration (aria2), torrent (qBittorrent)
# ==========================================================================
#
# DEMANDE DE L'UTILISATEUR LE 2026-09-18 : rendre S Web capable de telecharger
# des videos, de teleharger plus vite, et d'ouvrir un torrent — « hors pair »,
# sans rien reimplementer. Role Wizard invoque en premier : les trois outils
# existent deja, entretenus par des projets etablis, et TOUS LES TROIS sont
# dans les depots Fedora officiels (updates/updates-archive/fedora) — aucun
# COPR, aucun binaire externe, aucune question de provenance.
#
#   yt-dlp       2026.08.19   Unlicense (domaine public)   updates-archive
#   aria2        1.37.0       GPL-2.0+ avec exceptions      fedora
#   qbittorrent  5.2.3        GPL-2.0-or-later              updates
#
# CE QUE CHACUN FAIT, ET POURQUOI LES TROIS PLUTOT QU'UN SEUL. yt-dlp connait
# par extracteur dedie des milliers de sites video ; aria2 telecharge
# n'importe quel lien direct en 16 connexions simultanees (« High speed
# download utility with resuming and segmented downloading », son propre
# resume) — c'est lui qui repond a « telechargement multiple/accelere » ;
# qBittorrent est le client BitTorrent libre de reference depuis le retrait
# du uTorrent original vers du proprietaire truffe de publicite. Aucun ne
# fait le travail d'un autre : les superposer serait reinventer une roue que
# l'amont a deja fabriquee trois fois, chacune mieux qu'une quatrieme ne le
# ferait ici.
#
# L'INTEGRATION A S WEB NE PASSE PAR AUCUNE EXTENSION DE NAVIGATEUR. Voir
# l'entree du meme jour sur uBlock Origin : le vrai uBlock Origin a ete
# retire du Chrome Web Store, Google ayant coupe les extensions Manifest V2
# restantes. Un ecosysteme d'extensions est un sol mouvant ; un gestionnaire
# xdg-mime ne l'est pas, et c'est deja le mecanisme de ce depot pour tout ce
# qu'un navigateur ne doit pas ouvrir lui-meme (voir s-ouvrir-exe et ses
# freres). « s-telecharger » (nouveau) recoit l'adresse d'un signet pose sur
# la page de demarrage de S Web ; qBittorrent recoit directement les liens
# magnet et .torrent, par association xdg-mime — voir files/etc/xdg/
# mimeapps.list et 40-coutures.sh pour les deux controles correspondants.
dnf5 install -y --setopt=install_weak_deps=False yt-dlp aria2 qbittorrent

# ---------------------------------------------------------- Verification --
for paquet in yt-dlp aria2 qbittorrent; do
    if rpm -ql "$paquet" 2>/dev/null | grep -E '^/(var|opt)/|^/usr/local/'; then
        echo "ECHEC : $paquet a pose des fichiers hors de /usr et /etc." >&2
        exit 1
    fi
done

[[ -x /usr/bin/yt-dlp ]] \
    || { echo "ECHEC : /usr/bin/yt-dlp absent apres installation." >&2; exit 1; }
[[ -x /usr/bin/aria2c ]] \
    || { echo "ECHEC : /usr/bin/aria2c absent apres installation." >&2; exit 1; }
[[ -s /usr/share/applications/org.qbittorrent.qBittorrent.desktop ]] \
    || { echo "ECHEC : qBittorrent n'a pas pose son .desktop attendu — le nom a peut-etre change en amont, mimeapps.list viserait alors une cible morte." >&2; exit 1; }

echo "Telechargements poses :"
rpm -q yt-dlp aria2 qbittorrent | sed 's/^/  /'
