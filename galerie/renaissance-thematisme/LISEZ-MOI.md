# Renaissance Thématique — La Galerie de S

Création par **LePeintre** pour le bureau Constellation.

Quatre toiles procédurales peintes en direct sur le Canvas 2D de Constellation (`Fonds.js`), combinant matières, gradients radiaux étendus et constellations géométriques.

---

## Les Quatre Œuvres

### 1. 🌌 Cyber-Aurore (`aurore`)
- **Atmosphère** : Nuit polaire arctique traversée de voiles magnétiques boréaux.
- **Palette** :
  - Ciel d'obsidienne : `#030613`
  - Rideau émeraude : `rgba(38, 240, 165, 0.16)`
  - Faisceau cyan polaire : `rgba(30, 200, 255, 0.14)`
  - Voile violet spectral : `rgba(175, 55, 255, 0.13)`
- **Densité stellaire** : 1.1x (ciel riche et étincelant).
- **Rendu** : Une vibration douce et froide qui sublime les reflets de verre dépoli de la barre des tâches et du menu démarrer.

---

### 2. 🕰️ Astrolabe (`ambre`)
- **Atmosphère** : Horlogerie céleste d'époque, laiton brossé, cognac et lumière ambrée crépusculaire.
- **Palette** :
  - Dégradé zénithal : `#160a03` (base) -> `#0b0507` -> `#040205` (sommet)
  - Nébuleuses chaudes : Miel doré `rgba(255, 160, 45, 0.14)` et terracotta
  - Tracé astronomique : Cercles d'orbites et axe écliptique `rgba(255, 190, 80, 0.07)`
- **Densité stellaire** : 0.85x.
- **Rendu** : Un confort visuel chaleureux et reposant, parfait pour le travail de nuit sans fatigue oculaire.

---

### 3. 🌧️ Néo-Tokyo 2088 (`neotokyo`)
- **Atmosphère** : Métropole cyberpunk sous une pluie noire, reflets d'enseignes néon sur bitume mouillé.
- **Palette** :
  - Fond miroir sombre : `#030307`
  - Colonnes verticales néon : Magenta vibrant `rgba(255, 35, 135, 0.12)`, Cyan saturé `rgba(0, 225, 255, 0.10)`, Violet électrique `rgba(120, 60, 255, 0.11)`
  - Perspective au sol : Lignes de fuite `rgba(255, 40, 140, 0.045)` convergeant au tiers inférieur.
- **Densité stellaire** : 0.95x.
- **Rendu** : Électrisant et contrasté, faisant ressortir le liseré vif des applications et des astres.

---

### 4. 🗿 Monolithe (`monolithe`)
- **Atmosphère** : Pureté minérale brutaliste, titane et quartz fumé.
- **Palette** :
  - Cœur graphite : `#131418` en dégradé radial vers noir spatial absolu `#020204`.
  - Carroyage d'architecte : Trame de réticules et croix de visée discrètes `rgba(255, 255, 255, 0.06)` à intervalle régulier de 72 px.
- **Densité stellaire** : 0.6x (étoiles chirurgicales de haute précision).
- **Rendu** : Minimalisme absolu, zéro distraction, met en valeur les données et le code.

---

## Intégration dans le système

Ces thèmes sont injectés directement dans `Fonds.js` et exposés dans `Fonds.ORDRE`.
Ils s'affichent automatiquement dans le sélecteur visuel du menu des réglages de Constellation (Menu Démarrer > Réglages > Fonds d'écran), et s'activent d'un simple clic sans redémarrage.
