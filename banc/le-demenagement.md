# Le déménagement — S sur le NVMe, Windows sur la Seagate

Décidé le 2026-08-23 : **S natif sur le disque interne de la M720q**, Windows
cloné et amorçable sur la Seagate, et S capable de lire cette copie.

Ce fichier est l'ordre des gestes. **L'ordre est la protection** — pas la
prudence de celui qui tape.

---

## L'état de départ, relevé le 2026-08-23 et non supposé

| Disque | Quoi | État |
|---|---|---|
| 0 · WD SN730 NVMe · 238,5 Go | Windows | C: 237,5 Go, **104 Go occupés**, 135 libres. Pas de BitLocker actif, pas de `hiberfil.sys` |
| 1 · Seagate Game Drive · 4 657 Go | **S** | 1 Mio BIOS + 512 Mio ESP + 4 657 Go ext4. **Zéro octet libre** |
| 2 · SanDisk · 57,3 Go | `ECHANGE`, exFAT, vide | destinée à porter l'ISO |

Les 74,6 Go de `.qcow2` ont été supprimés le 2026-08-23 sur décision de
l'utilisateur — c'est ce qui fait passer C: de 178 à 104 Go occupés, et divise
par deux la durée du clonage.

---

## Ce qui peut échouer, dit avant de commencer

**Windows cloné sur un disque USB ne démarre pas toujours.** Une installation
née sur du NVMe n'embarque pas, dans son jeu d'amorçage, de quoi lire un disque
USB — au moment précis où elle doit lire le sien. Le symptôme est un écran bleu
`INACCESSIBLE_BOOT_DEVICE` (0x7B).

La phase `preparer-usb` corrige cela : elle arme les pilotes USB dans le
registre du **clone**, efface `MountedDevices` et pose le drapeau
`PortableOperatingSystem`. C'est exactement ce que faisait Windows To Go, et ça
marche souvent. **Ça ne se promet pas.**

**D'où l'ordre.** On ne touche au NVMe qu'après avoir *vu* le clone démarrer.
Tant que ce n'est pas arrivé, le Windows du NVMe est intact et un simple F12
ramène tout comme avant.

---

## Les huit gestes

### 1 · L'ISO, avant tout le reste

L'ISO est **la seule chose qui puisse reposer S** une fois la Seagate effacée.
Elle vient donc en premier, et elle est vérifiée avant qu'un octet de la
Seagate ne bouge.

```powershell
gh workflow run "Fabriquer l'ISO de S"
gh run watch                              # une vingtaine de minutes
gh run download <id> -n s-os-iso -D C:\Users\Ghis\Downloads\s-iso
```

Puis, depuis un terminal **administrateur** :

```powershell
powershell -ExecutionPolicy Bypass -File banc\graver-iso-sur-cle.ps1 -Iso "C:\Users\Ghis\Downloads\s-iso\s-os-latest-AAAAMMJJ.iso"
```

Le script refuse d'écrire si le disque 2 n'est pas, **des quatre côtés à la
fois**, une SanDisk USB de 61 524 148 224 octets sans rôle d'amorçage. Il relit
trois zones après écriture et compare.

> **Geste que je ne peux pas faire à votre place :** amorcer la clé (F12) et
> vérifier que l'installateur de S s'ouvre. Une ISO gravée n'est pas une ISO qui
> démarre. **Ne pas passer à l'étape 2 avant de l'avoir vu.**

### 2 · La sauvegarde, refaite juste avant

```powershell
powershell -ExecutionPolicy Bypass -File banc\sauvegarder-le-projet.ps1
```

Elle atterrit dans `C:\S-sauvegarde` — donc **dans ce qui va être cloné**. Elle
voyagera avec Windows sur la Seagate, et S la relira par `~/Windows`.

### 3 · Effacer la Seagate et la repartitionner

**C'est ici que le S actuel disparaît.** Ne rien lancer si l'étape 1 n'a pas
abouti.

```powershell
powershell -ExecutionPolicy Bypass -File banc\windows-sur-seagate.ps1 -Phase partitionner
```

Résultat : ESP 1 Gio · MSR 16 Mio · `WINDOWS-S` 400 Go NTFS · `DONNEES` ~4,2 To
NTFS.

