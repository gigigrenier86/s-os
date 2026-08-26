# Le Windows de S

## PC Boost — avant et apres, le meme programme, la meme machine

| | |
|---|---|
| `pcboost-avant-2026-08-26.png` | 2026-08-26, 22 h 47 |
| `pcboost-apres-2026-08-26.png` | 2026-08-26, 23 h 25 |

**Machine :** l'ordinateur de RyuRex — Intel Core i5-8400T, UHD Graphics 630,
Mesa 26.2.1, noyau `7.2.0-ogc6.1.fc44`. Rendu par la carte graphique reelle,
dans la session S, sur `kwin_wayland` par XWayland.

**Programme :** `PcBoostApp.exe`, un logiciel WPF/.NET 8 ecrit par
l'utilisateur, en publication autonome (`win-x64`, runtime embarque). Lance par
`s-ouvrir-exe` dans le prefixe `~/.local/share/S/windows`.

### Ce que les deux images montrent

Le meme programme, a trente-huit minutes d'intervalle, sans une ligne de son
code modifiee.

**Avant :** l'interface est deja juste — degrades, coins arrondis, la vague du
bas, la mise en page. Et **chaque icone est un carre vide**. La barre laterale
compte douze entrees et douze carres ; le bouton « Optimiser en 1 clic » n'a
pas son eclair ; les pastilles de theme n'ont ni coche ni engrenage.

**Apres :** maison, coeur, horloge, eclair, cadenas, globe — et la typographie
a change avec, parce que le texte est desormais rendu en vrai Segoe UI.

### Pourquoi, en une phrase

Le theme du programme demande `Segoe Fluent Icons, Segoe MDL2 Assets` et pointe
des caracteres de la zone privee Unicode. Le prefixe possedait dix-huit polices
et aucune Segoe. **Wine fournit un Windows vide** ; tout logiciel Windows
moderne suppose ces polices deja posees, et personne ne les posait.

`s-windows --polices` les emprunte au Windows sous licence de la machine, monte
en `/var/mnt/windows`, **et les declare au registre** — le second point est
celui qui compte : copier les fichiers seuls ne change rien, mesure a l'appui.

### Ce que ces images ne prouvent pas

- **Rien sur la vitesse.** Une capture ne montre pas 0,109 s contre 4,7 s ;
  ces chiffres sont dans `CLAUDE.md`, avec la facon dont ils ont ete pris.
- **Rien sur les autres logiciels.** Un programme qui n'emploie pas Segoe ne
  changera pas d'aspect.
- **Rien sur une machine sans Windows.** L'emprunt n'a de source que la ou un
  Windows est monte ; ailleurs, `s-windows --polices` le dit et s'arrete.

### Les polices ne sont pas dans ce depot, et ne doivent jamais y entrer

Segoe appartient a Microsoft. Ce depot est **public** : y deposer ces fichiers
serait une redistribution. Ils sont licencies avec le Windows de CETTE machine,
et c'est de la qu'ils viennent — copies vers le prefixe du meme utilisateur, sur
le meme disque.

**L'image transporte le geste ; les polices ne quittent pas la machine.** Les
captures ci-dessus montrent des glyphes rendus, pas des fichiers de police, et
c'est la difference qui rend leur publication legitime.


---

## PURPLE — la fenetre qui existait sans rien peindre

| | |
|---|---|
| `purple-2026-08-26.png` | 2026-08-26, 01 h 10 |

**Machine :** la meme — Intel Core i5-8400T, UHD Graphics 630, Mesa 26.2.1,
capture faite par kwin lui-meme sur la fenetre activee.

**Programme :** `PurpleLauncher.exe`, le lanceur de NCSoft. WPF, .NET
Framework 4.7.1, interface Chromium embarquee (CefSharp). Installe dans le
prefixe de S, lance par `s-ouvrir-exe`.

### Ce que l'image montre, et ce qu'elle a remplace

Le logo, le nom, la version, les boutons. Rien d'extraordinaire — sauf que
**pendant deux heures cette fenetre existait deja, a la bonne taille, et ne
contenait qu'une seule couleur distincte.** Noire.

WPF dessine par Direct3D 9. Quand ce chemin echoue sous Wine, la fenetre se
cree et ne peint pas. WPF porte un interrupteur de repli logiciel, et il
retablit tout.

### Le contre-exemple, qui est le vrai enseignement

| Couleurs distinctes | rendu materiel | rendu logiciel |
|---|---|---|
| PURPLE | **1** | **3133** |
| PcBoostApp | **6426** | zone centrale absente |

**Chacun marche dans le mode ou l'autre echoue.** Il n'existe donc pas de bon
reglage global — c'est un reglage par programme, et c'est pour ca que S offre
`s-windows --fenetre-noire`, nomme d'apres le symptome plutot que d'apres le
mecanisme.

### Ce que cette image ne prouve pas

- **Rien au-dela de l'ecran d'accueil.** Aucune connexion n'a ete tentee,
  aucun jeu n'a ete lance.
- **Rien sur PcBoostApp en rendu logiciel** : sa zone centrale etait vide a
  cinq secondes, et il n'a pas ete etabli si elle se remplit plus tard.
