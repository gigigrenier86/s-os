# S

Un système d'exploitation où les logiciels **Windows**, **Linux** et **Android**
tournent ensemble, sur le même bureau, avec le même dossier personnel.

---

## Où en est ce projet

**Nulle part encore, et autant le dire tout de suite.**

Le dépôt vient d'être créé. Aucune image n'a été construite, rien n'a démarré,
aucune machine n'a jamais tourné sous S. Ce qui est écrit ici est un plan qui
compile, pas un système qui marche.

L'état exact, ligne par ligne, est dans [CLAUDE.md](CLAUDE.md) — et il ne se met
à jour qu'avec une mesure, jamais avec une intention.

## Ce que ça fera, quand ça marchera

| Ce que tu lances | Comment ça tourne |
|---|---|
| Un jeu ou un logiciel Windows | **Proton / Wine** — traduction d'API, pas d'émulation, pleine vitesse |
| Une application Android | **Waydroid** — Android sur le noyau de la machine, pas une machine virtuelle |
| Un outil Linux | natif |

Un seul menu. Un seul dossier `Documents`, vu par les trois. Un seul
presse-papiers.

## Ce que ça ne fera jamais

Ces limites ne sont pas des chantiers en retard — ce sont des murs.

- **Les jeux à anti-triche noyau** : Valorant, Fortnite, et les serveurs
  Lineage 2 officiels. L'anti-triche s'installe *dans* le noyau Windows ; il n'y
  en a pas ici. Aucun réglage n'y changera rien.
- **Les applications Android à Play Integrity** : banques, certaines applis
  d'entreprise. Elles vérifient qu'elles tournent sur un Android certifié Google.
- **Les logiciels qui pilotent du matériel par un pilote Windows.** Wine traduit
  des appels de programme, pas des pilotes.

## Installer

Il n'y a rien à installer aujourd'hui. Quand il y aura une image :

```bash
# Depuis une installation Bazzite ordinaire, une seule fois :
sudo bootc switch --enforce-container-sigpolicy=false ghcr.io/<compte>/s-os:latest
sudo systemctl reboot
```

Pas d'ISO à fabriquer : S se pose sur une installation existante et la remplace.
Et `sudo bootc rollback` revient en arrière si une version casse quelque chose.

## Sur quoi c'est bâti

S n'a pas réinventé les moteurs, et ne le prétend pas. Il empile sur
[Bazzite](https://bazzite.gg/), qui apporte Steam, Proton et la recette Waydroid.
Ce que S ajoute, ce sont **les coutures** : faire que les trois mondes se
comportent comme un seul système.
