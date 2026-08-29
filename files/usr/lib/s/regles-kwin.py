#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Les regles kwin dont S a besoin pour poser ses deux fenetres de service.

POURQUOI DES REGLES, ET PAS DES COORDONNEES DANS LE QML. Un client Wayland ne
se place pas lui-meme : le protocole ne le permet pas, et le compositeur
decide. Mesure du 2026-08-25 : une fenetre demandant x=1516 y=24 s'est affichee
AU CENTRE de l'ecran. Ce n'est pas un defaut de Qt.

POURQUOI DANS ~/.config ET NON DANS L'IMAGE, ce qui contredit en apparence la
regle « ce qui doit tenir va dans l'image ». KConfig cascade : le fichier de
l'utilisateur l'emporte sur celui de /etc/xdg. Or « [General] rules= » existe
deja ici, vide, et kwin ne lit QUE les groupes nommes dans cette liste. Une
regle livree dans l'image serait donc masquee par une ligne vide du dossier
personnel.

LE CONTOURNEMENT EST DONC DANS L'AUTRE SENS : le code qui pose les regles, lui,
vit dans l'image. Il tourne a chaque ouverture de session, il se repare tout
seul si quelqu'un efface le fichier, et il n'ecrase jamais les regles que
l'utilisateur aurait ajoutees.

