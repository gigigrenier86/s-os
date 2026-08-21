# Remet la Seagate de 5 To dans un etat sain : GPT, une seule partition sur
# TOUT le disque, NTFS en formatage rapide.
#
# A lancer depuis un terminal ADMINISTRATEUR :
#   powershell -ExecutionPolicy Bypass -File "C:\Users\Ghis\Desktop\S\banc\formater-seagate.ps1"
#
# ASCII STRICT : PowerShell 5.1 lit un .ps1 UTF-8 en CP1252, et un tiret
# cadratin y devient un delimiteur de chaine qui casse tout le fichier.
#
# POURQUOI CE SCRIPT EXISTE
# Le disque etait en MBR avec une partition de 2 048 Go. MBR ne sait pas
# adresser au-dela de 2 To : 2,5 To des 4,55 To etaient donc INACCESSIBLES.
# C'est ca, "le mauvais format" -- pas le systeme de fichiers.
#
# POURQUOI NTFS ET PAS EXFAT
# exFAT n'est pas journalise : un debranchement brutal peut corrompre le
# volume entier. NTFS l'est, et Linux le lit comme il l'ecrit (pilote ntfs3
# du noyau, present dans Bazzite). Le disque servant a la fois de stockage
# sous Windows et d'hote pour S, c'est le seul choix qui tienne des deux cotes.
$ErrorActionPreference = 'Stop'

# --- L'elevation d'abord, sinon Remove-Partition echoue par un message CIM
# obscur ("L'acces a une ressource CIM n'etait pas disponible pour le client")
# qui ne dit pas ce qui manque. On teste le ROLE, jamais le nom du groupe :
# sur un Windows francais il s'appelle "Administrateurs".
$moi = New-Object Security.Principal.WindowsPrincipal(
           [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $moi.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "REFUS : cette fenetre n'est pas elevee. Ouvrir un terminal ADMINISTRATEUR."
}

# --- Garde-fous sur la cible ------------------------------------------------
$d = Get-Disk -Number 1
Write-Host ("Cible  : disque {0} - {1}" -f $d.Number, $d.FriendlyName) -ForegroundColor Cyan
Write-Host ("Taille : {0} To - bus {1} - table {2}" -f `
    [math]::Round($d.Size/1TB,2), $d.BusType, $d.PartitionStyle) -ForegroundColor Cyan

if ($d.BusType -ne 'USB')      { throw "REFUS : le disque 1 n'est pas sur un bus USB." }
if ($d.IsBoot -or $d.IsSystem) { throw "REFUS : le disque 1 porte un role de demarrage." }
if ($d.Size -lt 4TB)           { throw "REFUS : le disque 1 ne fait pas 4,5 To, ce n'est pas la Seagate." }
if ($d.FriendlyName -notmatch 'Seagate') { throw "REFUS : le disque 1 n'est pas une Seagate." }

# On regarde ce qu'on s'apprete a detruire, plutot que de le supposer vide.
$occupe = 0
Get-Partition -DiskNumber 1 -ErrorAction SilentlyContinue |
    Get-Volume -ErrorAction SilentlyContinue |
    ForEach-Object { $occupe += ($_.Size - $_.SizeRemaining) }
Write-Host ("Occupe : {0} Mo de donnees sur ce disque" -f [math]::Round($occupe/1MB,1)) -ForegroundColor Cyan

Write-Host ""
Write-Host "Ce disque va etre ENTIEREMENT EFFACE et repartitionne." -ForegroundColor Yellow
$r = Read-Host "Taper exactement : EFFACER DISQUE 1"
if ($r -ne 'EFFACER DISQUE 1') { throw "Annule." }

# --- Le travail -------------------------------------------------------------
Get-Partition -DiskNumber 1 -ErrorAction SilentlyContinue | Remove-Partition -Confirm:$false
Write-Host "Partitions supprimees." -ForegroundColor Green

# Set-Disk refuse de convertir un disque qui porte encore des partitions, d'ou
# l'ordre. Et il faut relire le style : sur un disque neuf jamais initialise,
# la conversion se fait par Initialize-Disk et non par Set-Disk.
$style = (Get-Disk -Number 1).PartitionStyle
if ($style -eq 'RAW') {
    Initialize-Disk -Number 1 -PartitionStyle GPT
    Write-Host "Disque initialise en GPT." -ForegroundColor Green
} elseif ($style -ne 'GPT') {
    Set-Disk -Number 1 -PartitionStyle GPT
    Write-Host "Converti de $style en GPT." -ForegroundColor Green
} else {
    Write-Host "Deja en GPT." -ForegroundColor Green
}

$p = New-Partition -DiskNumber 1 -UseMaximumSize -AssignDriveLetter
Write-Host ("Partition creee : {0} To, lettre {1}:" -f `
    [math]::Round($p.Size/1TB,2), $p.DriveLetter) -ForegroundColor Green

# Format-Volume fait un formatage RAPIDE par defaut. Le complet exigerait -Full,
# et aurait demande 24 heures sur ce disque -- mesure : 24 Mo/s en soutenu.
$v = Format-Volume -Partition $p -FileSystem NTFS -NewFileSystemLabel 'SEAGATE' -Confirm:$false
Write-Host ""
Write-Host ("TERMINE : {0}: {1}, {2} To, etiquette {3}" -f `
    $v.DriveLetter, $v.FileSystem, [math]::Round($v.Size/1TB,2), $v.FileSystemLabel) -ForegroundColor Green

$gagne = [math]::Round(($v.Size - 2048GB)/1GB,0)
Write-Host ("Recupere par rapport a l'ancienne table MBR : {0} Go" -f $gagne) -ForegroundColor Green
