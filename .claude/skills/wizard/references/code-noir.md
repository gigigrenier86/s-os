# Le Code Noir — la grille, et ce que cette machine a déjà répondu

Le Code Noir, c'est tout ce qui entre dans S en apportant un risque que
personne n'a regardé. Ta règle : **ne jamais le nommer sans l'expliquer**, et
ne jamais l'annoncer sans la mesure qui le confirme ou le tue.

---

## La règle qui gouverne toutes les autres

> **La provenance n'est pas la signature.**

« Ça vient de chez l'éditeur » ne vérifie rien : c'est une phrase sur l'origine,
pas une preuve de contenu. Tiens toujours **deux colonnes séparées** :

| D'où ça vient | Qu'est-ce qui l'a vérifié |
|---|---|
| une URL, un dépôt, un nom d'organisation | une signature, une somme de contrôle, une clé posée d'avance |

Une case remplie et l'autre vide, ce n'est pas « à moitié sûr ». C'est non
vérifié.

---

## La grille

| Forme | Ce que tu cherches | La commande qui tranche ici |
|---|---|---|
| **Dépendance abandonnée** | dernier commit, mainteneur unique, dernière version | date du dernier commit amont, `rpm -qi` (version, hôte de build) |
| **Provenance non vérifiable** | binaire tiré d'un lien direct, sans clé ni somme | lire le `build_files/*.sh` qui l'installe |
| **Dépôt de paquets ajouté** | qui le tient, `gpgcheck` actif, clé posée | voir *L'état des dépôts* ci-dessous |
| **Image de base** | signée ? vérifiée à la réception ? | voir *Le constat ouvert* ci-dessous |
| **Script tiré du web** | `curl … \| bash`, écriture hors du dossier annoncé | `grep -rn 'curl.*|.*sh' build_files/` |
| **Élévation de privilège** | `pkexec`, `sudo` dans un chemin non prévu | `grep -rn 'pkexec\|sudo' files/usr/bin/` |
| **Secret qui fuit** | clé, jeton, identifiant dans un fichier suivi | `git log -S'BEGIN OPENSSH'`, et la liste de `ou-chercher.md` |
| **Optimisation qui casse en silence** | une réécriture d'une ligne de l'amont | *la faute la plus chère de ce projet — voir plus bas* |

---

## L'état des dépôts — mesuré le 2026-08-25

Sur les **19** fichiers de `/etc/yum.repos.d/`, **4 sections seulement sont
actives**, et **toutes les quatre ont `gpgcheck=1`** :

```
fedora            gpgcheck=1     fedora.repo
updates           gpgcheck=1     fedora-updates.repo
updates-archive   gpgcheck=1     fedora-updates-archive.repo
terra-mesa        gpgcheck=1     terra-mesa.repo
```

Les COPR (`ublue-os`, `bieszczaders`, `negativo17`…) sont **désactivés sur la
machine** : ils ont servi à la construction, pas à l'exécution. Leurs clés
restent posées, ce qui est cohérent — les paquets qu'ils ont livrés sont
toujours là.

**Ce que S tire du web pendant sa construction**, relevé dans `build_files/` :
`repo.vivaldi.com`, `packages.microsoft.com`, `github.com`,
`downloads.claude.ai`, `zoom.us`, `us-central1-yum.pkg.dev`, `f-droid.org`,
`api.github.com`. Toute source ajoutée à cette liste est une décision de
sécurité, pas une commodité.

Pour revérifier :

```bash
grep -rhoE 'https?://[a-zA-Z0-9._~/-]+' build_files/*.sh Containerfile \
  | sed -E 's|(https?://[^/]+).*|\1|' | sort | uniq -c | sort -rn
```

---

## Le constat à moitié refermé : S signe son image depuis le 2026-08-26

> **Mise à jour du 2026-08-26.** La première moitié est faite : la construction
> **signe** désormais l'image, sans clé, par l'identité OIDC du workflow. Vérifié
> depuis la machine, code de retour **0** :
>
> ```bash
> cosign verify ghcr.io/gigigrenier86/s-os:latest \
>   --certificate-identity-regexp '^https://github.com/gigigrenier86/s-os/' \
>   --certificate-oidc-issuer https://token.actions.githubusercontent.com
> ```
>
> Le certificat prouve *ce dépôt, ce workflow, cette branche, ce commit* — plus
> précis qu'une clé partagée, et rien à garder ni à faire tourner.
>
> **Ce qui reste ouvert est la seconde moitié, et c'est une décision :**
> `policy.json` n'EXIGE toujours pas la signature, donc `rpm-ostree status` dit
> encore `ostree-unverified-registry`. Signer ne casse rien ; exiger peut
> empêcher une mise à jour ou un démarrage.
>
> **Et le contexte a changé la gravité du constat :** `uupd.timer` est actif sur
> la machine et tire `:latest` toutes les nuits vers 04 h 06, sans que personne
> décide. Ce n'était pas écrit dans le dépôt avant ce jour-là.

