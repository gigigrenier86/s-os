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

## 2026-08-29, apres-midi — les gestes Android reparlaient a un binaire mort, et la chaine neuve est eprouvee a l'ecran

**PREUVE :** capture `android-fdroid.png` (scratchpad de session) — F-Droid
rendu en entier, catalogue charge, dans une fenetre kwin de classe
`waydroid.org.fdroid.fdroid`, sur cette machine, apres que le geste
`s-android` du depot ait ete lance de bout en bout : ecriture des proprietes,
`systemctl start s-android.service`, `setprop waydroid.active_apps` +
`am start` — et l'installation de F-Droid elle-meme, faite en flux depuis
l'hote par le mecanisme neuf (`pm install -S`, « Success »).

**Le gouffre, trouve en se mettant a jour apres le redemarrage de midi.** Le
binderfs 0600 etait corrige, la machine redemarree dessus, `s-android.service`
fonctionnel au niveau bas — mais TOUT ce que l'utilisateur clique (l'icone
« Android », « Play Store », « Magasin Android », la bascule de la barre
laterale) etait encore ecrit contre la CLI `waydroid`, retiree la veille avec
le paquet. `which waydroid` : rien. Cliquer « Android » aurait boucle deux
minutes sur un `waydroid status` muet (« command not found » avale par
`2>/dev/null`, `grep -qi RUNNING` faux sans un mot) puis conclu « Android n'a
pas demarre ». Le succes silencieux, cote geste.

**Ce qui a ete construit — `partage-android.sh` porte desormais les verbes
natifs, partages par les trois gestes** (copie de reference au Grimoire,
`android-piloter-sans-waydroid.sh`) :

| Verbe | Mecanisme | Privilege |
|---|---|---|
| `s_android_etat` | `systemctl is-active s-android.service` | aucun |
| `s_android_dans` | `s_root lxc-attach -P /var/lib/waydroid/lxc -n android --` | pkexec |
| `s_android_prop_lire/ecrire` | `/var/lib/waydroid/waydroid.prop` en direct | lecture libre, ecriture pkexec |
| `s_android_installer` | `pm install -S <taille>`, APK en flux stdin | pkexec |
| `s_android_lancer` | `resolve-activity` + `setprop waydroid.active_apps` + `am start -n` | pkexec |

**Quatre hypotheses de la conception tuees par la mesure, chacune en
faisant :**

1. **« lxc-info marche sans privilege »** — vrai UNIQUEMENT conteneur arrete
   (la mesure du matin, faite dans ce seul etat). En marche : « Insufficent
   privileges to control » — le socket de commande est a root. La premiere
   boucle d'attente guettait RUNNING sur un temoin incapable de le dire, et
   « Android n'a pas demarre » est tombe sur un Android vivant (DHCP negocie).
   Remplace par systemd, qui se lit sans droit et possede lxc-start.
2. **« pm install -S <taille> - »** — le tiret final est refuse par ce pm
   (Android 13) : « Unknown option - ». La forme flux est `-S <taille>` seul,
   APK sur stdin. Corrige, puis eprouve sur le vrai F-Droid : « Success ».
3. **« am start rend son verdict par son code »** — faux : « Error: Activity
   not started », code 0. Le verdict se lit dans la sortie ; corrige.
4. **« am start suffit a faire une fenetre »** — faux : `hwcomposer.waydroid.so`
   ne cree une fenetre Wayland que d'apres `waydroid.active_apps` (lu dans sa
   table des symboles, extraite de vendor.img par `debugfs` sans montage ni
   droit). Sans le `setprop`, activite au premier plan et ecran vide. La
   sentinelle `Waydroid` donne l'interface complete — mesuree : l'accueil
   Android entier, horloge a l'heure de la machine, dans une fenetre kwin de
   1747×1028, exactement la taille calculee.

**Et le piege documente de s-monde a mordu deux fois le banc de cette passe**
— `lxc-attach` chowne son stdout : deux fichiers de capture passes root:0600
en un appel chacun. La lecon (« un tuyau, jamais le descripteur ») a ete
appliquee au seul endroit du code neuf qui redirigait
(`s-magasin-android` → `s_tee`).

**Deux defauts de fond corriges en chemin :**

- **Le marqueur `android-pret` mentait depuis le test a froid du 2026-08-28**
  — F-Droid efface avec les donnees, marqueur intact disant « pose ».
  L'exacte faute que ce carnet reproche aux marqueurs de premier demarrage,
  commise par S. Le marqueur porte desormais l'inode du dossier de donnees :
  donnees recreees, marqueur perime tout seul. (C'est ce qui a permis
  d'eprouver l'installation pour de vrai : F-Droid manquait reellement.)
- **`waydroid.cfg`/`waydroid_base.prop` sont morts avec le paquet** — le seul
  fichier qu'Android lit encore est `waydroid.prop`, celui
  qu'`android-lancer.sh` bind-monte. Tout le jeu de gardes en trois passes de
  l'ancien `s-android` (fichier contre `prop get`, la confusion payee le
  2026-08-25) se replie en UNE lecture et UNE ecriture. `suspend_action`
  disparait sans regression : il n'avait jamais rien fait, et le mecanisme
  qui l'aurait lu n'existe plus.

**Addendum, 14 h 35 — eprouve depuis l'IMAGE, et une course de plus.**
Construction verte (`652b5a5`), signature verifiee, `rpm-ostree upgrade`
puis redemarrage : binderfs a `0666` des le premier demarrage (la reserve
de midi tombe), les cinq fichiers identiques entre depot et `/usr`, et
l'utilisateur a clique « Android » depuis l'image — accueil rendu, capture
`android-image.png`. La chronologie pkexec de ce clic a montre une COURSE :
conteneur lance a 14:29:33, `pm list packages` a 14:29:36, trois secondes
plus tard — « Can't find service: package », « F-Droid absent » conclu a
tort, reinstallation trop tot, marqueur ecrit quand meme. « RUNNING » cote
lxc veut dire « /init a demarre », pas « Android repond ». Corrige : le
demarrage et l'attente de `sys.boot_completed` tiennent dans UNE elevation,
et le marqueur ne s'ecrit que si F-Droid est reellement la. Remesure a
froid : `pm list` 19 s apres le start, apres boot_completed, zero erreur ;
et `s-play-store` a tourne pour de vrai en chemin (marqueur absent) — sa
requete sqlite par `lxc-attach` a rendu l'identifiant Google. Il ne reste
rien de « non rejoue » dans la liste ci-dessous, sauf ce qui est un chantier.

**Ce que cette passe ne prouve pas :**

- **Une machine NEUVE ne peut plus obtenir Android du tout.** `waydroid init`
  etait le seul telechargeur de `system.img`/`vendor.img`, et il est parti
  avec le paquet. Cette machine vit sur les images du 2026-08-25 ; une
  reconstruction a zero n'aurait rien. `s-android` le DIT desormais
  honnetement au lieu d'echouer en silence. Chantier a part, non commence :
  reproduire la logique OTA de l'ancien `initializer.py`.
- **Aucune icone par application Android n'existe plus** — le demon Python
  (AppsService) qui posait un `.desktop` par installation est parti avec le
  paquet. `s-magasin-android` ouvre desormais l'application juste apres
  l'avoir installee, mais rien ne survit dans le menu. Chantier a part.
