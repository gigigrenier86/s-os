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

---

## Où on en est — 2026-08-20

**Le jalon 2 est atteint et prouvé.** S s'installe, démarre jusqu'à l'invite de
connexion, se met à jour par `bootc upgrade`, et **porte huit logiciels installés
aux bons chemins**. Le jalon 5 s'est ouvert le soir même : un double-clic installe
désormais dans les trois mondes, et c'est éprouvé. CI vert, image publique.

**La nuance porte tout le reste du carnet** : « installé » n'est pas « éprouvé ».
Des huit logiciels, un seul a jamais été exécuté — Vivaldi, par un `--version`.
Les coutures du jalon 5, elles, ont bien tourné : un vrai paquet Debian posé, un
vrai binaire Windows exécuté.

Tout ce qui suit a été **relevé par SSH dans le système installé**, pas seulement
dans l'image.

### Ce qui existe et fonctionne

| | |
|---|---|
| Dépôt | https://github.com/gigigrenier86/s-os — public |
| Image | `ghcr.io/gigigrenier86/s-os:latest` — **publique**, tirable sans authentification |
| Socle | `ghcr.io/ublue-os/bazzite:stable` — Fedora 44 atomique, KDE Plasma |
| Construction | GitHub Actions, ~9 min, **plus reconstruction quotidienne automatique** |
| Installation | `bootc install to-disk --source-imgref docker://…` — 35 min |
| Poids | **137 couches, 6,95 Go** — 128 viennent de Bazzite, 9 de S |
| Mise à jour | **`bootc upgrade`** — une retouche de geste coûte **9,6 Mo** depuis le découpage en couches (2,3 Go avant) |
| Démarrage | **35 s** en régime ; 58 s la première fois après une mise à jour |
| Compte utilisateur | créé à l'installation par **`plasma-setup`**, natif à l'image de base |
| Bureau | **KDE Plasma, vu et capturé** — `bureau-2026-08-20.png`. Rendu **logiciel** (`llvmpipe`), faute de GPU au banc |

### Les huit logiciels posés

| Logiciel | Version | Où | Provenance | Signature vérifiée |
|---|---|---|---|---|
| Vivaldi | 8.1.4087.68 | `/usr/lib/opt/vivaldi` (438 Mo) | dépôt Vivaldi | oui (`gpgcheck=1`) |
| VS Code | 1.134.0 | `/usr/share/code` (1,1 Go) | dépôt Microsoft | oui (`gpgcheck=1`) |
| Node.js | v24.18.0 | `/usr/bin` | Fedora | oui |
| Gemini CLI | 0.56.0 | `/usr/lib/node_modules` (100 Mo) | npm | **non** |
| Claude Code | 2.1.228 | `/usr/bin/claude` | dépôt RPM officiel | oui |
| Antigravity | 1.23.2 | `/usr/share/antigravity` (682 Mo) | dépôt Google | **non — `gpgcheck=0`** |
| RetroArch | 1.22.0 + 14 cœurs | `/usr/lib64/libretro` | Fedora | oui |
| Zoom | — | `/usr/lib/opt/zoom` (918 Mo) | dépôt Zoom | oui (clé Zoom) |
| F-Droid (APK) | — | `/usr/share/s/apk` (12 Mo) | f-droid.org | oui (GPG, empreinte en dur) |

**La provenance n'est pas la signature.** Les confondre présenterait un simple
« ça vient de chez l'éditeur » comme un contrôle, ce qu'il n'est pas. Deux
colonnes, donc : d'où ça vient, et si quelque chose l'a vérifié.

Plus deux lanceurs en fenêtre dédiée — **RapidO** vers MEWS, **Gemini** vers son
application web — et, dans `/etc/skel`, l'extension Claude Code, le pack de
langue français et un `argv.json` qui ouvre l'éditeur en français.

### Ce qui n'a JAMAIS été exercé

À dire nettement, parce que c'est l'essentiel de ce qui reste :

- **Aucune machine réelle n'a démarré sur S.** Tout ce qui précède s'est passé
  dans QEMU. Il manque le SSD externe — le seul achat du projet.
- **Waydroid n'a jamais tourné.** `binder` est compilé dans le noyau, le
  lanceur est présent, la recette de Bazzite existe — mais aucune application
  Android n'a jamais démarré. C'est le différenciateur du projet, et il est
  entièrement non éprouvé.
- **Lineage 2 n'a jamais été lancé**, ni aucun jeu.
- **L'iGPU n'a pas été jugé.** Les 266 réinitialisations relevées sous Windows
  n'ont pas d'équivalent mesuré sous Linux.
- **Le partage entre les mondes n'existe pas** — dossier personnel commun,
  presse-papiers commun, associations croisées. L'*installation* dans les trois
  mondes, elle, est cousue et éprouvée depuis le 2026-08-20 au soir : c'est la
  première moitié du jalon 5, et la seconde attend le jalon 3.
- **Aucun des huit logiciels de l'image n'a jamais servi.** Leur présence est
  prouvée, leur fonctionnement non — seul Vivaldi a été exécuté, par un
  `--version`. Les sept autres n'ont montré qu'un chemin de fichier.
- **`bootc rollback` n'a jamais été exercé.** C'est pourtant le filet de sécurité
  du projet, et il est exerçable dès aujourd'hui dans la machine virtuelle : deux
  déploiements y coexistent. Cela coûte un redémarrage à froid, et changerait une
  affirmation en mesure.
- **Aucune ISO installable n'a été produite.** La voie employée est
  `bootc install to-disk` depuis le registre.

### Où on va

| Jalon | État |
|---|---|
| 0 · La voie Waydroid | **fait** — `binder` compilé dans le noyau, prouvé à la construction |
| 1 · Le dépôt et la chaîne | **fait** — CI vert, image publiée, reconstruction quotidienne |
| 2 · L'image démarre | **fait et prouvé de l'intérieur** — 35 s, zéro service en échec |
| 3 · Le vrai matériel | **bloqué** — attend un SSD externe (~40 €) |
| 4 · Les trois mondes côte à côte | pas commencé — exige le jalon 3 |
| 5 · Les coutures | **commencé** — l'installation des trois mondes est cousue et éprouvée ; le partage entre eux ne l'est pas |
| 6 · L'identité | pas commencé — S s'annonce encore « Bazzite » |
| 7 · L'usage quotidien | pas commencé |

**Le jalon 3 est le seul verrou matériel**, et il ne se lève pas par du code : il
faut un vrai SSD externe, pas une clé — une mémoire flash s'effondre en écriture
aléatoire. Tout le reste en découle : Waydroid à vitesse réelle, les jeux,
l'iGPU, et le droit de dire que S fonctionne.

**Un second prérequis n'est pas tranché, et il se règle avant l'achat, pas
après** : Bazzite publie une procédure particulière pour les machines dont
Secure Boot est actif. L'état du firmware de la M720q sur ce point n'a jamais
été relevé. À faire avant de brancher quoi que ce soit.

**Le jalon 5 s'est ouvert le 2026-08-20 au soir**, et il se divise en deux
moitiés que rien n'obligeait à mener ensemble. La première — *installer* dans
les trois mondes d'un seul double-clic — ne demande pas de matériel : elle est
faite et éprouvée. La seconde — *partager* entre les mondes, un dossier
personnel, un presse-papiers, des associations croisées — attend le jalon 3,
puisqu'elle suppose que les trois mondes tournent en même temps.

### Les règles apprises, et qui tiennent tout

**1. Sur ostree, tout ce qui est modifiable est un lien vers `/var` — et `/var`
n'entre pas dans l'image.** `/opt`, `/usr/local`, `/home`, `/root`, `/srv`,
`/mnt`. C'est le principe unique derrière l'échec de Vivaldi, celui de npm, et
le risque qu'aurait couru l'installateur de Claude Code. `/etc` en est
l'exception salutaire.

**2. Le pire résultat n'est pas l'échec, c'est le succès silencieux.** Forcer
une installation vers `/var` « marche » et livre une image creuse. D'où un
contrôle `rpm -ql | grep '^/(var|opt)/'` dans chaque script, qui fait échouer la
construction plutôt que de livrer du vide.

**3. Vérifier avant de contourner.** Le détour `/opt` n'a servi qu'à deux
logiciels sur huit. Partout ailleurs un préfixe existait — `npm_config_prefix`,
`--extensions-dir`, un paquet RPM bien fait.

**4. Ce dont S a besoin entre dans l'image, jamais dans un mécanisme de premier
démarrage.** **Un** script de Bazzite a été pris en défaut sur ce point :
`flatpak-manager`, qui a tourné 5,6 s sans rien poser puis a écrit ses marqueurs.
Deux autres écrivent aussi des marqueurs et font correctement leur travail —
`bazzite-hardware-setup`, qui lit le matériel et redémarre à dessein, et
`plasma-setup`, qui crée le compte utilisateur. **Le marqueur n'est pas le
défaut : c'est le report du travail qui l'est.**

**5. Une ligne cosmétique ne doit jamais faire tomber une image saine.** Les
rapports se terminent par `|| true` ; seules les assertions bloquent.

**6. Capturer depuis l'instant zéro.** Deux heures ont été perdues à réparer une
machine qui n'avait rien, parce que je me connectais à la console *après* le
démarrage. Un écran noir et un port muet ont été lus comme une panne.

**7. Regarder la machine avant de chercher une solution.** Une enquête à quatre
pistes a été lancée sur un problème que l'image résolvait déjà : trois commandes
suffisaient à le voir.

