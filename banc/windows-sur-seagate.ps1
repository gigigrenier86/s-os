# Deplacer Windows du NVMe interne vers la Seagate, en le laissant amorcable.
#
#   powershell -ExecutionPolicy Bypass -File banc\windows-sur-seagate.ps1 -Phase inventaire
#
# ASCII STRICT : PowerShell 5.1 lit un .ps1 UTF-8 en CP1252. Voir le carnet.
#
# ============================================================================
# CE QUE CE SCRIPT FAIT, ET CE QU'IL NE PROMET PAS
# ============================================================================
#
# But : que la M720q ait S sur son disque interne rapide, et Windows sur la
# Seagate, amorcable au F12 si besoin.
#
# LE POINT QUI PEUT ECHOUER, ET IL FAUT LE SAVOIR AVANT DE COMMENCER : une
# installation Windows ordinaire clonee sur un disque USB tombe couramment sur
# INACCESSIBLE_BOOT_DEVICE (0x7B). Les pilotes USB ne font pas partie du jeu
# d'amorcage d'une installation posee sur du NVMe : au demarrage, le noyau
# charge de quoi lire un NVMe, pas de quoi lire un disque USB. La phase
# "preparer-usb" corrige cela dans le registre du CLONE -- c'est ce que fait
# Windows To Go -- et ca marche souvent. Ca ne se promet pas.
#
# D'OU L'ORDRE, QUI EST LA VRAIE PROTECTION :
#
#   1. inventaire    on regarde. Rien n'est ecrit.
#   2. partitionner  la SEAGATE est effacee et repartitionnee. Le NVMe n'est
#                    pas touche -- S y sera pose plus tard, et seulement si
#                    l'etape 6 a reussi.
#   3. capturer      photo coherente de C: (cliche VSS) vers un fichier .wim
#                    pose sur la Seagate. C'est AUSSI la copie de sauvegarde.
#   4. appliquer     le .wim est deplie dans la partition Windows de la Seagate.
#   5. preparer-usb  amorcage ecrit sur l'ESP de la Seagate, pilotes USB armes
#                    dans le registre du clone, lettres de lecteur remises a
#                    zero.
#   6. -- VOUS --    F12, choisir la Seagate. Windows doit demarrer.
#   7. Seulement alors : effacer le NVMe et y installer S depuis l'ISO.
#
# TANT QUE L'ETAPE 6 N'A PAS REUSSI, LE WINDOWS DU NVMe EST INTACT. Si le clone
# refuse de demarrer, on n'a perdu que le S installe sur la Seagate -- que
# l'ISO repose en une demi-heure.
#
# CE QUE CE SCRIPT NE FAIT PAS : il n'efface jamais le NVMe. Cette commande-la
# n'existe pas ici, a dessein.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('inventaire','partitionner','capturer','appliquer','preparer-usb','verifier')]
    [string] $Phase,

    [int]  $DisqueSeagate = 1,
    [int]  $DisqueWindows = 0,
    # 400 Gio : C: occupe ~113 Go une fois les .qcow2 partis. On laisse de la
    # marge pour des annees d'usage sans repartitionner un disque amorcable.
    [long] $TailleWindowsGo = 400,
    [switch] $SansConfirmation
)

