#!/usr/bin/python3
# Rend un programme WebView2 (Tauri, wry…) capable de s'ouvrir sous Wine.
#
# LE DEFAUT, MESURE LE 2026-11-03 SUR RECOMPLAUNCHER (Tauri 2, 13 echecs sur 13) :
#
#   le programme sort en « code 5 » (0xC0000005 tronque a un octet) en 4 a 10 s,
#   sans fenetre. WINEDEBUG=+seh donne la pile :
#
#     ole32 (+0x34d7d)   movq (%rax),%rax      <- pointeur invalide
#     recomplauncher     appel de RevokeDragDrop
#     user32             EnumChildWindows
#
#   Au demarrage, wry (le moteur de fenetres de Tauri) parcourt les fenetres
#   FILLES de la vue WebView2 et fait RevokeDragDrop puis RegisterDragDrop sur
#   chacune, pour poser son propre gestionnaire de glisser-deposer. Or ces
#   fenetres vivent dans le processus msedgewebview2.exe, pas dans celui du
#   programme : WebView2 est TOUJOURS hors processus.
#
#   Wine range le pointeur « OleDropTargetInterface » en propriete de fenetre,
#   lisible depuis n'importe quel processus, et RevokeDragDrop appelle Release()
#   dessus SANS verifier a qui appartient la fenetre. Le pointeur est valide
#   chez Chromium, pas chez nous : acces memoire invalide. (Windows refuse
#   l'appel pour une fenetre etrangere ; Wine non.) Meme defaut que le bogue
#   amont WineHQ 60225 (autre application Tauri), non corrige a ce jour dans
#   GE-Proton11-11 / wine-11.0.
#
#   Ca s'appelle une course quand Chromium n'a pas encore enregistre sa cible
#   (Launcher-SOW : un lancement sur trois tient) et un plantage certain quand
#   il l'a deja fait (RecompLauncher).
#
# LE CORRECTIF : rendre RevokeDragDrop sans effet DANS LE PROGRAMME — `xor eax,eax ;
# ret`, soit S_OK. Sans consequence : le programme ne revoque que pour reposer
# la sienne juste apres, et il quitte ensuite avec son processus.
#
# On ne patche pas Wine (/usr est en lecture seule et Proton se redeplie a
# chaque version) ni un decalage fige : l'appel est retrouve par sa SIGNATURE —
# la case « ole32!RevokeDragDrop » de la table d'imports, puis le petit tremplin
# `jmp [case]` que le compilateur genere, ou les `call [case]` directs. Une mise
# a jour du programme qui deplace tout reste couverte.
#
# SUR, ET REVERSIBLE :
#   - ne touche que les executables 64 bits qui importent RevokeDragDrop ET
#     embarquent WebView2 (un programme ordinaire revoque SES fenetres : on n'y
#     touche pas) ;
#   - garde « <programme>.avant-s » a la premiere correction ;
#   - idempotent : relance, il ne trouve plus rien a faire ;
#   - ecrit dans un fichier voisin puis renomme : jamais d'executable a moitie
#     ecrit.
#
# Usage : corriger_webview2.py <programme.exe>
# Sortie : une ligne, sur stdout. Code 0 dans tous les cas « normaux » — ce
# geste ne doit jamais empecher un lancement.
import os
import shutil
import struct
import sys

# Les deux remplacements font 6 octets, comme `jmp [case]` et `call [case]`.
TREMPLIN = bytes.fromhex("31c0c3909090")     # xor eax,eax ; ret ; nop x3
APPEL = bytes.fromhex("31c090909090")        # xor eax,eax ; nop x4


def _sections(d, pe):
    nsec = struct.unpack_from("<H", d, pe + 6)[0]
    opt = struct.unpack_from("<H", d, pe + 20)[0]
    so = pe + 24 + opt
    out = []
    for i in range(nsec):
        _n, vs, va, rs, ro, _r, _l, _nr, _nl, ch = struct.unpack_from("<8sIIIIIIHHI", d, so + 40 * i)
        out.append((va, max(vs, rs), ro, rs, ch))
    return out


