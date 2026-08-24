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
#   2. partitionner  la SEAGATE est effacee et repartitionnee : ESP, MSR,
#                    500 Go de NTFS pour Windows, et TOUT LE RESTE laisse
#                    VIERGE au type Linux -- c'est S qui le formatera en ext4,
#                    Windows ne sachant pas le faire. Le NVMe n'est pas
#                    touche : S y sera pose plus tard, et seulement si l'etape
#                    6 a reussi.
#   3. capturer      photo coherente de C: (cliche VSS) vers un .wim pose sur
#                    C: -- pas sur la Seagate, dont tout ce qui n'est pas
#                    Windows sera de l'ext4 que Windows ne sait pas ecrire.
#   4. appliquer     le .wim est deplie dans la partition Windows de la Seagate.
#                    C'est ELLE, amorcable, qui est la copie de sauvegarde.
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
    # 500 Go, decide par l'utilisateur le 2026-08-23. C: occupe ~104 Go une
    # fois les .qcow2 partis : il reste de la marge pour des annees d'usage
    # sans avoir a repartitionner un disque amorcable.
    [long] $TailleWindowsGo = 500,
    # Ou se depose l'image intermediaire. Elle ne peut PAS aller sur la Seagate :
    # tout ce qui n'est pas Windows y sera de l'ext4, que Windows ne sait ni
    # ecrire ni meme voir.
    [string] $Wim = 'C:\S-sauvegarde\windows-c.wim',
    [switch] $SansConfirmation,
    [switch] $SansAntivirus
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
# POURQUOI PAS Test-Path POUR SAVOIR SI UNE LETTRE EST LIBRE. Mesure du
# 2026-08-24, sur cette machine : D: et E: portent des volumes AMOVIBLES SANS
# MEDIA -- taille 0, OperationalStatus "Unknown". Test-Path rend alors FALSE
# alors que la lettre est bel et bien prise, et Add-PartitionAccessPath refuse
# avec "The requested access path is already in use". Un lecteur de cartes
# vide, une cle dont Windows ne lit aucune partition, un lecteur optique :
# trois facons banales de tomber dedans.
#
# On interroge donc la pile de stockage elle-meme, par quatre voies qui ne
# voient pas les memes choses. Et surtout : LA SEULE AUTORITE SUR UNE LETTRE
# LIBRE, C'EST LA TENTATIVE. On essaie chaque candidate et on garde la premiere
# que Windows accepte, au lieu de parier sur un inventaire.
function Lettres-Prises {
    $prises = @{}
    $noter  = { param($c) if ($c) { $prises[([string]$c).ToUpper().TrimEnd(':')] = $true } }
    Get-Volume -ErrorAction SilentlyContinue | ForEach-Object { & $noter $_.DriveLetter }
    Get-Partition -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.DriveLetter -and $_.DriveLetter -ne "`0") { & $noter $_.DriveLetter }
    }
    Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | ForEach-Object { & $noter $_.DeviceID }
    Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name.Length -eq 1) { & $noter $_.Name }
    }
    return $prises
}
# POURQUOI L'ESP NE SE CHERCHE PAS PAR SON ETIQUETTE. Mesure du 2026-08-24 sur
# la Seagate fraichement partitionnee : Windows NE REND AUCUN VOLUME pour une
# partition EFI System -- Get-Volume ne la liste pas, meme quand elle porte une
# lettre et un FAT32 valide. La chercher par FileSystemLabel rend donc TOUJOURS
# $null, et le refus ne tomberait que deux phases plus loin.
#
# On la reconnait a son TYPE GPT, propriete de la TABLE DE PARTITION et non du
# systeme de fichiers : celui-la, Windows le rend toujours.
function Trouver-ESP([int]$disque) {
    Get-Partition -DiskNumber $disque -ErrorAction SilentlyContinue |
        Where-Object { $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' } |
        Select-Object -First 1
}
function Lettre-De([object]$partition, [string]$etiquette) {
    if (-not $partition) { throw ("REFUS : partition d'etiquette {0} introuvable sur le disque {1}. Phase 'partitionner' faite ?" -f $etiquette, $DisqueSeagate) }
    if (-not $partition.DriveLetter -or $partition.DriveLetter -eq "`0") {
        $prises     = Lettres-Prises
        $candidates = 68..90 | Where-Object { -not $prises[[string][char]$_] }
        if (-not $candidates) { throw "REFUS : plus une seule lettre de lecteur libre." }
        $posee = $null
        foreach ($c in $candidates) {
            $lettre = "{0}:" -f [char]$c
            try {
                Add-PartitionAccessPath -DiskNumber $partition.DiskNumber `
                    -PartitionNumber $partition.PartitionNumber -AccessPath $lettre -ErrorAction Stop
                $posee = $lettre
                break
            } catch {
                Dire ("  {0} refusee ({1}), on essaie la suivante" -f $lettre, $_.Exception.Message.Trim()) 'DarkGray'
            }
        }
        if (-not $posee) { throw "REFUS : aucune lettre de D a Z n'a ete acceptee par Windows." }
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

    # LE RESTE EST A S, ET WINDOWS NE PEUT PAS LE FORMATER.
    # Decision de l'utilisateur, 2026-08-23 : ce qui reste sert PLEINEMENT a S
    # -- jeux Steam et Proton, prefixes Windows, conteneurs Debian, images
    # Android. Tout cela exige les permissions et les liens symboliques d'un
    # systeme de fichiers Unix ; une bibliotheque Steam sur NTFS est un nid a
    # pannes. Donc ext4.
    #
    # Or Windows ne sait pas creer d'ext4. On pose donc la partition au BON TYPE
    # GPT -- "Linux filesystem data" -- et on la laisse VIERGE. C'est S qui la
    # formatera, par "s-grand-disque --preparer", une fois installe.
    #
    # Ne pas lui donner de lettre : Windows proposerait de la formater a chaque
    # branchement, et un clic distrait suffirait a la reprendre.
    $dat = New-Partition -DiskNumber $DisqueSeagate -UseMaximumSize -GptType '{0fc63daf-8483-4772-8e79-3d69d8477de4}'
    Dire ("Pour S     : {0:N2} To, type Linux, VIERGE -- a formater depuis S" -f ($dat.Size/1TB)) 'Green'

    Dire ""
    Dire "Ce disque ne portera qu'UNE partition NTFS : celle de Windows." 'Cyan'
    Dire "s-monter-windows la trouvera en montant chaque candidate en lecture" 'Cyan'
    Dire "seule et en gardant celle qui contient Windows\System32\config\SYSTEM." 'Cyan'
    Dire ""
    Dire "La grande partition est VIERGE. Depuis S, une fois installe :" 'Yellow'
    Dire "    sudo s-grand-disque --preparer     # formate en ext4, une seule fois" 'Yellow'
}

# ----------------------------------------------------------------------------
'capturer' {
    Exiger-Elevation
    $null = Exiger-Seagate
    Titre "Capturer C: dans un fichier image"

    # L'IMAGE NE PEUT PAS ALLER SUR LA SEAGATE, et c'est une consequence directe
    # du choix d'ext4 : hors la partition Windows, ce disque n'a plus rien que
    # Windows sache ecrire. L'image se depose donc sur C:, d'ou elle sera
    # depliee vers la Seagate a l'etape suivante.
    $wim = $Wim
    New-Item -ItemType Directory -Path (Split-Path $wim) -Force | Out-Null

    if (Test-Path 'C:\hiberfil.sys') {
        throw "REFUS : hiberfil.sys present. Lancer 'powercfg /h off', redemarrer, puis recommencer."
    }

    # La place, avant d'engager une heure de travail. Une image /Compress:fast
    # tourne autour de 55 a 70 % du volume occupe ; on exige 80 % par prudence.
    $c = Get-Volume -DriveLetter C
    $occupe = $c.Size - $c.SizeRemaining
    $besoin = [long]($occupe * 0.8)
    $libre  = (Get-Volume -DriveLetter ((Split-Path $wim -Qualifier).TrimEnd(':'))).SizeRemaining
    Dire ("C: occupe {0:N1} Go -- il faut environ {1:N1} Go pour l'image, {2:N1} Go libres" -f `
          ($occupe/1GB), ($besoin/1GB), ($libre/1GB)) 'Cyan'
    if ($libre -lt $besoin) {
        throw ("REFUS : {0:N1} Go libres, il en faut environ {1:N1}." -f ($libre/1GB), ($besoin/1GB))
    }

    # POURQUOI UN CLICHE VSS PLUTOT QUE C: DIRECTEMENT. Capturer un volume
    # pendant qu'il tourne donne une image incoherente : les ruches de registre
    # sont ouvertes en ecriture et changent PENDANT la lecture. Le cliche fige
    # l'instant. C'est le seul moyen, sur un Windows en marche, d'obtenir une
    # copie qui demarre.
    Dire "Cliche instantane de C:..." 'Cyan'
    # Get-CimInstance N'A PAS de parametre -List : c'est l'idiome de l'ancien
    # Get-WmiObject, et melanger les deux familles coute une phase entiere.
    # Pour appeler une methode STATIQUE avec les cmdlets CIM, on vise la CLASSE
    # directement par Invoke-CimMethod -ClassName.
    $r = Invoke-CimMethod -ClassName Win32_ShadowCopy -MethodName Create `
             -Arguments @{ Volume = 'C:\'; Context = 'ClientAccessible' }
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

    # POURQUOI UNE LISTE D'EXCLUSION, ET CE QU'ELLE A COUTE D'APPRENDRE.
    # Le 2026-08-24, une capture est morte a 64 % apres 2 h 47 de travail, sur
    # "Error: 6 -- Descripteur non valide". Le journal de DISM nomme le fichier
    # qui l'a tuee : C:\cliche-s\Users\Ghis\OneDrive\....pdf,
    # HRESULT=0x80070006.
    #
    # Les fichiers "a la demande" de OneDrive ne sont pas des fichiers : ce sont
    # des marqueurs, dont le contenu est rendu par un pilote de filtre qui va le
    # chercher dans le nuage a l'ouverture. A travers un cliche VSS EN LECTURE
    # SEULE cette rehydratation ne peut pas aboutir, et le descripteur rendu est
    # invalide. Sur cette machine, 2 122 fichiers sur 2 125 sont dans cet etat.
    #
    # C'est aussi ce qui rendait la capture si lente : DISM tentait de les
    # telecharger un par un, et n'avait fait que 64 % en 2 h 47.
    #
    # Les exclure ne perd rien -- leur contenu vit dans le nuage, et le clone
    # resynchronisera a la premiere connexion. On les CHERCHE plutot que de les
    # coder en dur : un autre compte, un OneDrive d'entreprise, et une liste
    # figee laisserait repasser trois heures.
    #
    # ATTENTION : fournir /ConfigFile REMPLACE les exclusions par defaut de
    # DISM. Il faut donc les redonner en entier, pagefile et compagnie compris.
    $exclusions = @('\$ntfs.log', '\hiberfil.sys', '\pagefile.sys',
                    '\swapfile.sys', '\System Volume Information',
                    '\RECYCLER', '\$Recycle.Bin', '\Windows\CSC',
                    '\cliche-s')
    $nuage = @()
    Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Get-ChildItem $_.FullName -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'OneDrive*' } | ForEach-Object {
                $nuage += $_.FullName
                $exclusions += ($_.FullName -replace '^[A-Za-z]:', '')
            }
    }
    foreach ($n in $nuage) {
        $tous    = @(Get-ChildItem $n -Recurse -File -Force -ErrorAction SilentlyContinue)
        $enLigne = @($tous | Where-Object { $_.Attributes -band [IO.FileAttributes]::Offline })
        Dire ("  exclu : {0} -- {1} fichiers, dont {2} en ligne seulement" -f $n, $tous.Count, $enLigne.Count) 'Yellow'
    }
    if (-not $nuage) { Dire "  aucun dossier OneDrive trouve" 'Gray' }

    $conf = Join-Path $env:TEMP 's-capture-exclusions.ini'
    Set-Content -Path $conf -Value (@('[ExclusionList]') + $exclusions) -Encoding ASCII
    Dire ("  liste d'exclusion : {0} entrees" -f $exclusions.Count) 'Green'

    # L'antivirus scanne chaque octet lu a travers le cliche. C'est le second
    # facteur de lenteur, et il se retire le temps de la copie -- SUR DEMANDE
    # SEULEMENT, et remis en place dans le "finally" quoi qu'il arrive.
    $avPoses = @()
    if ($SansAntivirus) {
        foreach ($chemin in @($lien, (Split-Path $wim))) {
            try { Add-MpPreference -ExclusionPath $chemin -ErrorAction Stop; $avPoses += $chemin } catch {}
        }
        Dire ("  antivirus ecarte de : {0}" -f ($avPoses -join ', ')) 'Yellow'
    } else {
        Dire "  antivirus ACTIF pendant la copie -- relancer avec -SansAntivirus pour l'ecarter" 'Gray'
    }

    try {
        Dire ""
        Dire ("Capture vers {0} -- comptez plus d'une heure." -f $wim) 'Cyan'
        $chrono = [System.Diagnostics.Stopwatch]::StartNew()
        & dism.exe /Capture-Image /ImageFile:"$wim" /CaptureDir:"$lien\" /ConfigFile:"$conf" /Name:"Windows C" /Description:"Clone de C: de la M720q" /Compress:fast
        if ($LASTEXITCODE -ne 0) { throw ("ECHEC : dism /Capture-Image a rendu {0}." -f $LASTEXITCODE) }
        $chrono.Stop()
        $t = Get-Item $wim
        Dire ("Capture faite : {0:N1} Go en {1:hh\:mm\:ss}" -f ($t.Length/1GB), $chrono.Elapsed) 'Green'
    } finally {
        cmd /c rmdir "$lien" | Out-Null
        $cliche | Remove-CimInstance -ErrorAction SilentlyContinue
        foreach ($chemin in $avPoses) { Remove-MpPreference -ExclusionPath $chemin -ErrorAction SilentlyContinue }
        if ($avPoses) { Dire 'Antivirus remis en place' 'Green' }
        Remove-Item $conf -Force -ErrorAction SilentlyContinue
        Dire "Cliche libere" 'Green'
    }

    Dire ""
    Dire "Ce .wim est une IMAGE INTERMEDIAIRE, posee sur C:." 'Cyan'
    Dire "La vraie copie de sauvegarde sera la partition Windows amorcable de la" 'Cyan'
    Dire "Seagate, produite a l'etape suivante. Si vous voulez GARDER une image" 'Cyan'
    Dire "redepliable apres coup, recopiez ce fichier dans le clone une fois qu'il" 'Cyan'
    Dire "demarre -- il y a la place." 'Cyan'
}

# ----------------------------------------------------------------------------
'appliquer' {
    Exiger-Elevation
    $null = Exiger-Seagate
    Titre "Deplier l'image dans la partition Windows de la Seagate"

    $win = Trouver-Partition $DisqueSeagate 'WINDOWS-S'
    $lettreWin = Lettre-De $win 'WINDOWS-S'
    $wim = $Wim
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
    # -SansAntivirus vaut ici aussi. Ne pas l'implementer dans cette phase
    # aurait rendu le drapeau SILENCIEUSEMENT SANS EFFET sur la plus longue des
    # deux -- le genre de faux succes que ce depot s'interdit. Le depliage ecrit
    # ~110 Go de petits fichiers, et chacun passe sous l'analyse en temps reel.
    $avPoses = @()
    if ($SansAntivirus) {
        foreach ($chemin in @("$lettreWin\", (Split-Path $wim))) {
            try { Add-MpPreference -ExclusionPath $chemin -ErrorAction Stop; $avPoses += $chemin } catch {}
        }
        Dire ("  antivirus ecarte de : {0}" -f ($avPoses -join ', ')) 'Yellow'
    }
    try {
        $chrono = [System.Diagnostics.Stopwatch]::StartNew()
        & dism.exe /Apply-Image /ImageFile:"$wim" /Index:1 /ApplyDir:"$lettreWin\"
        if ($LASTEXITCODE -ne 0) { throw ("ECHEC : dism /Apply-Image a rendu {0}." -f $LASTEXITCODE) }
        $chrono.Stop()
    } finally {
        foreach ($chemin in $avPoses) { Remove-MpPreference -ExclusionPath $chemin -ErrorAction SilentlyContinue }
        if ($avPoses) { Dire 'Antivirus remis en place' 'Green' }
    }
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

    $esp = Trouver-ESP $DisqueSeagate
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
    foreach ($e in @('ESP-S','WINDOWS-S')) {
        $p = if ($e -eq 'ESP-S') { Trouver-ESP $DisqueSeagate } else { Trouver-Partition $DisqueSeagate $e }
        if (-not $p) { Dire ("{0,-10} : ABSENTE" -f $e) 'Red'; continue }
        $v = $p | Get-Volume -ErrorAction SilentlyContinue
        $fs = if ($v -and $v.FileSystem) { $v.FileSystem } else { 'FAT32 -- volume masque par Windows' }
        Dire ("{0,-10} : {1:N1} Go, {2}, lettre {3}" -f $e, ($p.Size/1GB), $fs, $p.DriveLetter) 'Green'
    }
    # La grande partition n'a pas de volume que Windows sache lire : on la
    # reconnait a son TYPE GPT, pas a une etiquette. Vue d'ici elle doit avoir
    # l'air vide -- si Windows y voyait un systeme de fichiers, c'est qu'elle
    # aurait ete reprise par autre chose.
    $lin = Get-Partition -DiskNumber $DisqueSeagate -ErrorAction SilentlyContinue |
           Where-Object { $_.GptType -eq '{0fc63daf-8483-4772-8e79-3d69d8477de4}' } | Select-Object -First 1
    if ($lin) {
        $v = $lin | Get-Volume -ErrorAction SilentlyContinue
        $etat = if ($v -and $v.FileSystem) { "ATTENTION : Windows y voit du $($v.FileSystem)" } else { "vierge, comme attendu" }
        Dire ("{0,-10} : {1:N2} To, type Linux, {2}" -f 'POUR-S', ($lin.Size/1TB), $etat) 'Green'
    } else {
        Dire ("{0,-10} : ABSENTE" -f 'POUR-S') 'Red'
    }
    $esp = Trouver-ESP $DisqueSeagate
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
