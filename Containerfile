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

# Constellation, le bureau etoile — le prototype de galerie/ entre tel quel.
# Une seule source : le fichier reste dans galerie/, l'image le recopie. Son
# lanceur vit dans files/usr/share/applications/, meme forme que RapidO.
COPY galerie/constellation/constellation.html /usr/share/s/constellation/constellation.html

# Foudre gelee, le fond d'ecran de S — meme principe : l'oeuvre et son script
# semeur vivent dans galerie/, l'image ne recoit que le rendu. Ses metadonnees
# KDE vivent dans files/usr/share/wallpapers/FoudreGelee/.
COPY galerie/foudre-gelee/foudre-gelee.png /usr/share/wallpapers/FoudreGelee/contents/images/3840x2160.png

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

# Les coutures — la partie qui bouge le plus
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/40-coutures.sh && \
    ostree container commit
