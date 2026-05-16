# Normalises every PNG under docs/screenshots/latest to a uniform
# 1233x1257 canvas. Anything already at the target size is skipped.
# Anything else is cropped to width 1233 (rightmost scrollbar pixels
# dropped) and bottom-padded with the bottom-left edge color so the
# fill matches the page background.
Add-Type -AssemblyName System.Drawing

$root = Join-Path $PSScriptRoot '..\docs\screenshots\latest'
$root = (Resolve-Path $root).Path
$targetW = 1233
$targetH = 1257

$converted = 0
Get-ChildItem -Path $root -Filter *.png | ForEach-Object {
    $path = $_.FullName
    $src = [System.Drawing.Bitmap]::FromFile($path)
    if ($src.Width -eq $targetW -and $src.Height -eq $targetH) {
        $src.Dispose()
        return
    }
    $fill = $src.GetPixel(0, $src.Height - 1)
    $dst = New-Object System.Drawing.Bitmap $targetW, $targetH
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $brush = New-Object System.Drawing.SolidBrush $fill
    $g.FillRectangle($brush, 0, 0, $targetW, $targetH)
    $copyW = [Math]::Min($src.Width, $targetW)
    $copyH = [Math]::Min($src.Height, $targetH)
    $g.DrawImage(
        $src,
        (New-Object System.Drawing.Rectangle 0, 0, $copyW, $copyH),
        (New-Object System.Drawing.Rectangle 0, 0, $copyW, $copyH),
        [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $brush.Dispose()
    $src.Dispose()
    # Write to a temp file first, then move into place so we never
    # leave a half-written PNG if anything throws.
    $tmp = "$path.tmp"
    $dst.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
    Move-Item -Force -Path $tmp -Destination $path
    Write-Host "normalised $($_.Name)"
    $converted++
}
Write-Host "done. converted=$converted"
