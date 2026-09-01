#!/usr/bin/env python3
"""Catalogue unifié de S : « Une application, le meilleur moteur ».

Associe à chaque grand logiciel recherché le moteur d'exécution optimal
(Linux natif, Android ou Windows Proton) selon la meilleure expérience mesurée.
"""

CATALOGUE_UNIFIE = {
    "spotify": {
        "nom": "Spotify",
        "moteur": "linux",
        "action": "flatpak install -y flathub com.spotify.Client",
        "description": "Musique et podcasts en streaming (Linux natif)",
        "ico": "i-musique"
    },
    "discord": {
        "nom": "Discord",
        "moteur": "linux",
        "action": "flatpak install -y flathub com.discordapp.Discord",
        "description": "Messagerie et salon vocal pour joueurs (Linux natif)",
        "ico": "i-bulle"
    },
    "vlc": {
        "nom": "VLC Media Player",
        "moteur": "linux",
        "action": "flatpak install -y flathub org.videolan.VLC",
        "description": "Lecteur multimédia universel (Linux natif)",
        "ico": "i-video"
    },
    "cap player": {
        "nom": "Cap Player",
        "moteur": "android",
        "action": "/usr/bin/s-magasin-android --installer com.cap.player",
        "description": "Lecteur IPTV & VOD optimisé (Android)",
        "ico": "i-video"
    },
    "whatsapp": {
        "nom": "WhatsApp",
        "moteur": "android",
        "action": "/usr/bin/s-magasin-android --installer com.whatsapp",
        "description": "Messagerie instantanée mobile (Android)",
        "ico": "i-bulle"
    },
    "instagram": {
        "nom": "Instagram",
        "moteur": "android",
        "action": "/usr/bin/s-magasin-android --installer com.instagram.android",
        "description": "Partage de photos et vidéos (Android)",
        "ico": "i-image"
    },
    "netflix": {
        "nom": "Netflix",
        "moteur": "linux",
        "action": "s-ouvrir-web https://www.netflix.com",
        "description": "Films et séries en continu (Application Web)",
        "ico": "i-video"
    },
    "lineage 2": {
        "nom": "Lineage II",
        "moteur": "windows",
        "action": "s-ouvrir-exe LineageII.exe",
        "description": "MMORPG classique (Windows / Proton)",
        "ico": "i-manette"
    },
    "lineage ii": {
        "nom": "Lineage II",
        "moteur": "windows",
        "action": "s-ouvrir-exe LineageII.exe",
        "description": "MMORPG classique (Windows / Proton)",
        "ico": "i-manette"
    },
    "obs": {
        "nom": "OBS Studio",
        "moteur": "linux",
        "action": "flatpak install -y flathub com.obsproject.Studio",
        "description": "Enregistrement et diffusion vidéo en direct",
        "ico": "i-video"
    },
    "gimp": {
        "nom": "GIMP",
        "moteur": "linux",
        "action": "flatpak install -y flathub org.gimp.GIMP",
        "description": "Éditeur d'images professionnel",
        "ico": "i-image"
    },
    "youtube": {
        "nom": "YouTube",
        "moteur": "linux",
        "action": "gio open https://www.youtube.com",
        "description": "Vidéos, musique et diffusions en direct (Web)",
        "ico": "i-video"
    },
    "tiktok": {
        "nom": "TikTok",
        "moteur": "android",
        "action": "/usr/bin/s-magasin-android --installer com.zhiliaoapp.musically",
        "description": "Vidéos courtes et créateurs (Android)",
        "ico": "i-video"
    },
    "telegram": {
        "nom": "Telegram",
        "moteur": "linux",
        "action": "flatpak install -y flathub org.telegram.desktop",
        "description": "Messagerie instantanée rapide et sécurisée",
        "ico": "i-bulle"
    }
}


def chercher_catalogue(terme):
    """Recherche dans le catalogue unifié le meilleur moteur pour une application."""
    if not terme:
        return []
    q = terme.lower().strip()
    resultats = []
    for cle, info in CATALOGUE_UNIFIE.items():
        if q in cle or q in info["nom"].lower():
            resultats.append({
                "id": f"catalogue:{cle}",
                "nom": info["nom"],
                "src": info["moteur"],
                "ico": info["ico"],
                "ep": 0,
                "epingle": 0,
                "img": "",
                "txt": info["description"],
                "action": info["action"],
                "compte": 0,
                "catalogue": 1
            })
    return resultats
