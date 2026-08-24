# Grave une ISO au secteur pres sur la cle USB SanDisk.
#
# A lancer depuis un terminal ADMINISTRATEUR :
#   powershell -ExecutionPolicy Bypass -File "C:\Users\Ghis\Desktop\S\banc\graver-iso-sur-cle.ps1" -Iso "C:\...\s-os.iso"
#
# ASCII STRICT : PowerShell 5.1 lit un .ps1 UTF-8 en CP1252, et un tiret
# cadratin y devient un delimiteur de chaine qui casse tout le fichier. Le
# piege est consigne au carnet, et il y a deja ete commis une fois.
#
# CE QUE CE SCRIPT REJOUE, ET QUI EST DEJA APPRIS
#
# 1. L'ELEVATION SE TESTE EN PREMIER. Sans elle, l'ouverture du disque physique
#    rend "Permission denied" -- mais trois etapes trop tard, la cle ayant
#    deja ete departitionnee. On teste le ROLE, jamais le nom du groupe, qui
#    s'appelle "Administrateurs" sur un Windows francais.
#
# 2. RETIRER LA LETTRE NE DEMONTE PAS LE VOLUME. Ce qui verrouille les secteurs
#    n'est pas le disque mais le VOLUME monte dessus. Mesure du 2026-08-20 :
#    "mountvol" annoncait "Aucun point de montage" pendant que Get-Volume
#    rendait encore un exFAT sain avec son espace libre vivant. Et Windows
#    refuse de mettre un media amovible hors ligne. La seule voie qui marche est
#    de SUPPRIMER LA PARTITION : sans volume, le disque redevient inscriptible
#    de bout en bout.
#
# 3. LE PIRE ECHEC EST CELUI QUI REUSSIT A MOITIE. Les secteurs 0 a 2047 sont
#    hors partition, donc toujours inscriptibles : une table de partition
#    s'ecrirait, puis l'ecriture de la suite serait refusee, et la cle
#    resterait sans table ET sans systeme. D'ou la sonde d'ecriture, qui
#    reecrit a l'identique un secteur PROFOND avant d'engager quoi que ce soit.
#
# CE QUI EST NEUF ICI : l'ecriture se fait par un FileStream .NET, pas par QEMU.
# Un handle de disque physique n'accepte que des ecritures alignees sur la
# taille de secteur -- d'ou un tampon multiple de 4096, et un dernier bloc
# complete a zero.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Iso,

    # Le numero de disque n'est PAS un defaut silencieux : il est verifie contre
    # trois preuves independantes avant la moindre ecriture.
    [int] $Disque = 2,

    # Taille attendue de la SanDisk, a l'octet pres. Un disque d'une autre
    # taille fait refuser le script.
    [long] $TailleAttendue = 61524148224,

    [switch] $SansConfirmation
)

$ErrorActionPreference = 'Stop'

