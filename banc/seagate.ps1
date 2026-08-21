# Prepare la Seagate de 4,55 To pour recevoir S, puis lance la machine
# virtuelle avec elle attachee. A lancer depuis un terminal ADMINISTRATEUR.
#
# ASCII STRICT : Windows PowerShell 5.1 lit un .ps1 UTF-8 en CP1252, et un
# tiret cadratin y devient un delimiteur de chaine qui casse le fichier
# entier. Ce piege a deja coute un cycle sur cle-usb.ps1.
#
# Securite par construction : la VM ne voit que son propre disque et la
# Seagate. Le NVMe interne n'est JAMAIS expose, donc rien de ce qui se passe
# a l'interieur ne peut atteindre Windows -- meme une faute de frappe.
#
# -Variante : de quoi bissecter le halt du 2026-08-21.
#   prouve    = la syntaxe EXACTEMENT eprouvee sur la cle virtuelle le
#               2026-08-21 a 01h15. C'est le defaut, et ce doit rester le
#               defaut : on ne part jamais d'une variante non eprouvee.
#   geometrie = declare au disque sa geometrie 512e (secteur physique 4096).
#               Plus rapide en theorie sur un SMR, JAMAIS EPROUVE, et premier
#               suspect du halt a 1,46 s de temps noyau.
# -SansEffacer : le disque est deja RAW, ne pas rejouer Clear-Disk.
param(
    [ValidateSet('prouve','geometrie')]
    [string] $Variante = 'prouve',
    [switch] $SansEffacer
)
$ErrorActionPreference = 'Stop'
$VM = 'C:\Users\Ghis\Desktop\S-vm'

# Taille relevee le 2026-08-21 sur la machine, a l'octet. Le garde-fou porte
# sur ce nombre et non sur un intervalle : une taille approchee laisserait
# passer un disque qu'on n'a pas identifie.
$TAILLE_SEAGATE = 5000981077504

