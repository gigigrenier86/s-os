# S — un OS qui reunit Windows, Linux et Android.
#
# On empile sur Bazzite plutot que de repartir de Fedora nu : elle apporte deja
# la pile de jeu reglee (Steam, Proton, GE-Proton, gamescope) et la recette
# Waydroid. Refaire ce travail serait le refaire moins bien.
#
# Tout ce qui suit entre DANS l'image, jamais dans un mecanisme de premier
# demarrage. Trois scripts de Bazzite ont ete pris en defaut sur ce point le
# 2026-08-20 — ils differaient leur travail et ecrivaient des marqueurs qui les
# empechaient de reessayer. La regle qui en decoule tient le reste du fichier.

# Le contexte de construction, isole dans son propre etage pour ne rien laisser
# dans l'image finale.
FROM scratch AS ctx
COPY build_files /build_files

FROM ghcr.io/ublue-os/bazzite:stable

# Ce qui se depose tel quel, sans logique : lanceurs, reglages, identite.
COPY files/ /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build_files/10-base.sh && \
    bash /ctx/build_files/20-android.sh && \
    bash /ctx/build_files/25-navigateur.sh && \
    bash /ctx/build_files/26-outils.sh && \
    bash /ctx/build_files/27-applications.sh && \
    bash /ctx/build_files/30-coutures.sh && \
    ostree container commit
