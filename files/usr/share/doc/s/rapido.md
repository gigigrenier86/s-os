# RapidO sur S

`rapido.desktop` est le portage de RapidO, l'application WPF du dépôt PC Boost.

**Le code d'origine ne peut pas être porté**, et il faut le dire nettement :

- **WPF n'existe pas sous Linux.** .NET y tourne très bien, mais WPF est une
  bibliothèque Windows et ne sera jamais portée. Le `.csproj` de RapidO cible
  d'ailleurs `net8.0-windows` avec `<UseWPF>true</UseWPF>`.
- **WebView2 est également Windows seul.** C'est une enveloppe autour du moteur
  Edge fourni par le système.

**Mais la raison d'être de RapidO est satisfaite ici sans écrire une ligne.**
Son propre `.csproj` la formule :

> « le moteur, lui, est le runtime WebView2 déjà installé par Windows. C'est
> toute la différence avec Electron, qui embarque son Chromium et pèse 225 Mo. »

C'est exactement ce que fait `vivaldi --app=` : une fenêtre sans chrome, servie
par le moteur du navigateur **déjà présent dans le système**. Aucun second
Chromium, aucun paquet supplémentaire.

396 lignes de WPF deviennent donc neuf lignes de `.desktop`.

**Ce qui est perdu :** `Perf.cs` et ses mesures — temps de navigation, mémoire
par processus, version du moteur affichée dans une barre d'état. Rien
n'empêchera de les retrouver plus tard ; ce ne sont pas les mêmes outils.

`--class=RapidO` et `StartupWMClass=RapidO` donnent à la fenêtre sa propre
identité dans la barre des tâches, au lieu de se confondre avec Vivaldi. C'est
ce qui fait qu'elle reste *une application*, et non un onglet déguisé.