**8. Le banc n'est pas l'OS.** Le redémarrage à chaud de QEMU ne repart pas, et
les attentes de périphériques `ttyS0` et `vda` coûtent 11 s. Le bureau, lui,
**démarre bel et bien** — il tombe seulement sur le rendu logiciel `llvmpipe`,
faute de GPU. Rien de tout cela n'est un défaut de S — mais tout cela y
ressemble, et j'ai mis quinze heures à cesser de le confondre.

**9. Une couture ne montre jamais son moteur.** C'est la règle du jalon 5, et
elle se vérifie au fichier produit, pas au message affiché : `distrobox-export`
nommait l'application « Galculator (on s-debian) » et posait en plus une icône
pour le conteneur. L'utilisateur a installé une calculatrice, pas un conteneur
Debian — les deux traces sont effacées après coup.

**10. Une icône qui apparaît n'est pas une icône qui lance.** `winemenubuilder`
écrit de vrais `.desktop` pour les raccourcis du menu Démarrer, mais leur `Exec`
appelle `wine`, absent d'ici puisque Proton vient d'umu. Sans `s-menu-windows`
pour les réécrire, l'installation d'un `.exe` semble réussir et ne produit que
des raccourcis morts. Ce défaut ne se voit qu'en cliquant.

**11. Une couche par étape, ou la mise à jour coûte tout.** Les huit scripts
tenaient dans un seul `RUN` : un `bootc upgrade` réel a alors annoncé
`layers needed: 2 (2.3 GB)` pour une retouche de couture, puisque la couche
unique portait aussi VS Code, Antigravity et Zoom. Et `COPY files/ /` doit
descendre au plus près du seul script qui en dépend, sinon il invalide tout ce
qui le suit à chaque virgule corrigée. **Mesuré après découpage**, sur le
manifeste de l'image publiée : la couche des coutures pèse **9,6 Mo**, celle du
`COPY` moins de 0,1 Mo. Une retouche de geste coûte donc 9,6 Mo au lieu de
2,3 Go.

### Les deux réserves assumées

- **Deux composants entrent sans vérification de signature**, pas un seul.
  Antigravity, dont le dépôt impose `gpgcheck=0` — décision de l'utilisateur,
  écrite dans le script. Et **Gemini CLI**, posé par `npm install -g` : npm
  authentifie le transport, pas le contenu, et le script désactive `audit`.
  Dans les deux cas la seule garantie est HTTPS vers l'éditeur. Pour Gemini CLI
  ce n'est pas un choix assumé : c'est sa seule voie de distribution.
- **Vivaldi est proprietaire**, et sa page destinée aux distributions dit
  qu'aucun accord n'est nécessaire quand son CLUF interdit la redistribution.
  Les deux textes se contredisent ; le dépôt étant public, c'est consigné.

### Le seul piège qui casserait une installation neuve

**`/etc/plasma-setup-done` ne doit jamais entrer dans l'image.** C'est le
marqueur qui désarme l'assistant de création de compte. S'il y entrait, toute
installation neuve démarrerait sans compte utilisateur et sans moyen d'en créer
un — et cela ne se verrait pas avant la machine suivante.
## 2026-08-19 — le dépôt est créé *(dépassé, voir « Où on en est » plus haut)*

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

### On ne fabrique pas d'ISO — on installe l'image directement

**Avant toute manipulation, lire `banc/LISEZ-MOI.md`** : il porte la préparation
du firmware, les cinq pièges de QEMU sous WHPX, la console série, et les six
impasses qui ont précédé la bonne route.

La route réellement employée, et la seule éprouvée — depuis un support live
Bazzite, vers le disque cible :

```bash
sudo bootc install to-disk --wipe --filesystem btrfs \
  --source-imgref docker://ghcr.io/gigigrenier86/s-os:latest \
  --target-imgref ghcr.io/gigigrenier86/s-os:latest \
  --root-ssh-authorized-keys /chemin/vers/cle.pub \
  --karg console=ttyS0,115200 \
  /dev/<disque cible — vérifier deux fois>
```

`--target-imgref` n'est pas facultative : sans elle, `bootc upgrade` ne sait pas
où aller chercher la suite.

**La voie `bootc switch` depuis une Bazzite déjà installée n'a jamais été
exercée**, et elle télécharge deux fois. Elle a été abandonnée en cours de route
au profit de celle ci-dessus ; elle n'est conservée ici que pour mémoire :

```bash
sudo bootc switch --enforce-container-sigpolicy=false ghcr.io/gigigrenier86/s-os:latest
```

`--enforce-container-sigpolicy=false` mérite son mot d'explication : l'image
n'est pas signée par une politique que `bootc` connaisse d'avance, et sans ce
drapeau il refuse de basculer. Le jour où S sera signé, il disparaîtra.

Les mises à jour suivantes sont atomiques, et `sudo bootc rollback` ramène en
arrière si une version casse quelque chose. Ce serait **le filet de sécurité le
plus important du projet** — contrairement à PC Boost, ici une erreur peut
empêcher la machine de démarrer. **Il n'a jamais été exercé**, et c'est la seule
promesse de ce carnet dont l'absence de preuve coûterait aussi cher.

L'ISO installable n'a d'objet qu'au jalon 6, si S doit être distribué.

---

## Règles de conception à ne pas casser

**Aucun secret dans le dépôt — il est public.** Mot de passe, clé privée, jeton :
rien de cela n'entre, pas même dans un script de banc. Ce dont le banc a besoin
passe par une variable d'environnement, et la clé SSH reste dans `S-vm/`, hors dépôt.
La règle a été écrite après coup : le mot de passe du banc a vécu en clair dans
`banc/invite.sh` du 2026-08-20 au soir, poussé sur une branche publique. **Un secret
poussé une fois reste dans l'historique** — il se change, il ne s'efface pas.

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

Cette liste vit désormais dans **« Où on en est »**, en tête de ce fichier.
Elle y est tenue à jour ; la garder en double la ferait diverger, et l’une
des deux mentirait.

*Ce qui suivait ici datait de la création du dépôt et disait « tout » —
c’était vrai le 2026-08-19, et faux depuis.*

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

---

## Vérifié sur documents — 2026-08-19

Ce qui a été confirmé à la source, et qui reste à confirmer sur une machine.

| Point | Source | Verdict |
|---|---|---|
| `ghcr.io/ublue-os/bazzite:stable` = bureau **KDE**, pilotes libres, sans NVIDIA | README de `ublue-os/bazzite` | **confirmé** — c'est bien la base du `Containerfile` |
| Waydroid est fourni par Bazzite via `ujust configure-waydroid` | doc officielle Bazzite | **confirmé** |
| `/usr/bin/waydroid-launcher` est le point d'entrée | doc officielle Bazzite | **confirmé** — c'est sur ce chemin que porte l'assertion de `20-android.sh` |
| La traduction ARM se pose par la même recette, libhoudini **ou** libndk, jamais les deux | doc officielle Bazzite | **confirmé** |
| Waydroid ne fonctionne pas sur NVIDIA | doc officielle Bazzite | **confirmé** — sans objet ici |

**Un point nouveau, et il concerne le jalon 3 :** Bazzite publie des instructions
particulières **pour les machines dont Secure Boot est actif**, à suivre *avant*
la bascule. La M720q est en Windows 11, donc Secure Boot est très probablement
activé — il n'a pas pu être lu depuis une session non élevée. À trancher avant
d'installer quoi que ce soit sur le SSD : soit enrôler la clé de Bazzite, soit
désactiver Secure Boot dans le firmware. Les deux sont réversibles.

**Une documentation n'est pas une machine.** Rien de cette table ne remplace le
jalon 3.

### Pressure-vessel réserve `/usr`, et Proton ne peut donc pas y vivre

Le réflexe évident, sur un système atomique, est de pré-cuire dans `/usr` tout ce qui
sinon se téléchargerait. Pour Proton, **c'est structurellement impossible**, et il a fallu
l'essayer pour le savoir.

`umu-run` n'exécute pas Proton directement : il passe par **pressure-vessel**, le bac à
sable conteneurisé de Steam. Or celui-ci construit son propre `/usr` et **refuse de
partager celui de l'hôte** :

```
pressure-vessel-wrap: W: Not sharing path STEAM_COMPAT_MOUNTS="…:/usr/lib/s/proton:…"
                         with container because "/usr" is reserved by the container framework
umu-shim: exec: /usr/lib/s/proton/proton: not found
```

Le Proton posé sous `/usr` est **littéralement introuvable** depuis l'intérieur, et
`PROTONPATH` n'y change rien : le chemin est valide sur l'hôte et inexistant dans le
conteneur. Le message est un simple avertissement — l'échec ne vient qu'ensuite, au
`exec`, sous une forme qui ne nomme pas la cause.

**Même famille que le piège `/opt` d'ostree, et même leçon** : un chemin qui semble libre
ne l'est pas, et c'est une couche invisible depuis le code qui en décide. D'où la forme
retenue — **l'archive** entre dans l'image, et se déplie dans le dossier personnel, que
pressure-vessel partage volontiers.

### Git ne suit pas les dossiers vides

Première construction, 2026-08-20 : échec sur
`COPY files/ /: copier: stat: "/files": no such file or directory`.

`files/usr/share/applications` et ses voisins avaient été créés localement, mais
**vides** — ils ne sont donc jamais entrés dans le dépôt, et le `COPY` visait un
chemin qui n'existe pas côté serveur.

