# Observations de l'utilisateur — a traiter (mis de cote le 2026-08-22)

**Rien n'a ete diagnostique ni corrige.** Ce fichier ne contient que le releve brut,
mis de cote parce que la limite de contexte etait atteinte. Reprendre d'ici.

## Le prompt, mot pour mot

> okay, voici mes observations, faut tu me regle tout ca ! je t'envoi aussi des images,
> tu devrais comprendre lesquelles vont ou selon ce que je dis : Je choisis install app.
> installes Android Platform tools
> Antigravity
>
> Asusctl et rog control center, avec erreurs, mais il inscrit installe. redemarrage
> necessaire car la petite fenetre 'close' ne fermait pas et empechais tout.
>
> Enable Bazzite CLI, il y a eu des erreurs que tu pourra voir sur les images, python
> aussi et une autre, inconnue, mais tu as une photo.
> encore une erreur, avec photo. regarde la chronologie des images, ca t'aidera a te situer.
>
> le demarrage est long.
>
> BoxTron = Creating Fedora, ca a dure vraiment longtemps, il y a une photo
>
> comme avec Fedora, quand termine, la fenetre de fin fige tout, je ne peu plus rien
> faire apart redemarrer
>
> RapidO ne se lance pas, avec image
>
> pareil pour Gemini et Vivaldi
>
> Ca semblait pareil pour zoom mais il a finalement ouvert donc Okay
>
> RetroArch fonctionne
>
> a chaque demarrage, la ligne : Added device Zram se fait a chaque fois
>
> Demarrages vraiment longs
>
> DaVinci Resolve ne fonctionne pas, meme principe de fenetre gelee que les 2 autres mais
> avec lui, je ne peux meme pas redemarrer, j'ai du forcer l'arret
>
> Antigravity Okay
>
> Bazaar s'ouvre mais ferme seul, je ne peux pas agir avec
>
> J'ai tente de faire une mise a jour, mais je n'avais probablement pas la bonne commande,
> Sudo est inneficace, il faudrait que l'utilisateur principaL soit root a la base
>
> Notre distrop s'appelle S, travaille avec LePeintre pour crecer NOTRE distro, pas bazzite,
> pas fedora, mais S

## Ce que les quinze photos montraient

Elles ne sont pas versionnees — **les redemander a l'utilisateur** au moment de reprendre.
Transcription de ce qui s'y lisait :

1. Console de demarrage : `[FAILED] Failed to start asusd.service - ASUS Notebook Control`,
   repete au moins six fois, plus `[DEPEND] asus-shutdown.service`. Wi-Fi `wlp2s0` s'associe.
2. Reglages Plasma en francais, page « Notifications du systeme ».
3. `Erreur — KIO Client : Impossible de trouver le programme « /usr/bin/vivaldi-stable »`,
   par-dessus l'installateur DaVinci Resolve du portail Bazzite.
4. CoolerControl : `error: Bus owner changed, aborting. This likely means the daemon crashed`
   puis `recipe 'install-coolercontrol' failed with exit code 1` — **c'est du `rpm-ostree`
   layering**, avec l'avertissement « This recipe will proceed to layer CoolerControl ».
5. Console : `EXT4-fs (sda3)`, `bazzite-hardware-setup.service/start running (2min 40s /
   17min 22s)`, `[FAILED] cardwired.service`, `[FAILED] tuned-ppd.service`, et
   `fedora-atomic-desktop-mandb-update.service/start running (2min 58s / no limit)`.
6. Console, autre demarrage : `tuned.service/start running (1min 30s / 2min 4s)`,
   uptime **186 s** au moment de `plymouth-quit`.
7-8. `recipe 'asus' failed with exit code 1` — cask Homebrew `rog-control-center-linux`,
   qui attend `asusctl-linux`, et `asusd.service` qui echoue.
