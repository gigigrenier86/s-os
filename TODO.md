# Entretien du 2026-08-26 — ce que l'utilisateur veut de S

Réponses aux 40 questions posées pour cerner la direction du projet, prises en
note au fil de l'eau. But : en tirer une liste de tâches concrètes une fois
l'entretien terminé — ce fichier n'est pas un journal de mesures comme
`CLAUDE.md`, c'est une capture de priorités et d'intentions.

---

## Réponses

**1. Depuis combien de temps utilises-tu S comme poste principal, vs. juste pour le développer ?**
> Pour l'instant, juste pour le développer.

**2. Que fais-tu en premier en t'assoyant devant la machine, dans une journée normale ?**
> Présentement on code ensemble, aussitôt que possible. Avant, il écoutait des animes japonais tout le temps.

*Réflexion : le rituel d'ouverture de session est en train de changer de nature — de la consommation passive (anime) vers la construction active (coder S). Vaut la peine de garder en tête pour toute décision d'ergonomie du bureau : l'usage réel, aujourd'hui, c'est développer, pas encore « vivre » sur la machine.*

**3. Y a-t-il une tâche que tu fais encore sur un autre appareil parce que S n'est pas prêt pour elle ?**
> RetroArch, Zoom et la webcam (image/son).

*Réflexion : RetroArch et Zoom sont pourtant déjà posés et mesurés fonctionnels dans le carnet (jalon 2/3) — donc soit l'usage réel révèle un défaut non capturé, soit ils sont utilisés ailleurs par habitude plutôt que par nécessité. À clarifier. La webcam (image et son), elle, n'a JAMAIS été mesurée nulle part dans ce carnet — trou complet, à ajouter aux chantiers non commencés.*

**4. Qu'est-ce qui te ferait dire « S est fini » ?**
> Tout est fluide, fonctionnel, innovant, le fun à utiliser et bien pratique, rapide surtout.

*Réflexion : pas une checklist de fonctionnalités — une sensation. Cinq mots-clés à retenir comme critères transversaux pour juger tout futur chantier : fluide, fonctionnel, innovant, agréable, rapide. La vitesse revient deux fois (« rapide surtout ») — c'est le critère qu'il pèse le plus.*

**5. Combien de temps par jour, réaliste, tu comptes y passer une fois que ça roule ?**
> Si tout roule bien, beaucoup de temps — mais du temps bien plus satisfaisant que sur une seule OS.

*Réflexion : la valeur qu'il vise n'est pas « autant de temps qu'avant », c'est la qualité de ce temps — la satisfaction vient précisément du fait d'avoir les trois mondes réunis, pas d'un seul. Ça confirme que la couture entre les mondes EST le produit, pas un à-côté.*

**6. Lineage II sur serveurs privés sans anti-triche — déjà essayé depuis S ?**
> Je vais essayer.

*Réflexion : jamais fait. Chantier ouvert, à planifier — c'est la raison d'être historique du choix « bascule vers des serveurs privés sans anti-triche » dans les limites connues d'avance du projet, et elle n'a toujours pas été éprouvée une seule fois.*

**7. PC Boost et RapidO — fréquence d'usage réelle ?**
> RapidO souvent, c'est mon réel travail — mais j'ai développé mon app moi-même. PC Boost a du potentiel infini.

