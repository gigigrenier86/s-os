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

## Où on en est — 2026-08-25

**Android tourne, les deux disques sont entiers à S, et le dossier partagé fait
enfin l'aller-retour.** Trois choses aussi : le dépôt vit désormais **sur la
machine** (`/var/home/RyuRex/S`), ce qui supprime d'un coup les deux pièges du
dépôt édité sous Windows — CRLF et bit d'exécution — et permet de mesurer au
lieu de supposer. La journée l'a fait cinq fois.

### L'espace, alloué

| | Avant | Après |
|---|---|---|
| Racine de S (NVMe) | 70 Go, 166 Gio inutilisés en bout de disque | **236,5 Go**, une seule partition, 188 Go libres |
| Grande partition Seagate | 4,1 To vierges | **ext4 `S-DISQUE`**, montée en `/var/mnt/disque`, `~/Disque` |
| `WINDOWS-S` (sda3) | 500 Go NTFS | **identique au secteur près** — relevé par `sfdisk -d` avant et après |

La racine a été étendue à chaud : `sfdisk -N 3`, `partx -u`, puis `resize2fs`
sur un système de fichiers monté. Aucune commande de la manœuvre n'écrit sur la
table de partition de la Seagate — `s-grand-disque` ne fait que formater une
partition qui existait déjà et qui était vierge.

### Ce qui bloquait Android depuis cinq jours tenait en deux arguments

`s-android` appelait `waydroid init -s GAPPS`. Le paquet Fedora ne fournit
**pas** `/usr/share/waydroid-extra/channels.cfg` — `waydroid-extra` n'est pas
installé — donc `system_channel` et `vendor_channel` valent la chaîne vide, et
l'initialiseur s'arrête sur *« You must provide 'System OTA' and 'Vendor OTA'
URLs »*. Le journal de S le disait depuis le 2026-08-24 à 21 h 56 ; personne ne
l'avait lu.

La recette de l'amont, elle, les passe en clair
(`/usr/share/ublue-os/just/82-bazzite-waydroid.just:33`). **La règle « on ne
réimplémente pas ce que l'amont maintient » vaut aussi pour une ligne de
commande** : S l'avait réécrite en laissant tomber deux arguments.

Corrigé, l'init a tiré 3,0 Go — `system.img` 2,5 Go en GAPPS, `vendor.img`
536 Mo, LineageOS 20 — et **la session Android atteint `RUNNING` en dix
secondes**. Le Play Store est là, F-Droid posé.

### La panne la plus large de la journée, et elle ne visait pas Android

`s-android` est resté bloqué sur sa **toute première phrase**, indéfiniment,
sans un mot. Ce n'était pas Android : c'était `notify-send`.

`org.freedesktop.Notifications` est déclaré activable par
`org.kde.plasma.Notifications.service`, dont l'`Exec` est
`plasma_waitforname org.freedesktop.Notifications` — il **attend** que quelqu'un
publie ce nom. Le seul qui le publie est `plasmashell`, qui ne tourne plus ici
puisque la coquille est Constellation. `notify-send` attend donc pour toujours.

**`s_dire` est dans `s-monde`, que chaque couture charge par `source`.** La
panne ne gelait pas un geste : elle gelait **tout geste, à sa première
notification** — et le filet de `s-coquille` avec, qui appelait `notify-send`
de la même façon. La bulle part désormais détachée et bornée à cinq secondes.

*Ce qui reste à faire, et qui est le vrai correctif :* Constellation devrait
publier ce service elle-même. Une coquille qui ne sait pas afficher une
notification n'est pas finie ; en attendant, les phrases de S ne bloquent plus
mais ne s'affichent nulle part.

### Trois autres défauts, tous trouvés en faisant, aucun en relisant

- **Aucun agent d'authentification dans la session S.** `pkexec` n'ouvre pas de
  fenêtre lui-même : il demande à l'agent de la session de poser la question.
  Sans agent et sans terminal, il ne peut ni demander ni aboutir — `s-android`,
  `s-monter-windows`, `s-grand-disque` et `s-nettoyer` échouaient tous de la
  même façon. Plasma l'attachait à `plasmashell` ; c'est à `s-coquille` de le
  porter, comme elle porte déjà `graphical-session.target`.
- **`s-grand-disque` ne retrouvait pas l'étiquette qu'il venait d'écrire.**
  Juste après son `mkfs`, la phase de montage du même passage répondait
  « aucune partition ext4 étiquetée S-DISQUE — rien à monter » : `lsblk` lit le
  cache d'udev. Un `udevadm settle` règle la chose.
- **Et son `chown` tombait à côté.** Il annonçait « appartient désormais à
  RyuRex » et le disque restait à `root` : sur un point de montage
  **automatique** non encore déclenché, `findmnt` rend `systemd-1 autofs` —
  donc vrai — et le `chown` visait le répertoire de service d'autofs, jamais la
  racine ext4. Le message était juste, la cible ne l'était pas. **Le succès
  silencieux dans sa forme la plus exacte.**

### Le dossier partagé fait l'aller-retour — et il était à sens unique

`s-partage` répondait « Waydroid pas encore initialisé — rien à lier » alors
qu'Android tournait et que `/sdcard` existait. La faute n'était pas dans le
code mais dans son raisonnement : **il cherchait le fichier de configuration,
puis supposait que les données vivaient à côté.** Elles ne vivent pas à côté —
waydroid 1.6 garde sa configuration dans `/var/lib/waydroid/waydroid.cfg`, sans
clef `data_path`, et pose les données de session dans
`~/.local/share/waydroid/data`. On cherche désormais le dossier de données
lui-même.

Le montage lié posé, **Android lisait et n'écrivait pas**. Le commentaire du
script affirmait que « la couche media d'Android réécrit les droits qu'elle
présente à ses applications » : **c'est faux, il n'y a pas de couche qui
réécrive quoi que ce soit.** Waydroid présente les droits POSIX de l'hôte tels
quels. Relevé sur `/sdcard/Download` du même conteneur, ce que les dossiers
d'Android portent et qu'il fallait copier : groupe **1023** (`media_rw`), bit
**setgid**, et une ACL `group:1023:rwx` **doublée en ACL par défaut** pour que
tout ce qui naît dedans en hérite.

**Éprouvé dans les deux sens, sur la machine :** un fichier écrit sous Linux se
lit depuis Android ; un fichier écrit par Android (`u0_a141 media_rw`) se relit
sous Linux ; et Linux écrit toujours. C'est la seconde moitié du jalon 5, et
c'est la première fois qu'elle tient debout.

### Ce qui n'est toujours pas éprouvé

- ~~Aucun de ces six correctifs n'est dans l'image.~~ **Ils y sont depuis
  15 h 47, et la machine a redémarré dessus à 11 h 55** — image `44.20260824`,
  `sha256:c73f90ed…` *(dépassé : depuis 15 h 50 la machine tourne sur
  `sha256:39f70f4f…`, construite à 15 h 44 — voir la dernière section)*.
  Vérifié dans la session, pas dans le dépôt : l'agent
  polkit tourne (PID relevé), `s-partage.service` a remonté le dossier partagé
  **treize secondes après le démarrage**, sans que personne le lui demande, et
  les droits ont suivi — groupe 1023, setgid, ACL par défaut. C'est la première
  fois que cette couture survit à un redémarrage.
- **Le glitch d'affichage de Waydroid n'est pas diagnostiqué**, et rien n'a été
  changé pour lui. La marche à suivre écrite le 2026-08-23 tient toujours :
  `waydroid bugreport` **pendant** que le glitch se produit, puis une variable
  à la fois.
- ~~**Le presse-papiers Linux↔Android n'existe pas.**~~ **Il existait depuis
  le début, et il fonctionne depuis le 2026-08-25 à 17 h** : Waydroid fournit le
  pont binder entier, il lui manquait le paquet `python3-pyclip`. Éprouvé dans
  les deux sens à l'écran. Voir la section de 17 h.
- ~~**`bootc rollback` n'a toujours jamais été exercé**, alors que deux
  déploiements coexistent sur cette machine.~~ **Exercé le 2026-08-25 à
  19 h 49, et il fonctionne.** Voir la section de 19 h 55.
- ~~`galerie/constellation` n'a toujours aucune capture.~~ **Elle en a une,
  prise le 2026-08-25 à 12 h 23 sur cette machine**, et c'est la première pièce
  de la Galerie rendue par une vraie carte graphique. Voir plus bas.
- **L'image de S n'est ni signée ni vérifiée** — `ostree-unverified-registry`,
  aucune étape `cosign` dans le flux d'Actions, et `policy.json` fait retomber
  `ghcr.io/gigigrenier86` sur `insecureAcceptAnything` alors qu'il vérifie
  `ghcr.io/ublue-os` par sigstore. Mesuré le 2026-08-25 au soir ; **rien n'a été
  changé pour ça**. Garantie absente, pas incident. Voir la section de la nuit.

---

## 2026-08-26, nuit — les .exe etaient lents ET brouillons, et c'etaient deux pannes

*« Presentement, le roulement des .exe est lent et brouillon, ca marche pas a
moitie. »* — l'utilisateur, en ouvrant le chantier.

La phrase decrit deux defauts sans rapport l'un avec l'autre, et il a fallu les
separer pour reparer l'un ou l'autre.

| | Ce que c'etait vraiment |
|---|---|
| **Lent** | chaque double-clic reconstruisait un Windows entier |
| **Brouillon** | le prefixe n'avait ni .NET, ni WebView2, ni **aucune police Segoe** |

---

### 1. Le cout, mesure avant de toucher a quoi que ce soit

Premier relevé, avec un programme qui ne fait **rien** :

```
umu-run cmd /c exit     1er 6,65 s   2e 5,06 s   3e 5,13 s
umu-run wineserver -w   3,97 s, et il sortait en code 1
```

Deux choses s'y lisent. Cinq secondes pour un programme vide — et surtout **le
2e lancement coute autant que le 1er**. Il n'y avait aucun chemin chaud. Et
`s-ouvrir-exe` montait ensuite un SECOND conteneur complet pour appeler
`wineserver -w`, c'est-a-dire pour attendre quelque chose qui n'existait deja
plus : quatre secondes de plus, et un code d'echec que personne ne lisait.

**Neuf secondes de rien avant que le programme de l'utilisateur commence.**

Une hypothese est morte la : je soupconnais la moisson du menu, appelee apres
chaque lancement. Elle coute **0,45 s sur 9,5**. Ce n'etait pas elle.

Une autre aussi : le gouverneur de frequence est `powersave`. Sous charge, les
six coeurs montent a **3,0 GHz sur un maximum de 3,3**. Le nom du gouverneur
alarmait, la mesure l'a innocente.

### 2. Ce que le conteneur sert vraiment a faire

`umu-run` monte `pressure-vessel`, le bac a sable de Steam, et son runtime
`sniper` de 797 Mo. La question n'etait pas « comment l'accelerer » mais **« a
quoi sert-il ici »**.

Il sert a **construire** le prefixe, pas a l'executer. C'est le script `proton`
qui, a la creation, copie DXVK et VKD3D-Proton dans `system32` et compose les
surcharges de DLL. Verifie sur la machine :
`drive_c/windows/system32/d3d11.dll` fait **3,9 Mo** et porte la signature
DXVK — ce n'est pas un lien vers Proton, c'est un vrai fichier depose dans le
prefixe.

> **proton CONSTRUIT le Windows. wine le FAIT TOURNER.**
>
> S refaisait la construction a chaque double-clic.

### 3. Le piege qui restait, et il aurait rendu le chemin rapide moche

Les surcharges qui font PREFERER ce DXVK au `d3d11` interne de Wine ne sont
**pas dans le registre**. Elles vivent dans `WINEDLLOVERRIDES`, une variable
d'environnement que `proton` compose a chaque lancement. Sans elle, Wine ignore
le DXVK pose a cote et retombe sur son rendu OpenGL.

**On ne recopie pas cette liste** — c'est exactement la faute que ce projet a
payee cinq jours sur `s-android`. On la lui demande :

```bash
umu-run cmd /c 'set > C:\capture-env.txt'
```

Proton compose son environnement, Wine le passe au processus Windows, et `cmd`
l'ecrit **depuis l'interieur**. Aucun correctif applique a Proton, aucune liste
devinee : sa propre decision, relue sur le disque, une fois par version.

Pourquoi par un fichier et pas par la sortie standard : `umu-run /usr/bin/env`
rend **zero ligne avec un code 0**. Le succes silencieux dans sa forme pure.

**Deux pieges que le filtrage doit couvrir, et ils sont dans la capture reelle :**

- Le `PATH` qu'on y lit vaut `C:\windows\system32;C:\windows;...` — c'est le
  PATH **de Windows**. Le rejouer cote Linux remplacerait le PATH du systeme :
  plus aucune commande ne repondrait.
- `LD_LIBRARY_PATH` porte des chemins qui **n'existent que dans le conteneur**
  (`/usr/lib/pressure-vessel/overrides/...`, `/ubuntu12_64/`). Dix chemins a la
  capture, **trois** apres nettoyage.

### 4. Le resultat, avec la preuve a chaque mesure

Un wineserver resident, porte par une unite utilisateur — un serveur lance
depuis un script meurt avec le groupe de processus de son lanceur, et celui-la
avait disparu entre deux commandes du meme banc.

```
                                    duree      preuve
umu-run cmd /c 'echo ok > C:\...'   4,72 s     fichier ecrit
umu-run cmd /c 'echo ok > C:\...'   4,53 s     fichier ecrit
wine direct, 1er apres la session   1,37 s     fichier ecrit
wine direct, lancements 2 a 8       0,109 s    fichier ecrit   (ecart 0,004)
```

**46 fois plus rapide en regime etabli**, sur la meme machine, le meme Proton,
le meme prefixe.

*« Avec la preuve »* n'est pas decoratif. Une premiere serie annoncait
**0,01 s** — et le fichier n'etait pas ecrit, et `dir C:\windows\system32`
rendait **zero ligne**. `wine64` sans l'environnement capture **sort en silence
sans rien faire**, en code 1. Toute mesure de cette section ecrit donc un
fichier et le relit.

### 5. Le brouillon : Wine fournit un Windows VIDE

`PcBoostApp`, un logiciel WPF/.NET 8 ecrit par l'utilisateur, s'ouvre — et
**chaque icone est un carre vide**. Douze entrees de barre laterale, douze
carres.

Son theme dit :

```xml
<FontFamily x:Key="IconFontFamily">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
```

et pointe des caracteres de la zone privee Unicode. Le prefixe possedait
**dix-huit polices, aucune Segoe**. Wine donne un Windows vide ; tout logiciel
Windows moderne suppose ces fondations posees, et personne ne les posait — ni
.NET, ni WebView2, ni les polices.

**Copier les vingt-six polices n'a RIEN change.** Ni `wineboot -u` : 549 entrees
de police au registre avant, 549 apres. Un fichier depose dans le dossier des
polices n'existe pas pour Windows tant qu'il n'est pas **declare** :

```
HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts
HKLM\Software\Microsoft\Windows\CurrentVersion\Fonts
    "Segoe Fluent Icons (TrueType)" = "SegoeIcons.ttf"
```

Deux cles, pas une — c'est ce que fait winetricks dans `w_register_font`, et
c'est de la qu'on l'a pris.

**Et le nom ne se deduit pas du fichier.** `SegoeIcons.ttf` se declare
« Segoe Fluent Icons », `segmdl2.ttf` se declare « Segoe MDL2 Assets »,
`seguisb.ttf` se declare « Segoe UI Semibold ». Aucune regle ne relie les deux :
il faut lire la table `name` du fichier. C'est `/usr/lib/s/polices.py`, trente
lignes, sans dependance.

Quarante-sept polices declarees. **Toutes les icones apparaissent**, et la
typographie change avec — voir `galerie/windows/`.

### 6. Ou les polices ont ete prises, et pourquoi c'est licite

Segoe appartient a Microsoft et ce depot est **public** : l'y deposer serait une
redistribution. Mais cette machine porte un vrai Windows sous licence, monte en
`/var/mnt/windows`, et ses polices sont licenciees **avec elle**.

> La doctrine du projet tient mot pour mot. *« De Windows, on ne prend aucun
> fichier »* vaut pour **l'image**. L'image ne transporte que le geste ; les
> polices ne quittent jamais la machine ou elles sont licenciees.

Et quand il n'y a pas de Windows sur la machine, `s-windows --polices` **le
dit** au lieu d'afficher des carres sans explication.

**Ce qu'on n'emprunte PAS, et c'est delibere :** aucune DLL. Les DLL internes de
Wine sont ecrites pour s'emboiter entre elles ; y substituer celles d'un vrai
Windows casse plus souvent que ca ne repare. Les polices sont l'exception parce
que ce sont des **donnees**, pas du code. Pour les runtimes, winetricks
telecharge les redistribuables officiels de Microsoft — plus propre qu'une copie,
et maintenu par quelqu'un d'autre que nous.

### 7. Les icones des programmes Windows

Demande de l'utilisateur en cours de chantier. Tout lanceur pose par
`s-menu-windows` portait `Icon=application-x-executable` : la meme icone grise
pour PURPLE, pour Cursor, pour n'importe quoi. Le menu disait le **genre** et
jamais **lequel** — le defaut deja corrige pour les etoiles le 2026-08-23,
reste entier du cote Windows.

L'icone est **dans le fichier** : tout binaire Windows la porte dans sa section
de ressources. `icoutils` sait l'en sortir depuis vingt ans, et **il etait deja
sur la machine — par accident.** Aucun paquet ne le demandait, aucune ligne de
ce depot ne le nommait. Il est desormais installe explicitement, sinon il aurait
disparu un jour et les icones seraient redevenues grises sans que personne
comprenne pourquoi.

Releve : PURPLE rend **neuf tailles jusqu'a 256**, Cursor **deux jusqu'a 512**,
et les deux projets .NET de l'utilisateur en rendent **zero** — leur `.csproj`
ne porte pas `<ApplicationIcon>`. Ce n'est pas un defaut de S, et le repli
generique reste juste dans ce cas-la.

### 8. Le defaut que j'ai introduit, et que la mesure a rattrape

`PcBoostApp` lance par `umu-run` **pendant que le serveur resident tournait** :
aucune fenetre apres soixante secondes, aucun message, un code qui ne dit rien.
Le meme lancement, serveur arrete, ouvre sa fenetre en cinq secondes. La cause
est le verrou : Proton prend `pfx.lock` et suppose qu'il possede le prefixe.

**Ce que ca aurait coute sans cette mesure :** le filet de secours de
`s-ouvrir-exe` — celui qui rejoue par `umu-run` quand le chemin direct echoue —
aurait echoue lui aussi, **en silence**, exactement dans le cas ou l'utilisateur
compte dessus. *Un filet qui ne rattrape rien est pire qu'aucun filet : il donne
l'illusion d'un recours.* D'ou `s_windows_pause` / `s_windows_reprendre`, et
tout ce qui passe par `umu-run` les encadre.

### 9. Mon banc a menti deux fois cette nuit

Il faut l'ecrire, parce que c'est la deuxieme fois en trois jours.

- Le premier banc photographiait les fenetres avant, lancait, et prenait la
  premiere **nouvelle**. Une fenetre restee d'un essai precedent tombait dans le
  lot : il a rendu **0,28 s** pour une application WPF, et **1,33 s** pour un
  chemin qui en coute cinq. Le banc refait EXIGE une table rase verifiee et
  **refuse de rendre un chiffre** s'il ne l'obtient pas.
- La serie a 0,01 s, deja racontee plus haut, ou rien ne tournait.

*Un banc qui ne peut pas echouer ne mesure rien.* Et le carnet notait deja la
meme faute le 2026-08-25 sur le clic de la barre des taches.

**Et `pgrep -f` a fauche mon propre shell une quatrieme fois** — le motif matche
la ligne de commande du banc lui-meme. Tout ce chantier n'emploie plus que
`-x`.

### 10. Ce que cette nuit ne prouve pas

- **Rien n'est encore dans l'image.** Tout a ete eprouve sur la copie de travail
  par `S_BIN` / `S_LIB`. La construction a ete **rejouee localement**, pas lue
  dans les journaux d'Actions — ils repondent 403 sans droits admin, et `gh`
  n'est pas sur cette machine.
- **Le premier lancement apres ouverture de session coute 1,37 s**, pas 0,109.
  Le serveur resident initialise la session Windows a son premier client. Il est
  tire par `s-session.target`, donc ce cout est paye pendant l'ouverture de
  session et non au premier double-clic — **mais ca n'a pas ete chronometre sur
  un vrai demarrage.**
- **`ntsync` est la et n'est pas utilise.** Le noyau `7.2.0-ogc6.1` porte
  `/dev/ntsync` en `crw-rw-rw-`, le pilote d'Elizabeth Figura. `UMU-Proton-10.0-4`
  n'en contient **aucune trace** (`grep -rl ntsync` sur tout son arbre : rien) —
  il tourne en `fsync`. Fedora 44 propose `wine-11.0 Staging`, plus recent que
  le `wine-10.0` de Proton. Piste ouverte, **rien n'a ete change pour ca**.
- **Aucun `winewayland.drv`** dans ce Proton : les programmes Windows passent
  par XWayland. Non mesure comme un defaut, juste constate.
- **Le repli sur `umu-run` n'a jamais servi pour de vrai.** Il est ecrit, sa
  condition est bornee, mais aucun lancement ne l'a declenche.
- **RapidO n'a pas encore ouvert.** Il demande WebView2 en plus de .NET 8.

---

## 2026-08-25, 22 h 30 — le telephone tient S, et la preuve s'ecrivait elle-meme

L'entree de 21 h se terminait ainsi : *« Rien de l'acces distant n'est donc
exerce a cette heure. »* Une heure et demie plus tard tout l'est — et la preuve
n'a pas eu besoin d'etre cherchee : **elle m'a ecrit.**

### Ce que le carnet disait, et ce que la machine a repondu

Releve du 2026-08-25 a 22 h, sur une machine amorcee a **21 h 21** sur l'image
`44.20260825` (`sha256:08e8f0bb…`), construite neuf minutes plus tot.

| Ligne du carnet, ecrite a 21 h | Ce que la machine repond a 22 h |
|---|---|
| `tailscaled` *disabled, inactive* | **enabled, active** |
| `mosh` **absent** | `/usr/bin/mosh` et `/usr/bin/mosh-server` — **mosh 1.4.0** |
| `tailscale up` jamais lance | **lance** — `s` = `100.103.169.98`, `s.taila13c03.ts.net` |
| `45-telephone.sh` jamais construit | **dans l'image, et amorcee dessus** |
| Tailscale SSH non prouve | **prouve** — trois sessions au journal |

Le Pixel est sur le tailnet en connexion **directe** (192.168.40.148:40563), pas
par un relais DERP. Le script de construction a donc fait exactement ce qu'on
lui demandait, sans qu'une seule commande soit tapee sur la machine — *ce qui
doit tenir va dans l'image*, verifie une fois de plus.

### Tailscale SSH survit a SELinux Enforcing, et l'avertissement est un faux temoin

Le controle de sante de Tailscale annonce, a chaque demarrage du demon :

```
health(warnable=ssh-unavailable-selinux-enabled):
  SELinux is enabled; Tailscale SSH may not work.
```

**Il ne lit que `getenforce`.** Le journal, lui, nomme le mecanisme reel :

```
22:13:56  ssh-conn: 100.76.223.14:47864->RyuRex@100.103.169.98:22
          access granted to <compte>@ as ssh-user "RyuRex"
          audit: SSH login: user=RyuRex uid=1000 node=pixel-9-pro-fold…
          starting pty command: [/usr/bin/tailscaled be-child ssh
                --login-shell=/bin/bash --uid=1000 --tty-name=pts/2
                --is-selinux-enforcing --force-v1-behavior --shell]
```

`--is-selinux-enforcing --force-v1-behavior` : **tailscaled detecte `Enforcing`
tout seul et bascule sur son chemin de repli pty.** Ce n'est pas un
contournement pose par S, c'est prevu dans le produit. `tailscaled` tourne par
ailleurs en `unconfined_service_t`, donc non confine.