Ce qui rend la faute coûteuse n'est pas sa nature, c'est **son moment** : une
source de `COPY` absente ne se découvre qu'au moment du `COPY`, donc **après** le
téléchargement complet de l'image de base. Quatre minutes pour une erreur qui se
lit en une seconde.

D'où l'étape **« Contrôler le contexte avant de télécharger dix gigaoctets »**,
posée en tête du workflow : elle vérifie que chaque source de `COPY` existe, que
chaque script porte un shebang et passe `bash -n`. Elle coûte une seconde et
rend son verdict avant le moindre octet téléchargé.

**Ce que ce premier échec a prouvé au passage**, et qui valait d'être su : l'image
Bazzite se télécharge entièrement sur un runner GitHub, `--mount=type=bind,from=ctx`
est accepté par le podman du runner, et l'espace disque suffit après nettoyage.
Les trois causes d'échec que l'on redoutait n'étaient pas les bonnes.

---

## 2026-08-20 — la chaîne de fabrication tourne, et binder est tranché

**Deuxième construction : verte de bout en bout.** L'image est bâtie et publiée.

| Élément | État |
|---|---|
| `Containerfile` | **construit avec succès** |
| Scripts de construction | **exécutés**, les trois |
| CI GitHub | **vert** — run 32329903510, 4 min 48 s |
| Image sur `ghcr.io` | **publiée** : `ghcr.io/gigigrenier86/s-os:latest` |
| Visibilité du paquet | **privée** — à basculer en public, voir plus bas |
| Démarrage en QEMU | **jamais tenté** |
| Démarrage sur matériel réel | **jamais tenté** — le SSD n'est pas acheté |

### Le risque principal du projet est levé — par la machine, pas par un document

```
binder est COMPILE dans le noyau (/usr/lib/modules/7.1.5-ogc5.1.fc44.x86_64/config)
: rien a charger.
```

`CONFIG_ANDROID_BINDER_IPC=y`. **Compilé dans le noyau, pas en module.** Ce n'est
plus la documentation de Bazzite qui l'affirme : c'est la configuration du noyau
de l'image elle-même, lue pendant sa construction.

Et cela justifie après coup d'avoir écrit `20-android.sh` en conditionnel : un
`/etc/modules-load.d` posé sans condition aurait fait tenter à systemd, **à chaque
démarrage**, le chargement d'un module qui n'existe pas.

Noyau de la base : **7.1.5-ogc5.1.fc44** — Fedora 44, noyau Bazzite.

### Ce que la construction a prouvé au passage

| Doute | Verdict |
|---|---|
| L'image Bazzite tient-elle sur un runner GitHub ? | **oui**, après l'étape de nettoyage |
| Le podman du runner accepte-t-il `--mount=type=bind,from=ctx` ? | **oui** |
| `dnf5` est-il utilisable pendant la construction ? | **oui** — `glibc-langpack-fr` et `hunspell-fr` posés |
| `/usr/bin/waydroid-launcher` est-il bien là ? | **oui** — l'assertion de `20-android.sh` passe |

Les trois causes d'échec que l'on redoutait n'étaient aucune la bonne.
**La seule vraie faute était un dossier vide.**


---

## L'hyperviseur Windows, activé le 2026-08-20

QEMU tournait en **TCG** — émulation pure, « facteur vingt » — parce qu'aucun
hyperviseur ne tournait sur la machine. Sans accélération, installer un bureau
Fedora dans une machine virtuelle aurait pris des heures, et le jalon 2 était
inatteignable tant que le SSD n'était pas acheté.

`HypervisorPlatform` a donc été activé :

    dism /Online /Enable-Feature /FeatureName:HypervisorPlatform /All /NoRestart

**Redémarrage requis**, et confirmé en attente par la clé
`HKLM\...\Component Based Servicing\RebootPending`. Tant qu'il n'a pas eu lieu,
`Win32_ComputerSystem.HypervisorPresent` reste à `False`.

Après redémarrage, QEMU accepte `-accel whpx`. Version installée : **9.1.91**.

### Le prix à payer, et comment ne pas le payer tout le temps

Activer cette fonctionnalité met **Windows lui-même au-dessus d'un hyperviseur**.
Certains anti-triche noyau le détectent et refusent alors de démarrer —
« A Hypervisor Is Already Running ». C'est un risque réel pour Lineage 2 sur
serveur officiel, où GameGuard est actif.

**Mais ce n'est pas un aller sans retour, et c'est ce qui rend l'arbitrage
facile.** L'hyperviseur se coupe au démarrage sans rien désinstaller, depuis une
invite élevée :

    bcdedit /set hypervisorlaunchtype off    # puis redemarrer — pour jouer
    bcdedit /set hypervisorlaunchtype auto   # puis redemarrer — pour QEMU

Un redémarrage dans chaque sens. La fonctionnalité reste installée dans les deux
cas ; seul son chargement au démarrage change.

*Note : la sécurité basée sur la virtualisation (VBS) était à `0` avant
l'activation — aucun conflit avec un dispositif déjà en place.*

---

## Le paquet est public — et le test que j'avais écrit était faux

Corrigé le 2026-08-20, après vérification.

**`ghcr.io` renvoie `HTTP 401` à toute requête sans jeton, publique ou privée.**
Un `curl` anonyme direct sur le manifeste ne prouve donc **rien** : c'est le
comportement normal du registre, qui exige un jeton porteur dans tous les cas.
La conclusion « 401 donc privé » consignée ici plus tôt reposait sur un test
insuffisant.

**Le vrai test est de savoir si le registre délivre un jeton à un anonyme**, et si
ce jeton ouvre le manifeste :

```bash
IMG=gigigrenier86/s-os
TOK=$(curl -s "https://ghcr.io/token?scope=repository:$IMG:pull&service=ghcr.io" \
      | grep -o '"token":"[^"]*' | cut -d'"' -f4)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Accept: application/vnd.oci.image.index.v1+json" \
  -H "Authorization: Bearer $TOK" \
  "https://ghcr.io/v2/$IMG/manifests/latest"
```

`200` = public. Pas de jeton délivré, ou `401`/`403` avec lui = privé.

**Relevé du 2026-08-20 : `200`, 130 couches.** Le paquet a été basculé en public
à la main dans l'interface web — il n'existe toujours pas d'API REST pour la
visibilité d'un paquet conteneur, et la visibilité du dépôt ne s'y propage pas.

Conséquence pour le jalon 3 : **`bootc switch` fonctionnera sans
authentification**, sur cette machine comme sur n'importe quelle autre.

```bash
sudo bootc switch --enforce-container-sigpolicy=false ghcr.io/gigigrenier86/s-os:latest
```

---

## 2026-08-20, 02 h 25 — S s'installe et s'amorce *(diagnostic corrigé plus bas)*

**Premier système installé et démarré.** En machine virtuelle, donc ce n'est pas
la preuve finale — mais c'est la première fois que l'image existe autrement que
comme un objet dans un registre.

| Étape | Résultat |
|---|---|
| `bootc install to-disk` | **`Installation complete!`** — GPT, ESP 512 Mio, racine btrfs, 129 couches |
| Chemin d'amorçage de secours | **`/EFI/BOOT/BOOTX64.EFI` présent** — la crainte du firmware sans mémoire persistante tombe |
| Amorçage depuis le disque seul | **oui** — GRUB, noyau, racine montée, systemd lancé |
| Activité disque | 2,55 Gio lus, 1,75 Gio écrits |
| Ouverture d'une session | **non** — voir ci-dessous |

### Le défaut trouvé, et pourquoi il valait le détour

```
Job bazzite-hardware-setup.service/start running (2min 13s / no limit)
```

Ce service se place **avant `systemd-user-sessions.service`** et n'a **aucune
limite de temps**. Tant qu'il ne rend pas la main, aucune session ne s'ouvre —
ni console, ni SSH — et **rien n'annonce d'erreur**. `systemd` affiche « no
limit » et compte les minutes.

**Une machine inutilisable qui a l'air de démarrer est pire qu'une machine qui
échoue.** C'est exactement le genre de panne que ce projet doit refuser.

Deux pistes se rejoignent. Le script `/usr/libexec/bazzite-hardware-setup`
appelle **`rpm-ostree kargs`**, et l'unité se déclare
`After=rpm-ostreed.service` : l'interaction avec un système installé par
`bootc install to-disk` — donc sans le chemin rpm-ostree habituel — est
suspecte. Et c'est par ailleurs un **défaut connu en amont**
(`ublue-os/bazzite`, issue 434), où le remède proposé est exactement celui
retenu ici.

### Le correctif, et sa limite

`10-base.sh` pose une limite de démarrage de 120 s sur ce service, par un
fichier de complément dans `/usr/lib/systemd/system/…d/`.

**Le service n'est pas désactivé**, et ce point compte : il configure de vraies
choses sur du vrai matériel, et la M720q en bénéficiera. On lui retire seulement
le droit de bloquer sans fin. Un échec au bout de deux minutes vaut mieux qu'une
machine qui ne s'ouvre jamais.

*Ce qui n'est pas résolu :* on ne sait pas **pourquoi** le script bloque, ni s'il
bloquerait de même sur du matériel réel. La limite traite le symptôme, pas la
cause — et c'est écrit ici pour que personne ne croie l'inverse.

### Deux mesures qui orientent la suite

- **Une installation complète prend 33 minutes** en machine virtuelle : 12 Go
  d'image à tirer, puis 129 couches à écrire.
- **La reconstruction quotidienne programmée fonctionne** — déclenchée par
  l'horloge à 05:57, verte en 4 min 51 s, sans intervention.

---

