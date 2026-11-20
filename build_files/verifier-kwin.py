#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Mesurer, dans un vrai kwin, ou finissent les fenetres quand le chrome est la.

POURQUOI CE CONTROLE EXISTE. Le 2026-11-19, l'assistant d'installation de
Flyff avait ses boutons sous la barre : la barre ne reservait aucune place, donc
toute fenetre maximisee ou haute finissait a y=1080, 52 px sous elle. Aucun
verificateur de la construction ne pouvait le voir — verifier-chrome.py charge
la scene sans compositeur, banc-fenetres.js joue un kwin de CARTON. Une faute de
GEOMETRIE ne se voit que dans un compositeur, et sans ce banc elle ne se voit
qu'au premier assistant cache, chez l'utilisateur.

CE QUE FAIT LE BANC. Sur un bus prive et des dossiers jetables (rien n'atteint
la session de qui le lance) :
  1. un kwin_wayland --virtual de 1920x1080 ;
  2. le VRAI fenetres.js charge dedans, comme le fait la coquille ;
  3. le VRAI s-chrome, avec ses vrais ponts et son integration layer-shell —
     donc la vraie barre, avec sa vraie zone reservee ;
  4. trois fenetres de test ordinaires : une petite, une maximisee, une haute
     et non redimensionnable (le profil d'un assistant d'installation) ;
  5. un script kwin qui releve les geometries et les rend par D-Bus (un script
     kwin ne rend rien a l'appelant : on se sert du bus comme temoin, meme
     patron que grimoire/kwin-capturer-la-coquille.sh).

CE QU'IL EXIGE.
  - la zone maximisable de kwin s'arrete a 1028 (1080 moins les 52 px de la
     barre) : c'est la zone RESERVEE, mesuree sans rattrapage de fenetres.js ;
  - les trois fenetres de test finissent a 1028, pas a 1080 (sous la barre) ni
     a 976 (une bande vide au-dessus : la zone retranchee deux fois) ;
  - la barre elle-meme n'est pas repoussee par sa propre zone : son bas reste
     a 1080.

ECHEC, SAUT, SUCCES. Code 0 : mesure faite et bonne. Code 1 : mesure faite et
mauvaise, ou s-chrome meurt sous Wayland. Code 77 : kwin virtuel indisponible
ici (pas de kwin, pas de bus de session, le compositeur ne demarre pas) — rien
n'a ete mesure, et le script le DIT : un controle qui se tait quand il ne peut
pas tourner est le succes silencieux que ce depot refuse.

CHEMIN. Sans argument, il verifie l'image INSTALLEE (/usr) — juste PENDANT la
construction, faux a la main. Lance depuis le depot : « verifier-kwin.py files »
verifie le depot qu'on vient de modifier.

