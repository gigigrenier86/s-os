#!/usr/bin/env python3
"""S Web -- graver un S de verre brise, rouge/vert/bleu, sans medaillon.

DEMANDE DE L'UTILISATEUR LE 2026-09-07 : « on retire vivaldi et on met S web
en avant, un beau S de verre brises vert rouge et bleu, comme le logo de
S ». Le logo de S (galerie/logo-s-os/) est un medaillon PHOTOGRAPHIE
(verre brise vert/bleu/or, sur un fond de circuit imprime, avec anneau et
texte) -- une image fournie, decoupee. Ici, aucune image source n'existe
avec les trois couleurs demandees (rouge, vert, bleu) : le logo est donc
COMPOSE, pas decoupe, en reprenant le meme langage visuel -- des eclats de
verre anguleux qui reconstituent un S -- mais sans medaillon ni anneau ni
texte : une icone d'application doit rester lisible a 16 px, un cercle dore
et une legende ne le permettraient pas a cette taille.

POURQUOI PAS DE BIBLIOTHEQUE DE GEOMETRIE (scipy/shapely absentes de cette
machine, verifie avant d'ecrire une ligne) : le decoupage en eclats ne
mimique pas une vraie fracture physique (un vrai diagramme de Voronoi) --
il RESSEMBLE a des eclats. La technique retenue : un masque du glyphe « S »
(rendu par une police en gras, donc un contour net et lisible), puis des
polygones anguleux tires au hasard, chacun peint dans une couleur, dont on
ne garde que l'intersection avec le masque (ImageChops.multiply sur le
canal alpha) -- puis chaque eclat garde est DEPLACE legerement vers
l'exterieur du centre du S, ce qui ouvre de vraies fentes entre eclats
sans qu'aucune fracture n'ait ete calculee geometriquement.

PREUVE : aucune encore. Genere et regarde a l'ecran (agrandi) avant d'etre
retenu, mais jamais vu sur du vrai materiel apres une construction et un
redemarrage -- meme reserve que logo-s-os/graver.py a sa propre creation.
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", ".."))

ICONE_256 = os.path.join(
    RACINE, "files/usr/share/icons/hicolor/256x256/apps/s-web.png"
)
ICONE_128 = os.path.join(
    RACINE, "files/usr/share/icons/hicolor/128x128/apps/s-web.png"
)
ICONE_64 = os.path.join(
    RACINE, "files/usr/share/icons/hicolor/64x64/apps/s-web.png"
)
APERCU_GALERIE = os.path.join(ICI, "s-web-logo.png")

# Rouge, vert, bleu -- le triptyque demande, pas des teintes decoratives
# choisies au hasard. Deux tons par couleur (clair/fonce) pour que le verre
# ait un vrai relief facette par facette, pas un aplat.
PALETTE = [
    ((230, 60, 70), (150, 25, 35)),      # rouge
    ((70, 210, 130), (20, 130, 75)),     # vert
    ((70, 140, 235), (25, 75, 165)),     # bleu
]

GRAINE = 20260907
random.seed(GRAINE)

RES = 2048          # resolution de travail -- reduite a la fin
POLICE = "/usr/share/fonts/liberation-sans-fonts/LiberationSans-Bold.ttf"


def masque_du_s(res):
    """Le contour du glyphe « S », rendu en gras, agrandi au maximum du
    cadre. Mesure et non devine : on cherche la plus grande taille de
    police dont la boite du texte tient dans le cadre, par dichotomie
    simple plutot que par une constante recopiee a l'oeil."""
    bas, haut = 10, res * 2
    meilleure = None
    while bas <= haut:
        mi = (bas + haut) // 2
        f = ImageFont.truetype(POLICE, mi)
        essai = Image.new("L", (res, res), 0)
        d = ImageDraw.Draw(essai)
        boite = d.textbbox((0, 0), "S", font=f)
        larg, ht = boite[2] - boite[0], boite[3] - boite[1]
        if larg <= res * 0.88 and ht <= res * 0.88:
            meilleure = (mi, boite)
            bas = mi + 1
        else:
            haut = mi - 1
    taille, boite = meilleure
    f = ImageFont.truetype(POLICE, taille)
    masque = Image.new("L", (res, res), 0)
    d = ImageDraw.Draw(masque)
    larg, ht = boite[2] - boite[0], boite[3] - boite[1]
    x = (res - larg) // 2 - boite[0]
    y = (res - ht) // 2 - boite[1]
    d.text((x, y), "S", font=f, fill=255)
    return masque


def polygone_eclat(cx, cy, rayon):
    """Un polygone irregulier a 5-7 sommets, jamais un cercle parfait --
    c'est l'irregularite du rayon par sommet qui donne l'allure d'un
    tesson, pas le nombre de cotes."""
    n = random.randint(5, 7)
    pts = []
    depart = random.uniform(0, math.tau)
    for i in range(n):
        angle = depart + (math.tau * i / n) + random.uniform(-0.35, 0.35)
        r = rayon * random.uniform(0.55, 1.15)
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    return pts


