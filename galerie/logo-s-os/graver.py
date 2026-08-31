#!/usr/bin/env python3
"""S -- graver le nouveau logo dans tout ce qu'il touche.

DEMANDE DE L'UTILISATEUR LE 2026-08-30 : « change le Logo De S-Os pour
celui-la, rend ca spectaculaire au demarrage ». Le fichier source,
logo-s-os-source.jpg, est l'image qu'il a fournie (un medaillon en verre
brise, dore et vert, sur un fond de circuit imprime) -- le fond de circuit
N'EST PAS repris : ce que S garde du fichier source est le medaillon
lui-meme, decoupe et rendu transparent, pas son arriere-plan.

CE QUE CE SCRIPT PRODUIT, ET POURQUOI TROIS FICHIERS ET NON UN SEUL :

  s-logo.png            256x256, RGBA, transparent hors du cercle.
                         L'icone d'application, l'avatar de compte (via
                         s-corriger-machine et /etc/skel/.face.icon), et le
                         "LogoPath=" du centre d'information KDE. Ecrit sous
                         files/, entre par COPY normal.

  s-logo-amorcage.png   816x816, RGBA, avec un halo doux DEJA PEINT dans
                         l'image (Plymouth ne fait lui-meme aucun fondu).
                         Le filigrane de l'ecran d'amorcage -- voir
                         build_files/43-amorcage.sh, qui explique pourquoi
                         un fichier plus grand suffit a le rendre plus
                         grand a l'ecran (le theme "two-step" ne redimen-
                         sionne jamais son filigrane). 816 px est mesure,
                         pas devine : assez grand pour se voir, assez petit
                         pour rester sous la ligne du spinner (alignement
                         vertical .7 du theme) sur un ecran 1080p.

  foudre-gelee-connexion.png   3840x2160 (2x un ecran 1080p), le fond de
                         l'ecran de connexion -- la Foudre gelee nue, avec
                         le medaillon et son propre halo composes dessus a
                         l'endroit ou convergent les eclairs. Remplace le
                         fichier du meme nom produit auparavant par
                         graver-le-s.ps1 (Windows/System.Drawing) ; ce
                         script-ci est son equivalent Linux, ecrit parce
                         que la machine qui a recu ce logo n'a plus de
                         Windows sous la main pour executer l'ancien.

LE HALO N'EST PAS UN FLOU DE L'IMAGE ELLE-MEME. Un essai a d'abord flout un
carre exactement decoupe au medaillon : le carre restait visible, en bordure,
comme une vitre teintee. La forme qui marche est un DISQUE PLEIN dessine dans
un cadre nettement plus grand que lui (4x son rayon), puis flout -- c'est la
MARGE, pas la formule, qui garantit qu'il n'y a plus rien a la limite du
cadre. Vu et corrige a l'ecran le 2026-08-30 avant d'etre retenu.

PREUVE : aucune encore. Ce script a tourne, ses trois sorties ont ete
regardees a l'ecran (agrandies a taille reelle) avant d'etre livrees, mais
aucune n'a encore ete vue sur du vrai materiel apres une vraie construction
et un vrai redemarrage. Tant que ce n'est pas fait, cette entree reste ici,
pas dans le corps du Grimoire ni dans une capture de Galerie datee.
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", ".."))
SOURCE = os.path.join(ICI, "logo-s-os-source.jpg")

ICONE = os.path.join(
    RACINE, "files/usr/share/icons/hicolor/256x256/apps/s-logo.png"
)
AMORCAGE = os.path.join(RACINE, "files/usr/share/s/marque/s-logo-amorcage.png")
FOND = os.path.join(ICI, "..", "foudre-gelee", "foudre-gelee.png")
GREETER = os.path.join(ICI, "..", "foudre-gelee", "foudre-gelee-connexion.png")


def decouper_medaillon(source_jpg):
    """Isole le medaillon circulaire, transparent hors de son anneau dore.

    Le centre et le rayon sont mesures sur l'image (scan radial le long de
    118 angles a la recherche du dernier pixel dore vu depuis le centre),
    pas devines a l'oeil -- median 705 px sur le fichier fourni le
    2026-08-30, retenu a 710 avec 6 px de marge.
    """
    src = Image.open(source_jpg).convert("RGB")
    cx, cy, r, pad = 1408, 768, 710, 6
    cote = (r + pad) * 2

    boite = (cx - r - pad, cy - r - pad, cx + r + pad, cy + r + pad)
    decoupe = src.crop(boite)

    echelle = 4
    grand = cote * echelle
    masque_hd = Image.new("L", (grand, grand), 0)
    d = ImageDraw.Draw(masque_hd)
    m = pad * echelle
    d.ellipse((m, m, grand - m, grand - m), fill=255)
    masque = masque_hd.resize((cote, cote), Image.LANCZOS)

    rgba = decoupe.convert("RGBA")
    rgba.putalpha(masque)
    return rgba


def disque_flou(rayon, teinte, intensite):
    """Un halo circulaire sans bord visible : un disque dans un cadre 4x
    plus large que son rayon, puis floute -- la marge fait le travail, pas
    la formule du degrade."""
    cadre = rayon * 4
    disque = Image.new("L", (cadre, cadre), 0)
    d = ImageDraw.Draw(disque)
    c = cadre // 2
    d.ellipse((c - rayon, c - rayon, c + rayon, c + rayon), fill=intensite)
    disque = disque.filter(ImageFilter.GaussianBlur(rayon * 0.5))
    halo = Image.new("RGBA", (cadre, cadre), teinte + (0,))
    halo.putalpha(disque)
    return halo, cadre


def liseret_pale(taille, marge=8, couleur=(220, 235, 255, 90), epaisseur=3):
    toile = Image.new("RGBA", (taille + 2 * marge, taille + 2 * marge), (0, 0, 0, 0))
    d = ImageDraw.Draw(toile)
    d.ellipse(
        (marge - 6, marge - 6, taille + marge + 5, taille + marge + 5),
        outline=couleur,
        width=epaisseur,
    )
    return toile.filter(ImageFilter.GaussianBlur(1))


def principal():
    maitre = decouper_medaillon(SOURCE)
    print(f"medaillon decoupe : {maitre.size}")

    maitre.resize((256, 256), Image.LANCZOS).save(ICONE)
    print(f"icone  -> {ICONE}")

    taille_amorcage = 340
    halo, cadre = disque_flou(int(taille_amorcage * 0.60), (140, 225, 210), 200)
    toile = Image.new("RGBA", (cadre, cadre), (0, 0, 0, 0))
    toile.alpha_composite(halo, (0, 0))
    logo_amorcage = maitre.resize((taille_amorcage, taille_amorcage), Image.LANCZOS)
    c = cadre // 2
    lxy = c - taille_amorcage // 2
    toile.alpha_composite(logo_amorcage, (lxy, lxy))
    toile.save(AMORCAGE)
    print(f"amorcage -> {AMORCAGE} ({toile.size}, filigrane {taille_amorcage} px)")

    fond = Image.open(FOND).convert("RGBA")
    larg, haut = fond.size
    taille = 560
    x = (larg - taille) // 2
    y = 300
    cx, cy = x + taille // 2, y + taille // 2

    halo2, cadre2 = disque_flou(int(taille * 0.62), (130, 220, 205), 180)
    scene = fond.copy()
    hxy = cadre2 // 2
    scene.alpha_composite(halo2, (cx - hxy, cy - hxy))
    scene.alpha_composite(liseret_pale(taille), (x - 8, y - 8))
    scene.alpha_composite(maitre.resize((taille, taille), Image.LANCZOS), (x, y))
    scene.save(GREETER)
    print(f"greeter -> {GREETER} ({scene.size}, plaque {taille}x{taille} en {x},{y})")


if __name__ == "__main__":
    principal()
