# WZNotes - Telemetry & Device Log Capture
$ErrorActionPreference = "Continue"
Set-Location -Path $PSScriptRoot

$logPath = Join-Path $PSScriptRoot "logs benchmark.txt"
$header = "`n================================================================`n" +
          "   BENCHMARK LOG CAPTURE - " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + "`n" +
          "================================================================"
Add-Content -Path $logPath -Value $header

$adbCandidates = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe",
    "C:\Users\buzunar\AppData\Local\Android\Sdk\platform-tools\adb.exe",
    "adb.exe"
)

$adb = $adbCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $adb) { $adb = "adb" }

Write-Host "Connecting to Android device via ADB ($adb)..." -ForegroundColor Cyan
try {
    $devices = & $adb devices | Out-String
    if ($devices -match 'device\r?\n') {
        Write-Host "Extracting latest benchmark results & engine telemetry from Pixel 8..." -ForegroundColor Green
        $rawLogs = & $adb logcat -d -v time -s flutter:V Choreographer:I HWUI:I
        
        # Filter to benchmark sessions and frame metrics
        $filteredLogs = $rawLogs | Where-Object { 
            $_ -match 'BENCHMARK' -or 
            $_ -match 'PERF JANK' -or 
            $_ -match 'DIAGNOSTIC' -or 
            $_ -match 'KEY ' -or
            $_ -match 'Choreographer'
        }
        
        if ($filteredLogs.Count -gt 0) {
            Add-Content -Path $logPath -Value ($filteredLogs -join "`n")
            Write-Host "Appended $($filteredLogs.Count) benchmark telemetry lines to logs benchmark.txt" -ForegroundColor Green
        } else {
            # Fallback: append all last 500 lines
            $lastLines = $rawLogs | Select-Object -Last 500
            Add-Content -Path $logPath -Value ($lastLines -join "`n")
            Write-Host "Appended $($lastLines.Count) device log lines to logs benchmark.txt" -ForegroundColor Green
        }
    } else {
        Write-Host "No connected Android device found via ADB." -ForegroundColor Yellow
    }
} catch {
    Write-Host "ADB dump notice: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Telemetry saved to: $logPath" -ForegroundColor Green
Start-Process notepad.exe -ArgumentList "`"$logPath`""