def graver_eclats(masque, res):
    """Semis d'eclats colores, chacun rogne au masque du S puis pousse
    vers l'exterieur -- c'est ce dernier pas qui ouvre les fentes."""
    cx_s, cy_s = res / 2, res / 2
    scene = Image.new("RGBA", (res, res), (0, 0, 0, 0))

    # Semis de centres : on tire dans le cadre entier et on ne garde que
    # ceux tombant sur le masque (ou tout pres, pour deborder un peu sur
    # les bords et laisser les eclats se toucher).
    centres = []
    essais = 0
    while len(centres) < 130 and essais < 20000:
        essais += 1
        x = random.uniform(res * 0.08, res * 0.92)
        y = random.uniform(res * 0.06, res * 0.94)
        if masque.getpixel((int(x), int(y))) > 40:
            centres.append((x, y))

    rayon_moyen = res * 0.052

    for (x, y) in centres:
        clair, fonce = random.choice(PALETTE)
        pts = polygone_eclat(x, y, rayon_moyen * random.uniform(0.6, 1.5))

        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        bx0, by0 = int(min(xs)) - 2, int(min(ys)) - 2
        bx1, by1 = int(max(xs)) + 2, int(max(ys)) + 2
        larg, ht = max(1, bx1 - bx0), max(1, by1 - by0)

        # Le degrade EST le verre : une facette n'est jamais un aplat.
        # Image.linear_gradient va du noir au blanc de haut en bas ;
        # colorize() y substitue clair/fonce, puis une rotation aleatoire
        # decide quelle arete de l'eclat attrape la lumiere.
        degrade = Image.linear_gradient("L").rotate(
            random.uniform(0, 360), resample=Image.BICUBIC, expand=True
        )
        dw, dh = degrade.size
        cx0, cy0 = dw // 2 - larg // 2, dh // 2 - ht // 2
        degrade = degrade.crop((cx0, cy0, cx0 + larg, cy0 + ht))
        teinte = ImageOps.colorize(degrade, black=fonce, white=clair).convert("RGBA")

        masque_eclat = Image.new("L", (larg, ht), 0)
        d = ImageDraw.Draw(masque_eclat)
        pts_locaux = [(px - bx0, py - by0) for (px, py) in pts]
        d.polygon(pts_locaux, fill=235)

        calque = Image.new("RGBA", (res, res), (0, 0, 0, 0))
        piece = Image.new("RGBA", (larg, ht), (0, 0, 0, 0))
        piece.paste(teinte, (0, 0))
        piece.putalpha(masque_eclat)
        calque.paste(piece, (bx0, by0), piece)

        cd = ImageDraw.Draw(calque)
        cd.polygon(pts, outline=fonce + (255,), width=max(1, res // 1400))
        i = random.randrange(len(pts))
        cd.line([pts[i], pts[(i + 1) % len(pts)]], fill=(255, 255, 255, 110), width=max(1, res // 1400))

        alpha_rogne = ImageChops.multiply(calque.split()[3], masque)
        calque.putalpha(alpha_rogne)

        # Une fente fine entre eclats voisins, pas une explosion : le
        # decalage reste sous 1 % de la resolution, uniforme, jamais
        # amplifie par la distance au centre -- sinon les eclats du bord
        # se detachent completement du S, comme la premiere version l'a
        # montre a l'ecran.
        dx, dy = x - cx_s, y - cy_s
        dist = math.hypot(dx, dy) or 1
        pousse = res * 0.006
        ox = int(dx / dist * pousse)
        oy = int(dy / dist * pousse)
        decale = calque.transform(
            (res, res), Image.AFFINE, (1, 0, -ox, 0, 1, -oy), resample=Image.BICUBIC
        )
        scene.alpha_composite(decale)

    return scene


def halo(scene, res, teinte, rayon_frac, force):
    cadre = res
    disque = Image.new("L", (cadre, cadre), 0)
    d = ImageDraw.Draw(disque)
    c = cadre // 2
    r = int(res * rayon_frac)
    d.ellipse((c - r, c - r, c + r, c + r), fill=force)
    disque = disque.filter(ImageFilter.GaussianBlur(r * 0.5))
    fond = Image.new("RGBA", (cadre, cadre), teinte + (0,))
    fond.putalpha(disque)
    base = Image.new("RGBA", (cadre, cadre), (0, 0, 0, 0))
    base.alpha_composite(fond)
    base.alpha_composite(scene)
    return base


def principal():
    masque = masque_du_s(RES)
    print(f"masque du S : {masque.size}")

    eclats = graver_eclats(masque, RES)
    print(f"eclats poses : icone composee sur fond transparent")

    for chemin, taille in ((ICONE_256, 256), (ICONE_128, 128), (ICONE_64, 64)):
        os.makedirs(os.path.dirname(chemin), exist_ok=True)
        eclats.resize((taille, taille), Image.LANCZOS).save(chemin)
        print(f"icone {taille}px -> {chemin}")

    # Un aperçu plus grand pour la Galerie, avec un halo tricolore doux
    # derriere -- jamais dans l'icone elle-meme, qui doit rester nette et
    # petite.
    fond_apercu = Image.new("RGBA", (RES, RES), (14, 16, 22, 255))
    scene_halo = halo(eclats, RES, (120, 90, 200), 0.42, 190)
    fond_apercu.alpha_composite(scene_halo)
    fond_apercu.resize((900, 900), Image.LANCZOS).save(APERCU_GALERIE)
    print(f"apercu galerie -> {APERCU_GALERIE}")


if __name__ == "__main__":
    principal()
