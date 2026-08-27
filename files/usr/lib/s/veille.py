#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""La veille des fenetres — endormir le programme dont la fenetre est rangee.

CE QUE CE FICHIER RESOUT. Reduire une fenetre ne coute rien au programme : il
continue de tourner, de dessiner, de reveiller le processeur. Un navigateur
range depuis trois heures anime toujours ses onglets. « Economie d'energie
max », demandee par l'utilisateur le 2026-08-26, veut dire autre chose : que le
programme s'ARRETE tant qu'on ne le regarde pas, et reparte instantanement.

LE MECANISME EXISTE DANS LE NOYAU ET NE DEMANDE PAS LE MOT DE PASSE. cgroup v2
porte un fichier « cgroup.freeze » sur chaque noeud. Ecrire 1 gele tous les
processus de la branche, ecrire 0 les relache. Mesure du 2026-08-26 sur cette
machine :

    /sys/fs/cgroup/.../app.slice/app-code-3359.scope/cgroup.freeze
    -rw-r--r--. 1 RyuRex RyuRex

Le fichier appartient a l'utilisateur. C'est la delegation cgroup de systemd —
« user@1000.service » recoit son sous-arbre — et c'est ce qui rend ce reglage
possible depuis Constellation, qui ne peut rien demander a polkit sans ecran.

BANC D'ESSAI DU 2026-08-26, SUR UNE PORTEE JETABLE :

    systemd-run --user --scope --unit=s-essai-gel -- sleep 300
    echo 1 > .../s-essai-gel.scope/cgroup.freeze
    cgroup.freeze -> 1      cgroup.events -> « frozen 1 »
    echo 0 > ...            cgroup.freeze -> 0

PREMIER PIEGE, MESURE AU MEME MOMENT : /proc/PID/stat continue d'annoncer
l'etat « S » pendant le gel. Un processus gele n'est pas en « D » ni en « T » —
le noyau le pose dans un piege de controle de tache qui ne change pas la
lettre. Verifier le gel en lisant /proc rendrait « ca n'a pas marche » sur un
gel parfaitement applique.

SECOND PIEGE, ET IL A FAIT ECHOUER LE BANC AVANT D'ETRE COMPRIS. Les deux
fichiers ne disent pas la meme chose, et ils ne repondent pas au meme moment :

    cgroup.freeze    LA DEMANDE — vaut 1 des que l'ecriture est rendue
    cgroup.events    L'ETAT      — « frozen 1 » quand les taches sont arretees

Releve du 2026-08-26, trois lectures d'affilee sur la meme portee, dans cet
ordre : cgroup.events dit « frozen 0 », cgroup.freeze dit « 1 », puis
cgroup.events relu dit « frozen 1 ». Le decalage tient dans une fraction de
milliseconde — le temps qu'une tache atteigne un point ou elle peut s'arreter —
mais il suffit a faire rendre FAUX a un controle ecrit juste apres la demande.

CONSEQUENCE SUR CE FICHIER : « gelee » lit l'ETAT et sert a observer ; le
balayage de rattrapage, lui, lit la DEMANDE. Une tache bloquee dans un appel
systeme non interruptible pourrait garder « frozen 0 » indefiniment alors que
la demande vaut 1 — s'en remettre a l'etat laisserait ce programme fige pour
toujours, ce que ce balayage existe precisement pour empecher.

═══ CE QU'ON REFUSE DE GELER, ET POURQUOI LA REGLE EST COURTE ═══════════════

On ne gele QUE les portees « app-*.scope » posees directement sous
« app.slice ». Rien d'autre. Cette seule phrase protege tout le reste, et ce
n'est pas une precaution theorique — c'est le releve de la machine :

    s-constellation   session-2.scope        pas sous app.slice  -> refuse
    kwin_wayland      session-2.scope        pas sous app.slice  -> refuse
    plasmashell       session-2.scope        pas sous app.slice  -> refuse
    Xwayland          session-2.scope        pas sous app.slice  -> refuse
    waydroid          system.slice/...       hors du sous-arbre  -> refuse
    wineserver        app.slice/s-windows.service   .service     -> refuse
    portails, kdeconnect, mpris-proxy        .service            -> refuse
    code, vivaldi     app.slice/app-*.scope                      -> ACCEPTE

Les quatre pieces du bureau vivent dans la portee de SESSION, jamais dans
app.slice : geler le compositeur figerait l'ecran entier sans que rien puisse
le degeler, puisque le degel viendrait d'un clic. C'est la panne qu'on ne peut
pas se permettre sur une machine pilotee a distance.

LA DISTINCTION « .scope » CONTRE « .service » N'EST PAS COSMETIQUE. app.slice
contient les deux : les portees sont les programmes que l'utilisateur a lances,
les services sont l'infrastructure de sa session. Parmi eux, s-windows.service
porte le WINESERVER — le geler figerait d'un coup tous les programmes Windows
de la machine, y compris ceux dont la fenetre est au premier plan.

ON REMONTE JUSQU'A LA PORTEE, ON NE GELE PAS LA FEUILLE. Mesure du
2026-08-26 : Konsole se range dans

    app.slice/app-org.kde.konsole-28261.scope/main.scope

