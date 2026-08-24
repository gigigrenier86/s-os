# S -- graver le logo dans le fond d'ecran de l'ecran de connexion.
#
# POURQUOI PASSER PAR L'IMAGE ET NON PAR UN THEME. Le gestionnaire de connexion
# de cette base est Plasma Login Manager, pas SDDM, et il n'a AUCUN systeme de
# themes : son QML est compile dans le binaire. On ne peut donc pas lui ajouter
# un logo par configuration. Le fond d'ecran est le seul pixel de cet ecran que
# S controle -- alors le logo entre dedans.
#
# ECRIT EN ASCII STRICT, et sans syntaxe posterieure a PowerShell 5.1. Un .ps1
# en UTF-8 casse sous 5.1, qui le lit en CP1252 : le piege est consigne dans le
# carnet, et il a deja ete commis une fois ici.
#
# Sortie : foudre-gelee-connexion.png, 3840x2160, versionne au depot et pose
# par COPY dans l'image. Le fond du bureau, lui, ne change pas.
#
# DEUX ALLURES ONT ETE RENDUES ET REGARDEES ; c'est la PLAQUE qui est livree.
# Le filigrane -- le S grandi et fondu dans le coeur de la foudre -- est reste
# dans ce script parce qu'il marche, mais son masque radial mange les
# extremites du S : a l'ecran ce n'est plus un logo, c'est une tache. Juge sur
# l'image, pas sur l'intention.

[CmdletBinding()]
param(
    [ValidateSet('plaque','filigrane')]
    [string] $Allure = 'plaque',
    [string] $Sortie = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$ici    = Split-Path -Parent $MyInvocation.MyCommand.Path
$racine = (Resolve-Path (Join-Path $ici '..\..')).Path
$fond   = Join-Path $ici 'foudre-gelee.png'
$logo   = Join-Path $racine 'files\usr\share\icons\hicolor\256x256\apps\s-logo.png'
if (-not $Sortie) { $Sortie = Join-Path $ici ('foudre-gelee-connexion-' + $Allure + '.png') }

foreach ($f in @($fond, $logo)) {
    if (-not (Test-Path $f)) { throw "Source absente : $f" }
}

$bg = [System.Drawing.Bitmap]::FromFile($fond)
$lg = [System.Drawing.Bitmap]::FromFile($logo)
Write-Host ("fond : {0}x{1}   logo : {2}x{3}" -f $bg.Width, $bg.Height, $lg.Width, $lg.Height)

# Le fond fait 3840x2160 et l'ecran de la M720q 1920x1080 : tout ce qu'on
# dessine ici sera vu a la MOITIE de sa taille. Un logo de 560 px se lit donc
# 280 px a l'ecran -- la taille d'une grosse icone d'application.
$larg = $bg.Width
$haut = $bg.Height

$g = [System.Drawing.Graphics]::FromImage($bg)
$g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

function New-CoinsArrondis([int]$x, [int]$y, [int]$w, [int]$h, [int]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x,            $y,           $d, $d, 180, 90)
    $p.AddArc($x + $w - $d,  $y,           $d, $d, 270, 90)
    $p.AddArc($x + $w - $d,  $y + $h - $d, $d, $d,   0, 90)
    $p.AddArc($x,            $y + $h - $d, $d, $d,  90, 90)
    $p.CloseFigure()
    return $p
}