### LA PREUVE N'ETAIT PAS A CHERCHER : ELLE PARLAIT

Une seconde session Claude Code a ouvert un canal vers celle-ci pour annoncer
que la connexion fonctionnait. L'arbre de processus de `pts/2` :

```
11173  tailscaled  be-child ssh  --tty-name=pts/2  --is-selinux-enforcing
 11181    /bin/bash -l
  11292      claude          <- la session qui ecrivait
```

Sa socket : `/tmp/cc-socks/11292.sock`. **Son PID exact.** Elle ne rapportait pas
que Tailscale SSH fonctionne — **elle tournait dedans.** Son premier message
etait deja la mesure, 31 secondes apres l'ouverture de la session.

### Trois faux temoins dans la meme soiree, et j'en ai commis un

**Le mien.** Pour savoir qui repond sur le port 22 du tailnet, le reflexe est de
sonder `100.103.169.98:22` **depuis `s` elle-meme**. Les deux sondes rendent
`SSH-2.0-OpenSSH_10.2` — parce qu'une machine qui vise sa propre adresse
tailscale ne traverse jamais le tunnel : le noyau route en local, droit sur
`sshd`. **Un temoin qui rend la meme valeur dans les deux cas ne mesure rien.**

**Et la reponse etait dans ma propre sortie, dix minutes plus tot.** Mon premier
`ps -eZ` rendait `tailscaled … pts/5`. **Un demon ne possede pas de pty.**
C'etait la session SSH de 21 h 53, ouverte a cet instant. Je ne l'ai pas lue.

**Les deux autres viennent de la session voisine, et elle les a retires
elle-meme.** Un `ausearch -m avc` qui echouait sur *Permission denied* avec un
`|| echo` en bout de chaine, dont l'absence de sortie a ete lue comme une
absence de denis — le releve reel est **84 denis aujourd'hui**, tous
`bootupctl` et `tokio-rt-worker`, aucun sur tailscale ni sshd. Et un
`ls /run/user/1000/cc-socks/` qui ne trouvait pas sa propre socket, d'ou la
conclusion que le nom ne suivait pas le PID.

**Il y a DEUX dossiers de sockets sur cette machine :**

```
/tmp/cc-socks/11292.sock                       <- la session venue du Pixel
/run/user/1000/cc-socks/{3796,5974,5981,9283,11044}.sock   <- les cinq locales
```

*« Je ne peux pas voir » n'est pas « il n'y a rien »*, trois fois dans la meme
heure, par deux sessions differentes.

### Mosh passe, et c'est lui qui a tranche le pare-feu

```
22:29:56  --cmd=mosh-server 'new' '-c' '256' '-s' '-l' 'LANG=en_US.UTF-8'
                 '--' 'tmux' 'new' '-A' '-s' 's'
```

| Temoin | Valeur |
|---|---|
| `mosh-server` | **en cours** |
| Clients tmux | **deux** — `/dev/pts/2` (Tailscale SSH) et `/dev/pts/8` (mosh) |
| Compteurs du Pixel | tx 5,9 Mo → **11,9 Mo** |

Trois choses d'un coup : Tailscale SSH accepte une **commande non interactive**,
`mosh-server` demarre a travers lui, et **l'UDP passe sur `tailscale0`**.

Cette derniere etait une **deduction** que ce carnet refusait d'ecrire comme
acquise : `firewall-cmd --get-zone-of-interface=tailscale0` repond `no zone`, et
« donc il retombe sur la zone par defaut, qui ouvre `1025-65535/udp` » est le
mecanisme documente de firewalld, pas une mesure. **Mosh l'a mesuree en se
connectant.**

La moitie serveur avait ete isolee d'abord, sur `s` seule : `LANG=fr_FR.UTF-8`
(mosh refuse de demarrer hors UTF-8, panne classique ecartee) et `mosh-server`
rendant `MOSH CONNECT 60999` en code 0. **Une variable a la fois.**

### Ce que ca coute, et ce qu'il faut savoir avant que ca surprenne

- **Mosh impose `LANG=en_US.UTF-8`**, celui de Termux, a la session qu'il ouvre.
  Sans effet aujourd'hui — la session tmux `s` existait deja et garde
  `fr_FR.UTF-8` — mais une session tmux **neuve** ouverte par mosh serait en
  anglais sur un systeme dont toute l'interface est en francais.
- **Deux clients sur une meme session tmux** : le compositeur de tmux dimensionne
  la fenetre au plus petit des deux. Une connexion morte laissee attachee
  retrecit l'affichage sans raison visible.
- **S'attacher a la session `s` par `tmux new -A -s s` depuis le telephone
  rejoint le pane qui fait tourner Claude Code sur la machine.** L'ecran du
  telephone affiche alors l'invite de Claude, et tout ce qui est tape lui
  arrive — y compris les commandes destinees a un shell. `pkg` n'existant pas
  sur S, une commande Termux tapee la ne peut aboutir nulle part. Il faut
  `CTRL-b c` pour une fenetre neuve, ou `Volume Bas + B` sur Termux, qui fait
  office de `CTRL` sans aucune configuration.

### Ce que cette passe ne prouve pas

- **`XDG_RUNTIME_DIR` dans une session Tailscale SSH n'est pas mesure.** La
  socket du telephone etait la seule dans `/tmp` quand les cinq autres sont
  dans `XDG_RUNTIME_DIR` : l'indice est fort, la mesure n'a pas ete prise — le
  processus a quitte pendant que je la cherchais. **Ce que ca vaudrait si ca se
  confirmait :** sans `XDG_RUNTIME_DIR`, rien ne trouve le bus de session
  utilisateur, donc `s-partage`, `s-android`, la coquille et l'agent polkit. Un
  geste `s-*` lance depuis le telephone echouerait, ou reussirait a moitie en
  silence. Le test tient en une ligne, depuis une session ouverte par Tailscale
  SSH : `echo "[$XDG_RUNTIME_DIR]"`.
- **Le repli par cle SSH n'a jamais servi et n'existe pas.**
  `~/.ssh/authorized_keys` est **absent** pour `RyuRex`. Tout repose donc sur
  Tailscale SSH ; le jour ou la politique du tailnet change, il n'y a pas de
  seconde porte. *Ce n'est pas un incident, c'est une garantie absente* — meme
  famille que la signature d'image.
- **Les 84 denis AVC du jour ne sont pas expliques.** Ils ne touchent ni
  tailscale ni sshd, et personne ne les a regardes.
- **La survie a un vrai changement de reseau n'est pas mesuree.** Mosh est
  prouve connecte ; le basculement Wi-Fi → donnees mobiles, qui est sa seule
  raison d'etre ici, ne l'a pas ete.
- **Le confort reel d'un TUI sur un ecran de telephone n'est pas juge.**

---

## 2026-08-25, nuit — les quatre rôles étaient injoignables, et le Wizard prend sa forme

Trois heures plus tôt, les rôles entraient dans le dépôt et le commit se
terminait ainsi : *« Le chargement des skills depuis `.claude/skills/` n'a pas
été exercé : il se vérifiera à la prochaine ouverture de session. »*

**Il s'est vérifié. Il a échoué.**

### Le lien qui manquait, et la règle 0 qui promettait le contraire

Une session ouverte dans `/var/home/RyuRex` — c'est-à-dire depuis le lanceur du
bureau, la seule façon dont S ouvre Claude Code — **ne voyait aucun des quatre
rôles**. Ni `wizard`, ni `alchimiste`, ni `contremaitre`, ni `peintre`.

La cause tient en une phrase : **Claude Code ne charge les skills d'un dépôt que
s'il démarre dans ce dépôt.** Les rôles étaient donc versionnés, sauvegardés,
emportés par le clone — et hors de portée. La règle 0 affirmait « chargée
d'office sur toute machine qui clone le dépôt » ; c'était une déduction, pas une
mesure, et elle était fausse.

Le déplacement du soir avait corrigé un vrai défaut — deux copies divergentes
dont la juste n'était pas versionnée — **en en créant un autre, invisible et
plus grave** : avant, les rôles se chargeaient et n'étaient pas suivis ; après,
ils étaient suivis et ne se chargeaient plus. On n'avait pas déplacé un
problème, on l'avait échangé contre un problème silencieux.

```bash
~/.claude/skills -> /var/home/RyuRex/S/.claude/skills
```

Un lien symbolique règle les deux moitiés d'un coup : une seule source, suivie
par git, atteignable depuis n'importe quel dossier de travail. Un rôle ajouté
dans `S/.claude/skills/` apparaît seul, sans rien recopier.

**Ce que ça n'efface pas :** Claude Code lit les skills **au démarrage**. Le
lien ne peuple pas la session qui le pose ; il faut en ouvrir une nouvelle. La
vérification a été faite sur les fichiers lus à travers le lien — les quatre
en-têtes se lisent — pas sur un chargement observé. *Le vrai témoin est la
prochaine session, et cette fois c'est écrit.*

### Le Wizard, rangé pour de vrai

Le quatrième rôle passe d'un fichier à une petite bibliothèque, parce qu'il est
celui qu'on invoque **avant** de comprendre ce qu'on cherche, et qu'un persona
seul ne dit pas où regarder sur cette machine-ci.

```
.claude/skills/wizard/
├── SKILL.md                                 la conduite, 89 lignes
└── references/
    ├── ou-chercher.md                       l'ordre des sources
    ├── code-noir.md                         la grille de risque
    └── de-la-trouvaille-a-la-preuve.md      où chaque chose se range
```

Les trois références ne sont pas chargées avec le rôle : il les ouvre quand il
en a besoin. Ce qui compte est ce qu'elles contiennent — **des commandes
relevées sur cette machine, pas des conseils généraux** :

- **`ou-chercher.md`** descend quatre étages, et le web est le dernier. Le
  dépôt d'abord (`git log -S` retrouve le commit qui a introduit une chaîne,
  donc le message qui l'explique), puis la machine (`/usr/share/ublue-os/just/`,
  28 fichiers de recettes amont en clair ; `rpm -qf`, `rpm -ql` ; et
  `~/.local/state/s/coquille.log`, qui a eu raison de trois enquêtes le même
  jour), puis l'amont du conteneur, puis seulement le dehors.
- **`code-noir.md`** porte la grille, l'état mesuré des dépôts, et les deux
  constats ci-dessous.
- **`de-la-trouvaille-a-la-preuve.md`** porte l'échelle à quatre barreaux —
  trouvaille, hypothèse nommée, mesure, mécanisme — et la règle qui empêche le
  Wizard de polluer le Grimoire : **ce qu'il trouve n'a pas de `PREUVE:`, donc
  ça va dans ce carnet, avec la mesure qui le tuerait.**

`grimoire/wizard.md` — le texte brut du rôle, déposé au Grimoire faute de
meilleur endroit — en sort. Zéro ligne `PREUVE:`, et ce n'est pas un mécanisme
qu'on `source`. Son contenu est entier dans le skill.

### Ce que le rangement a trouvé en passant, et c'est le vrai butin

Écrire une grille de risque oblige à la remplir. Deux constats en sont sortis.

**Le premier est mort en dix minutes, et c'est un bon résultat.** Un relevé :
`2792 paquets, 2691 sans signature PGP`. 96 % du système non signé — net,
chiffré, alarmant. Le contrôle :

```bash
podman run --rm registry.fedoraproject.org/fedora:44 rpm -qi bash | grep Signature
→ Signature   :        (vide, exactement comme ici)
```

Un Fedora 44 **pur** rend le même vide. Le relevé ne mesurait donc rien sur S :
l'en-tête n'est pas retenu dans la base RPM de ces images, chez l'amont comme
ici. Les **101** paquets qui portent une signature sont ceux des COPR et de
Terra, ajoutés par-dessus. *Un chiffre spectaculaire sans groupe témoin n'est
pas une mesure* — et sans ces dix minutes, cette entrée serait ici sous forme de
faille, et quelqu'un aurait passé une journée à « réparer » Fedora.

**Le second tient, et il reste ouvert.**

> **S ne signe pas son image, et cette machine ne la vérifie pas.**

Trois relevés concordants :

| Relevé | Ce qu'il dit |
|---|---|
| `rpm-ostree status` | `ostree-unverified-registry:ghcr.io/gigigrenier86/s-os` — le transport le dit lui-même |
| `/etc/containers/policy.json` | `ghcr.io/ublue-os` est en `sigstoreSigned` avec clés épinglées ; `ghcr.io/gigigrenier86` ne correspond à rien et retombe sur `"": insecureAcceptAnything` |
| `grep -rniE 'cosign\|sigstore\|signing' .github/workflows/ Containerfile` | **aucune ligne** |

Et `/etc/pki/containers/` ne contient que les clés d'ublue-os et de toolbx.

Cette machine amorce donc ce que `ghcr.io/gigigrenier86/s-os:latest` désigne au
moment du `bootc upgrade`, sans qu'aucune signature ne soit exigée. La confiance
repose entièrement sur le compte GitHub et le jeton d'Actions. **S vérifie
l'image de son amont plus sévèrement que la sienne.**

Ce n'est **pas** un incident : c'est une garantie absente. Et le correctif est
amont — la paire cosign et l'étape de signature font partie du gabarit
`ublue-os/image-template`, et `policy.json` accepterait une entrée
`ghcr.io/gigigrenier86` sur le patron exact de celle d'ublue-os. *On ne
réimplémente pas ce que l'amont maintient* : c'est son gabarit qu'il faudra
lire, pas une signature à inventer.

**La mesure qui dirait que c'est réglé :**

```bash
rpm-ostree status | grep -c 'ostree-unverified'      # doit tomber à 0
cosign verify --key cosign.pub ghcr.io/gigigrenier86/s-os:latest
```

**Rien n'a été changé pour ça ce soir.** C'est une hypothèse tranchée par la
mesure, pas un chantier ouvert — et elle est écrite ici précisément pour ne pas
être redécouverte dans trois semaines.

### Un relevé positif, tant qu'à mesurer

Sur les **19** fichiers de `/etc/yum.repos.d/`, **4 sections sont actives, et
les quatre ont `gpgcheck=1`** : `fedora`, `updates`, `updates-archive`,
`terra-mesa`. Les COPR — `ublue-os`, `bieszczaders`, `negativo17` — sont
**désactivés sur la machine** : ils ont servi à la construction, pas à
l'exécution, et leurs clés restent posées, ce qui est cohérent.

### Ce que cette passe ne prouve pas

- **Le chargement des quatre rôles n'est toujours pas observé.** Les fichiers se
  lisent à travers le lien ; aucune session ne les a encore montés. C'est le
  même « pas exercé » que le commit de 21 h — sauf qu'on sait maintenant ce qui
  le ferait échouer.
- **Aucune des commandes des trois références n'a été rejouée en bloc.** Elles
  ont toutes été relevées sur cette machine ce soir, une à une, mais rien ne les
  garde d'aujourd'hui : un chemin qui disparaît chez l'amont ne se signalera
  pas.
- **Rien de tout ceci n'entre dans l'image.** `.claude/` ne change pas une ligne
  de ce que la machine exécute.

---

## 2026-08-25, 21 h — travailler sur S depuis le telephone

Demande de l'utilisateur : *« je veux pouvoir travailler sur le projet depuis
mon telephone »*. Trois voies existaient et elles ne se valent pas ; celle
retenue est la seule compatible avec la methode de ce carnet.

### Pourquoi pas le nuage, et pourquoi pas une redirection de port

| Voie | Ce qu'elle donne | Pourquoi ecartee |
|---|---|---|
| Claude Code sur le web | confortable au doigt, rien a installer | **aveugle a la machine** — aucune mesure, aucun journal, aucun `bootc`. Or ce carnet ne vaut que par ce qu'il mesure |
| Ouvrir le port 22 sur la box | direct | exposer un `sshd` a l'Internet entier pour joindre une machine personnelle |
| **Tailscale + SSH** | **le vrai terminal de S, de n'importe ou** | **retenue** |

Ce qui a decide : `tailscale` **est deja dans l'image de base** — 1.102.3, mesure,
pas suppose — mais livre `disabled` et jamais demarre. Il ne manquait pas un
outil, il manquait une activation.

### Ce que la machine a repondu

| | |
|---|---|
| `sshd.socket` | **actif**, port 22 en ecoute — le travail de `10-base.sh` tient |
| Adresse | `192.168.40.149/24` en Wi-Fi — **privee**, injoignable de l'exterieur |
| Pare-feu | `firewalld` actif, zone `FedoraWorkstation`, **service `ssh` ouvert** |
| `tailscaled` | present, `disabled`, `inactive`, **aucun etat dans `/var/lib`** |
| `authorized_keys` de `RyuRex` | **aucune** — seul `root` a la cle posee a l'installation |
| `tmux` | present. `mosh` : **absent** |

### La mesure qui aurait fait echouer tout le reste en silence

Une machine qui s'endort ne repond plus au telephone, et rien ne le dit : on
croit que l'acces distant est casse. Releve :

```
powerdevil                    ne tourne pas
logind IdleAction             "ignore"
veilles depuis l'allumage     0
```

**La machine ne s'endort donc jamais — mais rien ne le decide.** C'est
l'absence de PowerDevil, elle-meme consequence du remplacement de Plasma par
Constellation, qui le produit. **Ca tient par accident**, exactement comme
`s-session.target` tenait par accident jusqu'au 2026-08-25 apres-midi.

**Et le garde evident serait un faux garde.** Un fragment `logind.conf.d` avec
`IdleAction=ignore` ne protegerait de rien : PowerDevil n'endort pas la machine
par `IdleAction`, il appelle `Suspend()` directement, que ce reglage ne
gouverne pas. Poser ce fichier donnerait le sentiment d'une protection sans en
etre une — le faux temoin que ce carnet collectionne. **C'est donc ecrit ici et
non « corrige ».**

### Ce qui entre dans l'image, et ce qui n'y entrera jamais

`build_files/45-telephone.sh`, branche avant `40-coutures.sh` — le seul creneau
disponible, puisque les coutures se terminent par `ostree container commit`.

- **`tailscaled` active dans l'image.** Un `systemctl enable` tape sur la
  machine ne survivrait pas a un `bootc upgrade` ; c'est la regle du carnet.
  Meme geste que `sshd.socket` dans `10-base.sh`, meme raison.
- **`mosh` pose.** Ce n'est pas un confort : un telephone change de reseau sans
  arret, et **chaque changement d'adresse IP tue une session SSH**. Mosh y
  survit parce qu'il ne tient aucune connexion TCP. C'est la difference entre
  « je peux travailler depuis mon telephone » et « tant que je ne bouge pas ».
- **Aucune cle, aucun identifiant, aucun jeton d'authentification.** Le depot
  est public. L'etat de Tailscale vit dans `/var/lib/tailscale`, qui est propre
  a la machine et survit aux mises a jour — la bonne moitie de la regle 1.
- **Un garde-fou**, meme patron que celui de `20-android.sh` sur
  `waydroid-launcher` : si l'amont retire Tailscale, **la construction echoue**
  au lieu de livrer une image dont l'acces distant s'est evapore.

### Ce que cette passe ne prouve pas — et c'est presque tout le cote machine

- ~~**`tailscale up` n'a jamais tourne.**~~ **Lance, et le tailnet est monte** —
  releve le 2026-08-25 a 22 h : `s` = `100.103.169.98`, le Pixel en connexion
  directe. Voir la section de 22 h 30.
- ~~**Le script de construction n'a jamais ete construit.**~~ **Construit,
  publie et amorce** — image `44.20260825`, `sha256:08e8f0bb…` : `tailscaled`
  est `enabled` et `mosh` est pose, sans qu'une commande ait ete tapee sur la
  machine.
- ~~**Tailscale SSH n'est pas prouve ici.**~~ **Prouve, et sous SELinux
  `Enforcing`** — trois sessions au journal, `access granted` a chacune. Le
  repli par cle SSH n'a donc jamais servi, et il **n'existe pas** :
  `~/.ssh/authorized_keys` est toujours absent. Voir la section de 22 h 30.
- ~~**Mosh au-dessus de Tailscale SSH n'est pas prouve**~~ **Mesure le
  2026-08-25 a 22 h 29 : il passe.** Et c'est lui qui a tranche la question du
  pare-feu que ce carnet laissait en deduction. Voir la section de 22 h 30.
- **Le confort reel d'un TUI sur un ecran de telephone n'est pas juge.** C'est
  l'utilisateur qui l'exercera le premier.

---

## 2026-08-25, 19 h 55 — le filet a servi, et il tient

**`bootc rollback` a ete exerce pour la premiere fois du projet.** C'etait la
derniere promesse de ce carnet sans une seule mesure derriere elle : elle y
figurait depuis le 2026-08-19, repetee dans six sections, et elle disait
elle-meme que son absence de preuve *« couterait aussi cher »* que celle de
n'importe quelle autre. Elle a coute un redemarrage a froid.

### La sequence, horodatee, lue dans le journal

| Heure | Ce qui s'est passe |
|---|---|
| 19:31:34 | `sudo bootc upgrade` — `layers already present: 128; layers needed: 19 (2.8 GB)` |
| 19:33:57 | deploiement cree en **28 s** — `checkout=11.2s composefs=13.8s etc=2.0s` |
| 19:36:23 | demarrage sur la **nouvelle** image `621bf38a` |
| 19:36:34 | `s-partage` a lie le dossier partage, **onze secondes** apres l'allumage |
| 19:36:44 | `s-session.target` atteinte |
| 19:49:39 | `sudo bootc rollback` — *« Rolling back to image: sha256:1c3b96d2… »* |
| 19:49:47 | **manoeuvre terminee : huit secondes**, `Freed objects: 315.7 kB` |
| 19:52:17 | demarrage sur l'**ancienne** image, celle de 16 h 46 |

**Huit secondes, et zero octet de reseau.** Le journal de bootc le dit dans sa
langue : `Transaction complete; bootconfig swap: no; deployment count change: 0`,
avec un cycle de gel/degel du `boot` de dix-neuf millisecondes. Rien n'est
retelecharge parce que rien n'a besoin de l'etre — **les deux arborescences sont
deja sur le disque, en clair.** C'est ce qui fait du rollback un filet et non
une reinstallation.

Etat de la machine apres retour : **zero unite en echec**, systeme et session ;
`s-session.target` et `graphical-session.target` actives, **sans une seule ligne
« Stopped target »**.

### Le prix, mesure fichier par fichier — pas deduit du numero de version

Les deux images portent le meme tag, la meme version `44.20260824` et le meme
noyau. Le numero ne dit rien. On lit donc l'arborescence d'en face :

| | ancienne `1c3b96d2` (celle qui tourne) | nouvelle `621bf38a` (dans la case du retour) |
|---|---|---|
| `pyclip` | **absent** | `usr/lib/python3.14/site-packages/pyclip` |
| `Constellation.qml:408` | `menuDemarrer.close()` — le bogue | `Session.bureau.relire()` |
| `s-android` | 9 166 o | **20 876 o** — le mode fenetre unique |

**Le rollback coute donc exactement les trois chantiers du soir** : le
presse-papiers Linux↔Android, la video qui joue, et le menu Demarrer dont
« Eteindre » ne faisait rien. Le journal de la coquille le confirme a l'ecran —
le `ReferenceError: menuDemarrer is not defined` retombe a chaque ouverture.

**Ce qu'il ne coute pas**, et il fallait le verifier plutot que le supposer : le
clavier CSA (`localectl` rend `ca`/`multix`, `kxkbrc` est en place) et la cible
de session. Les deux etaient deja dans l'image de 16 h 46.

### LE FAUX TEMOIN, ET IL M'A PRESQUE EU

Pour savoir quel deploiement avait demarre, le reflexe est de lire l'argument
`ostree=` du noyau. **Il ne distingue pas les deploiements.** Sa forme est
`ostree=/ostree/boot.<version>/<os>/<bootcsum>/<serial>`, et `bootcsum` est
l'empreinte du **noyau**, partagee par tout deploiement qui embarque le meme.