— un enfant. Le « cgroup.procs » de la portee elle-meme est VIDE, et un code
qui lirait le cgroup du processus pour le geler tel quel gelerait « main.scope »
en laissant le reste de l'application dehors. Le gel de cgroup v2 est
hierarchique : on vise la portee, et toute la branche s'arrete avec elle.
"""

import os


RACINE = "/sys/fs/cgroup"


def _chemin_cgroup(pid):
    """La ligne « 0:: » de /proc/PID/cgroup, ou None."""
    try:
        with open("/proc/%d/cgroup" % int(pid), "r", encoding="utf-8") as f:
            for ligne in f:
                if ligne.startswith("0::"):
                    return ligne[3:].strip()
    except (OSError, ValueError, TypeError):
        pass
    return None


def portee(pid):
    """La portee « app-*.scope » qui contient ce processus, ou None.

    Rend un chemin absolu sous /sys/fs/cgroup. None veut dire « ce processus
    n'est pas un programme lance par l'utilisateur » — et donc qu'on n'y
    touche pas.
    """
    # « int » PEUT LEVER, ET LE PID VIENT DE KWIN. Il arrive en JSON depuis
    # decrire() : une version du compositeur ou un type de fenetre rendant une
    # chaine ou un flottant faisait remonter le ValueError a travers _geler et
    # _veiller jusque hors de la methode D-Bus — la liste des fenetres cessait
    # de se mettre a jour et la barre se figeait sur son dernier etat. Le
    # contrat de l'en-tete est pourtant simple : ce qu'on ne sait pas lire vaut
    # « on ne sait pas », donc « on n'y touche pas ».
    if not pid:
        return None
    try:
        if int(pid) <= 1:
            return None
    except (TypeError, ValueError):
        return None
    relatif = _chemin_cgroup(pid)
    if not relatif:
        return None
    morceaux = [m for m in relatif.split("/") if m]
    try:
        i = morceaux.index("app.slice")
    except ValueError:
        return None
    if i + 1 >= len(morceaux):
        return None
    feuille = morceaux[i + 1]
    if not feuille.startswith("app-") or not feuille.endswith(".scope"):
        return None
    chemin = os.path.join(RACINE, *morceaux[:i + 2])
    if not os.path.isfile(os.path.join(chemin, "cgroup.freeze")):
        return None
    return chemin


# NOTRE PROPRE PORTEE, CALCULEE UNE FOIS. La regle ci-dessus la rend deja
# introuvable — Constellation tourne dans la portee de session — mais si un
# jour la coquille le lancait autrement, ce garde-fou tiendrait encore. Un
# bureau qui se gele lui-meme ne peut plus se degeler.
_NOTRE_PORTEE = portee(os.getpid())


def _ecrire(chemin, valeur):
    try:
        with open(os.path.join(chemin, "cgroup.freeze"), "w",
                  encoding="utf-8") as f:
            f.write(valeur)
        return True
    except OSError:
        # Une portee peut disparaitre entre le moment ou on la lit et celui ou
        # on ecrit : le programme vient de se fermer. Ce n'est pas une panne.
        return False


def geler(chemin):
    if not chemin or chemin == _NOTRE_PORTEE:
        return False
    return _ecrire(chemin, "1")


def degeler(chemin):
    if not chemin:
        return False
    return _ecrire(chemin, "0")


def gel_demande(chemin):
    """Vrai si le gel a ete DEMANDE sur cette branche.

    C'est la lecture qui ne ment jamais par retard : le fichier vaut 1 des que
    l'ecriture est rendue. Voir l'en-tete pour la difference avec « gelee ».
    """
    if not chemin:
        return False
    try:
        with open(os.path.join(chemin, "cgroup.freeze"), "r",
                  encoding="utf-8") as f:
            return f.read().strip() == "1"
    except OSError:
        return False


def gelee(chemin):
    """Vrai si les taches de la branche sont EFFECTIVEMENT arretees.

    Lit cgroup.events, pas /proc — et pas cgroup.freeze. Voir l'en-tete : les
    trois repondent des choses differentes, et deux d'entre elles ne repondent
    pas au meme moment. Celle-ci retarde de moins d'une milliseconde sur la
    demande ; un controle ecrit juste apres l'ecriture peut donc la lire fausse
    alors que le gel est en cours.
    """
    if not chemin:
        return False
    try:
        with open(os.path.join(chemin, "cgroup.events"), "r",
                  encoding="utf-8") as f:
            for ligne in f:
                if ligne.startswith("frozen "):
                    return ligne.split()[1] == "1"
    except OSError:
        pass
    return False


def app_slice():
    """Le chemin de app.slice de cette session, ou None."""
    chemin = os.path.join(
        RACINE, "user.slice", "user-%d.slice" % os.getuid(),
        "user@%d.service" % os.getuid(), "app.slice")
    return chemin if os.path.isdir(chemin) else None


def portees_gelees():
    """Toutes les portees d'application actuellement gelees.

    POURQUOI CE BALAYAGE EXISTE : LE TROU QUE atexit NE BOUCHE PAS. Constellation
    degele ce qu'il a gele en s'arretant proprement. Tue net — SIGKILL, plantage,
    fin de session brutale — il ne degele rien, et les programmes resteraient
    figes SANS QUE RIEN A L'ECRAN NE DISE POURQUOI. L'utilisateur verrait des
    fenetres mortes et n'aurait aucune raison de soupconner un fichier de cgroup.

    Constellation appelle donc ceci a son demarrage et relache tout. Le balayage
    est sur parce que RIEN D'AUTRE sur cette machine n'ecrit dans ces fichiers :
    une portee gelee qu'on trouve au demarrage est forcement un reste de nous.
    """
    base = app_slice()
    if not base:
        return []
    trouvees = []
    try:
        for nom in os.listdir(base):
            if not nom.startswith("app-") or not nom.endswith(".scope"):
                continue
            chemin = os.path.join(base, nom)
            # LA DEMANDE, PAS L'ETAT. Voir l'en-tete : une tache coincee dans
            # un appel systeme non interruptible garde « frozen 0 » alors que
            # le gel est demande. Balayer sur l'etat la laisserait derriere.
            if gel_demande(chemin):
                trouvees.append(chemin)
    except OSError:
        pass
    return trouvees
