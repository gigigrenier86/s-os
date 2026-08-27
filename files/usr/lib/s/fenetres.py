#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""La barre des taches de S — ce que Constellation sait des fenetres ouvertes.

CE QUE CE FICHIER RESOUT. Une barre des taches a besoin de deux choses qu'un
client Wayland n'a pas le droit d'avoir : la liste des fenetres des autres, et
le pouvoir d'en activer une. Releve sur la machine le 2026-08-25, dans les
soixante-dix protocoles annonces par kwin :

    org_kde_plasma_window_management   ABSENT
    zwlr_foreign_toplevel_manager_v1   ABSENT

Les deux qui auraient servi ne sont pas la, et c'est une decision de securite
juste : une application qui enumere les fenetres des autres peut les espionner.

L'INTERFACE QUE KWIN OUVRE VOLONTAIREMENT, ELLE, EST SON MOTEUR DE SCRIPTS. Un
script kwin tourne DANS le compositeur — il sait tout — et « callDBus » lui
permet de le dire au dehors. C'est la porte prevue, pas une porte forcee.

DANS LES DEUX SENS, ET PAR DEUX CHEMINS DIFFERENTS :

  kwin -> S   un script resident (fenetres.js) appelle cet objet a chaque
              fenetre ouverte, fermee, activee, renommee ou reduite.

  S -> kwin   pour activer une fenetre, on ecrit un script d'une ligne qui
              porte l'identifiant, on le charge, on le lance, on le decharge.
              Un script kwin ne peut rien RECEVOIR — pas de service, pas de
              file d'attente, pas meme un fichier a relire. Le seul canal
              entrant est le chargement lui-meme, donc c'est celui qu'on prend.
              Mesure : l'aller-retour complet coute quelques dizaines de
              millisecondes, ce qui est sous le seuil du clic percu.
"""

import json
import os
import time

from PySide6.QtCore import QObject, QTimer, Signal, Slot

import veille

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop


NOM = "org.s.Constellation"
CHEMIN = "/fenetres"

KWIN = ("org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting")

# « loadScript » EXISTE EN DEUX VERSIONS SUR LE BUS — loadScript(s) et
# loadScript(ss) — et dbus-python choisit la premiere qu'il trouve dans
# l'introspection, puis se plaint que Python lui donne deux arguments. On lui
# impose donc la signature. Sans cela, la barre s'ouvre vide et le journal
# parle de « Fewer items found in D-Bus signature », ce qui ne ressemble en
# rien au probleme reel.
RESIDENT = "/usr/lib/s/fenetres.js"


ETAT = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "s")
FICHIER_VUES = os.path.join(ETAT, "fenetres-vues.json")

# CE QU'ON A GELE, ECRIT SUR DISQUE, ET POURQUOI CE N'EST PAS UN LUXE. Un
# Constellation tue net laisse des programmes arretes que plus rien ne
# degele. La premiere version rattrapait cela en balayant app.slice au
# demarrage et en relachant TOUT ce qu'elle y trouvait gele — donc aussi la
# portee d'un banc de mesure en cours, ou un « systemctl --user freeze »
# demande a la main. On ne defait que ce qu'on a fait : cette liste est la
# seule autorisation qu'on se donne.
FICHIER_GELES = os.path.join(ETAT, "fenetres-gelees.json")

def _charger_geles():
    """Les portees que la session precedente avait gelees."""
    try:
        with open(FICHIER_GELES, "r", encoding="utf-8") as f:
            lu = json.load(f)
    except (OSError, ValueError):
        return set()
    if not isinstance(lu, list):
        return set()
    return set(str(x) for x in lu if isinstance(x, str))


def _sauver_geles(portees):
    """Retient la liste tout de suite : un plantage ne previent pas."""
    try:
        os.makedirs(ETAT, exist_ok=True)
        temporaire = FICHIER_GELES + ".tmp"
        with open(temporaire, "w", encoding="utf-8") as f:
            json.dump(sorted(portees), f)
        os.replace(temporaire, FICHIER_GELES)
    except OSError:
        pass


MODES = ("non", "reduire", "geler")
MODE_DEFAUT = "geler"

# LE DELAI ENTRE « range-la » ET « endors-le ». Le gel est immediat et brutal :
# applique dans la milliseconde qui suit la demande de reduction, il fige le
# programme AVANT que kwin ait fini de retirer sa fenetre de l'ecran. On laisse
# donc l'animation se terminer, puis on verifie que la fenetre est toujours
# rangee avant de geler — l'utilisateur a pu changer d'avis entre-temps.
DELAI_GEL = 600

# Un dossier d'etat qui grossit sans fin est un defaut. On oublie une fenetre
# des qu'elle n'existe plus : son identifiant kwin ne reviendra jamais.


def _ident(brut):
    """Reduit un identifiant aux caracteres d'un UUID.

    Il vient de kwin et jamais de l'exterieur, mais il traverse du JavaScript
    interpole. Une chaine qui traverse un langage se borne la ou elle ENTRE,
    pas la ou on espere qu'elle est sure.
    """
    return "".join(c for c in str(brut or "")
                   if c in "0123456789abcdefABCDEF-{}")


def _liste_js(idents):
    """Un tableau JavaScript d'identifiants deja bornes."""
    return "[" + ",".join('"%s"' % _ident(i) for i in idents) + "]"


