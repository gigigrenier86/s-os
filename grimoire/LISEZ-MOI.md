# Le Grimoire

Les mécanismes de ce projet qui ont **fonctionné**, extraits de leur contexte et
rendus réutilisables.

Chaque fichier est autonome : on le `source`, on appelle sa fonction. Rien n'a
besoin du reste du dépôt.

```bash
source grimoire/ostree-controle-usr.sh
controler_hors_usr vivaldi-stable
```

---

## La règle d'entrée, et c'est elle qui fait tout

**Rien n'entre ici sans une ligne `PREUVE:` datée, qui nomme la fois où ça a
tourné.**

Sans cette règle, une bibliothèque de recettes devient en six mois un cimetière
de bouts plausibles jamais exécutés — et le pire est qu'on s'y fie. C'est
exactement le « succès silencieux » que ce projet redoute ailleurs : une chose
qui a l'air d'un outil et qui n'en est pas un.

Une idée non éprouvée n'est pas interdite. Elle n'est simplement **pas ici** :
sa place est dans `CLAUDE.md`, section « ce qui n'a jamais été exercé », jusqu'à
ce qu'une mesure la fasse changer de fichier.

**Le déménagement d'une recette vers ce dossier est l'acte qui célèbre la
preuve.** Pas la construction verte, pas le code écrit : la mesure.

---

## Ce qu'il contient

| Fichier | Ce que ça résout | Éprouvé le |
|---|---|---|
| [ostree-controle-usr.sh](ostree-controle-usr.sh) | Faire échouer une construction plutôt que livrer une image creuse | 2026-08-20 |
| [ostree-detour-opt.sh](ostree-detour-opt.sh) | Installer un RPM qui exige `/opt` sur un système atomique | 2026-08-20 |
| [ghcr-visibilite.sh](ghcr-visibilite.sh) | Savoir si un paquet `ghcr.io` est vraiment public | 2026-08-20 |
| [ghcr-peser-couches.sh](ghcr-peser-couches.sh) | Peser chaque couche d'une image sans rien télécharger | 2026-08-20 |
| [disque-sonde-ecriture.sh](disque-sonde-ecriture.sh) | Savoir avant d'engager si un disque acceptera l'écriture | 2026-08-21 |
| [linux-couper-zram.sh](linux-couper-zram.sh) | Empêcher le zram de figer une grosse écriture | 2026-08-21 |
| [banc-preambule.ps1](banc-preambule.ps1) | Les cinq murs de Windows sur un disque physique | 2026-08-21 |
| [ostree-eprouver-dependance-python.sh](ostree-eprouver-dependance-python.sh) | Éprouver une dépendance Python manquante sans toucher à `/usr` | 2026-08-25 |
| [banc-controler-scripts.sh](banc-controler-scripts.sh) | Quatre contrôles à une seconde qui évitent quatre cycles perdus | 2026-08-21 |
| [ci-trouver-execution.sh](ci-trouver-execution.sh) | Retrouver la bonne exécution de CI sous `paths-ignore` | 2026-08-20 |
| [qemu-observer-sans-casser.sh](qemu-observer-sans-casser.sh) | Diagnostiquer un QEMU « figé » sans aggraver son cas | 2026-08-21 |
| [desktop-echapper-exec.sh](desktop-echapper-exec.sh) | Écrire un chemin dans un `Exec=` sans que GLib rejette la ligne | 2026-08-23 |
| [windows-lire-cible-lnk.sh](windows-lire-cible-lnk.sh) | Lire la cible d'un raccourci `.lnk` sans bibliothèque | 2026-08-23 |
| [kwin-capturer-la-coquille.sh](kwin-capturer-la-coquille.sh) | Photographier une fenêtre précise sous kwin, sans interface et sans déranger la session | 2026-08-25 |
| [proton-capturer-environnement.sh](proton-capturer-environnement.sh) | Demander à Proton l'environnement qu'il compose, au lieu de recopier sa liste | 2026-08-26 |
| [windows-declarer-police.sh](windows-declarer-police.sh) | Une police copiée dans un prefixe Wine n'existe pas tant qu'elle n'est pas déclarée | 2026-08-26 |
| [construction-eprouver-les-motifs.sh](construction-eprouver-les-motifs.sh) | Rejouer les contrôles par motif des scripts de build avant de construire | 2026-08-26 |
| [ostree-comparer-deploiements.sh](ostree-comparer-deploiements.sh) | Savoir ce qu'un `bootc rollback` coûte, avant de le faire | 2026-08-25 |
| [vivaldi-classe-reelle-app.sh](vivaldi-classe-reelle-app.sh) | Trouver la vraie classe d'une fenêtre `vivaldi --app=`, que `--class=` ne fixe jamais | 2026-08-26 |
| [veille-eprouver-le-gel.sh](veille-eprouver-le-gel.sh) | Éprouver la veille des fenêtres sans toucher à la session de l'utilisateur | 2026-08-26 |
| [wayland-ou-se-pose-un-popup.sh](wayland-ou-se-pose-un-popup.sh) | Savoir si ce compositeur place un popup Qt là où on le lui demande | 2026-08-27 |
| [android-piloter-sans-waydroid.sh](android-piloter-sans-waydroid.sh) | État, commande, installation et lancement dans l'Android LXC natif — et les quatre pièges qui s'y cachent | 2026-08-29 |