- ~~**`s-play-store` n'a pas ete rejoue**~~ — rejoue a 14 h 34, identifiant
  rendu (voir l'addendum).
- **La bascule et le mode d'affichage de la barre laterale** (`reglages.py`)
  sont reecrits et leurs fonctions de lecture mesurees en direct
  (`_android()` → RUNNING sur le conteneur vivant, `_mode_android()` lit le
  fichier sans exiger la session) — mais aucun clic dans le panneau lui-meme.
- **Rien n'est dans l'image.** Tout a tourne depuis le depot
  (`S_LIB=.../files/usr/lib/s`). Il faut une construction et un
  `bootc upgrade`.
- **`monkey` est un wrapper bash inerte sur cette image** — releve en
  passant, pour que personne ne compte dessus.

---

## 2026-08-29, midi — s-android.service mourait proprement en 15-25s, et la cause tenait en un chmod

**PREUVE :** `sys.boot_completed` vaut `1`, lu par `lxc-attach` sur cette
machine, apres un redemarrage `systemctl restart s-android.service` complet,
et le service reste `RUNNING` bien au-dela de la fenetre ou il mourait
systematiquement (30s+, contre 15-25s toutes les tentatives precedentes).

**Le symptome, releve pour la premiere fois sur la machine fraichement
reconstruite (voir la section precedente) :** `s-android.service` demarrait
sans erreur — `ExecStartPre=` reussi, `lxc-info` confirmant `RUNNING`,
Android bootant reellement (`init` premiere et deuxieme etape, `zygote`
lance) — puis s'arretait PROPREMENT 15 a 25 secondes plus tard :
`dnsmasq[…]: exiting on receipt of SIGTERM` suivi de
`systemd[1]: s-android.service: Deactivated successfully.`. Aucune ligne
d'erreur entre les deux. Un code de sortie 0, pas un crash.

**Quatre hypotheses formees et tuees avant la bonne, chacune par une
mesure — la methode qui compte plus que le resultat final :**

| Hypothese | Ce qui l'a tuee |
|---|---|
| Conteneur perime d'un essai manuel anterieur | `sudo lxc-stop -k` puis nouvel essai a froid : meme mort, meme fenetre |
| `Delegate=yes` manquant (systemd et cgroup v2 se disputent l'arbre de cgroups d'un gestionnaire de conteneurs) | ajoute, teste : **exactement le meme symptome**, a la seconde pres |
| `android-presse-papiers.py` sature `/dev/binder` (tournait a 99 % CPU en boucle depuis le demarrage de la machine, ouvrant le meme noeud partage) | service utilisateur arrete, nouvel essai : **meme mort** |
| Denis SELinux (AVC) sur le domaine `s_android_t` ou sur les fichiers de donnees | `ausearch -m avc --start today` **puis** scope precis sur la fenetre exacte de l'essai : zero denial pendant tout le cycle de vie du conteneur |

**La mesure qui a tranche, et qui a demande de suivre `lxc-start` depuis sa
naissance plutot que de chercher `servicemanager` apres coup** (une simple
attache `strace -p <pid-decouvert>` arrivait toujours trop tard — le
processus etait deja mort entre deux appels a `pgrep`) :

```
strace -f -tt -p <MainPID de s-android.service>
```

rejoue depuis l'exec de `lxc-start`, suit tous les forks a travers le
nouvel espace de noms PID (`ptrace` n'a pas besoin que le traceur et la
cible partagent le meme espace de noms), et montre la sequence exacte de
`servicemanager` (uid Android 1000, "system") :

```
openat(AT_FDCWD, "/dev/binder", O_RDWR|O_CLOEXEC) = -1 EACCES
write(2, "Binder driver '/dev/binder' coul"..., 109)
rt_tgsigqueueinfo(21, 21, SIGABRT, {})     <- s'auto-envoie SIGABRT
--- SIGABRT {si_signo=SIGABRT, si_code=SI_QUEUE, si_pid=21, si_uid=1000} ---
+++ killed by SIGABRT (core dumped) +++
```

**`servicemanager` ne recevait jamais la permission d'ouvrir
`/dev/binder`, et s'auto-abortait (`LOG_ALWAYS_FATAL`) en moins de
200 ms — avant meme d'avoir tente `BINDER_SET_CONTEXT_MGR`.** Verifie :
`/dev/binderfs/binder` est cree en `crw-------` (0600, `root:root`) a
CHAQUE montage de `dev-binderfs.mount`, releve deux fois de suite apres un
demontage/remontage volontaire. `servicemanager` tourne en UID 1000 —
sans droit d'ouvrir un fichier 0600 appartenant a `root`. **Aucun AVC ici,
et c'est normal : un refus DAC (permissions Unix) ne genere pas d'audit
SELinux.**

**Pourquoi c'etait invisible toutes les nuits precedentes.** Le vrai
Waydroid corrige cette permission lui-meme dans son outillage Python
(jamais lu jusqu'a ce soir, puisqu'on saute entierement son code depuis le
2026-08-28), quelque part avant de lancer le conteneur. Sur cette machine,
tant qu'aucun redemarrage complet n'avait eu lieu depuis la DERNIERE fois
que le vrai `waydroid` avait tourne (avant sa suppression), les noeuds
`/dev/binderfs/*` restaient permissifs — un `binderfs` monte une seule
fois au demarrage du systeme, jamais remonte entre deux sessions Android.
**Cette nuit est la premiere ou la machine a redemarre depuis que
`waydroid`/`waydroid-selinux` sont partis** (voir la section precedente,
`bootc upgrade` puis redemarrage) : le binderfs de ce boot n'a jamais ete
touche par l'ancien outillage, et la permission manquante est devenue
visible pour la premiere fois.

**Correctif :** un troisieme `ExecStartPre=` dans `s-android.service`,
`chmod 0666 /dev/binderfs/binder /dev/binderfs/hwbinder
/dev/binderfs/vndbinder`, avant le `ln -sf` deja present — cette commande
tourne dans le contexte par defaut (`init_t`), exactement comme le `ln`,
et n'a besoin d'aucun droit special. Une option de montage
(`stat_mode=0666`) a ete essayee en premier sur `dev-binderfs.mount` —
**refusee par ce noyau** (`fsconfig() failed: binder: Unknown parameter
'stat_mode'`), pas une option reconnue de ce `binder` de noyau. Le
`chmod` reste donc la forme retenue.

**`Delegate=yes` reste dans le fichier**, ajoute pendant cette meme
enquete sur une hypothese qui s'est averee fausse — voir son propre
commentaire dans `s-android.service`, corrige pour ne plus affirmer une
explication qu'aucune mesure n'a jamais soutenue.

**Methode a retenir, au-dela du correctif lui-meme :** une attache
`strace` sur un PID decouvert par sondage (`pgrep` en boucle) arrive
presque toujours trop tard pour un processus qui vit moins de 200 ms.
Attacher `-f` a l'ancetre depuis sa naissance (ici, `lxc-start` lui-meme,
dont le PID est connu a l'instant du `systemctl restart`) et laisser
`strace` suivre les forks jusque dans le nouvel espace de noms PID est la
seule methode qui a rendu la vraie sequence lisible.

### Ce que cette passe ne prouve pas

- **Le correctif n'a ete eprouve que par redemarrage du service**, pas par
  un redemarrage complet de la machine — le prochain `bootc upgrade` +
  redemarrage dira si `dev-binderfs.mount` (unite `static`, montee une
  seule fois par demarrage) redonne bien des noeuds 0600 vierges a chaque
  fois, comme attendu, et si le `chmod` les corrige aussi fiablement au
  tout premier demarrage de la machine qu'aux suivants.
- **Aucun geste au-dela de `getprop sys.boot_completed` n'a ete repris ce
  soir** — le Play Store, le presse-papiers, la video : rien de tout ca
  n'a ete recliqué depuis que le correctif tient.
- **Rien n'est encore dans l'image.** Le correctif vit dans `/usr` en
  overlay transitoire sur cette machine et dans le depot (`git commit` +
  `push` dans la foulee de cette section) — il faut une construction et
  un `bootc upgrade` pour qu'une machine neuve en beneficie.

---

## 2026-08-29, matin — la construction GitHub a echoue, et deux causes, pas une

**PREUVE :** commit `fb631cf` (celui qui rend le montage SELinux
reproductible) a echoue en construction — verifie via l'API publique de
GitHub (`api.github.com/repos/gigigrenier86/s-os/actions/runs`, aucune
authentification requise, `gh` n'est toujours pas sur cette machine).
Reproduit et corrige en local avec `podman run` sur l'image de base,
sans attendre une deuxieme construction distante pour le savoir.

**Cause 1 — `dev-binderfs.mount` n'est PAS une brique independante de
Bazzite.** Elle est livree PAR le paquet `waydroid` (`rpm -ql waydroid` le
montrait depuis le debut de la nuit, relu trop vite). `20-android.sh`
retire le paquet avant que `47-android-selinux.sh` ne verifie la presence
du fichier — la construction locale a rendu l'erreur en clair : "ECHEC :
dev-binderfs.mount absent". Corrige en le recopiant comme fichier a nous
(`files/usr/lib/systemd/system/dev-binderfs.mount`, contenu capture depuis
l'image de base avant suppression) : trois lignes generiques, rien de
propre a Waydroid dans son contenu, seulement dans sa provenance.

**Cause 2 — `core.filemode = false` sur ce depot.** `chmod +x` sur les
scripts avait ete fait sur les copies DEPLOYEES (`/usr/lib/s/...`), jamais
sur les fichiers du depot (`files/usr/lib/s/...`) avant de les committer —
et meme la ou ca avait ete fait, ce reglage du depot fait que git IGNORE
tout changement de mode execute par un `chmod` ordinaire. `git ls-files -s`
rendait `100644` (pas executable) pour `android-lancer.sh`,
`android-net.sh` et `android-presse-papiers.py`, silencieusement, sans
qu'aucun `git status` ne le signale. La seule commande qui marche ici :
`git update-index --chmod=+x <fichier>`, qui force le mode dans l'index
independamment du reglage du depot.

**Methode a retenir :** reproduire une panne de construction en local avec
`podman run` sur l'image de base amont, en rejouant juste les scripts
touches (`podman exec ... bash /build_files/XX.sh`), est beaucoup plus
rapide qu'attendre une deuxieme construction distante de dix minutes pour
voir si le correctif tient — et l'API publique de GitHub Actions donne le
verdict (`status`, `conclusion`, la liste des etapes) sans qu'aucun droit
admin ne soit necessaire, seul le telechargement des journaux bruts
l'exige (`403 Must have admin rights`).

---

## 2026-08-28, fin de nuit — le "pont input" n'a jamais existé a construire, et le test ultime passe

**PREUVE :** Mike s'est connecté a son vrai compte Google dans le Play Store,
sous `s-android.service`, clavier et souris compris — sans qu'une seule ligne
de code d'entree n'ait ete ecrite ce soir.

**Correction d'une hypothese tenue toute la soiree.** Les « trois ponts »
nommes au debut (Init/Zygote, Graphique, Input) n'en etaient reellement que
deux a construire. Le pont graphique (`hwcomposer.waydroid.so`, a l'interieur
de `system.img`, jamais touche — un des "depots utiles" que Mike a demande de
garder) parle le protocole Wayland complet, pas seulement l'affichage :
clavier et souris en font partie de base, au meme titre que les surfaces de
rendu. En gardant cette bibliotheque intacte plutot que de la remplacer, le
pont input est venu gratuitement avec le pont graphique. Rien a batir la —
juste ne pas casser ce qui etait deja la.

**Bilan de la nuit, dans l'ordre :**
1. `s-android.service` (lxc-start direct, domaine SELinux `s_android_t`
   renomme depuis `waydroid_t`) fait booter Android en entier.
2. Le presse-papiers a ete porte (`android-presse-papiers.py`), verifie
   depuis Android.
3. `waydroid`/`waydroid-selinux` retires (`rpm-ostree override remove`,
   pose, en attente d'un redemarrage).
4. Un vrai test a froid : donnees Android entierement effacees, redemarrage,
   Play Store et les services Google presents nativement (image GAPPS),
   aucune app tierce reinstallee.
5. Bug reseau trouve et corrige : `dnsmasq` mourait a chaque arret du
   service (meme cgroup que `lxc-start`), le fichier temoin de
   `android-net.sh` survivait dans `/run` et faisait sauter le vrai
   redemarrage du DHCP au tour suivant — corrige en verifiant le PID du
   processus, pas seulement l'existence du fichier.
6. La fenetre systeme generique d'Android (classe exacte `Waydroid`) est
   retiree de la barre des taches/Alt-Tab/pager (`skiptaskbar`+`skipswitcher`+
   `skippager`, Force) — KWin ne permet pas de forcer un titre ni une icone
   apres coup, seulement de filtrer dessus, mesure a plusieurs reprises.
7. Mike s'est connecte a son compte Google — la preuve finale, et elle n'a
   demande aucun code d'entree.

---

---

## 2026-08-28, nuit — Android tourne sous s-android.service, Waydroid n'est plus dans l'image

**PREUVE :** le 2026-08-28 vers 23h, `s-android.service` (root, `lxc-start` direct)
a fait booter Android en entier — `zygote`/`zygote64`/tous les HAL confirmés
par `ps -A` dans le conteneur — et une vraie capture d'écran a montré le
clavier Android rendu par Constellation. Le pont presse-papiers a été porté
(`android-presse-papiers.py`, service utilisateur) et vérifié : `service list`
depuis Android montre `waydroidclipboard: [lineageos.waydroid.IClipboard]`
sans qu'aucun code du paquet `waydroid` ne tourne. `rpm-ostree override remove
waydroid waydroid-selinux` est posé (attend un redémarrage).

**Ce qui a fait marcher `s-android.service`, dans l'ordre où les murs sont
tombés — utile si ça recasse :**

1. **`lxc-start` reste le moteur**, jamais `systemd-nspawn` : le module
   SELinux de Waydroid transitionne `lxc-start` vers `container_runtime_t`
   (binder/dma/graphics deja autorises) ; `systemd-nspawn` n'a aucune
   transition dediee, verifie via `seinfo -t`.
2. **Une seule ligne `ExecStart=`, jamais plusieurs `ExecStartPre=`.**
   `waydroid_exec_t` (devenu `s_android_exec_t`) n'est mappe que sur UN
   fichier ; chaque ligne `Exec*=` separee est relancee par `init_t`, qui n'a
   pas le droit d'entrer dans ce domaine. D'ou `android-lancer.sh` : un seul
   script qui prepare, appelle le pont reseau, puis `exec lxc-start`.
3. **`find`/readdir sur `/run/user/1000` est refuse** au domaine
   (`userdom_search_user_tmp_dirs` donne "search", pas "read") — on teste des
   noms de socket connus (`wayland-0`, `wayland-1`) au lieu de lister le
   dossier.
4. **`/var/lib/waydroid/rootfs` est un squelette vide** tant que `system.img`
   et `vendor.img` ne sont pas montes (+ overlay `system`/`vendor`) — c'est
   `tools/helpers/images.py::mount_rootfs()` qui le fait chez Waydroid, jamais
   appele puisqu'on saute son Python. Traduit en `mount(8)` direct dans
   `android-lancer.sh`.
5. **Toujours repartir d'un rootfs demonte** (`umount -R` en tete de script)
   plutot que de deviner l'etat avec `mountpoint -q` : un overlay monte deux
   fois sur lui-meme rend "bad superblock".
6. **`waydroid.prop` existe deja** dans `vendor.img` (place-holder de 19
   octets) — pas de `touch` avant le bind, l'overlay vendor est en lecture
   seule.

**Le module SELinux `s_android` (voir `files/usr/share/selinux/s-android/`)**
est une renomination mecanique de `waydroid.te` (`sed s/waydroid/s_android/g`)
— memes regles, domaine a nous. Compile avec
`selinux-policy-devel`/`checkpolicy` (installes en overlay `/usr` transitoire
pour ce soir, **pas encore dans le Containerfile**).

**Ce qui reste, et ce n'est pas cosmetique :**

- **Le Containerfile ne construit pas encore ce chantier.** Tout ce soir a
  ete fait en direct sur la machine (`bootc usr-overlay`, copies a la main).
  `build_files/20-android.sh` installe et verifie encore l'ancien Waydroid ;
  il faut le reecrire pour construire `s_android.pp` a l'image et deployer
  `android-lancer.sh`/`android-net.sh`/`android-presse-papiers.py` depuis
  `files/`. Sans ca, le prochain `bootc upgrade` qui tire une image
  fraichement construite **peut faire revenir Waydroid** — l'override
  `rpm-ostree` posé ce soir n'est pas garanti de survivre a une image
  entierement neuve.
- **Pont 3 (input) non commence.**
- **Pas d'arret propre** dans `android-lancer.sh` : les montages
  `system.img`/`vendor.img` restent actifs si le service s'arrete mal
  (`umount -R` en tete de script les nettoie au demarrage suivant, mais rien
  ne les demonte a l'arret).
- **Renommage visuel fait a moitie** : la fenetre systeme generique
  (`wmclass=Waydroid`) est forcee vers le titre « S » via `regles-kwin.py`,
  mais seulement pour une fenetre qui n'existe pas encore — celle deja
  ouverte au moment de la regle garde son ancien titre jusqu'a sa prochaine
  ouverture. Les fenetres d'applis gardent leur vrai nom (YouTube reste
  YouTube), par choix explicite de Mike.

---

## 2026-08-28, tard le soir — Mike veut retirer LXC de Waydroid, et la source dit pourquoi ce pont n'existe pas comme il le croit

Changement de cap de Mike : au lieu d'utiliser le noyau natif déjà en place
(entrée précédente), il veut maintenant que S se passe de Waydroid *comme
gestionnaire*, jugé responsable d'avoir cassé le clavier et la résolution et
d'avoir coûté du temps sur YouTube. Objectif annoncé : trois ponts à isoler —
(1) lancement Init/Zygote directement par `systemd`, sans LXC ; (2) pont
graphique (gralloc → Wayland) géré nativement par Constellation ; (3) pont
input (`evdev` → Android) « hardcodé » sans passer par la config Waydroid.

**Sur le pont 1, la source de Waydroid elle-même referme la piste telle que
posée.** `/usr/lib/waydroid/tools/helpers/lxc.py`, fonction `start()` :

```python
command = ["lxc-start", "-P", tools.config.defaults["lxc"],
           "-F", "-n", "waydroid", "--", "/init"]
```

**Zygote ne dépend déjà de rien qui vienne de LXC ou de Waydroid.** Une fois
`/init` lancé, c'est `init.rc` d'Android lui-même — livré par l'image système
Android, pas par Waydroid — qui démarre Zygote. « Faire démarrer Zygote sans
LXC » n'est donc pas une extraction à faire : Zygote démarre déjà tout seul.
Ce que LXC fournit, et que retirer LXC obligerait à reconstruire ailleurs,
c'est visible dans `generate_nodes_lxc_config()` du même fichier : près de 40
points de montage (binder/hwbinder/vndbinder, `/dev/ashmem`, les nœuds GPU,
`/dev/fb*`, le socket Wayland de la session, le socket Pulse, les données
utilisateur, les permissions vendor…) **dans un espace de noms de montage et
un espace de noms PID privés**, plus un profil AppArmor (`lxc-waydroid`) et un
profil seccomp dédiés.

**Pourquoi ces deux espaces de noms ne sont pas une option.** L'`init`
d'Android suppose être PID 1 de son propre arbre de processus, avec son
propre `/proc`, sa propre hiérarchie de cgroups, et son propre point de
montage racine construit sur mesure par les ~40 entrées ci-dessus. Le PID 1
de la machine, c'est déjà `systemd`. Deux `init` ne peuvent pas être PID 1 du
même espace de noms — il faut un espace de noms PID séparé pour que `/init`
d'Android s'y croie seul. **Retirer LXC ne retire donc pas une couche
d'isolation superflue : ça retire l'espace de noms sans lequel `/init`
d'Android ne peut pas tourner du tout**, sauf à réécrire cet `init` — projet
sans rapport avec « le sortir du conteneur ».

**Ce qui est vraiment séparable, et c'est la bonne reformulation du chantier :**
remplacer l'outillage Python de Waydroid (`lxc-start`/`lxc-attach`, écriture de
fichiers `.cfg` LXC) par un service `systemd` qui fait le même `unshare`
mount+pid directement (`systemd-nspawn` fait déjà exactement ça, en plus
minimal que LXC) — ce n'est pas « zéro conteneur », c'est « un conteneur plus
petit, tenu par `systemd` plutôt que par le démon `lxc` et le script Python de
Waydroid ». C'est un chantier réel ; « Zygote sans isolation du tout » n'en
est pas un.

**Pas encore regardé :** le pont graphique (`hwcomposer.waydroid.so`, déjà
partiellement documenté plus bas dans ce carnet) et le pont input (aucune
référence à `uinput`/`evdev`/`/dev/input` trouvée dans `/usr/lib/waydroid/` —
`grep -rl` y rend vide, donc soit ce pont vit ailleurs, soit Waydroid ne fait
pas de traduction input du tout et compte sur les nœuds `/dev/input`
directement visibles dans le conteneur — hypothèse non vérifiée).

**La mesure qui trancherait la suite :** `find / -xdev -iname '*.so' -exec sh
-c 'nm -D {} 2>/dev/null | grep -qi uinput && echo {}' \;` limité à
`/usr/lib/waydroid` et au rootfs Android, pour trouver qui, côté Waydroid ou
côté Android, ouvre réellement les nœuds `/dev/input`.

---

## 2026-08-28, soir — le Wizard cherche le noyau à recompiler pour binder/ashmem/PSI, et deux des trois existent déjà

Mike voulait recompiler nativement binder, ashmem et PSI pour s'affranchir d'un
conteneur comme Waydroid. La recherche déplace le problème plus qu'elle ne le
résout : deux des trois cibles sont déjà des réglages actifs du noyau qui
tourne, pas des modules à construire — et ce carnet définissait déjà Waydroid
comme non-émulé dès sa première section (lignes 22-24 : « Android *est* Linux,
son espace utilisateur partage le noyau hôte »). Binder et PSI *sont* déjà
cette couche native.

**Hypothèse — binder est compilé en dur (`=y`) dans `7.2.0-ogc6.1.fc44`, pas en
module : rien à recompiler.**
*Source :* `/usr/lib/modules/$(uname -r)/config` sur cette machine, lu le
2026-08-28 : `CONFIG_ANDROID_BINDER_IPC=y`, `CONFIG_ANDROID_BINDERFS=y`.
*Ce que ça impliquerait ici :* « recompiler binder en module » n'a pas de
cible — il faudrait recompiler le noyau entier pour en changer quoi que ce soit.
*La mesure qui la tue :* `ls -la /dev/binderfs/` → mesuré, `binder`,
`binder-control`, `hwbinder`, `vndbinder` déjà présents en `crw-rw-rw-`.

**Hypothèse — PSI est déjà actif et n'a jamais été un module « Android ».**
*Source :* même fichier : `CONFIG_PSI=y`, `CONFIG_PSI_DEFAULT_DISABLED` absent.
C'est une fonctionnalité mainline depuis Linux 4.20 ; Android (`lmkd`) la
consomme via `/proc/pressure/`, il ne la fournit pas.
*Ce que ça impliquerait ici :* aucune compilation possible ni nécessaire.
*La mesure qui la tue :* `cat /proc/pressure/memory` → mesuré, rempli
(`avg10=… avg60=… avg300=… total=…`), sur `cpu`, `io`, `irq`, `memory`.

~~**Hypothèse — ashmem n'a plus d'option dans ce noyau, et Waydroid ne le
charge pas parce que son propre userspace ne le demande plus.**~~
*Source :* `grep -i ashmem` sur le config embarqué rend vide ; `/dev/ashmem*`
absent. Le pilote `ashmem.c` est sorti de l'arbre mainline vers la 5.x au
profit de `memfd_create`, qu'Android émule depuis la version 10.

**Mesurée le 2026-08-28, confirmée.** `strings
/var/lib/waydroid/rootfs/system/lib64/libcutils.so | grep -i ashmem` a d'abord
semblé la contredire : le code réel d'`ashmem_create_region` etc. est bien lié
dans `libcutils.so`, aux côtés du chemin `memfd`. Ce n'était pas encore la
preuve — `strings` montre ce qui est *compilé*, pas ce qui *s'exécute* ; la
bascule entre les deux chemins dépend de `ro.vndk.version` (chaîne trouvée sur
la machine : *« device VNDK version (%s) is less than Q. Use ashmem only »*).
Le Voyeur a nommé la vraie mesure, prise dans la foulée :

```
waydroid shell getprop ro.vndk.version
→ 33
```

33 ≥ 29 (Q) : le chemin `memfd_create` est celui qui tourne, pas `ashmem`.

**Confirmation plus forte, trouvée le 2026-08-28 dans la source même de
Waydroid** (`/usr/lib/waydroid/tools/helpers/lxc.py`, fonction
`make_base_props`) : ce n'est pas une déduction depuis le VNDK, c'est écrit en
clair —

```python
if not os.path.exists("/dev/ashmem"):
    props.append("sys.use_memfd=true")
```

Waydroid détecte lui-même l'absence de `/dev/ashmem` côté hôte et **force**
la propriété Android `sys.use_memfd=true` avant même que le conteneur démarre.
La même fonction montre aussi que `/dev/ashmem` fait partie de la liste de
nœuds que `generate_nodes_lxc_config` tente de lier (`make_entry("/dev/ashmem")`,
ligne 50) — silencieusement ignoré ici puisque `check=True` par défaut et que
le fichier n'existe pas sur l'hôte.

**Aucun pilote ashmem à recompiler pour ce Waydroid.** Les trois cibles
d'origine (binder, ashmem, PSI) sont donc closes sans une ligne de C : binder
et PSI sont déjà natifs dans `7.2.0-ogc6.1.fc44`, et ashmem est émulé par le
userspace Android que Waydroid installe. Le seul chantier qui resterait est de
*patcher* binder ou PSI eux-mêmes — un projet différent de « recompiler les
modules Android », voir la source OGC plus bas.

**Hypothèse — `7.2.0-ogc6.1.fc44` n'est pas un noyau Fedora patché par
Bazzite : c'est celui de l'Open Gaming Collective (OGC), un consortium formé
courant 2026 (Bazzite/Universal Blue, ASUS Linux, ShadowBlip, PikaOS, Fyra
Labs, ChimeraOS, Nobara, Playtron), et sa source est publique et taguée.**
*Source :* `rpm -qi kernel-core` → `Vendor: The Linux Community and OGC
maintainer(s)`, `URL: https://opengamingcollective.org`, `Source RPM:
kernel-core-7.2.0-ogc6.1.fc44.src.rpm`. Recherche web du 2026-08-28 :
`github.com/OpenGamingCollective/linux` (fork mainline, tag `v7.2-ogc6`
présent) et `github.com/OpenGamingCollective/kernel-packages` (le vrai
générateur : `fedora/kernel.spec` + fragments `config/ogc.config.set` /
`.unset`, `.github/workflows/fedora.yaml` qui construit avec
`rpmbuild --define "_topdir $TOPDIR" -ba ./fedora/kernel.spec` dans un
conteneur `fedora:44`).
*Ce que ça impliquerait ici :* aucune COPR ni dépôt dnf actif sur la machine
ne sert ce noyau — seul `bieszczaders:kernel-cachyos-addons` est actif et ne
fournit que des akmods complémentaires (v4l2loopback, xone…), pas le noyau. Il
arrive déjà empaqueté dans `ghcr.io/ublue-os/bazzite:stable`, en amont de S
(le `Containerfile` de S ne le touche jamais — vérifié, `grep -i kernel
Containerfile build_files/*.sh` ne rend rien).
*La mesure qui la tue :* cloner `v7.2-ogc6`, tirer `fedora/kernel.spec` de
`kernel-packages`, et vérifier que son `Release:`/`%changelog` produit bien
`ogc6.1` pour une cible Fedora 44 → si ça ne correspond pas exactement, il faut
remonter au run de `fedora.yaml` précis (le numéro de build y est compté par
job), pas se fier au tag seul.

**Hypothèse — les en-têtes exacts pour compiler un module hors-arbre sont déjà
installés, sans rien télécharger.**
*Source :* `rpm -qa | grep kernel-devel` → `kernel-devel-7.2.0-ogc6.1.fc44` et
`kernel-devel-matched-7.2.0-ogc6.1.fc44` déjà posés ; `/usr/src/kernels/7.2.0-ogc6.1.fc44.x86_64/`
existe, arbre complet.
*Ce que ça impliquerait ici :* pour un module hors-arbre contre ce noyau précis
(ashmem via `anbox-modules`, par exemple, si l'hypothèse ashmem ci-dessus est
confirmée nécessaire), ni conteneur ni outil ublue-os spécifique ne sont
requis : `make -C /usr/src/kernels/$(uname -r) M=$PWD modules` tourne dans le
shell utilisateur, sans toucher `/usr` (lecture seule) ni l'image OSTree.
*La mesure qui la tue :* `test -e /usr/src/kernels/$(uname -r)/Makefile` →
mesuré, présent. Un build réel sur un module bidon (`obj-m += vide.o`)
confirmerait que la chaîne aboutit ; **non fait pendant cette passe**, c'est le
travail de l'Alchimiste.

**Le Code Noir à nommer avant de cloner quoi que ce soit :**
`kernel-packages` publie sa clé (`public.key` à la racine) et annonce des
« signed OCI images » — provenance d'un consortium de neuf organisations
connues, pas d'un mainteneur isolé. Mais `rpm -qi kernel-core` sur cette
machine rend `Signature : (none)`, cohérent avec ce que ce carnet a déjà
tranché sur les paquets Fedora/COPR (l'en-tête RPM ne retient jamais la
signature, même légitime — voir plus bas dans ce fichier, le faux Code Noir du
2026-08-25). *Ne pas confondre absence de signature RPM et absence de
provenance vérifiable :* la mesure qui trancherait vraiment est `cosign
verify` sur l'image OCI que `kernel-packages` publie, contre `public.key` — pas
l'en-tête RPM, qui ne le dira jamais.

**Verdict, mesuré le 2026-08-28 :** les trois cibles d'origine sont closes,
aucune ne demande de compilation. Binder et PSI tournent déjà nativement dans
`7.2.0-ogc6.1.fc44` ; ashmem est émulé par `memfd_create` côté userspace
Android (`ro.vndk.version` = 33 sur ce Waydroid, confirmé au-dessus). Le noyau
complet OGC (`github.com/OpenGamingCollective/linux`, tag `v7.2-ogc6`) ne
redevient utile que si le but glisse vers *modifier* binder/PSI eux-mêmes
plutôt que les utiliser — un chantier sans rapport avec « recompiler un
module Android ».

---

## Où on en est — 2026-08-26, soir

**Android tourne, les deux disques sont entiers à S, et le dossier partagé fait
enfin l'aller-retour.** Trois choses aussi : le dépôt vit désormais **sur la
machine** (`/var/home/RyuRex/S`), ce qui supprime d'un coup les deux pièges du
dépôt édité sous Windows — CRLF et bit d'exécution — et permet de mesurer au
lieu de supposer. La journée l'a fait cinq fois.

**Au 2026-08-26 au soir, trois choses ont changé de nature.** La machine
**n'accepte plus que sa propre signature** — `rpm-ostree` dit
`ostree-image-signed` depuis le redémarrage de 16 h 44, et c'était la dernière
décision qui attendait l'utilisateur. **Android est reparti** après cinq jours
d'arrêt, et il ne sert plus sa mise en page de téléphone. **Constellation** a
gagné un ciel qui porte des fichiers, un clic droit, et une barre latérale de
neuf réglages — mais **rien de ce pan n'est encore dans l'image**.

**Et le mode de travail a changé sans que personne l'ait exercé.** Depuis le
2026-08-25, S se pilote de n'importe où par le tailnet — `tailscaled` est actif,
le Pixel est en ligne, `sshd.socket` écoute, `mosh` et `tmux` sont posés, et
`claude` vit dans `/usr/bin` de l'image. **Aucune session distante n'a jamais
servi**, et le relevé du 2026-08-26 au soir dit pourquoi : voir plus bas.

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

- ~~**La veille des fenêtres n'a jamais tourné dans une vraie session.**~~
  **Elle tourne depuis six heures et demie, et le gel tient sur une vraie
  fenêtre.** Le gel était déjà mesuré de bout en bout, mais contre une portée
  jetable — onze contrôles verts, `grimoire/veille-eprouver-le-gel.sh`,
  garde-fous compris. Le 27 août à 5 h 24, sur la machine, contre une fenêtre :
  Vivaldi, laissé de côté depuis 22 h 59, portait `cgroup.freeze = 1` et
  `cgroup.events: frozen 1` ; son `cpu.stat` affichait `usage_usec 7294535`,
  puis exactement `7294535` deux secondes plus tard — **pas une microseconde de
  processeur**, pendant que ses 276 Mo restaient en mémoire, ce qui est
  précisément le petit cache demandé. Au même instant les deux portées en
  service, `app-code-2613.scope` et `app-org.kde.konsole-6103.scope`, étaient à
  `freeze = 0` : la garde ne gèle que ce qu'elle doit, sur la vraie machine et
  plus seulement au banc. Et `coquille.log`, où va toute la sortie de
  Constellation, n'a pas reçu une ligne depuis le démarrage — aucun
  avertissement QML, aucune trace Python en six heures et demie de service.

  Une réserve, parce qu'elle change la portée de la preuve : ce Vivaldi-là ne
  portait plus qu'**un seul processus vivant**, sans moteur de rendu, et quatre
  zombies. C'est donc un vrai programme, pas un programme lourd. Le gel d'un
  navigateur à vingt onglets, d'un jeu ou d'une fenêtre Android reste à voir.
  Les zombies méritent d'ailleurs leur propre ligne : **un parent gelé ne peut
  pas récolter ses enfants**, donc chaque enfant qui meurt pendant le sommeil
  occupe un numéro de processus jusqu'au réveil. Sans conséquence ici, à
  surveiller sur un programme bavard laissé gelé des jours.

- ~~**Le menu du clic droit n'a toujours pas été ouvert.**~~ **Il ne s'ouvrait
  pas, et ce n'était pas le focus.** La revue du 27 août l'a mesuré hors écran
  avant qu'un seul clic ne soit donné : le menu portait bien ses neuf articles
  et en demandait 360 pixels, mais s'ouvrait à 52 — la hauteur de la fenêtre de
  la barre, qui borne tout `Popup` mis en page en elle. Un article visible sur
  neuf. ~~`popupType: Popup.Window` lui rend sa fenêtre à lui et sa vraie
  hauteur~~ — **c'était vrai et insuffisant, et c'est l'utilisateur qui l'a vu
  le premier : « elle apparaît totalement à gauche de l'écran ».** La hauteur
  était bonne, l'abscisse perdue. Corrigé autrement, et mesuré cette fois avant
  d'être poussé : voir la section de 15 h 30.
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
- ~~**L'image de S n'est ni signée ni vérifiée**~~ — **elle est signée depuis le
  2026-08-26 à 12 h 28, et la machine l'EXIGE depuis le redémarrage de 16 h 44.**
  `rpm-ostree status` dit `ostree-image-signed` sur le déploiement booté, et la
  politique active rejette une image que la clé de S ne signe pas. Voir la
  section de 16 h 46. Le texte d'origine, vrai le 2026-08-25 au soir :
  `ostree-unverified-registry`, aucune étape `cosign` dans le flux d'Actions, et
  `policy.json` faisait retomber `ghcr.io/gigigrenier86` sur
  `insecureAcceptAnything` alors qu'il vérifiait `ghcr.io/ublue-os` par sigstore.
- ~~**PURPLE ne s'ouvre plus dans aucun des deux rendus.**~~ **Il s'ouvre** —
  fenêtre `352x561`, **3198 couleurs**, logo et version lisibles, vivant à 70 s.
  Ce qui reste vrai est plus étroit : il **stagne sur son écran de démarrage**,
  sans erreur. Non expliqué. Voir la section de l'après-midi.
- ~~**Tout le pan Constellation du soir est hors de l'image.**~~ **Il y est,
  et c'est vérifié fichier par fichier.** `bootc upgrade` a été lancé à la main
  à 19 h 19, sous la politique qui exige — `Fetching ostree-image-signed:…`,
  21 couches, 2,8 Go — et la machine a redémarré sur ce déploiement à 19 h 23.
  Voir la section de 19 h 23.
- **`uupd` n'a toujours pas tourné sous la politique qui exige** — son dernier
  passage automatique date de 04 h 09, avant que la politique ne devienne
  stricte. Mais `bootc upgrade`, qui passe par le même `policy.json`, **vient
  de le faire pour de vrai** — pas à froid par `skopeo`. Voir la section de
  19 h 23.
- **L'accès distant n'a jamais servi, et le relevé du 2026-08-26 à 19 h dit où
  il coince.** Le tailnet est monté (`s` = `100.103.169.98`, le Pixel en ligne),
  `sshd` **répond bien sur l'adresse du tailnet** — mais il refuse :

  ```
  ssh RyuRex@100.103.169.98
      Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password)
  ```

  **Et j'ai d'abord mal dit pourquoi.** Ma première phrase était *« RyuRex n'a
  aucune clé »*. C'est faux, et l'utilisateur l'a relevé :

  ```
  ~/.ssh/id_ed25519      privee, creee le 2026-08-24 a 22 h 16
  ~/.ssh/id_ed25519.pub  SHA256:0R2G/lofJ9YhF0VUWP569THia2vewUp0bFHAIvZdsA8
                         RyuRex@S-M720q
  ```

  **Une clé pour SORTIR n'est pas une autorisation d'ENTRER, et ce sont deux
  fichiers différents.** `id_ed25519` prouve qui l'on est chez les autres —
  `known_hosts` porte `github.com`, c'est presque sûrement elle qui pousse ce
  dépôt. `authorized_keys` décide qui entre ici, **et lui n'existe pas**. Avoir
  la première ne donne rien pour la seconde.

  `100.103.169.98` **est déjà dans `known_hosts`**, ajouté le 2026-08-25 à
  21 h 56 : une entrée par le tailnet a donc déjà été tentée ce soir-là.

  Le mot de passe reste offert — mesuré, pas supposé — donc la voie n'est pas
  fermée, elle est seulement pénible au doigt. Les deux sorties sans mot de
  passe **demandent toutes deux l'utilisateur** : poser la clé publique du
  téléphone dans `authorized_keys`, ou ouvrir Tailscale SSH dans les ACL du
  tailnet. `RunSSH` vaut déjà `true` sur cette machine ; il manque le bloc côté
  console.

  Ce qui est en place et mesuré ce soir : `mosh` et `mosh-server` posés (un
  téléphone change de réseau et **chaque changement d'IP tue une session SSH** ;
  mosh y survit), `tmux` posé, `claude` **dans l'image** à `/usr/bin/claude`
  (2.1.231), et la zone `FedoraWorkstation` ouvre déjà l'UDP 1025-65535 dont
  mosh a besoin. **Rien de tout cela n'a été exercé depuis le téléphone.**

---

## 2026-08-28, 14 h 06 — le Voyeur trouve trois vrais défauts dans le correctif d'il y a une heure

Le correctif de 13 h 17 était poussé, construit, déployé — et l'utilisateur
l'a testé sur la vraie machine. Verdict : la barre latérale se ferme
maintenant (correctif de l'autre session), mais « les limites de zone
d'apparition… ont toujours la barre par dessus, en haut, en bas », le
calendrier ne fait rien, et « la date est pratiquement invisible et
incomplète ». Rôle Voyeur invoqué — aller photographier les fenêtres réelles
plutôt que deviner depuis le code.

### Ce que la capture et le journal ont montré, pas supposé

`grimoire/kwin-capturer-la-coquille.sh` sur les deux fenêtres réelles, et le
journal de la coquille lu en même temps :

```
file:///usr/share/s/constellation/qml/Barre.qml:669: ReferenceError: popup is not defined
```
— quatre fois, une par clic sur l'horloge testé par l'utilisateur.

**Trois défauts, trois causes distinctes, aucune n'était une supposition :**

1. **Le calendrier ne s'ouvrait jamais.** `popup(x, y)` copié du menu voisin
   (`menuEpinglee`) sans vérifier qu'il s'agit d'une méthode de **`Menu`**,
   pas de **`Popup`** — ma déclaration `Popup { id: calendrier }` n'a pas
   cette fonction. Chaque clic jetait une `ReferenceError`, jamais captée,
   jamais affichée : le clic semblait ne rien faire. Corrigé en posant `x`/`y`
   puis en appelant `open()`, l'API réelle de `Popup`.
2. **La colonne déployée couvrait toujours les deux coins.** Le correctif de
   13 h 17 n'avait borné que la *poignée* d'un pixel — ce qui déclenche
   l'ouverture. La *colonne visible*, elle (`colonne` dans
   `BarreLaterale.qml`), gardait `anchors.top/bottom: parent` — pleine
   hauteur, du premier au dernier pixel, même une fois déployée. Une capture
   de la fenêtre réelle le montrait sans ambiguïté : les icônes commencent à
   `y=0`. Corrigé en donnant à `colonne` les mêmes `margeHaut`/`margeBas` que
   la poignée — ce qu'on ne peut pas déclencher ne doit pas non plus s'y
   afficher.
3. **La date était réellement peu visible, et son format vraiment tronqué.**
   `Theme.texte3` (34 % d'opacité) à 9 px sur fond sombre — la lecture du
   code confirme le constat de l'utilisateur, ce n'était pas une impression.
   Et `nomsMois[...].substring(0, 3)` rendait « Aoû » au lieu d'« août » —
   tronqué sans y avoir été invité. Corrigé : `Theme.texte2` (62 %) à 10 px,
   mois en toutes lettres, jour de semaine ajouté (« ven. 28 août »).

### Un quatrième défaut, trouvé en corrigeant le troisième — pas cliqué, lu

`anchors.right: parent.right` posé sur les deux `Text` **enfants d'un
`Column`** ne fait rien : un `Column` positionne ses enfants lui-même, sans
avertissement s'il ignore une ancre. L'heure et la date, de largeurs
différentes, se seraient donc alignées à **gauche** l'une sous l'autre plutôt
qu'à droite, sous l'horloge existante — jamais vu à l'écran par l'utilisateur,
trouvé en relisant le code pendant la correction du problème de couleur.
Corrigé en donnant au `Column` une largeur explicite et en alignant chaque
`Text` par `horizontalAlignment: Text.AlignRight`, plutôt que de lutter
contre le positionnement du `Column`.

### Éprouvé, dans la mesure où l'outil de ce projet le permet

`verifier-constellation.py`, pointé sur le dépôt : « aucun avertissement »,
après les quatre correctifs. **Ce qu'il ne teste pas** : le pont de ce
contrôleur est un leurre, il n'exerce jamais `calendrier.open()` pour de vrai
ni ne clique sur l'horloge — la preuve que `popup()` plantait vient du
journal d'une vraie session, pas de cet outil, et c'est délibérément noté ici
pour ne pas laisser croire le contraire.

### Ce que cette passe ne prouve pas

- **Aucun des quatre correctifs n'a été cliqué pour de vrai** sur la machine
  après cette réparation — seule la version d'avant l'a été, et c'est elle
  qui a produit les trois plaintes traitées ici.
- **Les marges (48 px / 52 px) restent les mêmes valeurs non mesurées à
  l'écran** qu'à 13 h 17 — seule leur application à `colonne` est neuve, pas
  leur justesse.
- **Rien de tout ceci n'est dans l'image** — corrigé dans le dépôt, pas
  encore construit ni redémarré dessus.

---

## 2026-08-28, 13 h 17 — la barre latérale gagne ses vrais coins morts, et l'horloge un calendrier

Demande de l'utilisateur, capture d'écran à l'appui : « je veux que les deux
encadrés ne déclenchent PAS la barre latérale et dans celui du bas où il y a
l'heure, je veux voir la date tout le temps et un calendrier au clic gauche ».
La capture montrait deux coins entourés en rose — le coin haut-droit (où une
application pose d'ordinaire ses boutons de fenêtre) et le coin bas-droit
(où vit l'horloge de la barre des tâches).

### Le mécanisme du défaut, trouvé en lisant avant de corriger

La poignée de la barre latérale (1 px depuis le correctif du 2026-08-26)
avait `height: parent.height` — **toute la hauteur de l'écran**, du premier au
dernier pixel. Viser les boutons d'une fenêtre en haut à droite, ou l'horloge
en bas à droite, traversait donc cette colonne d'un pixel et ouvrait la barre
latérale sans le vouloir, puisque rien n'excluait ces deux coins.

**Corrigé par deux marges, jamais par un cas particulier** :
`margeHaut: 48` (l'espace où une fenêtre pose ses boutons — une convention de
bureau, pas une application précise) et `margeBas: 52` — **exactement** la
hauteur de `Barre.qml`, lue comme une constante nommée plutôt que recopiée à
l'œil, pour que les deux ne divergent jamais silencieusement. La poignée
QML **et** le masque `wl_region` côté Python (`bornerLaterale`, qui lit ces
deux marges comme il lit déjà `epaisseurLigne`) ont été corrigés ensemble —
un seul aurait laissé l'autre mentir.

### L'horloge : la date en permanence, et un calendrier écrit à la main

**`Qt.labs.calendar` n'existe pas sur cette image** — vérifié avant d'écrire
une ligne, `find /usr/lib64/qt6/qml -iname "*calendar*"` ne rend rien. Pas de
composant à réutiliser ; la grille du mois est donc écrite en QML/JS pur,
sur le patron déjà éprouvé de `menuEpinglee` — dessinée dans la fenêtre de la
barre, ouverte vers le haut, bornée par `pont.bornerBarre` (dont la
condition inclut maintenant `calendrier.visible`).

L'horloge devient une colonne de deux lignes — l'heure, puis la date en
plus petit, **toujours affichée**, pas seulement au survol. Un clic gauche
ouvre le calendrier : mois courant, aujourd'hui surligné, navigation par
flèches. Les noms de mois et de jours sont écrits en dur plutôt que confiés
à `Qt.formatDate` — ce projet a déjà payé des surprises de format ailleurs
(le pluriel de « jour » recopié à la main dans la veille des fenêtres), pas
la peine d'ouvrir la même porte ici.

### Éprouvé, dans les deux sens qui comptaient

Le premier essai du contrôleur de construction (`verifier-constellation.py`,
pointé sur le dépôt et non sur l'image) a **échoué**, et c'est exactement ce
qu'il existe pour faire : `QML Row: Cannot anchor to an item that isn't a
parent or sibling` — en enveloppant l'horloge dans une nouvelle colonne,
j'avais cassé un ancrage préexistant ailleurs dans le fichier (la liste des
fenêtres ouvertes, ancrée sur `horloge.left`, qui n'était plus une sœur
directe). Corrigé en ancrant sur la colonne (`horlogeEtDate.left`) plutôt
que sur l'élément qu'elle contient désormais. Rejoué : « aucun avertissement ».

Le calcul du calendrier vérifié contre le vrai calendrier de la machine
(`cal 8 2026`) : le 1er août 2026 tombe un samedi, ISO jour 6 — la formule
`(getDay() + 6) % 7` rend bien 5 (colonne « sa », zéro-indexée depuis lundi),
exactement ce que `cal` montre.

Syntaxe Python de `s-constellation` revérifiée (`py_compile` et `ast.parse`,
propres tous les deux).

### Ce que cette passe ne prouve pas

- **Aucun clic n'a été donné pour de vrai** — ni sur les deux coins qui ne
  doivent plus déclencher la barre, ni sur l'horloge, ni dans le calendrier.
  Le contrôleur prouve que la scène charge sans avertissement ; il ne prouve
  pas qu'un geste à l'écran fait ce qu'il promet — la même réserve que ce
  carnet répète depuis le début.
- **Rien de tout ceci n'est dans l'image.** Corrigé dans le dépôt, pas encore
  construit ni redémarré dessus.
- **Les marges (48 px en haut, 52 px en bas) sont un choix raisonné, pas
  mesuré à l'écran** — 52 correspond exactement à `Barre.qml`, 48 est une
  estimation de la hauteur habituelle des boutons de fenêtre, jamais vérifiée
  contre une vraie application maximisée.

---

## 2026-08-28, encore — mon propre correctif était faux, et c'était la même hypothèse les deux fois

Construit, publié, déployé, redémarré sur `aeb74e5` (groupé avec le
correctif de l'autre session, calendrier compris). L'utilisateur teste :
« rien n'a changé », pour les deux défauts de l'entrée précédente.

**Confirmé un par un, pas supposé :**
1. Sélection au glissement : « oui les icônes font comme tu dis » (grossissent,
   halo) — la sélection elle-même fonctionne. « Mais si je tente de
   déplacer, seulement celle que je déplace bouge » — le déplacement en
   bloc ne fonctionne pas.
2. Clic droit sur une étoile : « exactement les options du bureau, aucun
   changement » — `evenement.accepted = true` n'a rien changé.

**La cause commune, trouvée en relisant plutôt qu'en re-essayant à
l'aveugle :** l'hypothèse écrite dans le commentaire de `Constellation.qml`
depuis l'ajout du glissement de sélection — « les étoiles gardent la main »
— n'a jamais été mesurée, seulement supposée par analogie avec le clic
droit. Et le clic droit lui-même le dément déjà : `ciel.childAt()` n'existe
pas par magie, mais la logique de propagation des Pointer Handlers de Qt
Quick ne privilégie pas automatiquement le descendant. Un `TapHandler` (ou
un `DragHandler`) posé sur `ciel` et un autre posé sur une étoile —
descendante de `ciel` — écoutent tous les DEUX le même point dès qu'un
geste démarre sur cette étoile. `evenement.accepted` sur celui de l'étoile
ne préempte pas celui de `ciel`.

**Ce que ça coûtait, exactement, pour le glissement :**
`cadreGlissement.onActiveChanged` appelait `ciel.choisirDans(null)` au
DÉPART de tout glissement sur `ciel` — y compris un glissement démarré sur
une étoile déjà choisie, pour la déplacer. La sélection était donc vidée à
l'instant même où l'utilisateur commençait à déplacer le groupe ; par le
temps où `onDeplacee` lisait `choisi`, elle valait déjà `false`. L'étoile
glissée bougeait quand même (son propre `DragHandler`, `target: astre`,
n'a besoin de rien d'autre), ce qui explique exactement « seulement celle
que je déplace bouge ».

**Le correctif, sur le même patron pour les deux :** vérifier explicitement
avec `ciel.childAt(x, y)` ce qu'il y a sous le point de départ, plutôt que
de compter sur une consommation d'événement qui ne marche pas entre
ancêtre et descendant. Le clic droit du fond se tait si la cible est une
étoile (`cible.app !== undefined`). Le glissement de sélection gagne une
propriété `surUneEtoile`, posée une fois au départ du geste, qui fait
taire toute la logique de sélection (vider, dessiner le cadre, choisir à
l'arrivée) pour ce glissement-là.

Vérifié par le contrôle de construction : scène chargée, zéro
avertissement. **Toujours pas cliqué pour de vrai** — c'est un correctif
sur un correctif qui n'avait jamais été éprouvé à l'écran non plus, et la
leçon vaut d'être écrite : la première fois, j'ai conclu qu'« accepter »
l'événement suffisait sans le vérifier sur la machine. Ça ne suffisait pas.

---

## 2026-08-28, suite — le clic droit dupliqué, et la sélection qui ne servait à rien

Une autre session travaillait au même moment sur `Barre.qml` (calendrier),
`BarreLaterale.qml` et `s-constellation` (marges de la poignée) — convenu
avec l'utilisateur de la laisser terminer. Deux défauts distincts touchés
en attendant, aucun sur ces trois fichiers.

**1. Le clic droit sur une étoile et sur le fond ouvraient le même menu.**
Releve par l'utilisateur : « n'a pas de sens ». Cause, dans `Astre.qml` :
un `TapHandler` ne consomme pas un point par défaut — le clic droit sur une
étoile atteignait bien `menuContextuel` (via `astre.menuDemande`), mais
remontait ENSUITE au `TapHandler` du `ciel`, qui ouvrait `menuDuFond`
par-dessus. Corrigé par `evenement.accepted = true` dans le gestionnaire de
l'étoile — le piège classique des Pointer Handlers de Qt Quick, aucun des
deux handlers ne « sait » qu'un autre existe sans qu'on le dise.

**2. La sélection au glissement (posée hier soir) ne faisait rien.**
L'utilisateur : « fonctionne mais ne sert à rien, je ne peux même pas les
déplacer en bloc, ou faire supprimer le raccourci ». Deux ajouts dans
`Constellation.qml` :
- **Déplacement en bloc** — glisser une étoile CHOISIE déplace toutes les
  autres étoiles choisies du même delta, comparées par `app.id` (jamais par
  référence JS, qui ne survit pas à un `relire()`).
- **`Suppr` retire la sélection** — un fichier part à la corbeille, une
  application est retirée du bureau (jamais désinstallée : « effacer » un
  raccourci n'efface pas le logiciel).

« Fusionner » les étoiles reste explicitement hors chantier — l'utilisateur
l'a nommé comme une fonction future, pas pour ce soir.

Vérifié par le contrôle de construction : scène chargée, zéro
avertissement. **Rien de tout ceci n'a été cliqué pour de vrai, rien n'est
dans l'image** — en attente que l'autre session termine avant toute
construction.

---

## 2026-08-28 — la barre latérale trouvée coincée ouverte, sur la machine, en direct

L'utilisateur, sur la machine tout juste redémarrée sur `829fc03` : capture à
l'appui, « la petite fenêtre de réglages ne se ferme pas ». Rôle Voyeur.

**Le popup ouvert est la glissière de `BarreLaterale.qml`** (jauge de volume
90 %, ouverte par un clic sur l'étoile-réglage — `EtoileReglage.qml` :
`onTapped → glissiereDemandee()`, jamais par survol).

**La boucle fermée, lue dans le code avant tout correctif :** le minuteur
`fermeture` (500 ms) est la seule route de fermeture, et sa condition
testait `!glissiere.visible`. Rien dans ce fichier ne remettait
`glissiere.visible` à `false` de lui-même — seule l'ouverture du panneau
« choix » (mutuellement exclusif) ou `deploye = false` le faisait, et ce
dernier dépendait justement de ce test. Une fois une seule jauge cliquée,
plus aucun survol ne pouvait jamais refermer la barre.

**Corrigé :** la condition teste maintenant le SURVOL de la glissière et du
panneau « choix » (`survolGlissiere.hovered`, `survolChoix.hovered` — deux
`HoverHandler` jusque-là anonymes, nommés pour l'occasion), pas leur
visibilité. Éprouvé par le contrôle de construction sur cette machine :
scène chargée, zéro avertissement.

**Ce que ça ne prouve pas :** pas encore reconstruit, pas encore redéployé
— le correctif est dans le dépôt, pas encore sur la machine qui a le
défaut sous les yeux.

---

## 2026-08-27, soir — l'entretien reprend, et le clic droit avait un vrai trou

Demande de l'utilisateur : reprendre l'entretien de `TODO.md` (questions 11 à
40, en pause depuis dix réponses), puis « commence avec ce que tu as
maintenant » — construire à partir des réponses déjà données plutôt que
d'attendre la fin des trente questions.

### Ce que les réponses 15 et 16 ont pointé, et qui s'est confirmé en lisant le code avant d'y toucher

L'utilisateur : « le clic droit sur le bureau ou sur les icônes de la
constellation donnent le même résultat, rien de pratique, et aucun clic droit
ne fonctionne sur les apps épinglées en bas » — et, geste par geste :
sélection par glissement, clic droit contextuel sur une étoile (retirer,
placer, effacer, exécuter en root).

**`Barre.qml` n'avait effectivement AUCUN gestionnaire de clic droit sur les
icônes épinglées.** Comparé aux fenêtres ouvertes de la même barre, qui en ont
un depuis le 2026-08-26 (`menuFenetre`) : les épinglées n'avaient qu'un
`TapHandler` de clic gauche. Un vrai trou, pas une impression.

**Le menu contextuel des étoiles (`menuContextuel`, Constellation.qml), lui,
existait déjà et distinguait bien fichier / dossier / application posée ou
non** — ce que le code montrait n'était donc pas « le même résultat partout »
au sens littéral, mais il manquait un geste demandé : exécuter en root.

### Quatre pièces ajoutées

1. **`noyau.py` : `lancer_en_root(entree)`.** Relance la commande `Exec` d'une
   étoile via `pkexec`, encadrée par `timeout --foreground 120` — le même
   garde-fou que les neuf autres `pkexec` de S (`s_root` dans `s-monde`) :
   un blocage sans fin sur une fenêtre de polkit à laquelle personne ne
   répond ne doit jamais geler la coquille.
2. **`s-constellation` : le slot `lancerEnRoot`.** Sans objet pour un
   fichier — un fichier n'a pas de commande à relancer, seulement un ouvreur
   que le système choisit pour lui.
3. **`Constellation.qml` : deux ajouts.**
   - « Executer en root » dans `menuContextuel`, masqué pour un fichier.
   - **Le cadre de sélection au glissement**, sur le `ciel` : un
     `DragHandler` sans cible, posé sur le vide — la même règle que le clic
     droit du fond, deux poignées plus haut : « les étoiles gardent la
     main », leur propre `DragHandler` (Astre.qml) tient le point dès qu'un
     glissement commence SUR elles, donc celui-ci ne reçoit que les
     glissements partis du vide, exactement le comportement d'un bureau
     normal.
4. **`Barre.qml` : un vrai clic droit sur les épinglées.** Menu « Ouvrir /
   Executer en root / Retirer de la barre », posé sur le patron exact de
   `menuFenetre` — fenêtre séparée qui reste au-dessus, ouverte vers le haut,
   bornée par `pont.bornerBarre`. La fonction `borner()` compte désormais ce
   second menu dans sa condition, sinon il se serait ouvert sans se laisser
   cliquer, comme `menuFenetre` avant le 2026-08-26.

### La réponse 14 — « je préfère avoir le choix »

Ajouté `mode-android` dans `reglages.py`, sur le patron « choix » déjà
existant pour l'énergie. **Honnête sur son coût, pas seulement sur son
existence** : le carnet du 2026-08-25 a mesuré que
`persist.waydroid.multi_windows` ne prend qu'au PROCHAIN démarrage du
conteneur, jamais à chaud — le réglage arrête donc la session Android puis la
relance par `s-android`, et tout ce qui y tournait se ferme. Le réglage ne
s'affiche que si Android tourne déjà : pas d'état inventé quand la session
est éteinte.

### Éprouvé sur cette machine, avec le vrai contrôle de construction

`lancerEnRoot` a d'abord manqué au leurre du contrôle de construction
(`verifier-constellation.py`) — ajouté aussitôt, sinon la prochaine
construction aurait échoué : c'est exactement ce que ce contrôle existe pour
attraper. Rejoué ensuite pour de vrai, sur cette machine, avec le PySide6 de
l'image (6.11.1) et une vraie session Wayland :

```
scene verifiee : files/usr/share/s/constellation/qml
slots         : 23 au pont, tous declares par le leurre
pont fenetres : 8 appel(s) QML, tous declares sur Fenetres
menu barre    : 9 articles instancies, 9 attendus, 222 px ouverts pour 222 demandes
scene QML     : chargee, menu ouvert, aucun avertissement
ciel          : 5 etoiles instanciees, dont 3 jaunes
```

Le menu de la barre reste à 9 articles et 222 px : les changements de
`Barre.qml` n'ont rien fait régresser sur ce qui existait déjà. Syntaxe
Python des trois fichiers touchés vérifiée par `py_compile`, sans erreur.

### Ce que cette passe ne prouve pas

- **Aucun clic n'a été donné pour de vrai.** Le clic droit sur une épinglée,
  le cadre de sélection, « Executer en root », le réglage Android : le
  contrôle ci-dessus prouve que la scène charge et que le pont est complet —
  pas que le geste fait à l'écran ce qu'il promet. C'est la même réserve que
  ce carnet répète depuis le début : un contrôle hors écran n'a jamais valu
  un vrai clic de souris.
- **Rien de tout ceci n'est dans l'image.** Écrit dans le dépôt, pas
  construit, pas redémarré dessus.
- **`lancer_en_root` n'a jamais été exercé contre un vrai `.desktop` ni un
  vrai `pkexec`.** Le chemin suit celui des neuf autres gestes root de S,
  mais celui-ci est neuf et personne ne l'a vu réussir ou échouer en vrai.
- **Le redémarrage d'Android que `mode-android` déclenche n'a jamais été
  observé de bout en bout.** Le carnet du 25 août établit que le réglage ne
  prend qu'au prochain démarrage du conteneur ; personne n'a mesuré CE geste
  précis (arrêt, puis relance par `s-android`) sur la machine.
- **Les questions 18 à 40 de l'entretien restent en attente**, inchangées.

### Addendum, la nuit suivante — la construction demandée a d'abord échoué, et ce n'était pas le code

Demande de l'utilisateur : « construis et redémarre pour éprouver ça pour de
vrai ». Poussé (`34e6d00`), la construction GitHub Actions a échoué à
l'étape « Construire l'image ». Les journaux d'Actions restent inaccessibles
sans droits admin (403, comme ce carnet le documente déjà) — reconstruit
donc en local avec podman, la voie de diagnostic établie.

**Le vrai coupable, mesuré avant d'écrire une ligne :** `build_files/
40-coutures.sh` tire `F-Droid.apk` par `curl`, et le certificat TLS de
`f-droid.org` avait expiré à 01:08:57 UTC ce matin-là. L'horloge de la
machine est saine (NTP, vérifié par `timedatectl`) — ce n'est pas un défaut
d'ici. F-Droid répond derrière plusieurs nœuds dont la rotation du
certificat Let's Encrypt n'était pas encore propagée partout : deux requêtes
`curl` consécutives depuis cette machine ont rendu 200 puis « certificate
has expired », à quelques secondes d'écart, sur le même domaine.

**Et `--retry 3` ne protégeait pas contre ça, sans que personne s'en soit
aperçu avant ce soir.** La page de manuel de curl le dit noir sur blanc :
`--retry` ne rejoue que les pannes qu'il juge *transitoires* (délais, 5xx) —
un échec de vérification TLS n'en fait pas partie par défaut. Il fallait
`--retry-all-errors`, absent des deux appels `curl` de ce fichier depuis le
premier jour. Corrigé sur les deux — l'APK et sa signature détachée.

**Éprouvé en local, deux fois :** premier essai après le correctif, même
panne (le nœud tiré au hasard était encore mauvais) ; second essai, réussi
(`65bf9cae500e`), et l'image passe le même contrôle d'amorçabilité que le
CI (`waydroid-launcher`, `/usr/lib/modules` présents). **Le code du commit
`34e6d00` était donc bon** — seule la panne externe l'a fait échouer.

Un commit vide pour relancer la construction distante n'a rien déclenché :
**`paths-ignore` filtre aussi un push à zéro fichier changé**, une variante
du piège déjà noté le 2026-08-20 (« le premier push d'une branche neuve ne
déclenche rien », « un commit qui ne touche que la documentation n'a aucune
exécution de CI »). Sans jeton d'API pour rejouer le run directement
(`gh` absent, aucun jeton GitHub sur la machine), c'est le correctif
`--retry-all-errors` lui-même — un vrai changement, pas un prétexte — qui
sert de second déclencheur.

**Et ce second déclencheur a rerouté vers le même mur.** La construction
distante a échoué une seconde fois, toujours à « Construire l'image »,
toujours 7 minutes de podman avant l'échec — donc toujours tard, donc
probablement le même endroit. `--retry-all-errors` n'a pas suffi, et
mesurer pourquoi a changé le diagnostic du tout au tout.

**Neuf tentatives d'un seul appel `curl --retry`, toutes identiques.**
`curl --retry 8 --retry-all-errors` contre `f-droid.org` a échoué neuf fois
de suite, avec le même message, en onze secondes. Un seul processus curl
garde sa résolution DNS — ou sa connexion — pour toute la durée de ses
propres retries : retomber sur le même nœud à chaque fois n'a rien
d'étonnant, c'est le mécanisme même du retry intra-processus.

**`getent ahosts f-droid.org` a tranché la question au lieu de la deviner :
six adresses (trois v4, trois v6), sondées une à une avec `curl --resolve` :**

| Adresse | Résultat |
|---|---|
| `2a00:c6c0:0:153:3::1` | injoignable depuis cette machine (0 ms) |
| `2a00:c6c0:0:155:1::1` | injoignable depuis cette machine (0 ms) |
| `2a01:4f9:3b:546d::2` | injoignable depuis cette machine (0 ms) |
| `37.218.243.72` | certificat expiré |
| `37.218.247.73` | certificat expiré |
| `65.21.79.229` | **valide — et lent** : 12,4 Mo en deux minutes |

**Une boucle de vingt processus séparés — mieux, toujours un tirage au
sort.** Chaque nouveau `curl` force une résolution neuve, ce qui explique la
variation observée plus tôt (200 puis 60 sur deux appels consécutifs) — mais
avec un seul nœud bon sur six, dix-sept échecs de suite restent possibles
(0,83¹⁷ ≈ 5 %) et ont été mesurés en vrai dans la foulée.

**Le correctif retenu : énumérer, pas tirer au sort.** `telecharger_avec_
reprises()` liste les adresses avec `getent ahosts` et essaie chacune une
fois avec `curl --resolve` — les nœuds morts ou au certificat périmé
échouent en quelques secondes, et le nœud sain, s'il existe parmi les
adresses connues, est forcément atteint. Un piège de plus s'est révélé en
mesurant : un `--max-time` trop court (15 s, puis 90 s) coupait le nœud
sain **avant la fin d'un téléchargement simplement lent** — `--max-time 240`
lui laisse la place, sans rien changer pour les nœuds morts, qui échouent
de toute façon en une poignée de secondes.

**Éprouvé en local, la construction complète, avec le journal qui le dit
lui-même :** `f-droid.org : recupere via 65.21.79.229`, `F-Droid : 12426276
octets, signature verifiee`, image `96977631325b` construite et amorçable
(même contrôle que le CI). C'est ce correctif, et seulement lui, qui est
poussé vers la construction distante suivante.

**Et cette fois la construction distante a réussi.** Run `33146263475` :
les onze étapes vertes, y compris les deux signatures. Publié, vérifié
depuis cette machine avec `cosign verify --key /etc/pki/containers/s-os.pub`
avant même de proposer `bootc upgrade` — signature valide, digest
`sha256:2463fbc9…`.

**`sudo bootc upgrade` a d'abord semblé n'avoir rien fait** (« rien à
modifier », rapporté par l'utilisateur) — en réalité il avait déjà réussi la
première fois : `rpm-ostree status`, sans droits, montrait un déploiement en
attente portant exactement ce digest, `Diff: 1 upgraded`, pendant que la
machine tournait encore sur celui de la veille. Il ne restait que le
redémarrage.

**Éprouvé après coup, sur la machine redémarrée :** `rpm-ostree status`
confirme `44.20260828.829fc03` bootée (`●`) sur le digest signé.
`s-constellation` tourne (PID relevé), aucune unité en échec — système et
session. Les cinq fichiers touchés ce soir sont identiques, octet pour
octet, entre le dépôt et `/usr` : `Constellation.qml`, `Barre.qml`,
`noyau.py`, `reglages.py`, `s-constellation`. **C'est la première fois que
le clic droit des épinglées, « Executer en root », le cadre de sélection et
le réglage `mode-android` existent ailleurs que dans le dépôt.**

**Ce qui reste vrai malgré tout ça, et qu'il ne faut pas se mentir :**
aucun de ces gestes n'a encore été cliqué. La preuve ci-dessus est celle
d'un déploiement réussi, pas celle d'une souris qui a vraiment glissé sur
le ciel ou d'un clic droit qui a vraiment ouvert un menu sur une épinglée.
C'est à l'utilisateur de les essayer maintenant, sur la machine, pour de
vrai.

---

## 2026-08-27, 22 h 07 — PC Boost trouve fwupd, la vraie réponse Linux au « téléchargement de pilotes »

Demande de l'utilisateur, après redémarrage sur l'image du soir : « tu peux
implanter une détection matérielle, téléchargement de pilotes etc, je veux
que tout fonctionne, que ça soit sur S ou sur windows ». Rôle Wizard invoqué
à nouveau, modèle Opus.

### Chercher avant d'écrire : la question avait déjà une réponse, maintenue par l'amont

« Téléchargement de pilotes » sous Windows = Windows Update + Catalogue
Microsoft, ce que `DriverUpdateService` fait déjà. Sous Linux, l'équivalent
n'est pas à inventer : **`fwupd` est déjà dans l'image de S** (2.1.7, hérité
de Bazzite), et c'est le mécanisme que tout le bureau Linux utilise pour les
mises à jour de firmware — BIOS, contrôleurs, disques — via le LVFS (Linux
Vendor Firmware Service). Vérifié en direct sur cette machine :

```
fwupdmgr get-devices --json   -> 11 appareils reels : CPU, TPM, SSD WDC SN730,
                                  Management Engine, quatre regions SPI (BIOS,
                                  Gigabit Ethernet, IFD, ME)...
fwupdmgr get-updates          -> « UEFI firmware can not be updated in legacy
                                  BIOS mode » — la M720q demarre en BIOS
                                  legacy, pas en UEFI. Aucune mise a jour
                                  disponible actuellement — code retour 2.
```

**Une vraie trouvaille au passage, non cherchée :** cette machine démarre en
BIOS legacy, pas en UEFI — jamais noté nulle part dans ce carnet jusqu'ici.
Ça n'empêche rien (GRUB démarre très bien en legacy), mais ça explique
pourquoi le plugin `uefi_capsule` de fwupd, celui qui poserait un vrai BIOS
à jour, ne s'active pas ici.

### Pourquoi ce n'est PAS entré dans le pont matériel existant

Mesuré avant d'écrire une ligne : le même SSD porte `NVME\VEN_15B7&DEV_5006`
côté fwupd et `PCI\VEN_15B7&DEV_5006` côté `lspci` (le pont matériel de
16 h 20). **Deux identifiants différents pour le même disque, jamais le
même.** Forcer une correspondance entre les deux aurait été deviner, pas
mesurer — exactement l'erreur que ce carnet punit ailleurs. `fwupd` reste
donc un pont à part : `outils-linux/pilotes-linux.py`, écrit dans
`pilotes-linux.json`, jamais fondu dans `linux-materiel.json`.

### Ce qui a été forgé, en suivant le patron déjà éprouvé

- `outils-linux/pilotes-linux.py` — appelle `fwupdmgr get-devices` et
  `get-updates` en JSON, écrit un relevé propre. **Ne pose jamais rien** :
  `fwupdmgr update` écrirait un vrai firmware, potentiellement
  irréversible ; ce script lit, il n'installe jamais.
- `Models/Drivers/FirmwareReport.cs` — trois `record` neufs
  (`FirmwareDevice`, `FirmwareUpdateCandidate`, `FirmwareReport`).
- `Services/Drivers/IFirmwareUpdateService.cs` /
  `LinuxFirmwareUpdateService.cs` — lit le pont, rend `FwupdPresent=false`
  proprement si Wine n'est pas détecté ou si le fichier manque.
- `App.xaml.cs` — un service de plus, à côté de `IDriverUpdateService`,
  jamais fondu dedans pour la raison des identifiants ci-dessus.
- `s-pcboost-lancer` gagne un quatrième étage : régénère `pilotes-linux.json`
  à chaque lancement, même geste que le pont matériel.

### Éprouvé en direct, pas juste compilé

```
22:07:16  Environnement : Wine détecté — inventaire matériel via le pont Linux.
22:07:17  VERIF : FirmwareUpdateService = present=True, appareils=11, maj=0
```

**Le compte est identique à la mesure manuelle** — 11 appareils, 0 mise à
jour — faite quinze minutes plus tôt directement avec `fwupdmgr`. Le service
lit exactement ce que la machine sait, rien de plus, rien de moins.

### Ce que cette passe ne prouve pas, et c'est plus large que d'habitude

- **Aucune mise à jour n'a pu être proposée pour de vrai** — cette machine
  n'en a aucune disponible en ce moment. Le chemin « il y a une mise à jour,
  l'utilisateur clique, elle s'installe » reste **entièrement non éprouvé**,
  et il le restera tant qu'un appareil de cette machine n'aura pas de vraie
  mise à jour à proposer.
- **Aucune installation de firmware n'est câblée, et c'est voulu.** Ce pont
  ne fait que lire. Déclencher une vraie écriture de firmware depuis PC
  Boost — donc depuis Wine, vers `fwupdmgr update`, potentiellement avec
  authentification polkit — est un chantier à part, pas commencé, et qui
  mérite sa propre prudence : un firmware mal posé est plus difficile à
  défaire qu'un pilote Windows.
- **Aucun écran de PC Boost n'affiche ce relevé.** Le service existe et
  répond, aucune page ni `ViewModel` ne le consomme encore — même réserve
  que pour les trois services étendus à 16 h 33.
- **Rien de tout ceci n'entre dans une construction de S.**
- **Le dépôt PC Boost n'a reçu aucun commit.**

---

## 2026-08-27, 16 h 33 — l'extension du pont, et le verdict sur ce qui ne se porte pas

Demande de l'utilisateur : « on étend au max pour que TOUT fonctionne ! ».
Rôle du Wizard invoqué explicitement — lire chaque service avant d'y toucher,
plutôt que de deviner depuis les noms de fichiers.

### Sept fichiers touchent WMI. Trois valaient une extension, quatre non — et ce n'est pas un renoncement

Balayage complet : `HardwareInventoryService` (fait à 16 h 20),
`MachineContextService`, `MemoryTopologyService`, `WmiServiceManager`,
`DeviceDriverProbe`, `DeviceHealth`, `Shell/PowerShellRunner`. Chacun lu en
entier avant de décider — pas de correctif sur un nom de méthode deviné.

**Trois se portent, et se portent bien, parce qu'ils lisent un fait du
matériel :**

- **`MachineContextService`** — le type de châssis SMBIOS décide si la
  batterie compte. `/sys/class/dmi/id/chassis_type` porte le **même code**
  que `Win32_SystemEnclosure.ChassisTypes`, et se lit **sans droits root** —
  vérifié en même temps que le reste du DMI, qui lui les exige. La mémoire
  installée bascule sur `/proc/meminfo`, la même source que
  `materiel-linux.py` utilise déjà pour `SystemProfile` — une seule vérité,
  pas deux lectures qui pourraient un jour diverger.
- **`MemoryTopologyService`** — le détail par barrette (fabricant, vitesse,
  emplacement) vient de `Win32_PhysicalMemory`, dont l'équivalent Linux est
  `dmidecode`. **Mesuré sur cette machine : `dmidecode` échoue sans
  élévation** (`/sys/firmware/dmi/tables/smbios_entry_point: Permission
  denied`). Ce service **ne demande pas de mot de passe pour un relevé de
  diagnostic** — il rend `null`, proprement, avec une ligne de journal qui
  dit pourquoi, là où il jetait une `ManagementException` avant.
- **`WmiServiceManager`** — gère des services Windows (DiagTrack, SysMain,
  WSearch...) qui **n'existent tout simplement pas** sous Wine. Rien à
  ponter : le geste correct est de le dire clairement, une fois, plutôt que
  de laisser WMI échouer en silence à chaque appel.

**Quatre ne se portent pas, et il fallait le trancher plutôt que le
supposer :**

- **`DeviceDriverProbe` / `DeviceHealth`** — vérifient un pilote Windows
  avant/après une **installation** de pilote Windows. « Installer un pilote
  Windows » n'a pas de sens sur du matériel dont le vrai pilote est un module
  du noyau Linux (`i915`, `xhci_hcd`...). Ces deux fichiers restent
  inchangés : ils ne sont jamais atteints sous Wine, puisque rien n'y
  déclenche le flux d'installation qui les appelle — pas un défaut à
  corriger, une branche qui ne s'exécute pas parce que sa raison d'être ne
  s'applique pas ici.
- **`PowerShellRunner`** — cherché `powershell.exe` et `pwsh.exe` dans tout
  le préfixe Windows de S : **aucun des deux n'y est**. Un script PowerShell
  peut faire n'importe quoi ; il n'y a pas de « traduction Linux »
  générique à écrire pour un langage entier. Laissé tel quel.

### Le principe qui les sépare, dit en une phrase

Ce qui se porte est ce qui décrit un **fait du matériel ou du système**
(la mémoire installée, le type de châssis). Ce qui ne se porte pas est ce
qui décrit une **fonctionnalité de Windows lui-même** (ses services, ses
pilotes signés, PowerShell) — la faire « marcher sous Wine » reviendrait à
prétendre qu'elle existe là où elle n'existe pas.

### Éprouvé en direct, dans le vrai processus — pas seulement compilé

Un appel temporaire posé dans `App.xaml.cs` au démarrage, retiré aussitôt
après lecture du journal :

```
16:31:54  Traits de la machine : DoubleAmorcage
16:31:54  Peuplement mémoire : indisponible sous Wine sans élévation
          (dmidecode exige root) — non demandé automatiquement.
16:31:54  Services Windows (DiagTrack, SysMain...) : sans objet sous Wine
16:31:54  VERIF : MachineContextService.Traits = DoubleAmorcage
16:31:54  VERIF : MemoryTopologyService.ReadAsync = null
16:31:54  VERIF : WmiServiceManager.GetServicesAsync = 11 entree(s), presentes=0
```

**`DoubleAmorcage` sans `Autonomie`** : la M720q Tiny n'est pas classée
portable — juste, puisque c'est un mini-PC de bureau (châssis SMBIOS type
35, « Embedded PC »). Aucune exception dans le journal, les trois chemins de
code se comportent exactement comme prévu, en conditions réelles.

### Ce que cette passe ne prouve pas

- **Aucune interface n'a été regardée** — les trois vérifications passent
  par le journal, pas par un écran cliqué. Les pages Matériel, Réparation et
  Entretien de PC Boost n'ont pas été ouvertes à l'œil.
- **Le retrait du code de vérification n'a été revérifié que par une
  recompilation propre**, pas par un second lancement après coup.
- **Rien de tout ceci n'entre dans une construction de S**, comme le reste
  de PC Boost — projet personnel, hors dépôt.
- **Le dépôt PC Boost n'a reçu aucun commit** — l'utilisateur a dit attendre
  que le travail de l'autre session Claude soit terminé avant de tout
  pousser ensemble.

---

## 2026-08-27, 16 h 20 — PC Boost voit le vrai matériel, par un pont plutôt qu'un WMI muet

Demande de l'utilisateur : « ajoute à PC Boost les informations nécessaires à
la détection de drivers, matériel etc. de Linux, Wine etc. ».

### Ce que WMI vaut sous Wine, mesuré et non supposé

`HardwareInventoryService` (176 fichiers, une vraie application MVVM —
`Services/Hardware`, `Services/Drivers`, `Services/Health`...) interroge
`Win32_ComputerSystem`, `Win32_PnPEntity`, `Win32_PnPSignedDriver` par WMI.
**La preuve que ça ne suffit pas sous Wine était déjà dans le journal de
PC Boost avant que j'écrive une ligne** : `MemoryTopologyService`, un service
voisin qui n'a pas encore été touché, y jette
`ManagementException: Error code: 0x80041002` à chaque démarrage. WMI sous
Wine n'est pas un mensonge silencieux partout — parfois il échoue bruyamment,
et le reste du temps il répond des classes vides, ce qui est pire.

### Deux architectures essayées, une seule retenue — et la première a coûté une vraie mesure

**Essayée d'abord : demander à Wine de lancer un binaire Linux natif depuis
`Process.Start`.** Un petit programme de test, publié pour `win-x64` et lancé
dans le vrai préfixe de S, a montré que `/usr/bin/uname` **démarre bel et
bien** sous Wine — mais que `Process.WaitForExit()` échoue sur le descripteur
retourné (`COMException 0x80070006 E_HANDLE`), et que la sortie standard
redirigée reste **vide**. Wine sait lancer un exécutable Unix ; il ne rend pas
un objet processus .NET utilisable pour autant. Piste fermée par la mesure,
pas par supposition.

**Retenue : un pont à sens unique par fichier**, exactement le patron déjà
prouvé par `s-partage` et par `proton-capturer-environnement.sh` du Grimoire —
demander la vérité à sa vraie source plutôt que de la deviner depuis l'autre
côté de la frontière. Linux écrit un JSON avant que Windows démarre ; Windows
ne fait que le lire.

### La détection de Wine, deux sources indépendantes, les deux d'accord

```csharp
HKEY_LOCAL_MACHINE\Software\Wine        présente
ntdll.dll -> export "wine_get_version"  présent
```

Éprouvé dans un binaire de test dédié, dans le vrai préfixe : les deux
répondent oui en même temps. Aucun des deux n'a de raison d'être vrai sur un
Windows authentique — pas de garde-fou à moitié fiable ici.

### Le pont ne réinvente aucun type — il nourrit ceux qui existent déjà

`SystemProfile`, `HardwareDevice`, `HardwareInventory` sont déjà des
`record` sérialisables en JSON, et `PnpHardwareId.TryParse()` sait déjà lire
un Hardware ID au format Windows (`PCI\VEN_8086&DEV_3E92`). Le script Linux
**écrit dans ce format-là**, pas dans un format inventé :

```
lspci -vmmnnk   -> Slot, Class, Vendor [hex], Device [hex], Driver, Module
/sys/class/dmi/id/*  -> sys_vendor, product_name, board_*, bios_*
/sys/class/net/*/wireless  -> distingue Wi-Fi d'Ethernet, sans deviner sur le nom
```

Résultat mesuré sur cette machine (M720q) : **21 périphériques réels**, dont
« CoffeeLake-S GT2 [UHD Graphics 630] », pilote `i915`, catégorie `Gpu` —
plus précis que ce que WMI aurait jamais rendu ici, puisqu'il n'aurait rien
rendu du tout.

`outils-linux/materiel-linux.py`, dans le dépôt PC Boost lui-même (pas dans
S) : c'est la moitié Linux d'une fonctionnalité de PC Boost, elle voyage avec
lui.

### Côté C#, trois pièces neuves, une modifiée

- `Services/Platform/IEnvironmentDetectionService.cs` /
  `EnvironmentDetectionService.cs` — la détection Wine, un singleton, deux
  sources.
- `Services/Hardware/LinuxHardwareInventoryService.cs` — lit le JSON,
  désérialise dans les types existants
  (`Converters = { new JsonStringEnumConverter() }`, la même convention déjà
  posée dans `JsonSnapshotStore` et `JsonHardwareProfileStore` — pas une
  nouvelle inventée à côté). Un fichier absent ou illisible rend un
  inventaire vide et **journalisé**, jamais une exception qui remonterait
  jusqu'à l'interface.
- `App.xaml.cs` : `IHardwareInventoryService` se choisit maintenant à
  l'exécution — `LinuxHardwareInventoryService` si Wine est détecté,
  `HardwareInventoryService` (WMI) sinon. Une seule ligne de composition
  root à comprendre, aucune des deux ne sait que l'autre existe.

### `s-pcboost-lancer` gagne un troisième étage

Le pont se régénère à **chaque lancement**, juste avant de copier le build
dans le préfixe — dans `C:\users\steamuser\AppData\Local\PcBoost\hardware\`,
l'emplacement que `IAppPaths.HardwareDirectory` déclarait déjà, pas un chemin
inventé pour l'occasion. `steamuser` et non `RyuRex` : c'est umu/Proton qui
impose ce compte dans tout préfixe qu'il construit, pas un choix de S — vérifié
sur le disque avant d'écrire quoi que ce soit.

### Éprouvé de bout en bout, pas juste compilé

```
16:19:08  Démarrage — journal : ...\PcBoost\logs\pcboost-20260827.log
16:19:08  Environnement : Wine détecté — inventaire matériel via le pont Linux.
16:19:09  Historique : un relevé de moins de 24 h existe déjà, rien à archiver.
```

**La ligne qui compte est la deuxième** — écrite par PC Boost lui-même, dans
son propre journal, pas déduite de l'extérieur. Aucune exception de
désérialisation derrière elle : le JSON produit par le script Linux est bien
celui que `LinuxHardwareInventoryService` attendait.

### Ce que cette passe ne prouve pas

- **`MemoryTopologyService`, `MachineContextService`, et les services de
  pilotes** (`DeviceDriverProbe`, `DeviceHealth`, `WmiServiceManager`,
  `PnpUtilDriverStore`...) **interrogent toujours WMI directement**, sans
  passer par ce pont. Seul `HardwareInventoryService` — la page Matériel — en
  bénéficie pour l'instant. `MemoryTopologyService` jette d'ailleurs
  toujours son exception au démarrage, prouvée plus haut, non corrigée.
- **Aucun écran de PC Boost n'a été regardé** avec les données du pont
  affichées — seul le journal confirme que le service a été choisi et n'a
  pas planté. Ce que l'utilisateur verrait à l'écran (la page Matériel, la
  liste des 21 périphériques) n'a pas été capturé.
- **La recherche de pilotes via le Microsoft Update Catalog n'a pas été
  essayée** avec des Hardware IDs venus du pont — rien ne dit encore si
  `MicrosoftUpdateCatalogProvider` trouve des correspondances pour du
  matériel décrit depuis Linux plutôt que depuis un vrai Windows.
- **Rien de ceci n'entre dans une construction de S** — comme le reste de
  PC Boost, c'est un projet personnel hors dépôt.
- **Le dépôt PC Boost n'a reçu aucun commit** — les nouveaux fichiers
  s'ajoutent aux quatorze déjà modifiés, non commités, tels que l'utilisateur
  les avait laissés.

---

## 2026-08-27, 15 h 56 — le vrai PC Boost entre dans S, compilé depuis Linux

Demande de l'utilisateur, mot pour mot : « le dossier de PC Boost doit être
sur la Seagate, importe-le dans S et mets-le à jour, je vais l'inclure
nativement dans S-OS ».

### Ce qui tournait dans S depuis la veille n'était pas le vrai PC Boost

`~/Downloads/PcBoostApp` — la source utilisée hier soir pour le premier
lanceur — **n'était qu'un fragment de build**, sans dépôt, sans historique.
Le vrai projet vit sur la Seagate, dans le Windows cloné :

```
/var/mnt/windows/Users/Ghis/Desktop/Projet pc boost/
    .git/                    un vrai dépôt, aucun remote configuré
    PcBoostApp/               le code de PC Boost
    RapidO/                   LE CODE SOURCE ORIGINAL DE RAPIDO EST ICI AUSSI
    .agents/skills/           PC Boost a ses propres rôles Claude, comme S
```

**Branche `pilotes-controles-installation`, dernier commit le 20 août, et
QUATORZE fichiers modifiés jamais commités** — `PcBoostApp/` et `RapidO/`
mêlés. Le vrai travail en cours n'était donc ni dans le dernier commit ni dans
aucun des deux builds déjà présents sur la machine (Downloads, ou
`publish/PcBoostApp.exe` sur la Seagate) : il était dans l'arbre de travail
sale, jamais compilé nulle part.

**Aucun remote — c'est le seul exemplaire.** Copié, jamais déplacé : le geste
le plus prudent quand une seule copie porte du travail non sauvegardé.
Importé tel quel dans `~/Projets/PcBoost`, `.git` et fichiers modifiés
compris, `bin/`/`obj/` exclus (déjà 137 Mo sans eux).

### La compilation se fait sur Linux, jamais dans Wine

**`dotnet` n'était pas sur la machine** — la ligne du 2026-08-19 qui le disait
présent parlait de la machine de développement Windows, pas de S. Posé par
Homebrew (`brew install dotnet`, .NET 10, déjà en bouteille — aucune
compilation locale, quelques minutes).

**Compiler un exécutable Windows depuis Linux n'a rien d'exotique une fois
qu'on s'y tient : c'est du texte C# vers un binaire PE, aucune API Windows
n'est appelée pendant la compilation.** Un seul réglage à poser,
`-p:EnableWindowsTargeting=true` — un garde-fou que le SDK pose par défaut
sur un système non-Windows, pas un vrai obstacle technique :

```bash
dotnet publish PcBoostApp.csproj -c Release -r win-x64 \
    --self-contained true -p:EnableWindowsTargeting=true
```

**Réussi du premier coup**, avec les quatorze fichiers modifiés inclus — donc
le vrai code en cours d'écriture, pas un instantané d'il y a une semaine.
164 Mo, 247 fichiers, déployés dans le Windows de S, lancés, fenêtre
`steam_proton | PC Boost` vivante.

### `s-pcboost-lancer` gagne un étage : il recompile, pas seulement il resynchronise

Hier soir, le script comparait un build déjà là à la copie posée. Maintenant
qu'un vrai projet et un vrai compilateur sont disponibles, il compare le
**code source** au dernier build, et régénère celui-ci si besoin — deux
étages, pas un :

```
1. .cs / .xaml plus recents que le dernier build  -> dotnet publish
2. Build plus recent que la copie posee            -> recopie
```

**Les deux comparaisons portent sur des dates, jamais des hachages, et c'est
fiable pour la même raison qu'hier soir :** ni `dotnet publish` ni `cp` ne
préservent les dates d'origine — un objet regénéré porte toujours la date de
sa DERNIÈRE régénération. Une vraie modification est donc toujours plus
récente que le dernier geste qui l'a absorbée.

**Un échec de compilation ne doit jamais écraser le dernier build bon** — le
script avertit et relance l'ancienne version plutôt que de propager une copie
à moitié écrite. Ce n'est pas un vœu pieux : `dotnet publish` ne réécrit pas
sa sortie s'il échoue, comportement standard et documenté de MSBuild
(construction incrémentale) — la branche d'échec du script n'a donc rien à
défaire, elle n'a qu'à ne pas toucher à `$BUILD` ni `$CIBLE`.

**Éprouvé dans deux cas sur trois, le troisième raisonné et non mesuré :**

| Cas | Résultat |
|---|---|
| Rien n'a changé | ni recompilation ni resynchronisation — juste le lancement |
| Un `.cs` touché | recompilation reçue, notifiée, copie synchronisée, lancé |
| Échec de compilation | **non mesuré pour de vrai** — voir plus bas |

**Le troisième cas n'a pas abouti à une vraie mesure**, et il faut le dire
plutôt que le cacher. Une erreur syntaxique a été introduite dans le fichier
source réel pour le déclencher — geste risqué sur le seul exemplaire d'un
projet sans remote — et une commande a expiré (35 s) avant que le test ne
conclue. Le fichier a été **restauré et revérifié identique à sa sauvegarde**
avant toute autre chose ; mais un `dotnet publish` lancé en arrière-plan a
vraisemblablement lu le fichier déjà restauré, et le journal de compilation
ne montre qu'un succès. **Le chemin d'échec repose donc sur la lecture du
code et le comportement documenté de MSBuild, pas sur une exécution
observée.** Refait plus tard, sans toucher au vrai fichier — une copie
jetable du projet suffirait à le vérifier sans risque.

### Ce que cette passe ne prouve pas

- **Le chemin d'échec de compilation n'a pas été mesuré pour de vrai** — voir
  ci-dessus. C'est une hypothèse cohérente avec le code et le comportement
  documenté de MSBuild, pas une preuve.
- **Rien de tout ceci n'entre dans une construction de S.** `~/Projets/PcBoost`
  et `s-pcboost-lancer` vivent dans le dossier personnel, hors du dépôt et de
  l'image — exactement voulu pour l'instant, l'utilisateur ayant dit vouloir
  l'inclure « nativement » plus tard, pas immédiatement.
- **Le dépôt PC Boost garde ses quatorze fichiers non commités, tels quels.**
  Aucun commit n'a été fait en son nom — ce n'est pas à moi de décider quand
  ce travail est prêt à être figé dans son histoire.
- **Aucune fonction de PC Boost n'a été exercée au-delà du lancement** — la
  fenêtre s'ouvre et reste en vie, rien de plus.

---

## 2026-08-27, 15 h 37 — PC Boost se resynchronise tout seul avant chaque lancement

Dernière pièce de l'entretien du 2026-08-26 : « ben oui ça vaut la peine, je
veux que tout fonctionne bien ». La copie de PC Boost posée dans le Windows de
S se périmait à chaque recompilation, sans que rien ne le signale — l'exact
défaut nommé la veille en clôturant le premier chantier.

**Ce n'est pas une pièce de S : c'est un outil personnel, hors du dépôt.**
PC Boost n'a pas d'installateur et sa copie posée vit dans le prefixe d'un
seul utilisateur — ni le mécanisme ni son besoin ne concernent une machine
neuve. Il vit donc dans `~/.local/bin/s-pcboost-lancer`, jamais dans
`files/`.

### Le mécanisme, et pourquoi une comparaison de dates suffit

`s-pcboost-lancer` compare la date de `PcBoostApp.dll` — l'assembly compilé
depuis le C#, pas l'hôte natif `.exe` qui ne change presque jamais — entre le
dossier de build (`~/Downloads/PcBoostApp/bin/Release/net8.0-windows/win-x64`)
et la copie posée. Si la source est plus récente, il recopie l'arborescence
entière avant de lancer.

**`cp` ne préserve pas la date source, et c'est ce qui rend la comparaison
fiable plutôt que fragile.** La copie posée porte toujours la date de sa
DERNIÈRE synchronisation, jamais celle d'un ancien build. Un nouveau build est
donc toujours plus récent que la dernière synchronisation — sauf le jour où
rien n'a changé, exactement le cas qu'on veut détecter sans agir.

### UNE ERREUR TROUVÉE EN TESTANT, PAS EN RELISANT

Le premier essai a donné **l'inverse de ce qui était attendu** : sans aucun
changement source, le script annonçait quand même un resynchronisation. La
cause : `windows.sh` était sourcé **avant** `s-monde`, alors que
`S_WIN_PFX="$S_PREFIXE/pfx"` dépend d'une variable que seul `s-monde` pose.
Sans elle, `S_WIN_PFX` valait `/pfx` tout court — un chemin qui n'existe nulle
part, silencieusement pris pour argent comptant parce que `[ -n
"${S_WIN_PFX:-}" ]` le trouvait non vide et se déclarait satisfait. **Le test
de garde vérifiait que la variable existait, jamais qu'elle était juste.**

Ordre inversé, réessayé dans les deux sens sur la machine :

```
sans changement source     -> pas de resync        (attendu)
.dll source touché         -> resync, puis lancement -> synchronisé (attendu)
```

Puis le vrai geste, par `gtk-launch` sur le `.desktop` lui-même et non par un
appel manuel du script : fenêtre `steam_proton | PC Boost` vivante.

### Ce que cette passe ne prouve pas

- **Aucune vraie recompilation de PC Boost n'a déclenché ce mécanisme** —
  seul un `touch` sur le `.dll` l'a simulée. Le jour d'un vrai `dotnet
  publish`, à vérifier que le dossier `win-x64` reste le même et que le nom
  de l'assembly ne change pas.
- **Rien de ceci n'entre dans une construction** — c'est un fichier du dossier
  personnel, pas de l'image. Il n'a donc pas besoin d'un redémarrage pour
  servir, et n'en survivrait pas une réinstallation complète non plus.

---

## 2026-08-27, 16 h — le Wizard passe après la forge, et trouve les deux choses qu'on croyait savoir

Le correctif de 15 h 30 était posé et poussé. Le Wizard aurait dû passer avant ;
il est passé après. Il n'a pas remplacé la forge — **il l'a validée, et il a
retiré deux affirmations fausses du carnet.**

### Première affirmation fausse : la mienne, écrite il y a une heure

J'ai écrit à 15 h 30 qu'un menu à qui l'on donne sa propre fenêtre ne peut pas
être placé, et j'ai cité quatre mesures. Les quatre partageaient une variable
que je n'avais pas contrôlée : **la même intégration de shell Wayland**. Le banc
la fait varier, six valeurs, trois passages chacune, résultat identique :

```
(aucune variable)  ->  QRect(0, 0, 200, 360)       perdu
xdg-shell          ->  QRect(0, 0, 200, 360)       perdu
qt-shell           ->  QRect(600, 171, 200, 360)   placé
wl-shell           ->  QRect(600, 171, 200, 360)   placé
layer-shell        ->  QRect(0, 0, 1920, 1028)     perdu, et menu détruit
(nom inexistant)   ->  QRect(600, 171, 200, 360)   placé
```

Trois valeurs placent le popup exactement où on le demande. **Et ce sont
exactement les trois que kwin ne parle pas** — `qt-shell` est un protocole privé
de Qt, `wl-shell` est mort, et le nom inexistant ne charge rien du tout. La
capture le dit sans discussion : la fenêtre s'affiche alors **avec une barre de
titre dessinée côté client**. Elle « marche » parce qu'elle a cessé d'être une
fenêtre gérée par le compositeur.

Un banc qui n'aurait lu que le nombre aurait conclu l'inverse de la vérité et
fait remplacer un correctif juste par une variable d'environnement toxique.
C'est pourquoi le banc finit par une capture d'écran :
`grimoire/wayland-ou-se-pose-un-popup.sh`.

**Le correctif de 15 h 30 reste donc le bon**, et il est maintenant le meilleur
mesuré, pas seulement le seul essayé.

### Seconde affirmation fausse : celle du carnet, depuis le 2026-08-25

Le tableau des protocoles dit depuis trois jours que `zwlr_layer_shell_v1` est
présent « mais qu'aucune liaison Python de cette image ne sait le parler ».
C'est faux, et la faute est dans la question : **la route n'est pas Python,
elle est QML.**

```
layer-shell-qt-6.7.4-1.fc44.x86_64          installé, Fedora Project
/usr/lib64/qt6/qml/org/kde/layershell/      module QML, importable
/usr/lib64/qt6/plugins/wayland-shell-integration/liblayer-shell.so
kwin annonce zwlr_layer_shell_v1 v5, org_kde_plasma_shell v8
```

Le module expose un type **attaché** — `anchors`, `layer`, `margins`,
`exclusionZone`, `keyboardInteractivity`, `scope` — qui s'écrit directement sur
un `Window` QML. Aucune liaison à forger. La scène charge, l'import passe, et
avec `QT_WAYLAND_SHELL_INTEGRATION=layer-shell` la sonde **s'ancre bien en bas
de l'écran**.

### Et pourtant on ne l'adopte pas aujourd'hui — voilà la mesure qui le dit

Dans cette même configuration, le menu du clic droit est **détruit** : il rend
`QRect(0, 0, 1920, 1028)`, et la capture montre une dalle blanche qui couvre
presque tout l'écran. Échanger un menu qui marche contre de l'espace réservé
n'est pas un marché acceptable.

### L'hypothèse, nommée, avec ce qui la tuerait

**`org.kde.layershell` peut donner à la barre de S son espace réservé — une
fenêtre maximisée s'arrêterait enfin au-dessus d'elle — à condition de trouver
comment ses popups cohabitent avec une surface de couche.**

Ce que ça vaudrait : la barre n'aurait plus besoin de règle kwin pour se poser,
la barre latérale non plus, et la limitation écrite au sommet de `Barre.qml`
depuis le premier jour — « une fenêtre maximisée passe SOUS la barre » —
tomberait.

**La mesure qui tranche**, et elle tient en trois lignes : ouvrir la sonde
layer-shell avec `exclusionZone: 52`, puis lancer une fenêtre `showMaximized()`
et lire sa hauteur. Si elle vaut 1028 au lieu de 1080, l'espace est réservé. Le
relevé du 2026-08-27 donne **722**, un nombre qui ne correspond ni à l'un ni à
l'autre — donc la sonde ne mesurait pas ce qu'elle croyait, et c'est par là
qu'il faut reprendre.

Tant que ce n'est pas fait, `popupType` reste absent du dépôt et la barre garde
sa fenêtre haute et son masque.

## 2026-08-27, 15 h 30 — le menu s'ouvrait tout à gauche, et la réponse était déjà écrite dans ce dépôt

Correctif poussé ce matin : `popupType: Popup.Window`, pour que le menu du clic
droit cesse d'être écrasé à cinquante-deux pixels. **Il l'a essayé et il a
dit :** « la fenêtre apparaît à la bonne hauteur, mais pas en haut de l'onglet,
elle apparaît totalement à gauche de l'écran ».

La hauteur était réparée. L'abscisse ne l'était pas — elle était simplement
perdue.

### Ce que la mesure dit

Sonde lancée sur la session vivante, quatre façons de donner une abscisse à un
menu qui a sa propre fenêtre :

```
popup(x, y)                      ->  popup à QRect(0, 0, 200, 360)
m.x / m.y puis open()            ->  popup à QRect(0, 0, 200, 360)
popup(parent, x, y)              ->  popup à QRect(0, 0, 200, 360)
objet d'ancrage posé à x, open() ->  popup à QRect(0, 0, 200, 360)
```

On demande 600, on obtient 0, quatre fois sur quatre.

**C'est une loi que ce dépôt avait déjà rencontrée et déjà écrite**, dans
`bornerLaterale`, le 2026-08-25 : *un client Wayland ne se positionne pas
lui-même* — une fenêtre demandant `x=1516` s'était affichée au centre. La barre
latérale y a répondu en gardant une fenêtre qui ne bouge jamais et en
rétrécissant sa **zone sensible** avec `setMask`, qui part en
`wl_surface.set_input_region`. J'avais lu ce commentaire ; je ne l'avais pas
appliqué au menu.

### Le remède, qui est le même

La fenêtre de la barre monte maintenant à `52 + 420` pixels. La bande visible
s'ancre en bas ; le reste est du vide que le masque exclut, et le menu redevient
un `Popup` ordinaire dessiné **dans** cette fenêtre — là où nos coordonnées sont
exactes et où personne ne le replace. `pont.bornerBarre` pose la zone sensible :
la bande, plus le rectangle du menu quand il est ouvert, parce qu'un menu
dessiné hors du masque s'affiche sans se laisser cliquer.

Mesure sur la session, même montage :

```
demande x = 600     ->  menuX 600     exact
implicitHeight 360  ->  menuH 360     entier
```

Et vu à l'écran, capture à l'appui : les neuf articles au complet, posés juste
au-dessus de la bande, à l'abscisse demandée.

### Un garde-fou, parce que le remède a un tranchant

Sans masque, une fenêtre haute de 472 pixels posée au-dessus de tout avalerait
les clics sur tout le bas de l'écran — bien pire que le défaut réparé. Si le
pont manque, la fenêtre **reste** haute de cinquante-deux pixels : le menu s'y
trouve borné, ce qui est visible et réparable, au lieu d'un bureau qui ne répond
plus, qui ne l'est pas.

### Ce que j'aurais dû faire

Ce défaut-là n'a pas été trouvé par une revue ni par un banc : il a été trouvé
par l'utilisateur, à l'écran, après un redémarrage. Le vérificateur mesurait
bien la hauteur du menu depuis ce matin — **il ne mesurait pas son abscisse**,
et rien dans une scène hors écran ne l'aurait révélée, puisque le défaut naît
du compositeur. La leçon est la même que celle du 2026-08-25, et le dépôt
l'avait déjà écrite : quand une fenêtre doit se placer, il faut le mesurer sur
la machine avant de le pousser. Cette fois, ça l'a été.

## 2026-08-27, 5 h 40 — la revue trouve quatorze choses, dont une qui rendait le menu inutilisable

Le gel a été mesuré sur une vraie fenêtre ce matin (voir plus haut : Vivaldi,
zéro microseconde de processeur, 276 Mo gardés). Une revue systématique du
commit `7891d47` a suivi. Elle a rendu **quatorze constats, tous vérifiés dans
le code avant d'être retenus**, et tous corrigés dans la foulée — aucun ne
demandait de mot de passe.

### Celui qui comptait le plus, et que personne n'aurait vu en lisant

Le menu du clic droit **ne pouvait pas fonctionner**, et le vérificateur le
déclarait vert. Il comptait les articles — neuf, c'est juste — et ne mesurait
jamais s'ils étaient visibles. Mesure hors écran, Qt 6.11, même scène :

```
defaut (Popup.Item)   implicitHeight 360  ->  height  52     borné
Popup.Window          implicitHeight 360  ->  height 360     intact
```

Cinquante-deux pixels, c'est la hauteur de la fenêtre de la barre : un `Popup`
mis en page dans une fenêtre y est borné, point. **Un article visible sur
neuf.** Le repli envisagé hier — faire grandir la fenêtre de la barre vers le
haut — n'était pas nécessaire : `popupType: Popup.Window` donne au menu sa
propre fenêtre, donc sa vraie hauteur.

Un second défaut se cachait dans le même endroit : `ouvrirPour` calculait sa
position depuis `height`, qui vaut l'implicite avant la première ouverture et
la valeur bornée ensuite. Le menu se posait à deux hauteurs différentes selon
qu'on l'avait déjà ouvert ou non. Il se pose maintenant sur `implicitHeight` et
`implicitWidth`, qui ne dépendent pas de l'état d'ouverture.

**Le vérificateur mesure maintenant la hauteur**, et la preuve qu'il sait
échouer est faite dans les deux sens :

```
scène installée (l'ancienne)  ->  ÉCHEC : s'ouvre à 52 px, en demande 222
scène du dépôt (corrigée)     ->  9 articles, 222 px ouverts pour 222 demandés
```

### Trois défauts qui auraient balayé le bureau de l'utilisateur

`activer()` documentait un garde-fou — **un repli demandé à la main suspend la
veille d'une passe** — parce que ranger la fenêtre du dessus fait remonter la
suivante, et que la règle « une seule debout » se déclencherait sur cette
remontée. Le commentaire disait la chose exactement : « le geste *écarte-moi
ça* deviendrait *ferme-moi tout* ».

**`endormir()` et `fermer()` faisaient le même geste sans poser le jeton.**
« Endors-moi cette fenêtre-là » aurait rangé et arrêté tout le reste du bureau.
Les deux articles du menu neuf de la veille, les deux touchés.

Le jeton lui-même avait deux fuites. Il n'était consommé qu'après le test du
mode : un repli demandé pendant que la veille était coupée posait un jeton que
plus rien ne venait prendre, et c'est **le premier Alt+Tab réel d'après le
retour à « geler »** qu'il avalait — des heures après la cause, avec l'air de
ne marcher qu'une fois sur deux. Il est maintenant pris avant toute autre
sortie. Et il se posait sans savoir si le script kwin était parti : `_script`
rend Faux quand le bus manque, donc un rangement qui n'a jamais eu lieu
mangeait quand même la passe suivante.

### « Ranger les autres » laissait les programmes arrêtés pour toujours

`reglerMode()` ne dégelait que pour « aucune veille ». Or on choisit « ranger
les autres » **précisément pour que les programmes continuent de tourner** : un
lecteur de musique déjà gelé restait arrêté indéfiniment, et la raison même du
choix était retournée en silence. On dégèle désormais dès qu'on quitte
« geler ».

### La veille était aveugle à ce que la barre ne montre pas

La garde qui protège une portée partagée ne lisait que la liste de la barre —
d'où sont retirées les fenêtres non `normalWindow` et `skipTaskbar`. Un
programme dont la fenêtre principale est rangée mais qui garde un mini-lecteur
**à l'écran** partage pourtant sa portée cgroup : le gel figeait la surface
visible en pleine image, et comme `_reveiller` ne connaît que les fenêtres de
la barre, **aucun clic ne pouvait plus la dégeler** — il fallait relancer
Constellation.

Le rapporteur kwin envoie maintenant *toutes* les fenêtres avec une étiquette
`montrable`, et le tri se fait côté Python : la barre ne reçoit que le
montrable, la veille voit tout. Éprouvé au banc.

### Le balayage du démarrage relâchait ce qui ne lui appartenait pas

Il écrivait `0` dans `cgroup.freeze` de **toute** `app-*.scope` gelée trouvée
dans `app.slice`, en supposant que rien d'autre sur la machine n'en gèle. Ce
même commit brisait déjà l'hypothèse : le banc `veille-eprouver-le-gel.sh`
crée et gèle sa propre portée, et un Constellation qui redémarre pendant la
mesure la dégelait sous elle. Idem pour un `systemctl --user freeze` demandé à
la main. Le balayage tournait aussi quand le mode retenu était « aucune
veille ».

On ne défait plus que ce qu'on a **écrit** avoir fait :
`~/.local/state/s/fenetres-gelees.json`, réécrit à chaque gel et à chaque
dégel. Deux mesures au banc plutôt qu'une — *gelée par un autre → le démarrage
n'y touche pas*, *gelée par nous → le démarrage la relâche*.

Le banc lui-même dépayse maintenant son dossier d'état dans un dossier
temporaire : le construire écrasait le fichier de la vraie session en train de
tourner.

### Le reste

- `veille.portee()` appelait `int(pid)` hors de tout `try`. Le pid vient de
  kwin en JSON ; une chaîne ou un flottant faisait remonter le `ValueError`
  hors de la méthode D-Bus, **la liste des fenêtres cessait de se mettre à
  jour et la barre se figeait sur son dernier état**. L'en-tête du fichier
  posait pourtant le contrat : ce qu'on ne sait pas lire vaut « on ne sait
  pas ».
- Le menu gardait un instantané de `modelData`, remplacé en entier par
  `JSON.parse` à chaque nouvelle de kwin : tous ses libellés mentaient dès que
  la fenêtre changeait d'état pendant qu'il était ouvert. Il garde maintenant
  l'identifiant et relit la liste.
- Le compte des fenêtres oubliées se refaisait à **chaque changement de
  titre** — donc plusieurs fois par seconde pendant qu'on tape dans un
  terminal — pour une étiquette invisible tant que le menu est fermé. Il se
  demande à l'ouverture.
- Le vérificateur ne contrôlait qu'un des deux ponts QML. Les six slots ajoutés
  à `Fenetres` n'étaient vérifiés par rien, et une faute de frappe serait
  passée verte jusqu'au clic — l'échec exact que ce contrôle reproche à son
  absence. Un second contrôle compare les appels `fenetres.machin(...)` écrits
  dans le QML aux `@Slot` déclarés : **8 appels, tous déclarés**.
- Le compte des articles du menu comparait avec `<` : le menu vide était
  attrapé, un article dupliqué passait à dix ou vingt sans signal. C'est `!=`.
- `fermerInactives(1)` annonçait « inactive depuis 1 **jours** », et recopiait
  en Python un pluriel que le QML compose déjà.
- Un champ `vu` était écrit sur disque et relu par personne, pendant qu'un
  commentaire envoyait le prochain lecteur le chercher.
- Une recette du grimoire était entrée non exécutable.

### Ce que le banc dit maintenant

**Dix-neuf contrôles, tous verts** — les onze d'hier, plus la surface visible
non montrée, les deux du balayage sélectif, le pid illisible, le passage
« geler » → « reduire », le jeton consommé en mode « aucune veille », le tri
montrable/non montrable, et le singulier de « 1 jour ».

## 2026-08-26, 23 h — une seule fenêtre debout, et les autres s'arrêtent pour de bon

**La demande, mot pour mot.** « Le changement de fenêtre active m'énerve un peu,
pas de clic droit fermer la fenêtre, quand tu veux changer tu vas au bureau
directement. Ce serait bien mieux si la première fenêtre descendait directement
en mode veille et que la deuxième ouvre direct, et qu'au nouveau changement la
2ᵉ passe en veille et vice versa, peu importe combien de fenêtres — économie
d'énergie max, seulement un petit cache pour ouverture rapide. Et mets une
option fermer toutes les fenêtres inactives depuis 10 jours. »

Trois choses dans une phrase : un geste qui manque, une règle de bureau, et une
économie d'énergie. La troisième est la seule qui demandait à chercher.

### Le mécanisme existait déjà dans le noyau, et il ne demande pas le mot de passe

C'était l'inconnue. « Mettre en veille » un programme veut dire l'ARRÊTER, pas
le réduire : une fenêtre réduite continue de tourner, de dessiner, de réveiller
le processeur. Le noyau sait faire exactement cela depuis Linux 5.2, et le
fichier est à portée de l'utilisateur — mesure du 2026-08-26 :

```
/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/
    app-code-3359.scope/cgroup.freeze
-rw-r--r--. 1 RyuRex RyuRex
```

**Il appartient à `RyuRex`.** C'est la délégation cgroup de systemd :
`user@1000.service` reçoit son sous-arbre, et l'utilisateur y écrit sans passer
par polkit. Ce détail décide de tout — un réglage de bureau qui réclamerait un
mot de passe serait mort d'avance sur une machine pilotée depuis un téléphone,
où personne ne peut répondre à la fenêtre de polkit.

**Le « petit cache pour ouverture rapide » n'était pas à écrire : c'est ce que
le gel EST.** Un programme gelé garde sa mémoire, ses fichiers ouverts, ses
connexions et sa fenêtre déjà dessinée. Le dégeler, c'est écrire un octet — il
repart à l'instruction suivante, sans rien recharger. Écrire un cache par-dessus
aurait été recopier ce que le noyau tient déjà.

### La règle de sûreté tient en une phrase, et c'est un relevé qui la donne

On ne gèle QUE les portées `app-*.scope` posées directement sous `app.slice`.
Rien d'autre. Ce n'est pas une précaution théorique — c'est ce que la machine
dit :

```
s-constellation   session-2.scope               pas sous app.slice  -> refusé
kwin_wayland      session-2.scope               pas sous app.slice  -> refusé
plasmashell       session-2.scope               pas sous app.slice  -> refusé
Xwayland          session-2.scope               pas sous app.slice  -> refusé
waydroid          system.slice/…                hors du sous-arbre  -> refusé
wineserver        app.slice/s-windows.service   c'est un .service   -> refusé
code, vivaldi     app.slice/app-*.scope                             -> ACCEPTÉ
```

**Les quatre pièces du bureau vivent dans la portée de SESSION, jamais dans
`app.slice`.** Geler le compositeur figerait l'écran entier sans que rien puisse
le dégeler, puisque le dégel viendrait d'un clic. C'est la panne qu'on ne peut
pas se permettre ici.

**La distinction `.scope` / `.service` n'est pas cosmétique.** `app.slice`
contient les deux : les portées sont les programmes que l'utilisateur a lancés,
les services sont l'infrastructure de sa session. Parmi eux, `s-windows.service`
porte le **wineserver** — le geler figerait d'un coup tous les programmes
Windows de la machine, y compris celui qu'on regarde.

**Et on remonte jusqu'à la portée, on ne gèle pas la feuille.** Konsole se range
dans `app-org.kde.konsole-28261.scope/main.scope` — un enfant. Le `cgroup.procs`
de la portée elle-même est VIDE. Un code qui aurait gelé le cgroup du processus
tel quel aurait figé `main.scope` en laissant le reste de l'application dehors.

### Deux pièges mesurés, et le second a fait échouer le banc avant d'être compris

**1. `/proc/PID/stat` annonce « S » pendant le gel.** Un processus gelé n'est ni
en `D` ni en `T` : le noyau le pose dans un piège de contrôle de tâche qui ne
change pas la lettre. Vérifier le gel en lisant `/proc` rend « ça n'a pas
marché » sur un gel parfaitement appliqué.

**2. `cgroup.freeze` et `cgroup.events` ne disent pas la même chose, et ne
répondent pas au même moment.**

```
cgroup.freeze   LA DEMANDE — vaut 1 dès que l'écriture est rendue
cgroup.events   L'ÉTAT      — « frozen 1 » quand les tâches sont arrêtées
```

Relevé du 2026-08-26, trois lectures d'affilée sur la même portée, dans cet
ordre : `cgroup.events` dit `frozen 0`, `cgroup.freeze` dit `1`, puis
`cgroup.events` relu dit `frozen 1`. Le décalage tient dans une fraction de
milliseconde — le temps qu'une tâche atteigne un point où elle peut s'arrêter —
mais il suffit à faire rendre FAUX à un contrôle écrit juste après la demande.
Le banc a rendu « ça n'a pas marché » sur un gel qui fonctionnait.

**Conséquence dans le code :** `gelee()` lit l'ÉTAT et sert à observer ; le
balayage de rattrapage lit la DEMANDE. Une tâche coincée dans un appel système
non interruptible pourrait garder `frozen 0` alors que la demande vaut 1 — s'en
remettre à l'état laisserait ce programme figé pour toujours, ce que ce balayage
existe précisément pour empêcher.

### Le trou que `atexit` ne bouche pas

Constellation dégèle ce qu'il a gelé en s'arrêtant proprement. **Tué net —
plantage, SIGKILL, fin de session brutale — il ne dégèle rien**, et les
programmes resteraient figés sans que rien à l'écran ne dise pourquoi.
L'utilisateur verrait des fenêtres mortes et n'aurait aucune raison de
soupçonner un fichier de cgroup.

Constellation balaie donc `app.slice` **à son démarrage** et relâche tout ce
qu'il trouve. Le balayage est sûr parce que rien d'autre sur cette machine
n'écrit dans ces fichiers : une portée gelée trouvée au démarrage est
forcément un reste de nous.

### On réagit au changement de fenêtre active, pas au clic sur la barre

C'est la différence entre un correctif et une règle. Alt+Tab, un clic sur une
fenêtre, un programme qui ouvre la sienne au démarrage : tous passent par
`windowActivated`, que le rapporteur kwin renvoie déjà. Brancher la veille sur
le clic de la barre l'aurait laissée muette dans les trois autres cas, et
l'utilisateur aurait vu une règle qui ne s'applique qu'une fois sur quatre.

**Une exception, et elle est nécessaire.** Ranger la fenêtre du dessus fait
remonter la suivante — c'est kwin qui choisit, pas nous. Sans exception, la
règle « une seule debout » se déclencherait sur cette remontée et rangerait tout
le reste : le geste « écarte-moi ça » deviendrait « ferme-moi tout ». Un repli
demandé à la main suspend donc la veille d'une passe.

### Ce que le gel coûte, et il faut le dire

**Un programme arrêté ne fait plus RIEN** : pas de musique, pas de
téléchargement, pas de compilation, pas de message reçu. C'est le sens de
« économie d'énergie max », et c'est aussi la raison des trois modes plutôt
qu'une bascule :

| mode | ce qu'il fait |
|---|---|
| `non` | l'ancien comportement, rien ne change |
| `reduire` | une seule fenêtre debout, les autres se rangent |
| **`geler`** | en plus, leur programme s'arrête — **défaut** |

Ils se règlent dans le menu du clic droit de la barre, là où on les voit agir.

### Le clic droit, qui n'existait pas

Il n'y avait **aucun** moyen de fermer une fenêtre depuis la barre : il fallait
la remonter, viser sa croix — et celle d'un programme Windows n'est pas au même
endroit que celle d'un programme Linux. Le menu porte maintenant : afficher ou
ranger, mettre en veille tout de suite, fermer la fenêtre, fermer les fenêtres
inactives, et les trois modes de veille.

**On dégèle avant de fermer, et c'est obligatoire.** `closeWindow()` envoie une
DEMANDE au programme : le compositeur ne détruit pas la fenêtre, il prie son
propriétaire de le faire. Un programme gelé ne reçoit rien et ne répond rien —
la fenêtre resterait à l'écran, et le geste aurait l'air cassé alors qu'il a
parfaitement fonctionné.

### Les dix jours

Le compte part de la **première fois qu'on a vu la fenêtre**, jamais de zéro :
une fenêtre ouverte il y a une minute n'a pas dix jours d'inactivité parce que
Constellation vient de démarrer. Les horodatages sont dans
`~/.local/state/s/fenetres-vues.json`, et ils survivent à un redémarrage du
bureau — `internalId` appartient à kwin, pas à nous.

**Le compte est dans l'étiquette du menu.** « Fermer les fenêtres inactives »
sans nombre demanderait à l'utilisateur de cliquer pour savoir ce qu'il
détruit. À zéro, l'article se grise au lieu de disparaître : son absence ne
dirait pas qu'il n'y a rien à fermer, elle dirait que la fonction n'existe pas.

### Le banc, et pourquoi il n'est pas à l'écran

`grimoire/veille-eprouver-le-gel.sh` — onze contrôles, deux secondes, aucune
fenêtre de l'utilisateur touchée. Il fabrique une portée jetable avec
`systemd-run`, invente une liste de fenêtres qui la désigne, et vérifie ce que
le noyau fait vraiment. Passage du 2026-08-26 : les onze verts, dont les cinq
garde-fous et le rattrapage après plantage.

**Éprouver à l'écran était impossible sans casser la session.**
`s-coquille` relance Constellation en boucle (`while true` avec témoin de
sortie) : on ne peut pas l'arrêter pour lui substituer la version du dépôt, la
coquille rouvre aussitôt celle de l'image et les deux se disputent le nom D-Bus
`org.s.Constellation`. Le faire quand même voudrait dire redémarrer la session
de l'utilisateur pendant qu'il travaille.

Le contrôle de construction a été étendu en compensation : il **ouvre** le menu
du clic droit et compte ses articles. Un `Repeater` à l'intérieur d'un `Menu`
charge sans une plainte même s'il n'instancie rien — un menu vide est un menu
valide. Sans ce contrôle, « fermer la fenêtre » aurait pu n'exister que dans le
fichier. Relevé : **9 articles instanciés**, sept plus deux traits.

Et ce contrôle a lui-même trouvé un piège : `contentData` rend une liste VIDE
sur un `Menu` pourtant peuplé — c'est la propriété par défaut, pas l'inventaire
des articles. Il faut lire `count`. La première version du contrôle aurait fait
échouer la construction pour un défaut inexistant.

### Ce qui reste une hypothèse, et il faut le dire

**Le menu s'ouvre-t-il VRAIMENT au-dessus de la barre ?** La barre porte
`Qt.WindowDoesNotAcceptFocus`, et un menu Qt Quick a besoin d'une prise sur le
pointeur. La scène charge sans un avertissement et les neuf articles
s'instancient hors écran, mais **le placement d'une fenêtre surgissante par le
compositeur ne se mesure pas hors écran**. C'est une hypothèse jusqu'au premier
clic droit sur la machine, après le prochain redémarrage.

Le menu s'ouvre explicitement vers le haut (`y = -height - 6`) plutôt que de
s'en remettre au rabattement automatique : la barre touche le bas de l'écran et
ne fait que cinquante-deux pixels.

## 2026-08-26, 21 h 45 — RapidO : `--class=` n'a jamais rien fait, et personne ne l'avait mesuré

Repris après un entretien avec l'utilisateur sur les priorités du projet — voir
`TODO.md`. RapidO est « son réel travail », donc la première chose à faire
était de vérifier qu'il tient vraiment, pas de le supposer.

**`--class=RapidO` et `StartupWMClass=RapidO`, présents depuis la création du
lanceur, n'ont jamais eu le moindre effet.** Mesuré deux fois sur la machine ce
soir — processus Vivaldi réutilisé, puis processus entièrement frais avec un
`--user-data-dir` isolé — la fenêtre porte toujours la même classe réelle,
calculée par Vivaldi lui-même à partir de l'URL, jamais celle du drapeau :

```
vivaldi --app=https://app.mews.com/           --class=RapidO   (déclaré)
    -> vraie classe : vivaldi-app.mews.com__-Default            (mesurée)
```

**Même mécanisme, même preuve, sur Gemini** — un second lanceur qui partage le
même patron — pour écarter l'hypothèse que ce soit propre à MEWS :

```
vivaldi --app=https://gemini.google.com/app   --class=Gemini   (déclaré)
    -> vraie classe : vivaldi-gemini.google.com__app-Default    (mesurée)
```

**C'est un succès silencieux dans sa forme la plus tranquille :** la fenêtre
s'ouvre, elle a l'air d'une application dédiée, rien ne dit que sa classe ment.
Ça ne cassait rien tant que rien dans S ne matchait par classe — vérifié,
aucune règle kwin ni aucun script de S ne cherchait « RapidO » — mais le jour
où une règle de positionnement ou un regroupement de barre des tâches en aurait
eu besoin, elle aurait échoué sans un mot.

**Corrigé dans les deux lanceurs** : `--class=` retiré (mort, trompeur pour qui
relit le code), `StartupWMClass` porte désormais la vraie valeur mesurée. Le
mécanisme de mesure — un script kwin qui liste les fenêtres et se sert du bus
comme témoin, puisqu'un script kwin ne rend rien à l'appelant — est au
Grimoire : `vivaldi-classe-reelle-app.sh`, réutilisable pour tout futur lanceur
`vivaldi --app=`.

**Ce que ça ne règle pas, et qui n'est pas un défaut de S :** en le relançant
pour le mesurer, RapidO affichait « Autoriser cet appareil ? » — MEWS demande
une autorisation de connexion que personne n'avait encore accordée sur cette
machine. C'est un geste de connexion normal, pas une panne ; à l'utilisateur de
le passer une fois.

### Ce que cette passe ne prouve pas

- **La formule de calcul de la classe** (`vivaldi-<hôte>__<segment>-<profil>`)
  n'est vérifiée que sur deux URL simples. Elle n'est pas fiable pour un chemin
  à plusieurs segments ou une requête — le Grimoire le dit explicitement, pas
  de fonction de calcul écrite, seulement l'outil de mesure.
- **Aucune règle kwin ni logique de barre des tâches n'utilise encore la
  nouvelle classe** — rien n'en avait besoin jusqu'ici, donc rien ne prouve que
  la correction change quoi que ce soit à l'usage, seulement qu'elle rend enfin
  vraie une valeur qui était fausse.
- **Rien de ceci n'est dans l'image** — corrigé dans le dépôt, pas encore
  construit ni redémarré dessus.

---

## 2026-08-26, 22 h — PC Boost entre dans le menu de S, pour la première fois

Priorité 2 de l'entretien (`TODO.md`). Contrairement à RapidO, PC Boost n'avait
**jamais** été posé comme logiciel Windows de S : compilé dans
`~/Downloads/PcBoostApp/bin/Release/net8.0-windows/win-x64/`, jamais copié dans
le Windows de S, jamais lancé par `s-ouvrir-exe`, aucune étoile, aucun lanceur.

**Pourquoi il n'était jamais entré dans le menu, et ce n'est pas un défaut de
`s-menu-windows` :** la moisson ne trouve que ce qu'un installateur a laissé —
un `.desktop` de `winemenubuilder` ou un `.lnk` du menu Démarrer. PC Boost n'a
pas d'installateur, c'est un binaire compilé posé à la main : rien à moissonner,
et c'était juste.

### Ce qui a été fait, en suivant le patron déjà posé pour Cursor et PURPLE

1. Le binaire autonome (163 Mo, .NET 8 self-contained) copié dans le Windows de
   S : `.../pfx/dosdevices/c:/Program Files/PcBoost/`.
2. Lancé par le vrai chemin — `s-ouvrir-exe`, pas un raccourci de circonstance —
   et vérifié en vie : `PcBoostApp.exe`, PID confirmé, fenêtre `steam_proton |
   PC Boost` mesurée par `vivaldi-classe-reelle-app.sh` (qui liste n'importe
   quelle fenêtre kwin, pas seulement celles de Vivaldi — son nom vient de sa
   première preuve, pas de sa portée).
3. Le lanceur posé par `poser_lanceur`, la même fonction que `s-menu-windows`
   utilise pour tout le reste — pas une réécriture à côté. Identifiant
   **`s-windows-cafb8de64966`**, calculé par le même hash SHA-256 du chemin
   résolu que porte chaque logiciel Windows de S.
4. ~~L'étoile posée dans le ciel par `s_placer_etoile`~~ **FAUX au moment
   d'écrire ces lignes — voir la correction ci-dessous.** L'étoile n'a été
   posée pour de vrai qu'après le redémarrage.

### UNE ERREUR À MOI, TROUVÉE APRÈS LE REDÉMARRAGE — ET C'EST LE MÊME PIÈGE QUE CE CARNET NOMME AILLEURS

`s_placer_etoile` a été appelée avec `s-windows-a9a1f2f55131` — **l'identifiant
de Cursor, pas celui de PC Boost.** La vérification qui a produit ce chiffre
était fausse : un `grep -B6 "Name=PC Boost"` sur plusieurs fichiers concaténés
par `cat` a fait déborder les six lignes de contexte du fichier *précédent*
dans le résultat, et j'ai lu la fin d'un autre lanceur comme si elle
appartenait à PC Boost. **Un contrôle qui mélange plusieurs fichiers sans dire
lequel ment.**

Conséquence, silencieuse jusqu'au redémarrage : `s_placer_etoile` a
simplement réécrit la position de Cursor sur elle-même — sans dégât, puisque
la position est déterministe pour un identifiant donné, mais **l'étoile de PC
Boost n'a jamais existé**. `placees.json` le confirmait : `None` pour
`s-windows-cafb8de64966`, une vraie position pour `s-windows-a9a1f2f55131`.

Trouvé en revérifiant CHAQUE affirmation après le redémarrage plutôt qu'en la
tenant pour acquise — exactement la règle 7 de ce carnet, appliquée à mon
propre travail de la soirée. Corrigé avec le bon identifiant, relu :
`{'x': 0.74, 'y': 0.69}` pour `s-windows-cafb8de64966`. **Ni le lanceur ni le
lancement du 2026-08-26 n'étaient faux** — seule l'étoile manquait.

**Icône : repli générique, et c'est attendu.** Le carnet le savait déjà depuis
le 2026-08-20 — le `.csproj` de PC Boost ne porte pas `<ApplicationIcon>`. Rien
de neuf à corriger ici.

### UN DÉFAUT TROUVÉ EN MESURANT, DANS LE GRIMOIRE POSÉ UNE HEURE PLUS TÔT

`vivaldi-classe-reelle-app.sh`, écrit pour RapidO, portait un identifiant
accentué — `témoin_log`. Sur cette machine, dans ce shell, `local` l'a refusé :
*« identifiant non valable »* — et la ligne suivante, une assignation à ce même
nom, a été **exécutée comme une commande** plutôt qu'affectée, parce que bash
ne l'a plus reconnue comme une variable. Renommé en `temoin_log`, ASCII pur,
réessayé : propre. **Un outil écrit une heure plus tôt a servi de banc
d'essai à lui-même**, et c'est la preuve que le Grimoire vaut d'être relu
après coup, pas seulement écrit une fois.

### Ce que cette passe ne prouve pas

- **PC Boost n'a été vérifié qu'au lancement.** Aucun de ses écrans n'a été
  cliqué, aucune de ses fonctions n'a été exercée — seule sa fenêtre existe et
  reste en vie.
- **Rien de ceci n'est dans l'image.** Le binaire vit dans le Windows de S sur
  cette machine précise ; une machine neuve ne l'aurait pas. Ce n'est pas un
  défaut à corriger — PC Boost est le logiciel personnel de l'utilisateur, en
  développement actif, pas un logiciel que S doit fournir d'avance.
- **La copie posée est figée à ce build.** Le jour où PC Boost est recompilé,
  le lanceur pointera sur un binaire périmé tant que personne ne recopie le
  nouveau par-dessus — aucun mécanisme de mise à jour automatique n'existe pour
  ce cas, contrairement aux logiciels posés par construction d'image.

---

## 2026-08-26, soir — Steam sur une Switch Lite : recherche pure, rien de mesuré

Hors du projet S — une console branchée à la machine le temps d'une soirée, pas
une couture de S. Consignée ici parce que le Wizard l'exige : une trouvaille
non éprouvée va au carnet, jamais au Grimoire, dont la règle d'entrée est une
`PREUVE:` datée qu'aucune de ces lignes ne porte. **Rien de ce qui suit n'a
tourné — ni sur cette Switch, ni ailleurs.**

### Ce qui est fermé, et pourquoi ça ne rouvrira pas de ce côté-ci

La Switch Lite porte la puce **Mariko**, sortie en septembre 2019. Deux voies
logicielles indépendantes sont mortes dessus, pour deux raisons différentes :

- **RCM / Fusée Gelée** — le bug qui permettait d'injecter un payload par USB
  vivait dans le BootROM du Tegra X1, gravé en usine, corrigé en silicium sur
  Mariko. Confirmé par SciresM, le mainteneur d'Atmosphère lui-même : « aucun
  exploit logiciel n'existe pour la Switch Lite ». [GBAtemp](https://gbatemp.net/threads/nintendo-switch-lite-exploit-is-it-possible-without-a-mod-chip.592310/)
- **Caffeine / Déjà Vu (WebKit du navigateur)** — un vrai exploit logiciel,
  sans RCM, qui a fait tourner du CFW sur des consoles patchées entre 2018 et
  2019. Colmaté par Nintendo au firmware **8.0.0**. La Switch Lite est sortie
  **après** ce patch : aucun exemplaire n'a jamais existé sur un firmware
  vulnérable. [switchbrew.org](https://switchbrew.org/wiki/Homebrew_Exploits)

Aucun successeur documenté à ces deux voies pour du matériel patché sur
firmware récent.

### Ce qui reste entrouvert — deux hypothèses nommées

1. **Le navigateur caché** (déroutement DNS via le portail captif,
   `045.055.142.122`, [Digital Trends](https://www.digitaltrends.com/gaming/how-to-use-hidden-nintendo-switch-browser/))
   reste accessible sur firmware stock, 20 minutes par session. **Hypothèse :**
   le client web de GeForce NOW s'y charge et fonctionne, ce qui donnerait du
   Steam en streaming sans rien souder. **La mesure qui la tuerait :** faire le
   tour DNS et naviguer vers `play.geforcenow.com` dans ce navigateur — jamais
   essayé.
2. **L'exploit userland de Gezine** (chercheur PS5, annoncé juillet 2026) tourne
   sur Switch 1 et 2, tout firmware, sans WebKit — mais reste **non publié**,
   sandboxé, sans accès noyau. **Hypothèse :** s'il est un jour publié, ça
   n'ira de toute façon pas jusqu'à un CFW complet. **La mesure :** surveiller
   sa publication — rien à essayer avant. [Wayayeo](https://wayayeo.org/nintendo-switch-2-modding-early-homebrew-and-hack-news/)

### Ce qui marche, mais coûte la console

**Modchip Picofly** (RP2040) — 6 à 15 $ la puce seule, 95 à 150 $ posé par un
professionnel, difficulté de soudure « milieu de l'échelle » sur la Lite.
[Wayayeo](https://wayayeo.org/hwfly-modchip-install-repair/) Jamais commandé,
jamais posé.

**Récupérer l'écran seul** (LCD + digitizer, contrôleur universel 4-50 $) pour
une machine Steam qui porte la coquille de la Switch — détruit la console comme
console, contourne le BootROM en l'excluant entièrement de la boucle. Jamais
tenté.

---

## 2026-08-26, 19 h 23 — la mise à jour signée est exercée pour de vrai, et le pan du soir est dans l'image

Relevé fait à la demande de l'utilisateur (« met toi à jour »), sur la machine,
vingt minutes après un redémarrage dont ce carnet n'avait encore rien dit.

### Ce que le journal du démarrage précédent raconte

```
19:19:56  sudo bootc upgrade
19:19:57  Fetching ostree-image-signed:docker://ghcr.io/gigigrenier86/s-os:latest
19:19:58  layers already present: 128; layers needed: 21 (2.8 GB)
19:21:54  Successfully imported image: ostree-image-signed:…
19:22:20  Created deployment; checkout=10.8s composefs=13.3s etc=1.1s
19:22:37  (redemarrage)
19:23:07  (nouveau demarrage, sur le deploiement neuf)
```

**C'est un `bootc upgrade` lancé à la main par l'utilisateur, et c'est la
première fois que ce chemin — pas `skopeo` à froid — passe sous la politique
qui exige une signature.** `rpm-ostree status` le confirme : le déploiement
booté porte `ostree-image-signed`, digest `c023642d…`, version
`44.20260826.58439d2`.

### Le pan Constellation du soir est dans l'image, vérifié fichier par fichier

Le carnet affirmait, dans la même respiration que ce démarrage n'avait pas
encore eu lieu, que « le ciel qui porte des fichiers, le clic droit et la
barre latérale » tournaient depuis le dépôt et non depuis l'image. **Faux
maintenant, et ça se vérifie sans supposer** : les onze fichiers touchés par
le commit `9da4454` sont **identiques, octet pour octet**, entre le dépôt et
`/usr` — `Constellation.qml`, `BarreLaterale.qml`, `EtoileReglage.qml`,
`Anneau.qml`, `Theme.qml`, `noyau.py`, `regles-kwin.py`, `reglages.py`,
`fenetres.js`, `s-constellation`.

Et `s-constellation` (PID 2352) tourne **sans aucune des variables de
détournement de développement** — `S_QML`, `S_NOYAU`, `S_BIN`, `S_LIB` sont
absentes de son environnement. Ce n'est plus la seconde Constellation lancée à
côté de la vraie que le carnet décrivait depuis le début de soirée : c'est la
vraie, et elle sert le pan du soir depuis `/usr`.

### L'état du reste, au même moment

| | |
|---|---|
| Unités en échec | **aucune**, système et session |
| `s-partage.service` | a relié le dossier partagé à 19 h 23 min 18 s, **onze secondes** après l'allumage |
| `tailscaled` | actif depuis le démarrage |
| Android | `STOPPED` — pas encore démarré sur ce boot |
| `HEAD` du dépôt (`3d27913`) | ne touche aucun fichier de code, seulement ce carnet — **rien n'attend une construction** |

### Ce que ça ne prouve pas

- **`uupd` lui-même n'a toujours pas tourné sous la politique qui exige** — son
  dernier passage automatique (04 h 09) précède le moment où elle est devenue
  stricte, et son prochain est à 04 h 01 cette nuit. `bootc upgrade` partage le
  même `policy.json`, mais ce n'est pas la même unité qui a été exercée.
  Cette nuit tranchera.
- **Aucun geste réel n'a été posé sur le ciel qui porte des fichiers, le clic
  droit ou la barre latérale depuis ce démarrage.** Le code tourne depuis
  l'image ; personne n'a encore cliqué dessus sur ce boot-ci.
- **Android n'a pas été redémarré** depuis le redémarrage de la machine.

---

## 2026-08-26, soir — le ciel porte des fichiers, le clic droit existe, et une barre s'ouvre au bord droit

Trois chantiers menés avec l'utilisateur devant l'écran, dans l'ordre qu'il a
fixé : les étoiles jaunes, le clic droit, la barre latérale. **Il a trouvé
quatre défauts que mes bancs n'ont pas vus, et il en a tué un que je croyais
avoir trouvé.**

### 1. Le ciel porte des fichiers, et c'est la règle inverse des applications

Une **application** ne monte au ciel que si on l'y pose — sinon un bureau de
cinquante-deux icônes n'est plus un bureau, c'est une liste. Un **fichier** y
est parce qu'il est dans le dossier. C'est la règle de tous les bureaux depuis
trente ans, et s'en écarter voudrait dire qu'un fichier déposé sur le bureau ne
s'y verrait pas.

Les deux cohabitent donc dans le même `Repeater`, et il a fallu une garde
explicite pour qu'un fichier **placé à la main** ne soit pas dessiné deux fois —
une fois par la boucle des positions, une fois par celle des fichiers.

**Un `.desktop` posé sur le bureau garde son monde et sa vraie icône.** Le
peindre en jaune avec une icône de document dirait le contraire de ce qu'il
est ; le carnet reproche déjà au menu d'avoir dit « le genre et jamais lequel ».

Le dossier se **demande** (`XDG_DESKTOP_DIR`), il ne se devine pas : `~/Bureau`
n'est vrai que parce que cette machine est en français.

### 2. LE DÉFAUT TROUVÉ EN CHEMIN VALAIT PLUS QUE LE CHANTIER

`chemin_icone()` ne cherchait que dans les sous-dossiers **`apps`**. Les icônes
d'un fichier vivent ailleurs — `mimetypes`, `places` — donc aucun fichier n'en
recevait. En corrigeant, une seconde disposition est apparue, **mesurée sur
cette machine** :

```
Adwaita, hicolor :  <theme>/<taille>/<categorie>/    16x16/mimetypes/…
breeze           :  <theme>/<categorie>/<taille>/    mimetypes/16/…
```

Le code ne connaissait que la première. **breeze est le thème de KDE**, donc
tout ce qu'il fournit était invisible. Mesuré avant/après sur les 76
applications du ciel :

| | icônes réelles |
|---|---|
| avant | 59 sur 76 — **77 %** |
| après | 68 sur 76 — **89 %** |

**Konsole, le Play Store, la Surveillance du système, le Centre d'aide et cinq
autres n'ont jamais eu leur icône dans Constellation.** Personne ne l'avait vu
parce qu'un glyphe générique fait illusion. Ce défaut n'a rien à voir avec les
fichiers ; il est sorti en travaillant à côté.

### 3. Le clic droit : on n'écrit aucun geste de fichier

KDE fait tout cela depuis vingt ans, et `kioclient` l'expose en ligne de
commande. Ce qui est écrit ici n'est que la couture.

| Geste | Qui travaille |
|---|---|
| Ouvrir | `kioclient exec` — il résout le type, l'application par défaut, les `.desktop` |
| **Propriétés** | **`kioclient openProperties`** — la vraie boîte de Dolphin |
| Mettre à la corbeille | `kioclient move … trash:/`, **jamais `rm`** |
| Compresser | `ark --add --changetofirstpath` |
| Terminal ici | `konsole --workdir` |
| Renommer, Créer | **écrits ici** — il n'existe pas de `kioclient rename` |

**La corbeille échoue sur `/tmp`**, et la branche d'échec l'a dit elle-même :
*« Impossible de trouver ou de créer un dossier de corbeille à cet
emplacement »*. Ce n'est pas un défaut — la spec freedesktop veut une corbeille
par volume, et un tmpfs n'en a pas. Sur `~`, éprouvé : le fichier part et se
retrouve dans `~/.local/share/Trash/files`.

Et le menu proposait **« Retirer du bureau » à un fichier**, ce qui ne veut rien
dire : pour lui, `placees` ne porte que sa POSITION, jamais sa présence. Le
geste l'aurait remis en grille en prétendant l'enlever.

### 4. La barre latérale : une seule fenêtre, et un masque

Demande de l'utilisateur, mot pour mot : *« une fine ligne qui fait toute la
hauteur de l'écran du côté droit, apparaissant (quand nous ne sommes pas en
train de jouer à un jeu par exemple) au contact de la souris avec le rebord »*.

**La fenêtre fait toujours 300 pixels de large et ne bouge jamais.** Un client
Wayland ne se positionne pas lui-même — mesure du 2026-08-25, une fenêtre
demandant `x=1516` s'est affichée au centre — donc une languette qui grandirait
devrait être replacée par kwin à chaque ouverture, et on la verrait sauter.

**Ce qui change, c'est sa zone SENSIBLE.** Mesuré sur le protocole,
`WAYLAND_DEBUG` à l'appui, dans les deux sens :

```
replié   ->  wl_region.add(295, 0, 5, 1080)      5 px recoivent la souris
deploye  ->  wl_region.add(0, 0, 300, 1080)      toute la fenetre
```

Sans ce masque, 300 pixels du bord droit avaleraient tous les clics — la colonne
où vivent les ascenseurs de toutes les fenêtres.

**La colonne visible ne fait que 76 px**, mais la fenêtre reste large : le nom
d'un réglage ne tient pas dans 76 px, il s'écrit donc **à gauche**. Une infobulle
Qt se poserait PAR-DESSUS la colonne qu'elle nomme — exactement le défaut
corrigé sur la barre des tâches le 2026-08-25.

**Neuf réglages, tous mesurés, aucun deviné :**

| Réglage | Outil | Relevé |
|---|---|---|
| Volume | `wpctl` | 100 %, non muet |
| **Luminosité** | **`ddcutil setvcp 10`** | 60/100, lisible sans root, **483 ms** |
| Contraste | `ddcutil setvcp 12` | 70/100 |
| Wi-Fi | `nmcli radio wifi` | activé |
| Tailnet | `tailscale status --json` | `Running`, 100.103.169.98 |
| Énergie | **`tuned-adm`** | `balanced-bazzite` |
| Android | `waydroid status` | `RUNNING` |
| Capturer, Verrouiller | `spectacle`, le geste de session | — |

**`powerprofilesctl` n'est PAS sur cette machine** — le chercher aurait donné un
réglage absent alors que la machine sait parfaitement changer de profil.
Bazzite emploie `tuned`.

Et **la luminosité par DDC/CI est la trouvaille** : un mini-PC de bureau n'a
aucun `backlight` dans `/sys`, donc `brightnessctl` n'y trouverait rien. C'est
le bus I2C du câble vidéo qui parle à l'écran, et le LG ULTRAGEAR répond.

**Les quatre couleurs de S sont tirées au sort à chaque ouverture.** Un réglage
n'appartient à aucun monde — c'est justement pourquoi sa couleur peut changer
sans mentir. Mesuré : 4 couleurs distinctes, **0 répétition voisine sur 3600
tirages**. Et l'anneau sert de jauge : le même cercle qui dit « posé et jamais
exercé » au ciel dit ici « soixante pour cent ».

### 5. LE MASQUE NE SE POSAIT JAMAIS, ET L'ERREUR ÉTAIT AVALÉE

L'utilisateur : *« le menu disparaît aussitôt que je tente de choisir »*.

La première version retrouvait la fenêtre une fois par `findChild` et gardait la
référence dans une fermeture. Sonde à l'appui :

```
RuntimeError: libshiboken: Internal C++ object
              (PySide6.QtGui.QWindow) already deleted.
```

**PySide6 se croit propriétaire d'un objet rendu par `findChild` et libère son
enveloppe dès le premier retour à la boucle.** Le masque n'était donc jamais
reposé : la barre restait sensible sur cinq pixels même déployée, la souris
n'entrait pas dans le panneau, son survol n'était jamais reçu — et le minuteur
de fermeture allait au bout.

**Et mon `except AttributeError: pass` avalait l'erreur en silence**, ce qui a
coûté la moitié du diagnostic. QML passe désormais la fenêtre en argument à
chaque appel : rien n'est gardé, rien ne peut être libéré sous nos pieds.

### 6. CE QUE L'UTILISATEUR A TROUVÉ, ET QUE MES BANCS N'ONT PAS VU

Quatre défauts en une soirée, tous à l'écran, aucun par relecture.

- **« Les étoiles restaient sous la barre, même épinglées. »** Un `DragHandler`
  écrit directement dans `x`/`y`, et une écriture **détruit la liaison** qu'elle
  remplace. Invisible tant qu'on mémorisait la position — le modèle rendait le
  même pixel. Le jour où un glissement ne mémorise rien (l'épinglage), l'étoile
  reste où la souris l'a lâchée.
- **« Plus du tout déplaçables. »** MA RÉGRESSION, introduite une heure plus tôt
  en corrigeant la précédente : je reposais la liaison **aussi** dans la branche
  qui enregistre, où `modelData` porte encore l'ANCIENNE position — l'étoile
  sautait en arrière à chaque lâcher.
- **« Beaucoup trop large. »** 320 px de panneau ; ramené à 76.
- **« Je vois presque plus rien. »** Luminosité **0** et contraste **0**, relevés
  par `ddcutil`. La molette réglait à l'aveugle : la valeur ne se relit qu'après
  près d'une seconde d'I2C, donc l'anneau montrait l'ancienne pendant qu'il
  tournait. **Le geste se rendait lui-même irréversible** — à zéro, la barre qui
  permettrait de remonter est invisible comme le reste. Plancher à 10 %, jauge
  qui répond tout de suite, et une glissière au clic avec un différé de 180 ms.

### 7. UNE HYPOTHÈSE QUE J'AVAIS ET QU'IL A TUÉE

J'avais relevé six positions dans `placees.json` qu'aucun geste n'expliquait, et
j'en avais conclu à un « glissement fantôme » émis à l'apparition de chaque
étoile. J'avais écrit le correctif ET un commentaire affirmant la mesure.

**« C'est moi qui ai glissé les étoiles. »**

Le correctif est parti, `Astre.qml` est redevenu identique à `HEAD`. *Un
commentaire qui affirme une mesure jamais faite est pire que pas de commentaire
du tout* — et sans sa phrase, il entrait dans le dépôt.

### 8. Deux contrôles neufs, qui attrapent ce qui n'échoue qu'au clic

- **Le contrôle de construction compte les étoiles.** « Aucun avertissement »
  n'est pas « quelque chose s'est dessiné » : la scène chargeait sans une
  plainte quand le pont ne rendait aucun fichier. Il compte désormais, et le
  leurre porte les trois cas — un dossier, un fichier, un fichier déjà placé
  (qui vérifie l'absence de doublon), plus un fichier épinglé depuis ailleurs
  qui ne doit PAS monter au ciel.
- **La concordance des slots.** Un slot présent au pont mais absent du leurre ne
  fait rien échouer : la scène charge, le menu s'ouvre, tout paraît sain — et
  l'appel meurt AU CLIC, chez l'utilisateur. **Sept gestes de fichiers étaient
  dans ce cas.** Éprouvé dans les deux sens : slot retiré → code 1 en le
  nommant, slot présent → code 0.

### 9. LE BLUETOOTH N'EXISTE PAS SOUS LINUX, ET CE N'EST PAS LINUX

L'utilisateur : *« sur Windows j'ai Bluetooth, mais il tend à être là, des fois
non »*. Relevé sur les **huit démarrages enregistrés** depuis le 25 août :

```
usb 1-14: device descriptor read/64, error -71     (x4)
usb 1-14: device not accepting address 9, error -71
usb usb1-port14: unable to enumerate USB device
```

La carte est une **Intel Wireless 8265/8275**, un combo Wi-Fi + Bluetooth dont
le Wi-Fi marche parfaitement en PCIe et dont **le Bluetooth passe par l'USB**.
`error -71` est `EPROTO` — une erreur de couche physique. Sur une carte M.2
combo, le Bluetooth emprunte les broches USB du connecteur : **contact
intermittent, carte mal serrée**. Ça colle avec « des fois oui, des fois non ».

**Ce qui n'est PAS prouvé :** que le port 14 *soit* le Bluetooth. C'est
l'hypothèse la plus probable — une M720q n'a pas quatorze ports externes — mais
rien ne l'établit. **La mesure qui trancherait est physique :** rouvrir la
machine, resserrer la carte M.2, et regarder si `lsusb` montre un `8087:`.

En attendant, **l'étoile Bluetooth ne se dessine pas du tout**. `_bluetooth()`
rend `None` — pas `False` — et la différence est tout le reste : « False »
voudrait dire « éteint, tu peux l'allumer » et poserait une étoile qui ne fait
rien. Le jour où la carte est resserrée, elle apparaît seule.

### 10. Mes propres fautes, écrites parce qu'elles reviennent

- **`kill` sur un motif a fauché mon shell TROIS FOIS** dans la soirée : ma
  ligne de commande contient le motif que je cherche. Le carnet le documente
  **cinq fois depuis le 20 août** et interdit `pgrep -f` pour ça. Forme employée
  ensuite : `awk` excluant `$$` et son parent.
- **Le contrôle de construction vise `/usr/share` par défaut**, ce qui est juste
  PENDANT la construction — `COPY files/ /` a déjà eu lieu — et faux à la main :
  il rend alors un verdict sur l'IMAGE et non sur le dépôt qu'on vient de
  modifier. Une heure perdue à comparer deux scènes différentes en les croyant
  identiques. Il annonce désormais le chemin qu'il vérifie.
- **Trois `s.replace()` sans `assert`**, dont aucun n'a matché : les sondes
  n'ont jamais été écrites et le banc a rendu un verdict sur du code non
  instrumenté.
- **Mon isolation de banc coupait aussi ce qui devait sortir.** Un faux
  `XDG_CONFIG_HOME` a envoyé la règle kwin dans un `kwinrulesrc` que kwin ne lit
  pas — le panneau s'affichait au centre de l'écran, et j'ai d'abord accusé le
  code. Et un `kioclient exec` lancé depuis ce banc a ouvert un VRAI Kate dans
  la session, qui a fini par déposer un fichier d'essai dans le vrai `~/Bureau`.
  *Un banc qui lance de vrais programmes n'est pas un banc isolé.*

### Ce que cette passe ne prouve pas

- **RIEN N'EST DANS L'IMAGE.** Tout a tourné depuis le dépôt, par `S_QML` et
  `S_NOYAU`, dans une seconde Constellation lancée à côté de la vraie. Il faut
  une construction et un `bootc upgrade`.
- **L'effacement pendant un jeu n'a jamais été exercé.** Le rapporteur de kwin
  envoie désormais `plein`, et la barre s'y abonne ; aucune fenêtre en plein
  écran n'a été ouverte pour le vérifier.
- **Le survol réel du bord n'a été mesuré qu'en forçant la propriété depuis
  Python.** Les captures montrent le résultat ; le geste, c'est l'utilisateur
  qui l'exerce.
- ~~**La glissière au clic vient d'être écrite et n'a pas été essayée.**~~
  **Essayée par l'utilisateur le 2026-08-26 au soir, elle fonctionne.**
  C'était la dernière pièce de ce pan que personne n'avait exercée.
- **`s-android` n'est pas appelé par la bascule Android** quand elle éteint :
  seul le démarrage passe par le geste de S, l'arrêt appelle `waydroid session
  stop` directement.
- **Aucun réglage n'a été exercé à distance**, alors que c'est désormais le
  mode de travail annoncé.

---

## 2026-08-26, 16 h 46 — la machine exige la signature de S, et le mot est enfin dans `rpm-ostree`

Le carnet se terminait, deux sections plus bas, sur une phrase précise :
*« Ce qui reste : le redémarrage. Tant qu'il n'a pas eu lieu, la politique
active est l'ancienne, `rpm-ostree status` dit encore
`ostree-unverified-registry` sur les trois déploiements, et `uupd` tirerait
toujours sans rien exiger à 4 h. »*

Le redémarrage a eu lieu à **16 h 44**. Les trois moitiés de cette phrase sont
tombées ensemble.

```
● ostree-image-signed:docker://ghcr.io/gigigrenier86/s-os:latest
       Digest : sha256:1a85013d…        Version : 44.20260826.2d1b55c

  ostree-unverified-registry:docker://…  <- le repli, deploye sous l'ancienne politique
       Digest : sha256:3308822c…        Version : 44.20260826.0fa3c09
```

**`ostree-image-signed`.** C'est la première fois que ce mot apparaît dans ce
projet, et il ne s'obtient pas en signant : il s'obtient en **exigeant**. Le
carnet distinguait les deux décisions depuis le 2026-08-25 ; la seconde est
prise.

### Éprouvé dans les deux sens, et cette fois sans policy de test

La vérification de l'après-midi passait par une politique écrite dans le
bloc-notes, avec `keyPath` remappé sur le déploiement en attente — nécessaire,
puisque la politique active était encore l'ancienne. **Plus rien de tel ici :
`skopeo` lit `/etc/containers/policy.json`, celui du système, celui qui gouverne
`uupd`.**

| | Ce que la machine répond |
|---|---|
| `1a85013d` — signée par la clé de S | `Copying blob` — **acceptée** |
| `3308822c` — non signée par elle | `cryptographic signature verification failed: invalid signature when validating ASN.1 encoded signature` — **rejetée** |
| `:latest` — ce que `uupd` tirera à 4 h | `Copying blob` — **passe** |

Le message du rejet mérite d'être lu : la vérification **a trouvé une
signature** — celle sans clé, par identité OIDC, qui reste publiée à côté de
l'image — et elle ne valide pas contre la clé publique de S. Ce n'est pas une
signature absente, c'est une signature qui n'est pas la bonne. C'est exactement
le comportement voulu.

Et la clé de l'image est celle du dépôt **au bit près** :
`26bb8579…` des deux côtés.

### Ce que ça change pour le repli, et il faut le dire

`3308822c` est l'image du rollback. **C'est aussi, mot pour mot, celle que le
sens 2 vient de rejeter.**

Le filet tient quand même, et pour une raison mesurée le 2026-08-25 à 19 h 49 :
un `bootc rollback` ne retélécharge rien — les deux arborescences sont déjà sur
le disque, en clair, et la manœuvre coûte huit secondes et zéro octet de réseau.
La politique gouverne le **tirage**, pas le retour.

**Ce qui n'est plus possible, en revanche, c'est de re-tirer cette image.** Une
machine neuve, ou celle-ci après un nettoyage du magasin, ne pourrait pas
l'installer. Ce n'est pas un incident : c'est le prix normal d'une politique qui
exige, et il vaut d'être écrit avant d'être découvert un jour où l'on compte
dessus.

### L'état de la session, relevé au même moment

| | |
|---|---|
| Unités en échec | **aucune**, système et session |
| `s-session.target` / `graphical-session.target` | **actives** toutes deux |
| `s-partage.service` | a lié le dossier partagé à **16:44:13** — treize secondes après l'allumage |
| Agent polkit | `polkit-kde-authentication-agent-1`, PID 2354 |
| Clavier | `ca` / `multix` — la disposition importée de Windows tient |
| `s-windows.service` | active, **`wineserver` vivant** |
| `uupd.timer` | actif, prochain passage **jeudi 04 h 00** — sous la nouvelle politique |

L'image bootée vient de `2d1b55c` ; l'écart avec `HEAD` (`cfb0f99`) ne porte que
sur ce carnet. **Tout le code du dépôt est dans l'image.**

### ET MON TÉMOIN A MENTI, DANS LA FAMILLE QUE CE CARNET COLLECTIONNE

Pour savoir si `s-partage` avait tourné, j'ai interrogé :

```
systemctl --user show s-partage.service -p Result -p ExecMainStatus
    Result=success
    ExecMainStatus=0
    ActiveState=inactive
```

J'en ai conclu qu'il avait tourné et fini. **`s-partage.service` n'est pas une
unité utilisateur** — elle vit dans `/usr/lib/systemd/system/`. Et
`systemctl --user show` d'une unité qui **n'existe pas** ne dit pas qu'elle
n'existe pas : il rend un objet par défaut, dont `Result=success` et
`ExecMainStatus=0`.

**Un témoin qui rend « succès » pour une chose absente est le succès silencieux
retourné vers l'outil de mesure.** Le journal, lui, disait `-- No entries --`,
et c'est cette contradiction qui a fait chercher plus loin. La forme sûre est
`systemctl --user cat`, qui répond franchement *« No files found »*, ou
`list-unit-files`, qui ne montre que ce qui existe.

C'est la même leçon que `pgrep -x` tronqué à quinze caractères et que
l'`ostree=` du noyau : **un témoin qui ne peut pas dire « je ne sais pas » ne
mesure rien.**

### Ce que cette passe ne prouve pas

- **`uupd` n'a pas encore tourné sous cette politique.** Le sens de sa mise à
  jour est prouvé à froid par `skopeo`, avec le même fichier de politique — mais
  le passage réel de 4 h n'a pas eu lieu. C'est la dernière chose à regarder,
  et elle se regarde toute seule demain matin.
- **Aucune image mal signée n'a jamais atteint cette machine par le chemin
  normal.** Le rejet est mesuré par `skopeo`, pas par un `bootc upgrade` qui
  aurait rencontré une vraie mauvaise image.
- **Le glitch d'affichage de Waydroid n'a pas été revu**, Android est `STOPPED`,
  et PURPLE n'a pas été rouvert depuis le redémarrage.

## 2026-08-26, 16 h — un cinquieme role : l'oeil qui regarde l'ecran avant que quiconque touche au code

Un brouillon trainait a la racine du depot, `Voyeur.md`, ecrit a la main. Il est
devenu `.claude/skills/voyeur/SKILL.md`, a cote des quatre autres — un `.md`
pose a la racine du dossier des roles ne s'invoque pas, il faut
`<nom>/SKILL.md` avec son en-tete `name:` / `description:`. Le brouillon est
sorti du depot une fois absorbe.

**Son declencheur est une phrase, pas un besoin technique :** « regarde je te
montre ». C'est le premier role qui s'arme sur ce que dit l'utilisateur plutot
que sur l'etat du code.

### Ce que le brouillon disait, et ce qui a ete corrige

Il ne connaissait que deux destinataires — le Wizard et l'Alchimiste — et il en
manquait donc la moitie. La table de repartition en couvre quatre : le Wizard
pour ce qu'il faut chercher ou dont l'origine ne se voit pas, l'Alchimiste pour
ce qui n'existe pas et qu'il faut forger, le Contremaitre pour ce que l'OS ou
l'image immuable barre, LePeintre pour ce qui est laid ou mal rendu.

Il faisait aussi du Voyeur le « chef d'orchestre », ce qui entre en collision
avec la regle 0 : l'ordre des roles est celui du travail, et le Wizard y passe
le premier parce que la faute qu'il evite se commet avant qu'on la voie.
**Tranche ainsi : le Voyeur est en amont des quatre, pas au-dessus.** Il
designe la cible ; le Wizard garde sa preseance des qu'il y a quelque chose a
chercher.

### La regle qu'il porte et que les autres n'ont pas

**Une capture est une affirmation sur le passe.** Elle prouve qu'une chose s'est
affichee, jamais *pourquoi*. Ce carnet en avait deja la preuve datee, plus haut,
sans l'avoir formulee comme une regle : un ecran montrait
`System.ComponentModel.Win32Exception (0x80004005): Success.` a
`HwndWrapper..ctor`, code 82. Le lire comme une regression de S etait faux — le
shell qui lancait le programme n'avait pas de `DISPLAY`, et ni le mot
« display » ni le mot « X11 » n'apparaissaient a l'ecran. **L'oeil avait raison
sur les pixels et tort sur la cause.**

D'ou l'obligation qui lui est faite : separer a voix haute *ce que je vois* de
*ce que j'en deduis*. Le premier est un fait, le second reste une hypothese tant
qu'une commande ne l'a pas confirmee — la meme regle que le Wizard, appliquee a
la source la moins verifiable de toutes.

Il herite aussi des deux pieges de `grimoire/kwin-capturer-la-coquille.sh`, car
il peut aller photographier lui-meme : la classe de fenetre de tout programme
Windows est `steam_proton` et jamais son nom, et `spectacle` prive de
`XDG_RUNTIME_DIR` ou de `WAYLAND_DISPLAY` n'ecrit rien en rendant 0.

### Et le chargement d'un role vient d'etre observe pour la premiere fois

Le 2026-08-25 au soir, ce carnet notait que **le chargement des quatre roles
n'etait toujours pas observe** — les fichiers existaient, rien ne prouvait
qu'ils entraient en session.

Le fichier `voyeur/SKILL.md` a ete ecrit a 16 h ; **Claude Code a annonce
`voyeur` parmi les competences disponibles dans la foulee, sans redemarrage de
session.** Le lien symbolique `~/.claude/skills -> S/.claude/skills` suffit donc
a rendre un role neuf invocable immediatement.

**Ce que cela ne prouve pas :** que les quatre autres soient charges en ce
moment. Un seul nom a ete annonce, celui qui venait d'apparaitre. La mesure qui
trancherait pour les cinq reste a faire, et elle est simple — ouvrir une session
neuve et regarder la liste complete.

### Ce que la regle 0 dit encore

Elle annonce « les quatre roles » et les nomme. Elle date, elle reste telle
quelle, et cette entree la remplace sur le compte : **ils sont cinq**. L'ordre
du travail, lui, ne change pas — on cherche avant de forger, on forge avant de
contourner, on contourne avant de peindre. Le Voyeur ne s'y insere pas : il ne
travaille pas, il regarde et il nomme.


## 2026-08-26, apres-midi — signer ne suffit pas a exiger, et Android mourait sur une redirection

Trois chantiers menes avec l'utilisateur devant la machine. Le premier a fait
tomber une phrase que ce carnet repetait depuis la veille ; les deux autres ont
sorti quatre defauts que seule l'execution pouvait montrer.

### 1. La signature sans cle ne peut PAS etre exigee, et le carnet promettait le contraire

Le carnet ecrivait : *« l'entree `ghcr.io/gigigrenier86` se pose dans
`policy.json` sur le patron exact de celle d'ublue-os »*. **Ce patron ne peut
pas marcher pour S**, et il a suffi de lire `policy.json` pour le voir :
ublue-os epingle des **cles publiques** (`keyPaths`). S est signe **sans cle**.
Il n'y a aucune cle a epingler.

La forme qui existe pour le sans-cle est `fulcio`, et la page de manuel de cette
machine tranche : *« Both `oidcIssuer` and **`subjectEmail`** are mandatory »*.
Or le certificat d'une identite GitHub Actions ne porte pas de courriel. Releve
par **deux sources independantes** — le JSON de `cosign` et `openssl` :

```
Subject         : (vide)
EmailAddresses  : None
URI             : https://github.com/gigigrenier86/s-os/.github/workflows/build.yml@refs/heads/main
```

**Et la machine l'a confirme, a froid, sans rien engager** — une policy de test
dans le bloc-notes, `skopeo copy --policy` :

```
Source image rejected: Required email "https://github.com/.../build.yml@refs/heads/main"
                       not found (got [])
```

`got []` : la liste est vide. Ce n'est plus une hypothese.

**C'EST POURQUOI L'AMONT SIGNE AVEC UNE CLE.** `/etc/pki/containers/ublue-os.pub`
n'est pas un archaisme : c'est la seule forme que `policy.json` sache verifier.
*On ne reimplemente pas ce que l'amont maintient* — et ici, on ne l'invente pas
non plus.

**Ce qui est fait :** la construction signe desormais **deux fois** — sans cle
pour l'audit humain (elle prouve le depot, le fichier de workflow, la branche et
le commit), et **avec une paire de cles** pour la machine. L'etape se saute
proprement tant que le secret n'est pas pose, pour ne pas faire rougir une
construction sur une clef absente. Et elle **compare la cle publique du depot a
celle que le secret produit** : sans ce controle, on signerait avec une cle
pendant que l'image en livre une autre, et la machine refuserait ses propres
mises a jour — une panne qui ne se verrait qu'au premier `bootc upgrade`.

`files/etc/containers/registries.d/gigigrenier86.yaml` entre aussi, sur le patron
exact d'ublue-os (verifie par `diff`, identique au nom pres) : **sans lui, la
verification ne trouve meme pas la signature**, qui est un objet publie a cote de
l'image et non dans son manifeste.

**`policy.json` n'a toujours pas ete touche, et c'est delibere.** Rendre la
signature LISIBLE et la rendre REQUISE sont deux decisions ; la seconde se prend
apres que la premiere ait ete vue fonctionner.

### 2. Android n'avait pas tourne depuis le 25 aout, et la cause n'etait pas Android

`android-init.log` appartenait a **root** depuis le 25 aout a 10 h 42 — pose par
un `pkexec` d'une version anterieure qui portait la redirection *a l'interieur*
de l'elevation. Le dossier, lui, restait a l'utilisateur : rien ne paraissait
anormal. Son contenu etait d'ailleurs la panne des cinq jours,
*« You must provide 'System OTA' and 'Vendor OTA' URLs »*.

**Bash evalue une redirection AVANT de lancer la commande.** Une redirection
refusee fait donc echouer la ligne entiere **sans que la commande ait tourne**,
et le `|| true` l'avale. Mesure :

```
/usr/bin/touch /tmp/temoin >> <journal non inscriptible>
code de retour : 1     ->  la commande N'A JAMAIS TOURNE
```

Pendant vingt-huit heures, `waydroid upgrade -o` et le reglage de mise en veille
n'ont donc jamais tourne, pendant que le geste affichait *« Application des
reglages a Android… »*. **Le succes silencieux dans sa forme la plus exacte.**

**Et le journal redevenait root apres chaque reparation.** Le coupable n'est pas
S : `waydroid shell` appelle `lxc-attach`, qui **chowne son propre `stdout`**
pour le donner au processus du conteneur — et quand ce stdout est un fichier
redirige, c'est le FICHIER qui change de proprietaire. Waydroid le sait a
moitie : `tools/helpers/lxc.py` releve le mode avant et le repose apres
(`os.chmod(sys.stdout.fileno(), perms)`). Il repose le **mode**, jamais le
**proprietaire**.

Deux correctifs, donc, et ils ne font pas double emploi :

- **`s_tee`** dans `s-monde` : un processus privilegie recoit un **tuyau**,
  jamais le descripteur du journal. `tee` est lance par le shell de
  l'utilisateur ; rien de ce qui se passe en root ne peut l'atteindre.
  Eprouve : le journal reste `RyuRex:RyuRex` apres un `waydroid shell` en root.
- **Une garde a l'ouverture de `s-monde`**, parce que **dix-neuf lignes** de ce
  depot ecrivent un journal sous `$S_ETAT` et que le legs est deja pose sur
  cette machine. Eprouvee dans les deux sens : un journal casse est repare et
  l'ancien garde a cote ; un journal sain garde **le meme inode**.

### 3. Le verrou du monde restait pris tant qu'Android tournait

`waydroid session start` est lance en arriere-plan et vit aussi longtemps que la
session. Il **heritait du descripteur 9**, celui que `flock` tient. Releve
pendant qu'Android tournait :

```
PID 9143  /usr/bin/python3 /usr/bin/waydroid session start   <- tient le 9
```

Un second geste attendait donc `flock -w 600` puis echouait, **sans un mot** —
c'est exactement ainsi qu'un `s-android` relance est reste bloque cet
apres-midi. C'est le defaut deja corrige pour `s-ouvrir-exe` le 2026-08-26,
*« le verrou tenait pendant toute la vie du programme »*, **reste entier de ce
cote-ci**. `9>&-` le ferme. Mesure apres correctif : **verrou libre alors
qu'Android tourne**, et un second geste le prend en **0 s**.

### 4. Android servait sa mise en page telephone — et ce n'etait ni la densite ni la taille

L'utilisateur, devant l'ecran : *« dans le menu de base, tout est trop gros »*.
L'accueil de YouTube servait **une** colonne, une vignette large de 1920 px par
ligne. La video, elle, jouait parfaitement.

**Deux hypotheses sont mortes avant la bonne**, et les ecrire ferme les pistes :

| Hypothese | Ce qui l'a tuee |
|---|---|
| La densite | Une vignette a 100 % de large fait 1920 px que la densite soit 140 ou 240 : elle ne change que le texte et les icones. **La capture le montrait** — barre du haut petite et nette, vignettes enormes |
| `ro.build.characteristics=tablet` | Posee, versee, confirmee par `getprop` — et YouTube n'en a tenu **aucun** compte |

**Ce qui decide est le qualificateur `long`.** AOSP classe un ecran dont le
rapport long/court atteint 1,75 comme LONG — un telephone en paysage. Isole en
ne changeant que ce qualificateur, a largeur quasi constante :

```
1920 x 1028   1,868   xlarge-long-      w2194dp   une colonne
1747 x 1028   1,699   xlarge-notlong-   w1996dp   TROIS colonnes
```

La taille de la fenetre se pose par `persist.waydroid.width/height`, **trouvees
dans la table des symboles** de `hwcomposer.waydroid.so`, a cote de
`choose_width_height(display*,int,int)`. Elle est **calculee et non codee en
dur** : 1747 ne vaut que pour un ecran 1920x1080. Et **la formule n'a qu'une
source** — elle vit dans `regles-kwin.py`, ou la coquille la lit deja pour
centrer cette meme fenetre.

**Trois pieges mesures en chemin, tous en faisant :**

1. **Une propriete `persist.` est gardee par Android dans SON magasin** et
   l'emporte sur `waydroid_base.prop`. Releve : le fichier portait 1747 et
   Android repondait 1700 **a la meme seconde**. Il faut donc aussi un
   `prop set` — c'est ce que `multi_windows` faisait deja, et le carnet notait
   qu'il marchait « par accident ».
2. **`waydroid prop` n'a PAS besoin de root.** Lance par `pkexec`, il repond
   *« WayDroid session is stopped »* alors qu'elle tourne : la session appartient
   a l'utilisateur, **root ne la voit pas**. Une elevation inutile est un mot de
   passe demande pour rien.
3. **kwin numerote ses comparaisons `0` sans importance, `1` EXACT,
   `2` SOUS-CHAINE, `3` regexp.** J'ai copie `1` depuis `COMMUN`, ou il est juste
   puisque `s-constellation` est une classe entiere. Ma regle cherchait donc une
   fenetre dont la classe vaut **exactement** `waydroid.`. Posee, lue par kwin,
   et ne matchant rien — la fenetre restait a `y=26` apres reconfigure et
   ouverture neuve. **C'est l'utilisateur qui a dit « la position ne tient
   pas »**, pas ma mesure.

**Et la position venait de lui aussi.** kwin ouvrait la fenetre en `86,26` — un
bas a 1054 alors que la barre de S commence a 1028. Il perdait vingt-six pixels,
c'est-a-dire **exactement la rangee de commandes de l'application**. La regle
force la POSITION seulement, jamais la taille : celle-ci appartient au
compositeur de Waydroid, a qui `s-android` l'a donnee.

Etat final, releve par kwin et **valide a l'ecran par l'utilisateur** :

```
waydroid.com.google.android.youtube | 86,0 1747x1028 | bas=1028
```

### 5. PURPLE s'ouvre et peint — le carnet avait tort

Le carnet portait, depuis le matin : *« PURPLE ne s'ouvre plus dans aucun des
deux rendus, sans une ligne de journal. Non explique, et pas etabli comme
regression. »* **Rien de cette phrase n'a survecu a l'essai.**

| Ce que le carnet dit | Ce que la machine repond |
|---|---|
| ne s'ouvre plus | fenetre `steam_proton \| PURPLE \| 352x561` |
| sans une ligne de journal | rien a journaliser : il ne plante pas |
| aucun processus a trente secondes | vivant a 30 s, a 70 s, et apres |
| fenetre noire (1 couleur) | **3198 couleurs**, logo et version 2.26.803.19 lisibles |

`DisableHWAcceleration=1` est bien pose : PURPLE tourne dans le rendu logiciel
que le carnet lui avait choisi le 25 aout, et **ce reglage tient**.

**Ce qui reste vrai, et c'est plus etroit :** il ne depasse pas son ecran de
demarrage. Il y stagne, passe de cinq processus a deux, sans erreur. Non
explique — un lanceur NCSoft qui attend probablement quelque chose du reseau.

**ET MES DEUX BANCS ONT MENTI, ENCORE.** C'est la sixieme et la septieme fois
que ce carnet l'ecrit :

- `pgrep -f '/wineserver$'` a declare le serveur resident **mort** alors qu'il
  tournait depuis 1 h 24. Le motif exige une ligne de commande qui FINIT par
  `/wineserver` ; le serveur porte `-f -p`. La regle du 26 aout au matin visait
  les `.exe` tronques a quinze caracteres — **elle vaut aussi pour tout ce qui
  prend des arguments.**
- Mon premier lancement, en `( ... ) &` depuis un shell de banc, a **tue
  PURPLE** avec le groupe de processus de son lanceur. Le carnet decrivait deja
  ce piege pour `wineserver` le 26 aout a l'aube ; je l'ai refait sur un autre
  programme. La forme sure est `setsid ... < /dev/null &`.

*Un banc qui ne peut pas echouer ne mesure rien* — et un banc qui tue ce qu'il
mesure mesure encore moins.

### Ce que cette passe ne prouve pas

- ~~**La signature par cle n'a jamais tourne.**~~ **Elle tourne.** L'utilisateur
  a genere la paire dans son terminal — la moitie privee n'est jamais passee
  par la session — et pose les deux secrets. Run sur `92754e2` : l'image
  `a96c6a1a` verifie *« The signatures were verified against the specified
  public key »*, code 0.
- ~~**`policy.json` n'est pas touche.**~~ **Il l'est, par
  `build_files/46-signature.sh`, et la chaine est eprouvee dans les deux sens
  AVANT redemarrage** — avec la politique exacte de l'image en attente,
  `keyPath` remappe sur le deploiement :

  ```
  1a85013d  signee par la cle   ->  « Copying blob »  = ACCEPTEE
  3308822c  non signee par elle ->  REJETEE
  ```

  ~~**Ce qui reste : le redemarrage.**~~ **Il a eu lieu a 16 h 44, et la chaine
  est eprouvee avec la politique REELLE du systeme** : l'image signee passe,
  l'image non signee par la cle est rejetee cryptographiquement, et `:latest`
  — ce que `uupd` tirera a 4 h — passe. `rpm-ostree status` dit desormais
  `ostree-image-signed`. Voir la section de 16 h 46.
- **La fenetre Android perd 173 pixels de largeur**, et l'utilisateur l'accepte
  pour l'instant. Le rapport 1,70 est un choix de marge sous le seuil de 1,75 ;
  **la valeur exacte du seuil n'a pas ete mesuree**, elle est lue dans AOSP.
- **Une seule application a ete jugee.** YouTube passe en trois colonnes ; rien
  ne dit ce que les trente-deux autres font de `notlong`.
- **Le glitch d'affichage de Waydroid n'a pas ete revu**, et PURPLE n'a pas ete
  rouvert.


---

## 2026-08-26, 07 h — la revue des quatre rôles : six défauts prouvés, cinq alertes tuées

Relecture complète du dépôt et de la machine avec les quatre rôles chargés,
consigne explicite : **des erreurs réelles ou des incohérences prouvées**, pas
des impressions. Ce qui suit est ce qui a survécu à sa propre vérification.

### 1. La machine tire toute seule, chaque nuit, une image que rien ne signe

Le carnet écrivait que l'absence de signature était *« une garantie absente,
pas un incident »*, et décrivait la mise à jour comme un geste. **Le geste est
automatique, et il n'était écrit nulle part.**

```
uupd.timer   actif   dernier passage 2026-08-26 04 h 09   prochain 04 h 06
journal      Fetching ostree-unverified-registry:ghcr.io/gigigrenier86/s-os:latest
```

`bootc-fetch-apply-updates.timer` est bien désactivé — c'est probablement ce
qui avait rassuré. Mais **`uupd`** d'Universal Blue fait le même travail, il est
actif, et `/etc/uupd/config.json` ne désactive que `distrobox` : le module
`system` tourne. Et `build.yml` republie `:latest` à **chaque poussée sur
`main`** plus une reconstruction quotidienne. La chaîne complète — je pousse,
`:latest` bouge, la machine l'installe pendant la nuit — n'était décrite dans
aucun fichier de ce dépôt.

**Ce qui est fait :** la construction **signe** désormais l'image, sans clé, par
l'identité OIDC du workflow (Sigstore/Rekor). Aucun secret à poser à la main —
c'est ce qui la rendait faisable sans intervention. On signe le **condensat**,
jamais l'étiquette.

**Ce qui n'est PAS fait, et c'est délibéré :** `policy.json` de la machine n'a
pas été touché. Signer et **exiger** la signature sont deux décisions ; la
seconde peut empêcher une mise à jour ou un démarrage. La vérification se fait
d'abord, à froid, sans rien engager :

```bash
cosign verify ghcr.io/gigigrenier86/s-os:latest \
  --certificate-identity-regexp '^https://github.com/gigigrenier86/s-os/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Le jour où elle répond, l'entrée `ghcr.io/gigigrenier86` se pose dans
`policy.json` sur le patron exact de celle d'ublue-os, et
`rpm-ostree status | grep -c ostree-unverified` doit tomber à **0**.

### 2. F-Droid entrait dans l'image sans vérification, et sa signature était publiée

`40-coutures.sh` faisait `curl` puis `test -s` — non vide, c'est tout. Vingt
lignes plus loin, `41-windows.sh` vérifie le sha512 de Proton et **sort en
échec**. Deux téléchargements, deux poids et mesures — et le commentaire du
premier affirmait que l'URL était *« vérifiable »* alors que rien ne la
vérifiait. **La provenance n'est pas la signature.**

F-Droid publie `F-Droid.apk.asc` (répond **200**) et documente ses empreintes.
La signature relue paquet par paquet porte l'émetteur
`802A9799016112346E1FEFF47A029E54DD5DCE7A` — **la sous-clé que F-Droid
documente**, sous la clé primaire `37D2C987…`. Deux sources indépendantes
concordent : sa page de documentation, et `keys.openpgp.org`.

La clé publique est **posée dans le dépôt** (`build_files/cles/f-droid.asc`),
pas téléchargée : une clé prise sur le même hôte que le fichier qu'elle valide
ne prouve rien de plus que l'hôte. `gpgv` fait la vérification — il ne fait que
ça, ne crée aucun trousseau, et vient de l'image de base.

**Éprouvé dans les deux sens** : signature valide → code 0 ; **un seul octet
changé dans l'APK** → code 1. Un contrôle qui ne sait pas échouer n'est pas un
contrôle.

### 3. Neuf `pkexec` pouvaient figer un geste pour toujours — `s_root`

Ce n'est pas une hypothèse : `s-android` est resté **trois minutes** sur sa
demande de mot de passe ce matin, pendant que l'utilisateur était ailleurs, et
il y serait encore. Le geste ne rend jamais la main, le verrou du monde reste
pris, une fenêtre polkit reste ouverte sur un écran que personne ne regarde, et
**rien ne le dit**.

La faille était dans **neuf appels, quatre gestes** — `s-android`,
`s-play-store`, `s-nettoyer`, `s-partage`. Elle se ferme donc une fois, dans
`s-monde` :

```bash
s_root <commande...>                 # 120 s par défaut
s_root --limite 900 <commande...>    # pour un travail légitimement long
```

`timeout --foreground`, et le premier plan n'est pas décoratif : sans lui, le
jour où `pkexec` n'a pas d'agent graphique et retombe sur une demande en clair,
lire le terminal depuis un autre groupe de processus lèverait `SIGTTIN`.

Un dépassement **se dit**, avec le nom de ce qui n'a pas été fait, et
l'appelant continue dégradé. **Mesuré** : `s_root --limite 3 /usr/bin/true` →
3 s, code **124**, notification, écran rendu.

Les limites ne sont pas uniformes, et c'est le point délicat : `waydroid init`
télécharge un gigaoctet, `rpm-ostree reset` travaille sur le disque. Une limite
courte y couperait un travail légitime. Elles sont donc à 3600 s et 900 s —
**ce qui borne le blocage sans le supprimer** pour ces deux-là.

### 4. Le code livré affirmait une mesure que la machine dément

`s-windows` et `windows.sh` portaient en commentaire *« PcBoostApp : matériel
6426, logiciel **17** »* comme justification du réglage par programme. Repris à
trente secondes, le rendu logiciel donne **8888 couleurs**, dont 3308 sur le
seul carré central. Les deux commentaires disent maintenant ce que la machine
dit, **et ce qu'ils n'établissent plus** : PURPLE garde sa justification, elle
n'a pas été réexaminée ; PcBoostApp l'a perdue.

### 5. La recette de capture ne marchait que depuis une session graphique

Trois défauts, tous vus en la faisant échouer, tous corrigés dans
`grimoire/kwin-capturer-la-coquille.sh` :

- **`XDG_RUNTIME_DIR` vide** → spectacle attend sans erreur et sans fichier.
  Trente secondes de silence.
- **`WAYLAND_DISPLAY` vide** → spectacle **avorte**. Et `DISPLAY=:0` ne le
  remplace pas : mesuré, il échoue quand même.
- **La classe de tous les programmes Windows est `steam_proton`** — c'est
  Proton qui la pose. Chercher par nom de programme ne rendait jamais rien.

Les deux variables **se déduisent** de `/run/user/<uid>` : la recette les
déduit au lieu de les exiger. Et elle accepte désormais le **titre** comme
second critère — `steam_proton` désigne le monde Windows, le titre désigne le
programme dedans. **Éprouvé depuis un shell nu**, sans affichage ni bus : la
coquille en 1920×1080, la barre en 1920×52, par son titre.

### 6. L'image ne pouvait pas dire de quel commit elle venait

Trouvé en vérifiant autre chose : le `:latest` publié portait

```
org.opencontainers.image.revision = 75cf7fe1...   <- n'existe pas dans S
org.opencontainers.image.created  = 2026-08-25T23:59:43Z
org.opencontainers.image.version  = 44.20260825
manifeste réellement construit le   2026-08-26 à 11 h 02 UTC
```

Le Containerfile ne pose **aucune** étiquette : elles viennent toutes de
Bazzite. `75cf7fe1` est un commit d'ublue-os, pas de S — vérifié,
`git cat-file` ne le connaît pas.

**Ce que ça coûtait, et ce n'est pas théorique :** le matin même, répondre à
*« est-ce que l'image porte bien ce que le dépôt contient ? »* a demandé de
comparer **75 fichiers un par un**. Une étiquette y répond en une commande. Et
`bootc status` affichait la même version `44.20260825` pour l'image démarrée
**et** pour celle de repli, alors que leurs condensats diffèrent.

La construction pose désormais `revision`, `source`, `created`, `title`, et une
version qui bouge : `44.<jour>.<commit court>`.

### 7. Les cinq alertes que la revue a tuées

Une alerte réfutée proprement ferme une piste. Elles valent d'être écrites :

| Ce que j'ai cru voir | Ce qui l'a tué |
|---|---|
| `set -e` absent de 11 scripts de construction | les 17 portent `set -euo pipefail` — je ne lisais que les 5 premières lignes |
| `s-logo` introuvable | c'est un **nom d'icône**, pas un binaire, et le PNG est dans l'image |
| `__pycache__` versionné | ignoré par `.gitignore` — présent dans l'arbre, absent du dépôt |
| Proton téléchargé sans contrôle | sha512 vérifié, avec sortie en échec |
| Liens morts dans le carnet | aucun, sur tous les liens de fichiers |

Et la dérive dépôt/image se limitait aux deux fichiers corrigés le matin même.

### Ce que cette revue a cassé, et ce qu'il a fallu pour le voir

La construction **#70 a échoué**, sur mes changements. Elle est morte à **426 s
sur les 517** d'une construction réussie — donc dans la dernière couche, celle
des coutures. Les journaux d'Actions répondent **403** sans droits admin, et
`gh` n'est pas sur la machine : le message d'erreur était hors d'atteinte.

Tout ce qui se vérifie sans lui a été vérifié, et **tout passait** : les onze
contrôles par motif rejoués un par un contre les fichiers réels, le bloc F-Droid
rejoué dans un conteneur Fedora, la clé bien présente dans le commit poussé,
aucun `.containerignore`. Quatre pistes mortes.

**Alors la machine a construit l'image elle-même.** `podman` est là — le
Containerfile dit encore *« elle n'a ni podman ni WSL »*, et ce n'est plus vrai.
Vingt et une couches plus tard, le message :

```
gpg: Fatal: can't create directory '/root/.gnupg': No such file or directory
ECHEC : build_files/cles/f-droid.asc ne porte pas la sous-cle attendue.
```

**`/root` est un lien vers `var/roothome`**, et `/var` est vide pendant la
construction d'une image ostree. `gpg` crée son dossier de travail au premier
appel qui en a besoin — `--show-keys` en a besoin, `--dearmor` non — et il n'y a
nulle part où le créer. Un outil innocent, une vérification juste, une image qui
ne se construit plus.

**Et la seconde ligne est un faux verdict de plus, le mien.** Mon `|| { echo
"ECHEC : ... ne porte pas la sous-clé attendue" }` attribuait à la clé
n'importe quel échec de la commande — y compris la mort de l'outil. Une branche
d'échec qui nomme UNE cause doit d'abord montrer ce qui s'est réellement passé.
La nouvelle version affiche la sortie de `gpgv` avant de conclure.

**Le correctif :** plus aucun appel à `gpg`. Le trousseau est posé en forme
**binaire** dans le dépôt — ce qui supprime le `--dearmor` — et `gpgv` suffit :
il ne fait que vérifier, avec le trousseau qu'on lui donne. `GNUPGHOME` est
malgré tout dérouté vers `/tmp`, monté en tmpfs pour ce `RUN`. Mesuré en
conteneur : signature bonne, empreinte confirmée **sur la sortie de `gpgv`
elle-même**, et `/root` comme `/var` restent intacts.

**Ce que ça change au-delà de ce défaut :** cette machine peut désormais
reproduire une construction entière en local, avec son journal complet, sans
dépendre d'Actions ni de droits qu'on n'a pas. Toute panne de construction se
diagnostique ici maintenant, en une passe, au lieu de neuf minutes par
hypothèse.

### La signature a demandé deux passes de plus, et la seconde était une jointure invisible

**Run #71** : image construite (472 s), publiée (443 s) — le correctif de F-Droid
tient, et la construction locale l'a confirmé de son côté. Les étiquettes sont
enfin justes sur l'image publiée :

```
revision = 30a85d38b73a71cc18f74d72336cfd05236336e7   <- un commit de S, enfin
version  = 44.20260826.30a85d3                        <- elle bouge
created  = 2026-08-26T12:28:50Z
```

Mais la **signature a échoué en cinq secondes** — le temps qu'il faut pour se
faire refuser, pas pour travailler.

**`podman login` et `cosign` ne lisent pas le même fichier d'identifiants.**
Le premier écrit dans `$XDG_RUNTIME_DIR/containers/auth.json` ; le second passe
par le trousseau de `go-containerregistry`, qui lit la configuration Docker.
Deux étapes qui se suivent dans le fichier et qui ne se parlent pas. `cosign
login` fait la jointure.

Et le relevé du condensat est désormais **contrôlé avant d'être utilisé** : un
fichier absent aurait fait mourir `cat` sur une ligne qui ne nomme pas ce qui
manque — exactement le faux verdict payé le matin même sur la clé de F-Droid.
Deux fois la même faute dans la même journée : **une branche d'échec doit
montrer ce qui s'est passé avant de dire ce qu'elle en conclut.**

### L'image de S est signée, et la signature se vérifie

**Run #72, sur `0fa3c09` : réussi.** Et depuis cette machine, sans rien de
préparé d'avance :

```
cosign verify ghcr.io/gigigrenier86/s-os:latest \
  --certificate-identity-regexp '^https://github.com/gigigrenier86/s-os/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
```
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted CA certificates

  Subject : .../.github/workflows/build.yml@refs/heads/main
  Issuer  : https://token.actions.githubusercontent.com
  Digest  : sha256:3308822c89e63ad63ce60b9c687c8865af9940be76605656803b33114dc5c0ee
  Rekor   : logIndex 2602579452
```
**Code de retour : 0.**

Ce que le certificat prouve est plus précis qu'une clé partagée : non pas
« quelqu'un qui détenait la clé de S », mais **ce dépôt, ce fichier de workflow,
cette branche, ce commit**. Personne ne détient de clé privée, donc personne ne
peut la perdre.

**La moitié qui reste est une décision, pas un travail.** `rpm-ostree status`
dit toujours `ostree-unverified-registry`, parce que `/etc/containers/policy.json`
n'exige rien pour `ghcr.io/gigigrenier86`. Signer était sans risque ; **exiger**
peut empêcher une mise à jour ou un démarrage. La commande ci-dessus répond
maintenant : c'est elle qu'il faut avoir vue passer avant de poser l'entrée dans
`policy.json`, sur le patron exact de celle d'ublue-os.

> **FAUX, mesure le 2026-08-26 en fin de journee.** Ce patron epingle des CLES
> PUBLIQUES ; S est signe SANS cle, et `containers/image` exige `subjectEmail`
> avec `fulcio` — que le certificat d'une identite GitHub Actions ne porte pas.
> `skopeo` repond : *« Required email ... not found (got []) »*. Il a fallu
> AJOUTER une paire de cles, comme l'amont. Voir la section de l'apres-midi.

### Ce qui reste, et qui demande une décision ou une présence

- ~~**Exiger la signature** (`policy.json`)~~ — **fait, et actif sur la machine
  depuis le redémarrage du 2026-08-26 à 16 h 44.** Voir la section de 16 h 46.
- ~~**Android n'a toujours pas tourné**~~ **Il tourne depuis le 2026-08-26
  a 15 h, et ce qui le bloquait n'etait pas Android : deux blocs de `s-android`
  mouraient sur une redirection vers un journal devenu root. Voir la section de
  l'apres-midi.** Le texte d'origine : `s-android` demande un mot de passe
  légitimement — `waydroid.cfg` porte `multi_windows = true` là où S veut
  `false`, et `waydroid_base.prop` (25 août, 10 h 44) ne porte **aucun** des
  réglages. La demande était juste ; c'est le blocage sans limite qui ne
  l'était pas, et il est réparé. Il faut quelqu'un devant la machine.
- ~~**PURPLE ne s'ouvre plus**~~ **FAUX, mesure le 2026-08-26 en fin de
  journee : il s'ouvre, peint 3198 couleurs, et survit. Deux de mes bancs
  mentaient — voir la section de l'apres-midi.** Le texte d'origine :
  PURPLE ne s'ouvre plus dans aucun des deux rendus, sans une ligne de
  journal. Non expliqué, et pas établi comme régression.
- **`ntsync`** présent, inutilisé. **RapidO**, contenu de page jamais observé.


## 2026-08-26, matin — le serveur gardait le préfixe, pas la session, et c'est l'utilisateur qui payait la différence

L'entrée précédente se terminait sur une réserve honnête : *« le coût de la
première ouverture de session avec le serveur résident n'a pas été chronométré
sur un vrai démarrage »*. Elle a été chronométrée ce matin, et **la réserve
avait raison contre la thèse qu'elle accompagnait**.

### Les conditions, parce qu'elles ne se retrouvent qu'une fois

La machine a démarré à 02 h 15 sur `sha256:9d022ebc…`, la session s'est ouverte
à 05 h 21, `s-windows.service` s'est levé dans la seconde (`fsync: up and
running` à 05:21:06.980, **47 ms** après la cible de session) — et **aucun
programme Windows n'a été lancé pendant l'heure et quart suivante**. C'est
exactement l'état qu'il fallait, et il ne se reproduit pas sur commande : une
seule mesure était possible.

```
                                    duree      preuve
1er lancement apres la session     2565 ms     fichier ecrit
lancements 2 a 8                    215 ms     fichier ecrit  (ecart 8 ms)
```

**Douze fois.** Et `ps` a dit pourquoi, dans la seconde qui a suivi :
`services.exe`, `rpcss.exe`, `plugplay.exe` et les deux `winedevice.exe`
avaient **quatre secondes d'âge**. Ils venaient de naître — une heure et quart
après l'ouverture de session, au moment précis de ma première commande.

> `wineserver -f -p` garde le **préfixe** ouvert. Il n'ouvre pas la **session**
> Windows. C'est le premier client qui la monte.

Le carnet écrivait : *« ce coût est payé pendant l'ouverture de session et non
au premier double-clic »*. **C'était faux.** Il était payé par l'utilisateur, en
regardant son premier double-clic ne rien faire pendant deux secondes et demie —
soit *plus* que le 1,37 s mesuré au banc la nuit précédente, parce qu'au banc
une session Windows traînait déjà.

### Le correctif, et il tient en une ligne d'unité

`s-windows --amorcer` : un client jetable (`cmd /c exit`), lancé par
`ExecStartPost` juste après le serveur résident.

Deux détails qui ne sont pas de la décoration :

- **Il attend le serveur avant de lui parler.** `ExecStartPost` part dès
  qu'`ExecStart` est *lancé*, pas dès qu'il *écoute*. Un client arrivé trop tôt
  monterait son propre `wineserver`, non persistant — l'amorce aurait produit
  exactement la panne qu'elle répare. On vérifie, on ne dort pas un temps fixe.
- **`ExecStartPost=-`**, avec le tiret. Une amorce ratée ne doit pas emporter le
  serveur résident : le pire cas sans amorce est le comportement d'avant, pas
  une panne.

Éprouvé en démontant la session Windows pour retrouver l'état froid, puis en
remesurant :

```
journal de la session   « session Windows amorcee en 1866 ms (code 0) »
1er lancement ensuite     224 ms     fichier ecrit
lancements 2 a 8          215 ms     fichier ecrit
```

**2565 ms → 224 ms.** Le coût n'a pas disparu : il a changé de payeur. Il est
maintenant sur `systemctl start`, qui rend la main en 1944 ms — et personne ne
regarde `systemctl start`. `s-session.target` n'attend pas cette unité
(`After=`, pas `Before=`), donc l'ouverture de session n'est pas rallongée.

**Et l'amorce se chronomètre elle-même, à chaque démarrage, dans le journal.**
C'est la seule mesure de ce chantier qui se reprend toute seule — donc la seule
qui dira toute seule le jour où elle cesse d'être vraie.

### Quatre lignes de ce carnet étaient fausses ce matin

| Ce qui était écrit | Ce que la machine a répondu |
|---|---|
| « Rien n'est encore dans l'image » | l'image `9d022ebc…` tourne depuis 02 h 15, et ses 75 fichiers de `files/usr` sont identiques au dépôt |
| « la construction a été rejouée localement, pas lue dans les journaux d'Actions » | le digest publié sur `ghcr.io` **est** celui qui a démarré |
| « le repli sur `umu-run` n'a jamais servi pour de vrai » | il a servi le 2026-08-26 à 00 h 07 — `code 82 en 1s pour PcBoostApp.exe` |
| « ce coût est payé pendant l'ouverture de session » | non : par le premier double-clic, 2565 ms |

### Le filet, déclenché volontairement pour la première fois

Un fichier texte renommé `.exe`, passé à `s-ouvrir-exe`. Le chemin direct
échoue en 0 s, la condition (`code ≠ 0` **et** `durée < 5 s`) mord, et la suite
se déroule en entier : ligne écrite dans `windows-repli.log`, serveur résident
descendu, `umu-run` rejoué, serveur **repris** (`active`, `wineserver` vivant).
Dix secondes en tout. `umu-run` refuse le faux binaire lui aussi — c'est le bon
résultat pour un fichier qui n'est pas un PE. **Le filet fait ce qu'il promet,
y compris rendre la machine comme il l'a trouvée.**

### PcBoostApp : la capture à trente secondes aboutit enfin, et elle contredit la table des rendus

La nuit précédente laissait ceci ouvert : *« sa zone centrale était vide alors
que le reste peignait — je n'ai pas établi si elle se remplit plus tard, la
mesure qui trancherait est une capture à trente secondes, et elle n'a pas
abouti »*.

Elle aboutit. **Elle n'aboutissait pas pour deux raisons, et aucune des deux
n'était PcBoostApp :**

1. **La classe de fenêtre d'un programme Windows de S est `steam_proton`**, pas
   le nom du programme. Tous la partagent — c'est Proton qui la pose. Un
   `capturer_fenetre PcBoostApp` ne trouvera jamais rien. Sa clause de garde
   (« rend 1 sans créer de fichier plutôt que photographier celle qui passait
   par là ») a évité une fausse preuve ; elle n'a pas dit pourquoi.
2. **`XDG_RUNTIME_DIR` vide fait taire `spectacle`** : il ne rend pas d'erreur,
   il ne rend pas la main — 30 s de silence, aucun fichier. Le succès silencieux
   dans sa forme pure, une fois de plus.

Une fois les deux levés, à trente secondes, fenêtre de 1028×733 :

```
                  total       zone centrale
rendu logiciel    8888 coul.   3308 coul.
rendu materiel    9735 coul.   3492 coul.
```

**La zone centrale se remplit, dans les deux rendus.** Le commentaire livré dans
`s-windows` et dans `windows.sh` annonce « PcBoostApp : matériel 6426, logiciel
**17** », et le carnet écrivait « zone centrale absente ». À trente secondes,
ce carré central contient **3308 couleurs**.

**Ce que ça établit, et ce que ça n'établit pas.** Ça tue la phrase « la zone
centrale ne peint pas en rendu logiciel » : elle peint. Ça n'établit **pas** que
le temps de pose soit la seule cause de l'écart — les deux séries n'ont pas été
prises sur la même fenêtre (1028×733 ici, taille non consignée là-bas), donc
leurs totaux ne se comparent pas ligne à ligne. **La mesure qui trancherait :**
les deux rendus, à 5 s puis à 30 s, dans une seule série et sur la même fenêtre.
En l'état, la justification de `--fenetre-noire` pour PcBoostApp ne tient plus ;
celle de PURPLE n'a pas été réexaminée.

### Trois pièges de banc, dont deux déjà écrits ici

- **`DISPLAY` vide tue WPF, et le message ne le dit pas.** Un shell sans
  affichage lance `PcBoostApp.exe`, et il meurt sur
  `System.ComponentModel.Win32Exception (0x80004005): Success.` à
  `HwndWrapper..ctor`, **code 82**. Ni le mot « display », ni le mot « X11 ».
  J'ai cru dix minutes à une régression de l'image. Le `wineserver` résident,
  lui, a bien `DISPLAY=:0` — il le tient de `systemd --user`.
- **`pkill -f 'Purple'` a fauché mon propre shell.** Cinquième fois dans ce
  dépôt, et la règle « ce chantier n'emploie plus que `-x` » était déjà écrite
  vingt lignes plus haut dans ce fichier.
- **Et `-x` ment au-delà de quinze caractères.** `pgrep -x PurpleLauncher.exe`
  rend **zéro**, toujours : `comm` est tronqué à 15. Il le dit sur `stderr`, que
  personne ne lit dans un banc. La forme sûre est `pgrep -f '/nom\.exe$'`.

### Ce que ce matin ne prouve pas

- **Le régime établi a doublé** : 215 ms là où la nuit mesurait 109 ms, sur la
  même machine et le même geste. Écart de 8 ms sur sept lancements, donc ce
  n'est pas du bruit. Hypothèse : le préfixe porte maintenant .NET 4.8,
  WebView2 et 227 polices déclarées, que `cmd.exe` n'avait pas à lire cette
  nuit-là. **Ce qui la tuerait :** la même série sur un préfixe neuf, avant les
  fondations. Non fait.
- **PURPLE n'ouvre plus**, dans aucun des deux rendus : il sort sans une ligne
  de journal, sans fenêtre, et sans processus survivant à trente secondes. Non
  expliqué. Ce n'est pas une régression établie — mon shell de banc a déjà
  menti une fois ce matin.
- **Android n'a pas tourné.** `s-android` s'arrête sur un `pkexec` (« Réglage de
  l'affichage ») qui attend un mot de passe. L'utilisateur n'était pas devant la
  machine ; la demande a été annulée et l'écran rendu. **Un monde de S qui ne
  peut pas démarrer sans quelqu'un devant le clavier est un défaut en soi**, et
  il n'est pas traité.
- **L'image reste `ostree-unverified-registry`** — ni signée, ni vérifiée.


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

### La suite de la nuit — la construction rouge, et une fenetre noire qui coupe dans les deux sens

#### La verification tournait vingt lignes avant que le fichier existe

Premiere construction apres livraison : **rouge**. La cause est ordinaire et
entierement de moi. `41-windows.sh` s'execute a la **ligne 63** du
`Containerfile` ; `COPY files/ /` est a la **ligne 84**. Les controles du
Windows resident y cherchaient `/usr/bin/s-windows` — sur un fichier qui
n'existe pas encore a cette etape.

Ils demenagent dans `40-coutures.sh`, qui passe apres les COPY, la ou vivent
deja les controles des autres gestes. `41-windows.sh` ne garde qu'`icoutils`,
qui est un paquet et ne depend d'aucun COPY. Rejoue dans
`ghcr.io/ublue-os/bazzite:stable`, la vraie base : **code 0**.

*Les journaux d'Actions repondent 403 sans droits admin et `gh` n'est pas sur
cette machine — la construction se rejoue donc en local, dans l'image de base,
comme le 2026-08-25.*

#### Trois defauts trouves en relisant mon propre code

Aucun n'est venu d'un essai. Les trois sont sortis d'une relecture du flux de
`s-ouvrir-exe`, ligne a ligne, une fois le code ecrit.

1. **Le verrou n'etait pas reentrant.** `s-ouvrir-exe` prend le verrou,
   constate que le Windows de S n'existe pas, et appelle
   `s-windows --preparer` — qui prend le meme. `flock` ne compte pas les prises
   par processus : deux ouvertures du meme fichier sont deux verrous
   concurrents, meme entre parent et enfant. **Le tout premier double-clic
   d'une machine fraiche serait reste muet dix minutes.** Eprouve dans les deux
   sens sur un verrou separe : l'ancienne forme bloque, la nouvelle passe.

2. **Le verrou tenait pendant toute la vie du programme.** Aucun second
   logiciel Windows ne pouvait demarrer tant qu'un premier tournait. Ca ne se
   voyait pas quand chaque lancement coutait cinq secondes ; a un dixieme de
   seconde, l'utilisateur en ouvrira plusieurs — c'est l'objet meme du
   chantier.

3. **Je bloquais tout logiciel .NET Framework** tant que `dotnet48` n'etait pas
   pose. Or `wine-mono` suffit a beaucoup d'entre eux : j'aurais casse des
   programmes qui fonctionnaient. On previent desormais, on ne refuse plus. Le
   refus reste pour .NET 8, et pour une raison technique et non par gout :
   wine-mono n'implemente pas .NET Core.

Et la detection distingue enfin `"frameworks"` de `"includedFrameworks"` : une
publication **autonome** porte elle aussi un `runtimeconfig.json`, et la
bloquer aurait arrete `PcBoostApp` en version `win-x64`, **qui tournait deja
avant que .NET soit installe**.

#### PURPLE : deux « .NET » qui n'ont rien a voir l'un avec l'autre

Le lanceur de NCSoft ne s'ouvrait pas, et le journal de Wine disait exactement
pourquoi :

```
parse_supported_runtime sku=".NETFramework,Version=v4.7.1" not implemented
Failed to run module constructor ... wine-mono-10.4.1 ... TypeInitializationException
```

**.NET Framework 4.x et .NET 8 sont deux moteurs sans rapport.** Poser le
second ne sert a rien au premier. `dotnetdesktop8` etait en place ; il fallait
`dotnet48`.

Et la demande est **dans le binaire**, pas dans un fichier a cote — PURPLE n'a
aucun `.exe.config`. Le compilateur inscrit l'attribut de cible dans les
metadonnees de l'assembly, ou il se lit en clair :

```
PurpleLauncher.exe   .NETFramework,Version=v4.7.1
RapidO.exe           (rien — c'est son runtimeconfig.json qui parle)
```

Pose, l'erreur disparait et `NDP\v4\Full  Release = 0x80eb1`.

#### La fenetre noire, et pourquoi il n'y a pas de bon reglage global

PURPLE s'ouvrait alors — **et sa fenetre etait noire**. Pas un artefact de
capture : la capture faite par kwin lui-meme sur la fenetre activee rend **une
seule couleur distincte**.

WPF dessine par Direct3D 9 (milcore), et porte un interrupteur pour retomber en
rendu logiciel : `HKCU\SOFTWARE\Microsoft\Avalon.Graphics`,
`DisableHWAcceleration`.

| Couleurs distinctes | materiel | logiciel |
|---|---|---|
| PURPLE (CefSharp) | **1** | **3133** |
| PcBoostApp (WPF) | **6426** | zone centrale absente |

> **Chacun marche dans le mode ou l'autre echoue.**

Il n'y a donc rien a trancher globalement : ce n'est pas un compromis, c'est un
reglage **par programme**. D'ou `s-windows --fenetre-noire <programme>`, nomme
d'apres le symptome et non d'apres le mecanisme — un utilisateur qui voit une
fenetre noire ne cherchera pas « Avalon.Graphics ».

**Ce n'est pas DXVK :** force en WineD3D, PURPLE reste noir. C'est bien le
chemin materiel de WPF lui-meme.

**Et la cle est globale a l'utilisateur**, ce qui a produit un quatrieme
defaut : la premiere version n'ecrivait le registre que si le mode differait du
defaut. Or la cle garde ce que le programme PRECEDENT y a laisse — apres
PURPLE, `PcBoostApp` tournait en rendu logiciel sans l'avoir demande. On compare
desormais a ce qui est reellement pose, pas au defaut.

**Eprouve de bout en bout, par le vrai geste `s-ouvrir-exe` et non par un
morceau**, en alternant les deux programmes :

```
PURPLE      3131 couleurs   PEINT   (rendu logiciel, retenu pour lui)
PC Boost    6426 couleurs   PEINT   (rendu materiel, remis pour lui)
PURPLE      3131 couleurs   PEINT   (reglage retrouve)
```

Chacun dans son mode, l'un apres l'autre, sans que l'utilisateur ait rien a
faire apres la premiere fois.

#### Mon banc a menti une troisieme fois

`pgrep -x PurpleLauncher.e` ne matchait rien, et j'en ai conclu que PURPLE ne
tournait pas. **`/proc/PID/comm` tronque a quinze caracteres** :
`PurpleLauncher.exe` y devient `PurpleLauncher.`, avec le point. Le motif etait
d'un caractere trop long.

Pendant ce temps une fenetre « PURPLE » etait bien a l'ecran, et un essai
precedent tournait encore — que mes `pkill` rataient pour la meme raison.

*C'est la troisieme mesure fausse de la nuit, apres le 0,28 s d'une fenetre WPF
et le 0,01 s d'un lancement ou rien ne tournait.* Et la troisieme confirme la
regle des deux premieres : **un banc qui ne peut pas echouer ne mesure rien**.

#### La construction est tombee deux fois, et la seconde faute etait une supposition

Le premier echec — les verifications vingt lignes trop tot — est raconte plus
haut. Le second a resiste, et voici pourquoi.

Le controle de `40-coutures.sh` cherchait :

```
grep -q 's-lien-windows --recenser' /usr/bin/s-ouvrir-exe
```

Le geste reecrit appelle :

```
"$S_GESTES/s-lien-windows" --recenser
```

**Un guillemet fermant entre le nom et l'option**, et la sous-chaine n'existe
plus. J'avais RAISONNE que le motif matcherait quand meme — une supposition, pas
une mesure, exactement ce que ce carnet interdit depuis le premier jour.

**Et le rejeu qui aurait du l'attraper ne rejouait que le bloc AJOUTE**, jamais
le fichier entier. *Un rejeu partiel ne prouve que la partie qu'il rejoue.*

Le comparatif des durees a designe la zone avant meme de lire l'erreur :

| | duree de « Construire l'image » |
|---|---|
| derniere construction verte | 7 min 20 |
| premier echec | **6 min 09** — donc plus tot : `41-windows.sh`, ligne 63 |
| second echec | **8 min 56** — donc plus tard qu'un succes : `40-coutures.sh`, ligne 198 |

Ce qui en sort vaut mieux que le correctif : **un balayage qui rejoue TOUS les
controles par motif de TOUS les scripts contre les fichiers que l'image livrera
vraiment.** Onze controles, deux secondes, au lieu de quarante minutes de
construction. Il a designe celui-la et lui seul.

Il est au Grimoire (`construction-eprouver-les-motifs.sh`) **et dans le flux
d'Actions**, a l'etape qui existait deja pour ca — celle qui dit « une faute qui
se lit en une seconde ».

Ce balayage attrape les deux pieges symetriques que ce depot a payes :
le **faux negatif** (le motif ne matche plus alors que le code est juste) et le
**faux positif** (le motif matche une phrase de commentaire alors que l'appel a
disparu — le garde-fou de `plasma_waitforname`, et le controle sur `s-partage`
qui a survecu au demenagement de l'appel qu'il surveillait).

#### Ce que cette seconde moitie ne prouve toujours pas

- **`PcBoostApp` en rendu logiciel n'a ete observe qu'une fois**, a cinq
  secondes, et sa zone centrale etait vide alors que le reste peignait. Je n'ai
  **pas** etabli si elle se remplit plus tard — la mesure qui trancherait est
  une capture a trente secondes, et elle n'a pas abouti.
- **RapidO s'ouvre et WebView2 s'initialise** — il annonce son moteur
  `151.0.4129.107` et charge une adresse. Le contenu de la page n'a pas ete
  observe rendu.
- **Le repli sur `umu-run` n'a toujours jamais servi pour de vrai.**
- **Le cout de la premiere ouverture de session avec le serveur resident n'a
  pas ete chronometre sur un vrai demarrage.**


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
| `zwlr_layer_shell_v1` | présent — ~~mais aucune liaison Python de cette image ne sait le parler~~ **faux : la route n'est pas Python, elle est QML.** `layer-shell-qt-6.7.4` est installé et livre `/usr/lib64/qt6/qml/org/kde/layershell/`, importable depuis PySide6. Mesuré le 2026-08-27 — et il casse le menu du clic droit. Voir la section de 16 h. |

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
