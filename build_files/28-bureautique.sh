#!/usr/bin/bash
set -euxo pipefail
source /ctx/build_files/lib-opt.sh

# ==========================================================================
# La bureautique : LibreOffice, natif, hors ligne, garanti
# ==========================================================================
#
# CE QUE CE FICHIER REPARE, ET POURQUOI IL EXISTE.
#
# Demande de l'utilisateur : « je veux [Microsoft Office] intégré dans S,
# faut que ça marche ». Mesuré le 2026-09-10, sur cette machine, avant
# d'écrire une ligne : Microsoft 365 (l'abonnement) ne s'installe QUE par
# Click-to-Run, qui virtualise ses fichiers et son registre via App-V.
# L'échec est tombé sur « Error Code: 30088-4 » — lu dans le propre journal
# de session d'Office :
#
#     ErrorMessage: "UnexpectedError (Orchestration::UpdateAppV:
#                     TryRefreshMergedManifest failed)"
#
# App-V dépend d'un service/filtre Windows profond, sans équivalent sous
# Wine — structurel, pas une affaire de configuration. Aucun installateur
# MSI classique (qui contournerait App-V) n'est distribué publiquement pour
# ce SKU : le seul chemin pour un vrai Microsoft Office sous Wine passerait
# par un binaire de provenance non vérifiable, exactement ce que ce dépôt
# refuse d'poser dans une image publique.
#
# LibreOffice n'est pas un pis-aller choisi par défaut : c'est ce qui
# GARANTIT de marcher, tout de suite, hors ligne, sans dépendre d'un
# abonnement ni d'un service cloud. Paquets Fedora officiels, signés
# (gpgcheck=1, vérifié dans yum.repos.d) — on ne réimplémente pas ce que
# l'amont maintient.
#
# Complémentaire à ce fichier : les cinq lanceurs Microsoft 365 web
# (files/usr/share/applications/office-*.desktop) — le VRAI Word/Excel/
# PowerPoint/Outlook/OneNote, avec l'abonnement réel de l'utilisateur,
# ouverts en fenêtre dédiée par Vivaldi (patron RapidO/Gemini), sans passer
# par Wine du tout. Les deux se complètent : LibreOffice pour l'édition
# locale garantie, les apps web pour le vrai Microsoft 365 quand le réseau
# et le compte sont là.

# « install_weak_deps=False » : le paquet complet « libreoffice » tire
# Draw, Math, Base et une douzaine de langpacks d'un coup. On choisit les
# trois composants qui répondent à Word/Excel/PowerPoint, plus le français
# — cohérent avec le reste de cette image, entièrement en français.
dnf5 install -y --setopt=install_weak_deps=False \
    libreoffice-writer \
    libreoffice-calc \
    libreoffice-impress \
    libreoffice-langpack-fr

# ---------------------------------------------------------- Verification --
# Règle 2 du carnet : un paquet posé hors de /usr et /etc livrerait une
# image creuse sans que rien ne le dise.
if rpm -ql libreoffice-writer libreoffice-calc libreoffice-impress \
           libreoffice-langpack-fr 2>/dev/null \
   | grep -E '^/(var|opt)/|^/usr/local/'; then
    echo "ECHEC : LibreOffice a pose des fichiers hors de /usr et /etc." >&2
    exit 1
fi

manque=0
[[ -f /usr/share/applications/libreoffice-writer.desktop ]] \
    || { echo "ABSENT : le lanceur Writer" >&2; manque=1; }
[[ -f /usr/share/applications/libreoffice-calc.desktop ]] \
    || { echo "ABSENT : le lanceur Calc" >&2; manque=1; }
[[ -f /usr/share/applications/libreoffice-impress.desktop ]] \
    || { echo "ABSENT : le lanceur Impress" >&2; manque=1; }
[[ "$manque" -eq 0 ]] || exit 1

# Rapport non bloquant : voir la note de 26-outils.sh.
echo "Bureautique posee :"
echo "  LibreOffice  $(rpm -q libreoffice-writer --qf '%{VERSION}')" || true
