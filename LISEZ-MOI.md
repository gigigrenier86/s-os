# S

Un système d'exploitation où les logiciels **Windows**, **Linux** et **Android**
tournent ensemble, sur le même bureau.

---

## Où en est ce projet — 2026-08-20

**S s'installe, démarre et se met à jour.** Mais uniquement en machine
virtuelle : aucune machine réelle n'a encore démarré dessus.

| | |
|---|---|
| Démarrage | **35 secondes**, zéro service en échec |
| Installation | depuis le registre, en 35 minutes |
| Mise à jour | `bootc upgrade` — 2 couches sur 130 quand seule l'image change |
| Compte utilisateur | créé à l'installation, par l'assistant de KDE |

### Ce qui est posé dans l'image, prêt à servir à la première connexion

Vivaldi · VS Code · Claude Code · Antigravity · Gemini (CLI et web) ·
Node.js · RetroArch et 14 cœurs · Zoom

Plus deux lanceurs en fenêtre dédiée, et l'éditeur qui s'ouvre en français avec
l'extension Claude Code déjà posée. *Posés et vérifiés à leur chemin ; aucun n'a
encore été ouvert pour de bon.*

### Un double-clic suffit, dans les trois mondes

| Tu double-cliques | Ce qui se passe | Éprouvé |
|---|---|---|
| un `.exe` ou un `.msi` | ça s'installe ou ça se lance, et l'icône arrive au menu | oui — un binaire Windows exécuté |
| un `.deb` ou un `.rpm` | ça s'installe, et l'icône arrive au menu | oui — paquet Debian réel, 10,5 s |
| un `.AppImage` | ça se range, et l'icône arrive au menu | associé, jamais exécuté |
| un `.flatpak` | ça s'installe en silence | associé, jamais exécuté |
| un `.apk` | ça s'installe dans Android | Waydroid n'a jamais tourné |

**Aucun programme tiers ne s'ouvre pour ça.** Wine, Proton, les conteneurs
travaillent en dessous et ne se montrent jamais. Le premier usage de chaque monde
télécharge son moteur une fois — Proton fait 793 Mo, et ça prend trois minutes.

Le **Play Store** est là, dans l'image Android. Google exige que l'appareil lui
soit déclaré une fois : « Activer le Play Store » lit l'identifiant, le copie et
ouvre la page. Il reste un collage et un clic, une seule fois. **F-Droid** est
posé en plus.

### Ce qui n'a jamais été éprouvé, et c'est l'essentiel

- **Aucune machine réelle n'a démarré sur S.** Il manque un SSD externe.
- **Waydroid n'a jamais tourné.** Le support est là — `binder` est compilé dans
  le noyau —, mais aucune application Android n'a démarré. C'est pourtant le
  cœur du projet.
- **Aucun jeu n'a été lancé.**
- **Les coutures n'existent pas** : menu unique, dossier partagé entre les trois
  mondes, presse-papiers commun. C'est ce qui ferait de S autre chose qu'une
  Bazzite avec des logiciels en plus.

L'état exact, ligne par ligne, est dans [CLAUDE.md](CLAUDE.md) — et il ne se met
à jour qu'avec une mesure, jamais avec une intention.

## Comment ça marche

| Ce que tu lances | Comment ça tourne |
|---|---|
| Un jeu ou un logiciel Windows | **Proton / Wine** — traduction d'API, pas d'émulation |
| Une application Android | **Waydroid** — Android sur le noyau de la machine |
| Un outil Linux | natif |

**Rien n'est émulé.** Wine veut dire *Wine Is Not an Emulator* : le processeur
exécute les mêmes instructions que sous Windows, seuls les appels système sont
réaiguillés. Waydroid, c'est Android lui-même sur le noyau — Android *est* Linux.

## Ce que ça ne fera jamais

Ces limites ne sont pas des chantiers en retard : ce sont des murs.

- **Les jeux à anti-triche noyau** — Valorant, Fortnite, les serveurs Lineage 2
  officiels. L'anti-triche s'installe *dans* le noyau Windows ; il n'y en a pas
  ici.
- **Les applications Android à Play Integrity** — banques, certaines applis
  d'entreprise. Elles vérifient qu'elles tournent sur un Android certifié Google.
- **Les logiciels qui pilotent du matériel par un pilote Windows.** Wine traduit
  des appels de programme, pas des pilotes.

## Installer

```bash
# Depuis une session live Bazzite, sur la machine cible :
sudo bootc install to-disk --wipe --filesystem btrfs \
  --source-imgref docker://ghcr.io/gigigrenier86/s-os:latest \
  --target-imgref ghcr.io/gigigrenier86/s-os:latest \
  --karg console=tty0 --karg console=ttyS0,115200 \
  /dev/<disque>
```

Puis, à chaque nouvelle version :

```bash
sudo bootc upgrade && sudo systemctl reboot
```

Pas d'ISO à fabriquer. `sudo bootc rollback` revient en arrière si une version
casse quelque chose.

## Sur quoi c'est bâti

S ne réinvente pas les moteurs et ne le prétend pas. Il empile sur
[Bazzite](https://bazzite.gg/), qui apporte Steam, Proton et la recette Waydroid.
Ce que S ajoute, ce sont les logiciels prêts à l'emploi — et, à terme, **les
coutures** qui feront que les trois mondes se comportent comme un seul système.
