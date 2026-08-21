# Ecrit S sur la cle USB : copie le script dans la machine virtuelle, puis
# le lance. A lancer apres cle-usb.ps1, qui attache la cle a la VM.
#
# ASCII STRICT : PowerShell 5.1 lit un .ps1 UTF-8 en CP1252, et un tiret
# cadratin y devient un delimiteur de chaine qui casse tout le fichier.
#
# La commande shell vit dans un FICHIER shell (poser-sur-cle.sh) et n'est pas
# construite ici : la version precedente la joignait dans une chaine PowerShell,
# les trois instructions se collaient sans separateur, et bash refusait de
# l'analyser -- "erreur de syntaxe pres du symbole inattendu findmnt".
$ErrorActionPreference = 'Stop'
$VM     = 'C:\Users\Ghis\Desktop\S-vm'
$CLE    = "$VM\cle-banc"
$SCRIPT = 'C:\Users\Ghis\Desktop\S\banc\poser-sur-cle.sh'

if (-not (Test-Path $CLE))    { throw "Cle SSH du banc introuvable : $CLE" }
if (-not (Test-Path $SCRIPT)) { throw "Script introuvable : $SCRIPT" }

$sshOpts = @(
  '-p','2222','-i',$CLE,
  '-o','StrictHostKeyChecking=no',
  '-o','UserKnownHostsFile=NUL',
  '-o','LogLevel=ERROR'
)

Write-Host "Copie du script dans la machine virtuelle..." -ForegroundColor Cyan
& scp -P 2222 -i $CLE -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL `
      -o LogLevel=ERROR $SCRIPT root@127.0.0.1:/root/poser-sur-cle.sh
if ($LASTEXITCODE -ne 0) { throw "La copie a echoue (code $LASTEXITCODE)." }

Write-Host ""
Write-Host "Ecriture de S sur la cle USB." -ForegroundColor Cyan
Write-Host "Compter plusieurs dizaines de minutes : sept gigaoctets a tirer," -ForegroundColor Cyan
Write-Host "puis a ecrire sur de la memoire flash, derriere QEMU." -ForegroundColor Cyan
Write-Host "Cette fenetre affiche l'avancement. Ne pas la fermer." -ForegroundColor Yellow
Write-Host ""

& ssh @sshOpts root@127.0.0.1 'bash /root/poser-sur-cle.sh'
$code = $LASTEXITCODE

Write-Host ""
if ($code -eq 0) {
    Write-Host "TERMINE. La cle porte S." -ForegroundColor Green
    Write-Host "Eteindre la VM, debrancher et rebrancher la cle, puis F12 au demarrage." -ForegroundColor Green
    Write-Host "La fiche d'observation est dans S\banc\premier-demarrage-reel.md" -ForegroundColor Green
} else {
    Write-Host ("ECHEC - code {0}. Ne rien debrancher, me le dire." -f $code) -ForegroundColor Red
}
