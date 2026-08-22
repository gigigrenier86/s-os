# Foudre gelee — le fond d'ecran de S.
#
# Une lampe electromagnetique au centre, ses filaments de foudre GELES en
# plein vol, et trois grands eclairs qui s'echappent du globe vers les bords.
# Palette glaciale, assortie au logo : bleu de glace, cyan pale, une pointe
# de violet.
#
# Tout est procedural et SEME : le meme Seed rend exactement la meme image.
# La foudre est un deplacement fractal de mi-points ; la lueur, quatre passes
# de trait du plus large et pale au plus fin et blanc — la technique classique
# du « glow » sans flou gaussien, que GDI+ n'offre pas.
#
# ASCII strict, comme tout script de ce depot destine a PowerShell.

param(
    [int]$Seed = 5,
    [int]$Largeur = 3840,
    [int]$Hauteur = 2160,
    [string]$Sortie = "$PSScriptRoot\foudre-gelee.png"
)

Add-Type -AssemblyName System.Drawing

$rnd = New-Object System.Random($Seed)
$bmp = New-Object System.Drawing.Bitmap $Largeur, $Hauteur
$g   = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$cx = $Largeur / 2.0
$cy = $Hauteur / 2.0 + 60
$rGlobe = 840.0

# ---------------------------------------------------------------------------
# Le fond : nuit glaciale, plus profonde aux bords qu'au centre
# ---------------------------------------------------------------------------
$rect = New-Object System.Drawing.Rectangle 0, 0, $Largeur, $Hauteur
$fond = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 6, 9, 20),
    [System.Drawing.Color]::FromArgb(255, 13, 21, 42),
    [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
$g.FillRectangle($fond, $rect)

function Halo([float]$x, [float]$y, [float]$r, [System.Drawing.Color]$centre) {
    $chemin = New-Object System.Drawing.Drawing2D.GraphicsPath
    $chemin.AddEllipse($x - $r, $y - $r, 2 * $r, 2 * $r)
    $pinceau = New-Object System.Drawing.Drawing2D.PathGradientBrush($chemin)
    $pinceau.CenterColor = $centre
    $pinceau.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $centre.R, $centre.G, $centre.B))
    $g.FillEllipse($pinceau, $x - $r, $y - $r, 2 * $r, 2 * $r)
    $pinceau.Dispose(); $chemin.Dispose()
}

# La respiration froide autour de la lampe
Halo $cx $cy 1500 ([System.Drawing.Color]::FromArgb(46, 70, 120, 210))
Halo $cx $cy 950  ([System.Drawing.Color]::FromArgb(40, 110, 170, 255))

# ---------------------------------------------------------------------------
# La foudre : deplacement fractal de mi-points
# ---------------------------------------------------------------------------
function Eclair([float]$x1, [float]$y1, [float]$x2, [float]$y2, [float]$disp, [int]$iter) {
    $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
    $pts.Add([System.Drawing.PointF]::new($x1, $y1))
    $pts.Add([System.Drawing.PointF]::new($x2, $y2))
    $d = $disp
    for ($i = 0; $i -lt $iter; $i++) {
        $nouv = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        for ($j = 0; $j -lt $pts.Count - 1; $j++) {
            $a = $pts[$j]; $b = $pts[$j + 1]
            $dx = $b.X - $a.X; $dy = $b.Y - $a.Y
            $len = [Math]::Sqrt($dx * $dx + $dy * $dy); if ($len -lt 1) { $len = 1 }
            $off = ($rnd.NextDouble() * 2 - 1) * $d
            $nouv.Add($a)
            $nouv.Add([System.Drawing.PointF]::new(
                ($a.X + $b.X) / 2 + (-$dy / $len) * $off,
                ($a.Y + $b.Y) / 2 + ( $dx / $len) * $off))
        }
        $nouv.Add($pts[$pts.Count - 1])
        $pts = $nouv
        $d *= 0.55
    }
    return , $pts.ToArray()
}

# La lueur : du manteau violet au coeur blanc. $e met a l'echelle les largeurs.
function Trace([System.Drawing.PointF[]]$pts, [float]$e = 1.0) {
    $passes = @(
        @(24.0, [System.Drawing.Color]::FromArgb(22, 130, 100, 255)),
        @(11.0, [System.Drawing.Color]::FromArgb(46, 100, 170, 255)),
        @( 4.2, [System.Drawing.Color]::FromArgb(140, 180, 225, 255)),
        @( 1.6, [System.Drawing.Color]::FromArgb(255, 244, 250, 255))
    )
    foreach ($p in $passes) {
        $stylo = New-Object System.Drawing.Pen($p[1], ([float]$p[0] * $e))
        $stylo.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $stylo.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $stylo.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLines($stylo, $pts)
        $stylo.Dispose()
    }
}

# Une branche qui part d'un point d'un eclair, dans une direction donnee
function Branche([System.Drawing.PointF]$origine, [float]$angle, [float]$longueur, [float]$e) {
    $fx = $origine.X + [Math]::Cos($angle) * $longueur
    $fy = $origine.Y + [Math]::Sin($angle) * $longueur
    $pts = Eclair $origine.X $origine.Y $fx $fy ($longueur * 0.16) 6
    Trace $pts $e
}

