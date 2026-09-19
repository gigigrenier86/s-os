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
_MAX_OCTETS = 256 * 1024 * 1024


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
    # 0600 : l'URL d'une playlist Xtream porte « username= » et « password= »
    # en clair. Avec le masque par defaut le fichier naissait en 0644.
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
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


def _premiere_virgule_hors_guillemets(ligne):
    """Position de la premiere virgule qui n'est pas dans une valeur entre
    guillemets, ou -1."""
    entre = False
    for i, c in enumerate(ligne):
        if c == '"':
            entre = not entre
        elif c == "," and not entre:
            return i
    return -1


def _decouper_extinf(ligne):
    """« #EXTINF:-1 tvg-id="x" tvg-logo="y" group-title="z",Nom affiche »

    LE NOM COMMENCE APRES LA PREMIERE VIRGULE HORS GUILLEMETS, PAS APRES LA
    DERNIERE. La version d'avant coupait sur la derniere virgule de la ligne
    (« rsplit(",", 1) ») : un nom qui en contient une — « Sky Sports 1, HD »,
    « Arte, FR », courants dans les listes publiques — devenait « HD » ou « FR ».
    Mesure du 2026-09-18 sur quatre lignes de test. Les virgules DANS une valeur
    d'attribut (group-title="News, World") ne separent rien non plus, d'ou le
    suivi des guillemets.
    """
    attrs = {}
    for cle, val in re.findall(r'([\w-]+)="([^"]*)"', ligne):
        attrs[cle.lower()] = val
    i = _premiere_virgule_hors_guillemets(ligne)
    nom = ligne[i + 1:].strip() if i >= 0 else ""
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
        # « timeout » ne borne que l'attente de chaque lecture, jamais le volume :
        # une adresse qui deverse des gigaoctets remplirait la memoire. Une
        # playlist de plusieurs centaines de milliers de chaines tient sous ce
        # plafond, un flux video pris pour une playlist n'y tient pas.
        brut = reponse.read(_MAX_OCTETS + 1)
    if len(brut) > _MAX_OCTETS:
        raise ValueError("cette adresse ne ressemble pas a une playlist "
                         "(plus de %d Mio)" % (_MAX_OCTETS // (1024 * 1024)))
    for encodage in ("utf-8", "latin-1"):
        try:
            return brut.decode(encodage)
        except UnicodeDecodeError:
            continue
    return brut.decode("utf-8", errors="replace")
