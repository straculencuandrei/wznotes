# WZNotes / Pixel Notes - PC Desktop Run Script
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "            WZNotes / Pixel Notes - Running on PC (Windows)" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Check and establish ADB USB sync tunnel if Android phone is connected
$adbExe = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (Test-Path $adbExe) {
    Write-Host "Configuring high-speed USB sync tunnel (Port 8485)..." -ForegroundColor DarkCyan
    & $adbExe forward --remove tcp:8484 2>$null
    & $adbExe reverse --remove tcp:8484 2>$null
    & $adbExe forward tcp:8485 tcp:8484 2>$null
}

Write-Host "Launching Windows Desktop App in Debug Mode..." -ForegroundColor Green
Write-Host "Press 'r' in the terminal to Hot Reload, 'R' to Hot Restart, 'q' to Quit." -ForegroundColor Gray
Write-Host ""

& flutter run -d windows @args

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "Session finished with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit..."