def _vers_offset(secs, rva):
    for va, vs, ro, rs, _ch in secs:
        if va <= rva < va + vs and rva - va < rs:
            return ro + rva - va
    return None


def _case_import(d, pe, secs, dll, nom):
    """RVA de la case de la table d'imports pour dll!nom, ou None."""
    imp_rva = struct.unpack_from("<I", d, pe + 24 + 112 + 8)[0]
    o = _vers_offset(secs, imp_rva) if imp_rva else None
    if o is None:
        return None
    while True:
        oft, _ts, _fc, name, ft = struct.unpack_from("<IIIII", d, o)
        if not name:
            return None
        no = _vers_offset(secs, name)
        if no is not None and d[no:no + 64].split(b"\0")[0].decode("latin-1").lower() == dll:
            t = _vers_offset(secs, oft or ft)
            k = 0
            while t is not None:
                v = struct.unpack_from("<Q", d, t + 8 * k)[0]
                if not v:
                    break
                if not v >> 63:
                    vo = _vers_offset(secs, v & 0x7FFFFFFF)
                    if vo is not None and d[vo + 2:vo + 2 + 64].split(b"\0")[0].decode("latin-1") == nom:
                        return ft + 8 * k
                k += 1
        o += 20


def trouver(d):
    """Liste de (decalage_fichier, octets_de_remplacement). Vide si rien a faire."""
    if d[:2] != b"MZ":
        return []
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    if d[pe:pe + 4] != b"PE\0\0" or struct.unpack_from("<H", d, pe + 24)[0] != 0x20B:
        return []                                   # 64 bits seulement
    secs = _sections(d, pe)
    case = _case_import(d, pe, secs, "ole32.dll", "RevokeDragDrop")
    if case is None:
        return []
    patches = []
    for va, vs, ro, rs, ch in secs:
        if not ch & 0x20000000:                     # section de code
            continue
        i = ro
        fin = ro + min(vs, rs) - 6
        while True:
            i = d.find(b"\xff", i, fin)
            if i < 0:
                break
            op = d[i + 1]
            if op in (0x25, 0x15):
                rel = struct.unpack_from("<i", d, i + 2)[0]
                if va + (i - ro) + 6 + rel == case:
                    # tremplin (jmp) : tous ses appelants d'un coup ; appel direct : un par un
                    patches.append((i, TREMPLIN if op == 0x25 else APPEL))
            i += 1
    return patches


def embarque_webview2(chemin, d):
    return b"WebView2Loader" in d or os.path.exists(os.path.join(os.path.dirname(chemin), "WebView2Loader.dll"))


def main(argv):
    if len(argv) != 2:
        print("usage : corriger_webview2.py <programme.exe>")
        return 2
    chemin = argv[1]
    try:
        with open(chemin, "rb") as f:
            d = bytearray(f.read())
    except OSError as e:
        print("illisible : %s" % e)
        return 0
    if b"RevokeDragDrop" not in d or not embarque_webview2(chemin, d):
        print("sans objet")
        return 0
    patches = trouver(bytes(d))
    if not patches:
        print("rien a corriger")
        return 0
    for o, b in patches:
        d[o:o + 6] = b
    sauvegarde = chemin + ".avant-s"
    try:
        if not os.path.exists(sauvegarde):
            shutil.copy2(chemin, sauvegarde)
        tmp = chemin + ".s-tmp"
        with open(tmp, "wb") as f:
            f.write(d)
        shutil.copymode(chemin, tmp)
        os.replace(tmp, chemin)
    except OSError as e:
        print("non ecrit : %s" % e)
        return 0
    print("corrige : %d appel(s) a RevokeDragDrop neutralise(s)" % len(patches))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
