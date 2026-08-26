# La Galerie

L'identité visuelle de S — **jalon 6**. Chaque pièce y est rangée prête à
reposer, ailleurs et autrement.

Le Grimoire garde les mécanismes ; la Galerie garde les **apparences**. Les deux
règles d'entrée ne peuvent pas être les mêmes, et c'est tout l'objet de ce qui
suit.

---

## La règle d'entrée : une capture, sur le bon matériel

Une recette du Grimoire prouve qu'elle marche en rendant un code de sortie.
Une œuvre de la Galerie ne peut se prouver qu'**en se montrant**. D'où :

**Rien n'entre ici sans une capture datée, et la capture doit nommer la machine
qui l'a rendue.**

Et ce n'est pas de la bureaucratie, parce que ce projet s'est déjà fait avoir
deux fois par une image :

- Une capture noire a été lue comme « le bureau ne démarre pas ». C'était faux
  dans les deux moitiés : le bureau tournait, et la capture datait d'avant la
  création du compte. L'erreur a vécu quinze heures et essaimé dans deux autres
  sections du carnet. **Une capture noire prouve qu'on n'a rien vu, jamais qu'il
  n'y a rien.**
- Une seconde capture, prise pendant un diagnostic, a photographié l'éditeur de
  code au lieu de la machine virtuelle — `SetForegroundWindow` échoue en silence.
  Deux captures d'une machine **haltée** avaient donc des empreintes différentes,
  ce qui se lit « ça progresse ». Conclusion inverse de la vérité.

---

## Le banc ne peut pas juger la moitié de ce dossier

**Les essais tournent sur `llvmpipe`, le rendu logiciel de Mesa.** Il n'y a pas
de GPU dans QEMU. Tout s'affiche, tout est lent.

| Jugeable au banc | À réserver au vrai matériel |
|---|---|
| une couleur, un contraste | un flou d'arrière-plan |
| une disposition, une marge | une transparence |
| un logo, une icône, une police | une animation de fenêtre |
| un texte, une chaîne visible | une impression de fluidité |
| la présence d'un élément | le coût réel d'un effet |

**Le piège nommé d'avance :** un flou qui rame sous `llvmpipe` se lit « ce thème
est trop lourd ». C'est faux — c'est « il n'y a pas de carte graphique ». Le
projet a déjà mis quinze heures à cesser de confondre les deux. Toute pièce
touchant aux effets porte donc la mention **JAMAIS JUGÉE SUR GPU** jusqu'à ce
qu'un écran réel la contredise.

---

## Où ça se pose, et pourquoi ça compte plus qu'ailleurs

Un thème est fait de fichiers de configuration, et sur un système atomique
**c'est exactement la famille de fichiers qui disparaît sans prévenir.**

| Emplacement | Sort |
|---|---|
| `/usr/share/…` | **entre dans l'image**, survit à `bootc upgrade` |
| `/etc/…` | **entre dans l'image** — pas un lien, fusionné au déploiement |
| `/etc/skel/…` | entre dans l'image, mais **seulement pour les comptes créés après** |
| `~/.config/…` | **hors image**, propre à la machine, ne se transporte pas |
| `/usr/local`, `/opt` | **liens vers `/var`** — écrire y réussit et livre du vide |

Une commande `kwriteconfig` tapée dans un terminal produit un bureau superbe
qui disparaît à la mise à jour suivante. **Ce qui doit tenir va dans l'image.**

Et une limite à dire plutôt qu'à cacher : le compte `Ghis` existe **déjà**.
Tout ce qui passe par `/etc/skel` ne le touchera pas.

---

## Le principe qui gouverne tout le reste

**Une couture ne montre jamais son moteur.** C'est la règle 9 du carnet, née
d'un cas concret : `distrobox-export` nommait une calculatrice
« Galculator (on s-debian) » et posait en plus une icône pour le conteneur.
L'utilisateur avait installé une calculatrice, pas un conteneur Debian.

Appliqué ici : **S ne doit annoncer ni Bazzite, ni Fedora, ni Wine, ni Waydroid,
ni Proton.** Non pour les cacher — le carnet les nomme, le dépôt est public et
les licences sont respectées — mais parce que l'utilisateur ouvre *un système*,
pas un empilement. Le moteur se lit dans la documentation, jamais dans la barre
des tâches.

---

## Les pièces

| Pièce | Ce que ça peint | Capture | Machine |
|---|---|---|---|
| **[constellation/](constellation/)** | Le bureau de S : un ciel, et les applications en étoiles | [constellation-2026-08-25.png](constellation/constellation-2026-08-25.png) | `s` — Intel UHD 630, pilote `i915` |
| **[trois-mondes/](trois-mondes/)** | Les trois mondes servis ensemble — et une vidéo Android qui joue enfin | [android-video-2026-08-25.png](trois-mondes/android-video-2026-08-25.png) | `s` — Intel UHD 630, pilote `i915` |
| **[windows/](windows/)** | Un logiciel WPF avant et après : douze carrés vides deviennent douze icônes | [pcboost-apres-2026-08-26.png](windows/pcboost-apres-2026-08-26.png) | `s` — Intel UHD 630, Mesa 26.2.1 |

### Constellation — la première pièce rendue par une vraie carte graphique

