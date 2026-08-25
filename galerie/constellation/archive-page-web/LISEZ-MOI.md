# Constellation, premiere maniere : une page web

Ce dossier garde la version qui a tourne du **2026-08-22 au 2026-08-24** : une
page HTML servie en HTTP sur `127.0.0.1:7373` par `s-etoiles`, et affichee par
Vivaldi lance en `--app`.

Elle n'est plus dans l'image. Elle est ici parce que c'est la regle de la
Galerie : une reussite visuelle se garde, meme quand elle est remplacee.

## Pourquoi elle a ete remplacee

L'utilisateur l'a nomme en un mot : *« pas question de le faire tourner dans un
fureteur »*. Les trois consequences concretes, elles, etaient mesurables :

| | |
|---|---|
| Le bureau dependait de Vivaldi | une mise a jour du navigateur pouvait le casser |
| Un port ouvert pour se parler a soi-meme | et une verification d'en-tete `Host` pour s'en proteger |
| **Le clic droit etait celui du navigateur** | « Recharger », « Inspecter » — jamais « Epingler » |

## Ce qui en a ete repris, et ce qui a ete jete

**Repris tel quel :** toute la logique machine de `s-etoiles` — lecture des
`.desktop`, choix du monde, resolution des icones, lancement par `gio launch`,
gestes de session, temoin de sortie. Ce code avait deja tourne sur la machine ;
il vit maintenant dans `files/usr/lib/s/noyau.py`.

**Repris a l'identique :** les peintures de fond (`FONDS`) et les traces des
glyphes, portees dans `files/usr/share/s/constellation/qml/Fonds.js` et
`Glyphes.js`.

**Jete :** le serveur HTTP, l'injection dans la page, le repli sur les donnees
de vitrine. Un client natif appelle le noyau directement.

## La faire tourner quand meme

```bash
python3 galerie/constellation/archive-page-web/s-etoiles
# puis ouvrir http://127.0.0.1:7373/ dans n'importe quel navigateur
```
