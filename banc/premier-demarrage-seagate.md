# Premier démarrage de S sur la M720q — 2026-08-21

**Tu es mes yeux à partir d'ici.** Quand la machine redémarre, Windows s'éteint
et je ne vois plus rien. Cette fiche est le seul document que tu auras sous les
yeux à ce moment-là.

---

## Avant de toucher à quoi que ce soit

- [ ] La Seagate est branchée sur un **port USB 3** — les bleus, **à l'arrière**
      de préférence : ceux de la façade partagent souvent leur contrôleur.
- [ ] Rien d'important n'est ouvert sous Windows.
- [ ] QEMU est arrêté. *(vérifié le 2026-08-21 : arrêté, disque libéré)*

---

## Le geste

### 1. **Redémarrer**, pas « Arrêter »

**C'est le premier piège, et il est mesuré sur ta machine.**
`HiberbootEnabled = 1` : le **démarrage rapide** de Windows est actif. « Arrêter »
puis rallumer fait une mise en veille déguisée qui **ne repasse pas par le
firmware** — F12 ne répondrait pas, ou la machine repartirait droit sur Windows.

> Menu Démarrer → Marche/Arrêt → **Redémarrer**

### 2. **F12** dès l'extinction de l'écran

Marteler F12 pendant que le logo Lenovo s'affiche. Le menu d'amorçage s'ouvre.

### 3. Choisir le disque — **et il ne s'appellera PAS « S »**

**C'est le deuxième piège.** `bootc` a été lancé avec `--generic-image`, qui
n'écrit **aucune variable de firmware** : aucune entrée « S » n'a été ajoutée au
BIOS. Le disque apparaîtra sous son nom de matériel, quelque chose comme :

```
    USB HDD : Seagate Game Drive PS
    Seagate Game Drive PS
    USB HDD
```

**C'est la bonne ligne.** Le disque démarre par le chemin de repli
`\EFI\BOOT\BOOTX64.EFI`, qui est justement celui que F12 va chercher sur un
amovible — vérifié présent, 1 026 520 octets.

Ne pas choisir `Windows Boot Manager`, ni le NVMe interne.

---

## Ce qui va se passer, dans l'ordre

| Quand | Ce que tu vois | Est-ce normal |
|---|---|---|
| 0 s | Menu GRUB, très bref | oui |
| 0–60 s | Texte blanc qui défile — **il dira « Bazzite »** | oui, le jalon 6 n'est pas fait |
| ~2 min 20 | **La machine redémarre toute seule** | **OUI — à dessein** |
| — | **Elle repart sur Windows** | oui, et c'est le piège |
| — | **Refaire F12, rechoisir le disque** | ← c'est là que tout se joue |
| puis | Texte, puis un écran graphique | oui |
| enfin | **« Welcome to Plasma Desktop »**, bouton *Begin Setup* — **en anglais** | oui |

### Le redémarrage automatique n'est pas une panne

`bazzite-hardware-setup` lit le matériel au tout premier démarrage, pose un
argument noyau, et **redémarre exprès**. Mesuré : 2 min 22 en machine virtuelle,
2 min 38 en autre banc.

**Et F12 est un choix ponctuel, déjà consommé.** La machine repartira donc sur
Windows. **Ce n'est pas un échec. Refais F12.**

Sans cet avertissement, on voit deux minutes d'écran figé puis Windows, et on
conclut que le disque ne démarre pas — alors que S a parfaitement démarré.

### Ce sera lent, et ce n'est pas un défaut

C'est un **disque à plateaux** en USB, probablement SMR. L'écriture a tenu
11–12 Mo/s. Un démarrage qui prend deux à quatre fois plus longtemps que prévu
est **le disque**, pas le système.

---

## L'assistant, quand il s'ouvre

Il est en anglais, et il demandera :
langue · clavier (**ca** pour un clavier canadien-français) · compte · nom de
machine.

**Créer le compte est nécessaire** : aucun mot de passe n'entre dans une image
publique, donc S ne peut pas en fournir un.

---

## Si ça ne marche pas — les trois questions, dans l'ordre

**1. Le disque n'apparaît pas dans F12.**
Ce n'est **jamais** Secure Boot : celui-ci vérifie les signatures *au chargement*,
pas à l'énumération — il ne masque pas un périphérique. C'est un problème de
port ou d'alimentation. Essayer un autre port USB 3, à l'arrière.

**2. Écran noir après le choix du disque.**
Attendre **au moins cinq minutes** avant de conclure. Un plateau USB est lent, et
une capture noire prouve qu'on n'a rien vu, jamais qu'il n'y a rien — le projet
s'est déjà fait avoir quinze heures là-dessus.

**3. La machine repart sur Windows.**
C'est presque certainement le redémarrage voulu de `bazzite-hardware-setup`.
**Refaire F12.** Si ça recommence une troisième fois, là c'est un vrai symptôme.

---

## Pour revenir à Windows

Rien à défaire : **Windows n'a pas été touché.** Le NVMe interne n'a jamais été
présenté à la machine virtuelle, et aucune entrée n'a été ajoutée au firmware.

Redémarrer sans toucher à F12 — ou débrancher la Seagate — et Windows revient.

---

## Ce que ce test doit trancher

Trois questions qu'aucune machine virtuelle ne peut résoudre :

1. **S démarre-t-il sur du vrai matériel.** Un firmware virtuel prouve qu'un
   support est amorçable ; il ne prouve pas qu'un système démarre.
2. **L'iGPU va-t-il mieux sous Linux.** 266 réinitialisations du moteur
   d'affichage en 30 jours sous Windows, conclusion « matériel ». `dmesg` et les
   compteurs `i915` diront si le défaut suit la machine. *Cette réponse vaut
   aussi pour PC Boost.*
3. **Waydroid tourne-t-il.** C'est la seule chose qui demandait exactement ce qui
   manquait au banc : un vrai GPU. Waydroid n'a **jamais** tourné.

---

## À me rapporter au retour

Le plus utile, dans l'ordre :

1. **Combien de F12 il a fallu** (1 ou 2).
2. **Le nom exact affiché dans le menu d'amorçage.**
3. **Combien de temps** jusqu'à l'écran d'accueil.
4. Une **photo de l'écran** si quelque chose cloche — même floue, même partielle.
5. Si tu arrives au bureau : est-ce **fluide ou pâteux**. C'est la première fois
   que S tournerait sur un vrai GPU, et c'est la mesure que le banc ne pouvait
   pas donner.
