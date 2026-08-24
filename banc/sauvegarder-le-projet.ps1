# Rassemble TOUT le projet S en un seul dossier, verifiable, pour qu'il
# survive au reformatage du NVMe et se retrouve intact depuis S.
#
#   powershell -ExecutionPolicy Bypass -File "C:\Users\Ghis\Desktop\S\banc\sauvegarder-le-projet.ps1"
#
# ASCII STRICT : voir l'en-tete de graver-iso-sur-cle.ps1.
#
# CE QUE CE SCRIPT SAUVE, ET POURQUOI CHAQUE MORCEAU
#
#   depot/          Le depot lui-meme, .git compris. Il est deja sur GitHub,
#                   mais un clone ne rend pas ce qui n'a jamais ete pousse, et
#                   S-vm/ n'est pas dans le depot du tout.
#   S-vm/           Le banc : cles SSH, journaux, captures, scripts. SANS les
#                   .qcow2, qui pesent 74 Go et se refabriquent depuis l'image
#                   publiee. C'est ici que vit la CLE PRIVEE du banc -- raison
#                   pour laquelle cette sauvegarde ne doit JAMAIS etre poussee
#                   sur un depot public.
#   claude/         La memoire et les transcriptions de Claude Code pour ce
#                   projet. Sans elles, la prochaine session repart sans savoir
#                   ce qui a ete appris ici.
#   photos/         Les quinze photos du PREMIER DEMARRAGE REEL du 2026-08-21.
#                   Le carnet les dit "non versionnees, a redemander" : elles
#                   etaient dans Downloads. Ce sont les seules images de ce
#                   soir-la.
#   vscode/         Les reglages de l'editeur et la liste des extensions.
#   MANIFESTE.txt   Chemin, taille et empreinte SHA-256 de chaque fichier.
#                   C'est ce qui permettra de dire, depuis S, si la copie est
#                   entiere -- plutot que de le supposer.
#
# CE QUE CE SCRIPT NE SAUVE PAS, ET IL FAUT LE DIRE : les trois .qcow2. Ils
# sont le seul banc ou "bootc rollback" restait exercable a froid. C'est une
# decision prise, pas un oubli.

[CmdletBinding()]
param(
    [string] $Vers = 'C:\S-sauvegarde',
    [switch] $SupprimerLesQcow2
)

$ErrorActionPreference = 'Stop'
function Dire($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

$PROJET = 'C:\Users\Ghis\Desktop\S'
$BANC   = 'C:\Users\Ghis\Desktop\S-vm'
$CLAUDE = "$env:USERPROFILE\.claude\projects\c--Users-Ghis-Desktop-S"
$VSCODE = "$env:APPDATA\Code\User"

Dire "=== Sauvegarde du projet S ===" 'Cyan'
Dire ("Destination : {0}" -f $Vers)
Dire ""

if (Test-Path $Vers) {
    # On ne fusionne pas en silence avec une sauvegarde precedente : deux etats
    # melanges ne sont plus un etat. On la date et on la met de cote.
    $vieux = "$Vers.precedente-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item -LiteralPath $Vers -Destination $vieux
    Dire ("Sauvegarde precedente mise de cote : {0}" -f $vieux) 'Yellow'
}
New-Item -ItemType Directory -Path $Vers -Force | Out-Null

# --- 1. Le depot ------------------------------------------------------------
Dire "1. Le depot (avec son .git)..." 'Cyan'
robocopy $PROJET "$Vers\depot" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "ECHEC : robocopy du depot, code $LASTEXITCODE" }
# Un bundle, en plus de la copie : un seul fichier qui contient TOUTE
# l'histoire et que "git clone" sait ouvrir. Si le .git copie s'abimait, il
# reste ca.
Push-Location $PROJET
try {
    & git bundle create "$Vers\depot-complet.bundle" --all 2>&1 | ForEach-Object { Dire "   $_" }
    $etat = (& git status --porcelain)
    if ($etat) { Dire "   ATTENTION : le depot a des modifications non commitees :" 'Yellow'; $etat | ForEach-Object { Dire "     $_" 'Yellow' } }
    else       { Dire "   depot propre, tout est commite" 'Green' }
    $enAvance = (& git rev-list --count '@{u}..HEAD' 2>$null)
    if ($enAvance -and $enAvance -ne '0') { Dire ("   ATTENTION : {0} commit(s) non pousse(s)" -f $enAvance) 'Yellow' }
    else { Dire "   tout est pousse sur GitHub" 'Green' }
} finally { Pop-Location }