## 2026-08-20, 04 h 20 — S démarre, et le diagnostic précédent était faux

**Le jalon 2 est atteint.** Console série capturée **depuis le premier octet** —
ce qui n'avait jamais été fait, et qui explique tout ce qui précède.

```
[  OK  ] Finished bazzite-hardware-setup.service - Configure Bazzite…
[  OK  ] Finished systemd-user-sessions.service - Permit User Sessions.

Bazzite
Kernel 7.1.5-ogc5.1.fc44.x86_64 on x86_64 (ttyS0)
bazzite login:
```

| Mesure | Valeur |
|---|---|
| Durée du démarrage | **25 secondes** |
| Services en échec | **aucun** |
| Cibles atteintes | toutes, dont `boot-complete` et `greenboot-success` |
| Invite de connexion | ouverte sur la console série |

### Ce que j'avais mal lu, et pourquoi

`bazzite-hardware-setup.service` **ne fige rien**. Au **premier** démarrage après
installation il lit le matériel, applique un argument noyau — ici
`bluetooth.disable_ertm=1` — puis **redémarre la machine, à dessein** :

```
Found needed karg changes, applying: --append-if-missing=bluetooth.disable_ertm=1
Staging deployment...done
Rebooting to apply karg changes
```

Cela lui prend **1 min 52 s**, mesuré. Aux démarrages suivants il trouve ses
marqueurs dans `/etc/bazzite/` et rend la main aussitôt.

**La limite de 120 s posée quelques heures plus tôt aurait donc interrompu un
travail légitime à huit secondes de sa fin.** C'était un piège, pas un filet.
Elle est portée à **quinze minutes** : assez large pour ne jamais gêner, assez
ferme pour qu'un vrai blocage — le défaut rapporté en amont — ne rende pas la
machine inaccessible.

**La leçon de méthode, et elle vaut pour tout ce dépôt :** j'ai conclu au
blocage parce que je regardais la console *après coup*, en m'y connectant trop
tard pour voir ce qui avait déjà défilé. Un écran noir et un port muet ont été
lus comme une panne, alors que la machine attendait tranquillement qu'on se
connecte. **Capturer depuis l'instant zéro, dans un fichier, aurait donné la
réponse en deux minutes au lieu de deux heures.**

### La vraie raison de l'absence de session

**L'image n'active pas OpenSSH sur TCP.** Seuls `sshd-unix-local.socket` et
`sshd-vsock.socket` écoutent, posés par `systemd-ssh-generator` — le port 22 ne
répond à personne.

Or `bootc install --root-ssh-authorized-keys` dépose bien une clé pour `root` :
**la clé est là, et rien ne l'écoute.**

`10-base.sh` active donc `sshd.socket` — la socket plutôt que le service, pour ne
rien coûter au repos. Et la raison de fond n'est pas le banc : **une machine dont
le bureau ne démarre pas devient irréparable si l'on ne peut pas l'atteindre
autrement.**

**Ce qui est arrivé ici, en revanche, était mal diagnostiqué — et le journal l'a
tranché le 2026-08-20 à 22 h 30.** J'avais écrit que le bureau ne démarrait pas,
faute d'accélération 3D, sur la seule foi d'une capture noire
(`S-vm/ecran-s.png`, 03 h 55). **C'est faux, et dans les deux moitiés de la
phrase.**

Le bureau démarre et tourne : `display-manager` est `active`,
`plasma-login-kwin_wayland` a passé la main normalement, **`plasmashell` tourne**,
et Steam s'est lancé par-dessus. La capture noire datait d'avant la création du
compte, à une heure où il n'y avait effectivement personne à afficher.

Ce qui manque n'est pas le bureau mais **l'accélération matérielle**, et le
journal le nomme sans ambiguïté :

```
plasmashell: MESA-EGL: warning: egl: failed to create dri2 screen
steam:       name: "llvmpipe (LLVM 22.1.8, 128 bits)"
             driver_id: k_EGpuDriverId_MesaLLVMPipe
```

`llvmpipe` est le rendu **logiciel** de Mesa : tout s'affiche, tout est lent.
C'est exactement ce qu'il faut savoir pour la suite — **le blocage de Waydroid
n'est pas « pas de bureau », c'est « pas de GPU »**, et cela ne se lève qu'au
jalon 3, sur du vrai matériel.

**Et le bureau a été regardé, à 19 h 31.** `bureau-2026-08-20.png`, versionnée
au dépôt : Plasma affiché, fond d'écran de Bazzite, barre des tâches portant
Vivaldi et Steam, et Steam ayant ouvert sa fenêtre de connexion par-dessus.
C'est la première image de S en fonctionnement, et elle dit exactement le
contraire de ce que le carnet affirmait la veille.

**La leçon de méthode est plus large que le cas.** Une capture d'écran est une
observation, pas un diagnostic ; j'en avais tiré une cause, qui est restée
écrite quinze heures et a essaimé dans deux autres sections. Trois commandes de
journal suffisaient — c'est la règle 7, et je l'ai enfreinte sur mon propre
carnet. Le correctif tient en une phrase : **une capture noire prouve qu'on n'a
rien vu, jamais qu'il n'y a rien.**

### `paths-ignore` surprend deux fois plutôt qu'une

Le filtre `paths-ignore: '**.md'` du workflow fait exactement ce qu'on lui
demande — ne pas reconstruire pour une virgule dans la documentation — mais il
produit deux effets qu'on ne prévoit pas :

1. **Le premier push d'une branche neuve ne déclenche rien.** Il n'y a pas de
   commit précédent auquel comparer les chemins. Constaté à la création du
   dépôt ; le `workflow_dispatch` sert de rattrapage.
2. **Un commit qui ne touche que de la documentation n'a aucune exécution de
   CI.** Évident après coup, mais une automatisation qui attend « le CI du
   dernier commit » attend alors indéfiniment. Constaté le 2026-08-20 : une
   chaîne de vérification a abandonné au bout de quinze minutes, alors que
   l'image voulue était construite depuis longtemps — sous le **commit
   précédent**.

**Chercher l'exécution par le SHA du dernier commit qui touche le code**, pas
par celui de `HEAD`.

---

## 2026-08-20, 05 h 40 — le jalon 2 est atteint, et prouvé de l'intérieur

**S installé depuis le registre, démarré, joint par SSH, et interrogé.** Voici ce
qu'il répond.

```
systeme : Bazzite            noyau : 7.1.5-ogc5.1.fc44.x86_64

bootc status
  spec.image.image     : ghcr.io/gigigrenier86/s-os:latest
  spec.image.transport : registry

CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"

/usr/bin/waydroid-launcher              present
glibc-langpack-fr, hunspell-fr          installes
bazzite-hardware-setup  TimeoutStartUSec=15min  Result=success

Startup finished in 4.495s (kernel) + 4.570s (initrd) + 20.233s (userspace)
                  = 29.299s ; graphical.target reached after 20.233s
0 unites en echec
```

**`bootc status` est la ligne qui compte le plus** : le système installé sait
qu'il est `s-os` et sait où chercher ses mises à jour. `bootc upgrade` fonctionnera.

### Une limite du banc, à ne pas confondre avec un défaut de S

**Le redémarrage à chaud dans QEMU ne repart pas.** Après l'unique redémarrage
que `bazzite-hardware-setup` provoque au premier démarrage, la machine virtuelle
n'écrit plus rien : `reboot: Restarting system` est la dernière ligne, et la
suite ne vient jamais.

**Un démarrage à froid, lui, aboutit toujours** — vérifié deux fois, 25 à 29
secondes jusqu'à l'invite de connexion.

La cause probable est le montage `-bios`, dont les variables UEFI ne survivent
pas : c'est la contrepartie connue du contournement de WHPX, consignée dans
`banc/`. **Ce n'est pas un défaut de S**, et il faut le dire clairement, parce
que le symptôme — machine muette après un redémarrage — ressemble exactement à
une panne du système.

*Conséquence pratique pour le banc :* après une installation, **éteindre et
relancer QEMU** plutôt qu'attendre que la machine revienne d'elle-même.

### Les trois mesures qui valent d'être retenues

| | |
|---|---|
| Installation complète, par `bootc install` depuis le registre | **35 minutes** |
| Premier démarrage — lit le matériel, pose un karg, redémarre | **2 min 43 s** |
| Démarrages suivants | **29 secondes**, dont 20 en espace utilisateur |

---

## 2026-08-20, 15 h 45 — un navigateur, RapidO, et `bootc upgrade` éprouvé

Trois choses en une passe, à la demande de l'utilisateur.

### `bootc upgrade` fonctionne, et c'est le résultat le plus important

Jamais exercé jusqu'ici. Sur un S installé, vers l'image reconstruite :

```
layers already present: 128; layers needed: 2 (342.5 MB)
Deploying...done (55 seconds)
Queued for next boot
Added layers: 2  (342.5 MB)   Removed layers: 1  (145.5 MB)
```

**Deux couches sur cent trente.** 342 Mo au lieu des 5,4 Go de l'image entière,
et 55 secondes de déploiement. À partir de maintenant, **chaque commit devient
une version installable sans réinstallation** — c'est ce qui rend le projet
tenable dans la durée.

*Rappel du banc :* il faut ensuite **éteindre et relancer QEMU à froid**, le
redémarrage à chaud ne repartant pas.

### S n'avait aucun navigateur, et le mécanisme prévu ne délivre pas

