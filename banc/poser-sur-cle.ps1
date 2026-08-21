# Ecrit S sur la cle USB, depuis l'interieur de la machine virtuelle.
#
# ASCII STRICT : PowerShell 5.1 lit un .ps1 UTF-8 en CP1252, et un tiret
# cadratin y devient un delimiteur de chaine qui casse tout le fichier.
#
# La cible est /dev/vdb DANS LA VM : c'est la cle USB physique, attachee par
# cle-usb.ps1. Le disque interne de la machine n'a jamais ete presente a la
# VM, il est donc structurellement hors d'atteinte.
#
# Verifications faites avant d'en arriver la :
#   vdb = 61 524 148 224 octets, soit exactement les 57,3 Go de la SanDisk
#   vda = 53 687 091 200 octets, et c'est lui qui porte /sysroot et /boot
#   vdb1 est en exFAT ; le disque de la VM est en btrfs
$ErrorActionPreference = 'Stop'
$VM  = 'C:\Users\Ghis\Desktop\S-vm'
$CLE = "$VM\cle-banc"

if (-not (Test-Path $CLE)) { throw "Cle SSH du banc introuvable : $CLE" }

# Le controle de taille est refait A L'INTERIEUR, juste avant d'ecrire :
# l'inventaire d'un appelant ne se tient jamais pour acquis, un disque ayant
# pu etre debranche ou remplace entre-temps.
$commande = @(
  'test "$(blockdev --getsize64 /dev/vdb)" = "61524148224" || { echo "TAILLE INATTENDUE - ARRET"; exit 1; }',
  'findmnt -n -o SOURCE / | grep -q vdb && { echo "LA CIBLE PORTE LA RACINE - ARRET"; exit 1; }',
  'podman run --rm --privileged --pid=host',
  '  -v /dev:/dev -v /var/lib/containers:/var/lib/containers',
  '  -v /root/.ssh/authorized_keys:/tmp/cle.pub:ro',
  '  --security-opt label=type:unconfined_t',
  '  ghcr.io/gigigrenier86/s-os:latest',
  '  bootc install to-disk --wipe --filesystem btrfs',
  '    --target-imgref ghcr.io/gigigrenier86/s-os:latest',
  '    --root-ssh-authorized-keys /tmp/cle.pub',
  '    /dev/vdb'
) -join ' '

Write-Host "Ecriture de S sur la cle USB." -ForegroundColor Cyan
Write-Host "Compter plusieurs dizaines de minutes : sept gigaoctets a tirer," -ForegroundColor Cyan
Write-Host "puis a ecrire sur de la memoire flash, derriere QEMU." -ForegroundColor Cyan
Write-Host ""

ssh -p 2222 -i $CLE -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL `
    -o LogLevel=ERROR root@127.0.0.1 $commande

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host "TERMINE. La cle porte S." -ForegroundColor Green
    Write-Host "Eteindre la VM, debrancher et rebrancher la cle, puis F12 au demarrage." -ForegroundColor Green
} else {
    Write-Host ("ECHEC - code {0}. Ne rien debrancher, me le dire." -f $LASTEXITCODE) -ForegroundColor Red
}
