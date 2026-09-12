#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""iptv.py — playlists et chaines IPTV : lecture, analyse, persistance.

CE QUE CE FICHIER FAIT, ET CE QU'IL NE FAIT PAS. C'est la moitie « donnees »
d'un LECTEUR : il n'heberge, ne fournit ni n'agrege aucune chaine lui-meme.
Chaque playlist vient d'une adresse M3U ou d'identifiants Xtream Codes que
l'UTILISATEUR possede deja — exactement ce que Ibo Player Pro et CAP Player
font deja sous Wine dans le Windows de S (voir windows.sh), sauf que celui-ci
est natif et ne depend d'aucun prefixe.

Xtream Codes n'est pas un second format a analyser : c'est une API qui
EXPOSE une playlist M3U ordinaire sur un chemin fixe (get.php). Un seul
analyseur (parser_m3u) sert donc les deux entrees.
"""

import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request

ETAT = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "s")
FICHIER_PLAYLISTS = os.path.join(ETAT, "iptv-playlists.json")

_AGENT = "S-IPTV/1.0"
_DELAI_S = 20  # une playlist peut porter des dizaines de milliers de lignes


def charger_playlists():
    try:
        with open(FICHIER_PLAYLISTS, "r", encoding="utf-8") as f:
            donnees = json.load(f)
        return donnees if isinstance(donnees, list) else []
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def sauver_playlists(playlists):
    # Ecriture dans un temporaire puis remplacement atomique — le meme
    # principe que noyau.sauver_placees : deux ecritures concurrentes ne
    # peuvent pas corrompre le fichier, au pire l'une des deux est perdue.
    os.makedirs(ETAT, exist_ok=True)
    tmp = FICHIER_PLAYLISTS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(playlists, f, ensure_ascii=False, indent=2)
    os.replace(tmp, FICHIER_PLAYLISTS)


def url_xtream(serveur, port, utilisateur, motdepasse):
    """Construit l'URL M3U que le serveur Xtream Codes expose lui-meme."""
    serveur = (serveur or "").strip().rstrip("/")
    if not re.match(r"^https?://", serveur, re.IGNORECASE):
        serveur = "http://" + serveur
    port = (port or "").strip()
    if port:
        serveur = f"{serveur}:{port}"
    q = urllib.parse.quote
    return (f"{serveur}/get.php?username={q(utilisateur or '')}"
            f"&password={q(motdepasse or '')}&type=m3u_plus&output=ts")


def _decouper_extinf(ligne):
    """« #EXTINF:-1 tvg-id="x" tvg-logo="y" group-title="z",Nom affiche »"""
    attrs = {}
    for cle, val in re.findall(r'([\w-]+)="([^"]*)"', ligne):
        attrs[cle.lower()] = val
    nom = ligne.rsplit(",", 1)[-1].strip() if "," in ligne else ""
    return attrs, nom


def parser_m3u(texte):
    """Rend une liste de {nom, groupe, logo, tvg_id, url}.

    Format ouvert et documente — le meme que VLC, Kodi, Ibo Player Pro et
    CAP Player lisent deja. Aucune ambiguite a lever ici.
    """
    chaines = []
    attrs_courants, nom_courant = None, None
    for brute in texte.splitlines():
        ligne = brute.strip()
        if not ligne or ligne.startswith("#EXTM3U"):
            continue
        if ligne.startswith("#EXTINF"):
            attrs_courants, nom_courant = _decouper_extinf(ligne)
            continue
        if ligne.startswith("#"):
            continue
        # Une ligne qui ne commence pas par « # » est l'URL du flux, qu'un
        # EXTINF l'ait ou non precedee.
        attrs = attrs_courants or {}
        chaines.append({
            "nom": nom_courant or ligne,
            "groupe": attrs.get("group-title", ""),
            "logo": attrs.get("tvg-logo", ""),
            "tvg_id": attrs.get("tvg-id", ""),
            "url": ligne,
        })
        attrs_courants, nom_courant = None, None
    return chaines


def telecharger(url):
    """Rend le texte d'une playlist distante.

    Leve sur echec — c'est a l'appelant de le dire a l'ecran, jamais
    d'inventer une liste vide qui ressemblerait a une vraie playlist deserte.
    """
    requete = urllib.request.Request(url, headers={"User-Agent": _AGENT})
    with urllib.request.urlopen(requete, timeout=_DELAI_S) as reponse:
        brut = reponse.read()
    for encodage in ("utf-8", "latin-1"):
        try:
            return brut.decode(encodage)
        except UnicodeDecodeError:
            continue
    return brut.decode("utf-8", errors="replace")