Releve : les deux demarrages de la soiree — l'un sur la nouvelle image, l'autre
sur l'ancienne — portent le meme `ostree=` **au caractere pres**
(`2c6eb4d8…`). Un temoin qui rend la meme valeur dans les deux cas et qu'on
lirait comme une identite : exactement la forme de faux verdict que ce carnet
collectionne depuis le 2026-08-20.

Ce qui identifie vraiment le deploiement booté est l'etoile d'`ostree admin
status`, ou le rond de `rpm-ostree status`. Rien d'autre.

### Et la recette ecrite pour mesurer ca s'est trompee a son premier essai

`grimoire/ostree-comparer-deploiements.sh` lisait le checksum par le **dernier
champ** de chaque ligne d'`ostree admin status`. Sur la ligne du booté c'est le
bon ; sur celle du rollback, le dernier champ est `(rollback)`. La fonction
rendait donc un seul deploiement sur deux — et sa reponse aurait ete
« un seul deploiement, aucun retour possible », ce qui est faux et rassurant
dans le mauvais sens.

**Trouve en l'executant, pas en la relisant**, et corrige en cherchant le motif
d'un checksum plutot qu'une position. Eprouvee dans les deux sens : trois
fichiers qui different rendent 1 et les nomment, deux gestes que la nouvelle
image ne touche pas rendent 0.

### Ce que cette passe ne prouve pas

- **Le rollback n'a pas ete exerce sur une image cassee.** Il l'a ete sur une
  image saine, par choix : la nouvelle a tourne treize minutes sans une unite en
  echec, session ouverte et Android demarre. Ce qui est prouve, c'est que la
  manoeuvre fonctionne et ce qu'elle coute — pas qu'elle sauve une machine qui
  ne demarre plus.
- **Le retour vers `621bf38a` n'a pas encore ete fait.** Tant qu'il ne l'est
  pas, la machine tourne **sans** le presse-papiers Android, sans la video, et
  avec « Eteindre » inerte dans le menu Demarrer.
- **Le second sens du filet n'est pas mesure.** Le carnet ecrivait a 17 h qu'*« un
  second rollback les rend »* ; c'est toujours une deduction.

---

## 2026-08-25, soir — Android en usage reel, et le temoin du matin qui parle

Quatre pannes rapportees par l'usage, toutes sur Android. **Trois sont reglees et
mesurees ; la quatrieme est cernee a une seule variable.** Et le journal de la
coquille a livre au passage la cause que le carnet disait inconnue le matin meme.

### La methode d'abord, parce qu'elle a paye

**Quatre hypotheses formees, trois refutees par la mesure avant d'entrer nulle
part.** Aucune n'est partie dans le depot.

| Hypothese | Ce qui l'a tuee |
|---|---|
| `debug.stagefright.ccodec=0` prive YouTube de decodeurs | l'image declare **27 codecs OMX**, dont vp9, vp8, opus, aac |
| Le multi-fenetrage casse la video, donc le plein ecran la repare | l'utilisateur : *« c'est pareil en plein ecran »* |
| Le masquage reseau manque | `firewall-cmd` disait non ; `nft` a montre la regle, **218 paquets deja traduits**, posee par iptables-nft hors de firewalld |

Et la mesure qui a le plus servi ne vient pas de moi : **l'utilisateur a trouve
que YouTube lance par `s-android` marche, et que le meme YouTube lance depuis la
barre echoue.** Deux chemins, une seule variable — `waydroid show-full-ui`
contre `waydroid app launch`. C'est ce qui a isole le defaut.

### Le gel : la cause reelle, et le levier qui marche

Le carnet accusait le gel du conteneur depuis le 2026-08-23 et le croyait corrige
par `suspend_action = none`. **Les deux moities etaient fausses en meme temps** :
la valeur ne fait rien (voir la section de 17 h), et le gel n'etait pas la cause
du trou dans la video — la barre de progression avancait, donc le conteneur
tournait.

**Mais le gel cassait autre chose, et personne ne l'avait relie.** Releve dans
`/var/lib/waydroid/waydroid.log` :

```
17:21:35  FROZEN → lxc-unfreeze      l'utilisateur lance la video
17:55:52  lxc-freeze → FROZEN        le conteneur gele
17:58:32  FROZEN → lxc-unfreeze      il degele
```

Et pendant ce temps, cote hote, le compteur du pont `waydroid0` **n'a pas bouge
d'un paquet** : `RX = 8862`, fige. Un conteneur gele, ce sont tous ses processus
arretes — plus de pile reseau, plus d'ARP, plus de bail DHCP. Au degel, Android
ne recupere rien. Releve dans le conteneur, apres :

```
ip route  →  192.168.240.0/24 dev eth0 ... src 192.168.240.112     (et rien d'autre)
getprop net.dns1  →  (vide)
ping 8.8.8.8      →  Network is unreachable
```

**Il avait son adresse et aucun moyen de sortir de son propre sous-reseau.**
C'est ca, « aucune connexion internet » dans les applications Android.

Le gel n'est pas decide par Waydroid : **Android le demande**, en appelant
`suspend()` sur `IHardware` quand il eteint son ecran. On ne peut pas refuser le
gel — `none` n'existe pas, `stop` est pire. On peut empecher Android de
s'endormir :

```
settings put system screen_off_timeout 2147483647
settings put global stay_on_while_plugged_in 7
```

**Mesure : 25 gels dans la journee, le dernier a 17 h 55, aucun depuis.**

### Le son n'etait pas casse, il etait inatteignable

L'hote etait hors de cause de bout en bout, et ca valait d'etre mesure avant de
chercher ailleurs : `wpctl` montre le flux **Waydroid** vivant, volume 1.00, non
coupe, branche sur la meme sortie que Vivaldi — que l'utilisateur entendait.

Le silence venait d'Android : `volume_music = 5`. **Et surtout, aucun moyen de
le changer** — une fenetre par application n'a ni barre d'etat, ni panneau de
volume, ni touches de volume. Le reglage existe et rien ne le presente.

Monte, le son marche partout, y compris dans les fenetres par application.

### La video : cerne a une variable, pas encore prouve

Symptome exact, et il a fallu la formulation de l'utilisateur pour le comprendre :
**ce n'est pas un ecran noir, c'est un trou.** On voit le bureau au travers.
Android decode (la barre avance), l'application dessine son interface, et la
couche video n'apparait nulle part.

Ce qui a ete ecarte : les codecs, le mode plein ecran, l'hote (kwin annonce NV12
et P010, `wl_subcompositor` et `wp_viewporter` sont la).

**Le levier trouve dans le binaire du compositeur** —
`strings` sur `hwcomposer.waydroid.so` :

```
persist.waydroid.use_subsurface
persist.waydroid.no_background_subsurface
"usage of subsurfaces requested but wl_subcompositor is not supported."
wl_subsurface  ·  wp_viewport  ·  apply_hwc_layer_to_window
```

`use_subsurface` etait **vide**. Essaye a `true`, puis a `false`, session
redemarree entre les deux (le conteneur redemarre bien, verifie dans
waydroid.log) : **aucun effet**, les couches restent `DEVICE` dans les deux cas.
Refutee.

### ET LA SOLUTION, TROUVEE DANS LA TABLE DES SYMBOLES

L'amont n'avait rien de plus recent — l'image systeme du 2026-04-03 **est** la
derniere publiee, le vendor du 2026-04-28 aussi. Verifie sur les deux flux OTA.
Il fallait donc trouver, pas attendre.

`strings` sur `hwcomposer.waydroid.so`, puis `c++filt`, rend la hierarchie
entiere des modes du compositeur :

```
compositing_full_ui_mode        / non_compositing_full_ui_mode
compositing_single_window_mode  / non_compositing_single_window_mode
multi_window_mode               <- SEUL, sans variante « compositing »
closed_mode
```

**« full_ui » et « single_window » ont chacun une variante qui COMPOSE les
couches ensemble. « multi_window_mode » n'en a pas.** Il ne sait que faire
correspondre une couche a une fenetre — d'ou son `can_handle_layer()`, d'ou
`skipped_layers_helper`, et d'ou la couche video qui n'a nulle part ou aller.

**Ce n'est donc pas un bogue : c'est une capacite que ce mode n'a jamais eue.**
Trois jours de carnet ont cherche un defaut la ou il n'y avait qu'une absence.

Et le releve de SurfaceFlinger le montrait depuis le debut, sans qu'on sache le
lire :

```
TID:23#…/HomeActivity#115       DEVICE  1920x1028   <- la fenetre, posee
     …/HomeActivity(BLAST)#126  DEVICE  1280x714    <- la video, perdue
```

**LE CORRECTIF : `multi_windows = false` AVEC `waydroid app launch <paquet>`.**
Ce n'est PAS le plein ecran d'Android — c'est
`compositing_single_window_mode` : une fenetre qui ne montre que
l'application, **sans barre d'etat, sans barre de navigation, sans lanceur**, et
dont le compositeur assemble lui-meme toutes les couches.

**Eprouve a l'ecran par l'utilisateur le 2026-08-25 au soir : la video joue.**
Avec le son, dans une fenetre, sans une seule interface d'Android visible.

C'est la regle 9 du projet tenue jusqu'au bout — *une couture ne montre jamais
son moteur* — et c'est la demande de l'utilisateur, mot pour mot : *« une icone,
clique, fonctionne, je ne veux aucunes interfaces tierces »*.

**Ce que ca coute, et le carnet ne le cache pas :** Waydroid ne tient qu'UNE
fenetre Android a la fois dans ce mode. Ouvrir Gmail pendant que YouTube tourne
remplace la fenetre au lieu d'en ajouter une.

**Et ce que ca corrige dans ce carnet :** l'entree du 2026-08-25 apres-midi
celebrait `multi_windows = true` comme ayant fait tomber cinq jours de
suppositions. C'etait vrai — il a rendu Android fenetre au lieu de plein ecran —
et c'est lui qui a introduit le trou dans la video. Les deux sont vrais ; la
seconde moitie a mis une soiree a se voir.

### SIX HYPOTHESES, CINQ REFUTEES, ET AUCUNE N'EST ENTREE DANS LE DEPOT

| Hypothese | Ce qui l'a tuee |
|---|---|
| `debug.stagefright.ccodec=0` prive des decodeurs | 27 decodeurs OMX presents, vp9/vp8/opus/aac compris |
| Le plein ecran de l'application repare | l'utilisateur : « c'est pareil » |
| Le masquage reseau manque | la regle existe, 218 paquets deja traduits |
| `use_subsurface` | essaye dans les deux sens, couches inchangees |
| Forcer la composition GPU (`SurfaceFlinger 1008`) | **plus AUCUNE fenetre Android** |
| **Le mode fenetre unique compositing** | **eprouve a l'ecran : la video joue** |

Et la cinquieme, en echouant, a livre le mecanisme : **le compositeur fabrique
les fenetres Wayland A PARTIR des couches `DEVICE`.** Sans elles, pas de
fenetres. C'est ce qui a permis de comprendre que la couche video, elle, n'etait
rattachee a aucune.

**La mesure qui a tout debloque ne vient pas de moi.** L'utilisateur a remarque
que YouTube lance par `s-android` marchait et que le meme YouTube lance depuis
la barre echouait. Deux chemins, une seule variable — `show-full-ui` contre
`app launch`. Sans ca, je cherchais encore dans les codecs.

### Un plantage du compositeur, releve et non explique

```
Cmdline: /vendor/bin/hw/android.hardware.graphics.composer@2.1-service
Abort message: 'Binder threadpool cannot be shrunk after starting'
  #04 libhidlbase.so (configureBinderRpcThreadpool)
  #05 hwcomposer.waydroid.so (hwc_binder_thread+81)
```

Un seul plantage, au demarrage de la session ; `init` relance le service, sinon
il n'y aurait aucune image. **Ce n'est pas la cause du trou** — l'affichage
fonctionne apres. C'est ecrit ici parce que ca reviendra.

### Et le temoin du matin a nomme la cause que le carnet disait inconnue

Le journal de la coquille, releve du demarrage de 16 h 52 :

```
qml: vignette trois : dimensions refusees -32x-20      (18 fois)
Constellation.qml:408: ReferenceError: menuDemarrer is not defined
```

**La chaine se lit d'un bout a l'autre :**

```
Column { id: corps ; width: parent.width }       0 tant que la ScrollView n'a pas mesure
  Column { width: parent.width - 32 }            0 - 32 = -32
    Grid { width: parent.width }                 -32, columns retombe a 1
      delegate { width: (-32 - 0) / 1 }          -32 de large, -20 de haut
```

Une marge fixe soustraite d'une largeur encore nulle.

**ET C'EST POURQUOI LE BANC DU MATIN AVAIT REFUTE LA BONNE HYPOTHESE.** Il avait
essaye une taille **nulle**, qui n'appelle jamais `onPaint` — vrai, et sans
rapport. Une taille **negative**, elle, appelle `onPaint` et passe des valeurs
impossibles a `createRadialGradient`. Le banc mesurait le mauvais cas et rendait
un verdict assure. *Le garde et le temoin poses le matin, eux, ont fait
exactement ce qu'on leur demandait : rendre la prochaine occurrence lisible.*

Corrige a la source par un `Math.max(0, ...)` sur les **quatre** occurrences.

### Deux defauts latents trouves en corrigeant le premier

`menuDemarrer` ne resout pas dans les delegues de `Repeater`, comme `bureau`
avant lui. Le journal n'en signalait qu'un — la ligne 408, l'ouverture d'une
application depuis le menu. **Deux autres etaient dans le meme cas sans avoir
ete cliques :**

- ligne 452, ouvrir un dossier ;
- **ligne 605, « Eteindre » et « Redemarrer »** — `menuDemarrer.close()` y est la
  PREMIERE ligne, donc `pont.session()` n'etait jamais atteint. **Eteindre depuis
  le menu Demarrer ne faisait rien**, et personne ne l'avait signale.

Le singleton `Session` porte desormais le menu comme il porte le bureau.
Controle de construction repasse : *« scene QML : chargee, menu ouvert, aucun
avertissement »*.

### Et une reponse a la question posee

*« L'appli YouTube de ma barre, est-ce que ca roule sur Waydroid ? »* Oui — les
deux. `usage.json` compte **18 lancements** de
`waydroid.com.google.android.youtube` : la barre a bien emis l'ordre a chaque
clic, et la coquille n'a rien journalise. Le defaut est entierement du cote de
Waydroid, pas de S.

### Ce que cette passe ne prouve pas

- ~~**`use_subsurface` n'a pas ete juge.**~~ Juge dans les deux sens, sans effet.
  Le correctif est ailleurs — voir plus haut.
- **Le plantage du compositeur n'est pas explique**, seulement releve.
- **Les correctifs QML de ce soir ne sont pas dans l'image** — controle de
  construction passe, pas de clic reel.
- ~~**Le correctif du gel n'est pas dans `s-android`.**~~ Il y est, avec le mode
  fenetre unique et la densite. **Mais rien de tout cela n'est encore dans
  l'IMAGE** : il faut une construction et un `bootc upgrade`. Sur cette machine
  les reglages sont poses a la main et tiennent ; sur une machine neuve, ils
  n'arriveront qu'avec l'image.

---

## 2026-08-25, 17 h — le presse-papiers existait deja, et trois lignes de ce carnet etaient fausses

Cinq chantiers repris d'un coup. Trois sont clos ; le chemin a fait tomber
**trois affirmations de ce carnet**, toutes du meme type : *un fichier de
configuration lu a la place de la machine.*

### Vivaldi ne se lancait plus, et la cause etait le nom de la machine

```
~/.config/vivaldi/SingletonLock -> bazzite-15646
```

Un profil Chromium se protege par un lien symbolique « machine-pid ». Au
demarrage le navigateur le relit, et **son comportement depend du nom** : meme
machine, il verifie si le PID vit encore et casse le verrou tout seul s'il est
mort ; **autre machine, il n'y touche JAMAIS** — il suppose un dossier personnel
partage en reseau et refuse, pour ne pas l'abimer.

Or S renomme la machine. `35-identite.sh` ecrit `DEFAULT_HOSTNAME="s"` dans
`os-release`, et comme `/etc/hostname` est vide, c'est ce nom que systemd
retient. **Le jour ou S a pris son nom, tout profil ne sous « bazzite » a herite
d'un verrou que rien ne casserait plus.** Deux etaient dans ce cas : Vivaldi, et
l'ancienne Constellation servie en page web.

Ce n'est donc pas un incident : c'est une **consequence permanente de l'identite
de S**, qui frappera toute machine mise a jour depuis une image anterieure.
`s-corriger-machine` gagne une cinquieme correction — elle ne retire que les
verrous portant un AUTRE nom, jamais ceux que Chromium sait reparer. Eprouvee
sur quatre profils factices : les trois noms etrangers tombent avec leurs trois
fichiers, le local reste intact, et un nom a tirets est coupe au bon endroit.

*Et le silence s'explique aussi* : Chromium voulait afficher « le profil est
utilise sur un autre ordinateur » dans une boite de dialogue, et le journal le
dit — `Unable to show message box`. La coquille n'avait rien a montrer.

### La cible de session, prouvee sur la vraie cible

Le carnet ecrivait a 16 h : *« Le correctif de `s-session.target` n'est pas dans
l'image. Il est prouve au banc, pas sur la vraie cible. »* Le `bootc upgrade` de
16 h 52 l'a embarque, et la mesure est faite :

```
16:53:02  Reached target s-session.target - S - la session graphique.
16:53:02  Reached target graphical-session.target - Current graphical user session.
```

**Et aucune ligne « Stopped target » derriere**, la ou le demarrage de 15 h 50 en
portait une a la meme seconde. Les deux cibles sont toujours actives sept minutes
plus tard, le portail XDG et l'accessibilite tournent, zero unite en echec —
systeme et session. La session ne tient plus par accident.

### Le presse-papiers Linux <-> Android : il existait, il lui manquait un paquet

Le carnet le portait comme un chantier a ecrire depuis le 2026-08-24. **Waydroid
le fournit en entier, et personne n'avait regarde.**

```
tools/interfaces/IClipboard.py        service binder « waydroidclipboard »
                                      transaction 1  sendClipboardData
                                      transaction 2  getClipboardData
tools/services/clipboard_manager.py   demarre dans la session (session_manager.py:108)
```

Ce qui l'eteignait tient en trois lignes : le gestionnaire s'ouvre sur un
`try: import pyclip`, et si l'import echoue il se saute lui-meme en journalisant
**au niveau `debug`**. Invisible partout. Le paquet `waydroid` de Fedora ne tire
pas `python3-pyclip`, qui existe pourtant dans les depots et se pose entierement
dans `/usr`.

**Eprouve AVANT de reconstruire l'image**, en depliant le RPM et en l'injectant
par `PYTHONPATH` dans une vraie session Waydroid — la recette est au Grimoire.
Deux sessions, une seule variable :

| | fils du processus de session |
|---|---|
| avec pyclip | **7** |
| sans pyclip | 6 |
| avec pyclip | **7** (reproduit) |

Puis la mesure qui compte, a l'ecran, dans les deux sens : un temoin ecrit sous
Linux colle dans Android, et **du texte copie dans YouTube sous Android relu
sous Linux par `wl-paste`** — un outil qui ne sait rien de Waydroid :

```
Provided to YouTube by JVCKENWOOD Victor Entertainment Corp.
```

**C'est la seconde moitie du jalon 5, et elle tient debout.**

### Deux reglages Android que le carnet declarait appliques, et qui ne l'etaient pas

**`suspend_action = none` ne fait rien.** Le code de l'amont,
`hardware_manager.py:22-27`, n'a que deux branches :

```python
if cfg["waydroid"]["suspend_action"] == "stop":  session_manager.stop(args)
else:                                            container_manager.freeze(args)
```

« none » n'est implemente nulle part dans waydroid 1.6.3 — le mot n'apparait pas
une seule fois dans `tools/` — et tombe dans le `else`, ou il gele exactement
comme la valeur par defaut. Releve a 17 h, la valeur `none` deja posee :
**`Session RUNNING / Container FROZEN`**. Le gel est intact, et le carnet
affirmait le contraire depuis le matin.

**La densite n'a jamais atteint Android.** `waydroid.cfg` dit 140 ;
`waydroid prop get ro.sf.lcd_density` dit **180**. La cause, lue dans le code :
la section `[properties]` n'est versee dans le conteneur que par
`make_base_props()`, appele **uniquement** depuis `initializer.py`
(`waydroid init`) et `upgrader.py` (`waydroid upgrade`) — jamais au demarrage du
conteneur, jamais au demarrage de la session. Releve :
`waydroid_base.prop` date de **10 h 44**, ne porte aucun des trois reglages, et
le conteneur a demarre a **16 h 52** sans le regenerer.

`multi_windows` faisait exception, et **par accident** : c'est une propriete
`persist.`, que `s-android` repose a chaque lancement et qu'Android garde dans
son propre magasin. Un seul des trois reglages marchait, pour une raison qui
n'avait rien a voir avec le mecanisme cense les poser.

`s-android` appelle desormais `waydroid upgrade -o` — que l'amont decrit lui-meme
comme *« just for updating configs »* — et **son garde interroge Android au lieu
de relire le fichier**. C'est la lecon de la passe, et elle est ancienne :
*« Je ne peux pas voir » n'est pas « il n'y a rien »*, et son symetrique, *« le
fichier le dit » n'est pas « la machine le fait »*.

### Et l'outil ecrit pour detecter le succes silencieux l'a commis

`controler_place_rpm`, dans la piece neuve du Grimoire, filtre la liste des
fichiers d'un paquet et refuse ceux qui se posent hors de `/usr`. Essaye sur
**`vivaldi-stable`** — le paquet qui, dans ce projet, a coute un detour entier
par `/opt` — il a repondu **« tout est dans /usr »**.

Parce que le paquet n'est pas dans les depots actives ici : `repoquery` a rendu
une liste **vide**, le `grep` n'a rien trouve, et l'absence de mauvaise nouvelle
a ete lue comme une bonne. Corrige : une liste vide rend desormais 2 et dit
qu'on ne peut rien conclure. *Le defaut a ete trouve en exercant la fonction
dans les deux sens, pas en la relisant.*

### Ce que cette passe ne prouve pas

- **Le glitch d'affichage de Waydroid n'est toujours pas diagnostique** — et on
  sait maintenant que le gel du conteneur, qu'on l'accusait d'avoir cause,
  **n'a jamais ete desarme**. L'hypothese redevient testable.
- **La densite n'a pas encore ete versee sur cette machine** : le correctif est
  ecrit, `waydroid upgrade -o` n'a pas tourne. Android est toujours a 180.
- **La capture de la Galerie n'est pas prise.** Le bureau virtuel vide rend une
  image **blanche** : ni Constellation ni la barre n'y sont — donc un second
  bureau virtuel donne aujourd'hui un ecran sans bureau et sans barre, ce qui est
  un defaut a part entiere, releve et non corrige.
- ~~**`bootc rollback` n'a toujours pas ete exerce.**~~ **Exerce le 2026-08-25
  a 19 h 49.** Les deux deploiements etaient mesures ainsi a 17 h : celui qui
  tournait (`1c3b96d2`, 16 h 46) portait le clavier CSA et la cible corrigee ;
  la cible du rollback (`39f70f4f`, 15 h 44) ni l'un ni l'autre. **La cible a
  change depuis** — le `bootc upgrade` de 19 h 31 l'a remplacee par
  `621bf38a`. Le raisonnement, lui, s'est verifie mot pour mot : revenir en
  arriere coute exactement les correctifs de l'image quittee, et un second
  rollback les rend. Voir la section de 19 h 55.
- **Rien de ces trois fichiers n'est dans l'image.** Le presse-papiers a tourne
  par injection `PYTHONPATH`, pas depuis `/usr`.

---

## 2026-08-25, fin d'apres-midi — le clavier importe de Windows, et une session qui tenait par accident

