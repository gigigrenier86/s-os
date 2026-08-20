# S

Un système d'exploitation qui fait tourner les logiciels Windows, Linux et Android
sur une seule machine, un seul bureau, un seul dossier personnel.

Construit par empilement sur **Bazzite**, publié comme image `bootc` sur `ghcr.io`.
Interface en français.

---

## Deux malentendus à lever avant de lire la suite

Ils sont revenus plusieurs fois pendant la conception. Ils reviendront.

### 1. Rien n'est émulé

- **Wine** veut dire *Wine Is Not an Emulator*. Le processeur exécute les mêmes
  instructions x86-64 que sous Windows. Seuls les appels à l'API Windows sont
  réaiguillés vers leurs équivalents Linux. Aucune machine virtuelle, aucune
  traduction d'instructions — certains jeux tournent **plus vite** sous Proton
  que sous Windows.
- **Waydroid**, c'est Android lui-même sur le noyau de la machine. Android *est*
  Linux : son espace utilisateur tourne dans un conteneur LXC qui partage le
  noyau hôte.

### 2. On ne fusionne pas des ISO

**Une ISO n'est pas une boîte de pièces détachées.** C'est une machine déjà
assemblée : son propre noyau, son propre chargeur d'amorçage, son propre format
de programmes. Fusionner deux ISO, c'est souder deux voitures en espérant qu'il
en sorte une qui roule. Le noyau Linux ne *refuse* pas de lire un `.exe` — il ne
sait pas ce que c'est.

**Mais la fusion rêvée existe déjà, et elle s'appelle Wine et Waydroid.**
Trente-trois ans à réécrire l'API Windows de zéro. Ce sont elles, la fusion.

**Ce qui n'a jamais été fait, et qui est le projet :** monter ces trois mondes
dans une seule machine cohérente — un menu, un dossier, un presse-papiers, un nom.

Conséquences pratiques : **de Windows, on ne prend aucun fichier** (Wine ne
contient pas une ligne de code Microsoft, c'est ce qui le rend libre et légal) ;
**d'Android non plus** (Waydroid télécharge sa propre image LineageOS au premier
lancement).

---

## Où on en est — 2026-08-19

**Le dépôt vient d'être créé. Rien n'a jamais été construit ni exécuté.**

| Élément | État |
|---|---|
| Squelette du dépôt | écrit |
| `Containerfile` | écrit, **jamais construit** |
| Scripts de construction | écrits, **jamais exécutés** |
| CI GitHub | écrit, **jamais lancé** |
| Image sur `ghcr.io` | **inexistante** |
| Démarrage en QEMU | **jamais tenté** |
| Démarrage sur matériel réel | **jamais tenté** — le SSD n'est pas acheté |

**Aucune ligne de ce dépôt n'a la moindre preuve derrière elle à ce jour.** Cette
table est le premier endroit à mettre à jour, et elle ne se met à jour qu'avec
une mesure ou une capture, jamais avec une intention.

---

## Architecture

| Monde | Moteur | Nature |
|---|---|---|
| Linux | le noyau | natif, c'est la fondation |
| Windows | Proton / Wine | traduction d'API, plein régime |
| Android | Waydroid | conteneur LXC sur le noyau hôte |

**Socle : `ghcr.io/ublue-os/bazzite:stable`** (variante KDE, bureau).

Bazzite apporte déjà la pile de jeu réglée — Steam, Proton, GE-Proton, gamescope,
pilotes de manettes — **et sa propre recette Waydroid**, `ujust configure-waydroid`.
Refaire ce travail serait le refaire moins bien.

**Ce que ça implique, et il faut le dire :** l'apport propre de S n'est **pas**
d'avoir réuni les moteurs. Bazzite les a déjà, chacun derrière son étape
d'installation. L'apport de S, ce sont **les coutures** — et rien d'autre.

```
Containerfile                 FROM ghcr.io/ublue-os/bazzite:stable
build_files/
  10-base.sh                  locale française
  20-android.sh               vérifie Waydroid, décide du chargement de binder
  30-coutures.sh              le cœur du projet — encore vide
files/usr/                    déposé tel quel dans l'image
.github/workflows/build.yml   construit et publie
image.toml                    bootc-image-builder — jalon 6 seulement
```

