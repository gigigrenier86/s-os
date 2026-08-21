# GRIMOIRE -- le preambule de tout script de banc Windows
# PREUVE : 2026-08-20/21. Chacun de ces blocs correspond a un mur reellement
#          rencontre, dans l'ordre ou ils sont tombes.
# POUR   : tout script PowerShell qui touche un disque physique ou lance QEMU.
#
# ASCII STRICT, ET CE FICHIER EST L'EXEMPLE. Windows PowerShell 5.1 lit un
# .ps1 UTF-8 en CP1252 : un tiret cadratin y devient un delimiteur de chaine
# et la ligne cesse d'etre analysee. Symptome typique : un
# "-ForegroundColor Cyan" affiche en clair au lieu d'etre applique.
# Aucun accent dans ce fichier, pas meme dans les commentaires.
#
# LES CINQ MURS, DANS L'ORDRE
#   1. La strategie d'execution refuse les .ps1
#        -> powershell -ExecutionPolicy Bypass -File "..."
#           leve la regle pour ce seul processus, sans rien changer a la machine.
#   2. Un .ps1 en UTF-8 casse sous PowerShell 5.1  -> ASCII strict, voir ci-dessus.
#   3. Windows refuse de mettre un media amovible hors ligne, et retirer la
#      lettre ne demonte PAS le volume -> il faut SUPPRIMER LA PARTITION.
#   4. L'acces brut a un disque physique exige l'elevation -> tester en TETE.
#   5. QEMU lance en processus enfant meurt avec sa fenetre -> Start-Process.

