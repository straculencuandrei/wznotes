# WZNotes / Pixel Notes - PC Desktop Run Script
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "            WZNotes / Pixel Notes - Running on PC (Windows)" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

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