9-12. Bazzite CLI / Homebrew : `Error: undefined method '[]' for nil` dans
   `Utils::Bottles.load_tab` (`bottles.rb:127`) — echoue sur `bat`, `eza`, `trash-cli` ;
   `python@3.14 has been deprecated` ; fin : ``brew bundle` failed! 4 Brewfile dependencies
   failed to install`. Brew vit dans `/var/home/linuxbrew`.
13. Boxtron : `Creating 'fedora' using image ghcr.io/ublue-os/fedora-toolbox:latest`,
    apres une longue copie de blobs.
14. Notification Plasma : **« Lancement de RapidO (En echec) — Impossible de trouver le
    programme /usr/bin/vivaldi-stable »**, horloge **20:04 le 21/08/2026**.

## Les fils a tirer, non verifies

- **La machine n'est pas la M720q.** `asusd`, `rog-control-center`, `wlp2s0`, ecran
  UltraGear : c'est un portable ASUS. Tout le carnet suppose la M720q — a relever avant
  d'interpreter quoi que ce soit.
- **`/usr/bin/vivaldi-stable` absent** casse RapidO, Gemini et Vivaldi d'un coup : les trois
  lanceurs pointent dessus. Le `tmpfiles.d` qui refait le pont `/var/opt/vivaldi ->
  /usr/lib/opt/vivaldi` est le premier suspect — **regarder la machine avant de conclure**
  (regle 7).
- **Le portail Bazzite (`ujust`, Brew, `rpm-ostree` layering) est le point commun** de
  presque toutes les pannes : asusctl, CoolerControl, Bazzite CLI, Boxtron, DaVinci. Ce
  n'est pas S qui echoue, c'est la couche amont — et la demande de l'utilisateur est
  justement de **ne plus passer par elle**.
- **Les fenetres de fin qui figent le bureau** : trois cas (asusctl, Boxtron, DaVinci),
  dont un a exige un arret force. A reproduire.
- **`sudo` inefficace** — l'utilisateur veut le compte principal administrateur. `wheel`
  a la creation du compte, ou une regle polkit dans l'image.
- **Demarrages longs** : `bazzite-hardware-setup` 2 min 40, `tuned` 1 min 30,
  `fedora-atomic-desktop-mandb-update` **sans limite** a 2 min 58, uptime 186 s au bureau.
- **« Added device zram » a chaque demarrage** : a qualifier — normal ou pas.
- **Jalon 6, demande explicite** : « notre distro s'appelle S, pas Bazzite, pas Fedora ».
  Avec LePeintre.

## Complement du 2026-08-22 au soir — la machine est identifiee

**« C'est le meme ordinateur »** — dit par l'utilisateur. Le portable ASUS des
photos et la machine de developpement Windows sont **une seule machine, en
double amorcage** : Windows sur le disque interne, S sur la Seagate par F12.
Ce n'est donc pas la M720q du carnet, et il n'y a pas de seconde machine.

Consequence qui change le carnet : **S a demarre sur du vrai materiel** — les
photos du 2026-08-21 20:04 montrent le bureau, RetroArch qui fonctionne, Zoom
qui s'ouvre. Le premier amorcage du jalon 3 a donc eu lieu, sur un portable
ASUS et non sur la M720q. A consigner proprement dans CLAUDE.md apres la
passe de diagnostic.

**Mesure en attente — la vitesse du demarrage.** L'image fait 35 s au banc ;
les ~3 min observees venaient des installations en chaine du portail Bazzite
(chaque layering rend le demarrage suivant « premier »), des services ASUS en
echec, et du plateau USB. A la prochaine session S, mesurer un SECOND
demarrage consecutif sans rien installer entre :

    systemd-analyze; systemd-analyze blame | head -15

et rapporter le resultat en photo. Si `fedora-atomic-desktop-mandb-update`
(vu a 2 min 58, « no limit ») s'avere bloquant, lui poser la meme limite que
`bazzite-hardware-setup` dans `10-base.sh`.
