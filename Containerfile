# S — un OS qui reunit Windows, Linux et Android.
#
# On empile sur Bazzite plutot que de repartir de Fedora nu : elle apporte deja
# la pile de jeu reglee (Steam, Proton, GE-Proton, gamescope) et la recette
# Waydroid. Refaire ce travail serait le refaire moins bien.
#
# Ce qui suit n'ajoute que ce qui manque vraiment : l'identite, et les coutures
# entre les trois mondes.

# Le contexte de construction, isole dans son propre etage pour ne rien laisser
# dans l'image finale.
FROM scratch AS ctx
COPY build_files /build_files

FROM ghcr.io/ublue-os/bazzite:stable

# Ce qui se depose tel quel, sans logique.
COPY files/ /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/10-base.sh && \
    bash /ctx/build_files/20-android.sh && \
    bash /ctx/build_files/30-coutures.sh && \
    ostree container commit
