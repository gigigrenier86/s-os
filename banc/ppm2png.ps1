param($src, $dst)
Add-Type -AssemblyName System.Drawing
$bytes = [IO.File]::ReadAllBytes($src)
$hdr = [Text.Encoding]::ASCII.GetString($bytes, 0, 40)
if ($hdr -notmatch '^P6\s+(\d+)\s+(\d+)\s+(\d+)\s') { throw "en-tete PPM inattendu" }
$w = [int]$Matches[1]; $h = [int]$Matches[2]; $off = ($Matches[0]).Length
$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$data = $bmp.LockBits((New-Object System.Drawing.Rectangle(0,0,$w,$h)), [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $bmp.PixelFormat)
$row = New-Object byte[] $data.Stride
for ($y = 0; $y -lt $h; $y++) {
  for ($x = 0; $x -lt $w; $x++) {
    $s = $off + ($y * $w + $x) * 3
    $row[$x*3] = $bytes[$s+2]; $row[$x*3+1] = $bytes[$s+1]; $row[$x*3+2] = $bytes[$s]
  }
  [Runtime.InteropServices.Marshal]::Copy($row, 0, [IntPtr]::Add($data.Scan0, $y * $data.Stride), $data.Stride)
}
$bmp.UnlockBits($data); $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
"$w x $h -> $dst"
