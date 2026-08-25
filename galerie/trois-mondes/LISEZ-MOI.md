# Les trois mondes, dans une seule session

**La première fois que Linux, Windows et Android servent ensemble à l'écran, et
que ça se voit.**

Machine : **`s` — Lenovo ThinkCentre M720q**, i5-8400T, rendu par
**Mesa Intel UHD Graphics 630 (CFL GT2)**, pilote `i915`.
Ce n'est pas `llvmpipe` : la réserve *JAMAIS JUGÉE SUR GPU* que la Galerie
impose aux transparences et aux dégradés **tombe pour ces trois pièces**.

---

## `android-video-2026-08-25.png` — la pièce

Prise le **2026-08-25 à 19 h 15**.

Une vidéo YouTube joue, plein cadre et nette, dans une **fenêtre Android**. En
bas, la barre de S porte six tuiles : VS Code, Vivaldi, trois Konsole, et
YouTube en surbrillance.

**Ce qu'on ne voit pas est ce qui compte.** Aucune barre d'état d'Android,
aucune barre de navigation, aucun lanceur, aucun cadre de Waydroid. Une icône,
un clic, l'application — c'est la règle 9 du projet tenue jusqu'au bout :
*une couture ne montre jamais son moteur.*

Cette image est arrivée après **six hypothèses, dont cinq réfutées par la
mesure**. Elle vaut ce que valent les cinq réfutations : le mode employé est
`compositing_single_window_mode`, trouvé dans la table des symboles de
`hwcomposer.waydroid.so` — voir `CLAUDE.md`, section du 2026-08-25 au soir.

## `barre-trois-mondes-2026-08-25.png` — la barre, 17 h 31

Le ciel de Constellation avec ses étoiles et leurs compteurs d'usage, la barre
en bas avec ses épinglées, et **deux tuiles côte à côte : VS Code et YouTube**.
La première image du projet montrant une fenêtre Linux et une fenêtre Android
rapportées par la même barre.

Elle porte un rectangle sombre à la place de la vidéo. **C'est volontaire de la
garder** : c'est le défaut, photographié le jour où il a été compris.

## `le-trou-2026-08-25.png` — la preuve du défaut, 18 h 59

La fenêtre Android photographiée seule, pendant la panne. Tout ce que YouTube
dessine est là : vignettes, titres, commentaires, contrôles, **et même les
sous-titres écrits en plein milieu du vide**. La barre de progression avance.

**Une seule couche sur toutes celles de l'écran manque** — celle que la
`SurfaceView` de la vidéo produit. C'est cette image qui a écarté d'un coup les
codecs, le réseau, le son et l'application, et qui a ramené l'enquête sur le
compositeur.

*Une capture qui montre un défaut a sa place ici autant qu'une capture qui
montre une réussite — à condition qu'elle dise laquelle des deux elle est.*
