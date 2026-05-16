# Generates an Android release keystore for Fluff and prints the
# values you need to paste into GitHub Actions secrets.
#
# Usage (run ONCE on your machine):
#   pwsh scripts/gen-keystore.ps1
#
# This script:
#   1. Asks for the four passphrases interactively (nothing is stored).
#   2. Runs keytool to produce app/android/keystore/release.jks.
#   3. Prints the base64 of the keystore + the four secret names you
#      must add to GitHub:
#        - KEYSTORE_BASE64
#        - KEYSTORE_PASSWORD
#        - KEY_ALIAS
#        - KEY_PASSWORD
#   4. Writes app/android/key.properties for local release builds.
#
# The keystore + key.properties are git-ignored. Never commit them.

[CmdletBinding()]
param(
  [string]$Alias = 'fluff-release',
  [int]$ValidityDays = 10000,
  [string]$DName = 'CN=Fluff, OU=Apps, O=iyashwantsaini, L=, S=, C=IN'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot/.."
$ksDir = Join-Path $repoRoot 'app/android/keystore'
$ksPath = Join-Path $ksDir 'release.jks'
$propsPath = Join-Path $repoRoot 'app/android/key.properties'

if (Test-Path $ksPath) {
  Write-Host "Keystore already exists at $ksPath" -ForegroundColor Yellow
  $ans = Read-Host 'Overwrite? (y/N)'
  if ($ans -ne 'y') { exit 1 }
  Remove-Item $ksPath -Force
}

New-Item -ItemType Directory -Force -Path $ksDir | Out-Null

$storePass = Read-Host -AsSecureString 'Store password (≥ 6 chars)'
$keyPass   = Read-Host -AsSecureString 'Key password (can match store password)'

# Convert to plaintext only inside the script scope so keytool can
# consume them via -storepass / -keypass.
$bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePass)
$bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPass)
try {
  $storePlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
  $keyPlain   = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)

  & keytool -genkey -v `
    -keystore $ksPath `
    -alias $Alias `
    -keyalg RSA `
    -keysize 4096 `
    -validity $ValidityDays `
    -storepass $storePlain `
    -keypass $keyPlain `
    -dname $DName
  if ($LASTEXITCODE -ne 0) { throw 'keytool failed' }

  # key.properties for local `flutter build apk --release`.
  Set-Content -Path $propsPath -Value @"
storeFile=keystore/release.jks
storePassword=$storePlain
keyAlias=$Alias
keyPassword=$keyPlain
"@

  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ksPath))

  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host 'Add these 4 GitHub Actions secrets:' -ForegroundColor Green
  Write-Host '  Settings → Secrets and variables → Actions → New repository secret'
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host ''
  Write-Host 'KEYSTORE_BASE64 =' -ForegroundColor Cyan
  Write-Host $b64
  Write-Host ''
  Write-Host 'KEYSTORE_PASSWORD =' -ForegroundColor Cyan
  Write-Host $storePlain
  Write-Host ''
  Write-Host 'KEY_ALIAS =' -ForegroundColor Cyan
  Write-Host $Alias
  Write-Host ''
  Write-Host 'KEY_PASSWORD =' -ForegroundColor Cyan
  Write-Host $keyPlain
  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Green
  Write-Host "Local key.properties written to $propsPath"
  Write-Host 'The keystore + key.properties are git-ignored.'
}
finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
}