$ErrorActionPreference = 'Stop'
function Dire($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Titre($m) { Dire ""; Dire ("=== " + $m + " ===") 'Cyan' }

# --- Garde-fous communs, joues a CHAQUE phase -------------------------------
# Un inventaire fait il y a dix minutes n'est pas l'etat du disque maintenant :
# une cle branchee entre-temps decale les numeros. On revalide toujours.
function Exiger-Elevation {
    $moi = New-Object Security.Principal.WindowsPrincipal(
               [Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $moi.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "REFUS : cette fenetre n'est pas elevee. Ouvrir un terminal ADMINISTRATEUR."
    }
}
function Exiger-Seagate {
    $d = Get-Disk -Number $DisqueSeagate
    if ($d.IsBoot -or $d.IsSystem)          { throw "REFUS : le disque $DisqueSeagate porte un role de demarrage." }
    if ($d.BusType -ne 'USB')               { throw ("REFUS : le disque {0} est sur un bus {1}, pas USB." -f $DisqueSeagate, $d.BusType) }
    if ($d.Size -lt 4TB)                    { throw ("REFUS : le disque {0} fait {1:N0} Go, pas 4,5 To." -f $DisqueSeagate, ($d.Size/1GB)) }
    if ($d.FriendlyName -notmatch 'Seagate'){ throw ("REFUS : le disque {0} se nomme {1}." -f $DisqueSeagate, $d.FriendlyName) }
    return $d
}
function Trouver-Partition([int]$disque, [string]$etiquette) {
    Get-Partition -DiskNumber $disque -ErrorAction SilentlyContinue | ForEach-Object {
        $v = $_ | Get-Volume -ErrorAction SilentlyContinue
        if ($v -and $v.FileSystemLabel -eq $etiquette) { $_ }
    } | Select-Object -First 1
}
function Lettre-De([object]$partition, [string]$etiquette) {
    if (-not $partition) { throw ("REFUS : partition d'etiquette {0} introuvable sur le disque {1}. Phase 'partitionner' faite ?" -f $etiquette, $DisqueSeagate) }
    if (-not $partition.DriveLetter -or $partition.DriveLetter -eq "`0") {
        $l = (68..90 | Where-Object { -not (Test-Path ("{0}:" -f [char]$_)) } | Select-Object -First 1)
        if (-not $l) { throw "REFUS : plus une seule lettre de lecteur libre." }
        Add-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath ("{0}:" -f [char]$l)
        Start-Sleep -Seconds 1
        $partition = Get-Partition -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber
    }
    return ("{0}:" -f $partition.DriveLetter)
}

# ============================================================================
switch ($Phase) {

# ----------------------------------------------------------------------------
'inventaire' {
    Titre "Inventaire -- rien n'est ecrit"
    Get-Disk | Select-Object Number,FriendlyName,@{n='Go';e={[math]::Round($_.Size/1GB,1)}},PartitionStyle,BusType,IsBoot,IsSystem |
        Format-Table -AutoSize | Out-String -Width 160 | Write-Host
    foreach ($d in Get-Disk) {
        Dire ("--- disque {0} : {1}" -f $d.Number, $d.FriendlyName) 'Cyan'
        Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | ForEach-Object {
            $v = $_ | Get-Volume -ErrorAction SilentlyContinue
            $desc = if ($v) { "{0} {1}, {2:N1} Go dont {3:N1} occupes" -f $v.FileSystem, $v.FileSystemLabel, ($v.Size/1GB), (($v.Size-$v.SizeRemaining)/1GB) } else { "sans volume" }
            Dire ("   {0}. {1,8:N1} Go  {2,-12} {3}" -f $_.PartitionNumber, ($_.Size/1GB), $_.Type, $desc)
        }
    }

    Titre "Ce que la copie va couter"
    $c = Get-Volume -DriveLetter C
    $occupe = $c.Size - $c.SizeRemaining
    Dire ("C: occupe        : {0:N1} Go" -f ($occupe/1GB))
    Dire ("Partition visee  : {0} Go sur la Seagate" -f $TailleWindowsGo)
    if ($occupe/1GB -gt $TailleWindowsGo * 0.9) {
        Dire ("ATTENTION : C: occupe {0:N1} Go, soit plus de 90 % de la partition visee." -f ($occupe/1GB)) 'Yellow'
    }
    # Mesure du 2026-08-21 sur ce disque : 24 Mo/s en soutenu.
    $sec = $occupe / 24MB
    Dire ("Duree estimee    : capture ~{0:N0} min, application ~{1:N0} min (24 Mo/s mesures sur ce disque)" -f (($sec*0.6)/60), ($sec/60))

    Titre "Ce qui pourrait empecher la copie"
    $hib = Test-Path 'C:\hiberfil.sys'
    Dire ("hiberfil.sys     : {0}" -f $(if ($hib) { "PRESENT -- desactiver l'hibernation (powercfg /h off) avant de cloner" } else { "absent, tres bien" })) $(if ($hib) {'Yellow'} else {'Green'})
    try {
        $bl = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        Dire ("BitLocker        : {0} / protection {1}" -f $bl.VolumeStatus, $bl.ProtectionStatus) $(if ($bl.ProtectionStatus -eq 'On') {'Yellow'} else {'Green'})
        if ($bl.ProtectionStatus -eq 'On') { Dire "                   Un clone d'un volume chiffre ne demarrera pas. Suspendre ou dechiffrer." 'Yellow' }
    } catch { Dire "BitLocker        : etat illisible (pas eleve ?)" 'Yellow' }
    $vss = Get-Service VSS -ErrorAction SilentlyContinue
    Dire ("Service VSS      : {0}" -f $(if ($vss) { $vss.Status } else { "ABSENT" }))
    Dire ("dism.exe         : {0}" -f $(if (Get-Command dism.exe -ErrorAction SilentlyContinue) { "present" } else { "ABSENT" }))

    Titre "Ce qu'il reste a faire"
    Dire "  1. Verifier l'ISO de S gravee sur la cle AVANT de toucher a la Seagate."
    Dire "     Sans elle, effacer la Seagate laisse la machine sans aucun S."
    Dire "  2. -Phase partitionner   (efface la Seagate)"
    Dire "  3. -Phase capturer"
    Dire "  4. -Phase appliquer"
    Dire "  5. -Phase preparer-usb"
    Dire "  6. F12 -> Seagate. Windows doit demarrer."
    Dire "  7. Seulement ensuite : installer S sur le NVMe depuis l'ISO."
}

# ----------------------------------------------------------------------------
'partitionner' {
    Exiger-Elevation
    $d = Exiger-Seagate
    Titre "Repartitionner la Seagate"
    Dire ("Cible : disque {0} -- {1} -- {2:N2} To" -f $d.Number, $d.FriendlyName, ($d.Size/1TB)) 'Cyan'

    Dire ""
    Dire "CE QUI VA ETRE DETRUIT :" 'Red'
    $trouve = $false
    Get-Partition -DiskNumber $DisqueSeagate -ErrorAction SilentlyContinue | ForEach-Object {
        $trouve = $true
        $v = $_ | Get-Volume -ErrorAction SilentlyContinue
        Dire ("  partition {0} : {1:N1} Go {2}" -f $_.PartitionNumber, ($_.Size/1GB), $(if ($v) { "-- $($v.FileSystem) $($v.FileSystemLabel)" } else { "-- sans volume lisible par Windows" })) 'Red'
    }
    if ($trouve) {
        Dire ""
        Dire "  L'une de ces partitions est TRES PROBABLEMENT l'installation de S" 'Red'
        Dire "  (ext4, que Windows n'affiche pas). Elle sera perdue." 'Red'
        Dire "  Ne continuer QUE si l'ISO de S est deja gravee et verifiee sur la cle." 'Red'
    }

    if (-not $SansConfirmation) {
        Dire ""
        $r = Read-Host ("Taper exactement : EFFACER LA SEAGATE ET Y METTRE WINDOWS")
        if ($r -ne 'EFFACER LA SEAGATE ET Y METTRE WINDOWS') { throw "Annule." }
    }

    Get-Partition -DiskNumber $DisqueSeagate -ErrorAction SilentlyContinue | Remove-Partition -Confirm:$false
    Start-Sleep -Seconds 2
    $style = (Get-Disk -Number $DisqueSeagate).PartitionStyle
    if     ($style -eq 'RAW') { Initialize-Disk -Number $DisqueSeagate -PartitionStyle GPT }
    elseif ($style -ne 'GPT') { Set-Disk -Number $DisqueSeagate -PartitionStyle GPT }
    Dire "Table GPT en place" 'Green'

    # ESP. 1 Gio et non 512 Mio : c'est le format recommande depuis Windows 11,
    # et la place ne manque pas sur 4,5 To.
    $esp = New-Partition -DiskNumber $DisqueSeagate -Size 1GB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
    $lettreEsp = Lettre-De $esp 'ESP'
    Format-Volume -Partition (Get-Partition -DiskNumber $DisqueSeagate -PartitionNumber $esp.PartitionNumber) `
        -FileSystem FAT32 -NewFileSystemLabel 'ESP-S' -Confirm:$false | Out-Null
    Dire ("ESP        : 1 Gio, FAT32, monte sur {0}" -f $lettreEsp) 'Green'

    # MSR. Windows l'attend sur tout disque GPT qu'il gere ; 16 Mio.
    $null = New-Partition -DiskNumber $DisqueSeagate -Size 16MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    Dire "MSR        : 16 Mio" 'Green'

    $win = New-Partition -DiskNumber $DisqueSeagate -Size ($TailleWindowsGo * 1GB) -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
    $lettreWin = Lettre-De $win 'WINDOWS-S'
    Format-Volume -Partition (Get-Partition -DiskNumber $DisqueSeagate -PartitionNumber $win.PartitionNumber) `
        -FileSystem NTFS -NewFileSystemLabel 'WINDOWS-S' -Confirm:$false | Out-Null
    Dire ("Windows    : {0} Go, NTFS, monte sur {1}" -f $TailleWindowsGo, $lettreWin) 'Green'

    # Le reste en NTFS : journalise (exFAT ne l'est pas, et un debranchement
    # brutal y corrompt le volume entier), et lu-ecrit nativement par le pilote
    # ntfs3 du noyau de S.
    $dat = New-Partition -DiskNumber $DisqueSeagate -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
    $lettreDat = Lettre-De $dat 'DONNEES'
    Format-Volume -Partition (Get-Partition -DiskNumber $DisqueSeagate -PartitionNumber $dat.PartitionNumber) `
        -FileSystem NTFS -NewFileSystemLabel 'DONNEES' -Confirm:$false | Out-Null
    Dire ("Donnees    : {0:N2} To, NTFS, monte sur {1}" -f ($dat.Size/1TB), $lettreDat) 'Green'

    Dire ""
    Dire "Note pour S : deux partitions NTFS coexistent desormais sur ce disque." 'Yellow'
    Dire "s-monter-windows ne choisit plus 'la plus grosse' -- il monte chaque" 'Yellow'
    Dire "candidate en lecture seule et garde celle qui contient vraiment" 'Yellow'
    Dire "Windows\System32\config\SYSTEM." 'Yellow'
}

# ----------------------------------------------------------------------------
'capturer' {
    Exiger-Elevation
    $null = Exiger-Seagate
    Titre "Capturer C: dans un fichier image"

    $dat = Trouver-Partition $DisqueSeagate 'DONNEES'
    $lettreDat = Lettre-De $dat 'DONNEES'
    $wim = "$lettreDat\S-sauvegarde\windows-c.wim"
    New-Item -ItemType Directory -Path (Split-Path $wim) -Force | Out-Null

    if (Test-Path 'C:\hiberfil.sys') {
        throw "REFUS : hiberfil.sys present. Lancer 'powercfg /h off', redemarrer, puis recommencer."
    }

    # POURQUOI UN CLICHE VSS PLUTOT QUE C: DIRECTEMENT. Capturer un volume
    # pendant qu'il tourne donne une image incoherente : les ruches de registre
    # sont ouvertes en ecriture et changent PENDANT la lecture. Le cliche fige
    # l'instant. C'est le seul moyen, sur un Windows en marche, d'obtenir une
    # copie qui demarre.
    Dire "Cliche instantane de C:..." 'Cyan'
    $r = (Get-CimInstance -ClassName Win32_ShadowCopy -List | Invoke-CimMethod -MethodName Create -Arguments @{ Volume = 'C:\'; Context = 'ClientAccessible' })
    if ($r.ReturnValue -ne 0) { throw ("REFUS : creation du cliche refusee, code {0}." -f $r.ReturnValue) }
    $cliche = Get-CimInstance Win32_ShadowCopy | Where-Object { $_.ID -eq $r.ShadowID }
    if (-not $cliche) { throw "REFUS : cliche cree mais introuvable." }
    Dire ("  cliche : {0}" -f $cliche.DeviceObject) 'Green'

    # DISM veut un CHEMIN DE DOSSIER, pas un peripherique : on relie le cliche
    # a un point de montage. La barre finale n'est pas decorative -- sans elle
    # le lien ne se cree pas.
    $lien = 'C:\cliche-s'
    if (Test-Path $lien) { cmd /c rmdir "$lien" | Out-Null }
    cmd /c mklink /d "$lien" ($cliche.DeviceObject + '\') | Out-Null
    if (-not (Test-Path "$lien\Windows\System32\config\SYSTEM")) {
        throw "REFUS : le cliche ne montre pas une installation Windows."
    }
    Dire ("  monte  : {0}" -f $lien) 'Green'

    try {
        Dire ""
        Dire ("Capture vers {0} -- comptez plus d'une heure." -f $wim) 'Cyan'
        $chrono = [System.Diagnostics.Stopwatch]::StartNew()
        & dism.exe /Capture-Image /ImageFile:"$wim" /CaptureDir:"$lien\" /Name:"Windows C" /Description:"Clone de C: de la M720q" /Compress:fast
        if ($LASTEXITCODE -ne 0) { throw ("ECHEC : dism /Capture-Image a rendu {0}." -f $LASTEXITCODE) }
        $chrono.Stop()
        $t = Get-Item $wim
        Dire ("Capture faite : {0:N1} Go en {1:hh\:mm\:ss}" -f ($t.Length/1GB), $chrono.Elapsed) 'Green'
    } finally {
        cmd /c rmdir "$lien" | Out-Null
        $cliche | Remove-CimInstance -ErrorAction SilentlyContinue
        Dire "Cliche libere" 'Green'
    }

    Dire ""
    Dire "Ce .wim EST la copie de sauvegarde de Windows demandee." 'Green'
    Dire "Il reste sur la Seagate meme apres l'installation de S, et il se relit" 'Green'
    Dire "avec 'dism /Apply-Image' sur n'importe quelle partition." 'Green'
}

# ----------------------------------------------------------------------------
'appliquer' {
    Exiger-Elevation
    $null = Exiger-Seagate
    Titre "Deplier l'image dans la partition Windows de la Seagate"

    $dat = Trouver-Partition $DisqueSeagate 'DONNEES'
    $win = Trouver-Partition $DisqueSeagate 'WINDOWS-S'
    $lettreDat = Lettre-De $dat 'DONNEES'
    $lettreWin = Lettre-De $win 'WINDOWS-S'
    $wim = "$lettreDat\S-sauvegarde\windows-c.wim"
    if (-not (Test-Path $wim)) { throw "REFUS : $wim introuvable. Phase 'capturer' faite ?" }

    # On refuse de deplier sur une partition qui porte deja quelque chose :
    # deux Windows melanges ne demarrent pas, et le diagnostic serait atroce.
    $dejaLa = @(Get-ChildItem "$lettreWin\" -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^(System Volume Information|\$RECYCLE\.BIN)$' })
    if ($dejaLa.Count -gt 0 -and -not $SansConfirmation) {
        Dire ("ATTENTION : {0} n'est pas vide ({1} entrees)." -f $lettreWin, $dejaLa.Count) 'Yellow'
        $r = Read-Host "Taper OUI pour ecrire quand meme"
        if ($r -ne 'OUI') { throw "Annule." }
    }

    Dire ("Application de {0} vers {1} -- comptez plus d'une heure." -f $wim, $lettreWin) 'Cyan'
    $chrono = [System.Diagnostics.Stopwatch]::StartNew()
    & dism.exe /Apply-Image /ImageFile:"$wim" /Index:1 /ApplyDir:"$lettreWin\"
    if ($LASTEXITCODE -ne 0) { throw ("ECHEC : dism /Apply-Image a rendu {0}." -f $LASTEXITCODE) }
    $chrono.Stop()
    Dire ("Applique en {0:hh\:mm\:ss}" -f $chrono.Elapsed) 'Green'

    if (-not (Test-Path "$lettreWin\Windows\System32\config\SYSTEM")) {
        throw "ECHEC : le clone ne porte pas Windows\System32\config\SYSTEM."
    }
    Dire "Le clone porte bien une installation Windows" 'Green'
}

# ----------------------------------------------------------------------------
'preparer-usb' {
    Exiger-Elevation
    $null = Exiger-Seagate
    Titre "Rendre le clone amorcable depuis un port USB"

    $esp = Trouver-Partition $DisqueSeagate 'ESP-S'
    $win = Trouver-Partition $DisqueSeagate 'WINDOWS-S'
    $lettreEsp = Lettre-De $esp 'ESP-S'
    $lettreWin = Lettre-De $win 'WINDOWS-S'
    if (-not (Test-Path "$lettreWin\Windows\System32\config\SYSTEM")) {
        throw "REFUS : pas de Windows dans $lettreWin. Phase 'appliquer' faite ?"
    }

    # --- 1. Les fichiers d'amorcage sur l'ESP de la Seagate -----------------
    Dire "Ecriture des fichiers d'amorcage sur l'ESP..." 'Cyan'
    & bcdboot.exe "$lettreWin\Windows" /s $lettreEsp /f UEFI
    if ($LASTEXITCODE -ne 0) { throw ("ECHEC : bcdboot a rendu {0}." -f $LASTEXITCODE) }
    foreach ($f in @("$lettreEsp\EFI\Microsoft\Boot\bootmgfw.efi", "$lettreEsp\EFI\Microsoft\Boot\BCD")) {
        if (Test-Path $f) { Dire ("  {0}" -f $f) 'Green' } else { throw ("ECHEC : {0} absent apres bcdboot." -f $f) }
    }
    # Le chemin de repli. Le firmware de cette machine a deja amorce la Seagate
    # par \EFI\BOOT\BOOTX64.EFI le 2026-08-21 : c'est la voie qui a fait ses
    # preuves ici, et elle ne demande aucune entree dans le BIOS.
    New-Item -ItemType Directory -Path "$lettreEsp\EFI\BOOT" -Force | Out-Null
    Copy-Item "$lettreEsp\EFI\Microsoft\Boot\bootmgfw.efi" "$lettreEsp\EFI\BOOT\BOOTX64.EFI" -Force
    Dire ("  {0}\EFI\BOOT\BOOTX64.EFI (chemin de repli)" -f $lettreEsp) 'Green'

    # --- 2. Le registre du CLONE -------------------------------------------
    Dire ""
    Dire "Armement des pilotes USB dans le registre du clone..." 'Cyan'
    $ruche = "$lettreWin\Windows\System32\config\SYSTEM"
    & reg.exe load 'HKLM\CLONE_S' "$ruche" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "ECHEC : impossible de charger la ruche SYSTEM du clone." }
    try {
        # Le jeu de controle actif n'est pas toujours le 001 : on le lit.
        $sel = (Get-ItemProperty 'HKLM:\CLONE_S\Select' -Name Current).Current
        $cs  = "HKLM:\CLONE_S\ControlSet{0:D3}" -f $sel
        Dire ("  jeu de controle actif : {0}" -f $cs)

        # Start=0 veut dire "charge par le chargeur d'amorcage", avant meme
        # que le noyau ne monte le disque. C'est exactement ce qui manque a une
        # installation nee sur du NVMe : elle n'embarque pas de quoi lire un
        # disque USB au moment ou elle doit lire son propre disque.
        $pilotes = @('USBSTOR','usbstor','UASPStor','uaspstor','usbhub','USBHUB3','usbhub3',
                     'USBXHCI','usbxhci','usbehci','usbohci','usbuhci','usbccgp',
                     'iusb3hub','iusb3xhc','EhStorClass','disk','partmgr','volmgr','volsnap')
        $armes = @(); $absents = @()
        foreach ($p in $pilotes) {
            $k = "$cs\Services\$p"
            if (Test-Path $k) {
                Set-ItemProperty -Path $k -Name 'Start' -Value 0 -Type DWord
                $armes += $p
            } else { $absents += $p }
        }
        Dire ("  armes   ({0}) : {1}" -f $armes.Count, ($armes -join ', ')) 'Green'
        if ($absents.Count) { Dire ("  absents ({0}) : {1}" -f $absents.Count, ($absents -join ', ')) 'Gray' }
        if ($armes.Count -lt 3) { throw "ECHEC : moins de trois pilotes armes -- la ruche n'est pas celle attendue." }

        # "Systeme d'exploitation portable" : Windows cesse d'hiberner, cesse
        # d'ecrire sur les disques internes, et accepte de vivre sur un support
        # amovible. C'est le drapeau que pose Windows To Go.
        $ctrl = "$cs\Control"
        Set-ItemProperty -Path $ctrl -Name 'PortableOperatingSystem' -Value 1 -Type DWord
        Dire "  PortableOperatingSystem = 1" 'Green'

        # LES LETTRES DE LECTEUR DOIVENT ETRE OUBLIEES. MountedDevices garde la
        # correspondance "lettre -> signature de volume". Copiee telle quelle,
        # elle designe les volumes du NVMe : le clone chercherait son C: sur un
        # disque qui n'est plus le sien. On efface, Windows redecouvre.
        $md = 'HKLM:\CLONE_S\MountedDevices'
        if (Test-Path $md) {
            $n = (Get-Item $md).GetValueNames().Count
            foreach ($v in (Get-Item $md).GetValueNames()) { Remove-ItemProperty -Path $md -Name $v -ErrorAction SilentlyContinue }
            Dire ("  MountedDevices : {0} correspondances effacees" -f $n) 'Green'
        }
    } finally {
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()   # sinon reg unload echoue
        & reg.exe unload 'HKLM\CLONE_S' | Out-Null
        Dire "  ruche refermee" 'Green'
    }

    Dire ""
    Dire "PRET. Maintenant, et avant de toucher au NVMe :" 'Cyan'
    Dire "  1. Redemarrer, F12, choisir la Seagate." 'Cyan'
    Dire "  2. Le PREMIER demarrage du clone est LENT -- Windows redecouvre" 'Cyan'
    Dire "     tout son materiel. Plusieurs minutes d'ecran fixe sont normales." 'Cyan'
    Dire "  3. Si l'ecran bleu dit INACCESSIBLE_BOOT_DEVICE : le clone ne sait" 'Yellow'
    Dire "     pas lire son disque. Le Windows du NVMe est intact -- redemarrer" 'Yellow'
    Dire "     dessus et on cherche quel pilote manque." 'Yellow'
    Dire ""
    Dire "  NE PAS EFFACER LE NVMe TANT QUE LE POINT 1 N'A PAS REUSSI." 'Red'
}

# ----------------------------------------------------------------------------
'verifier' {
    Titre "Ce que porte la Seagate"
    $null = Exiger-Seagate
    foreach ($e in @('ESP-S','WINDOWS-S','DONNEES')) {
        $p = Trouver-Partition $DisqueSeagate $e
        if (-not $p) { Dire ("{0,-10} : ABSENTE" -f $e) 'Red'; continue }
        $v = $p | Get-Volume
        Dire ("{0,-10} : {1:N1} Go, {2}, lettre {3}" -f $e, ($p.Size/1GB), $v.FileSystem, $p.DriveLetter) 'Green'
    }
    $esp = Trouver-Partition $DisqueSeagate 'ESP-S'
    $win = Trouver-Partition $DisqueSeagate 'WINDOWS-S'
    if ($esp) {
        $l = Lettre-De $esp 'ESP-S'
        foreach ($f in @("$l\EFI\Microsoft\Boot\bootmgfw.efi","$l\EFI\Microsoft\Boot\BCD","$l\EFI\BOOT\BOOTX64.EFI")) {
            Dire ("  {0} : {1}" -f $f, $(if (Test-Path $f) { "present" } else { "ABSENT" })) $(if (Test-Path $f) {'Green'} else {'Red'})
        }
    }
    if ($win) {
        $l = Lettre-De $win 'WINDOWS-S'
        $ruche = "$l\Windows\System32\config\SYSTEM"
        Dire ("  {0} : {1}" -f $ruche, $(if (Test-Path $ruche) { "present" } else { "ABSENT" })) $(if (Test-Path $ruche) {'Green'} else {'Red'})
        if (Test-Path $ruche) {
            & reg.exe load 'HKLM\CLONE_V' "$ruche" | Out-Null
            try {
                $sel = (Get-ItemProperty 'HKLM:\CLONE_V\Select' -Name Current).Current
                $cs  = "HKLM:\CLONE_V\ControlSet{0:D3}" -f $sel
                foreach ($p in @('USBSTOR','usbxhci','USBXHCI','uaspstor','UASPStor','usbhub3','USBHUB3')) {
                    $k = "$cs\Services\$p"
                    if (Test-Path $k) {
                        $s = (Get-ItemProperty $k -Name Start -ErrorAction SilentlyContinue).Start
                        Dire ("  pilote {0,-10} Start={1} {2}" -f $p, $s, $(if ($s -eq 0) { "(arme)" } else { "(PAS arme)" })) $(if ($s -eq 0) {'Green'} else {'Yellow'})
                    }
                }
                $po = (Get-ItemProperty "$cs\Control" -Name PortableOperatingSystem -ErrorAction SilentlyContinue).PortableOperatingSystem
                Dire ("  PortableOperatingSystem = {0}" -f $po) $(if ($po -eq 1) {'Green'} else {'Yellow'})
                $md = @((Get-Item 'HKLM:\CLONE_V\MountedDevices' -ErrorAction SilentlyContinue).GetValueNames()).Count
                Dire ("  MountedDevices : {0} correspondances (0 attendu)" -f $md) $(if ($md -eq 0) {'Green'} else {'Yellow'})
            } finally {
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                & reg.exe unload 'HKLM\CLONE_V' | Out-Null
            }
        }
    }
}

}