Bazzite prévoit Firefox — il est dans `/usr/share/ublue-os/bazzite/flatpak/install`.
Mais son gestionnaire a tourné **5,6 s sans rien poser**, puis a écrit ses
marqueurs dans `/etc/bazzite/`. Sa condition `[[ -f $VER_FILE && $VER = $VER_RAN ]]`
sera donc vraie à tous les démarrages suivants : **il ne réessaiera jamais.**

Troisième script Bazzite pris en défaut de la même manière — `hardware-setup`,
`flatpak-manager` — parce qu'ils supposent un premier démarrage fabriqué
autrement que par `bootc install`. **La règle qui s'en dégage : ce dont S a
besoin entre dans l'image, jamais dans un mécanisme de premier démarrage.**

### Vivaldi, et le détour obligé par `/opt`

Première tentative, échouée :

```
[RPM] failed to open dir opt of /opt/: cpio: mkdir failed - File exists
[RPM] unpacking of archive failed on file /opt/vivaldi
```

Deux contraintes se croisent, et aucune n'est un bogue :

1. **`/opt` est un lien vers `var/opt`** sur un système ostree, et **RPM refuse
   de dépaqueter à travers un lien symbolique** — durcissement délibéré contre
   une classe de failles.
2. **`/var` n'entre pas dans une image `bootc`** : il est propre à la machine et
   recréé à l'installation. Même en forçant, les fichiers n'y seraient pas.

Le détour, en quatre temps, dans `25-navigateur.sh` :

```bash
OPT_CIBLE="$(readlink /opt || echo var/opt)"   # relire, ne pas supposer
rm -rf /opt && mkdir -p /opt                   # un vrai dossier
dnf5 install -y vivaldi-stable
mv /opt/vivaldi /usr/lib/opt/vivaldi           # /usr, lui, EST l'image
rm -rf /opt && ln -s "${OPT_CIBLE}" /opt       # remettre comme ostree l'attend
# puis un tmpfiles.d qui refait le pont a chaque demarrage :
#   L  /var/opt/vivaldi  -  -  -  -  /usr/lib/opt/vivaldi
```

**Vérifié sur le système installé**, après redémarrage :

```
/var/opt/vivaldi        -> /usr/lib/opt/vivaldi        (cree au demarrage)
/usr/bin/vivaldi-stable -> /usr/lib/opt/vivaldi/vivaldi   et executable
Vivaldi 8.1.4087.68 stable
```

**Les codecs propriétaires se posent chez l'utilisateur**, pas dans l'image :
`/root/.local/lib/vivaldi/media-codecs-8.1`. C'est le bon comportement sur un
système en lecture seule, et il n'a rien demandé pour l'obtenir.

*Note de licence, ce dépôt étant public :* la page Vivaldi destinée aux
distributions Linux dit qu'aucun accord n'est nécessaire pour l'intégrer — Manjaro
et FerenOS le livrent par défaut — tandis que son CLUF interdit la
redistribution. Les deux textes se contredisent ; c'est consigné dans le script,
et une seule ligne suffirait à passer à une pose au premier démarrage.

### RapidO : 396 lignes de WPF deviennent neuf lignes de `.desktop`

RapidO est l'application de l'utilisateur, dans le dépôt PC Boost : une fenêtre
WebView2 épinglée sur `https://app.mews.com/`, avec une barre d'état qui mesure
les temps de chargement.

**Le code ne peut pas être porté.** Son `.csproj` cible `net8.0-windows` avec
`<UseWPF>true</UseWPF>` : **WPF n'existe pas sous Linux et n'y existera pas.**
WebView2 non plus, n'étant qu'une enveloppe autour du moteur Edge du système.

**Mais sa raison d'être est satisfaite sans écrire une ligne**, et c'est son
propre commentaire de `.csproj` qui la formule :

> « le moteur, lui, est le runtime WebView2 déjà installé par Windows. C'est
> toute la différence avec Electron, qui embarque son Chromium et pèse 225 Mo. »

C'est exactement ce que fait `vivaldi --app=` : une fenêtre sans chrome, servie
par le moteur **déjà présent**. `--class=RapidO` et `StartupWMClass=RapidO` lui
donnent son identité propre dans la barre des tâches — elle reste *une
application*, pas un onglet déguisé.

**Ce qui est perdu, et qui est nommé plutôt que passé sous silence :** `Perf.cs` et ses mesures —
temps de navigation, mémoire par processus, version du moteur en barre d'état.

### Une remarque sur les pilotes, et pourquoi elle était un faux problème

L'utilisateur a constaté des pilotes manquants **en regardant la machine
virtuelle**. Relevé : **7 périphériques PCI sur 8 ont un pilote chargé**, et le
huitième est le pont hôte — le contrôleur mémoire, qui n'en a pas besoin.

Ce qui manquait n'était pas des pilotes mais du matériel : QEMU expose une carte
Bochs, des disques virtio et un chipset ICH9 émulé. **Une machine virtuelle ne
peut rien dire des pilotes de la machine réelle**, et c'est encore une raison
pour laquelle le jalon 3 attend un vrai disque.

---

## 2026-08-20, 17 h 40 — six outils, prêts dès la première connexion

Demande de l'utilisateur : *« du prêt au moment même où je me connecte pour la
première fois »*. Tout entre dans l'image ; rien n'est différé.

| Outil | Version | Où il vit | Signature |
|---|---|---|---|
| VS Code | 1.134.0 | `/usr/share/code` (1,1 Go) | dépôt Microsoft, **signé** |
| Node.js | v24.18.0 | `/usr/bin` | Fedora |
| Gemini CLI | 0.56.0 | `/usr/lib/node_modules` (100 Mo) | npm |
| Claude Code | 2.1.228 | `/usr/bin/claude` | **dépôt RPM officiel signé** |
| Antigravity | 1.23.2 | `/usr/share/antigravity` (682 Mo) | **aucune — `gpgcheck=0`** |
| RetroArch | 1.22.0 + 14 cœurs | `/usr/lib64/libretro` | Fedora |
| Zoom | — | `/usr/lib/opt/zoom` (918 Mo) | clé Zoom |
| *(Vivaldi)* | 8.1.4087.68 | `/usr/lib/opt/vivaldi` (438 Mo) | dépôt Vivaldi |

**Antigravity est le seul binaire de cette image qui entre sans signature.**
Le dépôt Google impose `gpgcheck=0` ; le transport est du HTTPS vers `pkg.dev`,
donc le serveur est authentifié, le contenu ne l'est pas. **Décision prise en
connaissance de cause par l'utilisateur**, écrite dans le script et ici pour
que ce soit un choix et non un oubli.

### La clé de voûte : sur ostree, tout ce qui est modifiable est un lien

Relevé sur le système installé :

```
/opt        -> var/opt          /home  -> var/home
/usr/local  -> ../var/usrlocal  /srv   -> var/srv
/root       -> var/roothome     /mnt   -> var/mnt
```

**Et `/var` n'entre pas dans l'image.** Ce n'est donc pas une collection de
pièges séparés mais **un seul principe**, qui explique d'un coup l'échec de
Vivaldi sur `/opt`, celui de npm sur `/usr/local`, et le risque qu'aurait couru
l'installateur de Claude Code écrivant dans `$HOME` = `/root`.

**`/etc` en est l'exception, et c'est heureux** : ce n'est pas un lien, il est
stocké dans le commit sous `/usr/etc` et fusionné au déploiement. C'est donc un
emplacement sûr — d'où `/etc/skel`.

### Le pire résultat n'est pas l'échec, c'est le succès silencieux

Forcer une installation vers `/opt` ou `/var/usrlocal` **marche** : la
construction réussit et l'image ne contient rien. Le contenu de `/var` présent
dans une image se comporte comme un volume Docker — déversé à l'installation
initiale seulement, figé à cette version, et totalement absent pour une machine
qui se met à jour.

Un échec bruyant se corrige. Celui-là se découvre trois mois plus tard.

**D'où le contrôle ajouté à chaque script**, qui fait échouer la construction
plutôt que de livrer une image creuse :

```bash
rpm -ql <paquets> | grep -E '^/(var|opt)/|^/usr/local/' \
  && { echo "ECHEC: fichier hors /usr et /etc"; exit 1; } || true
```

### Un préfixe configurable bat toujours un déplacement

Le détour `/opt` — déplier, installer, `mv`, restaurer, poser un `tmpfiles.d` —
n'a servi qu'à **deux** logiciels sur huit : Vivaldi et Zoom. Partout ailleurs
un levier existait :

| Outil | Levier |
|---|---|
| npm | `npm_config_prefix=/usr` |
| VS Code CLI | `--extensions-dir` |
| Claude Code | le paquet RPM, qui vise `/usr/bin` |

**Vérifier avant de contourner.** Le contrôle coûte une commande ; le détour
appliqué inutilement ajoute du risque pour rien.

Et le réglage doit rester **local au script** : un `npm config set prefix -g`
écrirait `/etc/npmrc` dans l'image et casserait le `npm i -g` de l'utilisateur
après le démarrage — lui doit viser `/usr/local`, qui est justement inscriptible
une fois la machine installée. *Ce qu'on force pour construire ne doit jamais
devenir la configuration de la machine.*

### `/etc/skel`, et ce qu'il coûte

Les logiciels entrent dans l'image ; les **extensions d'éditeur**, elles, vivent
dans le dossier personnel. `/etc/skel` est le squelette recopié dans le dossier
de **chaque compte créé** — le seul mécanisme à la fois durable et personnel.

Y sont posés : l'extension **Claude Code**, le **pack de langue français**, et
un `argv.json` portant `{"locale":"fr"}` qui ouvre l'éditeur en français sans
qu'on le lui demande. VS Code n'écrase jamais un `argv.json` existant :
l'utilisateur garde la main.