---

## Construire, et installer

### La construction se fait dans le CI, jamais sur la machine

La machine de développement **n'a ni podman ni WSL**, et il ne lui reste que
~61 Go libres. Faire construire par GitHub Actions règle les deux d'un coup : on
ne télécharge jamais que le résultat.

### On ne fabrique pas d'ISO — on bascule

C'est la voie `bootc`, et elle évite de produire, héberger et retélécharger 6 Go
à chaque changement :

```bash
# Depuis une installation Bazzite ordinaire, une seule fois :
sudo bootc switch --enforce-container-sigpolicy=false ghcr.io/<compte>/s-os:latest
sudo systemctl reboot
```

Les mises à jour suivantes sont atomiques, et `sudo bootc rollback` ramène en
arrière si une version casse quelque chose. **C'est le filet de sécurité le plus
important du projet** : contrairement à PC Boost, ici une erreur peut empêcher la
machine de démarrer.

L'ISO installable n'a d'objet qu'au jalon 6, si S doit être distribué.

---

## Règles de conception à ne pas casser

**Ce qui est fait à la main après installation ne survit pas.** Sur une base
atomique, un réglage tapé dans un terminal disparaît ou dérive à la prochaine
mise à jour. Tout ce qui doit tenir va **dans l'image**. C'est toute la
différence entre un OS et un réglage.

**On ne réimplémente pas ce que l'amont maintient.** Waydroid passe par
`ujust configure-waydroid`, la recette de Bazzite. En revanche `20-android.sh`
**vérifie qu'elle existe toujours** et fait échouer la construction si elle
disparaît — bruyamment, plutôt que de livrer un OS dont la brique Android s'est
évaporée en silence.

**Rien d'inconditionnel quand la machine peut répondre.** `binder` est soit
compilé dans le noyau, soit un module. Poser un `modules-load.d` dans les deux
cas journaliserait une erreur à chaque démarrage pour rien. Le script lit la
configuration du noyau de l'image et tranche — et **il écrit ce qu'il a trouvé**
dans le journal de construction.

**Ce qui n'a pas été exercé s'écrit comme non exercé.** Règle héritée de PC Boost,
et elle vaut davantage ici : presque tout doit être vérifié sur du vrai matériel.
Une documentation n'est pas une machine. Un OS qui démarre dans QEMU n'est pas un
OS qui démarre.

---

## Limites, connues d'avance

1. **Wine traduit des API, pas des pilotes.** Un logiciel qui parle au matériel
   par un pilote noyau Windows ne peut pas fonctionner, quel que soit le réglage.
   C'est le seul mur vraiment infranchissable.
2. **Lineage 2 en est le cas concret.** `nProtect GameGuard` charge un pilote
   `.sys` en anneau 0 ; Wine n'a pas de noyau Windows où le charger. Les serveurs
   officiels NCSoft sont hors d'atteinte, ainsi que les gros serveurs privés à
   anti-triche — Asterios, Reborn, Scryde, Battleclub. **Décision prise : bascule
   vers des serveurs privés sans anti-triche**, où le jeu tourne.
3. **Waydroid ne fonctionne pas sur NVIDIA.** Sans objet ici : GPU Intel.
4. **Play Integrity** bloque les applications bancaires sous Waydroid.
5. **La traduction ARM** — libhoudini sur processeur Intel, libndk sur AMD,
   **jamais les deux** — est nécessaire à une bonne part des applications
   Android. Statut juridique trouble : installation séparée par `ujust`, jamais
   embarquée dans l'image.
6. **Windows reste sur le disque interne, définitivement.** PC Boost est du WPF
   .NET, qui ne se construit que sous Windows. Le double amorçage est l'état
   final, pas une étape. La licence Windows de la machine est OEM, liée à la
   carte mère : elle ne pourrait pas être déplacée dans une VM.
