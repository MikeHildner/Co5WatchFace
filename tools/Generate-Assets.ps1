# Generates the hand images and a placeholder preview for the Circle of Fifths face.
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

# ---- Placeholder preview (450x450) drawn at 10:08:32. Replace with an emulator screenshot later. ----
$bmp, $g = New-Canvas 450 450
$g.FillEllipse([System.Drawing.Brushes]::Black, 0, 0, 450, 450)
$linePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 0x5f, 0x63, 0x68)), 1.5
$g.DrawEllipse($linePen, 22, 22, 406, 406)
$g.DrawEllipse($linePen, 60, 60, 330, 330)
$g.DrawEllipse($linePen, 105, 105, 240, 240)
for ($k = 0; $k -lt 60; $k++) {
  $a = $k * 6 * [math]::PI / 180
  if ($k % 5 -eq 0) { $r1 = 206; $linePen.Width = 3 } else { $r1 = 214; $linePen.Width = 1.5 }
  $g.DrawLine($linePen, [float](225 + $r1 * [math]::Sin($a)), [float](225 - $r1 * [math]::Cos($a)), [float](225 + 222 * [math]::Sin($a)), [float](225 - 222 * [math]::Cos($a)))
}
$linePen.Width = 1
for ($k = 0; $k -lt 12; $k++) {
  $a = (15 + $k * 30) * [math]::PI / 180
  $g.DrawLine($linePen, [float](225 + 120 * [math]::Sin($a)), [float](225 - 120 * [math]::Cos($a)), [float](225 + 203 * [math]::Sin($a)), [float](225 - 203 * [math]::Cos($a)))
}
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center
$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
$S = [string][char]0x266F   # ♯
$B = [string][char]0x266D   # ♭
$majors = @("C","G","D","A","E","B","F$S/G$B","D$B","A$B","E$B","B$B","F")
$minors = @("a","e","b","f$S","c$S","g$S","d$S/e$B","b$B","f","c","g","d")
$fMaj = New-Object System.Drawing.Font "Segoe UI", 22, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$fMin = New-Object System.Drawing.Font "Segoe UI", 16, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$fMaj = New-Object System.Drawing.Font "Segoe UI", 30, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$fMin = New-Object System.Drawing.Font "Segoe UI", 21, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$grey = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0x9a, 0xa0, 0xa6))
for ($i = 0; $i -lt 12; $i++) {
  $a = $i * 30 * [math]::PI / 180
  $g.DrawString($majors[$i], $fMaj, $white, [float](225 + 184 * [math]::Sin($a)), [float](225 - 184 * [math]::Cos($a)), $fmt)
  $g.DrawString($minors[$i], $fMin, $grey, [float](225 + 143 * [math]::Sin($a)), [float](225 - 143 * [math]::Cos($a)), $fmt)
}
# date window
$g.DrawRectangle($linePen, 249, 209, 68, 32)
$fDate = New-Object System.Drawing.Font "Segoe UI", 18, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString("WED 24", $fDate, $grey, 283, 225, $fmt)
# hands at 10:08:32
function Hand($angleDeg, $len, $tail, $width, $brush) {
  $a = $angleDeg * [math]::PI / 180
  $dx = [math]::Sin($a); $dy = -[math]::Cos($a)
  $nx = -$dy; $ny = $dx
  $pts = [System.Drawing.PointF[]]@(
    (P (225 + $dx * $len) (225 + $dy * $len)),
    (P (225 + $dx * ($len - 20) + $nx * $width / 2) (225 + $dy * ($len - 20) + $ny * $width / 2)),
    (P (225 - $dx * $tail + $nx * $width / 2) (225 - $dy * $tail + $ny * $width / 2)),
    (P (225 - $dx * $tail - $nx * $width / 2) (225 - $dy * $tail - $ny * $width / 2)),
    (P (225 + $dx * ($len - 20) - $nx * $width / 2) (225 + $dy * ($len - 20) - $ny * $width / 2)))
  $g.FillPolygon($brush, $pts)
}
Hand (10 * 30 + 8 * 0.5) 140 20 14 $white
Hand (8 * 6) 200 25 10 $white
$red = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0xe5, 0x39, 0x35))
$redPen = New-Object System.Drawing.Pen $red, 2
$a = 32 * 6 * [math]::PI / 180
$g.DrawLine($redPen, [float](225 - 40 * [math]::Sin($a)), [float](225 + 40 * [math]::Cos($a)), [float](225 + 212 * [math]::Sin($a)), [float](225 - 212 * [math]::Cos($a)))
$g.FillEllipse($white, 215, 215, 20, 20)
$g.FillEllipse([System.Drawing.Brushes]::Black, 222, 222, 6, 6)
Save $bmp $g "preview.png"
