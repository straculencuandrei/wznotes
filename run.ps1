# WZNotes / Pixel Notes - Quick Run Script
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "              WZNotes / Pixel Notes - Quick Run" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if ($args.Count -gt 0) {
    Write-Host "Launching with arguments: $args" -ForegroundColor Green
    & flutter run --android-skip-build-dependency-validation @args
} else {
    Write-Host "Detecting connected Android device..." -ForegroundColor Gray
    try {
        $rawJson = flutter devices --machine | Out-String
        $devices = $rawJson | ConvertFrom-Json
        $androidDev = $devices | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1
        
        if ($androidDev) {
            Write-Host "Targeting: $($androidDev.name) [ID: $($androidDev.id)]" -ForegroundColor Green
            Write-Host ""
            & flutter run -d $androidDev.id --android-skip-build-dependency-validation
        } else {
            Write-Host "No Android device found. Defaulting to standard run..." -ForegroundColor Yellow
            Write-Host ""
            & flutter run --android-skip-build-dependency-validation
        }
    } catch {
        Write-Host "Device auto-detection fallback. Running standard flutter run..." -ForegroundColor Yellow
        Write-Host ""
        & flutter run --android-skip-build-dependency-validation
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "Session finished with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "You can target a specific device using:" -ForegroundColor Yellow
    Write-Host "  run.bat -d 37231FDJH0048J" -ForegroundColor Gray
    Write-Host "  run.bat -d windows" -ForegroundColor Gray
    Write-Host "================================================================" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit..."