# --- 2. Le banc, sans les images disque -------------------------------------
Dire "2. Le banc S-vm (sans les .qcow2)..." 'Cyan'
if (Test-Path $BANC) {
    robocopy $BANC "$Vers\S-vm" /E /XF *.qcow2 /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "ECHEC : robocopy du banc, code $LASTEXITCODE" }
    $q = @(Get-ChildItem $BANC -Recurse -Force -File -Filter *.qcow2)
    Dire ("   {0} .qcow2 laisses de cote, {1:N1} Go" -f $q.Count, (($q | Measure-Object Length -Sum).Sum/1GB)) 'Yellow'
} else { Dire "   S-vm absent" 'Yellow' }

# --- 3. La memoire de Claude Code -------------------------------------------
Dire "3. La memoire et les transcriptions..." 'Cyan'
if (Test-Path $CLAUDE) {
    robocopy $CLAUDE "$Vers\claude\projet" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "ECHEC : robocopy de .claude, code $LASTEXITCODE" }
    $m = @(Get-ChildItem "$Vers\claude\projet\memory" -File -ErrorAction SilentlyContinue)
    Dire ("   {0} souvenirs, {1} transcriptions" -f $m.Count, @(Get-ChildItem "$Vers\claude\projet" -Filter *.jsonl).Count) 'Green'
} else { Dire "   pas de dossier .claude pour ce projet" 'Yellow' }
foreach ($f in @("$env:USERPROFILE\.claude\settings.json", "$env:USERPROFILE\.claude\CLAUDE.md")) {
    if (Test-Path $f) { Copy-Item $f "$Vers\claude\" -Force }
}

# --- 4. Les photos du premier demarrage reel --------------------------------
Dire "4. Les photos du 2026-08-21..." 'Cyan'
New-Item -ItemType Directory -Path "$Vers\photos-premier-demarrage" -Force | Out-Null
$photos = @(Get-ChildItem "$env:USERPROFILE\Downloads" -File -Filter 'PXL_2026082*.jpg' -ErrorAction SilentlyContinue)
foreach ($p in $photos) { Copy-Item $p.FullName "$Vers\photos-premier-demarrage\" -Force }
Dire ("   {0} photos, {1:N0} Mo" -f $photos.Count, (($photos | Measure-Object Length -Sum).Sum/1MB)) 'Green'
# Les logos que l'utilisateur a fournis vivent hors du depot : ils y entrent aussi.
New-Item -ItemType Directory -Path "$Vers\logos-fournis" -Force | Out-Null
foreach ($p in @("$env:USERPROFILE\Pictures\Logo S.png", "$env:USERPROFILE\Downloads\Gemini_Generated_Image_aavrh2aavrh2aavr.jpg")) {
    if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p "$Vers\logos-fournis\" -Force }
}

# --- 5. VS Code -------------------------------------------------------------
Dire "5. Les reglages de VS Code..." 'Cyan'
New-Item -ItemType Directory -Path "$Vers\vscode" -Force | Out-Null
foreach ($n in @('settings.json','keybindings.json','argv.json')) {
    if (Test-Path "$VSCODE\$n") { Copy-Item "$VSCODE\$n" "$Vers\vscode\" -Force; Dire "   $n" 'Green' }
}
if (Test-Path "$VSCODE\snippets") { robocopy "$VSCODE\snippets" "$Vers\vscode\snippets" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null }
$code = Get-Command code -ErrorAction SilentlyContinue
if ($code) {
    & code --list-extensions 2>$null | Set-Content "$Vers\vscode\extensions.txt" -Encoding ascii
    Dire ("   {0} extensions listees" -f @(Get-Content "$Vers\vscode\extensions.txt" -ErrorAction SilentlyContinue).Count) 'Green'
} else {
    "code introuvable dans le PATH au moment de la sauvegarde" | Set-Content "$Vers\vscode\extensions.txt" -Encoding ascii
    Dire "   'code' absent du PATH -- liste d'extensions non prise" 'Yellow'
}

# --- 6. L'etat de la machine, tel qu'il est au moment de la sauvegarde ------
Dire "6. L'etat des disques..." 'Cyan'
$etatDisques = @()
$etatDisques += "# Etat des disques au $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$etatDisques += ""
$etatDisques += (Get-Disk | Select-Object Number,FriendlyName,SerialNumber,Size,PartitionStyle,BusType,IsBoot,IsSystem | Format-Table -AutoSize | Out-String -Width 200)
foreach ($d in Get-Disk) {
    $etatDisques += "## Disque $($d.Number) - $($d.FriendlyName) - $($d.Size) octets"
    $etatDisques += (Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue |
        Select-Object PartitionNumber,Size,Offset,Type,DriveLetter,GptType | Format-Table -AutoSize | Out-String -Width 200)
}
$etatDisques += "## Volumes"
$etatDisques += (Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,Size,SizeRemaining,UniqueId | Format-Table -AutoSize | Out-String -Width 250)
$etatDisques -join "`n" | Set-Content "$Vers\ETAT-DISQUES.txt" -Encoding utf8
Dire "   ETAT-DISQUES.txt ecrit" 'Green'

# --- 7. Le manifeste --------------------------------------------------------
# Sans lui, "la copie est arrivee" est une impression. Avec lui, c'est une
# verification -- et elle se refait depuis S par un seul sha256sum -c.
Dire "7. Empreintes..." 'Cyan'
$lignes = New-Object System.Collections.Generic.List[string]
$total = 0L
Get-ChildItem $Vers -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring($Vers.Length + 1).Replace('\','/')
    $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    $lignes.Add("$h  $rel")
    $total += $_.Length
}
$lignes | Set-Content "$Vers\MANIFESTE.sha256" -Encoding ascii
Dire ("   {0} fichiers, {1:N2} Go" -f $lignes.Count, ($total/1GB)) 'Green'

# --- 8. Le mode d'emploi ----------------------------------------------------
$lisez = @"
# La sauvegarde du projet S

Faite le $(Get-Date -Format 'yyyy-MM-dd a HH:mm') depuis Windows sur la M720q.

## Ce qu'il y a dedans

| Dossier | Quoi |
|---|---|
| depot/ | le depot S en entier, .git compris |
| depot-complet.bundle | toute l'histoire git en un fichier -- ``git clone depot-complet.bundle S`` |
| S-vm/ | le banc : cles SSH, journaux, captures. SANS les .qcow2 |
| claude/ | la memoire et les transcriptions de Claude Code pour ce projet |
| photos-premier-demarrage/ | les 15 photos du 2026-08-21 au soir |
| logos-fournis/ | les images de logo fournies hors depot |
| vscode/ | reglages et liste d'extensions |
| ETAT-DISQUES.txt | l'etat exact des trois disques au moment de la sauvegarde |
| MANIFESTE.sha256 | l'empreinte de chaque fichier |

## CE DOSSIER CONTIENT UNE CLE PRIVEE

``S-vm/cle-banc`` est la cle SSH du banc. Cette sauvegarde ne doit JAMAIS
etre poussee sur un depot public ni deposee sur un partage ouvert.

## Verifier depuis S que rien ne manque

``````bash
cd ~/Windows/S-sauvegarde        # ou que la copie ait atterri
sha256sum -c MANIFESTE.sha256 2>&1 | grep -v ': OK' | head
``````

Aucune ligne en sortie = tout est intact.

## Reprendre le travail sur S

``````bash
git clone ~/Windows/S-sauvegarde/depot-complet.bundle ~/S
cd ~/S && git remote set-url origin https://github.com/gigigrenier86/s-os.git
cp -r ~/Windows/S-sauvegarde/S-vm ~/S-vm
chmod 600 ~/S-vm/cle-banc
mkdir -p ~/.claude/projects/c--Users-Ghis-Desktop-S
cp -r ~/Windows/S-sauvegarde/claude/projet/* ~/.claude/projects/c--Users-Ghis-Desktop-S/
``````

Le nom du dossier de projet de Claude Code derive du CHEMIN : sur S le projet
ne sera plus a ``c:\Users\Ghis\Desktop\S``, donc le dossier attendu ne portera
plus ce nom. Il faudra renommer ``c--Users-Ghis-Desktop-S`` d'apres le nouveau
chemin -- sinon la memoire est la, et personne ne la lit.
"@
$lisez | Set-Content "$Vers\LISEZ-MOI.md" -Encoding utf8

Dire ""
Dire ("TERMINE : {0}" -f $Vers) 'Green'
Dire ("          {0} fichiers, {1:N2} Go" -f $lignes.Count, ($total/1GB)) 'Green'

# --- 9. Les .qcow2, si et seulement si on le demande ------------------------
if ($SupprimerLesQcow2) {
    Dire ""
    Dire "Suppression des images de banc..." 'Yellow'
    $q = @(Get-ChildItem $BANC -Recurse -Force -File -Filter *.qcow2 -ErrorAction SilentlyContinue)
    $poids = ($q | Measure-Object Length -Sum).Sum
    foreach ($f in $q) { Dire ("  - {0} ({1:N2} Go)" -f $f.Name, ($f.Length/1GB)) 'Yellow' }
    $avant = (Get-Volume -DriveLetter C).SizeRemaining
    foreach ($f in $q) { Remove-Item $f.FullName -Force }
    $apres = (Get-Volume -DriveLetter C).SizeRemaining
    Dire ("Supprime : {0:N2} Go. C: passe de {1:N1} a {2:N1} Go libres." -f `
          ($poids/1GB), ($avant/1GB), ($apres/1GB)) 'Green'
}
