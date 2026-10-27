# Print Android SHA-1 and SHA-256 from the project keystore
$androidRoot = Split-Path $PSScriptRoot -Parent
$keystore = Join-Path $androidRoot "keystore\debug.keystore"
$keytool = @(
    "$env:LOCALAPPDATA\Android\Sdk\..\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
) | ForEach-Object { Get-Item $_ -ErrorAction SilentlyContinue } | Select-Object -First 1 -ExpandProperty FullName

if (-not $keytool) {
    $keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
}

if (-not $keytool) {
    Write-Error "keytool not found. Install Android Studio or set JAVA_HOME."
}

if (-not (Test-Path $keystore)) {
    Write-Error "Project keystore not found: $keystore"
}

Write-Host "=== Spy Love — project keystore SHA keys ===" -ForegroundColor Cyan
Write-Host "Keystore: $keystore"
Write-Host "Package:  org.hmg.spy_love"
Write-Host "See also: android/keystore/KEYS.txt"
Write-Host ""

& $keytool -list -v -keystore $keystore -alias androiddebugkey -storepass android -keypass android |
    Select-String -Pattern "SHA1:|SHA256:"