# ---------------------------------------------------------------------------
# 1. L'ELEVATION, TOUJOURS EN PREMIER
# ---------------------------------------------------------------------------
# Sans elle QEMU echoue par "Could not open device: Permission denied", mais
# TROIS ETAPES PLUS LOIN : le disque a deja ete efface et le message ne dit pas
# ce qui manque. Le refus doit tomber avant qu'on ait touche a quoi que ce soit.
#
# On teste le ROLE, jamais le nom du groupe : sur un Windows francais il
# s'appelle "Administrateurs", et comparer des noms rend faux.
function Assert-Elevation {
    $moi = New-Object Security.Principal.WindowsPrincipal(
               [Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $moi.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "REFUS : cette fenetre n'est pas elevee. Ouvrir un terminal ADMINISTRATEUR."
    }
}

# ---------------------------------------------------------------------------
# 2. IDENTIFIER LA CIBLE PAR PLUSIEURS PREUVES INDEPENDANTES
# ---------------------------------------------------------------------------
# Une seule erreur ici coute le Windows de la machine. La taille a l'octet est
# la preuve la plus forte : deux disques de modeles differents ne la partagent
# jamais par accident. Le bus et le role de demarrage la completent.
function Assert-DisqueCible {
    param(
        [Parameter(Mandatory)][int]    $Numero,
        [Parameter(Mandatory)][long]   $TailleExacte,
        [string] $BusAttendu = 'USB'
    )
    $d = Get-Disk -Number $Numero
    Write-Host ("Cible  : disque {0} - {1}" -f $d.Number, $d.FriendlyName)   -ForegroundColor Cyan
    Write-Host ("Taille : {0} octets - bus {1} - table {2}" -f $d.Size, $d.BusType, $d.PartitionStyle) -ForegroundColor Cyan
    Write-Host ("Secteur: logique {0} / physique {1}" -f $d.LogicalSectorSize, $d.PhysicalSectorSize)  -ForegroundColor Cyan

    if ($d.BusType -ne $BusAttendu)  { throw ("REFUS : le disque {0} n'est pas sur un bus {1}." -f $Numero, $BusAttendu) }
    if ($d.IsBoot -or $d.IsSystem)   { throw ("REFUS : le disque {0} porte un role de demarrage." -f $Numero) }
    if ($d.Size -ne $TailleExacte)   { throw ("REFUS : taille {0}, attendu {1}." -f $d.Size, $TailleExacte) }

    # Redondant avec le precedent, et c'est voulu : ne coute rien, et couvre le
    # cas ou les numeros de disque auraient bouge entre deux branchements.
    $sys = @(Get-Disk | Where-Object { $_.IsSystem -or $_.IsBoot } | ForEach-Object { $_.Number })
    if ($sys -contains $Numero) { throw ("REFUS : le disque {0} porte Windows." -f $Numero) }

    return $d
}

# ---------------------------------------------------------------------------
# 3. LIBERER LE DISQUE POUR DE VRAI
# ---------------------------------------------------------------------------
# Ce qui verrouille le disque physique n'est pas le disque mais le VOLUME monte
# dessus. Retirer la lettre enleve le point de montage, pas le montage : mesure
# le 2026-08-20, mountvol annoncait "Aucun point de montage" tandis que
# Get-Volume rendait encore un systeme de fichiers sain avec son espace libre
# vivant, et QEMU tenait deja le disque ouvert.
#
# Clear-Disk plutot que Remove-Partition en boucle : un disque prepare par
# Windows porte souvent une partition reservee Microsoft (MSR) que
# Remove-Partition refuse parfois. -RemoveOEM couvre le cas.
#
# On verifie le VOLUME, pas le nombre de partitions : c'est le volume monte qui
# bloque, le compte de partitions n'en est qu'un indice.
function Clear-DisqueComplet {
    param([Parameter(Mandatory)][int] $Numero)

    Clear-Disk -Number $Numero -RemoveData -RemoveOEM -Confirm:$false

    $restantes = @(Get-Partition -DiskNumber $Numero -ErrorAction SilentlyContinue).Count
    if ($restantes -ne 0) { throw "REFUS : $restantes partition(s) subsistent." }

    $vol = @(Get-Disk -Number $Numero | Get-Partition -ErrorAction SilentlyContinue |
             Get-Volume -ErrorAction SilentlyContinue)
    if ($vol.Count -ne 0) { throw "REFUS : un volume est encore monte." }

    Write-Host ("Disque {0} sans volume monte : ecriture brute autorisee." -f $Numero) -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 4. LANCER QEMU DETACHE
# ---------------------------------------------------------------------------
# Lance en processus enfant, QEMU meurt avec la fenetre qui l'a lance. Une
# fermeture de terminal a deja coute sept minutes de demarrage.
#
# Les arguments passent par un TABLEAU et AUCUN ne doit contenir d'espace :
# Start-Process joint sa liste par des espaces sans proteger quoi que ce soit,
# si bien qu'un chemin espace arriverait coupe en deux. Un chemin avec espace
# se met dans une valeur "file=..." d'un seul argument, jamais separe.
function Start-QemuDetache {
    param([Parameter(Mandatory)][string[]] $Arguments,
          [string] $Qemu = 'C:\Program Files\qemu\qemu-system-x86_64.exe')

    foreach ($a in $Arguments) {
        if ($a -match '^-' -and $a -match ' ') {
            throw "REFUS : l'argument '$a' contient un espace, Start-Process le couperait."
        }
    }
    $p = Start-Process -FilePath $Qemu -ArgumentList $Arguments -PassThru
    Write-Host ("QEMU lance en processus {0}, DETACHE." -f $p.Id) -ForegroundColor Green
    Write-Host "Cette fenetre peut etre fermee sans risque."      -ForegroundColor Green
    return $p
}

# ---------------------------------------------------------------------------
# 5. DECLARER LA GEOMETRIE D'UN DISQUE 512e
# ---------------------------------------------------------------------------
# Beaucoup de disques modernes sont des 512e : secteur logique 512, secteur
# physique 4096. Le raccourci "-drive if=virtio" ne sait pas transmettre cette
# geometrie, et l'invite aligne alors ses ecritures sur 512 octets. Chaque
# ecriture desalignee oblige le disque a lire-modifier-ecrire un bloc de 4 Kio.
# Sur un SMR, ou la reecriture est deja le point faible, c'est le detail qui
# separe quarante minutes de trois heures.
#
# La forme qui marche -- eclater en -drive if=none + -device :
#   '-drive','file=\\.\PHYSICALDRIVE1,if=none,id=cible,format=raw,cache=none,aio=threads',
#   '-device','virtio-blk-pci,drive=cible,logical_block_size=512,physical_block_size=4096',
#
# Cote invite, blockdev --getpbsz doit alors rendre 4096. S'il rend 512, la
# geometrie n'est pas passee : l'ecriture aboutira mais sera bien plus lente.