def _charger_vues():
    try:
        with open(FICHIER_VUES, "r", encoding="utf-8") as f:
            lues = json.load(f)
        if isinstance(lues, dict):
            return {k: v for k, v in lues.items() if isinstance(v, dict)}
    except (OSError, ValueError):
        pass
    return {}


def _lire_mode():
    """Le mode de veille choisi, lu la ou tous les reglages de S vivent."""
    try:
        import noyau
        valeur = str(noyau.charger_reglages().get("veille", MODE_DEFAUT))
    except Exception:
        return MODE_DEFAUT
    return valeur if valeur in MODES else MODE_DEFAUT


class Fenetres(QObject):
    """La liste, telle que QML la lit — et la veille de ce qui n'est pas devant.

    ═══ LA VEILLE, AJOUTEE LE 2026-08-26 A LA DEMANDE DE L'UTILISATEUR ══════

    Sa phrase, mot pour mot : « ce serait bien mieux si la premiere fenetre
    descendait directement en mode veille et que la deuxieme ouvre direct, et
    qu'au nouveau changement la 2ieme passe en veille et vice versa, peu
    importe combien de fenetres — economie d'energie max, seulement un petit
    cache pour ouverture rapide ».

    Trois modes, parce que geler n'est pas sans consequence et qu'un reglage
    qu'on ne peut pas reculer est un piege :

        « non »      rien ne change, l'ancien comportement
        « reduire »  une seule fenetre debout a la fois, les autres se rangent
        « geler »    en plus, leur programme s'ARRETE — defaut

    ON REAGIT AU CHANGEMENT DE FENETRE ACTIVE, PAS AU CLIC SUR LA BARRE. C'est
    la difference entre un correctif et une regle : Alt+Tab, un clic sur une
    fenetre, un programme qui ouvre la sienne au demarrage — tous passent par
    « windowActivated », que le rapporteur nous renvoie deja. Brancher la
    veille sur le clic de la barre l'aurait laissee muette dans les trois
    autres cas, et l'utilisateur aurait vu une regle qui ne s'applique qu'une
    fois sur quatre.

    LE « PETIT CACHE POUR OUVERTURE RAPIDE » N'EST PAS A ECRIRE : c'est ce que
    le gel EST. Un programme gele garde sa memoire, ses fichiers ouverts, ses
    connexions et sa fenetre deja dessinee. Degeler, c'est une ecriture d'un
    octet — il repart a l'instruction suivante, sans rien recharger. Ecrire un
    cache par-dessus serait recopier ce que le noyau tient deja.

    CE QUE LE GEL COUTE, ET IL FAUT LE DIRE. Un programme arrete ne fait plus
    RIEN : pas de musique, pas de telechargement, pas de compilation, pas de
    message recu. C'est le sens de « economie d'energie max », et c'est aussi
    la raison du mode « reduire », pour le jour ou une de ces choses comptera
    plus que la batterie.
    """

    changees = Signal(str)
    modeChange = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._liste = []
        self._bus = None
        self._compteur = 0
        self._mode = _lire_mode()
        self._actif = None
        self._repli = None
        self._geles = set()
        self._toutes = []
        self._vues = _charger_vues()
        self._ecrit = 0.0
        # LE RESTE D'UNE SESSION TUEE NET, ET RIEN D'AUTRE. Un plantage
        # laisserait des programmes figes que plus rien ne degele. On relache
        # donc ce que la session precedente avait ECRIT avoir gele — pas ce
        # qu'on trouve gele dans app.slice, qui ne nous appartient pas.
        for portee in sorted(_charger_geles()):
            veille.degeler(portee)
        _sauver_geles(())

    # ---- Parler a kwin ---------------------------------------------------
    def _script(self, corps, prefixe):
        """Charge un script d'une passe dans kwin, le lance, le decharge.

        Les trois gestes etaient recopies a chaque usage. Ils sont ici une
        fois : un canal entrant qui n'existe qu'au chargement (voir l'en-tete)
        merite au moins de n'etre ecrit qu'une seule fois.
        """
        if self._bus is None:
            return False
        chemin = os.path.join(
            os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "s-%s.js" % prefixe)
        try:
            with open(chemin, "w", encoding="utf-8") as sortie:
                sortie.write(corps)
        except OSError:
            return False
        self._compteur += 1
        nom = "s-%s-%d" % (prefixe, self._compteur)
        try:
            objet = self._bus.get_object(*KWIN[:2])
            face = dbus.Interface(objet, KWIN[2])
            face.loadScript(chemin, nom, signature="ss")
            face.start()
            face.unloadScript(nom)
            return True
        except dbus.DBusException:
            # kwin peut etre en train de se reconfigurer. Une fenetre non
            # activee n'est pas une panne ; un bureau qui tombe pour ca en
            # serait une.
            return False

    # ---- Ce que la scene demande -----------------------------------------
    @Slot(result="QVariant")
    def liste(self):
        return self._liste

    @Slot(result=str)
    def mode(self):
        return self._mode

    @Slot(str, result=str)
    def reglerMode(self, valeur):
        """Change le mode de veille et le retient. Rend une phrase a afficher."""
        valeur = str(valeur)
        if valeur not in MODES:
            return "mode de veille inconnu : %s" % valeur
        self._mode = valeur
        try:
            import noyau
            noyau.sauver_reglage("veille", valeur)
        except Exception:
            pass
        # ON DEGELE DES QU'ON QUITTE « geler », PAS SEULEMENT POUR « non ».
        # Choisir « ranger les autres » se fait precisement pour que les
        # programmes CONTINUENT de tourner : ne relacher qu'a « non »
        # laisserait arretes pour toujours ceux qui l'etaient deja, et
        # retournerait en silence la raison meme du choix.
        if valeur != "geler":
            self._tout_degeler()
        self.modeChange.emit(valeur)
        return {"non": "Veille des fenetres desactivee",
                "reduire": "Une seule fenetre debout a la fois",
                "geler": "Veille : les fenetres rangees s'arretent"}[valeur]

    @Slot(str, bool)
    def activer(self, ident, deja_active=False):
        """Met la fenetre au premier plan, ou la reduit si elle y etait deja.

        C'est le comportement d'une barre des taches, et il n'est pas
        decoratif : sans le repli, cliquer sur la fenetre courante ne ferait
        rien du tout et l'utilisateur croirait le clic perdu.

        L'INTENTION VIENT DE LA BARRE, ELLE N'EST PLUS DEVINEE ICI. La premiere
        version lisait « workspace.activeWindow » au moment ou le script kwin
        tournait — c'est-a-dire APRES le clic, qui a pu deplacer le focus. Le
        premier clic reactivait alors la fenetre sans rien changer a l'oeil, et
        il en fallait deux pour la reduire. Mesure de l'utilisateur, pas
        supposition : « je dois cliquer plusieurs fois avant qu'elle descende ».
        La barre, elle, sait ce qu'elle vient d'afficher.

        UN REPLI DEMANDE A LA MAIN SUSPEND LA VEILLE D'UNE PASSE. Ranger la
        fenetre du dessus fait remonter la suivante — c'est kwin qui choisit,
        pas nous. Sans cette exception, la regle « une seule debout » se
        declencherait sur cette remontee et rangerait tout le reste : le geste
        « ecarte-moi ca » deviendrait « ferme-moi tout ». On laisse donc kwin
        faire ce qu'il fait d'habitude, une fois.
        """
        propre = _ident(ident)
        if not propre:
            return
        if not deja_active:
            self._reveiller(propre)
        parti = self._script(
            'var reduire = %s;\n'
            'var l = workspace.windowList();\n'
            'for (var i = 0; i < l.length; i++) {\n'
            '    if (String(l[i].internalId) === "%s") {\n'
            '        if (reduire && !l[i].minimized) {\n'
            '            l[i].minimized = true;\n'
            '        } else {\n'
            '            l[i].minimized = false;\n'
            '            workspace.activeWindow = l[i];\n'
            '        }\n'
            '        break;\n'
            '    }\n'
            '}\n' % ("true" if deja_active else "false", propre),
            "activer")
        # LE JETON NE SE POSE QUE SI LE GESTE EST PARTI. « _script » rend Faux
        # quand le bus manque ou que l'ecriture echoue : un rangement qui n'a
        # jamais eu lieu mangerait quand meme la veille suivante, et la regle
        # « une seule debout » aurait l'air de ne marcher qu'une fois sur deux.
        if deja_active and parti:
            self._repli = propre

    @Slot(str)
    def fermer(self, ident):
        """Ferme une fenetre — le geste qui manquait au clic droit.

        ON DEGELE AVANT DE FERMER, ET C'EST OBLIGATOIRE. « closeWindow » envoie
        une DEMANDE au programme : le compositeur ne detruit pas la fenetre, il
        prie son proprietaire de le faire. Un programme gele ne recoit rien et
        ne repond rien — la fenetre resterait a l'ecran, et le geste aurait
        l'air casse alors qu'il a parfaitement fonctionne.
        """
        propre = _ident(ident)
        if not propre:
            return
        self._reveiller(propre)
        # FERMER FAIT REMONTER LA SUIVANTE, exactement comme ranger. Sans le
        # jeton, « ferme-moi celle-la » rangerait et endormirait tout le reste
        # du bureau au passage. Voir activer().
        parti = self._script(
            'var cible = "%s";\n'
            'var l = workspace.windowList();\n'
            'for (var i = 0; i < l.length; i++) {\n'
            '    if (String(l[i].internalId) === cible) {\n'
            '        l[i].closeWindow();\n'
            '        break;\n'
            '    }\n'
            '}\n' % propre,
            "fermer")
        if parti:
            self._repli = propre

    @Slot(str)
    def endormir(self, ident):
        """Range une fenetre et arrete son programme tout de suite.

        C'EST UN GESTE A LA MAIN, DONC IL SUSPEND LA VEILLE D'UNE PASSE. Ranger
        cette fenetre-la fait remonter la suivante, et la regle « une seule
        debout » se declencherait sur cette remontee : « endors-moi celle-la »
        deviendrait « endors-moi tout le bureau ». Meme exception que dans
        activer(), pour la meme raison.
        """
        propre = _ident(ident)
        if not propre:
            return
        if self._ranger([propre]):
            self._repli = propre
        QTimer.singleShot(DELAI_GEL, lambda: self._geler([propre]))

    # ---- Les fenetres oubliees -------------------------------------------
    def _inactives(self, jours):
        """Les identifiants qu'on n'a pas actives depuis « jours » jours.

        LE COMPTE PART DE LA PREMIERE FOIS QU'ON A VU LA FENETRE, jamais de
        zero. Une fenetre ouverte il y a une minute n'a pas dix jours
        d'inactivite parce que Constellation vient de demarrer : elle n'a
        qu'une minute d'histoire, et on ne ferme pas ce dont on ne sait rien.
        C'est _noter() qui le garantit, en amorcant « actif » a l'instant du
        premier reperage — il n'y a pas d'autre champ a lire ici.
        """
        limite = time.time() - max(1, int(jours)) * 86400.0
        vieilles = []
        for f in self._liste:
            ident = f.get("id")
            vue = self._vues.get(ident)
            if not vue:
                continue
            if float(vue.get("actif", 0)) < limite:
                vieilles.append(ident)
        return vieilles

    @Slot(int, result=int)
    def inactivesDepuis(self, jours):
        """Combien de fenetres l'option fermerait. Sert a ecrire le menu.

        Un article qui promet « fermer les fenetres inactives » sans dire
        COMBIEN demande a l'utilisateur de cliquer pour savoir ce qu'il va
        detruire. Le compte est dans l'etiquette, et l'article se grise a zero.
        """
        return len(self._inactives(jours))

    @Slot(int, result=str)
    def fermerInactives(self, jours):
        """Ferme tout ce qui dort depuis « jours ». Rend une phrase a afficher."""
        vieilles = self._inactives(jours)
        if not vieilles:
            return ("Aucune fenetre inactive depuis %d jour%s"
                    % (int(jours), "s" if int(jours) > 1 else ""))
        for ident in vieilles:
            self._reveiller(ident)
        self._script(
            'var cibles = %s;\n'
            'var l = workspace.windowList();\n'
            'for (var i = 0; i < l.length; i++) {\n'
            '    if (cibles.indexOf(String(l[i].internalId)) < 0) continue;\n'
            '    l[i].closeWindow();\n'
            '}\n' % _liste_js(vieilles),
            "fermer-vieilles")
        # LE PLURIEL SE CALCULE UNE FOIS, ET « jours » EN FAIT PARTIE. Il
        # etait ecrit trois fois pour les fenetres et fige au pluriel pour les
        # jours : « 1 fenetre fermee — inactive depuis 1 jours ».
        s = "s" if len(vieilles) > 1 else ""
        j = "s" if int(jours) > 1 else ""
        return ("%d fenetre%s fermee%s — inactive%s depuis %d jour%s"
                % (len(vieilles), s, s, s, int(jours), j))

    @Slot()
    def activerBureau(self):
        """Ramene Constellation devant.

        Le menu Demarrer est dessine dans la fenetre du bureau, qui reste
        DERRIERE les autres — c'est ce qu'on attend d'un bureau. Ouvrir le menu
        depuis la barre sans remonter le bureau afficherait donc un menu
        invisible, et le bouton aurait l'air casse.
        """
        self._script(
            'var l = workspace.windowList();\n'
            'for (var i = 0; i < l.length; i++) {\n'
            '    if (String(l[i].resourceClass) === "s-constellation" &&\n'
            '        l[i].fullScreen) {\n'
            '        l[i].minimized = false;\n'
            '        workspace.activeWindow = l[i];\n'
            '        break;\n'
            '    }\n'
            '}\n',
            "bureau")

    # ---- La veille --------------------------------------------------------
    def _portee(self, fenetre):
        return veille.portee(fenetre.get("pid") or 0)

    def _ranger(self, idents):
        if not idents:
            return False
        return self._script(
            'var cibles = %s;\n'
            'var l = workspace.windowList();\n'
            'for (var i = 0; i < l.length; i++) {\n'
            '    if (cibles.indexOf(String(l[i].internalId)) < 0) continue;\n'
            '    if (l[i].minimized) continue;\n'
            '    l[i].minimized = true;\n'
            '}\n' % _liste_js(idents),
            "ranger")

    def _reveiller(self, ident):
        """Degele le programme d'une fenetre avant qu'on la montre.

        AVANT, ET PAS APRES. Une fenetre qu'on remonte doit se redessiner ; un
        programme gele ne redessine rien. Degeler apres l'avoir montree
        laisserait a l'ecran, le temps d'un aller-retour, une fenetre figee sur
        sa derniere image.
        """
        for f in (self._toutes or self._liste):
            if f.get("id") != ident:
                continue
            portee = self._portee(f)
            if portee:
                veille.degeler(portee)
                if portee in self._geles:
                    self._geles.discard(portee)
                    _sauver_geles(self._geles)
            return

    def _geler(self, idents):
        """Arrete les programmes de ces fenetres, si elles sont toujours rangees.

        ON REVERIFIE, PARCE QUE SIX CENTS MILLISECONDES SONT LONGUES. Entre la
        demande de rangement et le gel, l'utilisateur a pu remonter la fenetre.
        La geler alors la figerait sous ses yeux, au premier plan.
        """
        if self._mode != "geler":
            return
        # LA GARDE REGARDE TOUTES LES FENETRES DE KWIN, PAS CELLES DE LA BARRE.
        # Elle ne lisait que « self._liste », d'ou sont deja retirees les
        # fenetres que la barre ne montre pas : mini-lecteur, panneau
        # utilitaire, surface au type inhabituel. Un programme dont la fenetre
        # principale est rangee mais qui garde une de ces surfaces A L'ECRAN
        # partage pourtant sa portee cgroup : le gel figeait la surface visible
        # en pleine image, et comme _reveiller ne connait que les fenetres de
        # la barre, aucun clic ne pouvait plus la degeler.
        vivantes = set()
        for f in (self._toutes or self._liste):
            if f.get("active") or not f.get("reduite"):
                portee = self._portee(f)
                if portee:
                    vivantes.add(portee)
        for f in self._liste:
            if f.get("id") not in idents:
                continue
            if f.get("active") or not f.get("reduite"):
                continue
            portee = self._portee(f)
            # UNE PORTEE PARTAGEE NE SE GELE PAS. Deux fenetres du meme
            # programme vivent dans la meme portee cgroup : geler celle qui est
            # rangee arreterait aussi celle qu'on regarde.
            if not portee or portee in vivantes:
                continue
            if veille.geler(portee):
                self._geles.add(portee)
                _sauver_geles(self._geles)

    def _tout_degeler(self):
        for portee in list(self._geles):
            veille.degeler(portee)
        self._geles.clear()
        _sauver_geles(self._geles)

    def _veiller(self, liste):
        """La regle : une seule fenetre debout, les autres au repos.

        LE JETON SE CONSOMME AVANT TOUTE AUTRE SORTIE, et l'ordre n'est pas
        cosmetique. Il etait lu apres le test du mode : un repli demande a la
        main pendant que la veille etait coupee posait un jeton que plus rien
        ne venait prendre. Il attendait la, et c'est le premier Alt+Tab REEL
        d'apres le retour a « geler » qu'il avalait — la regle « une seule
        debout » avait alors l'air de ne marcher qu'une fois sur deux, des
        heures apres la cause.
        """
        actif = next((f for f in liste if f.get("active")), None)
        ident = actif.get("id") if actif else None
        if ident == self._actif:
            return
        self._actif = ident
        repli, self._repli = self._repli, None
        if self._mode == "non" or repli:
            return
        if not ident:
            return
        portee = self._portee(actif)
        if portee:
            veille.degeler(portee)
            if portee in self._geles:
                self._geles.discard(portee)
                _sauver_geles(self._geles)
        autres = [f.get("id") for f in liste
                  if f.get("id") != ident and not f.get("reduite")]
        self._ranger(autres)
        if self._mode == "geler":
            tous = [f.get("id") for f in liste if f.get("id") != ident]
            QTimer.singleShot(DELAI_GEL, lambda: self._geler(set(tous)))

    # ---- Ce que kwin raconte ---------------------------------------------
    def _noter(self, liste):
        """Retient quand chaque fenetre a ete vue et activee pour la derniere fois.

        LES IDENTIFIANTS SURVIVENT A CONSTELLATION, PAS A KWIN. « internalId »
        appartient au compositeur : il tient tant que la fenetre existe, donc a
        travers un redemarrage du bureau. C'est ce qui rend « inactive depuis
        dix jours » mesurable au lieu d'etre remis a zero chaque soir.
        """
        maintenant = time.time()
        presents = set()
        change = False
        for f in liste:
            ident = f.get("id")
            if not ident:
                continue
            presents.add(ident)
            vue = self._vues.get(ident)
            if vue is None:
                # AMORCE A « MAINTENANT », ET C'EST TOUTE L'ASTUCE. Une fenetre
                # qu'on decouvre n'a pas dix jours d'inactivite parce que
                # Constellation vient de demarrer : elle n'a que l'age de notre
                # connaissance d'elle. Il y avait ici un second champ « vu »
                # pour dire cela — personne ne le relisait jamais, l'amorce
                # d'« actif » le disait deja.
                self._vues[ident] = {"actif": maintenant}
                change = True
                continue
            if f.get("active"):
                vue["actif"] = maintenant
                change = True
        # Une fenetre fermee ne revient jamais sous le meme identifiant.
        for ident in [i for i in self._vues if i not in presents]:
            del self._vues[ident]
            change = True
        if change and maintenant - self._ecrit > 60.0:
            self._ecrit = maintenant
            self._sauver_vues()

    def _sauver_vues(self):
        try:
            os.makedirs(ETAT, exist_ok=True)
            temporaire = FICHIER_VUES + ".tmp"
            with open(temporaire, "w", encoding="utf-8") as f:
                json.dump(self._vues, f)
            os.replace(temporaire, FICHIER_VUES)
        except OSError:
            pass

    def recevoir(self, texte):
        try:
            liste = json.loads(texte)
        except (ValueError, TypeError):
            return
        if not isinstance(liste, list):
            return
        # KWIN ENVOIE DESORMAIS TOUT, ET ON TRIE ICI. La veille a besoin des
        # fenetres que la barre ne montre pas — elles partagent la portee
        # cgroup de celles qu'elle montre, voir la garde de _geler(). La barre,
        # elle, n'a rien a faire d'un panneau utilitaire ou d'une infobulle :
        # elle ne recoit que « montrable ». Un rapporteur d'avant ce changement
        # n'envoie pas le champ ; son absence vaut donc « montrable ».
        self._toutes = liste
        self._liste = [f for f in liste if f.get("montrable", True)]
        self._noter(self._liste)
        self._veiller(self._liste)
        self.changees.emit(json.dumps(self._liste))

    def arreter(self):
        """A l'extinction : on relache tout, et on retient ce qu'on a vu.

        Un programme gele que plus personne ne degele est une fenetre morte
        sans explication. Le balayage du demarrage rattrape les plantages ;
        celui-ci rattrape les arrets propres, qui sont la regle.
        """
        self._tout_degeler()
        self._sauver_vues()