**Coût mesuré : 337 Mo, recopiés pour chaque compte créé.** Sans conséquence
sur une machine à un utilisateur ; à surveiller au-delà. Réductible en posant
les extensions à l'échelle du système, au prix de ne plus pouvoir les
désinstaller individuellement.

**`google.geminicodeassist` a été écartée** : environ 178 Mo par compte, et
Google aurait basculé ses paliers individuels vers Antigravity à la mi-2026 —
*information rapportée, non vérifiée ici*. Gemini reste servi par sa CLI et par
son lanceur en fenêtre dédiée.

**Limite à connaître :** `/etc/skel` ne sert que les comptes créés **après** le
déploiement. Un compte existant ne reçoit rien.

### Ce que le démarrage coûte, et ce qu'il ne coûte pas

| Démarrage | Durée |
|---|---|
| Avant les six outils | 26 s |
| **Juste après une mise à jour d'image** | **58 s** |
| Suivant, stabilisé | **35 s** |

Les 58 secondes ne sont pas une régression mais un **coût unique** :
`ldconfig.service` reconstruit le cache de l'éditeur de liens (19,4 s) parce que
de nouvelles bibliothèques sont apparues, et `bootloader-update.service` met à
jour le chargeur (16,0 s). `systemd-update-done` les marque faits ; le démarrage
suivant les saute.

**Ne pas prendre ce coût pour un défaut** — c'est exactement le genre de chiffre
qui, lu une seule fois, ferait condamner à tort une image saine.

Les trois services les plus lents en régime sont des attentes de périphériques
`ttyS0` et `vda` à ~10,9 s : du **bruit de QEMU**, pas de S.

### Mes erreurs de cette passe, et comment elles ont été prises

Six enquêtes menées en parallèle, puis **chaque affirmation vérifiée sur le
système installé** plutôt que crue sur parole — y compris celles des enquêtes,
qui se terminaient elles-mêmes par « aucune de ces recettes n'a été construite ».

1. **RetroArch n'est pas dans RPM Fusion** mais dans les dépôts Fedora
   (1.22.0-20.fc44). Ma vérification précédente avait été mal lue, la sortie
   étant coupée. Toute la dépendance à RPM Fusion disparaît.
2. **Cinq noms de cœurs sur six étaient inventés** : `libretro-snes9x`,
   `beetle-psx`, `genesis-plus-gx`, `mupen64plus`, `flycast` n'existent nulle
   part. Quatorze cœurs existent. Le SNES passe par `bsnes-mercury`, la PS1 par
   `pcsx-rearmed` ; **Mega Drive, N64 et Dreamcast ne sont couverts par aucun
   paquet.**
3. **`retroarch-joypad-autoconfig` n'existe pas** — les profils de manettes sont
   déjà dans le paquet `retroarch`.
4. **Fedora 44 versionne Node** : `/usr/bin/node` vient de `nodejs20-bin`.
   L'installation se fait donc **par le chemin**, ce qui a d'ailleurs résolu en
   v24 plutôt qu'en v20 — et survivra au prochain changement.
5. **VS Code exige `--user-data-dir`**, seul drapeau levant son garde-fou root.
   `--no-sandbox` est inutile : `--install-extension` ne démarre jamais Chromium.

### Une ligne cosmétique ne doit jamais faire tomber une image saine

Une construction a échoué alors que **tout** s'était correctement installé : la
ligne qui rapportait les versions appelait `code --version` en root sans
`--user-data-dir`, ce qui sort en 1, ce que `set -e` a transformé en échec.

Toutes les lignes de rapport se terminent désormais par `|| true`. **Les
assertions, elles, restent bloquantes** — ce sont les seules qui doivent l'être.

### Ce qui manque encore, et que cette demande a révélé

**S n'a aucun compte utilisateur.** `bootc install` n'en crée pas ; seul `root`
existe, joignable par clé SSH. Personne ne peut donc ouvrir de session — et
`/etc/skel`, qui ne sert que les comptes créés après le déploiement, **n'a
encore servi à personne**.

C'est le dernier maillon manquant de « prêt dès la première connexion », et
c'est un vrai choix : inscrire le compte dans l'image, ou faire poser la question
au premier démarrage par `systemd-firstboot`.

---

## 2026-08-20, 18 h — la création de compte à l'installation existait déjà

**Rien n'a été construit pour ça, et c'est le bon résultat.** L'image de base
porte déjà l'assistant, et il a fonctionné : l'utilisateur a créé son compte
`Ghis` à 14 h 48 en répondant aux questions posées à l'écran — langue, clavier
`ca`, compte, nom de machine `ThinkCentre720Q`.

Le mécanisme est **`plasma-setup.service`** :

```
Description=Plasma Setup - Out-of-Box / First-Run setup wizard
Before=display-manager.service
ConditionPathExists=!/etc/plasma-setup-done
ConditionKernelCommandLine=!rd.live.image
Type=oneshot
ExecStart=/usr/libexec/plasma-setup-bootutil
```

Il s'exécute **avant le gestionnaire de session**, une seule fois, et se
désarme en écrivant `/etc/plasma-setup-done`.

### Le piège à ne jamais créer

**`/etc/plasma-setup-done` ne doit JAMAIS entrer dans l'image.** Vérifié le
2026-08-20 : `/usr/etc/plasma-setup-done` est absent, donc une installation
neuve relance bien l'assistant. Si un script de construction venait à créer ce
fichier — même par mégarde, en copiant un `/etc` complet — **toute installation
neuve démarrerait sans compte utilisateur et sans moyen d'en créer un.**

C'est le genre de régression qui ne se voit pas avant la machine suivante.

### Ce que la recherche a coûté, et la leçon

Une enquête à quatre pistes avait été lancée sur « comment créer un compte à
l'installation » avant que l'utilisateur ne signale que le système le lui avait
déjà demandé. Elle a été arrêtée en cours de route.

**Regarder la machine avant de chercher une solution** : le service était
`enabled`, le marqueur était daté, et le journal nommait `plasma-setup` en
clair. Trois commandes suffisaient.

### Ce que /etc/skel ne rattrape pas tout seul

Le compte `Ghis` date de **14 h 48** ; les extensions VS Code sont entrées dans
l'image à **17 h 38**. `/etc/skel` ne servant que les comptes créés *après* le
déploiement, le dossier personnel ne les avait pas.

Recopiées à la main sur ce compte — `anthropic.claude-code`,
`ms-ceintl.vscode-language-pack-fr`, `argv.json` — avec `chown` et `restorecon`.
336 Mo.

**À retenir pour toute addition future à `/etc/skel` :** elle ne touchera aucun
compte existant. Soit on l'applique à la main, soit on écrit un service qui
réconcilie — et ce service devra être idempotent, sans marqueur qui l'empêche de
rejouer, contrairement à ceux de Bazzite.

## 2026-08-20, 21 h — le jalon 5 : un double-clic suffit

Demande de l'utilisateur, et c'est le cœur du projet : *« je veux une OS où c'est simple
d'installer un .exe et l'utiliser, sans passer par des applis tierces — ça peut être fait
en tâche de fond sans qu'on le voie. Qu'il y ait une solution ou pas, faut en trouver
une. »*

**La solution existait déjà, en pièces détachées.** Le relevé de la machine installée l'a
montré avant qu'une ligne soit écrite : les quatre moteurs sont dans la base — `umu-run`
(lance un `.exe` sous Proton **sans Steam ni Lutris**), `distrobox` + `podman`, `flatpak`,
`waydroid`. Ce qui manquait n'était pas un moteur, c'était la **couture** entre le geste
et lui.

### Ce que la machine disait, avant

| Double-clic sur… | Ce qui se passait | Verdict |
|---|---|---|
| `.exe` `.msi` | **rien du tout** | aucun gestionnaire déclaré |
| `.deb` | s'ouvrait dans **l'archiveur** | pire que rien : ça *semble* marcher |
| `.AppImage` | rien | type MIME même pas déclaré sur Fedora |
| `.flatpak` | ouvrait un magasin graphique | fonctionnel, mais c'est un tiers qui s'affiche |
| `.apk` | installait dans Waydroid | **déjà bon**, hérité de la base |

### Ce qui a été écrit

Neuf fichiers, tous dans `/usr` et `/etc` — rien dans `/var`, que l'image ne transporte pas.

| Fichier | Rôle |
|---|---|
| `s-monde` | Le socle : chemins, verrou, notifications. Une couture ne montre **jamais** son moteur |
| `s-ouvrir-exe` | `.exe` et `.msi` par `umu-run`, dans un préfixe unique — « le Windows de S » |
| `s-menu-windows` | Moissonne les raccourcis de Wine et les **répare** — voir plus bas |
| `s-ouvrir-paquet` | `.deb` et `.rpm` dans un conteneur invisible, puis `distrobox-export` |
| `s-ouvrir-appimage` | Range, rend exécutable, extrait l'icône enfermée dedans |
| `s-ouvrir-flatpak` | Installe en silence, sans ouvrir de magasin |
| `s-android` | Initialise Waydroid en **GAPPS**, démarre la session, pose F-Droid |
| `s-play-store` | Lit l'identifiant Google, le copie, ouvre la page d'enregistrement |
| `40-coutures.sh` | Repose les bits d'exécution, pose F-Droid, reconstruit les index MIME |

### Le piège que personne ne mentionne