CONTROLES NEGATIFS (un banc qui ne sait pas dire non ne mesure rien) :
  --sans-zone            retire la zone reservee de Barre.qml -> doit ECHOUER ;
  --fenetres-js FICHIER  charge un autre fenetres.js (l'ancien) -> doit ECHOUER.

CE QU'IL NE PROUVE PAS. Un kwin virtuel logiciel n'est pas la session de la
machine : ni GPU, ni vraie souris, ni vrais menus de la barre. La fenetre reelle
d'un installateur Wine n'est pas rejouee — seul son profil l'est.
"""

import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

LARGEUR, HAUTEUR = 1920, 1080
HAUTEUR_BARRE = 52
BAS_ATTENDU = HAUTEUR - HAUTEUR_BARRE          # 1028
SOCKET = "s-kwin"
SKIP = 77

# Le client de test : une fenetre ordinaire, SANS l'integration layer-shell
# (le piege du 2026-11-19 : un client qui la herite devient une surface de
# couche plein ecran au lieu d'une fenetre).
QML = {
    "T-normale": 'import QtQuick\nWindow { visible: true; width: 700; height: 500;'
                 ' title: "T-normale"; color: "#ffffff" }',
    "T-maxi": 'import QtQuick\nWindow { visible: true; visibility: Window.Maximized;'
              ' title: "T-maxi"; color: "#ffeeee" }',
    "T-installateur": 'import QtQuick\nWindow { visible: true; width: 1000; height: 1040;'
                      ' minimumWidth: 1000; maximumWidth: 1000;'
                      ' minimumHeight: 1040; maximumHeight: 1040;'
                      ' title: "T-installateur"; color: "#eeffee" }',
}

LANCEUR = """
import sys
from PySide6.QtCore import QByteArray, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
app = QGuiApplication(sys.argv)
e = QQmlApplicationEngine()
e.loadData(QByteArray(sys.argv[1].encode()), QUrl("file:///banc.qml"))
sys.exit(app.exec() if e.rootObjects() else 3)
"""

RELEVE = """
var liste = workspace.windowList();
for (var i = 0; i < liste.length; i++) {
    var f = liste[i];
    var g = f.frameGeometry;
    var m = workspace.clientArea(KWin.MaximizeArea, f);
    callDBus("org.s.temoin", "/temoin", "org.s.temoin", "w",
        [String(f.resourceClass), String(f.caption),
         Math.round(g.x), Math.round(g.y), Math.round(g.width), Math.round(g.height),
         f.layer, f.maximizeMode, Math.round(m.y + m.height)].join("~"));
}
"""


def dire(texte):
    # Le rapport va dans un fichier : le bus prive lance de lui-meme le portail
    # XDG et le coffre, qui bavardent sur la meme sortie. L'exterieur n'imprime
    # que le rapport — et le bavardage seulement si la mesure a echoue.
    rapport = os.environ.get("S_KWIN_RAPPORT")
    if rapport:
        with open(rapport, "a", encoding="utf-8") as fh:
            fh.write(texte + "\n")
    else:
        print(texte, flush=True)


def arguments():
    racine, sans_zone, fen_js = None, False, None
    a = sys.argv[1:]
    i = 0
    while i < len(a):
        if a[i] == "--interne":
            pass
        elif a[i] == "--sans-zone":
            sans_zone = True
        elif a[i] == "--fenetres-js":
            i += 1
            fen_js = a[i]
        elif racine is None:
            racine = a[i]
        i += 1
    return os.path.abspath(racine or "/"), sans_zone, fen_js


def chemins(racine, fen_js):
    def r(*p):
        return os.path.join(racine, *p)
    return {
        "chrome": r("usr", "bin", "s-chrome"),
        "constellation": r("usr", "bin", "s-constellation"),
        "lib": r("usr", "lib", "s"),
        "qml": r("usr", "share", "s", "constellation", "qml"),
        "fenetres_js": os.path.abspath(fen_js) if fen_js else r("usr", "lib", "s", "fenetres.js"),
    }


# --------------------------------------------------------------------------
# Le processus EXTERIEUR : prepare un bus prive et des dossiers jetables, lance
# la partie interne dessous, puis nettoie — y compris les services que le bus
# a actives tout seuls (portail, coffre) et que dbus-run-session laisse vivre.

def tuer_les_restes(rt):
    """Tue, par PID exact, tout processus dont XDG_RUNTIME_DIR est le notre."""
    moi = os.getpid()
    for nom in os.listdir("/proc"):
        if not nom.isdigit() or int(nom) == moi:
            continue
        try:
            with open("/proc/%s/environ" % nom, "rb") as fh:
                env = fh.read().split(b"\0")
        except OSError:
            continue
        if ("XDG_RUNTIME_DIR=%s" % rt).encode() in env:
            try:
                os.kill(int(nom), signal.SIGKILL)
            except OSError:
                pass


def exterieur():
    for outil in ("kwin_wayland", "dbus-run-session", "busctl", "dbus-monitor"):
        if not shutil.which(outil):
            dire("  kwin           : banc SAUTE (%s introuvable ici)" % outil)
            return SKIP
    rt = tempfile.mkdtemp(prefix="s-kwin-rt-")
    cfg = tempfile.mkdtemp(prefix="s-kwin-cfg-")
    os.chmod(rt, 0o700)
    env = {k: v for k, v in os.environ.items()
           if k not in ("QT_WAYLAND_SHELL_INTEGRATION", "WAYLAND_DISPLAY", "DISPLAY",
                        "QT_QPA_PLATFORM", "DBUS_SESSION_BUS_ADDRESS", "XDG_SESSION_TYPE")}
    for d in ("c", "d", "k", "h", "s"):
        os.makedirs(os.path.join(cfg, d), exist_ok=True)
    rapport = os.path.join(cfg, "rapport.txt")
    env.update(XDG_RUNTIME_DIR=rt, XDG_CONFIG_HOME=cfg + "/c", XDG_DATA_HOME=cfg + "/d",
               XDG_CACHE_HOME=cfg + "/k", XDG_STATE_HOME=cfg + "/s", HOME=cfg + "/h",
               QML_DISK_CACHE="none", S_KWIN_RAPPORT=rapport)
    code, brut = 1, ""
    try:
        r = subprocess.run(
            ["dbus-run-session", "--", sys.executable, os.path.abspath(__file__),
             "--interne"] + sys.argv[1:],
            env=env, timeout=240, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, errors="replace")
        code, brut = r.returncode, r.stdout
    except subprocess.TimeoutExpired:
        dire("ECHEC : le banc kwin n'a pas fini en 240 s.")
        code = 1
    finally:
        # Les services que le bus a actives tout seul (portail, coffre) survivent
        # a dbus-run-session : on les tue ICI, apres lui, par PID exact — jamais
        # dans la partie interieure, qui tuerait aussi son propre parent.
        tuer_les_restes(rt)
        try:
            with open(rapport, encoding="utf-8") as fh:
                print(fh.read(), end="", flush=True)
        except OSError:
            pass
        shutil.rmtree(rt, ignore_errors=True)
        shutil.rmtree(cfg, ignore_errors=True)
    # Le bavardage du bus prive (portail, coffre, moniteur) n'apprend rien : on
    # ne montre que ce qui reste, et seulement si la mesure a echoue.
    bruit = ("dbus-daemon[", "(/usr/libexec/xdg-desktop-portal", "(xdg-desktop-portal")
    utile = [l for l in brut.splitlines() if l.strip() and not l.startswith(bruit)]
    if code not in (0, SKIP) and utile:
        dire("  --- sortie brute utile (derniere partie) ---")
        for ligne in utile[-25:]:
            dire("  | " + ligne[:200])
    return code


# --------------------------------------------------------------------------
# La partie INTERIEURE : tourne sous le bus prive.

def busctl(*args):
    return subprocess.run(["busctl", "--user"] + list(args), capture_output=True,
                          text=True, timeout=20)


def attendre_kwin(proc, journal, delai=30):
    fin = time.time() + delai
    sock = os.path.join(os.environ["XDG_RUNTIME_DIR"], SOCKET)
    while time.time() < fin:
        if proc.poll() is not None:
            return False
        if os.path.exists(sock) and busctl("introspect", "org.kde.KWin", "/Scripting").returncode == 0:
            return True
        time.sleep(0.5)
    return False


def charger_script(chemin, nom):
    r = busctl("call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting",
               "loadScript", "ss", chemin, nom)
    m = re.match(r"i\s+(-?\d+)", r.stdout.strip())
    if r.returncode != 0 or not m or int(m.group(1)) < 0:
        return False
    return busctl("call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting",
                  "start").returncode == 0


def decharger_script(nom):
    busctl("call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting",
           "unloadScript", "s", nom)


def releve(dossier):
    """Un tour de releve : [(classe, titre, x, y, w, h, couche, max, zone_bas)]."""
    sortie = os.path.join(dossier, "temoin.txt")
    with open(sortie, "w") as fh:
        mon = subprocess.Popen(["dbus-monitor", "--session", "interface='org.s.temoin'"],
                               stdout=fh, stderr=subprocess.STDOUT)
    try:
        time.sleep(0.8)
        charger_script(os.path.join(dossier, "releve.js"), "s-releve")
        time.sleep(1.5)
    finally:
        mon.terminate()
        try:
            mon.wait(3)
        except subprocess.TimeoutExpired:
            mon.kill()
        decharger_script("s-releve")
    fenetres = []
    with open(sortie, errors="replace") as fh:
        lignes = fh.read().splitlines()
    for i, ligne in enumerate(lignes):
        if "member=w" in ligne and i + 1 < len(lignes):
            m = re.match(r'^\s*string "(.*)"$', lignes[i + 1])
            if m:
                champs = m.group(1).split("~")
                if len(champs) == 9:
                    try:
                        fenetres.append(tuple(champs[:2]) + tuple(int(c) for c in champs[2:]))
                    except ValueError:
                        pass
    return fenetres


def interieur():
    racine, sans_zone, fen_js = arguments()
    p = chemins(racine, fen_js)
    for cle in ("chrome", "constellation", "fenetres_js"):
        if not os.path.isfile(p[cle]):
            dire("ECHEC : %s est absent (%s)." % (cle, p[cle]))
            return 1
    dire("  banc kwin sur : %s%s" % (racine, "  [SANS ZONE]" if sans_zone else ""))
    dire("  fenetres.js    : %s" % p["fenetres_js"])

    dossier = tempfile.mkdtemp(prefix="s-kwin-banc-")
    enfants = []
    try:
        # Les copies de travail : s-chrome fixe ses chemins en dur (/usr/...),
        # on lui en pose donc une copie qui pointe sur la racine verifiee —
        # l'original reste intact, c'est lui que la construction livre.
        qml = p["qml"]
        if sans_zone:
            qml = os.path.join(dossier, "qml")
            shutil.copytree(p["qml"], qml)
            barre = os.path.join(qml, "Barre.qml")
            src = open(barre, encoding="utf-8").read()
            neuf = re.sub(r"^[ \t]*LayerShell\.Window\.exclusionZone:[ \t]*barre\.hauteur[ \t]*\n",
                          "", src, flags=re.M)
            if neuf == src:
                dire("ECHEC : --sans-zone n'a rien retire de Barre.qml (la ligne a bouge ?).")
                return 1
            open(barre, "w", encoding="utf-8").write(neuf)
        chrome = open(p["chrome"], encoding="utf-8").read()
        chrome = chrome.replace('"/usr/bin/s-constellation"', repr(p["constellation"]))
        chrome = chrome.replace('_LIB = "/usr/lib/s"', "_LIB = %r" % p["lib"])
        chrome = chrome.replace('_QML = "/usr/share/s/constellation/qml"', "_QML = %r" % qml)
        chrome_copie = os.path.join(dossier, "s-chrome")
        open(chrome_copie, "w", encoding="utf-8").write(chrome)
        open(os.path.join(dossier, "releve.js"), "w").write(RELEVE)
        open(os.path.join(dossier, "lanceur.py"), "w").write(LANCEUR)

        # 1. kwin — UNE COPIE DU BINAIRE, PAS LUI. kwin_wayland porte la
        # capacite de fichier cap_sys_nice=ep (priorite temps reel) ; dans un
        # conteneur sans privileges — la construction en est un — le noyau
        # refuse alors l'execution : « Operation not permitted », mesure le
        # 2026-11-19 dans fedora:45 avec le /usr de S. Une copie perd les
        # attributs etendus, donc la capacite, dont un banc virtuel n'a que
        # faire. Les bibliotheques et greffons se trouvent par leurs chemins
        # compiles, pas par celui du binaire.
        journal = open(os.path.join(dossier, "kwin.log"), "w")
        try:
            kwin_bin = os.path.join(dossier, "kwin_wayland")
            shutil.copy(shutil.which("kwin_wayland"), kwin_bin)
            kwin = subprocess.Popen(
                [kwin_bin, "--virtual", "--width", str(LARGEUR), "--height", str(HAUTEUR),
                 "--socket", SOCKET, "--no-lockscreen"], stdout=journal, stderr=subprocess.STDOUT)
        except OSError as erreur:
            dire("  kwin           : banc SAUTE — kwin_wayland ne se lance pas ici (%s)" % erreur)
            return SKIP
        enfants.append(kwin)
        if not attendre_kwin(kwin, journal):
            journal.flush()
            queue = open(os.path.join(dossier, "kwin.log"), errors="replace").read()[-600:]
            dire("  kwin           : banc SAUTE — le compositeur virtuel ne demarre pas ici")
            dire("    " + queue.replace("\n", "\n    "))
            return SKIP
        time.sleep(1.5)

        # 2. le vrai rapporteur
        if not charger_script(p["fenetres_js"], "s-fenetres"):
            dire("ECHEC : kwin refuse de charger fenetres.js (%s)." % p["fenetres_js"])
            return 1

        # 3. le vrai chrome, integration layer-shell comprise
        env_w = dict(os.environ, WAYLAND_DISPLAY=SOCKET, QT_QPA_PLATFORM="wayland",
                     S_NOYAU=p["lib"], S_QML=qml)
        env_w.pop("QT_WAYLAND_SHELL_INTEGRATION", None)
        chrome_log = open(os.path.join(dossier, "chrome.log"), "w")
        proc_chrome = subprocess.Popen([sys.executable, chrome_copie], env=env_w,
                                       stdout=chrome_log, stderr=subprocess.STDOUT)
        enfants.append(proc_chrome)
        time.sleep(6)
        if proc_chrome.poll() is not None:
            chrome_log.flush()
            dire("ECHEC : s-chrome s'est arrete sous Wayland (code %s)." % proc_chrome.returncode)
            dire("    " + open(os.path.join(dossier, "chrome.log"), errors="replace")
                 .read()[-800:].replace("\n", "\n    "))
            return 1

        # 4. les fenetres de test — SANS l'integration, comme tout programme
        # que la barre lance depuis la correction du 2026-11-19.
        env_c = dict(os.environ, WAYLAND_DISPLAY=SOCKET, QT_QPA_PLATFORM="wayland")
        env_c.pop("QT_WAYLAND_SHELL_INTEGRATION", None)
        for nom, source in QML.items():
            enfants.append(subprocess.Popen(
                [sys.executable, os.path.join(dossier, "lanceur.py"), source], env=env_c,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        time.sleep(4)

        # 5. releve, jusqu'a ce que les geometries ne bougent plus
        precedent, courant = None, []
        for _ in range(8):
            courant = releve(dossier)
            cles = sorted((c[1], c[2], c[3], c[4], c[5]) for c in courant)
            if cles and cles == precedent:
                break
            precedent = cles
            time.sleep(1)

        return evaluer(courant)
    finally:
        for e in reversed(enfants):
            try:
                e.terminate()
                e.wait(3)
            except Exception:
                try:
                    e.kill()
                except Exception:
                    pass
        shutil.rmtree(dossier, ignore_errors=True)


def evaluer(fenetres):
    dire("  fenetres relevees (classe | titre | x,y wxh | bas | couche | max | zone-max bas) :")
    for c in sorted(fenetres, key=lambda c: (c[1] == "", c[1])):
        dire("    %s | %r | %d,%d %dx%d | bas=%d | layer=%d | max=%d | zoneMax=%d"
             % (c[0], c[1], c[2], c[3], c[4], c[5], c[3] + c[5], c[6], c[7], c[8]))
    par_titre = {c[1]: c for c in fenetres if c[1]}
    fautes = []
    for nom in QML:
        if nom not in par_titre:
            fautes.append("la fenetre de test %s n'est pas apparue" % nom)
    if "T-maxi" in par_titre:
        zone = par_titre["T-maxi"][8]
        if zone != BAS_ATTENDU:
            fautes.append("la zone maximisable de kwin s'arrete a %d, pas a %d : la barre "
                          "ne reserve pas sa place" % (zone, BAS_ATTENDU))
    for nom in QML:
        if nom in par_titre:
            c = par_titre[nom]
            bas = c[3] + c[5]
            if bas > BAS_ATTENDU:
                fautes.append("%s finit a %d, SOUS la barre (limite %d)" % (nom, bas, BAS_ATTENDU))
            elif bas < BAS_ATTENDU:
                fautes.append("%s finit a %d : une bande vide de %d px au-dessus de la barre "
                              "(zone retranchee deux fois ?)" % (nom, bas, BAS_ATTENDU - bas))
    # La barre : une surface sans titre, pleine largeur, collee en bas. Si sa
    # propre zone la repoussait, son bas ne vaudrait pas 1080.
    barres = [c for c in fenetres if c[1] == "" and c[4] == LARGEUR and c[5] >= HAUTEUR_BARRE
              and c[5] < HAUTEUR // 2]
    if not barres:
        fautes.append("aucune surface de barre (pleine largeur, sans titre) n'est apparue — "
                      "le chrome n'est pas ancre")
    elif not any(c[3] + c[5] == HAUTEUR for c in barres):
        fautes.append("la barre est repoussee : son bas vaut %s, pas %d"
                      % (sorted(c[3] + c[5] for c in barres), HAUTEUR))
    if fautes:
        for f in fautes:
            dire("ECHEC : " + f)
        return 1
    dire("  kwin           : zone reservee a %d, les trois fenetres de test finissent a %d, "
         "la barre reste collee en bas" % (BAS_ATTENDU, BAS_ATTENDU))
    return 0


if __name__ == "__main__":
    sys.exit(interieur() if "--interne" in sys.argv else exterieur())
