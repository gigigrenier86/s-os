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

### En attente de capture

**[constellation/](constellation/constellation.html)** — le bureau *Constellation*.

Elle **existe et tourne**, mais elle n'a pas encore été photographiée sur une
machine nommée, et la règle de cette Galerie ne se plie pas pour sa première
pièce. Elle montera dans le tableau dès qu'une capture datée la portera.

Publiée aussi ici : <https://claude.ai/code/artifact/92657e1b-fac5-449d-a5a4-492f09e252a8>

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