**Wine pose bien les raccourcis du menu Démarrer tout seul** — `winemenubuilder` écrit de
vrais `.desktop` dans `applications/wine/`. Mais leur ligne `Exec` appelle **`wine`, qui
n'existe pas sur ce système** : Proton est fourni par umu, pas par un paquet Fedora.
L'utilisateur verrait donc des icônes apparaître dans son menu et **ne rien lancer** —
le pire des échecs, celui qui a l'air d'une réussite.

`s-menu-windows` les réécrit pour qu'elles repassent par `s-ouvrir-exe`. Il ne
reconstitue pas le chemin Windows depuis `Exec`, dont les échappements de Wine sont
retors : il prend le dossier dans `Path=`, déjà côté Linux, et n'y ajoute que le nom du
binaire. Plus court et plus sûr.

### Le Play Store, et ce qui ne s'automatise pas

**Il est déjà là** : le Play Store vit dans l'image système Android, variante GAPPS, que
`waydroid init -s GAPPS` télécharge. Aucun dépôt RPM n'y donne accès — le dépôt Google du
projet sert à Antigravity et n'a rien à voir.

Ce qui reste est une exigence de **Google, pas de S** : le Play Store refuse de servir un
appareil non certifié, et l'identifiant doit lui être déclaré une fois, par un humain
connecté à son compte. **Aucun contournement n'existe**, et en inventer un serait mentir.
`s-play-store` fait les quatre cinquièmes : il lit l'identifiant dans la base de Google
Services Framework, le met dans le presse-papiers et ouvre la page. Il reste un collage et
un clic, **une fois dans la vie de la machine**.

**F-Droid est posé en plus**, et pas par préférence : c'est la seule boutique Android dont
l'APK ait une URL stable et vérifiable (`f-droid.org/F-Droid.apk`, HTTP 200 vérifié).
Aurora Store, qui aurait donné le catalogue Play sans compte Google, **a été écarté faute
de provenance** — leur site est une application JavaScript sans lien direct, aucun dépôt
GitHub, et leur dépôt F-Droid ne répond plus. Deviner l'URL d'un binaire est précisément
ce que ce projet s'interdit.

### Deux défauts trouvés en relevant la machine, pas en supposant

- **`sudo -n` échoue toujours en session graphique.** Il refuse par construction de
  demander un mot de passe, et il n'y a pas de terminal pour le taper. C'est `pkexec` qu'il
  faut — il ouvre une fenêtre, ce qui est le comportement normal sous Linux pour un geste
  système.
- **`dpkg-deb` n'existe pas sur une Fedora.** Le script lisait le nom du paquet avec, sur
  l'hôte, pour savoir quelles icônes exporter. Il aurait rendu une chaîne vide : le `.deb`
  se serait installé correctement et **aucune icône ne serait apparue**, sans le moindre
  message. Le nom se lit désormais dans le conteneur, où `dpkg-deb` est chez lui.

### Éprouvé pour de vrai, dans la machine installée — 22 h

Le banc a tourné sur la VM elle-même, `/usr` déverrouillé par `ostree admin unlock`.

**Les six associations sont effectives**, vérifiées une à une par
`xdg-mime query default` : `.exe`, `.msi`, `.deb`, `.rpm`, `.AppImage` et `.flatpak`
pointent tous vers leur couture. Le `.apk` reste sur Waydroid, comme voulu.

**Le chemin `.deb`, de bout en bout.** Conteneur Debian créé en **17 s**, un vrai paquet
Debian tiré depuis `deb.debian.org` (`galculator 2.1.4-2`, 171 ko), installé par
`s-ouvrir-paquet` en **10,5 s**, et `s-debian-galculator.desktop` posé dans le menu de
l'hôte avec son icône, ses catégories et son `StartupWMClass`. Rien de tout cela n'a
demandé un geste de plus que le double-clic.

**Le chemin `.exe`.** Le préfixe et Proton se posent en **3 min 02** au premier usage —
**793 Mo** téléchargés, dont umu vérifie lui-même le SHA512. Ensuite `cmd.exe`, un vrai
binaire PE Windows, **s'exécute et rend la main** : `umu-run` propage les codes de sortie
exactement, vérifié en demandant 0 puis 7 et en obtenant 0 puis 7. C'est la preuve qui
compte — un programme Windows tourne, lancé par la couture, sans qu'aucun programme tiers
ne s'ouvre.

**Le moissonneur.** Éprouvé sur un fichier reproduisant **octet pour octet** ce
qu'écrit `winemenubuilder` — `Exec` appelant `wine`, chemin Windows à barres inverses
doublées, `Path` passant par `dosdevices`. Il en a tiré le bon binaire et réécrit le
lanceur vers `s-ouvrir-exe`. C'était la pièce la plus risquée, puisque écrite ici.

### Trois défauts que seul l'essai pouvait montrer

- **`distrobox-export` montrait le moteur.** L'application arrivait au menu sous le nom
  « Galculator (on s-debian) », et un lanceur pour le conteneur lui-même s'ajoutait à
  côté. L'utilisateur a installé une calculatrice, pas un conteneur Debian : les deux
  traces sont effacées après l'export.
- **`tr` avertissait sur la sortie visible.** « barre oblique inverse non protégée » à
  chaque passage du moissonneur. La barre est désormais doublée dans l'argument, puisque
  `tr` interprète lui-même les échappements.
- **`notepad.exe` sort en 1 au banc**, sans une ligne d'erreur de Wine. Ce n'est pas la
  couture : `cmd.exe` passe, et les codes de sortie sont fidèles. Le bureau tourne bien
  (voir 22 h 30) mais **en rendu logiciel `llvmpipe`** ; une fenêtre Wine par-dessus
  n'aboutit pas. À reprendre sur du vrai matériel.

### Ce qui reste non prouvé

1. **Waydroid n'a jamais tourné**, ni le Play Store, ni `s-play-store`. Android exige une
   accélération graphique que le banc n'a pas. C'est le jalon 3, donc le SSD.
2. **`s-ouvrir-appimage` et `s-ouvrir-flatpak` n'ont jamais été exécutés.** Leur
   association est déclarée et effective ; le geste lui-même, non.
3. **Aucun installateur Windows réel n'a été posé.** Le moissonneur est éprouvé sur une
   entrée fabriquée fidèle, pas sur ce qu'un vrai `setup.exe` produit.
4. **Le premier usage du monde Windows coûte encore 793 Mo et quelques minutes.**
   Le compte exact, mesuré : 1,4 Go de Proton **et** 793 Mo de runtime Steam, soit 2,2 Go
   en tout. Proton est désormais **dans l'image** — son archive de 468 Mo s'y déplie sans
   réseau. Le runtime, lui, se télécharge toujours : umu post-traite sa mise en place, et
   refaire cela à la main serait fragile. Debian (~150 Mo) et Android (~1 Go) restent
   entiers. Tout cela vit dans `/var`, que l'image ne transporte pas — contrainte
   d'ostree, pas un oubli.

**Une voie de pré-cuisson a été essayée et ferme définitivement** : poser Proton déplié
sous `/usr` et y pointer `PROTONPATH`. Pressure-vessel **réserve `/usr`** et refuse de le
partager dans son conteneur — voir « Pièges rencontrés ». Restent possibles, non faites :
le magasin d'images en lecture seule de podman pour Debian
(`additionalimagestores`, présent dans `/usr/share/containers/storage.conf`), et
`waydroid init -i` pour Android.

### L'image publiée porte bien ce qu'on croit — 23 h

« La CI est verte » n'est pas « l'image le contient ». Un `bootc upgrade` réel a
donc été mené jusqu'au bout dans la machine, et le déploiement en attente relu
fichier par fichier :

| Dans le déploiement téléchargé | |
|---|---|
| `/usr/lib/s/windows/proton.tar.gz` | **491 237 448 octets** |
| `/usr/lib/s/windows/proton.version` | `UMU-Proton-10.0-4` |
| Les huit gestes `s-*` | présents, tous `-rwxr-xr-x` |
| `/usr/share/s/apk/fdroid.apk` | 12 426 276 octets |
| `/etc/xdg/mimeapps.list` | les onze types déclarés |

**Et c'est cette mise à jour qui a révélé le défaut de couches** :
`layers needed: 2 (2.3 GB)`. Voir la règle 11.

### Ce que pèse chaque couche — relevé du manifeste, 23 h 50

Le manifeste se lit sans rien télécharger : un jeton anonyme sur `ghcr.io`, puis
`/v2/<dépôt>/manifests/latest`. **137 couches, 6,95 Go** au total, dont 128
viennent de Bazzite. Les neuf dernières sont les nôtres, et l'ordre du
`Containerfile` s'y lit directement :

| Couche | Poids | Ce qu'elle porte |
|---|---|---|
| 129 | **0,0 Mo** | `20-android` — il ne fait que vérifier, et ça se voit |
| 130 | 235,0 Mo | Vivaldi |
| 131 | 773,4 Mo | VS Code, Antigravity, Node, Gemini CLI, Claude Code |
| 132 | 647,3 Mo | RetroArch et ses cœurs, Zoom |
| 133 | **468,3 Mo** | l'archive de Proton — le compte tombe juste |
| 134 | 106,6 Mo | `/etc/skel` et les extensions VS Code |
| 135 | 0,0 Mo | `COPY files/ /` — les gestes eux-mêmes |
| 136 | **9,6 Mo** | les coutures, F-Droid compris |

**C'est la preuve du découpage** : retoucher un geste ne touche plus que les
couches 135 et 136, soit **9,6 Mo au lieu de 2,3 Go**. Et lire un manifeste coûte
une requête, là où le mesurer par `bootc upgrade` coûtait une demi-heure de
téléchargement dans le banc.


