<#
.SYNOPSIS
    wznotes Unified One-Click Update Publisher & Packager
.DESCRIPTION
    Builds both Windows Desktop and Android Release packages, updates versions,
    generates version_manifest.json, and organizes everything into the dist/ directory.
#>

param(
    [string]$NewVersion = "",
    [int]$BuildNumber = 0,
    [string]$ReleaseNotes = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "`n================================================" -ForegroundColor Yellow
Write-Host "   wznotes Unified Release & Update Builder   " -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Yellow

# 1. Prompt for Version if not provided
if ([string]::IsNullOrWhiteSpace($NewVersion)) {
    $currentPubspec = Get-Content "pubspec.yaml" -Raw
    if ($currentPubspec -match "version:\s*([0-9\.]+)\+([0-9]+)") {
        $detectedVer = $Matches[1]
        $detectedBuild = [int]$Matches[2]
        Write-Host "Current Version: v$detectedVer (Build $detectedBuild)" -ForegroundColor Gray
    }
    
    $NewVersion = Read-Host "Enter New Version (e.g. 0.8.0)"
    if ([string]::IsNullOrWhiteSpace($NewVersion)) {
        Write-Host "Version cannot be empty. Aborting." -ForegroundColor Red
        exit 1
    }
}

if ($BuildNumber -le 0) {
    $inputBuild = Read-Host "Enter Build Number (e.g. 8)"
    if ([string]::IsNullOrWhiteSpace($inputBuild)) {
        $BuildNumber = 8
    } else {
        $BuildNumber = [int]$inputBuild
    }
}

function Test-IsNewerVersion([string]$newVer, [int]$newBuild, [string]$curVer, [int]$curBuild) {
    if ($newBuild -gt $curBuild) { return $true }
    
    $newParts = $newVer.Split('.') | ForEach-Object { [int]$_ }
    $curParts = $curVer.Split('.') | ForEach-Object { [int]$_ }

    for ($i = 0; $i -lt 3; $i++) {
        $n = if ($i -lt $newParts.Count) { $newParts[$i] } else { 0 }
        $c = if ($i -lt $curParts.Count) { $curParts[$i] } else { 0 }
        if ($n -gt $c) { return $true }
        if ($n -lt $c) { return $false }
    }
    return $false
}

$isNewer = Test-IsNewerVersion $NewVersion $BuildNumber $detectedVer $detectedBuild
if (-not $isNewer) {
    Write-Host "`n⚠️  DUPLICATE / SAME VERSION WARNING!" -ForegroundColor Yellow
    Write-Host "New Version: v$NewVersion+$BuildNumber is IDENTICAL to or OLDER than current v$detectedVer+$detectedBuild." -ForegroundColor Red
    Write-Host "Clients will NOT recognize this as a new update unless the version or build number is increased." -ForegroundColor Yellow
    $confirm = Read-Host "Do you still want to proceed anyway? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Aborted by user." -ForegroundColor Red
        exit 0
    }
}

$FullVersion = "$NewVersion+$BuildNumber"
Write-Host "`n[1/5] Updating pubspec.yaml and UpdateService to $FullVersion..." -ForegroundColor Green

# Update pubspec.yaml
$rawPubspec = Get-Content "pubspec.yaml" -Raw
$newPubspec = $rawPubspec -replace "version:\s*[0-9\.\+]+", "version: $FullVersion"
Set-Content "pubspec.yaml" -Value $newPubspec

# Update update_service.dart
$updateServicePath = "lib/infrastructure/update/update_service.dart"
if (Test-Path $updateServicePath) {
    $rawService = Get-Content $updateServicePath -Raw
    $rawService = $rawService -replace "static const String currentVersion = '[0-9\.]+';", "static const String currentVersion = '$NewVersion';"
    $rawService = $rawService -replace "static const int currentBuildNumber = [0-9]+;", "static const int currentBuildNumber = $BuildNumber;"
    Set-Content $updateServicePath -Value $rawService
}

# Create dist directory
$DistDir = Join-Path $ProjectRoot "dist"
if (Test-Path $DistDir) {
    Remove-Item -Path $DistDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DistDir | Out-Null

Write-Host "`n[2/5] Building Windows Desktop Release..." -ForegroundColor Green
flutter build windows

$WinReleaseDir = "build\windows\x64\runner\Release"
if (Test-Path $WinReleaseDir) {
    $ZipPath = Join-Path $DistDir "wznotes-windows-v$NewVersion.zip"
    Write-Host "Compressing Windows release to $ZipPath..." -ForegroundColor Cyan
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    Compress-Archive -Path "$WinReleaseDir\*" -DestinationPath $ZipPath -Force
} else {
    Write-Host "Warning: Windows build directory not found at $WinReleaseDir" -ForegroundColor Yellow
}

Write-Host "`n[3/5] Building Android Release APK..." -ForegroundColor Green
try {
    flutter build apk --release
    $ApkSource = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $ApkSource) {
        $ApkDest = Join-Path $DistDir "wznotes-android-v$NewVersion.apk"
        Copy-Item -Path $ApkSource -Destination $ApkDest -Force
        Write-Host "Saved APK to $ApkDest" -ForegroundColor Cyan
    }
} catch {
    Write-Host "Note: Android build skipped or failed (check Android SDK/JDK if building APK)." -ForegroundColor Yellow
}

Write-Host "`n[4/5] Generating version_manifest.json..." -ForegroundColor Green
$ManifestData = @{
    version = $NewVersion
    build_number = $BuildNumber
    title = "wznotes v$NewVersion Update"
    release_notes = $ReleaseNotes
    windows_url = "https://github.com/straculencuandrei/wznotes/releases/download/v$NewVersion/wznotes-windows-v$NewVersion.zip"
    android_url = "https://github.com/straculencuandrei/wznotes/releases/download/v$NewVersion/wznotes-android-v$NewVersion.apk"
    is_mandatory = $false
    published_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$ManifestJson = $ManifestData | ConvertTo-Json -Depth 4
Set-Content (Join-Path $DistDir "version_manifest.json") -Value $ManifestJson
Set-Content (Join-Path $ProjectRoot "version_manifest.json") -Value $ManifestJson

Write-Host "`n================================================" -ForegroundColor Yellow
Write-Host "   Release Packages Ready in: $DistDir   " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Yellow
Get-ChildItem $DistDir | Select-Object Name, Length

Write-Host "`nTo publish this update to your users:" -ForegroundColor Cyan
Write-Host "1. Push to GitHub: git add . && git commit -m 'Release v${NewVersion}+${BuildNumber}' && git push" -ForegroundColor Gray
Write-Host "2. Upload files in dist/ to GitHub Release v$NewVersion (or your hosting server)." -ForegroundColor Gray
Write-Host "All running PC and Mobile wznotes apps will automatically detect this update!`n" -ForegroundColor Green
