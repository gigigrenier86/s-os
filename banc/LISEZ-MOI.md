# Le banc — éprouver S dans QEMU, sur Windows

Ce dossier contient de quoi faire démarrer l'image de S dans une machine
virtuelle accélérée, sur la machine de développement Windows.

## Préparer

```bash
mkdir -p ~/Desktop/S-vm/firmware && cd ~/Desktop/S-vm
# Le firmware, concaténé : les VARIABLES D'ABORD, le code ensuite.
cat "/c/Program Files/qemu/share/edk2-i386-vars.fd" \
    "/c/Program Files/qemu/share/edk2-x86_64-code.fd" > firmware/bios.fd
# 4194304 octets exactement, sinon la concaténation est fausse.
"/c/Program Files/qemu/qemu-img.exe" create -f qcow2 S.qcow2 50G
```

## Lancer, piloter

    ./lancer-vm.sh              # démarre la machine
    ./moniteur.sh info status   # interroge le moniteur QEMU
    ./capture.sh nom            # capture l'écran en PPM
    powershell ./ppm2png.ps1 nom.ppm nom.png    # pour la regarder

## Les cinq pièges, tous rencontrés pour de vrai le 2026-08-20

Chacun a coûté un essai. Ils sont dans cet ordre parce que c'est celui dans
lequel ils se présentent.

1. **`-cpu max` fait échouer WHPX.** Symptôme : `WHPX: Failed to emulate MMIO
   access with EmulatorReturnStatus: 2`, puis `Failed to exec a virtual
   processor`. L'invité n'exécute rien — zéro octet lu, écran noir portant
   « Guest has not initialized the display (yet) ». **C'était la vraie cause**,
   et ce n'est pas celle que les rapports en amont mettent en avant.
   Remède : un modèle explicite couvrant `x86-64-v2`.

2. **Le modèle de processeur par défaut ne suffit pas non plus.** Fedora 44 exige
   `x86-64-v2` — CMPXCHG16B, LAHF/SAHF, POPCNT, SSE3, SSSE3, SSE4.1, SSE4.2 — et
   le `qemu64` par défaut ne les expose pas. D'où
   `-cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm`.

3. **WHPX ne prend pas en charge `-drive if=pflash`.** Le mécanisme sous-jacent
   est un mappage en lecture seule (`ROMD`), que ni WHPX ni HAX ne supportent.
   Remède : `-bios` avec le fichier concaténé. **Contrepartie à connaître : les
   variables UEFI ne survivent pas à un redémarrage**, le firmware étant en
   lecture seule — une entrée d'amorçage écrite en NVRAM par l'installateur
   serait perdue.

4. **`q35` ne crée aucun contrôleur USB.** Sans `-device qemu-xhci`, la tablette
   n'a pas de bus et QEMU refuse de démarrer. Et sans tablette, la souris est
   capturée et décalée : l'installateur graphique devient impraticable.

5. **`screendump` veut un chemin Windows.** QEMU est un programme Windows : un
   chemin à la mode Git Bash (`/c/Users/...`) échoue en silence, sans message.
   Écrire `C:/Users/...` — les barres obliques passent.

## Mesures du 2026-08-20

| | |
|---|---|
| Bureau Bazzite affiché, sous WHPX | **~80 s** depuis le lancement |
| Lecture de l'ISO, 35 premières secondes | 361 Mo |
| Même mesure en TCG | 311 Mo — l'écart ne se voit pas sur l'E/S, mais sur le calcul |

**`info blockstats` reste l'arbitre** entre « lent » et « planté » : un écran figé
dont `rd_bytes` progresse n'est pas une panne.

---

# Installer S sans installateur — la nuit du 2026-08-20

La voie « installer Bazzite puis basculer » a été abandonnée en cours de route
au profit d'une meilleure : **`bootc install to-disk` pose l'image directement**.
Un téléchargement au lieu de deux, et cela éprouve le vrai chemin d'installation
d'une image `bootc` plutôt qu'un détour.

Ce qui suit est la route effectivement praticable, et les six impasses qui l'ont
précédée.

## Ce qui ne marche pas, et pourquoi

### 1. `inst.ks=` est ignoré par l'ISO live de Bazzite

Le kickstart **est bien téléchargé** — le journal du serveur HTTP le prouve,
`GET /ks.cfg → 200` — mais Anaconda ne démarre jamais : la session live ouvre
`gdm` et le bureau. Sur une ISO live, l'installateur est une application qu'on
lance, pas un service qui s'arme sur la ligne de commande du noyau.

Ne pas conclure trop vite d'un `inst.ks` sans effet que le fichier n'a pas été lu :
**servir le kickstart par HTTP depuis l'hôte donne la preuve du contraire**, dans
le journal du serveur.

### 2. Anaconda se fige sans terminal

Lancé par `setsid nohup … < /dev/null`, Anaconda s'arrête net après
`INF screensaver: Inhibiting screensaver.` et n'écrit plus une ligne. Le
processus vit, le journal est gelé. Il lui faut un pseudo-terminal — et
`--noninteractive` n'y change rien.

### 3. `q35` ne permet pas le branchement à chaud

`device_add virtio-blk-pci` rend `Bus 'pcie.0' does not support hotplugging`. Il
faut prévoir tous les disques au lancement, ou déclarer des `pcie-root-port`.

### 4. `/var/tmp` d'une session live est un tmpfs de 3,9 Gio

C'est **la** cause du `no space left on device` qui interrompt `podman pull`
alors que le disque de travail est aux trois quarts vide : podman y écrit ses
blobs temporaires. Remède : `export TMPDIR=/var/lib/containers/tmp`, sur un vrai
disque.

Le message d'erreur nomme d'ailleurs le bon chemin —
`/var/tmp/container_images_storage…` — et il suffit de le lire au lieu de
regarder l'espace du disque qu'on croyait concerné.

