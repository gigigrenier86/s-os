#!/usr/bin/env python3
"""Sora -- un premier logo, invente plutot que copie.

DEMANDE DE L'UTILISATEUR LE 2026-09-01 : « invente un Beau S pour
l'instant comme logo » -- en attendant qu'il fournisse la vraie image
qu'il avait en tete (jamais recuperee : collee dans le chat, jamais
enregistree sur disque, meme situation que le premier essai du logo de
S-OS le 2026-08-30). Celui-ci est donc explicitement un PLACEHOLDER,
a remplacer des que l'utilisateur donne un vrai fichier.

CE QUI LE DISTINGUE DU LOGO DE S-OS (galerie/logo-s-os/) : S-OS est un
medaillon dore/vert, en verre brise -- l'identite du systeme entier.
Sora est UN COMPOSANT a l'interieur de S (l'assistant IA), donc une
palette differente et deliberement plus "logicielle" : indigo/violet en
fond (associe communement a l'IA/au calcul), un "S" en Plex Sans Bold --
meme famille typographique que tout le reste de S -- rendu en cyan clair
avec un halo doux, sur le meme principe deja eprouve dans
galerie/logo-s-os/graver.py (disque_flou : un disque plein dans un cadre
bien plus grand que lui, puis floute -- c'est la marge, pas la formule,
qui evite tout bord visible).

AUCUN numpy sur cette machine (verifie le 2026-09-01) : le degrade
radial du fond est fait a la main, par cercles concentriques dessines du
bord vers le centre -- pas par Image.radial_gradient, dont un essai
precedent (logo S-Os) a deja produit un bord carre visible sur un cadre
de meme taille que le degrade.

PREUVE : aucune encore. Ce script tourne et sa sortie a ete regardee a
l'ecran avant d'etre postee ici, mais rien n'a encore ete vu sur du vrai
materiel apres une construction et un redemarrage.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", ".."))

ICONE = os.path.join(RACINE, "files/usr/share/icons/hicolor/256x256/apps/s-sora.png")
POLICE = "/usr/share/fonts/ibm-plex-sans-fonts/IBMPlexSans-Bold.otf"

# Indigo profond au centre -> violet-bleu au bord -- distinct de la
# palette teal/or du medaillon S-OS, pour ne jamais confondre les deux
# a l'oeil dans une liste d'icones.
CENTRE = (26, 16, 64)
BORD = (58, 32, 122)
GLYPHE = (150, 225, 250)      # cyan clair -- meme famille que le halo
                                # teal du medaillon S-OS, plus lumineux
HALO = (120, 200, 245)


def degrade_radial(taille, centre, bord):
    """Cercles concentriques du bord vers le centre -- pas de
    Image.radial_gradient (deja pris en defaut sur ce depot, voir
    l'en-tete)."""
    img = Image.new("RGB", (taille, taille), bord)
    d = ImageDraw.Draw(img)
    c = taille // 2
    rayon_max = int(taille * 0.75)
    pas = max(1, rayon_max // 200)
    for r in range(rayon_max, 0, -pas):
        t = 1 - (r / rayon_max)
        couleur = tuple(int(centre[i] * t + bord[i] * (1 - t)) for i in range(3))
        d.ellipse((c - r, c - r, c + r, c + r), fill=couleur)
    return img


def masque_circulaire(taille, marge=6):
    """4x supersamplant, meme technique que decouper_medaillon dans
    galerie/logo-s-os/graver.py -- bord net, jamais crenele."""
    echelle = 4
    grand = taille * echelle
    m = Image.new("L", (grand, grand), 0)
    d = ImageDraw.Draw(m)
    marge_hd = marge * echelle
    d.ellipse((marge_hd, marge_hd, grand - marge_hd, grand - marge_hd), fill=255)
    return m.resize((taille, taille), Image.LANCZOS)


def glyphe_avec_halo(taille, lettre, couleur_glyphe, couleur_halo):
    """La lettre est dessinee sur un canevas hors-ecran, puis son propre
    alpha sert a la fois de forme nette ET de source du halo -- meme
    principe que disque_flou (galerie/logo-s-os) : le flou se fait dans
    un cadre bien plus grand que la forme, jamais sur son propre alpha
    serre, sinon le bord de CE cadre devient visible."""
    cadre = taille * 2
    police = ImageFont.truetype(POLICE, int(taille * 1.05))

    forme = Image.new("L", (cadre, cadre), 0)
    d = ImageDraw.Draw(forme)
    bbox = d.textbbox((0, 0), lettre, font=police)
    lx = (cadre - (bbox[2] - bbox[0])) // 2 - bbox[0]
    ly = (cadre - (bbox[3] - bbox[1])) // 2 - bbox[1]
    d.text((lx, ly), lettre, font=police, fill=255)

    # Deux couches de flou : une large et pale (le "glow" qui se voit de
    # loin), une plus serree et plus dense (la lueur collee au trait) --
    # un seul flou donnait soit un halo invisible, soit une bouillie.
    halo_large = forme.filter(ImageFilter.GaussianBlur(taille * 0.16))
    halo_serre = forme.filter(ImageFilter.GaussianBlur(taille * 0.05))
    couche_halo = Image.new("RGBA", (cadre, cadre), couleur_halo + (0,))
    couche_halo.putalpha(Image.eval(halo_large, lambda p: min(255, int(p * 1.6))))
    couche_halo2 = Image.new("RGBA", (cadre, cadre), couleur_halo + (0,))
    couche_halo2.putalpha(Image.eval(halo_serre, lambda p: min(255, int(p * 1.3))))

    couche_nette = Image.new("RGBA", (cadre, cadre), couleur_glyphe + (0,))
    couche_nette.putalpha(forme)

    toile = Image.new("RGBA", (cadre, cadre), (0, 0, 0, 0))
    toile.alpha_composite(couche_halo)
    toile.alpha_composite(couche_halo2)
    toile.alpha_composite(couche_nette)
    return toile, cadre


def principal():
    taille = 256
    fond = degrade_radial(taille, CENTRE, BORD)
    fond_rgba = fond.convert("RGBA")
    fond_rgba.putalpha(masque_circulaire(taille))

    lettre, cadre = glyphe_avec_halo(taille, "S", GLYPHE, HALO)
    lettre = lettre.resize((taille, taille), Image.LANCZOS) if cadre != taille else lettre
    fond_rgba.alpha_composite(lettre, (0, 0))

    os.makedirs(os.path.dirname(ICONE), exist_ok=True)
    fond_rgba.save(ICONE)
    print("icone Sora -> %s (%s)" % (ICONE, fond_rgba.size))


if __name__ == "__main__":
    principal()
