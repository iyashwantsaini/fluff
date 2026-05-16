Add-Type -AssemblyName System.Drawing
$rows = @()
Get-ChildItem -Path "c:\repos\fluff\docs\screenshots\latest" -Filter *.png | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $rows += [PSCustomObject]@{ Name = $_.Name; W = $img.Width; H = $img.Height }
    $img.Dispose()
}

$bases = $rows | ForEach-Object { ($_.Name -replace "-(light|dark)\.png$","") } | Sort-Object -Unique
foreach ($b in $bases) {
    $l = $rows | Where-Object { $_.Name -eq "$b-light.png" }
    $d = $rows | Where-Object { $_.Name -eq "$b-dark.png" }
    if (-not $l -or -not $d) { 
        Write-Host "MISSING: $b (light=$($l -ne $null) dark=$($d -ne $null))" 
    }
    elseif ($l.W -ne $d.W -or $l.H -ne $d.H) { 
        Write-Host "MISMATCH: $b light=$($l.W)x$($l.H) dark=$($d.W)x$($d.H)" 
    }
}

Write-Host "--- DIMENSION COUNTS ---"
$rows | Group-Object W, H | Sort-Object Count -Descending | ForEach-Object { "$($_.Count): $($_.Values -join 'x')" } | Select-Object -First 5