Le relevé d'origine, conservé parce qu'il dit pourquoi c'était vrai :

**Mesuré le 2026-08-25 au soir.**

Trois relevés qui concordent :

```
rpm-ostree status  →  ostree-unverified-registry:ghcr.io/gigigrenier86/s-os:latest
                          ^^^^^^^^^^ le transport le dit lui-meme
```

`/etc/containers/policy.json` — hérité de Bazzite — vérifie bien par sigstore
l'organisation amont :

```json
"ghcr.io/ublue-os": [{ "type": "sigstoreSigned",
                       "keyPaths": ["/etc/pki/containers/ublue-os.pub", …] }]
```

…mais `ghcr.io/gigigrenier86/s-os` ne correspond à aucune entrée nommée et
retombe donc sur :

```json
"": [{ "type": "insecureAcceptAnything" }]
```

Et le dépôt ne signe rien : `grep -rniE 'cosign|sigstore|signing'
.github/workflows/ Containerfile` **ne rend aucune ligne**, et
`/etc/pki/containers/` ne contient que les clés d'ublue-os et de toolbx.

**Ce que ça veut dire, en une phrase :** cette machine amorce ce que
`ghcr.io/gigigrenier86/s-os:latest` désigne au moment du `bootc upgrade`, sans
qu'aucune signature ne soit exigée. La confiance repose entièrement sur le
compte GitHub et sur le jeton d'Actions. **Ironie mesurée : S vérifie l'image
de son amont plus sévèrement que la sienne.**

**Ce que ça ne veut pas dire :** ni qu'une compromission a eu lieu, ni que le
registre est en danger. C'est une garantie absente, pas un incident.

**Le correctif existe et il est amont** — la génération d'une paire cosign et
l'étape de signature font partie du gabarit `ublue-os/image-template`, et
`policy.json` accepterait une entrée `ghcr.io/gigigrenier86` sur le même patron
que celle d'ublue-os. *On ne réimplémente pas ce que l'amont maintient* : c'est
son gabarit qu'il faut lire, pas une signature à inventer.

**La mesure qui dirait que c'est réglé :**

```bash
rpm-ostree status | grep -c 'ostree-unverified'      # doit tomber a 0
cosign verify --key cosign.pub ghcr.io/gigigrenier86/s-os:latest
```

---

## Le faux Code Noir du 2026-08-25 — et pourquoi il compte plus que le vrai

Un relevé sur cette machine :

```
2792 paquets, 2691 sans signature PGP
```

96 % du système « non signé ». Alarmant, net, chiffré — et **faux comme
constat sur S**.

Le contrôle qui l'a tué tient en une commande :

```bash
podman run --rm registry.fedoraproject.org/fedora:44 rpm -qi bash | grep Signature
→ Signature   :        (vide, exactement comme ici)
```

Un Fedora 44 **pur** rend le même résultat. L'en-tête de signature n'est donc
pas retenu dans la base RPM de ces images, chez l'amont comme ici : le relevé
ne mesure pas la sécurité de S, il mesure une propriété des images Fedora. Les
**101** paquets qui *portent* une signature sont ceux venus des COPR et de
Terra, ajoutés par-dessus.

**La leçon, et c'est la tienne :** un chiffre spectaculaire sans groupe témoin
n'est pas une mesure. Devant tout relevé alarmant sur S, la première question
est *« l'amont pur fait-il pareil ? »*, et `podman run --rm` y répond en deux
minutes. Sans ce contrôle, cette entrée aurait fini dans `CLAUDE.md` comme une
faille, et quelqu'un aurait passé une journée à « réparer » Fedora.

Une alerte réfutée proprement est un bon résultat. **Une alerte publiée sans
témoin est une dette.**

---

## Le Code Noir que ce projet a réellement payé

Il n'avait l'air de rien : `s-android` appelait `waydroid init -s GAPPS`.

La recette de l'amont, elle, passe les canaux en clair
(`/usr/share/ublue-os/just/82-bazzite-waydroid.just`). S avait **réécrit la
ligne en laissant tomber deux arguments** ; l'initialiseur s'arrêtait sur *« You
must provide 'System OTA' and 'Vendor OTA' URLs »*. **Cinq jours.** Et le
journal le disait depuis le premier soir.

C'est la forme de Code Noir la plus fréquente ici, et la moins spectaculaire :
non pas du code malveillant, mais **du code de l'amont réécrit de mémoire**.
Ton premier réflexe devant toute commande d'outil tiers dans ce dépôt est de la
comparer à la recette installée sur la machine.

```bash
grep -rn '<outil>' /usr/share/ublue-os/just/
```
