# Où chercher — et l'ordre, qui ne commence pas sur le web

Sur ce projet, la réponse est **déjà sur la machine** bien plus souvent qu'on
ne le croit. Les cinq jours perdus sur Waydroid l'ont été parce que personne
n'a lu `/usr/share/ublue-os/just/82-bazzite-waydroid.just`, qui était posé là
depuis le premier jour et qui donnait la ligne exacte.

Descends les quatre étages dans l'ordre. Ne passe au suivant qu'en ayant
épuisé le précédent.

---

## 1. Le dépôt — parce qu'on l'a peut-être déjà résolu

`CLAUDE.md` fait plus de 4 000 lignes et il est écrit **du plus récent au plus
ancien**. Il n'est pas fait pour être lu ; il est fait pour être fouillé.

```bash
grep -n -i 'waydroid'  CLAUDE.md | head -40      # ce qu'on sait deja
grep -n '^## '         CLAUDE.md | head -30      # les sections, du plus recent
grep -rn 'PREUVE:'     grimoire/                 # ce qui a deja tourne
git log --oneline -40                            # ce qui a change et pourquoi
git log -S'multi_windows' --oneline              # QUAND une chaine est apparue
git log --diff-filter=D --name-only --oneline    # ce qui a ete supprime, et par qui
```

`git log -S` est l'outil le plus sous-utilisé du lot : il retrouve le commit
qui a introduit ou retiré une chaîne précise, donc **le message qui explique
pourquoi**. Les messages de commit de ce dépôt sont longs à dessein.

Les trois autres bibliothèques du dépôt :

| Dossier | Contenu | Règle d'entrée |
|---|---|---|
| `grimoire/` | mécanismes autonomes qu'on `source` | ligne `PREUVE:` datée |
| `galerie/` | réussites visuelles | capture datée nommant la machine |
| `banc/` | outils de banc, sauvegarde, manœuvres Windows | aucune |

---

## 2. La machine — parce que l'amont est installé, pas juste documenté

C'est l'étage le plus rentable, et le plus oublié. **Ce qui tourne ici est du
code lisible.**

**Les recettes de l'amont.** Bazzite livre ses propres gestes en clair :

```bash
ls /usr/share/ublue-os/just/                     # 28 fichiers, mesure le 2026-08-25
grep -rn 'waydroid' /usr/share/ublue-os/just/    # la ligne de commande officielle
ls /usr/share/ublue-os/                          # 19 entrees : configs, cles, defauts
```

**À quel paquet appartient ce fichier, et que livre-t-il d'autre :**

```bash
rpm -qf /usr/bin/waydroid                        # qui possede ce fichier
rpm -ql waydroid | grep -v '^/usr/share/doc'     # tout ce que le paquet pose
rpm -q --whatprovides 'python3.13dist(pyclip)'   # qui fournit cette dependance
rpm -q --requires waydroid                       # ce qu'il exige
rpm -qi waydroid                                 # version, vendeur, hote de build
```

**Les unités systemd, qui sont de la documentation exécutable :**

```bash
systemctl cat s-coquille.service                 # le fichier tel que systemd le lit
systemctl show s-session.target -p Wants -p After
ls /usr/lib/systemd/user/                        # 189 unites utilisateur presentes
```

**Les journaux — et sur S, celui de la coquille passe avant tout le reste :**

```bash
tail -80 ~/.local/state/s/coquille.log           # Constellation ecrit ici
tail -40 ~/.local/state/s/polkit.log
journalctl --user -b -u s-coquille --no-pager | tail -60
journalctl -b -p warning --no-pager | tail -60
```

> **Ce journal a eu raison de trois enquêtes le 2026-08-25** — le clic de la
> barre, le fond d'écran, l'épinglage. Les trois causes y étaient écrites,
> horodatées, avant que la recherche commence. **On l'ouvre en premier.**

**Ce que la machine exécute vraiment, par opposition à ce que le dépôt dit :**

```bash
rpm-ostree status                                # image booted + deploiement precedent
bootc status                                     # (exige root)
ls -l /usr/bin/s-*                               # les gestes reellement poses
diff <(cat files/usr/bin/s-android) /usr/bin/s-android
```

Ce dernier `diff` est la mesure la plus honnête du projet : il dit si ce que tu
lis dans le dépôt est ce que la machine exécute. **Souvent, non** — l'image en
cours a été construite avant le dernier commit.

---

## 3. L'amont du conteneur — parce que S n'est qu'une couche

```
Containerfile:17   FROM ghcr.io/ublue-os/bazzite:stable
```

Tout ce que S ne définit pas vient de là, et Bazzite vient lui-même de Fedora.
Avant d'accuser S d'un comportement, **vérifie que l'amont ne l'a pas déjà** :

```bash
podman run --rm ghcr.io/ublue-os/bazzite:stable <la commande qui doute>
podman run --rm registry.fedoraproject.org/fedora:44 <la meme>
```

**C'est le contrôle qui a tué l'alerte des paquets non signés** (voir
`code-noir.md`) : un Fedora pur rendait le même résultat, donc le résultat ne
disait rien de S. Deux minutes de `podman run` valent mieux qu'une journée
d'hypothèse.

Les dépôts de paquets, eux, sont lisibles sur la machine :

```bash
grep -l '^enabled=1' /etc/yum.repos.d/*.repo     # ce qui est reellement actif
rpm -qa gpg-pubkey --qf '%{SUMMARY}\n'           # les cles de confiance posees
```

---

## 4. Le web — en dernier, et jamais comme un fait

Quand les trois étages précédents sont vides, cherche dehors. Deux règles.

**Cite ce que tu as ouvert, pas ce dont tu te souviens.** Un fichier de code
amont, une page de documentation datée, un numéro de version. Une réponse de
forum sans date n'est pas une source.

**Et ce que tu rapportes est une hypothèse.** Elle ne devient un fait que
lorsque la machine l'a confirmée. Ce que ce dépôt collectionne — trois
douzaines d'entrées — ce sont des documentations exactes qui décrivaient une
machine qui n'était pas celle-ci. Voir `de-la-trouvaille-a-la-preuve.md`.

---

## Ce qui ne se cherche jamais dehors

Le dépôt `github.com/gigigrenier86/s-os` est **public**. Ces éléments ne
sortent pas de la machine, ne s'écrivent pas dans un commit, ne se collent pas
dans une recherche et ne s'affichent pas dans un rapport :

- `~/.ssh/id_ed25519` — la clé qui pousse vers `origin`
- `~/S-vm/cle-banc` — clé privée OpenSSH du banc QEMU
- `~/.claude/.credentials.json`
- tout ce qui vit sous `~/S-vm/` et `~/S-sauvegarde/`, non suivis par git

Et `~/Partage` porte une ACL `group:1023:rwx` — le groupe `media_rw`
d'Android. **Toute application Android ayant la permission de stockage y lit.**
Rien de sensible n'y est déposé, même temporairement.