*NTFS et non exFAT pour les données : exFAT n'est pas journalisé, un
débranchement brutal y corrompt le volume entier — et le noyau de S lit et écrit
NTFS nativement par `ntfs3`.*

### 4 · Capturer Windows

```powershell
powershell -ExecutionPolicy Bypass -File banc\windows-sur-seagate.ps1 -Phase capturer
```

Environ **45 minutes** (104 Go à 24 Mo/s mesurés sur ce disque). Passe par un
cliché VSS : lire un volume qui tourne donnerait des ruches de registre
incohérentes, donc une copie qui ne démarre pas.

Le `.wim` produit — `DONNEES:\S-sauvegarde\windows-c.wim` — **est la copie de
sauvegarde**. Il reste sur la Seagate après tout, et se redéplie sur n'importe
quelle partition par `dism /Apply-Image`.

### 5 · Déplier

```powershell
powershell -ExecutionPolicy Bypass -File banc\windows-sur-seagate.ps1 -Phase appliquer
```

Environ **75 minutes**.

### 6 · Rendre amorçable

```powershell
powershell -ExecutionPolicy Bypass -File banc\windows-sur-seagate.ps1 -Phase preparer-usb
powershell -ExecutionPolicy Bypass -File banc\windows-sur-seagate.ps1 -Phase verifier
```

`verifier` relit la ruche du clone et dit, pilote par pilote, ce qui est armé.

### 7 · Le moment de vérité — **c'est vous**

Redémarrer, **F12**, choisir la Seagate.

- **Le premier démarrage est lent** : Windows redécouvre tout son matériel.
  Plusieurs minutes d'écran fixe sont normales.
- **Écran bleu `INACCESSIBLE_BOOT_DEVICE`** → le clone ne sait pas lire son
  disque. Rien n'est perdu : F12, redémarrer sur le NVMe, et on cherche quel
  pilote manque.
- **Windows démarre** → l'étape 8 est ouverte.

> Piège déjà consigné au carnet : **F12 est un choix ponctuel, déjà consommé.**
> Si le clone redémarre de lui-même en cours de route, la machine repartira sur
> le NVMe. Ce n'est pas un échec — il faut refaire F12.

### 8 · S sur le NVMe

Seulement maintenant. Amorcer sur la clé (F12), et installer S sur `nvme0n1`.

**Ce qui n'est pas encore éprouvé et qui le sera là :** l'installateur Anaconda
de l'ISO. La voie *prouvée* du dépôt reste `bootc install to-disk` depuis un
support live — si l'ISO déçoit, c'est le filet :

```bash
sudo bootc install to-disk --wipe --filesystem ext4 \
  --source-imgref docker://ghcr.io/gigigrenier86/s-os:latest \
  --target-imgref ghcr.io/gigigrenier86/s-os:latest \
  /dev/nvme0n1
```

---

## Après : ce que S doit faire tout seul

`s-monter-windows` a été repris pour ce déménagement, et il a fallu deux
corrections que rien n'annonçait :

1. **Il ne regardait que les disques non amovibles** (`RM=0`). Windows partant
   sur un disque USB, il ne l'aurait jamais trouvé — et n'aurait rien dit.
2. **« La plus grosse NTFS » ne marche plus** : la Seagate en portera deux, et
   la partition de données de 4,2 To bat celle de Windows. Il **monte désormais
   chaque candidate en lecture seule** et garde celle qui contient vraiment
   `Windows/System32/config/SYSTEM`.

Éprouvé sur de fausses partitions le 2026-08-23 : écarte 4 To de données, retient
300 Go de Windows, se tait si aucune ne porte Windows. **Jamais exercé sur la
machine.**

---

## Ce que ce déménagement change au carnet

La ligne *« Windows reste sur le disque interne, définitivement »* des limites
connues d'avance **n'est plus la décision en vigueur**. Elle reposait sur un
raisonnement qui tient toujours — PC Boost est du WPF, il ne se construit que
sous Windows — mais l'utilisateur a tranché autrement le 2026-08-23 : Windows
reste **disponible**, sur la Seagate, et le NVMe rapide revient à S.

Ce qui se paie : Windows sera **lent**, sur un plateau USB. C'est le prix exact
que S payait jusqu'ici, échangé de place.