ET IL EST APPELE PAR CONSTELLATION, PAS PAR LA COQUILLE, parce que les deux
regles ont besoin de la taille de l'ecran — que seul un programme connecte au
compositeur connait. La deviner en lisant kscreen-doctor serait une seconde
source de verite pour une chose que Qt sait deja.
"""

import configparser
import io
import os
import subprocess
import sys


# Les titres sont des CLEFS, pas des decorations : la barre, la bulle et le
# bureau appartiennent tous a s-constellation et portent donc la meme classe.
# Le titre est le seul moyen de les distinguer, et il doit correspondre mot
# pour mot au « title: » de Bulle.qml et de Barre.qml.
TITRE_BULLE = "S - notification"
TITRE_BARRE = "S - barre"
TITRE_LATERALE = "S - barre laterale"

# LA SEULE FENETRE ANDROID QU'ON TRAITE A PART. Les fenetres d'applis (classe
# « waydroid.<paquet> ») affichent deja leur vrai nom (YouTube, Gmail...) et
# le gardent. Mais la fenetre systeme generique -- clavier virtuel, popups --
# porte litteralement la classe « Waydroid » (majuscule, sans point) : c'est
# la seule fuite de marque visible, mesuree le 2026-08-28 par une capture
# d'ecran reelle. Son sort : plus bas dans `regles()`, sous
# "s-android-systeme".

LARGEUR_BULLE = 380
MARGE_BULLE = 24
HAUTEUR_BARRE = 52
# LA FENETRE DE LA BARRE EST PLUS HAUTE QUE LA BARRE, ET LA REGLE DOIT POSER LA
# FENETRE. Le menu du clic droit est un Popup borne a sa fenetre : il lui faut
# de la place au-dessus de la bande visible. Donner au menu sa propre fenetre
# ne marche pas — mesure du 2026-08-27, il se pose tout a gauche de l'ecran,
# parce qu'un client Wayland ne se positionne pas lui-meme. La fenetre monte
# donc, et son masque ne laisse sensible que la bande du bas.
# CE NOMBRE DOIT VALOIR « hauteur + placeMenu » DE Barre.qml. Deux fichiers qui
# doivent rester d'accord finissent par diverger, d'ou ce rappel.
HAUTEUR_FENETRE_BARRE = HAUTEUR_BARRE + 420
# LA LARGEUR EST CELLE DU PANNEAU DEPLOYE, ET LA FENETRE LA GARDE TOUJOURS.
# Elle ne bouge donc jamais : c'est sa zone SENSIBLE qui retrecit quand elle est
# repliee, pas sa geometrie. Un client Wayland ne se positionne pas lui-meme
# (mesure du 2026-08-25, une fenetre demandant x=1516 s'est affichee au centre) ;
# une languette qui grandirait devrait etre replacee a chaque ouverture, et on
# la verrait sauter.
# ELLE DOIT VALOIR « largeur » DE BarreLaterale.qml, PAS « largeurBarre ». La
# fenetre est plus large que la colonne visible : le nom d'un reglage s'ecrit a
# gauche de celle-ci, dans le reste de la fenetre. Deux fichiers qui doivent
# rester d'accord finissent par diverger — ce depot le repete depuis
# « s-partage » — d'ou ce rappel plutot qu'un simple nombre.
LARGEUR_LATERALE = 300

# LE RAPPORT QUI DECIDE DE LA MISE EN PAGE D'ANDROID, ET IL N'EST PAS COSMETIQUE.
#
# AOSP classe un ecran dont le rapport long/court atteint 1,75 comme « long » —
# c'est-a-dire un telephone en paysage. Une application Android sert alors sa
# mise en page telephone : UNE colonne, large de tout l'ecran. Mesure a l'ecran
# le 2026-08-26 sur l'accueil de YouTube :
#
#   1920 x 1028  ->  1,868  ->  xlarge-long-     ->  une colonne
#   1700 x 1028  ->  1,654  ->  xlarge-notlong-  ->  trois colonnes
#
# On vise 1,70 et non 1,74 : le seuil d'AOSP est un flottant, et on ne se pose
# pas a un centieme d'une bascule qu'on ne controle pas.
#
# CETTE FONCTION EST LA SOURCE UNIQUE. s-android l'appelle pour dimensionner la
# fenetre (persist.waydroid.width/height) et « regles » l'appelle pour la
# centrer. Deux formules qui doivent rester d'accord finiraient par diverger —
# ce depot l'a paye assez souvent pour ne pas recommencer.
RAPPORT_ANDROID = 170  # en centiemes


def taille_android(largeur, hauteur):
    """La taille de la fenetre Android pour cet ecran. Rend (largeur, hauteur)."""
    utile = max(1, hauteur - HAUTEUR_BARRE)
    return min(largeur, utile * RAPPORT_ANDROID // 100), utile

COMMUN = {
    "skiptaskbar": "true",
    "skiptaskbarrule": "2",
    "skippager": "true",
    "skippagerrule": "2",
    "skipswitcher": "true",
    "skipswitcherrule": "2",
    "above": "true",
    "aboverule": "2",
    "positionrule": "2",
    "types": "1",
    "wmclass": "s-constellation",
    "wmclasscomplete": "false",
    "wmclassmatch": "1",
    "titlematch": "1",
}


def fichier_regles():
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(base, "kwinrulesrc")


def regles(largeur, hauteur):
    """Les deux groupes, calcules pour cet ecran-ci."""
    bulle = dict(COMMUN)
    bulle.update({
        "Description": "S - la bulle de notification, en haut a droite",
        "title": TITRE_BULLE,
        "position": "%d,%d" % (max(0, largeur - LARGEUR_BULLE - MARGE_BULLE),
                               MARGE_BULLE),
    })

    barre = dict(COMMUN)
    barre.update({
        "Description": "S - la barre des taches, en bas",
        "title": TITRE_BARRE,
        "position": "0,%d" % max(0, hauteur - HAUTEUR_FENETRE_BARRE),
        # LA TAILLE EST FORCEE, ET C'EST NECESSAIRE : la barre demande la
        # largeur de l'ecran, mais kwin peut la retailler a l'ouverture si une
        # autre regle ou un souvenir de geometrie traine. Une barre des taches
        # de 800 pixels de large collee a gauche a l'air d'un bogue.
        "size": "%d,%d" % (largeur, HAUTEUR_FENETRE_BARRE),
        "sizerule": "2",
    })
    laterale = dict(COMMUN)
    laterale.update({
        "Description": "S - la barre laterale, au bord droit",
        "title": TITRE_LATERALE,
        "position": "%d,0" % max(0, largeur - LARGEUR_LATERALE),
        # LA TAILLE EST FORCEE POUR LA MEME RAISON QUE CELLE DE LA BARRE : la
        # fenetre demande toute la hauteur de l'ecran, et un souvenir de
        # geometrie suffirait a la rendre plus courte — une ligne qui s'arrete
        # au milieu du bord droit n'a plus l'air d'une poignee, mais d'un
        # defaut d'affichage.
        "size": "%d,%d" % (LARGEUR_LATERALE, hauteur),
        "sizerule": "2",
    })

    # LES FENETRES ANDROID, COLLEES EN HAUT.
    #
    # MESURE DU 2026-08-26 : kwin posait la fenetre de YouTube en 110,26 —
    # 1700x1028 a partir de y=26, donc un bas a 1054 alors que la barre de S
    # commence a 1028. L'utilisateur perdait vingt-six pixels du bas, c'est-a-
    # dire exactement la rangee de commandes de l'application.
    #
    # On force la POSITION seulement, jamais la taille : celle-ci est decidee
    # par le compositeur de Waydroid, a qui s-android l'a donnee. Forcer les
    # deux ferait dependre l'affichage de deux autorites au lieu d'une.
    #
    # « waydroid. » en sous-chaine attrape toutes les applications d'un coup :
    # leur classe est « waydroid.<paquet> ». Et cette regle n'herite PAS de
    # COMMUN — une application Android est une fenetre ordinaire, qui doit
    # rester dans la barre des taches et sous les fenetres de service de S.
    larg_android, _ = taille_android(largeur, hauteur)
    android = {
        "Description": "S - les fenetres Android, collees en haut",
        "wmclass": "waydroid.",
        "wmclasscomplete": "false",
        # « 2 » ET PAS « 1 » — ET LA DIFFERENCE M'A COUTE DEUX ESSAIS.
        # kwin numerote ses modes de comparaison ainsi :
        #     0 = sans importance   1 = EXACT   2 = SOUS-CHAINE   3 = regexp
        # COMMUN emploie « 1 » et a raison : « s-constellation » est une classe
        # entiere. Le copier ici cherchait une fenetre dont la classe vaut
        # EXACTEMENT « waydroid. », ce qui n'existe pas — la regle etait donc
        # posee, lue par kwin, et ne matchait rien. Mesure : la fenetre restait
        # a y=26 apres reconfigure, ouverture neuve comprise.
        "wmclassmatch": "2",
        "position": "%d,0" % max(0, (largeur - larg_android) // 2),
        "positionrule": "2",
        "types": "1",
    }

    # LA FENETRE SYSTEME GENERIQUE D'ANDROID (clavier, popups) -- classe
    # EXACTEMENT « Waydroid », jamais « waydroid.<quelquechose> ». D'ou
    # wmclassmatch=1 (exact) et non 2 (sous-chaine) : la regle "s-android"
    # ci-dessus deja capte la sous-chaine "waydroid." en minuscules, celle-ci
    # ne doit surtout pas la recouper.
    #
    # PAS DE FORCE SUR LE TITRE -- ESSAYE ET ABANDONNE LE 2026-08-28. Un
    # conteneur relance a froid, regle deja posee avant la creation de la
    # fenetre : le titre restait « Waydroid » quand meme, et forcer
    # `caption` depuis un script kwin (contournement direct) n'a rien fait
    # non plus -- la propriete est en lecture seule. KWin sait FILTRER sur un
    # titre, jamais le REECRIRE : ce n'est pas une capacite qu'il offre.
    #
    # LA VRAIE REPONSE : Mike ne veut pas d'un nom different, il veut « un
    # simple outil inexistant » -- rien a renommer, une fenetre qui ne se
    # presente nulle part comme une chose a part. skiptaskbar/skipswitcher/
    # skippager en Force (memes cles que COMMUN) la retirent de la barre des
    # taches, d'Alt-Tab et du selecteur : son titre interne reste
    # « Waydroid », mais plus aucun endroit ou Mike le croiserait ne
    # l'affiche.
    android_systeme = {
        "Description": "S - la fenetre systeme d'Android, invisible comme outil",
        "wmclass": "Waydroid",
        "wmclasscomplete": "false",
        "wmclassmatch": "1",
        "skiptaskbar": "true",
        "skiptaskbarrule": "2",
        "skippager": "true",
        "skippagerrule": "2",
        "skipswitcher": "true",
        "skipswitcherrule": "2",
    }

    return {"s-bulle": bulle, "s-barre": barre, "s-laterale": laterale,
            "s-android": android, "s-android-systeme": android_systeme}


def poser(largeur, hauteur):
    """Ecrit les regles si elles manquent ou ont change. Rend (change, ennui)."""
    chemin = fichier_regles()
    lecteur = configparser.ConfigParser(interpolation=None, strict=False)
    # KConfig distingue les majuscules ; configparser les ecrase par defaut.
    lecteur.optionxform = str
    if os.path.isfile(chemin):
        try:
            lecteur.read(chemin, encoding="utf-8")
        except configparser.Error as err:
            # ON NE REECRIT PAS UN FICHIER QU'ON NE SAIT PAS LIRE. Perdre les
            # regles de l'utilisateur pour poser les notres serait un mauvais
            # marche.
            return False, "kwinrulesrc illisible (%s) — regles non posees" % err

    if not lecteur.has_section("General"):
        lecteur.add_section("General")
    liste = [n for n in lecteur.get("General", "rules", fallback="").split(",")
             if n]

    voulues = regles(largeur, hauteur)
    change = False
    for groupe, contenu in voulues.items():
        deja = (groupe in liste
                and lecteur.has_section(groupe)
                and all(lecteur.get(groupe, c, fallback=None) == v
                        for c, v in contenu.items()))
        if deja:
            continue
        change = True
        if groupe not in liste:
            liste.append(groupe)
        if not lecteur.has_section(groupe):
            lecteur.add_section(groupe)
        for clef, valeur in contenu.items():
            lecteur.set(groupe, clef, valeur)

    if not change:
        return False, None

    lecteur.set("General", "rules", ",".join(liste))
    lecteur.set("General", "count", str(len(liste)))

    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    tampon = io.StringIO()
    lecteur.write(tampon, space_around_delimiters=False)
    # Ecriture puis remplacement : une session qui se ferme au mauvais moment
    # ne doit pas laisser un fichier de regles a moitie ecrit.
    provisoire = chemin + ".s-nouveau"
    with io.open(provisoire, "w", encoding="utf-8") as sortie:
        sortie.write(tampon.getvalue())
    os.replace(provisoire, chemin)
    return True, None


def relire():
    """Demande a kwin de relire ses regles, sans redemarrer la session."""
    try:
        subprocess.run(
            ["busctl", "--user", "call", "org.kde.KWin", "/KWin",
             "org.kde.KWin", "reconfigure"],
            timeout=10, check=False,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        # kwin n'est pas encore la : il lira le fichier en demarrant, ce qui
        # est le cas normal a l'ouverture de session.
        pass


def appliquer(largeur, hauteur):
    """Pose et fait relire. Rend une phrase a journaliser, ou None."""
    change, ennui = poser(largeur, hauteur)
    if ennui:
        return ennui
    if change:
        relire()
        return "regles kwin posees pour un ecran de %dx%d" % (largeur, hauteur)
    return None


if __name__ == "__main__":
    # En ligne de commande, on prend la taille en arguments : c'est le seul
    # moyen d'essayer ce fichier sans ouvrir une session.
    l = int(sys.argv[1]) if len(sys.argv) > 1 else 1920
    h = int(sys.argv[2]) if len(sys.argv) > 2 else 1080
    phrase = appliquer(l, h)
    if phrase:
        print("regles-kwin : " + phrase, file=sys.stderr)