---

## Les cinq principes qui reviennent partout

Ils ne sont pas rangés dans un fichier parce qu'ils traversent tous les autres.

**1. Le pire résultat n'est pas l'échec, c'est le succès silencieux.**
Une installation forcée vers `/var` « marche » et livre du vide. Un `.deb`
associé à l'archiveur « s'ouvre ». Des icônes Wine apparaissent et ne lancent
rien. À chaque fois, l'échec bruyant aurait coûté dix minutes ; le succès
silencieux coûte des mois.

**2. Vérifier avant de contourner.**
Le détour `/opt` n'a servi qu'à 2 logiciels sur 8. Partout ailleurs un préfixe
existait. Le contrôle coûte une commande ; le détour appliqué inutilement
ajoute du risque pour rien.

**3. Un contrôle pris trop tôt ment.**
`swapoff` puis « swap 0 Mio » — et le swap est revenu trois minutes plus tard.
`bootc` a rendu la main — et le cache du boîtier USB n'est pas vidé. Le contrôle
se prend après le délai, jamais dans la foulée du geste.

**4. Capturer depuis l'instant zéro.**
Deux heures perdues à réparer une machine qui n'avait rien, parce que la console
était lue *après* le démarrage. Un écran noir et un port muet ont été pris pour
une panne. Une capture noire prouve qu'on n'a rien vu, jamais qu'il n'y a rien.

**5. L'état d'une machine ne dit pas l'état de l'image.**
Sur un système atomique, une VM peut tourner sur un déploiement antérieur et
paraître avoir tout perdu. Interroger l'image directement — `podman run` sur le
tag publié — est le seul contrôle qui réponde à la question posée.

---

## En attente de preuve

Écrits, syntaxiquement validés, **jamais exécutés**. Ils monteront dans le
tableau ci-dessus le jour où ils auront tourné, pas avant.

| Fichier | Ce qu'il attend |
|---|---|
| [../banc/seagate.ps1](../banc/seagate.ps1) | Un lancement élevé sur la Seagate |
| [../banc/poser-sur-seagate.sh](../banc/poser-sur-seagate.sh) | La même chose, côté invité |
| `blockdev --flushbufs` après `bootc` | Vider le cache d'un boîtier USB — repris de la théorie, jamais mesuré ici |
| Géométrie 512e déclarée à virtio | `blockdev --getpbsz` doit rendre 4096 dans l'invité. Jamais vérifié |
