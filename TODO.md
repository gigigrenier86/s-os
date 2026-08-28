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

1. [x] **La barre latérale qui s'ouvrait trop tôt** — corrigée
   (`BarreLaterale.qml`, `epaisseurLigne` 5 px → 1 px), construite et
   déployée le 2026-08-27 matin (confirmée identique octet pour octet dans
   l'image `825b545` en cours). **Reste à essayer à la souris pour de vrai** —
   personne ne l'a encore fait : pousser la souris dans le coin droit et
   vérifier qu'elle ne s'ouvre qu'au tout dernier pixel, pas en travers d'un
   survol de passage.
2. [x] **Le mécanisme de mise à jour de PC Boost** — fait le 2026-08-27 à
   15 h 37, puis **étendu à 15 h 56** : `~/.local/bin/s-pcboost-lancer`
   compare maintenant le CODE SOURCE (pas juste un build déjà là) au dernier
   build, recompile avec le SDK .NET posé par Homebrew si besoin, resynchronise
   la copie posée, puis lance. Le vrai projet PC Boost (avec RapidO dedans, et
   quatorze fichiers non commités) a été importé depuis la Seagate dans
   `~/Projets/PcBoost` — voir CLAUDE.md, 2026-08-27, 15 h 56. Testé dans deux
   cas sur trois (rien ne change → rien ; source touchée → recompile et
   resynchronise) ; le troisième (échec de compilation) est raisonné, pas
   mesuré en vrai — un essai a expiré avant de conclure, sans dommage au
   fichier source (revérifié identique à sa sauvegarde).
   **C'est un fichier personnel, hors du dépôt S** — rien à construire, il
   sert déjà.
2bis. [x] **PC Boost voit le vrai matériel sous Wine** — fait le 2026-08-27 à
   16 h 20, demande explicite de l'utilisateur. WMI ne rend rien de fiable
   sous Wine (mesuré : `MemoryTopologyService` jette une `ManagementException`
   au démarrage). Un pont par fichier — `outils-linux/materiel-linux.py`
   (dans le dépôt PC Boost) écrit le vrai matériel Linux (`lspci`, `dmi`) en
   JSON, `LinuxHardwareInventoryService.cs` le lit — remplace WMI **pour la
   page Matériel seulement**. Détection Wine par deux sources (registre +
   export `ntdll.dll`), les deux d'accord. Éprouvé de bout en bout : le
   journal de PC Boost lui-même confirme « Environnement : Wine détecté ».
   Voir CLAUDE.md, 2026-08-27, 16 h 20.
2ter. [x] **Extension au maximum, avec verdict tranché** — fait le 2026-08-27
   à 16 h 33, demande de l'utilisateur (« on étend au max pour que TOUT
   fonctionne »), via le rôle Wizard. Les sept fichiers touchant WMI ont été
   lus un par un. **Trois étendus** : `MachineContextService` (châssis via
   `/sys/class/dmi/id/chassis_type`, lisible sans root ; mémoire via
   `/proc/meminfo`), `MemoryTopologyService` (dégrade proprement — le détail
   par barrette exige `dmidecode`, qui exige root, jamais demandé sans
   consentement), `WmiServiceManager` (les services Windows n'existent pas
   sous Wine, le dit clairement au lieu d'un WMI en échec). **Quatre laissés
   intacts, et c'est un verdict, pas un oubli** : `DeviceDriverProbe`,
   `DeviceHealth` (installation de pilotes Windows — n'a pas de sens sur du
   matériel piloté par le noyau Linux), `PowerShellRunner` (aucun
   `powershell.exe` dans le préfixe). Éprouvé en direct dans le vrai
   processus, journal à l'appui : `MachineContextService.Traits =
   DoubleAmorcage` (pas `Autonomie` — juste, la M720q Tiny n'est pas un
   portable), `MemoryTopologyService` rend `null` proprement,
   `WmiServiceManager` rend 11 entrées dont 0 présente. Voir CLAUDE.md,
   2026-08-27, 16 h 33. **Aucun écran de PC Boost n'a été regardé** — tout
   passe par le journal.
2quater. [x] **fwupd, la vraie réponse Linux au « téléchargement de
   pilotes »** — fait le 2026-08-27 à 22 h 07, demande explicite (« implante
   une détection matérielle, téléchargement de pilotes... »), rôle Wizard,
   modèle Opus. `fwupd` était déjà dans l'image (hérité de Bazzite) — pas
   réinventé, juste ponté : `outils-linux/pilotes-linux.py` lit
   `fwupdmgr get-devices`/`get-updates`, `LinuxFirmwareUpdateService.cs` le
   sert à PC Boost. **Ne fonde PAS avec le pont matériel existant** : le SSD
   porte `NVME\VEN_15B7&DEV_5006` côté fwupd et `PCI\VEN_15B7&DEV_5006` côté
   `lspci` — deux identifiants pour le même disque, jamais mesurés
   identiques, donc jamais forcés en une seule correspondance. Éprouvé en
   direct : le journal de PC Boost confirme 11 appareils, 0 mise à jour —
   identique à la mesure manuelle par `fwupdmgr`. **Trouvaille au passage :
   la M720q démarre en BIOS legacy, pas en UEFI**, jamais noté avant.
   **Ce qui manque, et c'est large :** aucune mise à jour réelle n'existe sur
   cette machine en ce moment, donc le chemin « clic → installation » n'a
   jamais pu être éprouvé et ne le sera pas tant qu'un vrai appareil n'a pas
   de mise à jour à proposer. Rien n'installe de firmware — lecture seule,
   volontairement, un firmware mal posé étant plus dur à défaire qu'un
   pilote Windows. Aucun écran de PC Boost n'affiche encore ce relevé. Voir
   CLAUDE.md, 2026-08-27, 22 h 07.
3. **Après le redémarrage, revérifier ce qui a été touché ce soir** — RapidO
   (`StartupWMClass` corrigé), PC Boost (lanceur et étoile posés), et la barre
   latérale, tous corrigés dans le dépôt mais mesurés au mieux une fois avant
   la construction. La règle habituelle de ce carnet s'applique : ce qui n'a
   pas tourné depuis l'image ne compte pas comme prouvé.
4. **Les questions 11 à 40 de l'entretien** restent en attente plus haut dans
   ce fichier, inchangées.

---

## Réponses — reprise du 2026-08-27

**11. Usage concret d'Android sur S — quelles applications, quel usage ?**
> Toutes les applications, Android dispose de plusieurs apps très intéressantes.

*Réflexion : réponse large, sans application précise nommée — ce qui laisse
les questions 12 et 13 faire le vrai travail de précision (quelles
applications survivent au glitch d'affichage jamais diagnostiqué, lesquelles
parmi les 32 déjà installées comptent vraiment au quotidien). Ce qui compte
déjà : Android n'est pas traité comme un monde annexe ou un test ponctuel ici,
c'est un usage large — au même titre que RapidO côté Linux (réponse 7). Ça
confirme la réponse 5 : la valeur de S vient des trois mondes réunis, et
Android y tient sa vraie place dans l'usage, pas seulement dans
l'architecture.*

**13. Le Play Store est enregistré, 32 applications installées — il en manque ?**
> Non mais j'ai installé Cap Player, qui fonctionne et est connecté, mais le
> menu de recherche est inefficace, je ne vois rien, exactement ce que je ne
> veux pas.

*Réflexion : rien ne manque au catalogue, mais un défaut concret apparaît —
Cap Player se connecte et fonctionne, et sa recherche interne ne rend rien.
Reste à établir si c'est un défaut de l'application elle-même (recherche
côté serveur cassée) ou un symptôme de l'environnement Waydroid — à vérifier
plutôt qu'à supposer. Nouveau chantier, jamais listé jusqu'ici.*

**14. Mode fenêtré ou plein écran préféré au quotidien ?**
> Je préfère avoir le choix.

*Réflexion : ne tranche pas en faveur d'un mode fixe — ça demande un réglage
accessible. Le carnet du 2026-08-25 a déjà établi que les deux modes sont
mutuellement exclusifs au niveau de Waydroid (`multi_windows` true/false,
sans variante intermédiaire), et que changer de mode exige un redémarrage de
la session Android, pas un simple clic. « Avoir le choix » veut donc dire un
réglage exposé quelque part (barre latérale ?), pas un choix par
application.*

**15. Le ciel qui porte des fichiers, le clic droit, la barre latérale — essayés depuis le redémarrage de ce soir ?**
> Oui, mais le clic droit sur le bureau ou sur les icônes de la constellation
> donnent le même résultat, rien de pratique, et aucun clic droit ne
> fonctionne sur les apps épinglées en bas.

*Réflexion : le clic droit existe (posé le 2026-08-25) mais seulement pour le
bureau lui-même — jamais contextualisé par étoile, et complètement absent sur
la barre des tâches. C'est exactement le trou que nomme la réponse 16 :
retirer une étoile, la replacer, l'effacer, l'exécuter en root sont des
gestes qui devraient dépendre de CE sur quoi on clique, pas d'un menu
générique répété partout.*

**16. Un geste courant sur un bureau normal qui manque encore à Constellation ?**
> Clic gauche et glisser pour sélectionner des icônes, clic droit sur les
> étoiles pour retirer ou placer sur le bureau, effacer, exécuter en root.

*Réflexion : quatre gestes nommés, tous absents aujourd'hui — la sélection
par glissement (rectangle de sélection), et un clic droit vraiment
contextuel par étoile (retirer/placer, effacer, exécuter en root) plutôt que
le menu unique et générique relevé à la réponse 15. Liste de travail
concrète pour Constellation, pas une plainte vague.*

**17. Le rangement des étoiles (grossir à l'usage, fusionner en amas) — vraiment utile, ou gadget ?**
> C'est ce qui donne son charme à ce bureau et qui le rend unique.

*Réflexion : verdict net — ce mécanisme n'est pas un gadget à simplifier ou
retirer, c'est l'identité même de Constellation. À protéger dans tout futur
chantier sur le bureau, au même titre que la règle « une couture ne montre
jamais son moteur ».*

**Code écrit pour 14, 15 et 16** — le 2026-08-27 au soir, sur la demande
« commence avec ce que tu as maintenant » : clic droit sur les épinglées de
la barre (n'existait pas du tout), « Executer en root » sur une étoile,
sélection au glissement sur le ciel, réglage Android fenêtré/plein écran.
Vérifié par le contrôle de construction sur cette machine (scène chargée,
zéro avertissement, menu de la barre toujours à 9 articles) — **aucun clic
réel, rien dans l'image.** Voir CLAUDE.md, 2026-08-27, soir.

---

## Questions 11 à 40 — en attente, gardées en mémoire pour une prochaine passe

**Android**
12. Le glitch d'affichage jamais diagnostiqué — encore gênant, ou contourné ?

**Constellation — le bureau**
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

*Entretien en pause après 16 questions sur 40 — reprise possible à tout moment
(la 12 reste ouverte, voir la note de clarification datée du 2026-08-27).*