Demande de l'utilisateur : *« peux-tu me trouver mon language de clavier dans
windows et me l'importer ? francais canadien multilangue standard »*. La reponse
etait dans le registre du Windows monte sous `~/Windows`, et le chemin pour l'y
lire a fait tomber deux defauts qui n'avaient rien a voir avec le clavier.

### Ce que Windows dit, lu dans sa ruche et non suppose

Aucun lecteur de ruche n'existe dans l'image — ni `hivexsh`, ni `chntpw`, ni
`reglookup` — et **on ne superpose pas un paquet pour repondre a une question**.
Un lecteur `regf` minimal en Python pur suffit : l'en-tete, les cellules `nk`,
`vk`, `lf/lh/li/ri`, et de quoi descendre un chemin.

```
HKCU\Keyboard Layout\Preload      1 = 00000c0c   2 = 00001009
HKCU\Keyboard Layout\Substitutes  00000c0c → 00011009
                                  00001009 → 00011009
HKLM\...\Keyboard Layouts\00011009
    Layout Text = "Canadian Multilingual Standard"
    Layout File = "KBDCAN.DLL"
```

**Les deux entrees clavier de Windows pointent sur la meme disposition.** Son
equivalent xkb est `ca(multix)`, que xkeyboard-config nomme « Canadian (CSA) » —
meme norme CSA Z243.200, verifiee touche par touche dans
`/usr/share/X11/xkb/symbols/ca` : `/ \ |` a gauche du 1, `é` sur la touche `?`,
`ç ~` sur `[`, `è à`, `« »` en AltGr sur `z x`, AltGr en niveau 3 et **Ctrl
droit** en niveau 5. C'est la signature de la CSA, et rien d'autre ne l'a.

*Note de sequence :* les deux numeros de la ruche etaient egaux, donc elle est
propre — aucun journal de transaction en attente. Lire une ruche sale rendrait
des valeurs perimees sans le dire.

### Et la session tapait en QWERTY americain

Voila le defaut, et personne ne l'avait vu : `localectl` annoncait `ca` pendant
que la session tapait `us`. Mesure en dumpant le keymap compile reellement
recu — `grave` a gauche du 1, `slash` sur `AB10`, `bracketright` la ou la CSA
met `ç`.

**`kwin_wayland` 6.7 ne lit NI `/etc/vconsole.conf`, NI
`/etc/X11/xorg.conf.d/00-keyboard.conf`, NI `XKB_DEFAULT_*`.** Il lit
`~/.config/kxkbrc`, groupe `[Layout]` — et ce fichier n'est ecrit que par le
module de reglages clavier de Plasma, qui ne tourne pas ici puisque la coquille
est Constellation. Faute de fichier, **il retombe sur `us` sans un mot**. Le
succes silencieux, encore, pris par le bout ou personne ne regarde.

`s-session` ecrit donc `kxkbrc` depuis la seule source de verite du systeme, et
**jamais par-dessus un fichier existant** : le jour ou l'utilisateur choisit sa
disposition, c'est son choix qui doit tenir. Eprouve dans les deux sens sur un
dossier personnel factice — sans fichier il produit `ca`/`multix` et le
journalise, avec un fichier il n'y touche pas.

**Ce que `kxkbrc` ne fait pas :** se relire a chaud. Ni `reconfigure`, ni le
signal `org.kde.keyboard.reloadConfig` que kwin declare pourtant ecouter ne le
lui font relire — les deux essayes, sans effet. Il faut rouvrir la session.

### Quatre bancs, dont trois mentaient — et c'est la lecon de la passe

Pour savoir quelle source kwin honore, il a fallu quatre bancs :

| Banc | Ce qu'il rendait | Ce qu'il valait |
|---|---|---|
| kwin imbriqué (backend Wayland) | toujours `us` | **faux** — un kwin imbrique **herite du clavier de son hote** |
| kwin `--virtual` | toujours `us` | **faux** — aucun peripherique clavier, donc aucun keymap emis |
| `strings` sur `libkwin` | pas de `kxkbrc` | **faux** — les litteraux Qt sont en **UTF-16**, invisibles a `strings` en ASCII. `strings -e l` rend `kxkbrc`, `kwinrc`, `org.kde.keyboard`, `reloadConfig` |
| kwin neuf sur **son propre bus** (`dbus-run-session`) | `"ca" … "Canadien (CSA)"` | **le seul concluant** |

Le banc concluant a aussi servi de temoin : en declarant deux dispositions,
kwin en annonce deux — donc il lit bien le fichier.

### La cible de session ne tenait que par accident, et le journal le disait

Trouve en regardant le journal du demarrage de 15 h 50, pas en relisant du code :

```
15:50:31  Reached target s-session.target
15:50:31  Stopped target s-session.target
15:50:31  graphical-session.target: Failed to enqueue stop job, ignoring:
            Transaction ... is destructive (kunifiedpush-distributor.service
            has 'start' job queued, but 'stop' is included in transaction)
```

`s-session.target` portait **`StopWhenUnneeded=yes`**. Une cible demarree par
`systemctl --user start` n'est reclamee par personne : aucune autre unite ne la
porte en `Wants=` ni en `Requires=`. Elle etait donc jugee superflue **a
l'instant meme ou elle venait d'etre atteinte**, et s'arretait — emportant
`graphical-session.target`, qui porte elle aussi `StopWhenUnneeded=yes`.

**Si le portail XDG, gvfs et l'accessibilite ont survecu ce jour-la, c'est parce
que l'arret a echoue sur une course.** Un demarrage sans cette course aurait
fait retomber la cible graphique — donc exactement la panne que ce fichier a ete
ecrit pour reparer le 2026-08-24, un jour plus tot.

**Eprouve, et le premier banc ne l'etait pas assez :** deux cibles factices,
identiques a cette ligne pres. Le premier essai laissait la cible graphique
debout dans les deux cas — parce que ma copie de `graphical-session.target`
n'avait pas le `StopWhenUnneeded=yes` que la vraie porte. Rendu fidele :

| | cible de session | **cible graphique** |
|---|---|---|
| avec `StopWhenUnneeded` | inactive | **inactive** |
| sans | active | **active** |

Au passage, un doublon retire : `s-session.target` existait **dans l'image ET
dans `~/.config/systemd/user/`**, pose a la main le 2026-08-24. Identiques ce
jour-la, et c'est celui du dossier personnel qui gagnait — il n'aurait jamais
recu ce correctif. *Deux fichiers qui doivent rester d'accord finissent toujours
par diverger*, et ce carnet le repete depuis `s-partage`.

### Fonds.js : un garde pose, une cause NON trouvee, et c'est ecrit ainsi

Le journal porte trois `createRadialGradient(): Incorrect arguments`, aux lignes
41, 66 et 80 de `Fonds.js`. Qt ne leve ce message que sur une valeur **non
finie**.

L'hypothese evidente — *le canevas peint avant d'avoir une taille* — **a ete
essayee et refutee au banc** : un Canvas de dimension nulle ou `NaN` n'appelle
jamais `onPaint`. Il ne peut donc pas produire cette erreur. Et le banc lui-meme
a menti une fois de plus avant de le dire : **en `QT_QPA_PLATFORM=offscreen`,
`onPaint` n'est jamais appele du tout** — sonde posee, zero appel. Un banc qui
ne peint rien ne prouve rien.

Ce qui est pose est donc un **garde doublé d'un temoin**, sur les deux appelants
de `Fonds.js` — le fond du bureau et les vignettes du menu : on refuse de
peindre une surface impossible, **et on ecrit les dimensions recues**. La
prochaine occurrence nommera sa cause au lieu de la cacher. *La cause n'est pas
corrigee ; elle est rendue lisible.*

### Ce que la machine a appris sur elle-meme

Releve du 2026-08-25 a 16 h, sur une machine redemarree a 15 h 50 :

| | |
|---|---|
| Image | `sha256:39f70f4f…`, **et c'est exactement le digest publie sur ghcr** |
| Code | `Barre.qml`, `Constellation.qml`, `Session.qml`, `fenetres.py`, `fenetres.js`, `s-android`, `s-constellation` — **identiques entre le depot et l'image en cours** |
| Unites en echec | **aucune**, systeme et session |
| Android | 32 lanceurs, Play Store lance 2 fois, YouTube 4 |
| Waydroid | les trois reglages **appliques** |
| Sauvegarde | `S-sauvegarde-2026-08-25-15h37`, 182 Mo, sur le grand disque |

**Deux details de methode, qui coutent une heure a qui ne les connait pas :**

- ~~**Les recettes `ghcr-*.sh` du Grimoire rendent 404 aujourd'hui.**~~
  **Corrige le 2026-08-25 au soir, et le constat etait a moitie faux :**
  `ghcr-peser-couches.sh` envoyait deja les quatre types et marchait
  (147 couches, 7,29 Go, releve ce jour-la). Seule `ghcr-visibilite.sh` etait
  cassee — et pas seulement cassee : elle repondait **« PRIVE » sur un paquet
  public**. Elle ne demandait que des types d'INDEX, or le manifeste publie est
  un `oci.image.manifest.v1`. Un 404 « pas de ce type-la » etait lu comme un
  refus de permission. *La recette ecrite pour corriger un faux verdict de
  visibilite en rendait un autre, a l'envers.* Elle envoie desormais les quatre
  types, distingue 404 de 401/403, et gagne `ghcr_digest` — qui sert a savoir
  si la CI a fini de publier.
- **`gh` n'est pas installe sur cette machine.** La CI ne se verifie plus en
  ligne de commande depuis que le depot a demenage ; on interroge `ghcr.io`
  directement.

### Ce que cette passe ne prouve pas

- **Le clavier CSA n'a pas encore ete tape.** `kxkbrc` est pose et `localectl`
  regle, mais kwin ne relit ce fichier qu'a son demarrage : il faut une
  reconnexion, et c'est l'utilisateur qui l'exercera le premier.
- **Le correctif de `s-session.target` n'est pas dans l'image.** Il est prouve au
  banc, pas sur la vraie cible — qui refuse le demarrage manuel, et qu'on ne
  fait pas tomber pour voir sur une session qu'on est en train d'utiliser.
- **La cause des erreurs de `Fonds.js` reste inconnue.** Seul un temoin a ete
  pose.
- ~~**Le presse-papiers Linux↔Android n'existe toujours pas.**~~ **Corrige le
  2026-08-25 a 17 h** — il ne manquait qu'un paquet. Voir la section de 17 h.
- ~~**`bootc rollback` n'a toujours jamais ete exerce.**~~ **Exerce le
  2026-08-25 a 19 h 49 — voir la section de 19 h 55.**

---

## 2026-08-25, soir — la sauvegarde suit le depot sur la machine

`banc/sauvegarder-le-projet.ps1` tournait sur la machine de developpement
Windows. Le depot vit maintenant sur S ; la sauvegarde devait suivre.
`banc/sauvegarder-le-projet.sh` en est le pendant, et il garde les deux regles
qui font la valeur de l'original :

- **Le bundle est clone pour de vrai avant d'etre declare bon.** Un bundle qu'on
  n'a pas ouvert n'est pas une sauvegarde, c'est un espoir. Releve de la premiere
  passe : 95 commits, `HEAD 4c5e07f`.
- **Une empreinte par fichier.** « La copie est arrivee » doit etre une
  verification, pas une impression. 942 fichiers, 182 Mo, manifeste verifie
  apres coup — et re-verifie apres deplacement.

Il emporte aussi ce que le depot ne garde pas : le banc `S-vm/` sans ses images
disque, et surtout **la memoire, les skills et les transcriptions de Claude
Code**, qui sont le seul endroit ou vit le raisonnement ayant produit le code.
Le depot n'en garde que le resultat.

### Et une destination qui a du changer avant meme la premiere sauvegarde

Elle allait dans `~/Partage`, le dossier des trois mondes — l'endroit evident
pour « travailler ailleurs ». **C'etait une faute**, et le relevé la nomme :

```
group:1023:rwx          # media_rw d'Android
default:group:1023:rwx
```

`~/Partage` est lisible par **toute application Android autorisee au stockage**.
Or cette sauvegarde contient la cle privee du banc. Elle va donc sur le grand
disque, que seul Linux voit.

C'est la meme famille de faute que le mot de passe du banc pousse en clair le
2026-08-20 : un secret depose dans un endroit pratique, sans se demander qui
d'autre le lit.

---

## 2026-08-25, soir — l'etiquette qui empechait d'atteindre ce qu'elle nommait

Petit irritant rapporte par l'usage, et c'est un vrai defaut d'interface :
survoler une epinglee de la barre faisait apparaitre son nom **par-dessus la
pastille**, presque aussitot, et le clic tombait donc sur l'etiquette.

Il n'y a pas la place de poser l'infobulle en dessous — la barre touche le bas
de l'ecran. Qt la met donc par-dessus, et son delai de 400 ms est plus court que
le temps qu'on met a viser. **Une etiquette qui empeche d'atteindre ce qu'elle
nomme est pire que pas d'etiquette du tout.**

Les epinglees descendent de sept pixels ; avec les onze deja libres au-dessus,
cela fait dix-huit pixels ou le nom s'ecrit sans rien couvrir. L'infobulle de Qt
disparait au profit d'une etiquette unique, portee par la barre elle-meme et
bornee aux deux extremites — une epinglee tout a gauche ne doit pas envoyer son
nom hors de l'ecran.

**Jugee sur l'image, pas sur l'intention** : rendue avec l'etiquette forcee
visible, dans une seconde barre lancee a cote de la vraie et titree autrement
pour que la regle kwin ne la place pas au meme endroit. Sans cette precaution la
capture montrait la barre de l'image en cours, et j'aurais valide un correctif
que je n'avais pas regarde.

---

## 2026-08-25, soir — deux defauts que le journal a nommes en trois lignes

La barre marche. Restaient deux choses, et **les deux etaient ecrites dans
`~/.local/state/s/coquille.log`** avant que je regarde quoi que ce soit. C'est la
deuxieme fois de la journee ; le reflexe est acquis.

### Reduire une fenetre demandait plusieurs clics

Le script d'activation lisait `workspace.activeWindow` **au moment ou il
tournait** — c'est-a-dire apres le clic, qui a pu deplacer le focus entre-temps.
Il concluait « elle n'est pas active » et la reactivait : rien ne bougeait a
l'oeil. Il fallait un second clic pour que la lecture tombe juste.

**La barre, elle, sait ce qu'elle vient d'afficher** : chaque tuile porte l'etat
`active` que le rapporteur lui a donne, et c'est cette verite-la que
l'utilisateur a cliquee. L'intention part donc avec le clic, au lieu d'etre
redevinee a l'autre bout.

Eprouve sur la machine, du premier coup :

| Demande | Resultat |
|---|---|
| `activer(id, deja_active=True)` | `reduite=true` |
| `activer(id, deja_active=False)` | `reduite=false, active=true` |

### Le fond d'ecran, et deux correctifs faux avant le bon

Les vignettes s'affichaient, le clic arrivait, et le gestionnaire mourait a sa
premiere ligne. Trois etats successifs, tous lus dans le journal :

| Essai | Ce que la machine a repondu |
|---|---|
| `bureau.fondActuel = …` | `ReferenceError: bureau is not defined` |
| `Window.window.fondActuel = …` | `QML TapHandler: Window.window does only support types deriving from Item`, puis `TypeError: Value is null` |
| `Session.bureau.fondActuel = …` | — |

**`Window.window` etait une bonne idee mal placee** : c'est bien un type attache,
donc insensible aux identifiants, mais il ne s'attache qu'a un `Item` — et un
`TapHandler` n'en est pas un.

**Ce qui resout a coup sur dans ces delegues etait sous les yeux depuis le
debut** : cinq lignes au-dessus du gestionnaire qui echouait, `Theme.texte2` est
lu sans erreur. Un singleton n'est pas cherche dans la chaine des contextes,
c'est un type resolu a la compilation. D'ou `Session.qml`, un singleton d'une
seule propriete, que le bureau remplit lui-meme au demarrage.

**Et le meme defaut frappait ailleurs, sans que personne l'ait signale** :
`Constellation.qml:403`, l'epinglage depuis le menu Demarrer — la phrase de
confirmation n'arrivait jamais. Meme cause, meme correctif.

### Ce que cette passe ne prouve pas

- **Les delegues du menu ne s'instancient pas dans le banc hors ecran.** Trois
  sondes y ont ete posees et aucune n'a parle : `GridView` et `Repeater` a
  l'interieur d'un `Popup` invisible ne fabriquent rien. La resolution de
  `Session` dans ces delegues est donc **deduite** de celle de `Theme`, qui y est
  lue sans erreur sur la machine — pas mesuree directement.
- ~~Aucun des deux correctifs n'a ete clique a la souris.~~ **Les deux l'ont
  ete**, et ce sont les fichiers d'etat qui le disent, pas une impression :
  `reglages.json` porte `{"fond": "trois"}` a 15 h 28 — donc une vignette a ete
  cliquee et le fond a change — et `epingles.json` porte quatorze epinglees a
  15 h 29. Le premier correctif avait deja ses deux sens prouves par appel
  direct ; celui-la ne pouvait l'etre qu'a l'ecran, et il l'a ete.

---

## 2026-08-25, soir — le journal disait tout, et j'ai construit un banc pour rien

Quatre defauts rapportes par l'usage. Trois sont corriges et mesures ; le
quatrieme a revele une limite de Waydroid qu'il faut ecrire plutot que cacher.

### Le clic ne faisait rien, et la cause etait ecrite depuis le premier clic

```
Barre.qml:247: TypeError: Property 'activer' of object [object Object],[object Object] is not a function
```

`[object Object],[object Object]`, c'est **le tableau des fenetres**. Dans
`Barre.qml`, la propriete `property var fenetres` — la liste — **masquait** la
propriete de contexte `fenetres`, qui porte le pont vers kwin. Le nom nu
designait donc la liste, et `fenetres.activer(...)` cherchait une methode sur un
tableau. **Le clic arrivait parfaitement ; c'est le gestionnaire qui explosait.**

Une collision de noms que rien ne signale : QML ne previent pas qu'une propriete
de composant masque une propriete de contexte, et le controleur de construction
ne peut pas la voir — elle n'echoue qu'au clic, a l'execution.

La liste s'appelle desormais `ouvertures`, et **la barre ne parle plus au pont
du tout** : elle emet un signal, Constellation agit. Meme patron que
`menuDemande`, qui lui a toujours marche — et c'est la ce qu'il fallait
remarquer, puisque les deux voisins se comportaient differemment.

**Ma methode a ete mauvaise, et c'est la lecon de la passe.** J'ai bati un banc
a evenements synthetiques pour savoir si le clic arrivait. Il a repondu « aucun
clic recu » — puis, mis a l'epreuve sur une fenetre temoin vide de trois lignes,
**il a repondu la meme chose**. `sendEvent` sur une `QQuickWindow` ne livre rien
en PySide6. Le banc accusait le code d'un defaut qui etait le sien, pour la
troisieme fois dans ce carnet.

Le journal de la coquille, lui, portait la reponse exacte, horodatee, repetee a
chaque clic. **Ouvrir `~/.local/state/s/coquille.log` coutait cinq secondes.**

### Et le journal en portait un second, que personne n'avait demande

```
Constellation.qml:497: ReferenceError: bureau is not defined
```

Sept fois — sept clics de l'utilisateur sur une vignette de fond d'ecran, sans
effet. **Changer de fond d'ecran ne marchait pas**, et ce defaut est anterieur a
toute la journee. Le delegue des vignettes est instancie dans un contexte ou
l'identifiant racine du fichier ne porte pas. `Window.window` est un *type
attache*, pas un identifiant : il traverse n'importe quel contexte.

### Les fenetres s'arretent au-dessus de la barre

C'etait annonce comme une limite du protocole, et c'en est une : un client
Wayland ne reserve pas d'espace sans `zwlr_layer_shell_v1`. Mais **le script
kwin, lui, tourne dans le compositeur** — il n'a pas besoin de demander la
permission de deplacer une fenetre. Il rattrape donc, apres coup, toute fenetre
dont le bas depasse la limite.

Mesure sur la machine, une Konsole maximisee :

| | avant | apres |
|---|---|---|
| Konsole | `y=0 h=1080 bas=1080` | **`y=0 h=1028 bas=1028`** |

**Et la premiere version s'est bornee elle-meme** : la barre, dont le bas est a
1080, a ete remontee de 52 pixels par la regle qu'elle venait de poser. Un
garde-fou qui s'applique a son propre garde se mord la queue. Les fenetres de S
en sont exclues nommement.

**Le vrai plein ecran n'est pas touche** — une barre par-dessus un film serait
pire que le defaut qu'on repare.

### Android : le gel, la demesure, et une fenetre qui refuse de retrecir

*« Après une seconde d'inactivité je vois le bureau à travers. »* La cause est
dans `waydroid.cfg` : **`suspend_action = freeze`**, et la machine a deja ete
relevee avec *Session RUNNING / Container FROZEN*. Un conteneur gele cesse de
rendre — au bout d'une seconde, la surface ne se redessine plus et le bureau
apparait au travers. Ce n'est pas un defaut d'affichage : c'est une economie
d'energie pensee pour un telephone dans une poche, appliquee a une fenetre qu'on
regarde. Corrige en `none`.

*« Tout est tellement gros que je ne vois presque rien. »* `ro.sf.lcd_density`
vaut **180**, pensee pour un ecran tenu a trente centimetres. Sur un 1920x1080
de bureau, Android croit avoir 1707 points de large la ou il en a 1920. A
**140**, il en compte 2194.

Les trois reglages entrent dans `waydroid.cfg` par `s-android`, et **le garde
porte sur les trois**, pas sur un seul : une machine qui a recu le premier avant
que les deux autres n'existent doit encore les recevoir. Sinon le correctif ne
rattrape que les installations neuves — exactement la faute que ce carnet
reproche aux marqueurs de premier demarrage de l'amont.

**Une limite mesuree, et elle reste :** une fenetre Waydroid **refuse de
retrecir**. Releve sur YouTube Android — `normalWindow=true`,
`fullScreen=false`, `resizeable=true`, et pourtant une hauteur imposee a 1028
laisse la fenetre a 1080. Android decide la taille de ses surfaces et le
compositeur ne l'en fait pas demordre. Les fenetres Android couvriront donc les
52 derniers pixels ; la barre etant toujours au-dessus, on la voit quand meme.

### Ce que cette passe ne prouve pas

- **Le clic n'a toujours pas ete essaye a la souris.** La cause est certaine —
  le journal la nomme — et le correctif la supprime, mais c'est l'utilisateur
  qui l'exercera le premier.
- **Le bornage n'a ete essaye que sur une Konsole**, une seule fois, sur un seul
  ecran.
- ~~Les trois reglages Waydroid n'ont pas ete appliques sur cette machine.~~
  ~~**Ils le sont** — releve dans `/var/lib/waydroid/waydroid.cfg` le 2026-08-25
  a 16 h.~~ **FAUX, corrige le 2026-08-25 a 17 h : ce releve lisait le fichier
  de configuration, pas la machine.** Un seul des trois est effectif.
  `waydroid prop get ro.sf.lcd_density` rend **180**, pas 140 — `[properties]`
  n'est verse dans le conteneur que par `waydroid init` ou `waydroid upgrade`.
  Et `suspend_action = none` **n'existe pas** dans waydroid 1.6.3 : il tombe
  dans le `else` qui gele. Seul `multi_windows` marche, et par accident — c'est
  une propriete `persist.` reposee a chaque lancement. Voir la section de 17 h.
- **Le glitch d'affichage d'Android n'est toujours pas diagnostique** — et il se
  peut que le gel du conteneur en ait toujours ete la cause, ce qui reste a
  verifier plutot qu'a proclamer.

---

## 2026-08-25, apres-midi — une vraie barre des taches, et Android en fenetres

Deux demandes de l'utilisateur, toutes deux parties d'un usage reel : *« la
barre des tâches, j'aimerais pouvoir l'utiliser normalement, toujours visible en
bas »*, et *« les applis Android sont plein écran par défaut et l'image se brise
— je préfère des fenêtres »*.

### Android en fenêtres : une propriété, et cinq jours de suppositions tombent