## 2026-08-20, 21 h 30 — la clé USB, et les cinq murs de Windows

**Décision de l'utilisateur : tester sur sa clé USB plutôt que d'attendre le SSD.**
Le plan écartait la clé — la mémoire flash s'effondre en écriture aléatoire — et cet
argument reste vrai **pour un usage quotidien**. Pour un test d'une heure, il ne tient
pas : la clé répond exactement aux trois questions que le banc ne peut pas trancher.

**La clé n'était plus l'installateur Windows.** Le carnet de PC Boost la protégeait
depuis le 2026-08-18 (`CCCOMA_X64F`, FAT32, 1 066 fichiers, 31 minutes de travail).
Relevée ce soir : une seule partition **exFAT de 57,3 Go, vide**. Elle a été reformatée
entre-temps. Il n'y avait donc rien à protéger — mais **il fallait regarder avant de le
dire**, et non se fier à ce que le carnet affirmait deux jours plus tôt.

### La cible, vérifiée trois fois avant d'écrire

Une seule erreur ici coûterait le Windows de la machine. Trois preuves indépendantes :

| Preuve | `vda` (la VM) | `vdb` (la clé) |
|---|---|---|
| Taille exacte | 53 687 091 200 o | **61 524 148 224 o** = 57,3 Go |
| Système de fichiers | btrfs | **exFAT** |
| Rôle | porte `/sysroot`, `/boot`, `/var` | monté nulle part |

Et une garantie qui ne dépend d'aucune vérification : **le NVMe interne n'a jamais été
présenté à la machine virtuelle.** Même une faute de frappe à l'intérieur ne peut pas
l'atteindre. C'est de la sécurité par construction, pas par vigilance.

### Cinq murs, dans l'ordre où ils sont tombés

Aucun n'est propre à S ; tous se reposeront à la prochaine manipulation de disque
physique depuis Windows.

1. **La stratégie d'exécution refuse les `.ps1`.** `powershell -ExecutionPolicy Bypass
   -File …` lève la règle pour ce seul processus, sans rien changer sur la machine.
2. **Un `.ps1` en UTF-8 casse sous PowerShell 5.1**, qui le lit en CP1252 : le tiret
   cadratin devient un délimiteur de chaîne et la ligne cesse d'être analysée — d'où un
   `-ForegroundColor Cyan` affiché en clair. Le piège est écrit noir sur blanc dans le
   carnet de PC Boost, et je l'ai quand même commis. **Les scripts de banc s'écrivent en
   ASCII strict**, et un contrôle `ParseFile` avant lancement coûte une seconde.
3. **Windows refuse de mettre un média amovible hors ligne** — « Removable media cannot
   be set to offline ». Ce qui verrouille le disque physique n'est pas le disque mais le
   **volume monté** dessus — et **retirer la lettre ne le démonte pas** : cela enlève le
   point de montage, pas le montage. Mesuré le 2026-08-20, QEMU tenant déjà le disque
   ouvert : `mountvol` annonçait « Aucun point de montage » tandis que `Get-Volume`
   rendait encore un exFAT sain de 61 519 953 920 octets avec son espace libre vivant.
   Windows refuse alors toute écriture par handle de disque sur les secteurs de la
   partition, et QEMU n'émet ni `FSCTL_LOCK_VOLUME` ni `FSCTL_DISMOUNT_VOLUME`.
   Il faut **supprimer la partition** : sans volume, le disque redevient inscriptible de
   bout en bout, et `bootc` écrit lui-même la table depuis l'intérieur.

   **Ce défaut aurait été le pire de la série**, parce qu'il échoue à moitié : la table
   de partition, elle, se serait écrite — secteurs 0 à 2047, hors partition, donc
   autorisés — puis l'écriture de l'ESP aurait été refusée. Après le téléchargement, et
   en laissant la clé sans table **et** sans système. Windows l'aurait annoncée « non
   initialisée ». D'où la sonde d'écriture de `poser-sur-cle.sh`, qui réécrit à
   l'identique le secteur 2048 et le dernier **avant** d'engager quoi que ce soit.
4. **L'accès brut à un disque physique exige l'élévation.** Sans elle, QEMU rend
   « Could not open device: Permission denied » — mais **trois étapes trop tard**, la clé
   ayant déjà été démontée. Le contrôle d'élévation est passé en tête du script : un refus
   doit tomber avant qu'on ait touché à quoi que ce soit. Et il teste le **rôle**, jamais
   le nom du groupe, qui s'appelle « Administrateurs » sur un Windows français.
5. **QEMU lancé en processus enfant meurt avec sa fenêtre.** Fermer le terminal a coûté
   sept minutes de démarrage. `Start-Process -PassThru` le détache — en passant les
   arguments par un tableau dont **aucun ne contient d'espace**, puisque `Start-Process`
   les joint sans les protéger.

### Où ça en est

`banc/poser-sur-cle.ps1` écrit S sur la clé depuis la VM, et refait le contrôle de taille
**à l'intérieur, juste avant d'écrire** — l'inventaire d'un appelant ne se tient jamais
pour acquis. Le script est écrit, sa syntaxe validée, et **il n'a pas encore été lancé** :
l'écriture est un geste de l'utilisateur, pas du mien.

**Ce que ce test doit trancher**, et qu'aucune machine virtuelle ne peut dire :

1. **S démarre-t-il sur du vrai matériel.** Un firmware virtuel prouve qu'un support est
   amorçable ; il ne prouve pas qu'un système démarre.
2. **L'iGPU de la M720q va-t-il mieux sous Linux.** 266 réinitialisations du moteur
   d'affichage en 30 jours sous Windows, conclusion « matériel ». `dmesg` et les compteurs
   `i915` diront si le défaut suit la machine. **Cette réponse vaut aussi pour PC Boost.**
3. **Waydroid tourne-t-il**, et donc le Play Store. C'est la seule chose qui demandait
   exactement ce qui manquait au banc : un vrai GPU. Mesuré au banc, Steam tourne sur
   `llvmpipe`, du rendu logiciel.

### La relecture croisée qui a évité le troisième essai — 2026-08-20, 22 h

Après deux tentatives échouées, la chaîne entière a été soumise à quatre examens
parallèles — les scripts, l'invocation de `bootc`, l'amorçage sur la M720q,
l'environnement — chacun suivi d'un sceptique chargé de **démolir** ce qu'il trouvait.
**17 défauts avancés, 5 confirmés, 12 réfutés.** Le taux de réfutation est le résultat le
plus utile : sans cette seconde passe, douze corrections plausibles et fausses seraient
entrées dans le dépôt. Parmi les réfutées, quatre visaient le garde-fou « la cible porte
la racine » — l'argument, séduisant, était qu'une racine `composefs` ne rend jamais un nom
de périphérique ; il ne tenait pas.

**Deux bloquants, tous deux mesurés :**

- **Le volume Windows, resté monté** — détaillé au mur 3 ci-dessus.
- **La place manquante, et l'échec était déjà au journal du projet.**
  `S-vm/bootc-install.log` porte, ligne 2 : « no space left on device », sur la **même
  image**, à la couche 84 sur 137. Le `pull` paie deux fois sur le même système de
  fichiers — ~7 Gio de blobs compressés dans `$TMPDIR` pendant tout le dépôt, puis les
  couches décompressées dans le magasin, dont le déploiement aplati de 16 Gio est le
  plancher. Pic entre 23 et 26,5 Gio ; il y avait 22,9 Gio. Le script n'appelait `df`
  nulle part.

  Libéré ce soir : `ostree admin undeploy` + `rpm-ostree cleanup` ont rendu **3,15 Gio**
  (dont un dossier de déploiement orphelin, présent sur disque et absent d'`ostree admin
  status`), et le résidu du test des coutures — Steam et le magasin podman de l'essai
  `.deb` — **3,66 Gio** de plus. De 22,9 à **29,4 Gio**.

**Trois majeurs, tous dans la fiche remise à l'utilisateur** — c'est-à-dire dans le seul
document qu'il aura sous les yeux au moment où je ne verrai rien :

- **Le premier démarrage redémarre la machine au bout de 2 min 38 s**, à dessein
  (`bazzite-hardware-setup` pose `bluetooth.disable_ertm=1` puis redémarre). Or **F12 est
  un choix ponctuel, déjà consommé** : la machine repart sur Windows. L'utilisateur aurait
  vu deux minutes d'écran figé puis Windows, et conclu que la clé ne démarre pas — alors
  que S avait parfaitement démarré et n'attendait qu'un second F12.
- **Secure Boot est déjà désactivé** sur cette machine (`UEFISecureBootEnabled = 0`,
  confirmé par msinfo32). La fiche demandait de le vérifier et décrivait un symptôme
  — « Secure Boot violation » — qui **ne peut pas se produire ici** : shim et GRUB sont
  signés par Fedora et passent ; c'est le noyau, signé `O=Universal Blue`, qui serait
  refusé, deux étages plus loin et sans ce message.
- **« La clé n'apparaît pas dans F12 » n'est jamais Secure Boot** : il vérifie les
  signatures au chargement, pas à l'énumération — il ne masque pas un périphérique.

**Ce que ça dit de la méthode.** Les deux bloquants étaient invisibles à la relecture :
l'un se voyait en interrogeant Windows pendant que QEMU tenait le disque, l'autre en
lisant un journal vieux de quinze heures dans le dossier du banc. Aucun n'aurait été
trouvé en relisant le code.
