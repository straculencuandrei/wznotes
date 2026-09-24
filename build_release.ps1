<#
.SYNOPSIS
    wznotes 1-Click Builder for Windows (.exe / .zip) and Android (.apk)
.DESCRIPTION
    Builds release binaries, places them into a dedicated 'releases/' folder in the root,
    generates version manifests, and automatically opens Windows Explorer showing the files!
#>

param(
    [ValidateSet("all", "windows", "android")]
    [string]$Target = "all",
    [switch]$NoExplorer = $false,
    [switch]$NoGit = $false,
    [string]$ReleaseNotes = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

# 1. Detect current version from pubspec.yaml
$rawPubspec = Get-Content "pubspec.yaml" -Raw
$ver = "0.8.2"
$build = 19
if ($rawPubspec -match "version:\s*([0-9\.]+)\+([0-9]+)") {
    $ver = $Matches[1]
    $build = [int]$Matches[2]
}

# Update update_service.dart fallbacks to stay in sync
$updateServicePath = "lib/infrastructure/update/update_service.dart"
if (Test-Path $updateServicePath) {
    $serviceRaw = Get-Content $updateServicePath -Raw
    $serviceRaw = $serviceRaw -replace "defaultFallbackVersion = '[0-9\.]+';", "defaultFallbackVersion = '$ver';"
    $serviceRaw = $serviceRaw -replace "defaultFallbackBuildNumber = [0-9]+;", "defaultFallbackBuildNumber = $build;"
    Set-Content $updateServicePath -Value $serviceRaw
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   wznotes 1-Click Release Builder (v$ver+$build)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan

# 2. Setup releases folder
$ReleaseDir = Join-Path $ProjectRoot "releases"
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

$generatedFiles = @()

# 3. Build Windows Desktop
if ($Target -eq "all" -or $Target -eq "windows") {
    Write-Host "`n[1/2] Building Windows Desktop Release (x64)..." -ForegroundColor Yellow
    flutter build windows --release

    $winBuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
    if (Test-Path $winBuildDir) {
        $winDestFolder = Join-Path $ReleaseDir "wznotes-windows"
        if (Test-Path $winDestFolder) { Remove-Item $winDestFolder -Recurse -Force }
        Copy-Item -Path $winBuildDir -Destination $winDestFolder -Recurse -Force

        $winZipName = "wznotes-windows-v$ver.zip"
        $winZipPath = Join-Path $ReleaseDir $winZipName
        if (Test-Path $winZipPath) { Remove-Item $winZipPath -Force }
        
        Write-Host "Creating portable ZIP: $winZipName..." -ForegroundColor Gray
        Compress-Archive -Path "$winBuildDir\*" -DestinationPath $winZipPath -Force
        
        $generatedFiles += [PSCustomObject]@{
            File = $winZipName
            Type = "Windows Release ZIP (Upload to GitHub)"
            SizeMB = [math]::Round((Get-Item $winZipPath).Length / 1MB, 2)
            Path = $winZipPath
        }
        $generatedFiles += [PSCustomObject]@{
            File = "wznotes-windows\wznotes.exe"
            Type = "Windows App Executable (Ready to run)"
            SizeMB = [math]::Round((Get-Item (Join-Path $winDestFolder "wznotes.exe")).Length / 1MB, 2)
            Path = Join-Path $winDestFolder "wznotes.exe"
        }
    } else {
        Write-Host "Error: Windows build directory not found at $winBuildDir" -ForegroundColor Red
    }
}

# 4. Build Android APK
if ($Target -eq "all" -or $Target -eq "android") {
    Write-Host "`n[2/2] Building Android Release APK (ARM64 & Universal)..." -ForegroundColor Yellow
    flutter build apk --release

    $apkSource = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkSource) {
        $apkDestName = "wznotes-android-v$ver.apk"
        $apkDestPath = Join-Path $ReleaseDir $apkDestName
        Copy-Item -Path $apkSource -Destination $apkDestPath -Force
        
        $generatedFiles += [PSCustomObject]@{
            File = $apkDestName
            Type = "Android APK (Install on phone / GitHub)"
            SizeMB = [math]::Round((Get-Item $apkDestPath).Length / 1MB, 2)
            Path = $apkDestPath
        }
    } else {
        Write-Host "Error: Android APK not found at $apkSource" -ForegroundColor Red
    }
}

# 5. Update version_manifest.json
$manifest = @{
    version = $ver
    build_number = $build
    title = "wznotes v$ver Update"
    release_notes = if ($ReleaseNotes) { $ReleaseNotes } else { "Centered sleek AMOLED app icons for PC and Android, ultra-lean build, zero-config sync, and VS Code smooth caret" }
    windows_url = "https://github.com/straculencuandrei/wznotes/releases/download/v$ver/wznotes-windows-v$ver.zip"
    android_url = "https://github.com/straculencuandrei/wznotes/releases/download/v$ver/wznotes-android-v$ver.apk"
    is_mandatory = $false
    published_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
}
$manifestJson = $manifest | ConvertTo-Json -Depth 4
Set-Content (Join-Path $ReleaseDir "version_manifest.json") -Value $manifestJson
Set-Content (Join-Path $ProjectRoot "version_manifest.json") -Value $manifestJson

# 6. Display Summary Table
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "   BUILD COMPLETE! All files are in: releases/          " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
$generatedFiles | Format-Table File, Type, SizeMB -AutoSize

Write-Host "Release Directory: $ReleaseDir`n" -ForegroundColor Cyan

# 7. Git Commit, Tag & Push to GitHub
if (-not $NoGit) {
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host "   Sending Release to GitHub & Creating Tag v$ver        " -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Yellow

    git add .
    $statusCheck = (git status --porcelain)
    if ($statusCheck) {
        $commitMsg = if ($ReleaseNotes) { "Release v${ver}+${build}: $ReleaseNotes" } else { "Release v${ver}+${build}" }
        git commit -m $commitMsg
        Write-Host "[GIT] Committed changes: $commitMsg" -ForegroundColor Green
    } else {
        Write-Host "[GIT] Working tree clean, nothing to commit." -ForegroundColor Gray
    }

    Write-Host "[GIT] Creating Git tag: v$ver..." -ForegroundColor Cyan
    git tag -f -a "v$ver" -m "wznotes Release v$ver"

    Write-Host "[GIT] Pushing main and tag v$ver to GitHub..." -ForegroundColor Cyan
    git push origin main
    git push origin "v$ver" --force
    git push origin --tags

    Write-Host "`n[SUCCESS] Tag v$ver successfully published to GitHub!" -ForegroundColor Green
    Write-Host "`nTo attach release binaries (APK / ZIP) to your GitHub Release:" -ForegroundColor Yellow
    Write-Host "👉 https://github.com/straculencuandrei/wznotes/releases/new?tag=v$ver`n" -ForegroundColor Cyan
}

# 8. Automatically open Windows Explorer directly in releases folder!
if (-not $NoExplorer) {
    Write-Host "Opening Windows Explorer to releases folder..." -ForegroundColor Gray
    Invoke-Item $ReleaseDir
}