`persist.waydroid.multi_windows` était **vide**. Sans elle, Waydroid rend **une
seule surface plein écran** où vit tout Android : une application lancée prend
l'écran entier, et rien ne se range à côté d'une fenêtre Linux. Posée à `true`,
session redémarrée, `kwin` voit ceci :

```
waydroid.com.android.documentsui | Files | 1920x1080 | fenetre
```

**Une vraie fenêtre, avec ses boutons de titre, et l'image est nette.** Le
« glitch » que ce carnet traîne non diagnostiqué depuis le 2026-08-23 ne s'est
pas reproduit une fois en mode fenêtré. Ce n'est pas une preuve qu'il est
corrigé — il n'a pas été *cherché*, il a cessé d'apparaître — mais l'hypothèse
change de camp : le carnet supposait que `multi_windows false` serait un
*remède* au glitch, et c'est l'inverse qui s'est produit.

**Et cela éclaire un autre défaut, écrit dans `s-android` depuis le
2026-08-23** : le gel de l'écran « autoriser les sources inconnues » y était
attribué à *« une fenêtre que le multi-fenêtrage de Waydroid n'affiche pas »*.
Le multi-fenêtrage n'était pas activé du tout. Une boîte de dialogue qui n'a pas
de fenêtre à elle dans un Android plein écran ressemble exactement à un gel.

La propriété entre dans `[properties]` de `waydroid.cfg` — la persistance que
l'amont prévoit — **avant** le démarrage de la session, parce qu'elle est lue
quand le conteneur monte. Posée à chaud, elle ne prend qu'au démarrage suivant,
et l'utilisateur conclurait qu'elle ne marche pas.

### La barre des tâches : ce que Wayland refuse, et par où on passe

Une barre des tâches a besoin de deux choses qu'un client Wayland **n'a pas le
droit d'avoir** : la liste des fenêtres des autres, et le pouvoir d'en activer
une. Relevé sur la machine, dans les soixante-dix protocoles annoncés par
`kwin` :

| Protocole | État |
|---|---|
| `org_kde_plasma_window_management` | **absent** |
| `zwlr_foreign_toplevel_manager_v1` | **absent** |
| `zwlr_layer_shell_v1` | présent — mais aucune liaison Python de cette image ne sait le parler |

Les deux qui auraient servi ne sont pas là, et **c'est une décision de sécurité
juste** : une application qui énumère les fenêtres des autres peut les espionner.

**L'interface que kwin ouvre volontairement, elle, est son moteur de scripts.**
Un script kwin tourne *dans* le compositeur — il sait tout — et `callDBus` lui
permet de le dire au dehors. C'est la porte prévue, pas une porte forcée. Deux
sens, deux chemins différents :

- **kwin → S** : un script résident, `fenetres.js`, appelle Constellation à
  chaque fenêtre ouverte, fermée, activée, **renommée** ou réduite. Le titre
  compte autant que le reste : un navigateur qui change d'onglet ne crée pas de
  fenêtre, il renomme la sienne.
- **S → kwin** : un script kwin ne peut rien **recevoir** — pas de service, pas
  de file d'attente, pas même un fichier à relire. Le seul canal entrant est le
  chargement lui-même. On écrit donc un script d'une ligne qui porte
  l'identifiant, on le charge, on le lance, on le décharge.

Ce qui sort est délibérément pauvre : un identifiant, une classe, un titre, deux
états. Pas de capture, pas de contenu, pas de géométrie.

### La barre a quitté la scène du bureau, et il le fallait

Elle y était, en pilule flottante — donc **invisible dès qu'une fenêtre
s'ouvrait**, puisque le bureau reste derrière. Une barre qu'il faut dégager pour
voir n'en est pas une. Elle vit maintenant dans une fenêtre à elle, posée
au-dessus des autres par une règle kwin, comme la bulle.

**Ce que le protocole ne permet pas, et qu'il faut dire :** un client Wayland ne
réserve pas d'espace à l'écran. Cela demande `zwlr_layer_shell_v1` ou
`org_kde_plasma_shell`, que rien ici ne sait parler. **Une fenêtre maximisée
passe donc sous la barre au lieu de s'arrêter au-dessus.** C'est le prix, il est
connu, et il vaut mieux qu'une barre qu'on ne voit jamais.

Les deux règles kwin sont désormais posées **par Constellation** et non par
`s-coquille` : elles dépendent de la taille de l'écran, que seul un programme
connecté au compositeur connaît. La deviner en lisant `kscreen-doctor` serait
une seconde source de vérité pour une chose que Qt sait déjà.

### Éprouvé sur la machine, vers 13 h 55

| | |
|---|---|
| Le rapporteur | chargé dans kwin (`isScriptLoaded` → `true`), rejoue à chaque changement |
| La liste | trois fenêtres rendues avec classe, titre, actif, réduit |
| L'activation | `activer(id)` → la fenêtre visée passe à **`ACTIVE`** au rapport suivant |
| Android dans la barre | « Google Play Store », **liseré vert**, avec sa vraie icône, à côté de deux Konsole à liseré rouge |
| L'heure, les épinglées | en place, la grammaire des trois mondes conservée |

**Un défaut trouvé en essayant, pas en relisant :** `loadScript` existe en deux
versions sur le bus — `loadScript(s)` et `loadScript(ss)` — et `dbus-python`
choisit la première trouvée dans l'introspection, puis se plaint que Python lui
donne deux arguments. La barre s'ouvrait vide, et le journal parlait de
*« Fewer items found in D-Bus signature »*, ce qui ne ressemble en rien au
problème réel. La signature est désormais imposée à l'appel.

**Et une correction de lisibilité, mesurée à l'écran :** à 86 % d'opacité — le
verre des panneaux — le texte du bureau transparaissait à travers la barre et se
mêlait aux titres des fenêtres. Un panneau qu'on regarde de temps en temps peut
être translucide ; une barre qu'on lit pour choisir une fenêtre, non. L'aide du
bureau, elle, remonte de 52 pixels : elle était passée sous la barre.

### Ce que cette passe ne prouve pas

- **Rien n'est dans l'image.** Tout a tourné depuis le dépôt, dans une seconde
  Constellation lancée à côté de la vraie.
- **Le clic n'a jamais été essayé à la souris.** `activer()` a été appelée
  directement ; le chemin QML `TapHandler → fenetres.activer` est écrit et
  vérifié sans avertissement par le contrôleur de construction, pas exercé.
- **La capture de la Galerie montre l'ancienne barre flottante.** Elle est
  datée et vraie pour son image ; elle sera à refaire quand celle-ci sera posée.
- **Le glitch de Waydroid n'est pas diagnostiqué** — il a cessé d'apparaître, ce
  qui n'est pas la même chose.
- **La barre ne réserve pas son espace**, faute de layer-shell.

---

## 2026-08-25, midi — la coquille sait enfin parler, et la Galerie a son premier tableau

Deux chantiers que le carnet réclamait depuis le matin. Les deux sont finis, et
les deux ont coûté un détour qu'aucune relecture n'aurait trouvé.

### Constellation publie `org.freedesktop.Notifications`

Le correctif du matin avait détaché `notify-send` et l'avait borné à cinq
secondes : plus rien ne gelait, et les phrases de S partaient dans le vide.
Mesuré au bus juste après le redémarrage, la situation exacte :

```
org.freedesktop.Notifications    -  -  -  (activatable)  -
```

**Personne ne possédait le nom.** La coquille le prend désormais elle-même —
`files/usr/lib/s/notifications.py`, publié par `s-constellation` au démarrage.

**Trois formes ont été écrites, essayées sur la machine, et deux rejetées par la
mesure.** C'est la seule raison pour laquelle ce fichier n'est pas en QtDBus
comme le reste de la coquille :

| Forme | Ce qu'elle donnait |
|---|---|
| `QDBusVirtualObject`, XML d'introspection écrit à la main | `GetServerInformation` exact, mais **la réponse de `Notify` sortait avec le mauvais type** — un objet virtuel ne déclare rien à Qt, qui devine d'après la valeur Python, et un entier ne devient jamais un `u` |
| Slots exportés (`ExportAllSlots`) | `Notify`, `CloseNotification`, `GetCapabilities` **exacts**. Mais Qt déduit la signature du type déclaré dans le slot, et un slot Python ne peut pas rendre **quatre chaînes séparées** : `GetServerInformation` sortait en `as` au lieu de `ssss` |
| `QDBusContext` et réponse différée pour ce seul appel | **erreur de segmentation**, reproduite deux fois |

**Et la deuxième forme est le piège de la journée, parce qu'elle a l'air de
marcher.** Un appel direct de `Notify` répondait `u 1` ; l'introspection était
juste ; tout semblait bon. Mais **libnotify interroge `GetServerInformation`
avant d'afficher quoi que ce soit**, et `notify-send` répondait alors
*« Unexpected reply type »* sans jamais rien montrer. Le seul client que S
utilise partout était le seul que cette forme cassait — et le message ne
nommait pas la méthode fautive. **Le succès silencieux, une fois de plus, mais
déplacé d'un appel.**

La forme retenue est `dbus-python`, où la signature s'écrit au lieu de se
deviner : `out_signature="ssss"`, `out_signature="u"`.

**Et il n'y a pas deux boucles pour autant** — mesuré à l'exécution, pas
supposé : Qt utilise `QEventDispatcherGlib` sous Linux, donc il fait déjà
tourner le contexte principal de GLib, celui-là même auquel `DBusGMainLoop`
s'attache. Le service est servi **par la boucle de Qt**, sans fil supplémentaire.
Un repli en fil séparé est armé si jamais Qt était bâti sans GLib, parce que
sinon le service répondrait à personne et ne le dirait pas.

**Ce que S déclare savoir faire : `body`, et rien d'autre.** Annoncer `actions`
sans dessiner de boutons ferait afficher aux applications des choix qui
n'apparaissent nulle part.

### La bulle, et pourquoi elle ne peut pas se placer elle-même

Elle vit dans une **fenêtre à part**, pas dans la scène du bureau. Constellation
est une fenêtre plein écran que le compositeur garde **derrière** les autres —
c'est ce qu'on attend d'un bureau, et c'est ce qui rendrait une bulle invisible
pile au moment où elle sert.

Mesuré sur la machine : `Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint |
Qt.Tool` suffit à passer devant les autres fenêtres sous `kwin_wayland`.
**Mais les coordonnées `x` et `y` sont ignorées** — une fenêtre demandant
`x=1516 y=24` s'est affichée **au centre de l'écran**. Ce n'est pas un défaut de
Qt : un client Wayland ne se place pas lui-même, le compositeur décide.

Une règle kwin la pose donc en haut à droite. **Et elle ne peut pas vivre dans
l'image, ce qui contredit en apparence la règle « ce qui doit tenir va dans
l'image ».** KConfig cascade : le fichier de l'utilisateur l'emporte, et
`~/.config/kwinrulesrc` portait déjà une ligne `rules=` **vide** — or kwin ne lit
que les groupes nommés dans cette liste. Une règle livrée par `/etc/xdg` serait
masquée par une ligne vide du dossier personnel.

**Le contournement est donc dans l'autre sens : le code qui pose la règle, lui,
est dans l'image.** `s-coquille` l'exécute à chaque ouverture de session ; il se
répare tout seul si le fichier disparaît, et il n'écrase jamais les règles que
l'utilisateur aurait ajoutées.

Le titre de la fenêtre — `S - notification` — n'est pas décoratif : **c'est la
clef de la règle**. La bulle et le bureau appartiennent à la même application et
portent donc la même classe ; le titre est le seul moyen de les distinguer.

### Éprouvé sur la machine, le 2026-08-25 vers 12 h 45

| | |
|---|---|
| Signatures au bus | `Notify susssasa{sv}i → u`, `CloseNotification u`, `GetCapabilities → as`, `GetServerInformation → ssss` — **les quatre exactes** |
| `notify-send` | rendu en **0,031 s**, **sans erreur** |
| La bulle | **vue en haut à droite, par-dessus une konsole au premier plan**, capture à l'appui |
| Urgence critique | liseré et bordure rouges, **et elle ne part pas toute seule** |
| Expiration | posée à 3 000 ms, **absente 5 s plus tard** — mesuré en comparant la zone de la bulle sur deux captures |
| `CloseNotification` | ferme et rend la main sans erreur |

**Et `org.kde.plasma.Notifications.service` est remplacé dans l'image.** En
session normale il ne sert à rien, Constellation prenant le nom au démarrage. Il
ne compte que dans le cas contraire — coquille tombée, bureau de secours — et
là, son `Exec` pointe désormais sur `/usr/bin/false` : **échouer en quelques
millisecondes vaut mieux qu'attendre sans fin.**

### La Galerie a sa première pièce, et c'est la première rendue par un vrai GPU

`galerie/constellation/constellation-2026-08-25.png` — 1920 × 1080, prise à
12 h 23 sur `s`, rendue par **Mesa Intel UHD Graphics 630, pilote `i915`**.
Ce n'est pas `llvmpipe` : la réserve *JAMAIS JUGÉE SUR GPU* que la Galerie
impose aux transparences et aux dégradés **tombe pour cette pièce**.

L'index de la Galerie décrivait encore Constellation comme « une page servie par
son pont `s-etoiles` ». C'était faux depuis le 2026-08-24 ; c'est corrigé.

### Photographier la coquille était une recette à part entière

Trois pièges, et le troisième a été **commis par moi dans la recette censée
l'éviter** :

1. **L'API de capture de kwin est réservée.** `org.kde.KWin.ScreenShot2` est
   publiée, complète et alléchante — et elle répond
   `NoAuthorized: The process is not authorized to take a screenshot` à un
   script. kwin vérifie l'exécutable de l'appelant. Ce n'est pas contournable
   proprement, et c'est bien. On appelle donc `spectacle`, déjà dans l'image et
   déjà autorisé : *on ne réimplémente pas ce que l'amont maintient.*
2. **« Montrer le bureau » ne survit pas à la capture.** `showDesktop b true`
   marche une seconde ; dès que spectacle démarre, kwin voit une activation et
   sort du mode. Mesuré : juste après, `showingDesktop` valait déjà `false`, et
   l'image montrait la konsole par-dessus le bureau.
3. **`spectacle -a` réussit toujours, même quand on a visé le vide.** La
   première version de la recette, essayée avec un motif de classe inexistant,
   a rendu une image et le code 0 — celle de la fenêtre qui se trouvait active.
   Un fichier, un succès, et le sentiment d'avoir photographié ce qu'on
   demandait.

**Ce qui marche** : un script kwin chargé sur le bus pose l'activation sur la
fenêtre visée, puis `spectacle -b -n -a` la photographie. Rien n'est réduit,
donc rien n'est à restaurer — *une capture ne doit pas réorganiser la session
pour se réussir.*

**Et pour savoir si l'activation a trouvé sa cible**, alors qu'un script kwin ne
rend rien à l'appelant et que son `print` ne ressort ni dans le journal
utilisateur ni dans le journal système — vérifié : le script appelle, **quand il
a trouvé**, une méthode sur un nom de bus que personne ne possède. L'appel
échoue sans conséquence, mais un `dbus-monitor` lancé à côté le voit passer,
avec la classe trouvée en argument. **On se sert du bus comme d'un témoin, pas
comme d'un transport.** Les deux chemins sont éprouvés : image et code 0 sur la
coquille, aucun fichier et code 1 sur un motif absent.

La recette est au Grimoire — `kwin-capturer-la-coquille.sh`, `PREUVE:` datée.

### La première construction est tombée, et c'est le garde-fou qui l'a fait tomber

Le contrôle ajouté à `36-constellation.sh` vérifie que le `.service` de Plasma a
bien été recouvert, en cherchant `plasma_waitforname` dans le fichier. Il l'a
trouvé — **dans le commentaire que j'y avais écrit pour expliquer ce qu'on
remplaçait** :

```
#     Exec=/usr/bin/plasma_waitforname org.freedesktop.Notifications
```

Construction rouge, code juste, garde-fou faux. **Un contrôle qui cherche une
chaîne trouve aussi la documentation qui l'explique** — et ce dépôt commente
beaucoup, donc le piège reviendra. Le contrôle lit désormais la ligne `Exec`,
ancrée en début de ligne, et il est éprouvé dans les deux sens : il laisse
passer notre fichier, et il attrape celui de Plasma.

Au passage, une leçon de méthode : le journal de construction n'était pas
lisible sans droits d'administrateur sur le dépôt, donc la cause n'a pas été
lue mais **rejouée** — les trois contrôles neufs relancés un à un contre le
dépôt, sur la machine. Le deuxième a échoué en deux secondes. *Rejouer coûte
moins cher que demander l'accès.*

### Le geste disait le contraire du service, sur la même machine

Premier essai après le redémarrage, `s-partage` tapé à la main :

```
s-partage : Android  : Waydroid pas encore initialise — rien a lier pour l'instant
```

**C'était faux.** Le journal du même démarrage dit que `s-partage.service` avait
posé le montage treize secondes après l'allumage, et `findmnt` le confirmait.
Le service et le geste, dans le même fichier, se contredisaient.

**Deux défauts superposés, et le premier est une leçon sur la correction du
matin.** Le raisonnement « les données vivent à côté de la configuration » a été
corrigé le 2026-08-25 dans le mode root de `s-partage` — **et pas dans
`s-monde`**, où vivait la même recherche pour le mode utilisateur. Or
`s-partage` porte en tête, écrit noir sur blanc : *« deux fichiers qui doivent
rester d'accord finissent toujours par diverger »*. Il en était un. La recherche
vit désormais dans `/usr/lib/s/partage-android.sh`, sourcé des deux côtés.

**Le second défaut aurait survécu à la correction du premier.** Le dossier de
données d'Android est en `drwxrwx---` sous un UID qui n'existe pas sur l'hôte —
relevé sur la machine. Un `test -d .../data/media/0` lancé par l'utilisateur
répond donc **faux**, non parce que le dossier manque, mais parce qu'on n'a pas
le droit de regarder. `mountpoint` échoue pour la même raison.

C'est **le succès silencieux pris par l'autre bout** : au lieu d'annoncer une
réussite qui n'a pas eu lieu, le script annonçait un échec qui n'existait pas —
avec la même assurance, et une cause inventée. *« Je ne peux pas voir » n'est
pas « il n'y a rien ».*

La réponse se lit dans `/proc/self/mountinfo`, **qui se lit sans aucun droit sur
ce qu'il décrit**. Le geste dit maintenant, sur la même machine, à la même
seconde : `Android : /sdcard/Partage (deja lie)`. Et quand il ne peut vraiment
pas savoir, il distingue les deux cas plutôt que d'en inventer un.

### L'indice que S se passait à lui-même n'était pas honoré

`s_dire` envoie `x-canonical-private-synchronous:s-couture` à chaque phrase.
Cela veut dire *remplace la précédente, ne l'empile pas* — et le serveur du
matin l'ignorait, ce qui aurait fait défiler six bulles à la file pour une seule
couture bavarde. Il est honoré, et éprouvé : trois phrases d'une même couture
reçoivent le même identifiant, une phrase sans indice en reçoit un autre.

**Vu à l'écran, depuis l'image, pas depuis le dépôt :** la bulle « Partage — Le
dossier partagé est lié dans les trois mondes », en haut à droite, envoyée par
la commande exacte que `s_dire` compose.

### Ce que cette passe ne prouve pas

- **Rien de tout cela n'est dans l'image.** Le service, la bulle, la règle kwin
  et le remplacement du `.service` sont dans le dépôt et ont tourné **depuis le
  dépôt**, sur un banc qui charge `Bulle.qml` sans ouvrir un second bureau. Il
  faut une construction et un `bootc upgrade`.
- **La bulle n'a jamais été affichée par Constellation elle-même**, seulement
  par ce banc. Le branchement dans `Constellation.qml` est écrit, pas exercé.
- **Le repli en fil GLib n'a jamais servi** — la boucle de Qt a toujours suffi
  ici.
- **Aucune application réelle n'a encore notifié S.** Les essais viennent tous
  de `notify-send` et de `busctl`.

---

## Où on en est — 2026-08-24 *(dépassé, voir plus haut)*

**S tourne sur le NVMe, Windows est passé sur la Seagate, et les deux coutures
que ce carnet réclamait depuis le 20 août existent.** Trois chantiers menés le
2026-08-24, tous partis d'une mesure sur la machine plutôt que d'une intention.

### Ce qui a été mesuré, et qui contredisait ce carnet

| Ce qu'on croyait | Ce que la machine a dit |
|---|---|
| Le fond de S est posé partout | `35-identite.sh` n'écrivait `Image=` que dans les paquets look-and-feel en portant déjà une — `com.valve.vapor` n'en a pas, et c'est lui que `/etc/xdg/kdeglobals` impose. Le fond était dans **neuf paquets inertes et absent du seul qui sert** |
| L'écran de verrouillage suit le look-and-feel | Non : `/etc/xdg/kscreenlockerrc`, livré par la base, pointe en dur sur `convergence.jxl`. Rien dans S ne le recouvrait |
| L'écran d'amorçage attend une décision | `43-amorcage.sh` était écrit depuis le 23 mais **jamais branché** dans le Containerfile |
| La session graphique existe | `graphical-session.target` était **inactive**, et le gestionnaire systemd de l'utilisateur ne connaissait **aucune** variable de session |

**La dernière ligne est la plus coûteuse, et elle explique des pannes qu'on
attribuait ailleurs.** Tout ce qui porte `PartOf=graphical-session.target` ne
démarrait jamais : `xdg-desktop-portal`, `gvfs-*`, `at-spi`, et
`plasma-dolphin` — le gestionnaire de fichiers — qui était en échec. Et comme
le portail est **le seul chemin** par lequel un programme Windows peut demander
« ouvre cette page » depuis le bac à sable de Proton, un clic sur « Login »
dans Cursor ne produisait rien du tout. Pas une erreur : rien.
`s-session.target` tire désormais la cible, même patron que
`plasma-workspace.target`.

### Constellation n'est plus une page web

Elle était servie en HTTP sur `127.0.0.1:7373` et affichée par Vivaldi en
`--app`. C'est un client Wayland natif QtQuick : plus de navigateur, plus de
port ouvert, plus de moteur de rendu web dans la session. Le moteur
d'inventaire n'a pas été réécrit mais **extrait** dans `files/usr/lib/s/noyau.py`
— 17 fonctions sur 18 identiques au mot près, seule `composer_etoiles` refaite.

Le clic droit **n'existait pas** : il tombait sur le menu du navigateur.
L'épinglage non plus — la barre affichait `ordre[:7]`, les sept plus lancées,
sans aucune prise. Les deux existent maintenant.

**Trois défauts trouvés en rendant la scène, pas en la relisant** — et aucun
n'aurait été visible autrement :

- `MultiEffect` ne dessine **rien** sans shaders : l'étoile sortait vide, sans
  message ;
- un `Shape` **ne respecte pas le découpage de ses ancêtres**, vérifié au rendu
  logiciel *et* sur le vrai pipeline GPU — les anneaux des tuiles hors panneau
  se peignaient par-dessus le bureau ;
- `Popup { Item { anchors.fill: parent } }` ne parente pas où l'on croit.

`build_files/verifier-constellation.py` charge désormais la scène **pendant la
construction**, avec un pont leurre, et fait échouer l'image au moindre
avertissement QML. Éprouvé contre deux fautes délibérées.

### Les coutures

**Le dossier partagé existe** : un seul dossier, trois noms — `~/Partage` sous
Linux, `P:\` sous Windows, `/sdcard/Partage` sous Android. Lien symbolique dans
`dosdevices` d'un côté, montage lié de l'autre : un lien symbolique ne survit
pas à la couche de stockage d'Android. Cinq comportements éprouvés au banc,
dont un fichier écrit sous Linux relu en `P:\essai.txt`.

**Et le retour des connexions Windows.** Un logiciel Windows moderne se connecte
en renvoyant vers `monappli://callback?token=…`. Il inscrit ce protocole dans le
registre **du préfixe**, que Linux ne lit pas. `s-lien-windows` et `registre.py`
l'y lisent et le déclarent côté Linux. Sur le préfixe réel : 1 protocole trouvé,
200+ types de fichiers écartés.

