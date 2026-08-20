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

## 2026-08-19 — le dépôt est créé *(dépassé, voir la section suivante)*

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
autrement.** C'est exactement ce qui vient d'arriver ici, l'accélération 3D
manquant en machine virtuelle.

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