# ---------------------------------------------------------------------------
# Les filaments de la lampe : du coeur au verre du globe
# ---------------------------------------------------------------------------
for ($i = 0; $i -lt 15; $i++) {
    $angle = $rnd.NextDouble() * 2 * [Math]::PI
    $r     = $rGlobe * (0.86 + $rnd.NextDouble() * 0.14)
    $fx = $cx + [Math]::Cos($angle) * $r
    $fy = $cy + [Math]::Sin($angle) * $r
    $pts = Eclair $cx $cy $fx $fy 95 7
    Trace $pts 0.62
    # Le pied du filament sur le verre : un givre discret
    Halo $fx $fy 34 ([System.Drawing.Color]::FromArgb(96, 200, 235, 255))
    if ($rnd.NextDouble() -lt 0.5) {
        $k = [int]($pts.Count * (0.4 + $rnd.NextDouble() * 0.4))
        Branche $pts[$k] ($angle + ($rnd.NextDouble() - 0.5) * 1.6) (90 + $rnd.NextDouble() * 130) 0.4
    }
}

# ---------------------------------------------------------------------------
# Trois grands eclairs geles qui s'echappent du globe vers les bords
# ---------------------------------------------------------------------------
# Chaque expression est parenthesee : la virgule de PowerShell lie plus fort
# que les operateurs arithmetiques, et « $Largeur - 1.0, x » se lirait
# « $Largeur - (1.0, x) » — une soustraction sur un tableau.
$sorties = @(
    @(0.0,              ($Hauteur * 0.22)),
    @(($Largeur - 1.0), ($Hauteur * 0.30)),
    @(($Largeur * 0.80), 0.0)
)
foreach ($s in $sorties) {
    $angle = [Math]::Atan2([float]$s[1] - $cy, [float]$s[0] - $cx)
    $dx = $cx + [Math]::Cos($angle) * $rGlobe * 0.55
    $dy = $cy + [Math]::Sin($angle) * $rGlobe * 0.55
    $pts = Eclair $dx $dy ([float]$s[0]) ([float]$s[1]) 170 9
    Trace $pts 1.0
    for ($b = 0; $b -lt 3; $b++) {
        $k = [int]($pts.Count * (0.25 + $rnd.NextDouble() * 0.55))
        Branche $pts[$k] ($angle + ($rnd.NextDouble() - 0.5) * 1.9) (150 + $rnd.NextDouble() * 260) 0.5
    }
}

# ---------------------------------------------------------------------------
# La lampe elle-meme : le globe de verre et l'electrode
# ---------------------------------------------------------------------------
$verre = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(34, 185, 220, 255), 3.5)
$g.DrawEllipse($verre, [float]($cx - $rGlobe), [float]($cy - $rGlobe), [float](2 * $rGlobe), [float](2 * $rGlobe))
$verre.Dispose()
# Le reflet du verre, en haut a gauche — un arc, pas un cercle
$reflet = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60, 220, 240, 255), 7)
$reflet.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$reflet.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawArc($reflet, [float]($cx - $rGlobe + 26), [float]($cy - $rGlobe + 26), [float](2 * $rGlobe - 52), [float](2 * $rGlobe - 52), 205, 40)
$reflet.Dispose()

# L'electrode : un coeur aveuglant
Halo $cx $cy 300 ([System.Drawing.Color]::FromArgb(120, 150, 200, 255))
Halo $cx $cy 130 ([System.Drawing.Color]::FromArgb(210, 220, 240, 255))
Halo $cx $cy 55  ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))

# ---------------------------------------------------------------------------
# Le gel : poussiere de glace et cristaux
# ---------------------------------------------------------------------------
for ($i = 0; $i -lt 1100; $i++) {
    $x = $rnd.NextDouble() * $Largeur
    $y = $rnd.NextDouble() * $Hauteur
    $t = 0.8 + $rnd.NextDouble() * 2.2
    $a = 14 + $rnd.Next(70)
    $pinceau = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, 205, 228, 255))
    $g.FillEllipse($pinceau, [float]$x, [float]$y, [float]$t, [float]$t)
    $pinceau.Dispose()
}
# Quelques cristaux a quatre branches, comme du givre sur une vitre
for ($i = 0; $i -lt 26; $i++) {
    $x = [float]($rnd.NextDouble() * $Largeur)
    $y = [float]($rnd.NextDouble() * $Hauteur)
    $t = [float](5 + $rnd.NextDouble() * 16)
    $a = 26 + $rnd.Next(64)
    $stylo = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($a, 220, 240, 255), 1.1)
    $g.DrawLine($stylo, $x - $t, $y, $x + $t, $y)
    $g.DrawLine($stylo, $x, $y - $t, $x, $y + $t)
    $g.DrawLine($stylo, $x - $t * 0.45, $y - $t * 0.45, $x + $t * 0.45, $y + $t * 0.45)
    $g.DrawLine($stylo, $x - $t * 0.45, $y + $t * 0.45, $x + $t * 0.45, $y - $t * 0.45)
    $stylo.Dispose()
}

# ---------------------------------------------------------------------------
# La vignette : les bords s'assombrissent, l'oeil revient au centre
# ---------------------------------------------------------------------------
$chemin = New-Object System.Drawing.Drawing2D.GraphicsPath
$chemin.AddEllipse(-$Largeur * 0.35, -$Hauteur * 0.5, $Largeur * 1.7, $Hauteur * 2.0)
$vignette = New-Object System.Drawing.Drawing2D.PathGradientBrush($chemin)
$vignette.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
$vignette.SurroundColors = @([System.Drawing.Color]::FromArgb(150, 2, 4, 12))
$g.FillRectangle($vignette, $rect)
$vignette.Dispose(); $chemin.Dispose()

$g.Dispose()
$bmp.Save($Sortie, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Peint : $Sortie ($Largeur x $Hauteur, graine $Seed)"