class Service(dbus.service.Object):
    def __init__(self, fenetres, nom_bus):
        super().__init__(nom_bus, CHEMIN)
        self._fenetres = fenetres

    @dbus.service.method(NOM, in_signature="s", out_signature="")
    def Fenetres(self, liste_json):
        self._fenetres.recevoir(liste_json)


def publier(parent=None, script=RESIDENT):
    """Prend le nom, charge le rapporteur dans kwin, et rend l'objet.

    Rend (fenetres, None) ou (None, phrase). Comme pour les notifications, un
    echec ici ne doit pas empecher le bureau de s'ouvrir : une barre sans
    fenetres reste une barre, et les etoiles marchent toujours.
    """
    DBusGMainLoop(set_as_default=True)
    try:
        bus = dbus.SessionBus()
    except dbus.DBusException as err:
        return None, "pas de bus de session (%s)" % err

    try:
        nom_bus = dbus.service.BusName(NOM, bus, do_not_queue=True)
    except dbus.exceptions.NameExistsException:
        return None, "%s est deja possede par un autre programme" % NOM
    except dbus.DBusException as err:
        return None, "le nom %s n'a pas pu etre pris (%s)" % (NOM, err)

    fenetres = Fenetres(parent)
    fenetres._bus = bus
    fenetres._service = Service(fenetres, nom_bus)
    fenetres._nom_bus = nom_bus

    if not os.path.isfile(script):
        return fenetres, "le rapporteur %s est absent — barre sans fenetres" % script

    # LE RAPPORTEUR SE DECHARGE AVANT DE SE CHARGER. Une session rouverte sans
    # que kwin ait redemarre garderait sinon deux exemplaires branches sur les
    # memes signaux, et chaque fenetre ouverte serait annoncee deux fois.
    try:
        objet = bus.get_object(*KWIN[:2])
        face = dbus.Interface(objet, KWIN[2])
        try:
            face.unloadScript("s-fenetres")
        except dbus.DBusException:
            pass
        face.loadScript(script, "s-fenetres", signature="ss")
        face.start()
    except dbus.DBusException as err:
        return fenetres, "kwin n'a pas charge le rapporteur (%s)" % err

    return fenetres, None
