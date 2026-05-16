#!/usr/bin/env pwsh
# Generates the Fluff app icon using System.Drawing (GDI+).
# Outputs:
#   assets/icon/fluff_icon_1024.png  - master 1024x1024
#   app/web/favicon.png              - 32x32
#   app/web/icons/Icon-192.png       - 192x192
#   app/web/icons/Icon-512.png       - 512x512
#   app/web/icons/Icon-maskable-192.png
#   app/web/icons/Icon-maskable-512.png

param(
  [string]$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
)

Add-Type -AssemblyName System.Drawing

# Color palette (Material You violet — matches WlmTheme seed).
$bgTop    = [System.Drawing.Color]::FromArgb(255, 182, 157, 248)  # #B69DF8
$bgBottom = [System.Drawing.Color]::FromArgb(255,  79,  55, 139)  # #4F378B
$fg       = [System.Drawing.Color]::White

function Draw-RoundedRect {
  param($graphics, $brush, $x, $y, $w, $h, $r)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2 * $r
  $path.AddArc($x,        $y,        $d, $d, 180, 90)
  $path.AddArc($x+$w-$d,  $y,        $d, $d, 270, 90)
  $path.AddArc($x+$w-$d,  $y+$h-$d,  $d, $d,   0, 90)
  $path.AddArc($x,        $y+$h-$d,  $d, $d,  90, 90)
  $path.CloseFigure()
  $graphics.FillPath($brush, $path)
  $path.Dispose()
  return
}

function Render-Icon {
  param([int]$size, [string]$out, [bool]$maskable = $false)

  # For maskable icons the safe zone is 80% of the canvas; we shrink
  # the artwork into the inner 80% and fill the rest with the gradient.
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode    = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode= [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

  if ($maskable) {
    # Fill entire canvas with gradient (no rounded corners — launcher masks).
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $bgTop, $bgBottom, 90
    $g.FillRectangle($brush, $rect)
    $brush.Dispose()
    # Inset artwork to 80% safe zone.
    $inset = [int]($size * 0.10)
    $artSize = $size - 2 * $inset
    $g.TranslateTransform($inset, $inset)
  } else {
    # Squircle background.
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $bgTop, $bgBottom, 90
    $radius = [int]($size * 0.22)  # 224/1024
    Draw-RoundedRect $g $brush 0 0 $size $size $radius
    $brush.Dispose()
    $artSize = $size
  }

  # Draw the "F" mark (3 rounded rectangles) — proportions tuned at 1024.
  $whiteBrush = New-Object System.Drawing.SolidBrush $fg
  $s = $artSize / 1024.0

  # Vertical stem
  Draw-RoundedRect $g $whiteBrush ([int](340*$s)) ([int](240*$s)) ([int](150*$s)) ([int](544*$s)) ([int](36*$s))
  # Top bar
  Draw-RoundedRect $g $whiteBrush ([int](340*$s)) ([int](240*$s)) ([int](400*$s)) ([int](150*$s)) ([int](36*$s))
  # Middle bar (shorter)
  Draw-RoundedRect $g $whiteBrush ([int](340*$s)) ([int](470*$s)) ([int](300*$s)) ([int](130*$s)) ([int](32*$s))

  # The "fluff" — a small white circle bottom-right of the F as a punctuation accent.
  $dotD = [int](120 * $s)
  $dotX = [int](680 * $s)
  $dotY = [int](664 * $s)
  $g.FillEllipse($whiteBrush, $dotX, $dotY, $dotD, $dotD)

  $whiteBrush.Dispose()

  if ($maskable) { $g.ResetTransform() }

  # Ensure output dir exists.
  $dir = Split-Path $out
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
  Write-Host "wrote $out ($size px)"
}

$targets = @(
  @{ size = 1024; out = "$RepoRoot\assets\icon\fluff_icon_1024.png"; maskable = $false },
  @{ size =  512; out = "$RepoRoot\app\web\icons\Icon-512.png";       maskable = $false },
  @{ size =  192; out = "$RepoRoot\app\web\icons\Icon-192.png";       maskable = $false },
  @{ size =  512; out = "$RepoRoot\app\web\icons\Icon-maskable-512.png"; maskable = $true },
  @{ size =  192; out = "$RepoRoot\app\web\icons\Icon-maskable-192.png"; maskable = $true },
  @{ size =   32; out = "$RepoRoot\app\web\favicon.png";              maskable = $false }
)

foreach ($t in $targets) {
  Render-Icon -size $t.size -out $t.out -maskable $t.maskable
}

Write-Host "`nDone. Master at assets\icon\fluff_icon_1024.png"
