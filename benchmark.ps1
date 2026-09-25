# WZNotes / Pixel Notes - Writing Performance Benchmark & Diagnostic Runner
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

$logFile = Join-Path $PSScriptRoot "logs benchmark.txt"
try {
    Start-Transcript -Path $logFile -Append -Force | Out-Null
    Write-Host "[Logging Active] Telemetry is being recorded to: logs benchmark.txt" -ForegroundColor Green
} catch {
    Write-Host "[Logging Notice] Could not start transcript: $_" -ForegroundColor Yellow
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "     WZNotes - Heavy Writing Performance & Telemetry Tool       " -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " Diagnostic Telemetry Active:" -ForegroundColor Green
Write-Host "   * Realtime FPS & Frame Render Latency (UI Build + GPU Raster)" -ForegroundColor Gray
Write-Host "   * Keystroke-to-Screen Input Latency (in ms)" -ForegroundColor Gray
Write-Host "   * 8k / 20k / 60k Words Synthetic Stress Testing" -ForegroundColor Gray
Write-Host "   * Live log output saved to: logs benchmark.txt" -ForegroundColor Cyan
Write-Host "   * Press 'P' in this terminal to toggle Flutter's Performance Graph" -ForegroundColor Yellow
Write-Host "   * Press 'v' to launch Flutter DevTools profiler in your browser" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$flutterArgs = @("--android-skip-build-dependency-validation")
$hasExplicitDevice = $false

if ($args.Count -gt 0) {
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq "-d" -or $args[$i] -eq "--device-id") {
            $hasExplicitDevice = $true
        }
    }
    $flutterArgs += $args
}

function Find-AndroidDevice {
    # 1. Fast Path: Query ADB directly in < 50ms without Flutter JSON overhead
    $adbCandidates = @(
        "adb",
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "C:\Android\platform-tools\adb.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools\adb.exe"
    )
    $adbExe = $null
    foreach ($candidate in $adbCandidates) {
        if ($candidate -eq "adb" -and (Get-Command adb -ErrorAction SilentlyContinue)) {
            $adbExe = "adb"; break
        } elseif (Test-Path $candidate) {
            $adbExe = $candidate; break
        }
    }

    if ($adbExe) {
        try {
            $adbOutput = & $adbExe devices -l 2>$null | Out-String
            foreach ($line in ($adbOutput -split "`r?`n")) {
                if ($line -match "^([A-Za-z0-9_\-\.:]+)\s+device\s+(.*)") {
                    $devId = $matches[1]
                    $desc = $matches[2]
                    $model = if ($desc -match "model:([^\s]+)") { $matches[1] } else { "Android Device" }
                    return @{ Id = $devId; Name = $model }
                }
            }
        } catch {}
    }

    # 2. Fallback Path: Query Flutter devices with robust JSON isolation
    try {
        $rawJson = flutter devices --machine 2>$null | Out-String
        $startIdx = $rawJson.IndexOf('[')
        $endIdx = $rawJson.LastIndexOf(']')
        if ($startIdx -ge 0 -and $endIdx -gt $startIdx) {
            $cleanJson = $rawJson.Substring($startIdx, $endIdx - $startIdx + 1)
            $devices = $cleanJson | ConvertFrom-Json
            $android = $devices | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1
            if ($android) {
                return @{ Id = $android.id; Name = $android.name }
            }
        }
    } catch {}

    return $null
}

if ($hasExplicitDevice) {
    Write-Host "Launching with user-specified device arguments: $args" -ForegroundColor Green
    Write-Host ""
    & flutter run @flutterArgs
} else {
    $targetDev = $null
    while ($null -eq $targetDev) {
        Write-Host "Detecting connected Android device..." -ForegroundColor Gray
        $targetDev = Find-AndroidDevice

        if ($targetDev) {
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host " [DEVICE LOCKED] $($targetDev.Name) [ID: $($targetDev.Id)]" -ForegroundColor Green
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host ""
            & flutter run -d $targetDev.Id @flutterArgs
            break
        } else {
            Write-Host ""
            Write-Host "================================================================" -ForegroundColor Red
            Write-Host "   [WARNING] NO CONNECTED ANDROID DEVICE FOUND!" -ForegroundColor Red
            Write-Host "================================================================" -ForegroundColor Red
            Write-Host " * Connect your Pixel 8 via USB cable or wireless ADB." -ForegroundColor Yellow
            Write-Host " * Ensure 'USB Debugging' is turned ON in Developer Options." -ForegroundColor Yellow
            Write-Host " * If prompted on your phone, tap 'Allow USB debugging'." -ForegroundColor Yellow
            Write-Host "----------------------------------------------------------------" -ForegroundColor Gray
            Write-Host " Options:" -ForegroundColor Cyan
            Write-Host "   [R] Retry Android device detection (default)" -ForegroundColor White
            Write-Host "   [W] Run Windows PC build anyway" -ForegroundColor Gray
            Write-Host "   [Q] Quit" -ForegroundColor Gray
            Write-Host ""
            $choice = Read-Host " Enter choice (R/W/Q)"
            if ($choice -match "^[Ww]") {
                Write-Host "Launching Windows PC Desktop build..." -ForegroundColor Yellow
                & flutter run -d windows @flutterArgs
                break
            } elseif ($choice -match "^[Qq]") {
                Write-Host "Exiting benchmark runner." -ForegroundColor Gray
                exit 0
            } else {
                Write-Host "Retrying in 2 seconds..." -ForegroundColor Gray
                Start-Sleep -Seconds 2
            }
        }
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "Benchmark session finished with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
}

try {
    Stop-Transcript | Out-Null
} catch {}

Write-Host ""
Write-Host "Benchmark logs saved to: $logFile" -ForegroundColor Green
Read-Host "Press Enter to exit..."