function Dire($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

# Read n'est PAS tenu de rendre le nombre d'octets demande : il rend ce qu'il a
# sous la main. Sur un fichier local il rend presque toujours tout, ce qui rend
# le defaut invisible au banc et bien reel sur un disque USB. Comparer un tampon
# a moitie rempli ferait declarer FAUSSE une gravure correcte -- le pire verdict
# possible, puisqu'il ferait recommencer huit gigaoctets pour rien.
function Lire-Exactement([System.IO.Stream]$flux, [byte[]]$tampon, [int]$combien) {
    $total = 0
    while ($total -lt $combien) {
        $lu = $flux.Read($tampon, $total, $combien - $total)
        if ($lu -le 0) { break }
        $total += $lu
    }
    return $total
}

# --- 1. L'elevation, avant tout le reste ------------------------------------
$moi = New-Object Security.Principal.WindowsPrincipal(
           [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $moi.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "REFUS : cette fenetre n'est pas elevee. Ouvrir un terminal ADMINISTRATEUR."
}
Dire "Elevation : OK" 'Green'

# --- 2. L'ISO ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Iso)) { throw "REFUS : introuvable -- $Iso" }
$f = Get-Item -LiteralPath $Iso
if ($f.Length -lt 100MB) { throw ("REFUS : {0} ne fait que {1:N1} Mo -- ce n'est pas une ISO d'installation." -f $f.Name, ($f.Length/1MB)) }
Dire ("ISO       : {0}" -f $f.FullName)
Dire ("Poids     : {0:N2} Gio ({1} octets)" -f ($f.Length/1GB), $f.Length)

# Une ISO hybride porte une signature de table de partition dans son premier
# secteur. Sans elle, la graver au secteur pres ne donnerait rien d'amorcable :
# autant le dire maintenant plutot qu'apres vingt minutes d'ecriture.
$tete = New-Object byte[] 512
$fs = [System.IO.File]::OpenRead($f.FullName)
try { $null = $fs.Read($tete, 0, 512) } finally { $fs.Dispose() }
if ($tete[510] -eq 0x55 -and $tete[511] -eq 0xAA) {
    Dire "Hybride   : signature 55AA presente -- gravable au secteur pres" 'Green'
} else {
    Dire "ATTENTION : pas de signature 55AA dans le premier secteur." 'Yellow'
    Dire "            Cette ISO n'est peut-etre pas hybride ; la cle pourrait ne pas amorcer." 'Yellow'
}

# --- 3. La cible, prouvee trois fois ----------------------------------------
$d = Get-Disk -Number $Disque
Dire ""
Dire ("Cible     : disque {0} -- {1}" -f $d.Number, $d.FriendlyName) 'Cyan'
Dire ("            {0:N1} Go, bus {1}, table {2}, serie {3}" -f ($d.Size/1GB), $d.BusType, $d.PartitionStyle, $d.SerialNumber) 'Cyan'

if ($d.IsBoot -or $d.IsSystem)  { throw "REFUS : ce disque porte un role de demarrage." }
if ($d.BusType -ne 'USB')       { throw ("REFUS : le disque {0} n'est pas sur un bus USB (bus = {1})." -f $Disque, $d.BusType) }
if ($d.Size -ne $TailleAttendue){ throw ("REFUS : taille {0} octets, attendu {1}. Ce n'est pas la cle visee." -f $d.Size, $TailleAttendue) }
if ($d.FriendlyName -notmatch 'SanDisk') { throw ("REFUS : le disque se nomme {0} -- ce n'est pas une SanDisk." -f $d.FriendlyName) }
if ($d.Size -gt 200GB)          { throw "REFUS : ce disque fait plus de 200 Go -- ce n'est pas une cle." }
Dire "Garde-fous : quatre preuves concordantes (USB, taille exacte, marque, sans role d'amorcage)" 'Green'

if ($f.Length -gt $d.Size) {
    throw ("REFUS : l'ISO ({0:N2} Gio) est plus grosse que la cle ({1:N2} Gio)." -f ($f.Length/1GB), ($d.Size/1GB))
}

# On regarde ce qu'on detruit, plutot que de le supposer vide.
Dire ""
Dire "Ce qui se trouve sur cette cle aujourd'hui :" 'Yellow'
$rien = $true
Get-Partition -DiskNumber $Disque -ErrorAction SilentlyContinue | ForEach-Object {
    $rien = $false
    $v = $_ | Get-Volume -ErrorAction SilentlyContinue
    if ($v) {
        Dire ("  partition {0} : {1} {2}, {3:N1} Go dont {4:N1} Go occupes, lettre {5}" -f `
              $_.PartitionNumber, $v.FileSystem, $v.FileSystemLabel, ($v.Size/1GB), (($v.Size - $v.SizeRemaining)/1GB), $_.DriveLetter) 'Yellow'
    } else {
        Dire ("  partition {0} : {1:N1} Go, sans volume monte" -f $_.PartitionNumber, ($_.Size/1GB)) 'Yellow'
    }
}
if ($rien) { Dire "  (aucune partition)" 'Yellow' }

if (-not $SansConfirmation) {
    Dire ""
    Dire "Cette cle va etre ENTIEREMENT EFFACEE et remplacee par l'ISO." 'Red'
    $r = Read-Host ("Taper exactement : GRAVER DISQUE {0}" -f $Disque)
    if ($r -ne ("GRAVER DISQUE {0}" -f $Disque)) { throw "Annule." }
}

# --- 4. Liberer les secteurs ------------------------------------------------
# Voir le mur 2 de l'en-tete : c'est le volume qui verrouille, pas le disque,
# et seule la suppression de la partition le fait lacher.
Get-Partition -DiskNumber $Disque -ErrorAction SilentlyContinue |
    Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
$reste = @(Get-Partition -DiskNumber $Disque -ErrorAction SilentlyContinue)
if ($reste.Count -gt 0) { throw ("REFUS : {0} partition(s) subsistent -- Windows n'a pas lache le disque." -f $reste.Count) }
Dire "Partitions supprimees -- les secteurs sont libres" 'Green'

# --- 5. La sonde d'ecriture -------------------------------------------------
# On reecrit A L'IDENTIQUE un secteur PROFOND, bien au-dela des 2048 premiers
# qui sont toujours autorises. Si Windows refuse, on le sait maintenant, avant
# d'avoir ecrase quoi que ce soit d'utile.
$chemin = "\\.\PhysicalDrive$Disque"
$SECTEUR = 4096
$SONDE   = 64MB
try {
    # bufferSize = 1 : on DESACTIVE le tampon interne de FileStream. Sur un
    # handle de disque physique, Windows n'accepte que des lectures et des
    # ecritures alignees sur la taille de secteur ; laisser .NET decouper nos
    # blocs a sa guise reviendrait a parier sur son decoupage.
    $h = New-Object System.IO.FileStream($chemin, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None, 1, $false)
} catch {
    throw ("REFUS : impossible d'ouvrir {0} en ecriture -- {1}" -f $chemin, $_.Exception.Message)
}
try {
    $tampon = New-Object byte[] $SECTEUR
    $h.Position = $SONDE
    $lu = $h.Read($tampon, 0, $SECTEUR)
    if ($lu -ne $SECTEUR) { throw "REFUS : lecture de sonde incomplete ($lu octets)." }
    $h.Position = $SONDE
    $h.Write($tampon, 0, $SECTEUR)
    $h.Flush()
    Dire ("Sonde     : secteur a {0} Mio reecrit a l'identique -- l'ecriture profonde passe" -f ($SONDE/1MB)) 'Green'
} catch {
    $h.Dispose()
    throw ("REFUS : la sonde d'ecriture a echoue -- {0}" -f $_.Exception.Message)
}

# --- 6. La gravure ----------------------------------------------------------
# LE NOM DE CETTE VARIABLE A COUTE UNE GRAVURE. Elle s'appelait $BLOC, et le
# tampon s'appelait $bloc. EN POWERSHELL LES NOMS DE VARIABLES SONT INSENSIBLES
# A LA CASSE : c'etait la MEME variable. La ligne "$bloc = New-Object byte[]
# $BLOC" ecrasait donc la taille par le tableau, et l'appel devenait
# "Read(tableau, 0, tableau)". PowerShell a refuse :
#
#   Impossible de convertir l'argument "count" (valeur "0 0 0 0 ...") de "Read"
#   en type "System.Int32"
#
# Et comme le message recrache le tableau entier, le journal de la gravure
# pesait 33 Mo. L'habitude venue du shell et de Python -- constantes en
# majuscules, variables en minuscules -- ne tient pas ici.
$TAILLE_BLOC = 8MB   # multiple de 512 ET de 4096 : aligne quelle que soit la cle

# L'assertion qui aurait attrape la faute en une seconde. Elle reste : le meme
# piege se retendra au prochain script PowerShell de ce depot.
if ($TAILLE_BLOC -isnot [int]) {
    throw ("REFUS : la taille de bloc n'est pas un entier mais un {0} -- collision de nom ?" -f $TAILLE_BLOC.GetType().Name)
}
Dire ""
Dire ("Gravure de {0:N2} Gio par blocs de {1} Mio..." -f ($f.Length/1GB), ($TAILLE_BLOC/1MB)) 'Cyan'

# ============================================================================
# LA TETE S'ECRIT EN DERNIER, ET C'EST TOUT LE SECRET DE CETTE GRAVURE.
# ============================================================================
#
# CE QUI A TUE LE PREMIER ESSAI REEL : 368 Mio ecrits, puis
#
#     Exception lors de l'appel de "Write" avec "3" argument(s) :
#     "Fonction incorrecte."
#
# ERROR_INVALID_FUNCTION sur un disque physique veut dire que quelqu'un
# d'autre s'est mis a possceder ces secteurs. Ce quelqu'un, c'est Windows :
# des que le premier bloc de l'ISO est ecrit, le secteur 0 porte une table de
# partition VALIDE. Le gestionnaire de volumes enumere alors le disque, monte
# la partition qu'il y trouve, et notre handle -- qui n'a jamais verrouille ce
# volume, puisqu'il n'existait pas -- perd le droit d'ecrire a l'interieur.
#
# Windows refusant par ailleurs de mettre un media amovible hors ligne (mur 2
# de l'en-tete), on ne peut pas l'en empecher par la voie normale.
#
# LA PARADE : ne jamais laisser exister de table de partition valide TANT QUE
# l'ecriture n'est pas finie.
#
#   1. on ecrase le premier mebioctet avec des zeros -- plus rien a enumerer ;
#   2. on ecrit tout le corps, de 1 Mio jusqu'a la fin ;
#   3. on ecrit la tete EN DERNIER, d'un seul coup.
#
# Entre 1 et 3 le disque n'a aucune table : Windows n'a rien a monter, donc
# rien a verrouiller. La table apparait a la toute derniere ecriture, quand
# plus rien ne reste a ecrire.
#
# Un mebioctet suffit largement : MBR au secteur 0, en-tete GPT au secteur 1,
# table GPT jusqu'au secteur 33, et la premiere partition d'une ISO hybride
# commence au secteur 2048 -- soit exactement 1 Mio.
#
# ET PENDANT CE TEMPS, NE PAS INTERROGER LE STOCKAGE. Un simple Get-Volume ou
# Get-Partition lance un rafraichissement de la pile de stockage, qui refait
# enumerer les disques. C'est probablement ce qui a acheve le premier essai :
# l'inventaire tournait dans une autre fenetre au moment ou l'ecriture est
# morte.
$TAILLE_TETE = 1MB
if ($TAILLE_TETE % $SECTEUR -ne 0) { throw "REFUS : la tete n'est pas alignee." }

$src = [System.IO.File]::OpenRead($f.FullName)
$chrono = [System.Diagnostics.Stopwatch]::StartNew()
$ecrits = 0L
$dernier = 0
try {
    # --- 1. Neutraliser la tete --------------------------------------------
    $zeros = New-Object byte[] $TAILLE_TETE
    $h.Position = 0
    $h.Write($zeros, 0, $TAILLE_TETE)
    $h.Flush($true)
    Dire "  tete neutralisee -- le disque n'a plus de table a enumerer" 'Green'

    # --- 2. Le corps, de 1 Mio a la fin ------------------------------------
    $src.Position = $TAILLE_TETE
    $h.Position   = $TAILLE_TETE
    $ecrits = [long]$TAILLE_TETE
    $bloc = New-Object byte[] $TAILLE_BLOC
    while ($true) {
        $n = $src.Read($bloc, 0, $TAILLE_BLOC)
        if ($n -le 0) { break }
        # Un handle de disque physique n'accepte que des ecritures alignees sur
        # la taille de secteur. Le dernier bloc d'une ISO ne l'est pas
        # forcement : on le complete a zero plutot que de le tronquer.
        $aEcrire = $n
        if ($aEcrire % $SECTEUR -ne 0) {
            $aEcrire = [int]([Math]::Ceiling($n / [double]$SECTEUR) * $SECTEUR)
            for ($i = $n; $i -lt $aEcrire; $i++) { $bloc[$i] = 0 }
        }
        $h.Write($bloc, 0, $aEcrire)
        $ecrits += $n
        $pct = [int](100 * $ecrits / $f.Length)
        if ($pct -ge $dernier + 5) {
            $dernier = $pct
            $debit = $ecrits / 1MB / $chrono.Elapsed.TotalSeconds
            $minutes = [int]((($f.Length - $ecrits) / 1MB) / [Math]::Max($debit, 0.1) / 60)
            Dire ("  {0,3} %  --  {1:N0} Mio ecrits, {2:N1} Mio/s, ~{3} min restantes" -f $pct, ($ecrits/1MB), $debit, $minutes)
        }
    }
    $h.Flush($true)

    # --- 3. La tete, en dernier --------------------------------------------
    $tampon_tete = New-Object byte[] $TAILLE_TETE
    $src.Position = 0
    $lu = Lire-Exactement $src $tampon_tete $TAILLE_TETE
    if ($lu -ne $TAILLE_TETE) { throw ("REFUS : tete lue incomplete ({0} octets)." -f $lu) }
    $h.Position = 0
    $h.Write($tampon_tete, 0, $TAILLE_TETE)
    $h.Flush($true)
    Dire "  tete ecrite en dernier -- la table de partition apparait maintenant" 'Green'
} finally {
    $src.Dispose()
}
$chrono.Stop()
Dire ("Ecrit     : {0:N0} Mio en {1:hh\:mm\:ss} ({2:N1} Mio/s)" -f ($ecrits/1MB), $chrono.Elapsed, ($ecrits/1MB/$chrono.Elapsed.TotalSeconds)) 'Green'

# --- 7. Relire, et comparer -------------------------------------------------
# Une ecriture qui rend la main n'est pas une ecriture arrivee sur la memoire
# flash. On relit trois zones -- debut, milieu, fin -- et on compare.
Dire ""
Dire "Verification par relecture..." 'Cyan'
$src = [System.IO.File]::OpenRead($f.FullName)
$ok = $true
try {
    $tailleTest = 4MB
    $points = @(0L, [long]($f.Length / 2), [long]($f.Length - $tailleTest))
    foreach ($p in $points) {
        $p = [long]([Math]::Floor($p / $SECTEUR) * $SECTEUR)
        $a = New-Object byte[] $tailleTest
        $b = New-Object byte[] $tailleTest
        $src.Position = $p
        $luA = Lire-Exactement $src $a $tailleTest
        $h.Position   = $p
        $luB = Lire-Exactement $h   $b $tailleTest
        if ($luA -ne $tailleTest -or $luB -ne $tailleTest) {
            Dire ("  offset {0,12:N0} : lecture incomplete ({1} / {2} octets)" -f $p, [Math]::Min($luA, $luB), $tailleTest) 'Red'
            $ok = $false
            continue
        }
        $identique = $true
        for ($i = 0; $i -lt $tailleTest; $i++) { if ($a[$i] -ne $b[$i]) { $identique = $false; break } }
        if ($identique) {
            Dire ("  offset {0,12:N0} : identique sur {1} Mio" -f $p, ($tailleTest/1MB)) 'Green'
        } else {
            Dire ("  offset {0,12:N0} : DIFFERENT (premier ecart a +{1})" -f $p, $i) 'Red'
            $ok = $false
        }
    }
} finally {
    $src.Dispose()
    $h.Dispose()
}

Dire ""
if ($ok) {
    Dire "TERMINE : la cle porte l'ISO de S et est amorcable." 'Green'
    Dire ""
    Dire "Windows va proposer de formater la cle : REFUSER." 'Yellow'
    Dire "Il ne sait pas lire le systeme de fichiers d'une ISO Linux ; ce n'est" 'Yellow'
    Dire "pas un defaut de la gravure." 'Yellow'
    Dire ""
    Dire "Pour amorcer dessus : F12 au demarrage, choisir la cle en UEFI." 'Cyan'
} else {
    Dire "ECHEC : la relecture ne correspond pas a l'ISO. Ne pas amorcer dessus." 'Red'
    exit 1
}
