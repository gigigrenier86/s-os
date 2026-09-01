# S — un OS qui reunit Windows, Linux et Android.
#
# On empile sur Bazzite plutot que de repartir de Fedora nu : elle apporte deja
# la pile de jeu reglee (Steam, Proton, GE-Proton, gamescope) et la recette
# Waydroid. Refaire ce travail serait le refaire moins bien.
#
# Tout ce qui suit entre DANS l'image, jamais dans un mecanisme de premier
# demarrage. Un script de Bazzite a ete pris en defaut sur ce point le
# 2026-08-20 : flatpak-manager, qui a tourne 5,6 s sans rien poser puis a ecrit
# ses marqueurs. Le marqueur n'est pas le defaut — c'est le report du travail.

# Le contexte de construction, isole dans son propre etage pour ne rien laisser
# dans l'image finale.
FROM scratch AS ctx
COPY build_files /build_files

FROM ghcr.io/ublue-os/bazzite:stable

# UNE COUCHE PAR ETAPE, et l ordre n est pas indifferent.
#
# Tout tenait dans un seul RUN jusqu au 2026-08-20. Consequence mesuree par un
# « bootc upgrade » reel : changer une ligne d une couture reinvalidait la couche
# entiere, VS Code et Zoom compris, et la mise a jour annoncait
# « layers needed: 2 (2.3 GB) ». Decoupe ainsi, une retouche des coutures ne
# coute plus que sa propre couche.
#
# L ordre va donc du plus stable et du plus lourd vers le plus volatil.

# Langue francaise et acces distant
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/10-base.sh

# Waydroid : verifie binder, ne pose rien de lourd
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/20-android.sh

# libhoudini (traduction ARM d'Android, ~66 Mo) — Code Noir assume, voir
# CLAUDE.md 2026-08-30 : proprietaire, sans licence documentee, MD5 seul.
# Decision prise avec l'utilisateur. Pre-cuit ici, jamais installe ici —
# seul « s-android --traduction-arm » l'extrait, sur la machine qui le demande.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/21-android-arm.sh

# Vivaldi (438 Mo)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/25-navigateur.sh

# VS Code, Node, Gemini, Claude Code, Antigravity (~2 Go)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/26-outils.sh

# RetroArch et ses coeurs, Zoom (918 Mo)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/27-applications.sh

# L archive de Proton (468 Mo) — gros et stable
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/41-windows.sh

# /etc/skel : ce qui attend a la premiere connexion
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/30-premiere-connexion.sh

# La machine s'annonce S — une retouche d'os-release, que tout le reste lit :
# l'invite de console, l'entree du chargeur d'amorcage, le centre d'information.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/35-identite.sh

# Ce qui se depose tel quel, sans logique : gestes, lanceurs, associations.
#
# Ce COPY est ICI, et pas en tete, parce qu'il porte les fichiers qui changent le
# plus souvent. Place au debut, il invaliderait toutes les couches qui suivent —
# soit VS Code, Antigravity, Zoom et Proton — a chaque virgule corrigee dans un
# geste. Seul 40-coutures.sh en a besoin, donc il descend jusqu'a lui.
COPY files/ /

# Constellation n'a plus de COPY depuis galerie/, et c'est le changement du
# 2026-08-24 : le bureau n'est plus une page web recopiee dans l'image, c'est
# un client Wayland natif. Sa scene QML et son noyau Python entrent par le
# COPY files/ ci-dessus, comme tout le reste de S.
#
# L'ancienne page et son pont HTTP restent dans
# galerie/constellation/archive-page-web/ — la Galerie garde ses oeuvres, meme
# remplacees — mais ne sortent plus dans l'image.

# Foudre gelee, le fond d'ecran de S — meme principe : l'oeuvre et son script
# semeur vivent dans galerie/, l'image ne recoit que le rendu. Ses metadonnees
# KDE vivent dans files/usr/share/wallpapers/FoudreGelee/.
COPY galerie/foudre-gelee/foudre-gelee.png /usr/share/wallpapers/FoudreGelee/contents/images/3840x2160.png

# L'ecran de connexion porte le logo de S — et il ne peut le porter que par la.
# Plasma Login Manager n'a AUCUN systeme de themes (son QML est compile dans le
# binaire) : le fond d'ecran est le seul pixel de cet ecran que S decide. Le
# logo est donc grave DANS l'image, par galerie/foudre-gelee/graver-le-s.ps1.
#
# Il ne va PAS dans le paquet de fonds d'ecran de KDE : ce dossier est indexe
# par la taille du fichier, et y poser une seconde image 3840x2160 ferait
# apparaitre deux « Foudre gelee » dans le selecteur de fond du bureau.
COPY galerie/foudre-gelee/foudre-gelee-connexion.png /usr/share/s/connexion/foudre-gelee-s.png