**Depuis le 2026-08-24, ce n'est plus une page web.** Constellation est un
client Wayland natif : un processus, une fenêtre, une scène QtQuick, qui appelle
le noyau de S dans son propre processus. Plus de serveur HTTP sur 127.0.0.1,
plus de port ouvert, plus de moteur de rendu web au démarrage de la session — et
plus de menu contextuel proposant « Recharger » et « Inspecter » là où
l'utilisateur cherchait « Épingler ».

Le dossier attendait sa capture depuis le 2026-08-22. **Elle a été prise le
2026-08-25 à 12 h 23, sur `s`, en 1920 × 1080, rendue par une Intel UHD 630 avec
le pilote `i915`.** Ce n'est pas `llvmpipe` : la réserve *JAMAIS JUGÉE SUR GPU*
tombe pour cette pièce, et ce qu'on voit est ce que la machine affiche.

Le détail de ce qu'elle montre — l'échelle logarithmique des étoiles, la couleur
des trois mondes, l'anneau, le fond peint une seule fois — est dans
[constellation/LISEZ-MOI.md](constellation/LISEZ-MOI.md).

La maquette d'origine reste rangée dans
[constellation/archive-page-web/](constellation/archive-page-web/) avec le pont
qui la servait : c'est d'elle que sort tout le vocabulaire visuel, et
`Theme.qml` en reprend la palette couleur pour couleur.

Publiée aussi ici : <https://claude.ai/code/artifact/92657e1b-fac5-449d-a5a4-492f09e252a8>

### Les trois mondes — la pièce qui prouve la promesse du projet

Prise le **2026-08-25 à 19 h 15**, sur `s`. Une vidéo YouTube joue plein cadre
dans une fenêtre Android, et la barre de S porte six tuiles venues de deux
mondes.

**Ce qu'on ne voit pas est ce qui compte** : aucune barre d'état d'Android,
aucune barre de navigation, aucun lanceur, aucun cadre de Waydroid. Une icône,
un clic, l'application. C'est la règle 9 — *une couture ne montre jamais son
moteur* — tenue jusqu'au bout, et c'est la demande de l'utilisateur mot pour
mot.

Le dossier garde aussi **deux captures du défaut**, prises le même soir, avant
que la cause soit trouvée. Elles restent parce qu'elles ont servi : c'est en
regardant `le-trou-2026-08-25.png` — où les sous-titres s'écrivent en plein
milieu du vide, par-dessus une vidéo absente — qu'on a écarté d'un coup les
codecs, le réseau, le son et l'application.

*Une capture qui montre un défaut a sa place ici autant qu'une capture qui
montre une réussite — à condition qu'elle dise laquelle des deux elle est.*

---

### Le Windows de S — la pièce qui montre une panne qu'on ne voyait pas

Deux captures du **même programme**, à trente-huit minutes d'écart, sans une
ligne de son code modifiée. C'est la seule pièce de cette Galerie qui se lit en
paire : isolée, l'image « avant » a l'air correcte.

`PcBoostApp` est un logiciel WPF/.NET 8 écrit par l'utilisateur. Il s'ouvrait,
il rendait ses dégradés, ses coins arrondis et sa mise en page — et **chaque
icône était un carré vide**. Douze entrées de barre latérale, douze carrés. Le
genre de défaut qu'on finit par ne plus voir.

Son thème demande `Segoe Fluent Icons, Segoe MDL2 Assets`. Le prefixe possédait
dix-huit polices et aucune Segoe : **Wine fournit un Windows vide**, et tout
logiciel Windows moderne suppose ces polices déjà posées.

Ce que la paire enseigne au-delà des icônes : **copier les fichiers de police
n'a rien changé**, et `wineboot -u` non plus. Il fallait les *déclarer* au
registre, sous leur vrai nom de famille — qui ne se déduit pas du nom du
fichier. La recette est au Grimoire (`windows-declarer-police.sh`) ; la mesure
qui l'a imposée est dans `CLAUDE.md`.

**Les polices ne sont pas dans ce dépôt et ne doivent jamais y entrer.** Elles
sont licenciées avec le Windows de cette machine, et c'est de là qu'elles
viennent. L'image transporte le geste ; les glyphes rendus se publient, les
fichiers non.

---

## La capture, elle-même, est une recette

Photographier la coquille demandait de résoudre trois pièges — l'API de capture
de kwin est réservée, « montrer le bureau » ne survit pas au démarrage de
l'outil de capture, et `spectacle -a` réussit même quand on a visé une fenêtre
qui n'existe pas. La marche à suivre est au Grimoire :
[kwin-capturer-la-coquille.sh](../grimoire/kwin-capturer-la-coquille.sh).

Elle ne réduit ni ne déplace aucune fenêtre : **une capture ne doit pas
réorganiser la session pour se réussir.**

---

## Ce qui existe déjà comme trace visuelle

Ce ne sont pas des œuvres — ce sont les **avant**, et ils valent d'être gardés
pour qu'on puisse mesurer le chemin.

| Image | Ce qu'elle montre | Rendu |
|---|---|---|
| [../bureau-2026-08-20.png](../bureau-2026-08-20.png) | Plasma, fond d'écran **de Bazzite**, Vivaldi et Steam en barre | `llvmpipe` |
| [../cle-ecran-accueil.png](../cle-ecran-accueil.png) | « Welcome to Plasma Desktop », bouton *Begin Setup* — **en anglais** | `llvmpipe` |
| [../cle-demarrage-console.png](../cle-demarrage-console.png) | La console de démarrage, qui dit **Bazzite** | texte |

Ces trois images disent la même chose : **S n'a pas encore de visage.**