### 5. La session live ne peut pas héberger l'image en mémoire

Le système de fichiers d'une session live est une surcouche en RAM. Une image
`bootc` pèse une quinzaine de gigaoctets décompressée : **il faut un second
disque**, monté sur `/var/lib/containers`, sinon `podman pull` ne peut pas
aboutir.

## Ce qui marche : piloter la machine sans jamais toucher la souris

Une session live n'a ni compte connu, ni SSH ouvert. Mais elle a une console
série, et c'est par là que tout se prend.

### La console série devient un vrai terminal

    -serial tcp:127.0.0.1:4446,server,nowait

Au lieu de `-serial file:…`, qui ne fait que lire. On y écrit alors, et
`localhost-live login:` répond.

**Une reconnexion réinitialise l'invite de connexion.** Une séquence de login
doit donc tenir dans **une seule connexion**, avec des pauses entre les lignes —
c'est tout l'objet de `serie-multi.sh`. La session, elle, survit côté invité une
fois ouverte.

Le compte est **`liveuser`**, sans mot de passe, et son `sudo` ne demande rien.

### Puis on bascule sur SSH, par une clé

La console série vomit des séquences d'échappement OSC 3008 à chaque commande —
illisible pour un usage prolongé. On pose donc une clé et on passe à SSH :

    ssh-keygen -t ed25519 -N "" -f ./cle-banc
    # puis, par la console serie, en une ligne :
    #   mkdir -p ~/.ssh && echo '<cle publique>' > ~/.ssh/authorized_keys
    #   chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
    #   sudo systemctl start sshd

Le port est redirigé au lancement : `hostfwd=tcp:127.0.0.1:2222-:22`.

**`sudo` réclame un mot de passe par SSH** alors qu'il n'en demandait pas sur la
console série — faute de terminal. `echo '<mdp>' | sudo -S -p ''` règle la
question sans allouer de tty.

### L'installation elle-même

```bash
# Un disque de travail, sinon l'image n'a nulle part ou tenir.
mkfs.ext4 -F -L travail /dev/vdb
mount /dev/vdb /var/lib/containers
export TMPDIR=/var/lib/containers/tmp && mkdir -p "$TMPDIR"

podman pull ghcr.io/gigigrenier86/s-os:latest

podman run --rm --privileged --pid=host \
  -v /dev:/dev -v /var/lib/containers:/var/lib/containers \
  -v /tmp/cles:/tmp/cles:ro \
  --security-opt label=type:unconfined_t \
  ghcr.io/gigigrenier86/s-os:latest \
  bootc install to-disk --wipe --filesystem btrfs \
    --root-ssh-authorized-keys /tmp/cles \
    --karg console=tty0 --karg console=ttyS0,115200 \
    /dev/vda
```

Deux options changent tout pour la suite :

- **`--root-ssh-authorized-keys`** — `bootc install` **ne crée aucun compte**.
  Sans cette option, le système installé démarrerait sans qu'on puisse s'y
  connecter. C'est le seul moyen d'y entrer sans repasser par une session live.
- **`--karg console=ttyS0,115200`** — le système installé parle alors sur la
  console série, donc son démarrage se lit en texte au lieu de se deviner sur
  des captures d'écran.

---

## Plus simple encore : `bootc` en natif, sans podman du tout

Découvert le 2026-08-20 vers 03 h, après que le stockage podman d'une session
live remontée d'un démarrage précédent eut cessé de fonctionner
(`podman images` répondait, `podman run` rendait
`readlink /var/lib/containers/storage/overlay: invalid argument`).

**La session live de Bazzite embarque `bootc` nativement** — 1.15.2. Et
l'option `--source-imgref` permet de lui désigner le registre directement, au
lieu de le faire tourner dans un conteneur :

```bash
bootc install to-disk --wipe --filesystem btrfs \
  --source-imgref docker://ghcr.io/gigigrenier86/s-os:latest \
  --target-imgref ghcr.io/gigigrenier86/s-os:latest \
  --root-ssh-authorized-keys /root/cles \
  --karg console=tty0 --karg console=ttyS0,115200 \
  /dev/vda
```

**Ce que ça supprime, et c'est beaucoup :**

- plus de `podman pull`, donc plus de stockage local à gérer ;
- **plus besoin du second disque** — c'était sa seule raison d'être ;
- plus de `/var/tmp` en tmpfs à contourner ;
- plus de fichier monté dans un conteneur, donc plus la question de savoir où
  il est visible.

`--target-imgref` mérite d'être posé explicitement : c'est la référence que le
système installé utilisera pour ses **mises à jour ultérieures**. Sans elle,
`bootc upgrade` ne saurait pas où chercher.

**La méthode par podman reste consignée plus haut**, parce qu'elle a fonctionné
et qu'elle éclaire ce que fait `bootc` — mais celle-ci est la bonne.

## Deux chaînes concurrentes valent une soirée perdue

Une leçon de conduite, pas de technique. Deux exemplaires du même script
d'automatisation ont tourné en parallèle sans que je m'en aperçoive : l'un
effaçait le disque que l'autre installait, l'un éteignait la machine que l'autre
attendait. Le journal est illisible et deux heures y sont passées.

Deux règles en découlent, pour ce dépôt :

1. **Un script détaché par `nohup` depuis l'outil ne survit pas toujours** — et
   quand on croit qu'il est mort, il ne l'est pas forcément. Vérifier par
   `ps` avant de relancer.
2. **Avant toute opération destructrice, compter les processus.** `taskkill` sur
   QEMU sans regarder ce qui tourne a coûté, plus tôt dans la nuit, une
   installation de 6,63 Gio lancée par l'utilisateur.