### Une correction à ce que j'ai écrit dans le commit

Le message de `7d4d324` dit que Waydroid n'avait jamais tourné faute d'une
ligne. **C'est trop fort, et ce carnet dit le contraire plus bas :** Android a
tourné le 2026-08-23. Le fait exact est plus étroit :
`waydroid-container.service` n'était pas **activé**, donc `dev-binderfs.mount`
— qui est `static` et ne se lève que tirée — n'était jamais montée au
démarrage. `s-android` compensait en démarrant le conteneur à la main via
`pkexec`. L'activer supprime l'invite de mot de passe et rend Android
disponible dès l'ouverture de session ; ça ne débloque pas cinq jours.

### Ce qui n'est toujours pas éprouvé

- **`43-amorcage.sh` n'a jamais tourné.** Il régénère l'initramfs, seul
  changement du dépôt qui puisse empêcher la machine de démarrer. Il est branché
  dans cette version. ~~`bootc rollback` n'a toujours jamais été exercé.~~
  *(Exercé le 2026-08-25 à 19 h 49 — voir la section de 19 h 55.)*
- **La coquille native n'a jamais démarré une vraie session.** Elle a été rendue
  en image, hors écran, sur les deux pipelines — jamais ouverte par le greeter.
- **Le presse-papiers commun n'existe pas.** Linux↔Windows fonctionne déjà, Wine
  s'en charge. Linux↔Android demande un pont, et il n'a pas été écrit : il ne
  peut pas être mesuré tant que Waydroid n'a pas redémarré sur cette
  installation.
- **`s-partage` côté Android n'a jamais été exercé** — le montage lié attend que
  `waydroid init` ait déplié ses données.

`banc/etat-des-mondes.sh` relève tout cela d'une commande, sur la machine, sans
rien supposer.

---

## Où on en est — 2026-08-22 *(dépassé, voir plus haut)*

**S a démarré sur du vrai matériel, et personne n'a encore diagnostiqué ce qu'on
y a vu.** Le premier amorçage a eu lieu le **2026-08-21 au soir** : bureau Plasma
affiché, compte `RyuRex` créé, RetroArch qui fonctionne, Zoom qui s'ouvre. Le
jalon 3 est franchi.

**Correction du 2026-08-23 : ce paragraphe s'est trompé, voir « La machine
retrouvée » plus bas.** Il n'y a jamais eu de portable ASUS. C'est bien la
**M720q** qui a démarré S le 2026-08-21, confirmé par l'utilisateur et par le
matériel lui-même (`hostnamectl`, i5-8400T, UHD 630) relevé en direct depuis
une session dessus. L'erreur venait d'une déduction non vérifiée d'une session
précédente ; elle est corrigée, pas effacée, pour que la méthode reste lisible.

**Ce qui a été vu n'a pas été soigné.** Une quinzaine de photos ont été prises,
**non versionnées** — à redemander à l'utilisateur. Le relevé brut et leur
transcription vivent dans
[`banc/observations-2026-08-22-a-traiter.md`](banc/observations-2026-08-22-a-traiter.md).
En résumé, et rien n'est vérifié sur la machine :

- **`/usr/bin/vivaldi-stable` est introuvable**, ce qui casse d'un coup Vivaldi,
  RapidO et Gemini — les trois lanceurs pointent dessus. Le `tmpfiles.d` qui
  refait le pont `/var/opt/vivaldi → /usr/lib/opt/vivaldi` est le premier
  suspect, pas le coupable.
- **Presque toutes les autres pannes viennent du portail Bazzite** — `ujust`,
  Homebrew, `rpm-ostree` layering : asusctl, CoolerControl, Bazzite CLI,
  Boxtron, DaVinci Resolve. Ce n'est pas S qui échoue, c'est la couche amont —
  et la demande de l'utilisateur est justement de ne plus passer par elle.
- **Trois fenêtres de fin figent le bureau**, dont une a exigé un arrêt forcé.
- **`sudo` est inefficace** pour le compte principal.
- **Les démarrages sont longs** (~3 min). L'hypothèse — layerings en chaîne,
  services ASUS en échec, plateau USB — **n'est pas une mesure** : il manque un
  second démarrage consécutif sans rien installer entre, `systemd-analyze` à
  l'appui.

**Le jalon 2 est atteint et prouvé.** S s'installe, démarre jusqu'à l'invite de
connexion, se met à jour par `bootc upgrade`, et **porte huit logiciels installés
aux bons chemins**. Le jalon 5 s'est ouvert le soir même : un double-clic installe
désormais dans les trois mondes, et c'est éprouvé. CI vert, image publique.

### La Seagate — écrite le 2026-08-21

