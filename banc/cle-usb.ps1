# Prepare la cle USB pour recevoir S, puis lance la machine virtuelle avec
# elle attachee. A lancer depuis un terminal ADMINISTRATEUR.
#
# ASCII STRICT : Windows PowerShell 5.1 lit un .ps1 UTF-8 en CP1252, et un
# tiret cadratin y devient un delimiteur de chaine qui casse le fichier.
# La premiere version de ce script est tombee exactement dessus.
#
# Securite par construction : la VM ne voit que son propre disque et la cle.
# Le disque interne n'est jamais expose, donc rien de ce qui se passe a
# l'interieur ne peut l'atteindre.
$ErrorActionPreference = 'Stop'
$VM = 'C:\Users\Ghis\Desktop\S-vm'

# --- L'elevation d'abord ---------------------------------------------------
# Sans elle, QEMU echoue par "Could not open device: Permission denied", mais
# TROIS ETAPES PLUS LOIN : la cle a deja ete demontee, et le message ne dit
# pas ce qui manque. Le refus doit tomber avant qu'on ait touche a quoi que
# ce soit. On teste le role, jamais le nom du groupe : sur un Windows
# francais il s'appelle "Administrateurs", et comparer des noms rend faux.
$moi = New-Object Security.Principal.WindowsPrincipal(
           [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $moi.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "REFUS : cette fenetre n'est pas elevee. Ouvrir un terminal ADMINISTRATEUR et relancer."
}

# --- Garde-fou : on verifie la cible AVANT toute chose ---------------------
$d = Get-Disk -Number 1
Write-Host ("Cible  : disque {0} - {1}" -f $d.Number, $d.FriendlyName) -ForegroundColor Cyan
Write-Host ("Taille : {0} Go - bus {1}" -f [math]::Round($d.Size/1GB,1), $d.BusType) -ForegroundColor Cyan

if ($d.BusType -ne 'USB')      { throw "REFUS : le disque 1 n'est pas sur un bus USB." }
if ($d.IsBoot -or $d.IsSystem) { throw "REFUS : le disque 1 porte un role de demarrage." }
if ($d.Size -gt 100GB)         { throw "REFUS : le disque 1 fait plus de 100 Go, ce n'est pas la cle." }

Write-Host ""
Write-Host "Cette cle va etre ENTIEREMENT EFFACEE." -ForegroundColor Yellow
$r = Read-Host "Taper exactement : EFFACER DISQUE 1"
if ($r -ne 'EFFACER DISQUE 1') { throw "Annule." }

# --- Liberer le disque -----------------------------------------------------
# Windows refuse de mettre un media amovible hors ligne ("Removable media cannot
# be set to offline"). Ce qui verrouille le disque physique est le VOLUME monte
# dessus -- et RETIRER LA LETTRE NE LE DEMONTE PAS : cela enleve le point de
# montage, pas le montage. Mesure le 2026-08-20, QEMU tenant deja le disque
# ouvert : Get-Volume rendait encore un exFAT sain de 61 519 953 920 octets avec
# son espace libre vivant, alors que mountvol annoncait "Aucun point de montage".
#
# Or Windows refuse toute ecriture par handle de DISQUE sur des secteurs couverts
# par un volume monte, et QEMU n'emet ni FSCTL_LOCK_VOLUME ni FSCTL_DISMOUNT_VOLUME.
# La partition allant de l'offset 1 Mio jusqu'au dernier octet, tout sauf les 2048
# premiers secteurs aurait ete refuse : bootc aurait ecrit la table de partition
# (autorisee, hors volume) puis serait mort en erreur d'E/S sur l'ESP -- apres le
# telechargement, et en laissant la cle sans table et sans systeme.
#
# Supprimer la partition supprime le volume. Sans volume monte, le disque
# redevient ecrivable de bout en bout.
Get-Partition -DiskNumber 1 -ErrorAction SilentlyContinue |
    Remove-Partition -Confirm:$false

# On verifie le VOLUME, pas le nombre de partitions : c'est le volume monte qui
# bloque, le compte de partitions n'en est qu'un indice.
$restantes = @(Get-Partition -DiskNumber 1 -ErrorAction SilentlyContinue).Count
if ($restantes -ne 0) { throw "REFUS : $restantes partition(s) subsistent sur le disque 1." }

$vol = @(Get-Disk -Number 1 | Get-Partition -ErrorAction SilentlyContinue |
         Get-Volume -ErrorAction SilentlyContinue)
if ($vol.Count -ne 0) { throw "REFUS : un volume est encore monte sur le disque 1." }

Write-Host "Disque 1 sans volume monte : ecriture brute autorisee." -ForegroundColor Green

# --- La VM, avec la cle en second disque ----------------------------------
# bootc ecrira lui-meme la table de partition depuis l'interieur : rien n'a
# besoin d'etre prepare ici.
Write-Host "Lancement de la machine virtuelle..." -ForegroundColor Cyan

# QEMU est lance DETACHE, et c'est important : lance en processus enfant, il
# meurt avec la fenetre qui l'a lance. Une fermeture de terminal a deja coute
# un demarrage de sept minutes.
#
# Les arguments passent par un tableau et AUCUN ne contient d'espace :
# Start-Process joint sa liste par des espaces sans proteger quoi que ce soit,
# si bien qu'un chemin espace arriverait coupe en deux.
$qemuArgs = @(
  '-name','S-installation-sur-cle',
  '-accel','whpx,kernel-irqchip=off','-machine','q35',
  '-cpu','qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt,+cx16,+lahf_lm',
  '-smp','4','-m','8192',
  '-bios',"$VM\firmware\bios.fd",
  '-drive',"file=$VM\S.qcow2,if=virtio,format=qcow2",
  '-drive','file=\\.\PHYSICALDRIVE1,if=virtio,format=raw,cache=none',
  '-boot','order=c',
  '-serial','tcp:127.0.0.1:4446,server,nowait',
  '-vga','std',
  '-device','qemu-xhci,id=xhci','-device','usb-tablet,bus=xhci.0',
  '-netdev','user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22',
  '-device','virtio-net-pci,netdev=n0',
  '-monitor','tcp:127.0.0.1:4445,server,nowait'
)
$p = Start-Process -FilePath 'C:\Program Files\qemu\qemu-system-x86_64.exe' `
                   -ArgumentList $qemuArgs -PassThru

Write-Host ""
Write-Host ("QEMU lance en processus {0}, DETACHE." -f $p.Id) -ForegroundColor Green
Write-Host "Cette fenetre peut etre fermee sans risque." -ForegroundColor Green
