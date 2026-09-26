# Generates the hand images and the sharp/flat/natural glyph images for the Circle of Fifths face.
# The accidentals are rendered from Bravura Text (tools/fonts/BravuraText.otf, SIL OFL) as white
# images; watchface.xml colours them per theme through InlineImage's color attribute.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$out = Join-Path $PSScriptRoot "..\watchface\src\main\res\drawable"
New-Item -ItemType Directory -Force $out | Out-Null

function P([float]$x, [float]$y) { New-Object System.Drawing.PointF $x, $y }

function New-Canvas([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)
  return @($bmp, $g)
}
function Save($bmp, $g, $name) {
  $g.Dispose()
  $bmp.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output "wrote $name"
}

$white = [System.Drawing.Brushes]::White

# Hour hand: 14 x 160, pivot at row 140 (tip 140px above centre, 20px tail)
$bmp, $g = New-Canvas 14 160
$g.FillPolygon($white, [System.Drawing.PointF[]]@((P 7 0), (P 14 22), (P 14 150), (P 7 160), (P 0 150), (P 0 22)))
Save $bmp $g "hand_hour.png"

# Minute hand: 10 x 225, pivot at row 200
$bmp, $g = New-Canvas 10 225
$g.FillPolygon($white, [System.Drawing.PointF[]]@((P 5 0), (P 10 18), (P 10 216), (P 5 225), (P 0 216), (P 0 18)))
Save $bmp $g "hand_minute.png"

# Second hand: 12 x 252, pivot at row 212, thin needle with a round counterweight on the tail
$bmp, $g = New-Canvas 12 252
$g.FillRectangle($white, 5, 0, 2, 252)
$g.FillEllipse($white, 0, 228, 12, 12)
Save $bmp $g "hand_second.png"

# Accidentals from Bravura Text, trimmed to their ink bounds.
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Join-Path $PSScriptRoot "fonts\BravuraText.otf"))
$font = New-Object System.Drawing.Font $pfc.Families[0], 400, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
foreach ($glyph in @(@("acc_sharp", [char]0x266F), @("acc_flat", [char]0x266D), @("acc_natural", [char]0x266E))) {
  $bmp = New-Object System.Drawing.Bitmap 600, 900, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gr = [System.Drawing.Graphics]::FromImage($bmp)
  $gr.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $gr.Clear([System.Drawing.Color]::Transparent)
  $gr.DrawString([string]$glyph[1], $font, $white, 100, 100)
  $gr.Dispose()
  $minX = 600; $minY = 900; $maxX = 0; $maxY = 0
  for ($y = 0; $y -lt 900; $y++) { for ($x = 0; $x -lt 600; $x++) {
    if ($bmp.GetPixel($x, $y).A -gt 8) {
      if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
    } } }
  $w = $maxX - $minX + 1; $h = $maxY - $minY + 1
  $crop = $bmp.Clone((New-Object System.Drawing.Rectangle $minX, $minY, $w, $h), $bmp.PixelFormat)
  $crop.Save((Join-Path $out "$($glyph[0]).png"), [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Output ("wrote {0}.png ({1}x{2})" -f $glyph[0], $w, $h)
  $crop.Dispose(); $bmp.Dispose()
}