| | |
|---|---|
| Disque | Seagate Game Drive PS · **5 000 981 077 504 octets** · USB · HDD 512e · SMR probable |
| Écriture | **25,91 Gio en 42 min**, 11–12 Mo/s tenus, sans effondrement SMR |
| Structure | BIOS boot 1 Mio · ESP 512 Mio · racine **ext4 4,5 To** |
| Noyau posé | **7.2.0-ogc4.1.fc44** (l'image est reconstruite chaque jour) |
| Vérifié | `\EFI\BOOT\BOOTX64.EFI` · 8 gestes `s-*` · Proton 491 237 448 o · F-Droid · 13 associations · `binder` · origine `s-os:latest` |
| `plasma-setup-done` | **absent** — l'assistant de compte s'ouvrira |
| Caches | `sync` + `blockdev --flushbufs`, deux fois avec délai |

**Le débit a monté pendant l'écriture**, de 6,75 à 12,5 Mo/s : `mkfs` sur 4,5 To
coûte cher en métadonnées, les couches sont plus séquentielles. Ne pas lire le
premier chiffre comme une tendance.

### Le halt de QEMU, et ce qu'il apprend

Le premier lancement s'est **halté à 1,46 s de temps noyau**. Signature :
**0,00 s de CPU consommée sur 75 s**, les 8 threads en attente, zéro E/S sur le
disque hôte — lequel restait sain. Un arrêt franc, pas une lenteur.

La cause : j'avais introduit **trois changements d'un coup** sur un chemin
éprouvé, pour gagner en performance — `if=none` + `-device virtio-blk-pci`, les
tailles de bloc 512e, et `aio=threads`. Revenir à la syntaxe exacte qui avait
marché a tout réglé du premier coup.

**Et une passe contradictoire a réfuté ma propre explication** : `hdev_open()`
refuse tout autre mode qu'`aio=threads` sous Windows, et QEMU n'implémente pas
`.bdrv_probe_blocksizes` pour un `host_device` — l'alignement est figé à 512 côté
hôte. **Deux de mes trois « optimisations » étaient inertes.** Elles ne pouvaient
pas être la cause, et je les avais accusées avec assurance.

`banc/seagate.ps1` porte désormais un paramètre `-Variante`, dont **le défaut est
la syntaxe éprouvée**. Une seule variable à la fois.

### Deux dossiers neufs, et leurs règles d'entrée

- **`grimoire/`** — les mécanismes qui ont fonctionné, extraits et réutilisables.
  Règle : **rien n'entre sans une ligne `PREUVE:` datée**. Quinze pièces.
  Son propre outil, lancé sur le dépôt, a trouvé sept scripts ayant perdu leur
  bit d'exécution dans git — dont quatre dans `build_files/`.
- **`galerie/`** — l'identité visuelle, jalon 6. Règle : **rien n'entre sans une
  capture datée qui nomme la machine**. Une pièce, *Constellation*, en attente
  de sa première photo.

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

- **Aucune des pannes du premier démarrage réel n'a été diagnostiquée.** Elles
  ont été observées le 2026-08-21 au soir, transcrites le 2026-08-22, et
  **rien n'a été regardé sur la machine depuis**. C'est le premier travail qui
  attend, et la règle 7 s'y applique en entier : regarder avant de chercher une
  solution.
- **Waydroid a tourné le 2026-08-23** — cette ligne disait le contraire jusque
  là. Android a démarré sur la M720q, affiché son interface et lancé F-Droid.
  Restent deux défauts : **l'écran glitche**, et **l'installation depuis
  F-Droid gèle** sur l'autorisation « sources inconnues ». Le second est
  contourné (« Magasin Android » installe depuis l'hôte, sans jamais ouvrir
  l'installateur d'Android) ; **le premier n'est pas diagnostiqué**, et rien
  n'a été changé pour lui.
- **Lineage 2 n'a jamais été lancé**, ni aucun jeu.
- **L'iGPU n'a pas été jugé.** Les 266 réinitialisations relevées sous Windows
  n'ont pas d'équivalent mesuré sous Linux.
- **Le partage entre les mondes n'existe pas** — dossier personnel commun,
  presse-papiers commun, associations croisées. L'*installation* dans les trois
  mondes, elle, est cousue et éprouvée depuis le 2026-08-20 au soir : c'est la
  première moitié du jalon 5, et la seconde attend le jalon 3.
- **Les huit logiciels rendent leur version, et trois seulement ont vraiment
  servi.** `git`, `node`, `npm`, `claude`, `gemini`, `code` et `antigravity`
  répondent à un `--version` dans la machine installée (2026-08-21). Sur le vrai
  matériel, **RetroArch fonctionne**, **Zoom s'ouvre**, **Antigravity est
  déclaré bon** — et **Vivaldi ne se lance pas du tout**, son binaire étant
  introuvable. Le reste n'a toujours ouvert aucune fenêtre.
- ~~**`bootc rollback` n'a jamais été exercé.**~~ **Exercé le 2026-08-25 à
  19 h 49, sur la machine réelle et non dans le banc.** Ce paragraphe disait,
  et c'était juste : *« cela coûte un redémarrage à froid, et changerait une
  affirmation en mesure »*. Cela a coûté un redémarrage à froid, et c'est
  devenu une mesure. Voir la section de 19 h 55.
- **Aucune ISO installable n'a été produite.** La voie employée est
  `bootc install to-disk` depuis le registre.

### Où on va

| Jalon | État |
|---|---|
| 0 · La voie Waydroid | **fait** — `binder` compilé dans le noyau, prouvé à la construction |
| 1 · Le dépôt et la chaîne | **fait** — CI vert, image publiée, reconstruction quotidienne |
| 2 · L'image démarre | **fait et prouvé de l'intérieur** — 35 s, zéro service en échec |
| 3 · Le vrai matériel | **fait — le 2026-08-21 au soir**, sur la **M720q** en double amorçage (correction du 2026-08-23 : ce n'est pas un portable ASUS, voir « La machine retrouvée »). Bureau affiché, compte créé, RetroArch et Zoom en marche. GPU réel confirmé le 2026-08-23 : rendu Mesa `i915`, pas `llvmpipe` |
| 4 · Les trois mondes côte à côte | **franchi dans les faits le 2026-08-25** — 32 applications Android installées et lancées, dont la plupart viennent du **Play Store** et non de F-Droid : l'enregistrement de l'appareil auprès de Google a donc abouti. Linux, Windows et Android tournent et servent le même jour, dans la même session |
| 5 · Les coutures | **commencé** — l'installation des trois mondes est cousue et éprouvée ; le partage entre eux ne l'est pas |
| 6 · L'identité | **S a sa propre session depuis le 2026-08-22** — le greeter ne propose plus que « S » et « S — bureau de secours » ; ce que S lance n'est plus la coquille de l'amont mais la sienne, Constellation, servie par son pont `s-etoiles`. Plus l'os-release réécrit (la machine s'annonce « S », `ID` restant `bazzite` pour ne pas casser les recettes de l'amont), le logo, et **Foudre gelée**, fond d'écran 4K procédural. **Constellation a démarré pour de vrai le 2026-08-23 sur la M720q** — la session s'ouvre, le ciel s'affiche, trois défauts y ont été trouvés et corrigés. **Le greeter porte le logo de S depuis le 2026-08-23 au soir** : Plasma Login Manager n'ayant aucun système de thèmes, la plaque du S est gravée dans le fond d'écran de connexion, seul pixel de cet écran que S décide — jamais vue sur la machine. Reste l'écran d'amorçage, qui porte encore un nom qui n'est pas le nôtre, et **aucune capture n'a été prise** — donc rien n'entre encore dans `galerie/` |
| 7 · L'usage quotidien | pas commencé |

**Le verrou matériel est levé, et il en reste un de vitesse.** La Seagate est un
plateau USB, pas le SSD prévu : elle a suffi à démarrer, elle se paiera en
lenteur tant qu'elle sera le support. Ce qui attend maintenant n'est plus un
achat mais un **diagnostic** — Waydroid, les jeux, l'iGPU du portable ASUS, et
le droit de dire que S *fonctionne* plutôt que *démarre*.

**Secure Boot est réglé par les faits** : le disque a démarré, donc rien ne le
bloque sur cette machine. Le relevé de 2026-08-20 portait sur la M720q et ne dit
rien de l'ASUS ; il n'a plus besoin de le dire.

**Le jalon 5 s'est ouvert le 2026-08-20 au soir**, et il se divise en deux
moitiés que rien n'obligeait à mener ensemble. La première — *installer* dans
les trois mondes d'un seul double-clic — ne demande pas de matériel : elle est
faite et éprouvée. La seconde — *partager* entre les mondes, un dossier
personnel, un presse-papiers, des associations croisées — attendait le jalon 3,
puisqu'elle suppose que les trois mondes tournent en même temps. **Le jalon 3
étant franchi, elle n'est plus bloquée** — elle attend seulement que le monde
Windows et le monde Android aient tourné une fois sur cette machine.

### Les règles apprises, et qui tiennent tout

**0. Les quatre rôles se chargent à l'ouverture de la session, et pour toute sa
durée.** `wizard`, `alchimiste`, `contremaitre`, `peintre` — dans cet ordre, qui
est celui du travail : on **cherche** avant de forger, on **forge** avant de
contourner, on **contourne** ce que le système refuse, on **peint** ce qui
tient. Ils ne s'invoquent pas au coup par coup, quand le besoin devient
évident : à ce moment-là, la faute qu'ils évitent est déjà commise — le Wizard
existe précisément pour la passe où l'on n'a pas encore compris qu'on
réimplémentait l'amont.

Ils vivent dans **`.claude/skills/` du dépôt**, et c'est un déplacement du
2026-08-25 : ils étaient dans `~/.claude/skills/`, hors du dépôt, pendant que
trois `.md` périmés du 21 août traînaient à la racine sous les noms
`ALCHEMIST.md`, `Contremaitre.md` et `LePeintre.md`. **Les deux copies avaient
déjà divergé, et la juste était celle que git ne gardait pas** — l'ancien
`ALCHEMIST.md` demandait encore d'archiver dans `archives_alchimiques.md`, qui
n'a jamais existé. *Deux fichiers qui doivent rester d'accord finissent toujours
par diverger*, et ce carnet le répète depuis `s-partage`.

Une seule copie désormais, versionnée, et ~~**chargée d'office par Claude Code
sur toute machine qui clone le dépôt**~~ — ce qui est exactement ce qu'on attend
d'une règle numéro 0.

> **Faux, mesuré le 2026-08-25 à 21 h 44, et c'est la vérification que ce
> commit annonçait remettre à la prochaine session.** Claude Code ne charge les
> skills d'un dépôt que s'il **démarre dans ce dépôt**. Une session ouverte
> depuis `~` — c'est-à-dire la façon dont le lanceur du bureau ouvre S — n'en
> voyait aucun des quatre. Les rôles étaient versionnés et **injoignables**.
> Corrigé par un lien symbolique, `~/.claude/skills` → `S/.claude/skills` :
> une seule source, suivie par git, atteignable de partout. Voir la section du
> 2026-08-25, nuit.

*Et « utilise les skills » désigne ces quatre-là — jamais ceux livrés avec
Claude Code.*

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
## 2026-08-22, 21 h — S-Constellation : la maquette devient la session

**Constatation de l'utilisateur, et elle était juste : « le système de bureau
Constellation ne s'est pas implanté ».** Ce n'était pas un bureau. C'était une
page HTML ouverte dans une fenêtre par-dessus la coquille de la base, par un
lanceur pointant sur `/usr/bin/vivaldi-stable` — le binaire justement
introuvable sur la machine réelle. **Une maquette derrière un lien mort.**

Demande de fond, mot pour mot : *« je ne veux plus voir de Bazzite ou de Fedora
ou Plasma, je veux que S ait sa propre architecture qui est S - Constellation »*.

### Ce qui sépare habiller une base d'en poser une autre

Un bureau, c'est deux choses, et une seule se voit.

| | Qui la voit | Décision |
|---|---|---|
| Le **compositeur** — dessine les fenêtres, parle au GPU, gère Xwayland | personne, jamais | **gardé** : `kwin_wayland`, déjà dans la base, a déjà affiché un bureau sur cette machine |
| La **coquille** — barre, menu, icônes, fond, gestes | **tout ce que l'utilisateur voit** | **remplacée entièrement** par Constellation |

**Ce n'est pas un renoncement, et il faut le dire pour que personne ne le
relise comme tel.** Un compositeur ne met aucun nom à l'écran, aucun logo,
aucune couleur. En réécrire un donnerait moins bien, plus tard, pour un
résultat identique à l'œil. C'est la règle « on ne réimplémente pas ce que
l'amont maintient » appliquée là où elle vaut — et son exact opposé appliqué
à la coquille, où **rien de l'amont ne démarre plus** : ni `plasmashell`, ni sa
barre des tâches, ni son menu.

### Les quatre pièces écrites

| Fichier | Ce qu'il fait |
|---|---|
| `files/usr/share/wayland-sessions/s.desktop` | l'entrée « S » du greeter |
| `s-session` | choisit le compositeur, prépare le bus de session, lance la coquille |
| `s-coquille` | démarre le pont, puis Constellation en plein écran — **et porte le filet** |
| `s-etoiles` | le pont : sert la page, inventorie la machine, lance, compte, éteint |

### Le pont, et pourquoi il injecte au lieu d'appeler

Une page ne peut ni lancer un programme, ni lire un menu d'applications, ni
éteindre un ordinateur — le navigateur l'en empêche, et c'est heureux. Il
fallait un interlocuteur local : `s-etoiles`, un serveur HTTP sur `127.0.0.1`.

**Il réécrit la page avant de l'envoyer** plutôt que de la faire appeler une API.
Conséquence : la page reste *strictement la même* qu'ouverte seule. Aucune
restructuration asynchrone, aucun état de chargement — et **le prototype de
`galerie/` continue de vivre tel quel** avec ses données de vitrine. Le pont ne
remplace qu'un commentaire-repère, `/*__S_ETOILES__*/`.

### Ce qui ne se voit plus, et ce qui se voit encore

- **Les sessions de l'amont sont masquées** (`NoDisplay=true`), pas effacées.
  Le greeter propose « S » et « S — bureau de secours ». Un bureau arraché ne
  se remet pas d'un clic ; une session masquée, si.
- **Les applications dont le nom porte Bazzite, Fedora, Plasma, Waydroid,
  Distrobox, Proton ou Wine ne montent pas au ciel.** Pas pour les cacher — le
  carnet les nomme, le dépôt est public — mais parce qu'on ouvre *un* système,
  pas un empilement. C'est la règle 9 étendue au menu entier.
- **Restent à peindre, et c'est écrit dans le journal de construction** : le
  thème du greeter et l'écran d'amorçage graphique. Le second exige de refaire
  l'initramfs. Ils portent encore un nom qui n'est pas le nôtre.

### Trois défauts que seul le banc pouvait montrer

Le pont a été **exécuté**, sur la machine de développement, avec un faux menu
d'applications de douze entrées et la vraie page.

1. **Le monde Windows disparaissait en entier.** Le filtre qui écarte les
   gestionnaires de fichiers portait sur la *commande* : tout `.desktop` dont
   l'`Exec` appelle `s-ouvrir-exe`. Or **les raccourcis moissonnés par
   `s-menu-windows` appellent tous `s-ouvrir-exe`, c'est leur raison d'être.**
   « Lineage II » avait disparu du ciel sans un mot — le succès silencieux, une
   fois de plus. Le filtre porte désormais sur l'identifiant.
2. **Le bureau demandait ses polices à Google à chaque ouverture de session.**
   La page tire IBM Plex de `fonts.googleapis.com` : sans conséquence pour une
   maquette, inacceptable pour une coquille — une requête vers Google à chaque
   connexion, et un écran sans polices hors ligne. Les familles entrent dans
   l'image ; le pont retire les liens distants en servant. Le fichier de
   `galerie/` reste intact pour sa vie de maquette.
3. **Alt+F4 aurait déconnecté l'utilisateur.** La coquille est une fenêtre : la
   fermer rend un code 0, que la boucle lisait comme « sortie propre ». On
   perdait sa session pour avoir manqué un raccourci. Le pont pose désormais un
   témoin quand la sortie est *voulue* ; sans témoin, la coquille se rouvre.

### Ce qui est éprouvé, et ce qui ne l'est pas

**Éprouvé au banc, le 2026-08-22 — machine de développement, portable ASUS sous
Windows, pont exécuté par Python, page rendue dans un vrai navigateur :**

| | |
|---|---|
| Inventaire | 7 étoiles tirées de 12 `.desktop` — Bazzite, Fedora, `NoDisplay` et `TryExec` mort écartés |
| Les trois mondes | `linux`, `windows` (via `s-ouvrir-exe`), `android` (via `waydroid`) classés juste |
| La page | 7 astres créés, 7 raccourcis en barre, horloge vivante, **aucune erreur de console** |
| Lancement réussi | `{"ok": true}`, compteur écrit dans `usage.json` |
| Lancement impossible | `{"ok": false, "dit": "…introuvable"}` — l'échec se dit |
| **La boucle complète** | après un lancement, l'étoile passe de 30 à **60 px**, son anneau devient plein, elle s'épingle à la barre — **et survit au rechargement** |
| Garde-fou | `Host` étranger → **403**, `Origin` étranger → **403**, page normale → 200 |
| Témoin de sortie | posé par « Éteindre », **pas** par « Verrouiller » |

**Jamais exercé, et c'est l'essentiel de ce qui reste :**

- **La session elle-même n'a jamais démarré.** `kwin_wayland /usr/bin/s-coquille`
  n'a jamais été lancé nulle part. C'est le point de rupture unique de tout ce
  travail : si cette invocation est fausse, la session meurt et le greeter
  revient — d'où l'entrée de secours, qui rend cette panne réparable sans SSH.
- **Le filet n'a jamais servi.** Trois chutes en moins d'une minute posent un
  bureau de secours ; personne n'a vérifié qu'il se pose.
- **Aucune capture sur S.** La règle de `galerie/` tient : Constellation ne
  montera dans son tableau que photographiée sur la machine qui la fait tourner.
- **Le greeter peut se souvenir de l'ancienne session.** Une session masquée ne
  se choisit plus, mais rien ne dit ici comment SDDM traite un souvenir devenu
  invisible. **À la première connexion, choisir « S » dans le menu des sessions.**

---

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
6. **Windows déménage sur la Seagate — décision du 2026-08-23, qui renverse
   cette limite.** Elle disait « Windows reste sur le disque interne,
   définitivement », et son raisonnement tient toujours : PC Boost est du WPF
   .NET, qui ne se construit que sous Windows, donc Windows doit rester
   *disponible*. Mais l'utilisateur a tranché autrement — **S natif sur le NVMe
   rapide, Windows cloné et amorçable sur la Seagate**. Le double amorçage reste
   l'état final ; ce qui change est de quel disque chaque monde démarre. La
   licence OEM est liée à la carte mère, donc au même boîtier : le clone reste
   activé. Ce qui se paie : Windows sera lent, sur un plateau USB — le prix
   exact que S payait, échangé de place. Voir
   [`banc/le-demenagement.md`](banc/le-demenagement.md).
7. **L'UHD 630 borne le périmètre « jeux »** au rétro, à l'indé et à l'émulation.
   Lineage 2, moteur de 2003, y est à l'aise. Rien de moderne. Ça n'a rien à voir
   avec Linux — c'est vrai sous Windows aussi.

---

## La machine — relevé du 2026-08-19, et retrouvée le 2026-08-23

> **L'avertissement du 2026-08-22 ci-dessous était une erreur, corrigée le
> 2026-08-23.** Il affirmait que la machine qui fait tourner S était un
> portable ASUS et non la M720q. C'est faux : l'utilisateur confirme n'avoir
> jamais changé de machine, et une session ouverte en direct dessus le
> 2026-08-23 le confirme matériellement — `hostnamectl` rend
> `Hardware Model: ThinkCentre M720q`, `/proc/cpuinfo` rend
> `i5-8400T @ 1.70GHz`, et `lspci` rend `UHD Graphics 630` avec le pilote
> `i915` actif. **Ce relevé du 2026-08-19 s'applique donc bel et bien** à la
> machine qui fait tourner S. Ce que l'avertissement erroné disait — texte
> original conservé pour la méthode, pas pour le fait :
>
> *« Tout ce relevé décrit une M720q, et S n'a jamais démarré dessus. La
> machine qui a démarré S le 2026-08-21 au soir est un portable ASUS — celui-là
> même qui sert au développement, en double amorçage. Son matériel n'a jamais
> été relevé : ni processeur, ni mémoire, ni iGPU, ni firmware. »*
>
> Voir « Le GPU réel, confirmé le 2026-08-23 » plus bas pour ce que la session
> en direct a appris de neuf — notamment que le rendu est **matériel**
> (`i915`/Mesa), pas `llvmpipe`, une première pour le projet.

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

## 2026-08-21, 01 h 40 — S démarre depuis une clé, et le blocage est expliqué

**Le jalon 3 est franchi sur banc.** Une clé virtuelle a reçu S, et **S a démarré dessus**,
seul, en UEFI, sans aucun autre disque attaché. Capture à l'appui : `cle-boot-1.png`.

### Le banc qui a permis tout ça

Écrire sur la vraie clé exige l'élévation — accès brut à un disque physique — donc
immobilise l'utilisateur et interdit le travail de nuit. La parade est celle du banc VHD de
PC Boost : **un `qcow2` de 61 524 148 224 octets, l'octet près**. Le garde-fou de taille de
`poser-sur-cle.sh` le laisse passer sans aucune modification, si bien que **c'est exactement
le même chemin de code** qui est exercé — sonde d'écriture et contrôle de place compris.

Ce qu'il ne prouve pas : le débit réel de la mémoire flash et le comportement du contrôleur
USB. Il prouve tout le reste.

### Le blocage de la veille, expliqué et corrigé

**Le zram**, comme supposé — mais le correctif d'abord écrit était faux, et seul le banc
l'a montré.

- **L'unité à arrêter est `dev-zram0.swap`, pas `systemd-zram-setup@zram0.service`.**
  `swapoff -a` désactive le swap une seconde, puis **systemd le réactive** : l'unité `.swap`
  reste active et il la remet en service.
- **Un contrôle pris trop tôt ment.** Le script affichait fièrement « swap 0 Mio » juste
  après le `swapoff`, et `swapon --show` rendait de nouveau `/dev/zram0` trois minutes plus
  tard. La vérification se fait désormais **après un délai**, et le script prévient si un
  swap subsiste au lieu de continuer en silence.

### Le chiffre qui change les prévisions

**L'installation écrit 20,2 Gio, pas 7,5.** Le « layers needed: 137 (7.5 GB) » de `bootc`
est le volume des couches à **transférer** ; l'arborescence déployée pèse près du triple.

Conséquence rétrospective : la tentative bloquée s'était arrêtée à **6,99 Gio, soit un tiers
du chemin** — et non « presque au bout », comme je l'avais cru et dit. J'ai lu 6,99 contre
7,5 comme une quasi-réussite ; c'était une lecture fausse, faute d'avoir compris ce que
mesurait le 7,5.

### Ce qui a été mesuré

| | |
|---|---|
| Durée de l'écriture | **21 minutes** (01:15 → 01:36), disque virtuel |
| Volume écrit | 20 717 Mio |
| Occupation réelle du `qcow2` | 16,7 Gio |
| Système de fichiers | **ext4**, `mkfs.ext4 -O verity` |
| Structure | BIOS boot 1 Mio · ESP FAT32 512 Mio · racine ext4 56,8 Gio |
| Débit moyen | ~16 Mio/s sur disque virtuel |

### Ce que la capture de démarrage prouve

Sept choses, et chacune était une inconnue :

1. **Le firmware trouve la clé et lui passe la main** — l'ESP et le chargeur sont corrects.
2. **`EXT4-fs (vda3): re-mounted`** — la racine ext4 monte ; le changement de système de
   fichiers depuis btrfs ne casse rien.
3. **`Reached target boot-complete.target`** puis **`greenboot-success.target`** — le
   contrôle de santé au démarrage de Bazzite passe. **Le système se déclare sain lui-même.**
4. Réseau en ligne, NetworkManager démarré.
5. `ostree-finalize-staged.service` terminé — le déploiement est propre.
6. **`bazzite-hardware-setup.service/start running (57s / 15min 25s)`** — le service dont la
   fiche annonce le redémarrage automatique. Les « 15min 25s » confirment au passage que
   l'`override` `TimeoutStartSec=900` posé par `10-base.sh` est bien en vigueur.
7. `--generic-image` n'a rien cassé : les deux chargeurs sont installés et aucune variable
   de firmware n'a été touchée.

### Ce qui reste inconnu

Le matériel réel. Un firmware virtuel qui trouve la clé ne dit rien du contrôleur USB de la
M720q, ni de son iGPU, ni du débit d'une vraie mémoire flash — qui sera **plus lent** que
les 16 Mio/s du disque virtuel.

### Le second démarrage arrive à l'assistant de création de compte

**La chaîne est éprouvée de bout en bout**, et les deux captures sont versionnées :

| Capture | Ce qu'elle prouve |
|---|---|
| `cle-demarrage-console.png` | le premier démarrage, jusqu'à `greenboot-success` |
| `cle-ecran-accueil.png` | le second : **« Welcome to Plasma Desktop », bouton *Begin Setup*** |

C'est précisément l'écran que verra l'utilisateur. L'assistant `plasma-setup` s'ouvre et
demande la création du compte — comportement voulu, puisque aucun mot de passe n'entre dans
une image publique.

**Le rendu est graphique alors que le banc n'a aucune accélération 3D.** Plasma tombe sur
`llvmpipe`, le rendu logiciel de Mesa, et l'assistant s'affiche quand même. Cela ne dit
rien de la fluidité sur matériel réel, mais cela écarte définitivement la crainte d'un
« écran noir » — laquelle avait déjà été une fausse alerte le 2026-08-20.

### Le redémarrage automatique, vu et chronométré

`bazzite-hardware-setup` a déclenché son redémarrage à **142,3 s d'uptime**, soit 2 min 22 s
— cohérent avec les 2 min 38 s mesurés en machine virtuelle la veille. La fiche donne donc
une fourchette plutôt qu'un chiffre.

**Et le redémarrage à chaud n'est jamais reparti**, l'écran restant figé treize minutes sur
`systemd-shutdown`. Ce n'est pas un défaut de S : c'est la limite du banc déjà consignée
plus haut — *le redémarrage à chaud de QEMU ne repart jamais, le démarrage à froid marche
toujours*. Un arrêt forcé suivi d'un démarrage à froid a rendu l'écran d'accueil en 100 s.
Sur matériel réel, F12 rejoue exactement ce démarrage à froid.

### Une réserve levée, et une corrigée

- **Aucune entrée ne sera ajoutée au BIOS.** `--generic-image` déclare *« Changes to the
  system firmware will be skipped »*, et la clé a bien démarré par le chemin de repli
  `\EFI\BOOT\BOOTX64.EFI`. La réserve annoncée à l'utilisateur est donc **fausse** et a été
  retirée de la fiche.
- **`plymouthd` empêche le démontage propre de la racine** au redémarrage — « Failed to
  unmount /sysroot: Device or resource busy », puis « Unable to finalize remaining file
  systems, ignoring ». C'est bruyant et sans conséquence ici, le système redémarrant juste
  après. À surveiller si un arrêt propre devenait nécessaire.

### Les outils tournent — première exécution réelle des huit logiciels

Le carnet disait depuis le 2026-08-20 qu'**aucun des huit logiciels n'avait jamais été
lancé**, seul Vivaldi ayant reçu un `--version`. **Ce n'est plus vrai.** Exécutés cette nuit
**sous le compte utilisateur**, pas en root :

| Outil | Version rendue |
|---|---|
| `git` | 2.55.0 |
| `node` | v24.18.0 |
| `npm` | 11.16.0 |
| `claude` | **2.1.228 (Claude Code)** |
| `gemini` | 0.56.0 |
| `code` | 1.134.0 |
| `antigravity` | 1.107.0 |

Cela reste un `--version` : aucun n'a ouvert de fenêtre ni fait de travail utile. Mais le
binaire se lance, trouve ses bibliothèques et rend une réponse cohérente — ce que ni la
présence d'un fichier ni la construction ne prouvaient.

**`/etc/skel` tient sa promesse.** Le compte porte bien `anthropic.claude-code` et
`ms-ceintl.vscode-language-pack-fr` dans VS Code, et `argv.json` impose `locale: fr`. C'est
la seule mécanique du projet qui soit à la fois dans l'image et propre à chaque compte, et
elle est désormais vérifiée de bout en bout.

### Une fausse alerte, et ce qu'elle apprend

Le contrôle a d'abord semblé catastrophique : `/usr/bin/s-*` **vide** dans la machine
virtuelle, et le `.deb` toujours associé à l'archiveur. Les coutures auraient disparu.

Elles n'ont jamais été là : **cette VM tourne sur un déploiement antérieur**. L'`ostree admin
undeploy` de la veille, fait pour libérer de la place, a retiré le déploiement récent.

L'image publiée, elle, les porte toutes — vérifié en lançant un conteneur depuis
`ghcr.io/gigigrenier86/s-os:latest`, c'est-à-dire **exactement ce que la clé a reçu** : huit
scripts, sept lanceurs dont « Android » et « Magasin Android », treize associations, F-Droid
(12,4 Mio) et Proton pré-cuit dans `/usr/lib/s/windows`.

**La leçon vaut au-delà du cas** : sur un système atomique, l'état d'une machine ne dit pas
l'état de l'image. Interroger l'image directement — `podman run` sur le tag publié — est le
seul contrôle qui réponde à la question posée.

## 2026-08-23 — la machine retrouvée, et le GPU réel

**Ce carnet s'était trompé le 2026-08-22 en écartant la M720q.** Une session ouverte en
direct sur la machine qui fait tourner S — pas une supposition — rend :

```
hostnamectl : Hardware Vendor: Lenovo · Hardware Model: ThinkCentre M720q
              Static hostname: LenovoGhis · OS Image: bazzite-44.20260820
/proc/cpuinfo : Intel(R) Core(TM) i5-8400T CPU @ 1.70GHz
lspci         : 00:02.0 VGA … Intel UHD Graphics 630 [8086:3e92], pilote i915 actif
```

**C'est exactement le relevé du 2026-08-19**, à la lettre. L'utilisateur confirme n'avoir
jamais changé de machine ; l'avertissement du 2026-08-22 était une déduction non vérifiée
d'une session précédente, jamais recoupée avec le matériel — exactement ce que la règle 7
demande de ne plus faire, et que cette entrée corrige sans effacer l'erreur.

### Le GPU réel, confirmé pour la première fois

Chaque test jusqu'ici — VM QEMU, banc de clé virtuelle — tombait sur `llvmpipe`, le rendu
logiciel de Mesa, faute de GPU. Sur cette session réelle :

```
OpenGL renderer string: Mesa Intel(R) UHD Graphics 630 (CFL GT2)
OpenGL version string: 4.6 (Compatibility Profile) Mesa 26.2.1
```

**Rendu matériel, pilote `i915`, pas de repli logiciel.** C'est la première fois que le
projet voit son iGPU réel accepter d'afficher quoi que ce soit — la question ouverte
depuis le jalon 3 (« l'iGPU n'a pas été jugé ») a une première réponse partielle : il
fonctionne, au moins pour le rendu 2D d'un bureau Plasma.

**Les 266 réinitialisations mesurées sous Windows restent sans réponse.** `dmesg` est
restreint aux non-root (`kernel.dmesg_restrict=1`) et le journal noyau accessible sans
`sudo` ne remonte que 10 lignes `i915` sur 34 minutes d'uptime — bien trop court pour dire
quoi que ce soit sur un défaut mesuré à l'échelle du mois. Aucun reset ni hang dans cette
fenêtre, mais l'absence de preuve n'est pas une preuve d'absence ici : à réévaluer après
plusieurs jours d'usage réel, et avec `sudo` fonctionnel pour lire le journal complet.

### Ce que cette session a trouvé, en clair

| | |
|---|---|
| Disque racine de S | `sda`, 4,5 To, ext4 — la Seagate, comme prévu |
| Windows | `nvme0n1`, 238,5 Go, partitions NTFS — le NVMe interne de la M720q, intact |
| Session en cours | **KDE Plasma standard** (`plasmashell`, `kwin_wayland`) — **pas Constellation** |
| `sudo -n` | échoue encore — le correctif du 2026-08-23 (`s-corriger-machine`) n'est pas encore déployé sur cette machine au moment du relevé |
| Uptime | 34 min — démarrage récent, le même que celui annoncé par l'utilisateur en ouverture de cette conversation |

**Donc non, Constellation n'a toujours jamais tourné sur cette machine** — le greeter a
choisi la session KDE de l'amont, pas « S ». Rien d'étonnant : les correctifs qui forcent
la session par défaut vers S sont ceux que cette même conversation vient de pousser vers
`ghcr.io`, encore en construction au moment de ce relevé. C'est un `bootc upgrade` et un
redémarrage de plus qui trancheront, pas une supposition de plus.

> **Et ils ont tranché, une heure et demie plus tard.** Ce paragraphe était vrai
> à 01 h 43 et a cessé de l'être vers 03 h : le `bootc upgrade` a eu lieu, et
> Constellation a démarré. Voir « Constellation a tourné » en fin de carnet. Le
> texte reste tel quel — c'est un relevé horodaté, pas une conclusion.

### La CI a échoué une première fois, et le défaut était réel

Le premier push (sudo, session par défaut, menu) a fait échouer la construction :
`37-effacer-bazzite.sh` accusait à tort d'avoir masqué « Antigravity - URL Handler ». La
cause : le garde-fou rescannait **tout** `/usr/share/applications`, pas seulement les
fichiers que sa propre boucle venait de masquer — et Antigravity pose ce raccourci caché
par conception (`NoDisplay=true` posé par l'éditeur, pour son gestionnaire d'URL). Corrigé
en faisant tenir au script la liste des fichiers qu'il modifie lui-même, et en ne
garde-fouant plus qu'eux. Seconde CI verte en 8 min 52 s.

### Le disque Windows, partagé depuis S — écrit, jamais démarré

En creusant la machine réelle (voir plus haut), le disque Windows s'est laissé monter
sans mot de passe, via `udisksctl` — et sans `hiberfil.sys`, donc sans le risque de
corruption qu'un Windows en démarrage rapide aurait posé. Ça a suffi à poser un geste
permanent plutôt qu'un essai ponctuel.

**Quatre pièces, sur le même principe que `s-corriger-machine`** : ce que S ne peut pas
savoir à la construction — l'UUID de la partition Windows, propre à chaque machine et à
chaque réinstallation de Windows — se découvre au démarrage, jamais avant.

| Fichier | Rôle |
|---|---|
| `s-monter-windows` (+ `s-monter-windows.service`) | Trouve la plus grosse partition NTFS interne (jamais une petite partition WinRE), et arme un montage automatique vers `/var/mnt/windows` par `systemd-mount --automount=yes` — sans unité statique à graver dans l'image |
| `s-fichiers-windows` (+ son `.desktop`) | Ouvre `~/Windows` dans le gestionnaire de fichiers ; le premier accès déclenche le montage réel, systemd s'en charge |
| `/etc/skel/Windows` | Le lien pour tout compte créé désormais ; les comptes déjà créés le reçoivent du service au démarrage, même limite que partout ailleurs dans `/etc/skel` |

**Ce qui est vérifié, et ce qui ne l'est pas.** La détection par taille a été testée en
direct sur la M720q : elle choisit bien `nvme0n1p3` (237 Go) et jamais `nvme0n1p4`
(853 Mo, la récupération). Le montage lui-même, via `udisksctl`, a fonctionné en
lecture-écriture sans accroc. **La commande `systemd-mount` du script, elle, n'a jamais
tourné** — la permission d'invoquer `sudo` depuis cette session a été refusée par la
classification automatique de l'outil, par prudence sur une action qui touche l'état
système. Le service n'a donc jamais été exercé de bout en bout ; ce sera le même
`bootc upgrade` et redémarrage qui le dira, en même temps que Constellation.

## 2026-08-23, 03 h — Constellation a tourné, et trois défauts sont tombés

**C'est la première fois que la coquille de S s'affiche sur une machine.** Le
`bootc upgrade` et le redémarrage annoncés deux sections plus haut ont eu lieu :
le greeter a proposé « S », la session s'est ouverte, le ciel s'est peint. Le
point de rupture unique redouté depuis le 2026-08-22 — `kwin_wayland` lançant
`s-coquille` — **tient**.

Trois défauts sont apparus aussitôt, et aucun ne se voyait autrement qu'en
regardant l'écran.

### 1. L'étoile Vivaldi manquait, sans un mot

Le `.desktop` du paquet vise `/usr/bin/vivaldi-stable`, qui vise `/opt/vivaldi`,
qui vise `/var/opt/vivaldi`. **Ce dernier pont ne s'était jamais refait** :
`/var/opt/vivaldi` existait déjà comme un vrai dossier — les codecs
propriétaires que Vivaldi y télécharge — et le `L` de `tmpfiles.d` refuse de
poser un lien par-dessus un dossier existant.

**Ce qui rend la panne muette :** `gio` résout `Exec` **au chargement** du
`.desktop`, pas à l'exécution. Le fichier était donc rejeté avant même d'être
proposé — Vivaldi disparaissait du ciel *et* du menu de l'amont, sans erreur.
C'est le succès silencieux de la règle 2, transposé au bureau.

Correctif : viser le chemin de **l'image**, jamais le pont qui peut se rompre —
`Exec=/usr/lib/opt/vivaldi/vivaldi`, comme `s-coquille` le fait déjà pour son
propre moteur. Un `TryExec` l'accompagne, et **la première tentative en `sed`
aveugle était fausse** : elle en posait un dans chaque groupe, or `TryExec` n'a
le droit de vivre que dans `[Desktop Entry]` et `desktop-file-validate` rejette
le reste.

### 2. Le ciel recevait quatre-vingt-une applications d'un coup

L'inventaire réel de la machine compte **81 entrées**, EmuDeck et consorts
compris. Le pont les déversait toutes. **Un inventaire déversé n'est pas un
ciel, c'est un fouillis** — et cela ne pouvait se découvrir que sur une vraie
machine : le banc du 2026-08-22 tournait sur un faux menu de douze entrées.

`s-etoiles` gagne donc un état persistant, `placees.json`, et deux routes —
`/api/placer` et `/api/retirer`. **Le ciel ne montre plus que ce que
l'utilisateur y met, à la position qu'il lui donne** ; l'inventaire complet
reste accessible par le menu. Les coordonnées sont bornées à `[0,1]` côté pont,
et l'identifiant vérifié contre l'inventaire — une route qui écrit un fichier
n'accepte pas ce qu'on lui donne sur parole.

### 3. `mandb` mangeait la moitié du démarrage — mesuré, enfin

Le carnet supposait depuis le 2026-08-22 que les ~3 minutes de démarrage
venaient « des layerings en chaîne, des services en échec et du plateau USB », en
écrivant que ce n'était pas une mesure. **C'en est une, maintenant.**
`systemd-analyze critical-chain` nomme un seul coupable :

```
fedora-atomic-desktop-mandb-update.service : 2 min 51 s
demarrage total jusqu'a l'invite          : 4 min 49 s
```

La cause n'est pas la lenteur du service mais **sa place** : `systemd` ajoute
tout seul un `Before=multi-user.target` à toute unité portant
`WantedBy=multi-user.target`, sauf si `DefaultDependencies=no`. L'index des pages
de manuel retenait donc le bureau entier, pour rien — il n'est nécessaire ni
pour ouvrir une session ni pour lancer un logiciel.

`DefaultDependencies=no` le décroche du chemin critique **sans l'empêcher de
tourner** ; le `TimeoutStartSec` reste en filet. La limite de temps posée le
2026-08-22 était donc un filet, pas un moteur — c'était écrit, et c'est
maintenant vérifié.

### Ce que cette session ne prouve toujours pas

- **Aucune capture n'a été prise.** La règle de `galerie/` tient : Constellation
  n'entrera dans son tableau que photographiée sur la machine qui la fait
  tourner. C'est le seul geste qui manque pour clore la pièce.
- **Le filet de `s-coquille` n'a jamais servi** — trois chutes en moins d'une
  minute doivent poser un bureau de secours ; personne ne l'a vu se poser.
- **Les trois correctifs ci-dessus ne sont pas sur la machine.** Ils sont
  construits et publiés (CI verte, `ghcr.io` à jour) ; il manque un
  `bootc upgrade` et un redémarrage — le même qui exercera enfin
  `s-monter-windows` et `s-corriger-machine` de bout en bout.
- **Waydroid n'a toujours jamais tourné**, et reste le différenciateur du projet.

## 2026-08-23, soir — huit observations de l'utilisateur, et ce qu'elles ont trouvé

Huit remarques rapportées de l'usage réel. Elles ont fait tomber **trois
hypothèses de fond de ce carnet**, dont une qui rendait tout un pan du jalon 6
inatteignable sans que personne s'en aperçoive.

### Le greeter n'est pas SDDM — et le journal de construction le disait depuis le premier jour

*« À l'écran de mot de passe, c'est encore la maudite photo Bazzite. »*

Fedora 44 a basculé ses variantes KDE de SDDM vers **Plasma Login Manager**.
Bazzite ne réinstalle SDDM que sur ses images « deck ». Tout ce que ce carnet
appelait « le thème du greeter, reste à peindre » visait donc un logiciel
**absent de l'image**.

Et la preuve était imprimée à chaque construction depuis le 2026-08-22, par
`36-constellation.sh` lui-même :

```
greeter : aucun theme sddm
```

Ce message était juste, et personne ne l'a lu. `/usr/share/sddm/themes` n'existe
pas ici. **Un `echo` bien placé avait la réponse ; il a fallu quatre jours pour
la regarder** — la convention du dépôt qui veut qu'un script écrive ce qu'il
découvre a fonctionné, c'est sa relecture qui a manqué.

La photo elle-même vient de `/usr/lib/plasmalogin/defaults.conf`, livré par
Bazzite, qui pointe sur son fond maison. **C'est le seul vecteur de sa marque à
cet écran** : le QML du greeter n'affiche ni nom de distribution ni logo.

`42-greeter.sh` réécrit ce fichier et double dans `/etc/plasmalogin.conf`, qui
gagne dans tous les cas — le support de `plasmalogin.conf.d` est récent et a été
rapporté comme ignoré sur des versions publiées, on ne parie pas dessus.

**Et la même clé règle la deuxième plainte** — *« je dois choisir mon bureau, je
ne veux pas avoir à faire ça »* :

```ini
[Greeter]
PreselectedSession=s.desktop
```

Elle l'emporte sur la session mémorisée. Au passage : **Plasma Login Manager
n'honore pas `NoDisplay`** dans la liste des sessions, contrairement à SDDM — le
masquage posé par `36-constellation.sh` est inopérant *ici*. On ne supprime pas
les sessions de l'amont pour autant ; la préselection rend la question sans
objet, puisqu'on ne choisit plus.

**Troisième découverte du même fil :** `/etc/xdg/kcm-about-distrorc`, livré par
Bazzite, réécrit en dur le nom, le logo et le site du panneau « À propos ».
**Tout le travail de `35-identite.sh` sur `os-release` était annulé à l'endroit
même où l'utilisateur va vérifier le nom de son système.**

**Ce qui reste à la base :** l'écran d'amorçage. `43-amorcage.sh` est écrit et
**n'est pas branché** — il régénère l'initramfs, seul changement de ce dépôt qui
puisse empêcher la machine de démarrer, et ~~`bootc rollback` n'a toujours
jamais été exercé~~ — **exercé depuis, le 2026-08-25 à 19 h 49, et il
fonctionne : le filet existe pour de bon.** Son en-tête dit ce qu'il faut faire
avant de le brancher.

### Les trois démons du démarrage — trois causes différentes

*« asusd est toujours refusé, je n'ai pas un appareil ASUS. »*

`asusd` **ne vient pas de S**, et le carnet l'avait établi le 2026-08-22 : le
portail l'a superposé à moitié. Le masquer dans l'image serait le succès
silencieux. Ce qui l'enlève est `rpm-ostree reset`, **sur la machine** — devenu
un geste à double-clic, **`s-nettoyer`**, qui montre ce qu'il va retirer avant
de le retirer.

Ce que l'image gagne quand même, c'est une **condition matérielle posée
d'avance** sur les trois unités ASUS :

```ini
ConditionFirmware=smbios-field(sys_vendor $= "ASUS*")
```

C'est la même règle que celle qu'`asusctl` applique en udev, portée là où elle
manque — car `asus-shutdown.service`, lui, porte `WantedBy=multi-user.target` et
`Requires=asusd.service` : il tire `asusd` là où udev ne l'aurait jamais fait.
Avec `StartLimitBurst=5`, cela donne exactement les six lignes en échec de la
photo du 2026-08-21. Un drop-in visant une unité absente est ignoré : il est
donc déjà là si quelqu'un relance `ujust asus`.

**Piège vérifié au passage, et le carnet croyait l'inverse :** dans systemd,
plusieurs conditions sont combinées en **ET**, jamais en OU. Le OU se demande
explicitement, par une barre verticale après le signe égal.

*« cardwire Daemon échoue toujours. »*

**Trouvé.** C'est `cardwired.service`, dont la `Description=` est littéralement
`Cardwire Daemon` — la transcription du 2026-08-21 était exacte au caractère
près. L'entrée « `cardwired` — introuvable, et je refuse de deviner » était
correcte pour sa méthode et fausse dans sa conclusion : le nom est absent du
dépôt Bazzite parce que **c'est un paquet externe**, entré le 2026-08-20 en
remplacement de `switcheroo-control` et `supergfxctl`.

C'est un gestionnaire de GPU qui masque une carte aux applications par des
crochets eBPF, activé par preset **sans aucune condition matérielle**, et qui
refuse de démarrer si `/sys/kernel/security/lsm` ne contient pas `bpf`.
Contrairement à `asusd`, **il vient de l'image** — donc de celle de S. Sur une
machine à GPU intégré unique, il n'a rien à masquer : `39-materiel.sh` le
désactive.

*« zram0 indique à chaque fois qu'elle n'est pas là et la place, perte de
temps. »*

**Celui-là n'est pas une panne, et il ne sera pas « réparé ».** Le message vient
du noyau. Un périphérique zram est un disque compressé **en mémoire vive** : il
n'existe plus quand la machine s'éteint, il est recréé à chaque démarrage par
construction, et **aucune image ne peut le pré-cuire** — ce serait pré-cuire de
la RAM. Le coût est de l'ordre de la milliseconde.

Ce qui est fait à la place : le réglage devient **celui de S**, décidé dans
l'image plutôt qu'hérité. Détail peu connu et utile — un fragment de
`zram-generator.conf.d/` l'emporte sur le fichier principal **quel que soit son
dossier**. S bat donc le réglage de Bazzite depuis `/usr`, sans toucher `/etc`.
Et sur un disque USB à plateaux, le swap compressé n'est pas un luxe : c'est ce
qui évite l'effondrement.

### Le VLC installé qui n'apparaissait nulle part — cinq défauts, pas un

*« J'ai installé VLC en .exe, installation réussie, mais il n'apparaissait pas
dans mes apps du menu démarrer, aucune étoile bleue. »*

Cinq causes indépendantes, trouvées en relisant le chemin entier. **Chacune
suffisait à elle seule.**

1. **Constellation ne relisait jamais son inventaire.** Il était figé au moment
   où le pont avait servi la page ; la seule minuterie était l'horloge. Il
   fallait fermer la session pour voir une application nouvelle. *C'est un
   bureau qui ne remarque pas ce qu'on installe dessus.* La page relit
   maintenant `/api/etoiles` toutes les quinze secondes — et **ne redessine que
   si quelque chose a changé**, en ne touchant qu'aux étoiles concernées :
   re-semer le ciel détruirait les amas fusionnés à chaque tour.
2. **L'API et la page n'avaient pas la même forme.** `/api/etoiles` rendait
   l'inventaire brut, sans `epingle` ni `ep`, là où l'injection les ajoutait.
   Tant que la page ne relisait jamais l'API, la différence ne se voyait pas ;
   dès qu'elle la relit, elle perdrait sa barre des tâches à chaque tour. Une
   seule source désormais, `composer_etoiles()`.
3. **Tout reposait sur `winemenubuilder`, que Proton désactive couramment.**
   Quand il ne tourne pas, `applications/wine/` reste vide et il n'y a rien à
   moissonner. D'où une **seconde source qui ne dépend de personne** : les
   `.lnk` du menu Démarrer, lus directement dans le préfixe.
4. **La photo du menu était prise trop tôt.** `umu-run` rend la main dès que le
   processus principal sort, alors que l'installateur écrit ses raccourcis dans
   ses dernières secondes. Et comme la comparaison conditionnait la moisson, il
   n'y avait **aucun rattrapage**. On attend maintenant `wineserver -w`, et on
   moissonne dans tous les cas.
5. **`printf %q` produisait un `.desktop` invalide.** Sur « Program Files », il
   écrit une barre inverse suivie d'un espace — qui n'est pas une séquence
   d'échappement valide, et GLib rejette alors **la valeur entière**. Le lanceur
   existait et rien ne le lançait.

**Et un sixième point, qui n'est pas un défaut mais une conséquence :** depuis
le 2026-08-23, le ciel ne montre que ce qu'on y épingle. Une application
*qu'on vient d'installer* n'y montait donc pas non plus — or celle-là,
l'utilisateur vient justement de dire qu'il la voulait, en l'installant. La
distinction retenue : **le ciel ne se remplit pas tout seul du passé, mais il
accueille tout de suite ce qu'on y ajoute.**

### L'icône du programme dans l'étoile

Demande de l'utilisateur. Les glyphes dessinés disent le *genre* d'un logiciel ;
l'icône dit *lequel*. Le pont résout maintenant le fichier d'icône déclaré par
le `.desktop` et le sert par une route `/icone?id=…` — une adresse plutôt qu'une
image en clair dans la page, parce que 81 icônes en `data:` pèseraient plusieurs
mégaoctets à chaque tour. **La route ne lit jamais un chemin venu de la
requête** : elle prend un identifiant, le cherche dans l'inventaire, et c'est
l'inventaire qui dit quel fichier lire. Le glyphe reste le repli — et le
prototype de `galerie/`, ouvert seul, ne change pas d'un pixel.

### Waydroid a tourné, et ce que le gel apprend

*« J'ai lancé F-Droid et l'écran glitch ; j'ai tenté d'installer une app mais ça
a figé à l'autorisation de sources inconnues, rien ne s'est installé. »*

**Première nouvelle, et le carnet disait le contraire depuis le premier jour :
Waydroid a tourné.** « Waydroid n'a jamais tourné » est faux depuis cette
soirée-là. Le différenciateur du projet a démarré, affiché une interface
Android, et lancé F-Droid.

**Le gel est contourné, pas réparé — et c'est délibéré.** L'écran d'autorisation
n'appartient pas à F-Droid : c'est `packageinstaller`, un composant d'Android.
Le gel n'est pas un défaut catalogué de Waydroid ; l'hypothèse la plus plausible
est qu'il s'ouvre dans une fenêtre que le multi-fenêtrage n'affiche pas — *une
fenêtre invisible qui a le focus ressemble exactement à un gel*.

On ne l'ouvre donc plus. **`waydroid app install` installe en silence**, par un
service qui tourne dans `system_server` avec la permission `INSTALL_PACKAGES` :
aucune confirmation n'est demandée. C'est déjà ce que S fait pour poser F-Droid
lui-même, et ça a toujours marché. Le nouveau geste **« Magasin Android »**
cherche dans le catalogue F-Droid depuis l'hôte, télécharge, installe, et fait
monter l'étoile. F-Droid reste le catalogue ; son interface ne sert plus à
installer. C'est la règle 9 portée au monde Android : *une couture ne montre
jamais son moteur, et surtout pas la boîte de dialogue du moteur.*

En complément, `s-android` accorde d'avance l'autorisation à F-Droid pour ceux
qui voudront quand même passer par lui — par `appops`, car `pm grant` ne peut
pas : la permission est déclarée `signature|appop` dans AOSP. **Réserve : cela
retire l'écran qui a gelé, pas la confirmation finale.**

**Le glitch d'affichage n'est PAS corrigé, et rien n'a été touché.** Aucun
rapport connu ne vise un Intel Gen 9.5 mono-GPU ; le corpus est presque
entièrement AMD, et les deux cas Intel sont des portables hybrides. Poser une
propriété au hasard serait la faute du halt de QEMU refaite à l'identique. Ce
qu'il faut d'abord : `ls /dev/dri/renderD*`, `waydroid prop get
ro.hardware.gralloc`, et un `waydroid bugreport` **pendant** que le glitch se
produit — il capture cinq minutes de `logcat` et de `dmesg`, ce qu'un relevé
après coup ne peut pas donner. Puis une variable à la fois :
`gralloc.gbm.legacy=true`, sinon `persist.waydroid.multi_windows false`.

*Correction au carnet en passant :* Aurora Store avait été écarté « faute de
provenance ». **C'est faux — il est sur `f-droid.org`**, et l'URL répond. La
raison de l'écarter, si on l'écarte, doit être une autre.

### Ce qui est éprouvé au banc, et ce qui ne l'est pas

**Éprouvé, sur la machine de développement, le 2026-08-23 :**

| | |
|---|---|
| L'échappement d'une ligne `Exec` | **6 chemins sur 6** relus à l'identique, dont un portant à la fois la barre inverse, le dollar, l'accent grave, le guillemet et l'espace — vérifié contre les règles de `g_shell_parse_argv`, **pas** contre `shlex` de Python, qui n'est pas un modèle fidèle et faisait échouer un échappement correct |
| Le lecteur de `.lnk` | cible rendue depuis la forme ANSI, depuis la forme **UTF-16 seule** (celle que le motif ANSI manquerait), et rien rendu — sans erreur — sur un fichier de 200 octets nuls |
| La conversion vers `dosdevices` | correcte |
| Syntaxe | tous les scripts shell, le Python de `s-etoiles`, zéro CRLF |

Les deux premières pièces entrent au grimoire, avec leur ligne `PREUVE:`.

**Une leçon de méthode, et elle a failli me coûter deux corrections fausses.**
Le premier banc a déclaré l'échappement cassé sur les six chemins. Il avait
tort deux fois : Git Bash réécrit `/usr/bin/...` en `C:/Program Files/Git/...`
en passant à un Python natif Windows, ce qui découpait la ligne en trois ; et
`shlex` de Python n'applique pas les règles du shell dans les guillemets
doubles. **Un banc qui échoue accuse le code par défaut, et il faut le
soupçonner lui d'abord** — c'est la règle 7 retournée vers l'outil de mesure.

**Jamais exercé, et c'est l'essentiel de ce qui reste :**

- **Aucun de ces correctifs n'a tourné sur la machine.** Ni le greeter, ni les
  démons, ni la moisson, ni les icônes, ni le magasin Android. Le banc prouve
  que le code fait ce qu'il dit ; il ne prouve pas que la machine le fera.
- **`s-nettoyer` n'a jamais retiré quoi que ce soit** — `rpm-ostree reset` n'a
  jamais été lancé ici.
- **Le glitch de Waydroid n'est pas diagnostiqué**, et rien n'a été changé pour
  lui.
- **L'écran d'amorçage porte toujours le nom de la base**, et le script qui le
  changerait n'est pas branché.

## 2026-08-23, nuit — le logo au greeter, et la décision de déménager Windows

Trois demandes en une : le logo de S à l'écran de connexion, une copie amorçable
de Windows sur la Seagate, et une ISO installable sur la clé. La première est
faite et cousue dans l'image ; les deux autres sont **écrites, éprouvées là où
elles pouvaient l'être, et pas encore exécutées** — elles demandent des heures
de copie et un geste au firmware que je ne peux pas poser.

### Le logo ne pouvait entrer que par le fond d'écran, et c'est un fait, pas un renoncement

Plasma Login Manager **n'a aucun système de thèmes** — son QML est compilé dans
le binaire. On ne peut donc pas lui *ajouter* un logo : ni par configuration, ni
par un fichier posé quelque part. Le seul pixel de cet écran que S décide est
son fond d'écran.

Le logo y est donc **gravé**. `galerie/foudre-gelee/graver-le-s.ps1` compose la
plaque du S sur Foudre gelée et produit `foudre-gelee-connexion.png`, versionné
au dépôt et posé par `COPY` dans `/usr/share/s/connexion/`. **Le fond du bureau,
lui, reste nu** : un logo permanent au milieu d'un écran qu'on regarde toute la
journée serait une signature, pas une identité.

Détail qui compte pour la netteté : le fond fait 3840×2160 et l'écran de la
M720q 1920×1080. Une plaque de 560 px s'y lit **280 px** — la taille d'une
grosse icône d'application, et le logo source de 256 px n'est agrandi que de
2,2×.

**Deux allures ont été rendues et regardées avant de choisir.** La plaque — le
logo aux coins arrondis, halo bleu, au-dessus du cœur de la foudre. Et un
filigrane — le S grandi et fondu dans l'éclair. Le filigrane est resté dans le
script parce qu'il fonctionne, mais son masque radial mange les extrémités du
S : à l'écran ce n'est plus un logo, c'est une tache. **Jugé sur l'image, pas
sur l'intention.**

**Et le filigrane était d'abord cassé, d'une façon instructive.** Il rendait des
bandes horizontales. La cause : `LockBits` sur un **sous-rectangle** ne rend pas
une foulée de `largeur × 4` mais celle de l'image entière — 3840×4 ici, pas
1040×4 — parce qu'il verrouille la zone en place sans la recopier. Le défaut ne
s'est pas déduit, il s'est **vu** : c'est en regardant le PNG qu'il est apparu.

Le garde-fou qui va avec : `42-greeter.sh` refuse désormais de livrer une image
dont le fond de connexion serait **identique** au fond nu. Sans lui, un graveur
qui n'aurait pas tourné donnerait un écran de connexion sans logo, sans qu'une
seule étape de construction échoue. Encore la règle 2.

### Le flou que la source a révélé, et la seconde voie qu'il impose

Vérifier que ce greeter n'a bien aucun système de thèmes a fait tomber autre
chose. Sa source porte un shader — `WallpaperFader.frag` — dont le facteur est
lié à `Window.window.blur`, propriété pilotée par un appel D-Bus `blurScreen`
émis au changement de fenêtre active. À plein régime : **rayon de flou de
50 px**, contraste et saturation modifiés.

**Si ce flou s'applique au repos, la plaque gravée dans le fond devient une
tache bleue.** On ne le sait pas — il faudrait lire le C++ qui met `blur` à vrai,
et il n'a pas été lu jusqu'au bout.

Deux faits confirmés au passage, et ils valident le reste du travail :

- **`Main.qml` du greeter ne dessine ni logo ni nom de distribution.** Le fond
  d'écran est donc bien le seul vecteur, comme supposé.
- **L'horloge est placée entre la liste des comptes et le bloc de connexion**,
  centrée horizontalement — pas en haut. La plaque, posée à 300 px sur 2160,
  ne devrait pas la rencontrer.

D'où une **seconde voie, que le flou ne peut pas atteindre** : le logo devient
l'**avatar du compte**. `42-greeter.sh` le posait déjà dans `/etc/skel/.face.icon`
— donc seulement pour les comptes créés ensuite, jamais pour `Ghis` qui existe
déjà. `s-corriger-machine` le pose désormais au démarrage dans
`/var/lib/AccountsService/icons/<compte>` et déclare la clé `Icon=`. L'avatar est
dessiné **par-dessus** : aucun shader ne l'atteint.

Il n'écrase jamais un avatar existant, ni une clé `Icon=` déjà déclarée —
éprouvé sur deux fichiers AccountsService, l'un neuf, l'autre portant déjà un
choix. *Et le premier banc s'est trompé lui-même* : il créait le fichier d'icône
avec `: >`, donc **vide**, donc `-s` échouait et le code semblait ne rien faire.
La règle 7 retournée vers l'outil de mesure, une fois de plus.

### La décision qui renverse une limite du carnet

Demande de l'utilisateur, mot pour mot : *« Je veux que S soit natif sur la
720Q comme OS principale et que la copie windows soit amorçable sur la Seagate.
Je veux que S puisse lire ce qu'il y a sur cette copie windows. »*

Cela **annule** la limite 6, qui disait « Windows reste sur le disque interne,
définitivement ». Le raisonnement de cette limite tient toujours — PC Boost est
du WPF, il ne se construit que sous Windows — mais la conclusion a changé :
Windows reste **disponible**, sur la Seagate, et le NVMe rapide revient à S.

Ce qui se paie honnêtement : **Windows sera lent**, sur un plateau USB. C'est le
prix exact que S payait jusqu'ici, échangé de place.

### Ce que ce déménagement a fait tomber dans `s-monter-windows`

Deux défauts, tous deux du type « ne rien trouver, ne rien dire ».

1. **Il ne regardait que les disques non amovibles** (`RM=0`). Windows partant
   sur un disque USB, il ne l'aurait **jamais** trouvé — et `~/Windows` serait
   resté vide sans qu'une commande échoue.
2. **« La plus grosse NTFS » cesse de marcher** dès que la Seagate porte à la
   fois le Windows cloné (400 Go) et une partition de données (4,2 To). Le
   raccourci aurait monté les données.

Le remplacement n'est pas un meilleur raccourci, c'est **un regard** : chaque
candidate est montée en lecture seule et on cherche dedans
`Windows/System32/config/SYSTEM`. La première qui l'a gagne ; si aucune ne l'a,
on ne monte rien — un `~/Windows` vide est moins trompeur qu'un `~/Windows`
plein d'autre chose.

**Éprouvé le 2026-08-23** sur de fausses partitions : écarte 4 To de données,
écarte une partition dont le montage échoue, retient les 300 Go de Windows.
**Jamais exercé sur la machine.**

Au passage, un défaut de lecture qui existait déjà : `lsblk -r` sépare ses
colonnes par un espace et **n'écrit rien** pour un champ vide — deux espaces que
`awk` recolle en un seul, et toutes les colonnes suivantes se décalent. La
sortie est désormais lue en `-P`, par nom de champ. Et **en `awk`, pas par
`eval`** : un des champs s'appelle `PATH`, et l'évaluer écraserait le `PATH` du
shell, après quoi plus une seule commande du script ne se trouverait.

### La sauvegarde, et les quinze photos qui n'étaient pas perdues

`banc/sauvegarder-le-projet.ps1` rassemble le dépôt (`.git` compris, plus un
`git bundle` de toute l'histoire), le banc `S-vm/` sans ses images disque, la
mémoire et les transcriptions de Claude Code, les réglages de VS Code, l'état
exact des trois disques, et un **manifeste SHA-256 de chaque fichier** — pour
que « la copie est arrivée » soit une vérification et non une impression.
**585 fichiers, 0,45 Go.** Le bundle a été **cloné pour de vrai** avant d'être
déclaré bon : 66 commits, `HEAD` identique.

**Et les quinze photos du premier démarrage réel n'ont jamais été perdues.** Le
carnet les dit « non versionnées — à redemander à l'utilisateur » depuis le
2026-08-22. Elles étaient dans `Downloads`, sous leurs noms d'appareil
(`PXL_20260821_*`, `PXL_20260822_*`), 84 Mo. Elles entrent dans la sauvegarde.
*Chercher avant de redemander.*

Les trois `.qcow2` du banc — 74,6 Go — ont été **supprimés** sur décision de
l'utilisateur. C'est un choix, pas un oubli : c'était le seul banc où
`bootc rollback` restait exerçable à froid. C: passe de 60 à **135 Go libres**,
et Windows n'occupe plus que 104 Go, ce qui divise par deux la durée du clonage
à venir.

### L'ISO, et pourquoi elle est un atelier séparé

`.github/workflows/iso.yml` fabrique l'ISO **à la demande**, jamais à chaque
commit : une image se met à jour par `bootc upgrade`, une ISO ne sert qu'à poser
S sur une machine neuve. Elle porte l'image entière, donc **elle installe sans
réseau**.

`banc/graver-iso-sur-cle.ps1` la grave au secteur près sur la SanDisk. Il rejoue
les murs déjà appris — l'élévation testée en premier, la partition supprimée
parce que **retirer la lettre ne démonte pas le volume**, une sonde d'écriture à
64 Mio *avant* d'engager quoi que ce soit — et il en ajoute un : sur un handle
de disque physique, le tampon interne de `FileStream` est désactivé, parce que
Windows n'accepte que des écritures alignées sur la taille de secteur et qu'on
ne parie pas sur le découpage de .NET.

### L'ordre, qui est ici la seule vraie protection

Écrit en entier dans [`banc/le-demenagement.md`](banc/le-demenagement.md), et
résumé ici parce que s'en écarter coûterait le Windows de la machine :

**L'ISO d'abord, gravée et vue démarrer.** Puis la sauvegarde. Puis la Seagate
effacée. Puis la capture, le dépliage, la préparation USB. **Puis F12 — et
seulement si le clone démarre pour de vrai, le NVMe est effacé.**

`banc/windows-sur-seagate.ps1` **n'efface jamais le NVMe** : cette commande
n'existe pas dedans, à dessein. Tant que le clone n'a pas démarré, un F12 ramène
tout comme avant.

### Ce qui peut échouer, dit avant plutôt que découvert

**Une installation Windows née sur du NVMe ne sait pas lire un disque USB au
moment où elle doit lire le sien** — les pilotes USB ne sont pas dans son jeu
d'amorçage. Le symptôme est `INACCESSIBLE_BOOT_DEVICE`. La phase `preparer-usb`
arme ces pilotes dans le registre du **clone**, efface `MountedDevices` — qui
sinon ferait chercher son `C:` sur un disque qui n'est plus le sien — et pose
`PortableOperatingSystem`. C'est ce que faisait Windows To Go. **Ça marche
souvent, ça ne se promet pas.**

Et la capture passe par un **cliché VSS**, jamais par `C:` en direct : lire un
volume qui tourne donne des ruches de registre incohérentes, donc une copie qui
ne démarre pas.

### Ce qui n'a pas été exercé, et c'est l'essentiel de ce qui reste

- **Le logo n'a jamais été vu à l'écran de connexion**, ni comme plaque ni
  comme avatar. Il est dans l'image publiée ; personne ne l'a regardé sur la
  machine. Deux inconnues subsistent : le **flou** du `WallpaperFader`, qui
  déciderait du sort de la plaque, et la **position** de celle-ci, qui reste un
  pari sur une mise en page qu'on n'a pas vue. Les deux se règlent en une ligne
  du graveur — mais il faut d'abord regarder l'écran.
- **Aucune phase du déménagement n'a été exécutée**, sauf `inventaire`, qui
  n'écrit rien.
- **`s-monter-windows` n'a toujours jamais tourné sur la machine**, ni dans son
  ancienne forme ni dans la nouvelle.
