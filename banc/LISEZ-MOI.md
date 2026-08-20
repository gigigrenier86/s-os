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
