# De la trouvaille à la preuve — et où chaque chose se range

Tu rapportes du dehors. Rien de ce que tu rapportes n'est un fait tant que
cette machine ne l'a pas confirmé. Ce fichier dit comment franchir cet écart,
et où écrire à chaque étape.

---

## L'échelle, et ses quatre barreaux

| Barreau | Ce que tu as | Où ça s'écrit |
|---|---|---|
| 1. **Trouvaille** | une page, un dépôt, une ligne de code amont | nulle part encore — tu cites la source |
| 2. **Hypothèse nommée** | une affirmation vérifiable, **et la mesure qui la tuerait** | `CLAUDE.md` |
| 3. **Mesure faite** | la commande a tourné sur cette machine, la sortie est là | `CLAUDE.md`, l'hypothèse tranchée |
| 4. **Mécanisme éprouvé** | ça marche, c'est extrait, c'est réutilisable | `grimoire/` avec `PREUVE:` datée |

**Tu ne montes jamais deux barreaux d'un coup.** Le barreau 4 n'est pas ton
travail : c'est celui de l'Alchimiste, et il ne peut le faire qu'après le 3.

Ce que tu ne peux pas mesurer toi-même reste au barreau 2 — et c'est un
résultat, pas un échec. Une hypothèse nommée avec sa mesure vaut infiniment
mieux qu'une affirmation confiante.

---

## Les trois pièges, tous déjà payés ici

### « le fichier le dit » n'est pas « la machine le fait »

`waydroid.cfg` annonçait `ro.sf.lcd_density=140` pendant qu'Android rendait à
180. Le réglage était écrit, lu, correct — et sans effet, parce que la session
en cours l'avait chargé avant.

> **Le test :** ne lis jamais le réglage, lis **l'effet**. Pas `cat` sur la
> configuration : la commande qui interroge le système qui l'applique.

### « je ne peux pas voir » n'est pas « il n'y a rien »

Un `test -d` a échoué faute de droits, et le geste a annoncé une panne
inexistante — **avec assurance et une cause inventée**. Le répertoire existait.

> **Le test :** devant une absence, distingue toujours *absent*, *invisible* et
> *interdit*. `ls` qui échoue et `ls` qui rend le vide ne disent pas la même
> chose. Vérifie le code de retour ET le message d'erreur, jamais l'un seul.

### La provenance n'est pas la signature

Développé dans [`code-noir.md`](code-noir.md).

---

## Et le piège qui les contient tous : le succès silencieux

> *Le pire résultat n'est pas l'échec, c'est le succès silencieux.*

Ce dépôt en collectionne : un `chown` qui annonçait « appartient désormais à
RyuRex » en visant le répertoire de service d'autofs ; un `lsblk` qui ne
retrouvait pas l'étiquette qu'il venait d'écrire, parce qu'il lisait le cache
d'udev ; une recette de capture d'écran qui rendait une image et un code 0
pour une classe de fenêtre **inexistante**.

**Un code de retour 0 n'est pas une preuve.** La preuve, c'est l'effet observé
par un chemin différent de celui qui l'a produit :

- écrit un fichier ? **relis-le depuis l'autre côté** (Linux écrit, Android
  lit) ;
- posé une règle ? **provoque le cas qu'elle gouverne** ;
- publié un service D-Bus ? **appelle-le depuis un autre processus** ;
- corrigé un affichage ? **une capture datée**, ce que la Galerie exige.

Et quand tu écris une vérification, éprouve-la d'abord **contre un cas qui doit
échouer**. Le garde `plasma_waitforname` du 2026-08-25 passait au vert en se
reconnaissant lui-même dans son propre commentaire ; il ne gardait rien.

---

## La forme d'une hypothèse nommée dans `CLAUDE.md`

Quatre lignes, jamais moins :

```markdown
**Hypothèse — <l'affirmation, en une phrase tranchée>.**
*Source :* <ce que tu as ouvert : fichier amont, doc datée, version>
*Ce que ça impliquerait ici :* <la conséquence concrète pour S>
*La mesure qui la tue :* `<la commande exacte>` → <ce qu'elle rendrait si l'hypothèse est fausse>
```

Le quatrième point n'est pas décoratif : **une hypothèse sans sa mesure n'est
pas une hypothèse, c'est une opinion**, et elle n'entre pas dans le carnet.

Le jour où la mesure est faite, on ne supprime pas l'entrée : on la **barre**
et on écrit le verdict à la suite. `CLAUDE.md` est plein de `~~texte barré~~`
suivi de la correction datée, et c'est délibéré — la piste fermée doit rester
visible, sinon quelqu'un la rouvrira.

**Une hypothèse réfutée est un bon résultat.** Ce carnet en compte des
dizaines ; chacune a économisé la journée qu'aurait coûtée la vérifier deux
fois.

---

## Un cas travaillé, de bout en bout

**Barreau 1 — trouvaille.** Un relevé sur la machine : `2792 paquets, 2691
sans signature PGP`.

**Barreau 2 — hypothèse nommée.** *« La chaîne de construction de S perd les
signatures des paquets Fedora. »* Conséquence : on ne saurait pas dire d'où
vient 96 % du système. Mesure qui la tue : lancer la même commande dans un
Fedora 44 pur — si elle rend le même vide, l'hypothèse est fausse.

**Barreau 3 — mesure.**

```bash
podman run --rm registry.fedoraproject.org/fedora:44 rpm -qi bash | grep Signature
→ Signature   :
```

Même vide. **Hypothèse morte** : la propriété vient des images Fedora, pas de
S. Écrit dans le carnet, barré, daté.

**Barreau 4 — n'a pas lieu.** Rien n'entre au Grimoire : il n'y a aucun
mécanisme, seulement une piste fermée. Et c'est le déroulement normal — *la
plupart de tes enquêtes s'arrêtent au barreau 3, et elles ont pourtant servi*.

Ce qui **est** resté de cette passe, en revanche, c'est le constat voisin que
la même enquête a mis au jour et que la mesure n'a pas réfuté : l'image de S
n'est ni signée ni vérifiée. Voir [`code-noir.md`](code-noir.md).

> **Chercher ne rapporte pas toujours ce qu'on cherchait.** C'est même le cas
> le plus fréquent, et le plus utile.
