# Premier démarrage de S sur du vrai matériel — fiche d'observation

Cette fiche existe parce que **personne ne verra l'écran à ma place**. Ce qui n'est pas
noté ici sera perdu : un premier démarrage ne se rejoue pas à l'identique.

Machine : Lenovo ThinkCentre M720q (10T7002CUS), i5-8400T, 16 Go, UHD 630.
Support : SanDisk 3.2Gen1 de 57,3 Go.

---

## Avant de redémarrer

1. Éteindre la machine virtuelle, sinon la clé lui appartient encore.
2. **Débrancher puis rebrancher la clé** — Windows lui a supprimé sa partition, et
   le firmware doit la redécouvrir.
3. Redémarrer, et appuyer sur **F12** dès l'écran Lenovo.

> **F12 est un choix ponctuel.** Il ne modifie pas l'ordre de démarrage. Sans clé
> branchée, la machine repart sur Windows comme d'habitude.

4. **Le premier démarrage redémarre la machine tout seul, au bout d'environ deux
   minutes et demie. C'est voulu, ça n'arrive qu'une fois — et il faut refaire F12.**

> `bazzite-hardware-setup` ne tourne qu'au **premier** démarrage d'une installation
> neuve : il ajoute l'argument noyau `bluetooth.disable_ertm=1`, met le changement en
> attente, puis redémarre pour l'appliquer. Mesuré sur cette même image en machine
> virtuelle : **2 min 38 s** entre le noyau et le redémarrage, dont 1 min 51 s pour le
> service seul. Il se place `Before=systemd-user-sessions`, donc **aucun écran de
> connexion n'apparaît pendant ce temps** — l'écran semble figé, et il ne l'est pas.
>
> Comme F12 est un choix ponctuel déjà consommé, ce redémarrage **repart sur Windows**
> si tu ne fais rien. Ce n'est pas un échec : c'est le moment d'appuyer sur F12 une
> seconde fois et de rechoisir la clé.

> **Secure Boot est déjà désactivé sur cette machine** — relevé le 2026-08-20 par deux
> sources : `UEFISecureBootEnabled = 0` dans le registre, et msinfo32 (LENOVO
> 10T7002CUS, BIOS M1UKT77A, mode UEFI). **Rien à régler dans le BIOS avant ce test.**
> Ne pas le réactiver, et se méfier d'un « Load Optimized Defaults » : le noyau de
> Bazzite est signé par un certificat `O=Universal Blue`, pas par Fedora, et
> `bootc install --generic-image` n'inscrit aucune clé. L'enrôlement
> (`ujust enroll-secure-boot-key`) se fait depuis un système **déjà démarré** — donc
> trop tard.

---

## Ce qu'il faut regarder, dans l'ordre

### 1. Le menu de démarrage
- [ ] La clé apparaît-elle ? Sous quel nom exact ?
- [ ] Y a-t-il une entrée **UEFI** et une entrée héritée ? **Prendre l'UEFI.**

### 2. L'amorçage
- [ ] Un menu de démarrage s'affiche-t-il, ou ça enchaîne directement ?
- [ ] Combien de temps entre le choix et le premier texte à l'écran ?
- [ ] **Du texte rouge ou blanc qui défile** : le noter, même approximativement.
  C'est là que se voient les pannes de pilote.

### 3. L'écran de connexion
- [ ] Arrive-t-il ? Au bout de combien de temps ?
- [ ] La résolution est-elle correcte, ou une basse définition étirée ?
      *(Une basse définition = le pilote `i915` n'a pas pris la main.)*
- [ ] Le compte `Ghis` est-il proposé, ou l'assistant de création s'ouvre-t-il ?
      **Les deux réponses sont normales** — l'assistant signifie que le compte est créé
      à l'installation, ce qui est le comportement voulu sur une image publique.

### 4. Le bureau
- [ ] S'ouvre-t-il ? Est-il **fluide** ou saccadé ?
      *(Saccadé = rendu logiciel, donc pas d'accélération. C'est LE point du test.)*
- [ ] Le son, le réseau, le Wi-Fi : présents ?

### 5. L'iGPU — la question qui vaut pour les deux projets
- [ ] **L'écran se fige-t-il, clignote-t-il, ou revient-il au noir une seconde ?**
      C'est la signature des 266 réinitialisations vues sous Windows.
- [ ] Si oui : au bout de combien de temps, et pendant quelle activité ?

### 6. Les coutures — le jalon 5
- [ ] Le menu contient-il **Android** et **Magasin Android** ?
- [ ] Double-cliquer un `.exe` : que se passe-t-il ? Une notification arrive-t-elle ?
- [ ] Lancer **Android** : Waydroid démarre-t-il ? *(1 Go à télécharger la première fois.)*

---

## Si ça ne démarre pas

Ce n'est pas un échec du projet, c'est un résultat. Ce qui compte est **où** ça
s'arrête :

| Symptôme | Ce que ça dit |
|---|---|
| La clé n'apparaît pas dans F12 | la machine virtuelle tourne encore et garde la clé · la clé n'a pas été débranchée puis rebranchée · l'ESP n'a pas été écrite · le démarrage USB est désactivé dans le BIOS. **Ce n'est jamais Secure Boot** : il vérifie les signatures au chargement, pas à l'énumération — il ne masque pas un périphérique |
| La clé apparaît, mais seulement en entrée héritée | prendre l'UEFI ; s'il n'y a pas d'entrée UEFI, c'est l'ESP qui n'a pas été écrite |
| GRUB s'affiche, puis le choix rend une erreur de signature et retombe sur le menu | Secure Boot a été réactivé. shim et GRUB sont signés par Fedora et passent ; le noyau est signé par Universal Blue et non — le refus tombe deux étages plus loin, et **aucun message « Secure Boot violation » n'apparaît**. Le désactiver : **F1** au démarrage, *Security > Secure Boot > Disabled*, **F10**. Mesuré le 2026-08-20 : il est déjà désactivé, donc cette ligne ne devrait pas se produire |
| Texte qui défile puis arrêt | un pilote manque : **photographier l'écran** |
| Écran noir après le texte | c'est l'affichage, pas le démarrage |
| Deux minutes d'écran figé, puis un redémarrage vers Windows | **normal au premier démarrage** — refaire F12, voir le point 4 |

**Une photo de l'écran vaut mieux qu'une description**, surtout pour du texte d'erreur.

---

## Ce qui ne peut PAS arriver

Le Windows du disque interne n'est pas touché. Il n'a jamais été présenté à la machine
virtuelle qui a écrit la clé, et `bootc install` n'a écrit que sur `/dev/vdb`. Débrancher
la clé et redémarrer ramène tout en l'état.

Seule réserve : le firmware **peut** ajouter une entrée de démarrage pour la clé dans sa
mémoire. Elle se supprime dans le BIOS, et n'empêche pas Windows de démarrer.