# S-Constellation : la session propre de S.
#
# Elle vient APRES les COPY, parce qu'elle verifie ce qu'ils ont depose — la
# page, ses trois gestes, ses deux entrees de session — et refuse de sortir une
# image dont le bureau ne demarrerait pas. Elle vient AVANT les coutures parce
# qu'elle ne bouge qu'a chaque refonte de la coquille, la ou les coutures
# bougent a chaque geste corrige.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/36-constellation.sh

# sudo actif des la creation du compte, S preselectionnee au greeter, et le
# menu d'applications debarrasse du nom de l'amont — sans rien desinstaller.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/37-effacer-bazzite.sh

# Le disque Windows du double amorcage, partage depuis S sans redemarrer.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/38-partage-windows.sh

# Des demons pour le materiel present, et lui seul : cardwired desactive
# (gestionnaire de GPU sans objet sur un iGPU unique), condition DMI posee
# d'avance sur les unites ASUS, reglage zram decide par S.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/39-materiel.sh

# EasyEffects (~13 Mo installe) — l'egaliseur que pilote l'etoile
# « Egaliseur » de la barre laterale. Voir build_files/48-son.sh.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/48-son.sh

# GameMode — le complement du mode « Jeu » de la barre laterale. Voir
# build_files/49-jeu.sh : rien a piloter, il s'auto-active par jeu.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/49-jeu.sh

# L'ecran de connexion aux couleurs de S, et la session preselectionnee.
# APRES les COPY, puisqu'il verifie le fond d'ecran et la session qu'ils posent.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/42-greeter.sh

# Les depots actifs dont la cle GPG a disparu. Herite de la base : « terra-mesa »
# est actif et reclame RPM-GPG-KEY-terra44-mesa, quand l'image ne porte que des
# cles terra42 et terra43. Nos dnf5 ne s'en apercevaient pas — dnf ne lit la cle
# d'un depot qu'au moment d'installer un paquet VENANT de lui — mais toute
# resolution globale y tombe, et c'est ce qui bloquait la fabrication de l'ISO.
#
# APRES tous nos dnf5, pour ne rien changer a ce qui marchait deja.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/44-depots.sh

# L'ecran d'amorcage graphique aux couleurs de S.
#
# BRANCHE LE 2026-08-24, A LA DEMANDE EXPLICITE DE L'UTILISATEUR : « je vois
# encore des images de Bazzite au demarrage, c'est NON ». C'etait la derniere
# surface de l'amont qui restait visible, et la seule que 42-greeter.sh
# declarait « NON TRAITE ».
#
# CE QU'IL FAUT SAVOIR AVANT DE RECONSTRUIRE. Cette etape regenere l'initramfs.
# C'est le SEUL changement de tout ce depot qui puisse rendre la machine
# incapable de demarrer, et le filet prevu — « bootc rollback » — n'a jamais
# ete exerce. L'en-tete de 43-amorcage.sh recommandait de le brancher SEUL,
# sans aucun autre changement dans la meme version. Ce n'est pas le cas ici :
# cette version porte aussi la refonte native de Constellation. Si la machine
# ne revient pas, deux causes possibles au lieu d'une.
#
# Pour la retirer sans rien casser d'autre : commenter ce seul RUN.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/43-amorcage.sh

# Le telephone — Tailscale active, mosh pose
#
# Place juste avant les coutures, et pas ailleurs : « 40-coutures.sh » se
# termine par « ostree container commit », donc rien ne peut venir apres lui.
# Ce script-ci ne bougera presque jamais ; le jour ou il bougera, il ne fera
# reconstruire que la couche des coutures — 9,6 Mo, mesures le 2026-08-20.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/45-telephone.sh

# EXIGER LA SIGNATURE — apres le COPY, qui pose la cle et la declaration.
#
# Sa place ici n'est pas indifferente : le script LIT deux fichiers venus de
# « COPY files/ / » et echoue s'ils manquent. Plus haut, il ne les verrait pas
# et livrerait une image qui exige une signature qu'elle ne sait pas verifier.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/46-signature.sh

# s-android : module SELinux (renomme depuis celui de Waydroid, retire dans
# 20-android.sh) et verification de ce que COPY files/ / a depose.
# APRES le COPY (ligne 84), comme 36/37/38/39/42/44/45/46 : il lit ce qu'il
# a pose et echoue s'il manque.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/47-android-selinux.sh

# Les coutures — la partie qui bouge le plus
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/40-coutures.sh && \
    ostree container commit
