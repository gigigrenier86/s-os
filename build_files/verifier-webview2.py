#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""Le correctif WebView2 corrige ce qu'il doit, et RIEN d'autre.

Un controle qui ne sait pas echouer ne prouve rien : on fabrique ici un PE64
minimal (un tremplin « jmp [RevokeDragDrop] » et son appelant) et on verifie,
dans les deux sens, ce que /usr/lib/s/corriger_webview2.py en fait.

  - le tremplin est neutralise, l'appelant n'est PAS touche ;
  - la sauvegarde « .avant-s » est l'original exact ;
  - relance, il n'y a plus rien a faire (idempotent) ;
  - un programme SANS WebView2 reste intact — un programme ordinaire revoque
    SES fenetres, on ne lui retire pas ce droit ;
  - un executable qui n'importe pas RevokeDragDrop reste intact.

Eprouve le 2026-11-03 en sabotant l'outil : sans son filtre WebView2, le
controle echoue sur « programme sans WebView2 touche » ; avec une detection
aveugle, sur « tremplin non neutralise ».

Usage : verifier-webview2.py <corriger_webview2.py>
"""
import importlib.util, os, struct, sys, tempfile
spec = importlib.util.spec_from_file_location("cw2", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

def faux_pe(avec_webview2=True, avec_import=True):
    # .text a 0x1000 (fichier 0x200), .idata a 0x2000 (fichier 0x400)
    pe = 0x80
    d = bytearray(0x600)
    d[0:2] = b"MZ"; struct.pack_into("<I", d, 0x3C, pe)
    d[pe:pe+4] = b"PE\0\0"
    struct.pack_into("<HHIIIHH", d, pe+4, 0x8664, 2, 0, 0, 0, 0xF0, 0x22)
    o = pe + 24
    struct.pack_into("<H", d, o, 0x20B)
    struct.pack_into("<II", d, o+112+8, 0x2000, 0x40)           # repertoire des imports
    so = o + 0xF0
    struct.pack_into("<8sIIIIIIHHI", d, so, b".text", 0x100, 0x1000, 0x100, 0x200, 0, 0, 0, 0, 0x60000020)
    struct.pack_into("<8sIIIIIIHHI", d, so+40, b".idata", 0x200, 0x2000, 0x200, 0x400, 0, 0, 0, 0, 0xC0000040)
    # .idata : descripteur, noms, tables
    base = 0x400
    nom_dll, nom_fn = 0x2100, 0x2120
    ilt, iat = 0x2140, 0x2160
    struct.pack_into("<IIIII", d, base, ilt, 0, 0, nom_dll, iat)
    a = base+(nom_dll-0x2000); d[a:a+10] = b"ole32.dll\0"
    f = (b"RevokeDragDrop\0" if avec_import else b"AutreFonction\0"); a = base+(nom_fn-0x2000)+2; d[a:a+len(f)] = f
    struct.pack_into("<Q", d, base+(ilt-0x2000), nom_fn)
    struct.pack_into("<Q", d, base+(iat-0x2000), nom_fn)
    # .text : tremplin en 0x1000, appelant en 0x1010
    t = 0x200
    struct.pack_into("<i", d, t+2, iat - (0x1000 + 6)); d[t] = 0xFF; d[t+1] = 0x25
    d[t+0x10] = 0xE8; struct.pack_into("<i", d, t+0x11, 0x1000 - (0x1010 + 5))
    if avec_webview2: d[0x5C0:0x5CE] = b"WebView2Loader"
    return bytes(d)

with tempfile.TemporaryDirectory() as tmp:
    def ecrire(nom, contenu):
        p = os.path.join(tmp, nom); open(p, "wb").write(contenu); return p
    p = ecrire("a.exe", faux_pe())
    avant = open(p, "rb").read()
    assert m.main(["x", p]) == 0
    apres = open(p, "rb").read()
    assert apres[0x200:0x206] == m.TREMPLIN, "tremplin non neutralise"
    assert apres[0x210:0x215] == avant[0x210:0x215], "l'appelant ne doit pas etre touche"
    assert open(p + ".avant-s", "rb").read() == avant, "sauvegarde absente ou alteree"
    assert not m.trouver(apres), "pas idempotent"
    q = ecrire("b.exe", faux_pe(avec_webview2=False)); b = open(q, "rb").read()
    m.main(["x", q]); assert open(q, "rb").read() == b, "programme sans WebView2 touche"
    r = ecrire("c.exe", faux_pe(avec_import=False)); c = open(r, "rb").read()
    m.main(["x", r]); assert open(r, "rb").read() == c, "autre import touche"
print("OK")
