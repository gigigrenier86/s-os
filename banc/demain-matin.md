# Demain matin — écrire S sur la clé, et démarrer dessus

Tout ce qui pouvait être éprouvé sans toi l'a été cette nuit. **S démarre depuis une clé** —
prouvé sur un disque virtuel de la taille exacte de la tienne, à l'octet près. Ce qui reste
est la clé réelle et le matériel réel.

---

## Étape 1 — Écrire la clé *(une à deux heures, sans toi)*

**Terminal administrateur** (clic droit sur le menu Démarrer → *Terminal (administrateur)*).

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Ghis\Desktop\S-vm\cle-usb.ps1"
```

Il vérifie la cible, demande `EFFACER DISQUE 1`, **supprime la partition** — indispensable,
sans quoi Windows refuse l'écriture — et lance la machine virtuelle, détachée.

Attends que la VM ait démarré. Puis, dans la même fenêtre :

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Ghis\Desktop\S-vm\poser-sur-cle.ps1"
```

**Ne ferme pas cette fenêtre : elle porte l'exécution.**

### Ce que tu dois voir passer

```
  taille   : 61524148224 octets (attendu 61524148224)
  ecriture : autorisee (secteurs 2048 et 120164351)
  image    : deja au magasin, aucun telechargement
  swap     : aucun, verifie apres coup
```

Ces quatre lignes sont les garde-fous. **Si l'une échoue, le script s'arrête sans rien
écrire** et dit pourquoi.

> **Combien de temps ?** 21 minutes sur disque virtuel, à ~16 Mio/s. Sur de la mémoire
> flash réelle, derrière QEMU, compte **une à deux heures**. Ce n'est pas une panne.

> **Le volume écrit est de 20,2 Gio**, pas les 7,5 annoncés par `bootc` — ce chiffre-là ne
> compte que les couches à transférer. Si tu vois passer 7 Gio, tu n'es qu'au tiers.

---

## Étape 2 — Démarrer dessus

1. **Éteindre la machine virtuelle** (sinon la clé lui appartient encore).
2. **Débrancher puis rebrancher la clé.**
3. Redémarrer, **F12** dès l'écran Lenovo, choisir l'entrée **UEFI** de la clé.

### Le piège qui te ferait conclure à tort

**Le premier démarrage redémarre la machine tout seul, au bout de 2 min 20 s a 2 min 40 s.**
C'est `bazzite-hardware-setup` : il pose un argument noyau puis redémarre pour l'appliquer.
Pendant ce temps l'écran affiche `Preparing System - Please wait` et **semble figé**.

Comme F12 est un choix ponctuel déjà consommé, ce redémarrage **repart sur Windows**.
**Ce n'est pas un échec : refais F12 et rechoisis la clé.** Ça n'arrive qu'une fois.

### Ce qui est déjà vérifié, et que tu n'as pas à surveiller

- Le firmware trouve la clé et lui passe la main.
- La racine ext4 monte.
- Le réseau monte.
- `greenboot-success` est atteint — **le système se déclare sain lui-même**.
- Secure Boot est déjà désactivé sur ta machine : **rien à régler dans le BIOS**.

---

## Étape 3 — La première connexion

Un assistant KDE s'ouvre et te demande de **créer ton compte**. C'est voulu : aucun mot de
passe n'entre dans l'image, qui est publique.

Le compte que tu crées reçoit automatiquement ce que `/etc/skel` contient — extensions VS
Code, pack de langue française, réglages.

### Pour travailler sur S depuis S

Tout est déjà dans l'image, rien à installer :

| Outil | Commande |
|---|---|
| VS Code | `code` |
| Claude Code | `claude` |
| Antigravity | `antigravity` |
| Git, Node, npm | `git`, `node`, `npm` |
| Gemini CLI | `gemini` |

Le dépôt se récupère par :

```bash
git clone https://github.com/gigigrenier86/s-os.git ~/S
```

**Claude Code et Antigravity demanderont une authentification** au premier lancement — c'est
normal, aucun jeton n'est embarqué dans une image publique.

---

## Ce qu'il faut regarder, et noter

La fiche détaillée est dans `premier-demarrage-reel.md`. Les trois questions qui comptent :

1. **Le bureau est-il fluide ou saccadé ?** Saccadé = pas d'accélération graphique, et
   Waydroid ne suivra pas. C'est la question qui commande tout le reste.
2. **L'écran se fige-t-il ou clignote-t-il ?** C'est la signature des 266 réinitialisations
   vues sous Windows. **Cette réponse vaut aussi pour PC Boost.**
3. **Waydroid démarre-t-il ?** Icône « Android » au menu. 1 Go à télécharger la première
   fois. C'est ce qui débloque le Play Store.

---

## Deux choses à savoir avant de t'y installer

**La clé sera lente.** Mémoire flash, écriture aléatoire médiocre. Pour démarrer, regarder,
essayer Waydroid et trancher la question de l'iGPU, elle suffit largement. Pour une journée
de développement, tu la sentiras — et l'alternative n'est pas de renoncer, c'est le SSD
externe à ~40 €, que ce test aura justifié au lieu de le précéder.

**PC Boost ne se compilera pas sur S.** C'est du WPF .NET, Windows uniquement. Tu pourras
travailler sur S depuis S, mais pas sur PC Boost : le double amorçage est l'état final, pas
une étape transitoire.