*Réflexion : RapidO est déjà résolu et posé (c'est une fenêtre Vivaldi `--app`, donc 100 % côté Linux — pas Wine, pas de risque Windows) et c'est du VRAI usage quotidien de travail, pas un test. C'est donc déjà une réussite silencieuse du projet, à ne jamais casser en y touchant. PC Boost, lui, tourne sous Proton/WPF et « a du potentiel infini » selon l'utilisateur — signal clair que c'est un logiciel à faire grandir, pas juste à faire fonctionner une fois.*

**8. Autres logiciels Windows précis à tester ?**
> Microsoft Store, et que tout fonctionne.

*Réflexion : nouveau chantier jamais évoqué dans le carnet — les applications du Microsoft Store sont empaquetées en MSIX/UWP, un format différent d'un `.exe` classique, avec ses propres exigences (souvent liées à des services Windows non présents sous Wine). `s-ouvrir-exe` et `s-menu-windows` ne couvrent que les `.exe`/`.msi` aujourd'hui — le Store est un mécanisme entièrement différent, jamais abordé.*

**9. Le ralentissement de Windows sur la Seagate — senti au quotidien ?**
> Je ne le sens pas, je n'y vais pas.

*Réflexion : cohérent avec la réponse 7 — RapidO ne touche jamais Windows/Proton, donc le seul gros utilisateur régulier du monde Windows serait PC Boost, et visiblement l'utilisateur n'y va pas souvent en ce moment. Donc la lenteur de la Seagate reste théorique pour l'instant, pas vécue — mais deviendra un problème réel le jour où PC Boost (potentiel infini, réponse 7) prend plus de place.*

**10. PURPLE (lanceur NCSoft bloqué à l'écran de démarrage) — encore un chantier ouvert ?**
> Il semble difficile, mais je l'ai déjà ouvert et vu la demande de connexion — elle ne se rendait pas.

*Réflexion : INFORMATION NEUVE, absente du carnet. Le carnet dit seulement « stagne sur son écran de démarrage, sans erreur » et suppose qu'il « attend probablement quelque chose du réseau ». L'utilisateur confirme avoir VU une demande de connexion apparaître — donc PURPLE tente bien un appel réseau, mais celui-ci n'aboutit pas. Piste concrète à suivre : capturer le trafic réseau du préfixe Wine pendant le lancement (`iptables`/`nft` en écoute, ou un simple `strace` sur les appels socket) pour voir si la requête sort du conteneur/préfixe et où elle meurt.*

---

## To-do list — tirée des 10 premières réponses

### Chantiers jamais commencés
- [ ] **Webcam (image et son)** sur S — aucune mesure nulle part dans le carnet. (Q3)
- [ ] **Microsoft Store / applications MSIX-UWP** sous Wine/Proton — mécanisme entièrement différent des `.exe`, jamais abordé. (Q8)
- [ ] **Lineage II sur serveur privé sans anti-triche** — jamais essayé, alors que c'est la raison d'être de la décision « bascule serveurs privés » dans les limites connues du projet. (Q6)

### Chantiers rouverts avec une piste neuve
- [ ] **PURPLE / NCSoft** — la demande de connexion apparaît mais n'aboutit pas. Prochaine étape : tracer le trafic réseau du préfixe Wine pendant le lancement pour voir où ça meurt. (Q10)

### À clarifier avant d'agir
- [ ] Pourquoi RetroArch et Zoom, déjà mesurés fonctionnels, sont encore utilisés ailleurs — habitude, ou défaut non capturé ? (Q3)

### Priorités confirmées à ne jamais casser
- [x] **RapidO** — vérifié le 2026-08-26 au soir, pas juste supposé fonctionnel. Un vrai défaut dormant trouvé et corrigé : `--class=RapidO` n'avait jamais eu d'effet, la fenêtre portait en réalité `vivaldi-app.mews.com__-Default`. Corrigé dans `rapido.desktop` (et `gemini.desktop`, même patron), méthode de mesure au Grimoire (`vivaldi-classe-reelle-app.sh`). **Reste à faire :** construire l'image et redémarrer dessus pour que le correctif serve vraiment ; et l'utilisateur doit encore passer l'écran « Autoriser cet appareil ? » de MEWS, une fois, à la main. Voir CLAUDE.md, 2026-08-26, 21 h 45.
- [x] **PC Boost** — priorité 2. Posé dans le Windows de S pour la première fois, exactement comme s'il avait été « installé » : binaire copié dans `Program Files\PcBoost\`, lancé et vérifié en vie via `s-ouvrir-exe` (fenêtre `steam_proton | PC Boost` mesurée), lanceur posé par la même fonction que Cursor/PURPLE. Icône générique — attendu, le `.csproj` n'en déclare pas. Voir CLAUDE.md, 2026-08-26, 22 h. **L'étoile, elle, avait échoué le soir même** — posée sous le mauvais identifiant (celui de Cursor, à cause d'un `grep` multi-fichiers mal lu), trouvé et corrigé après le redémarrage. Vrai identifiant : `s-windows-cafb8de64966`. **Reste à faire :** aucune fonction de PC Boost n'a été exercée, seulement son lancement ; et la copie posée se périme à chaque recompilation, sans mécanisme de mise à jour — à recopier à la main après chaque build tant que rien de mieux n'existe.

### Signal de fond pour toute décision future
- Grille de jugement : **fluide, fonctionnel, innovant, agréable, rapide** — la vitesse est le critère qui pèse le plus. (Q4)
- Ce que la machine vaut, ce n'est pas le temps qu'on y passe, c'est la satisfaction d'avoir les trois mondes réunis — la couture EST le produit. (Q5)
- **PC Boost** est vu comme ayant un « potentiel infini » — candidat naturel pour du développement futur, pas juste du support. (Q7)

---

## LA SUITE — enregistré le 2026-08-26 avant une construction + redémarrage

L'utilisateur a demandé de sauvegarder ce qui reste à faire avant de
construire et redémarrer, parce qu'un redémarrage coupe cette session. Ordre
de reprise, tel que confirmé dans la conversation :

1. **La barre latérale qui s'ouvre trop tôt** — corrigée dans le dépôt
   (`BarreLaterale.qml`, `epaisseurLigne` 5 px → 1 px), **jamais testée en
   vrai**, ni au banc ni sur la machine. C'est la construction en cours qui
   doit le prouver. Voir CLAUDE.md pour la mesure exacte à refaire après
   redémarrage : pousser la souris dans le coin droit et vérifier qu'elle ne
   s'ouvre qu'au tout dernier pixel, pas en travers d'un survol de passage.
2. **Le mécanisme de mise à jour de PC Boost** — l'utilisateur a confirmé
   « ben oui ça vaut la peine » juste avant de signaler le bug de la barre.
   **Pas commencé.** Le besoin : la copie posée dans
   `.../pfx/dosdevices/c:/Program Files/PcBoost/` se périge à chaque
   recompilation de `~/Downloads/PcBoostApp`, et rien ne la resynchronise. Une
   piste à explorer en premier plutôt qu'à supposer : un service ou un geste
   qui compare la date du binaire compilé à celle de la copie posée, et
   recopie s'il y a divergence — dans l'esprit de ce que `s-partage` fait déjà
   pour d'autres coutures.
3. **Après le redémarrage, revérifier ce qui a été touché ce soir** — RapidO
   (`StartupWMClass` corrigé), PC Boost (lanceur et étoile posés), et la barre
   latérale, tous corrigés dans le dépôt mais mesurés au mieux une fois avant
   la construction. La règle habituelle de ce carnet s'applique : ce qui n'a
   pas tourné depuis l'image ne compte pas comme prouvé.
4. **Les questions 11 à 40 de l'entretien** restent en attente plus haut dans
   ce fichier, inchangées.

---

## Questions 11 à 40 — en attente, gardées en mémoire pour une prochaine passe

**Android**
11. Usage concret d'Android sur S — quelles applications, quel usage ?
12. Le glitch d'affichage jamais diagnostiqué — encore gênant, ou contourné ?
13. Le Play Store est enregistré, 32 applications installées — il en manque ?
14. Mode fenêtré ou plein écran préféré au quotidien ?

**Constellation — le bureau**
15. Le ciel qui porte des fichiers, le clic droit, la barre latérale — essayés depuis le redémarrage de ce soir ?
16. Un geste courant sur un bureau normal qui manque encore à Constellation ?
17. Le rangement des étoiles (grossir à l'usage, fusionner en amas) — vraiment utile, ou gadget ?
18. Constellation doit ressembler à quelque chose de précis, ou son identité actuelle convient ?
19. La barre latérale à 76px, ses neuf réglages — il en manque un ?

**L'accès distant**
20. Le travail depuis le téléphone — besoin réel et proche, ou capacité « au cas où » ?
21. `authorized_keys` ou ACL Tailscale SSH — et pourquoi l'un plutôt que l'autre ?
22. Depuis quel appareil le plus souvent — Pixel, autre ordinateur, autre chose ?
23. À distance, juste discuter avec moi, ou aussi piloter/surveiller la machine ?

**Sécurité, mises à jour, filet de sécurité**
24. Garder la mise à jour automatique nocturne, ou préférer la déclencher soi-même ?
25. Confiance suffisante dans `bootc rollback`, ou encore plus de filets voulus avant de laisser la machine évoluer seule ?
26. Le dépôt public sur GitHub — choix confortable et assumé, ou ça dérange ?

**Le dossier partagé et les trois mondes**
27. Le presse-papiers Linux↔Android — utilisé souvent, dans les deux sens ?
28. Une couture manquante entre deux mondes qu'il voudrait voir (ex. Windows↔Android direct) ?
29. `~/Partage` — utilisé comme prévu, ou un autre usage a émergé ?

**Le carnet et la méthode**
30. Ce carnet énorme — relu vraiment, ou surtout une mémoire pour moi ?
31. Le niveau de détail (mesures, PREUVE:, hypothèses réfutées) — utile au quotidien, ou juste pour la rigueur ?
32. Résumer périodiquement le carnet pour le garder lisible, ou sa croissance ne dérange pas ?

**Priorités et prochaines étapes**
33. Une seule chose à finir cette semaine — laquelle ?
34. Stabiliser l'existant vs. ajouter du neuf — où est le curseur en ce moment ?
35. Un chantier abandonné en cours de route qu'il voudrait reprendre ?
36. `uupd` sous la politique de signature stricte n'a jamais tourné pour de vrai — forcer un test cette nuit, ou attendre que ça arrive naturellement ?

**Vision à plus long terme**
37. D'autres personnes utiliseront S un jour, ou projet strictement personnel ?
38. Le jalon 6 (logo, greeter, écran d'amorçage) — pousser plus loin, ou l'essentiel y est déjà ?
39. Une fonctionnalité neuve, jamais mentionnée dans le carnet, gardée en tête depuis un moment ?

**Sur la façon de travailler ensemble**
40. Proposer et attendre le feu vert, ou avancer et montrer le résultat — ou ça dépend du risque de chaque geste ?

---

*Entretien en pause après 10 questions sur 40 — reprise possible à tout moment.*