# --- L'elevation d'abord ---------------------------------------------------
# Sans elle, QEMU echoue par "Could not open device: Permission denied" mais
# TROIS ETAPES PLUS LOIN : le disque a deja ete efface, et le message ne dit
# pas ce qui manque. Le refus doit tomber avant qu'on ait touche a rien.
# On teste le ROLE, jamais le nom du groupe : sur un Windows francais il
# s'appelle "Administrateurs", et comparer des noms rend faux.
$moi = New-Object Security.Principal.WindowsPrincipal(
           [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $moi.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "REFUS : cette fenetre n'est pas elevee. Ouvrir un terminal ADMINISTRATEUR et relancer."
}

# --- Garde-fous : identifier la cible AVANT toute chose --------------------
$d = Get-Disk -Number 1
Write-Host ""
Write-Host ("Cible  : disque {0} - {1}" -f $d.Number, $d.FriendlyName) -ForegroundColor Cyan
Write-Host ("Taille : {0} octets - bus {1} - table {2}" -f $d.Size, $d.BusType, $d.PartitionStyle) -ForegroundColor Cyan
Write-Host ("Secteur: logique {0} / physique {1}" -f $d.LogicalSectorSize, $d.PhysicalSectorSize) -ForegroundColor Cyan

if ($d.BusType -ne 'USB')        { throw "REFUS : le disque 1 n'est pas sur un bus USB." }
if ($d.IsBoot -or $d.IsSystem)   { throw "REFUS : le disque 1 porte un role de demarrage." }
if ($d.Size -ne $TAILLE_SEAGATE) { throw ("REFUS : taille {0}, attendu {1}. Ce n'est pas la Seagate identifiee." -f $d.Size, $TAILLE_SEAGATE) }

# Le NVMe interne ne doit jamais etre le disque 1. Controle redondant avec le
# precedent, et c'est voulu : celui-ci ne coute rien et couvre le cas ou les
# numeros de disque auraient bouge entre deux branchements.
$sys = @(Get-Disk | Where-Object { $_.IsSystem -or $_.IsBoot } | ForEach-Object { $_.Number })
if ($sys -contains 1) { throw "REFUS : le disque 1 porte Windows." }

Write-Host ""
Write-Host ("Variante de ligne de commande : {0}" -f $Variante) -ForegroundColor Magenta

# Un disque deja RAW n'a plus rien a effacer, et Clear-Disk y echoue. On lit
# l'etat plutot que de le supposer -- c'est la regle 7 du carnet, et elle vaut
# aussi pour les reprises apres echec.
$dejaVide = ($d.PartitionStyle -eq 'RAW')
if ($dejaVide) {
    Write-Host "Le disque est deja RAW : rien a effacer, on saute la confirmation." -ForegroundColor Green
}
elseif ($SansEffacer) {
    throw "REFUS : -SansEffacer demande, mais le disque porte encore une table $($d.PartitionStyle)."
}
else {
    Write-Host "Ce disque va etre ENTIEREMENT EFFACE : table, partitions, D: SEAGATE." -ForegroundColor Yellow
    Write-Host "Il sera rendu a Windows plus tard, en retrecissant ext4." -ForegroundColor Yellow
    $r = Read-Host "Taper exactement : EFFACER DISQUE 1"
    if ($r -ne 'EFFACER DISQUE 1') { throw "Annule. Rien n'a ete touche." }
}

# --- Liberer le disque -----------------------------------------------------
# Windows refuse de mettre un media amovible hors ligne ("Removable media
# cannot be set to offline"). Ce qui verrouille le disque physique est le
# VOLUME monte dessus -- et RETIRER LA LETTRE NE LE DEMONTE PAS : cela enleve
# le point de montage, pas le montage. Mesure le 2026-08-20 : mountvol
# annoncait "Aucun point de montage" tandis que Get-Volume rendait encore un
# systeme de fichiers sain avec son espace libre vivant.
#
# Or Windows refuse toute ecriture par handle de DISQUE sur des secteurs
# couverts par un volume monte, et QEMU n'emet ni FSCTL_LOCK_VOLUME ni
# FSCTL_DISMOUNT_VOLUME. bootc aurait ecrit la table (secteurs 0-2047, hors
# volume, donc autorisee) puis serait mort en erreur d'E/S sur l'ESP -- apres
# le telechargement, en laissant le disque sans table ET sans systeme.
#
# Clear-Disk plutot que Remove-Partition en boucle : ce disque porte une
# partition reservee Microsoft (MSR) en plus de la NTFS, et Remove-Partition
# la refuse parfois. -RemoveOEM couvre le cas.
if (-not $dejaVide) {
    Write-Host ""
    Write-Host "Suppression des partitions..." -ForegroundColor Cyan
    Clear-Disk -Number 1 -RemoveData -RemoveOEM -Confirm:$false
}

# On verifie le VOLUME, pas le nombre de partitions : c'est le volume monte
# qui bloque, le compte de partitions n'en est qu'un indice. Ce controle
# tourne dans TOUS les cas, y compris sur reprise -- un disque RAW pourrait
# theoriquement avoir ete remonte entre-temps.
$restantes = @(Get-Partition -DiskNumber 1 -ErrorAction SilentlyContinue).Count
if ($restantes -ne 0) { throw "REFUS : $restantes partition(s) subsistent sur le disque 1." }
$vol = @(Get-Disk -Number 1 | Get-Partition -ErrorAction SilentlyContinue |
         Get-Volume -ErrorAction SilentlyContinue)
if ($vol.Count -ne 0) { throw "REFUS : un volume est encore monte sur le disque 1." }

Write-Host "Disque 1 sans volume monte : ecriture brute autorisee." -ForegroundColor Green

# --- La VM, avec la Seagate en second disque -------------------------------
# bootc ecrira lui-meme la table de partition depuis l'interieur : rien n'a
# besoin d'etre prepare ici.
#
# DEUX VARIANTES, ET LE DEFAUT EST CELLE QUI A DEJA MARCHE.
#
# "geometrie" declare au disque son secteur physique de 4096 octets, ce que le
# raccourci if=virtio ne sait pas transmettre. En theorie c'est un gain reel
# sur un SMR : sans cette declaration l'invite aligne ses ecritures sur 512
# octets, et chaque ecriture desalignee oblige le disque a lire-modifier-
# ecrire un bloc de 4 Kio.
#
# MAIS ELLE N'A JAMAIS ETE EPROUVEE, et le 2026-08-21 l'invite s'est HALTE a
# 1,46 s de temps noyau avec elle : zero CPU consomme sur 75 s, les huit
# threads de QEMU en attente, zero E/S sur le disque hote -- lequel restait
# Online et sain. Un arret franc, pas une lenteur.
#
# La lecon vaut plus que l'optimisation : on ne modifie pas un chemin eprouve
# le soir meme du premier essai reel, et surtout pas pour de la performance.
# Trois changements avaient ete introduits d'un coup (if=none + -device, les
# tailles de bloc, aio=threads), ce qui interdisait de savoir lequel accusait.
# D'ou ce parametre : une seule variable a la fois.
#
# L'ordre des -drive fixe les noms : S.qcow2 en premier donc vda, la Seagate
# ensuite donc vdb. poser-sur-seagate.sh vise vdb et revalide la taille.
if ($Variante -eq 'geometrie') {
    $argsDisque = @(
      '-drive','file=\\.\PHYSICALDRIVE1,if=none,id=seagate,format=raw,cache=none,aio=threads',
      '-device','virtio-blk-pci,drive=seagate,logical_block_size=512,physical_block_size=4096'
    )
    Write-Host "ATTENTION : variante JAMAIS EPROUVEE, et suspecte du halt du 2026-08-21." -ForegroundColor Yellow
}
else {
    # Mot pour mot la forme qui a fonctionne sur la cle virtuelle.
    $argsDisque = @(
      '-drive','file=\\.\PHYSICALDRIVE1,if=virtio,format=raw,cache=none'
    )
}

Write-Host "Lancement de la machine virtuelle..." -ForegroundColor Cyan

# QEMU est lance DETACHE, et c'est important : lance en processus enfant, il
# meurt avec la fenetre qui l'a lance. Une fermeture de terminal a deja coute
# sept minutes de demarrage.
#
# Les arguments passent par un tableau et AUCUN ne contient d'espace :
# Start-Process joint sa liste par des espaces sans proteger quoi que ce soit,
# si bien qu'un chemin espace arriverait coupe en deux.
$qemuArgs = @(
  '-name','S-installation-sur-seagate',
  '-accel','whpx,kernel-irqchip=off','-machine','q35',
  '-cpu','qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm',
  '-smp','4','-m','8192',
  '-bios',"$VM\firmware\bios.fd",
  '-drive',"file=$VM\S.qcow2,if=virtio,format=qcow2"
) + $argsDisque + @(
  '-boot','order=c',
  '-serial','tcp:127.0.0.1:4446,server,nowait',
  '-vga','std',
  '-device','qemu-xhci,id=xhci','-device','usb-tablet,bus=xhci.0',
  '-netdev','user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22',
  '-device','virtio-net-pci,netdev=n0',
  '-monitor','tcp:127.0.0.1:4445,server,nowait'
)
$p = Start-Process -FilePath 'C:\Program Files\qemu\qemu-system-x86_64.exe' -ArgumentList $qemuArgs -PassThru

Write-Host ""
Write-Host ("QEMU lance en processus {0}, DETACHE." -f $p.Id) -ForegroundColor Green
Write-Host "Cette fenetre peut etre fermee sans risque." -ForegroundColor Green
Write-Host ""
Write-Host "Me dire que c'est parti : je prends la main par SSH." -ForegroundColor Cyan