7. **L'UHD 630 borne le périmètre « jeux »** au rétro, à l'indé et à l'émulation.
   Lineage 2, moteur de 2003, y est à l'aise. Rien de moderne. Ça n'a rien à voir
   avec Linux — c'est vrai sous Windows aussi.

---

## La machine — relevé du 2026-08-19

| Point | Valeur |
|---|---|
| Machine | LENOVO 10T7002CUS — ThinkCentre M720q Tiny |
| Processeur | i5-8400T, 6 cœurs / 6 fils, Coffee Lake — AVX2 et SSE 4.2 |
| Mémoire | 15,9 Go — 2×8 Go @ 2133, double canal |
| Affichage | Intel UHD 630 |
| Disque interne | WD SN730 NVMe 256 Go — 61 Go libres |
| USB | contrôleur Intel USB 3.1 |
| Virtualisation | activée au firmware, **aucun hyperviseur actif** → QEMU en TCG, lent |
| Outillage | `git` · `dotnet` · QEMU présents ; `gh`, `podman` absents ; **WSL absent** |

`SSE 4.2` présent → la traduction ARM d'Android est utilisable, et c'est
**libhoudini** qu'il faut sur un processeur Intel.

QEMU est à `C:\Program Files\qemu\`, avec `edk2-x86_64-code.fd` — et le fichier
de variables x86_64 s'appelle bien `edk2-i386-vars.fd`, ce qui surprend mais est
correct.

> **Attention.** Une clé SanDisk de 57 Go porte la clé d'installation Windows 11
> (volume `CCCOMA_X64F`). Aucune étape de ce projet ne doit l'écraser. Elle ne
> ferait pas un banc de toute façon : c'est de la mémoire flash, dont l'écriture
> aléatoire s'effondre. Le banc sera un vrai SSD externe.

---

## Ce qui n'a jamais été exercé

À tenir à jour, et à ne jamais vider par optimisme :

- **Tout.** Voir la table d'état plus haut. Le dépôt a été créé aujourd'hui.
- Le SSD externe n'est pas acheté. Rien n'a touché de matériel réel.
- L'état de l'iGPU sous Linux est inconnu. Sous Windows, il accuse 266
  réinitialisations du moteur d'affichage en 30 jours, conclusion « matériel ».
  Si c'en est bien une, Linux la rencontrera aussi — et les trois couches
  s'appuient toutes sur le GPU.

---

## Conventions

- Commentaires et documentation **en français**, à l'indicatif.
- Un commentaire explique *pourquoi*, jamais *quoi*.
- **Les scripts sont en LF, sans exception.** Un CRLF donne
  `bad interpreter: /bin/bash^M` dans le conteneur. `.gitattributes` le force ;
  ne pas le contourner.
- Un script de construction qui découvre quelque chose l'**écrit** dans le
  journal. Un `echo` bien placé est ce qui permettra de remplir la table d'état
  avec des faits plutôt qu'avec des suppositions.

---

## Pièges rencontrés

### Le dépôt est édité sous Windows, l'image se construit sous Linux

- **Le bit d'exécution ne survit pas.** Un script créé sous Windows entre dans
  git en `100644`. Dans le conteneur, `RUN /ctx/build_files/10-base.sh` rend
  alors « Permission denied » et la construction meurt au premier `RUN` — après
  avoir téléchargé toute l'image de base, donc tard et pour rien. Deux parades,
  posées toutes les deux : `git update-index --chmod=+x` enregistre le mode, et
  le `Containerfile` appelle **`bash /ctx/...`** plutôt que le script seul, ce
  qui rend la construction indifférente au mode si un futur checkout le reperd.
  Vérifier par `git ls-files -s build_files/` : `100755` attendu.
- **Le CRLF casse tout, en silence apparent.** Un script en fins de ligne Windows
  donne `bad interpreter: /bin/bash^M`. `.gitattributes` force le LF ;
  `git ls-files --eol` le confirme (`i/lf w/lf` attendu).

Ces deux vérifications coûtent une seconde et évitent chacune un aller-retour
complet de CI.