if ($Allure -eq 'plaque') {
    # --- Allure 1 : la plaque -------------------------------------------------
    # Le logo est une image OPAQUE sur fond bleu clair -- pas de canal alpha
    # utile (verifie : A=255 aux quatre coins). Pose tel quel sur un ciel
    # sombre, un carre clair ressemble a un autocollant. On lui arrondit donc
    # les coins et on lui donne un halo : ca devient une plaque, c'est-a-dire
    # une intention.
    $taille = 560
    $x = [int](($larg - $taille) / 2)
    # Assez bas pour laisser l'horloge du greeter respirer, assez haut pour ne
    # pas tomber dans le bloc de connexion, qui est centre verticalement.
    $y = 300
    $r = [int]($taille * 0.22)

    # Le halo : des contours concentriques de plus en plus larges et de plus en
    # plus pales. Moins couteux qu'un vrai flou, et suffisant a cette echelle.
    for ($i = 44; $i -ge 1; $i--) {
        $a = [int](26.0 * (1.0 - $i / 45.0))
        if ($a -le 0) { continue }
        $col = [System.Drawing.Color]::FromArgb($a, 150, 190, 255)
        $pen = New-Object System.Drawing.Pen($col, 2)
        $ch  = New-CoinsArrondis ($x - $i) ($y - $i) ($taille + 2 * $i) ($taille + 2 * $i) ($r + $i)
        $g.DrawPath($pen, $ch)
        $pen.Dispose()
        $ch.Dispose()
    }

    $chemin = New-CoinsArrondis $x $y $taille $taille $r
    $ancien = $g.Clip
    $g.SetClip($chemin)
    $g.DrawImage($lg, $x, $y, $taille, $taille)
    $g.Clip = $ancien

    # Un lisere tres pale : il detache la plaque du ciel sans la cerner.
    $pen = New-Object System.Drawing.Pen(([System.Drawing.Color]::FromArgb(70, 220, 235, 255)), 3)
    $g.DrawPath($pen, $chemin)
    $pen.Dispose()
    $chemin.Dispose()

    Write-Host ("plaque : {0}x{0} en ({1},{2}) -- soit {3} px a l'ecran" -f $taille, $x, $y, ($taille / 2))
}
else {
    # --- Allure 2 : le filigrane ---------------------------------------------
    # Le S grandi et fondu dans le coeur de la foudre. Le carre disparait par un
    # masque radial, et le melange est un "eclaircir" : seul ce qui est plus
    # clair que le ciel se voit. Le bloc de connexion peut passer par-dessus
    # sans se battre avec un bord franc.
    $taille = 1040
    $cx = [int]($larg * 0.492)   # le coeur de la foudre, releve sur l'image
    $cy = [int]($haut * 0.530)
    $x  = $cx - [int]($taille / 2)
    $y  = $cy - [int]($taille / 2)

    # On agrandit le logo a part, puis on melange a la main pixel par pixel :
    # System.Drawing n'a pas de mode de fusion.
    $gr = New-Object System.Drawing.Bitmap($taille, $taille, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gg = [System.Drawing.Graphics]::FromImage($gr)
    $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gg.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gg.DrawImage($lg, 0, 0, $taille, $taille)
    $gg.Dispose()

    $rect  = New-Object System.Drawing.Rectangle($x, $y, $taille, $taille)
    $plein = New-Object System.Drawing.Rectangle(0, 0, $taille, $taille)
    $dFond = $bg.LockBits($rect,  [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $dLogo = $gr.LockBits($plein, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,  [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    # LA FOULEE N'EST PAS LA LARGEUR. LockBits sur un SOUS-rectangle rend la
    # foulee de l'image entiere -- 3840*4 ici, pas 1040*4 -- parce qu'il verrouille
    # la zone en place, sans la recopier. Supposer taille*4 donne des bandes
    # horizontales : le defaut a ete vu a l'ecran avant d'etre compris.
    $sF = $dFond.Stride
    $sL = $dLogo.Stride
    $nF = $sF * $taille
    $nL = $sL * $taille
    $bF = New-Object byte[] $nF
    $bL = New-Object byte[] $nL
    [System.Runtime.InteropServices.Marshal]::Copy($dFond.Scan0, $bF, 0, $nF)
    [System.Runtime.InteropServices.Marshal]::Copy($dLogo.Scan0, $bL, 0, $nL)

    $demi  = $taille / 2.0
    $r0    = $demi * 0.34   # jusqu'ici, pleine intensite
    $r1    = $demi * 0.50   # au-dela, plus rien
    $force = 0.92
    for ($py = 0; $py -lt $taille; $py++) {
        $dy = $py - $demi
        for ($px = 0; $px -lt $taille; $px++) {
            $dx = $px - $demi
            $d  = [Math]::Sqrt($dx * $dx + $dy * $dy)
            if ($d -ge $r1) { continue }
            if ($d -le $r0) {
                $a = 1.0
            } else {
                $t = ($r1 - $d) / ($r1 - $r0)
                $a = $t * $t * (3.0 - 2.0 * $t)
            }
            $a  = $a * $force
            $iF = $py * $sF + $px * 4
            $iL = $py * $sL + $px * 4
            for ($c = 0; $c -lt 3; $c++) {
                $f = $bF[$iF + $c]
                $l = $bL[$iL + $c]
                # "eclaircir" pondere : on ne fonce jamais le ciel.
                $v = $f + ($l - $f) * $a
                if ($v -lt $f)   { $v = $f }
                if ($v -gt 255)  { $v = 255 }
                $bF[$iF + $c] = [byte][Math]::Round($v)
            }
        }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($bF, 0, $dFond.Scan0, $nF)
    $bg.UnlockBits($dFond)
    $gr.UnlockBits($dLogo)
    $gr.Dispose()
    Write-Host ("filigrane : {0}x{0} centre en ({1},{2})" -f $taille, $cx, $cy)
}

$g.Dispose()
$bg.Save($Sortie, [System.Drawing.Imaging.ImageFormat]::Png)
$bg.Dispose()
$lg.Dispose()
$o = Get-Item $Sortie
Write-Host ("ecrit : {0}  ({1:N2} Mo)" -f $o.FullName, ($o.Length / 1MB))
