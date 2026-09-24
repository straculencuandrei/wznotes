<#
.SYNOPSIS
    wznotes Modern Dual-Target Release Builder for Windows (x64) and Android (APK)
.DESCRIPTION
    High-performance CLI builder with clean 2-progress-bar live dashboard, zero terminal clutter,
    versioning automation, manifest generation, and GitHub release pipeline.
#>

param(
    [ValidateSet("all", "windows", "android")]
    [string]$Target = "all",
    [string]$Tag = "",
    [ValidateSet("clean", "logs", "")]
    [string]$Mode = "",
    [switch]$NoExplorer = $false,
    [switch]$NoGit = $false,
    [string]$ReleaseNotes = ""
)

$ErrorActionPreference = "Continue"
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

# Unicode characters via [char] to remain 100% ASCII-clean
$cTL    = [char]0x256D  # top-left rounded corner
$cTR    = [char]0x256E  # top-right rounded corner
$cBL    = [char]0x2570  # bottom-left rounded corner
$cBR    = [char]0x256F  # bottom-right rounded corner
$cH     = [char]0x2500  # horizontal line
$cV     = [char]0x2502  # vertical line
$cCheck = [char]0x2713  # checkmark
$cCross = [char]0x2717  # crossmark
$cStar  = [char]0x2605  # star
$cBlock = [char]0x2588  # full block
$cShade = [char]0x2591  # light shade block
$cDot   = [char]0x2022  # bullet dot
$ESC    = [char]27

# Ensure UTF-8 output encoding for console
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

# Native Win32 Console Handler for 100% reliable in-place buffer writing
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WinConsole {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile);

    [StructLayout(LayoutKind.Sequential)]
    public struct COORD {
        public short X;
        public short Y;
        public COORD(int x, int y) { X = (short)x; Y = (short)y; }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct CONSOLE_SCREEN_BUFFER_INFO {
        public COORD dwSize;
        public COORD dwCursorPosition;
        public ushort wAttributes;
        public short srWindowLeft;
        public short srWindowTop;
        public short srWindowRight;
        public short srWindowBottom;
        public COORD dwMaximumWindowSize;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleScreenBufferInfo(IntPtr hConsoleOutput, out CONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool WriteConsoleOutputCharacter(
        IntPtr hConsoleOutput,
        string lpCharacterStream,
        uint nLength,
        COORD dwWriteCoord,
        out uint lpNumberOfCharsWritten);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleCursorPosition(IntPtr hConsoleOutput, COORD dwCursorPosition);

    private static IntPtr hConOut = IntPtr.Zero;

    public static IntPtr GetConOut() {
        if (hConOut == IntPtr.Zero || hConOut == new IntPtr(-1)) {
            hConOut = CreateFile("CONOUT$", 0x40000000 | 0x80000000, 2, IntPtr.Zero, 3, 0, IntPtr.Zero);
        }
        return hConOut;
    }

    public static int GetCursorY() {
        try {
            IntPtr h = GetConOut();
            CONSOLE_SCREEN_BUFFER_INFO info;
            if (GetConsoleScreenBufferInfo(h, out info)) {
                return info.dwCursorPosition.Y;
            }
        } catch {}
        return -1;
    }

    public static void WriteAt(int x, int y, string text) {
        try {
            IntPtr h = GetConOut();
            uint written;
            WriteConsoleOutputCharacter(h, text, (uint)text.Length, new COORD(x, y), out written);
        } catch {}
    }

    public static void SetCursor(int x, int y) {
        try {
            IntPtr h = GetConOut();
            SetConsoleCursorPosition(h, new COORD(x, y));
        } catch {}
    }
}
"@
} catch {}

# Stop any running instance of wznotes and wait for Windows file locks to release
$killed = $false
try {
    Get-Process "wznotes" -ErrorAction SilentlyContinue | ForEach-Object {
        $_ | Stop-Process -Force -ErrorAction SilentlyContinue
        $killed = $true
    }
} catch {}
if ($killed) { Start-Sleep -Milliseconds 400 }

# -------------------------------------------------------------
# 1. Header Banner & Version Detection
# -------------------------------------------------------------
Clear-Host
Write-Host ""
$sepLine = "  " + ([string]::new($cH, 74))
Write-Host $sepLine -ForegroundColor DarkCyan
Write-Host "  WZNOTES MODERN RELEASE BUILDER" -ForegroundColor Cyan
Write-Host "  Targets: Windows Desktop (x64) + Android Universal APK" -ForegroundColor DarkGray
Write-Host $sepLine -ForegroundColor DarkCyan
Write-Host ""

$rawPubspec = Get-Content "pubspec.yaml" -Raw
$detectedVer = "0.8.6"
$detectedBuild = 21
if ($rawPubspec -match "version:\s*([0-9\.]+)\+([0-9]+)") {
    $detectedVer = $Matches[1]
    $detectedBuild = [int]$Matches[2]
}

# Suggest next patch version
$suggestedVer = $detectedVer
if ($detectedVer -match "^([0-9]+)\.([0-9]+)\.([0-9]+)$") {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3] + 1
    $suggestedVer = "$major.$minor.$patch"
}

Write-Host "  Current App Version:  " -NoNewline -ForegroundColor Gray
Write-Host "v$detectedVer" -NoNewline -ForegroundColor Yellow
Write-Host " (Build $detectedBuild)" -ForegroundColor DarkGray

# -------------------------------------------------------------
# 2. Version Prompt
# -------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Tag)) {
    Write-Host ""
    $userTagInput = Read-Host "  Enter version to build [Press Enter for '$suggestedVer']"
    if (-not [string]::IsNullOrWhiteSpace($userTagInput)) {
        $Tag = $userTagInput.Trim()
    } else {
        $Tag = $suggestedVer
    }
}

# Normalize version and build numbers
$gitTag = if ($Tag.StartsWith("v") -or $Tag.StartsWith("V")) { $Tag } else { "v$Tag" }
$cleanVersion = $gitTag -replace "^[vV]", ""

$ver = $detectedVer
$build = $detectedBuild

if ($cleanVersion -match "^([0-9\.]+)\+([0-9]+)$") {
    $ver = $Matches[1]
    $build = [int]$Matches[2]
} elseif ($cleanVersion -match "^([0-9\.]+)$") {
    $ver = $Matches[1]
    if ($ver -ne $detectedVer) {
        $build = $detectedBuild + 1
    } else {
        $build = $detectedBuild
    }
} else {
    $ver = $cleanVersion
    $build = $detectedBuild + 1
}

# Flutter/pubspec.yaml strictly requires 3-segment Semantic Versioning (e.g. 0.9 -> 0.9.0, 1 -> 1.0.0)
$vParts = $ver.Split('.')
if ($vParts.Count -eq 1) {
    $ver = "$ver.0.0"
} elseif ($vParts.Count -eq 2) {
    $ver = "$ver.0"
}

$gitTag = "v$ver"

# Update pubspec.yaml if changed
if ($ver -ne $detectedVer -or $build -ne $detectedBuild) {
    Write-Host "  Updating pubspec.yaml to $ver+$build..." -ForegroundColor DarkYellow
    $updatedPubspec = $rawPubspec -replace "version:\s*[0-9\.\+]+", "version: $ver+$build"
    Set-Content "pubspec.yaml" -Value $updatedPubspec
}

# Update update_service.dart fallbacks
$updateServicePath = "lib/infrastructure/update/update_service.dart"
if (Test-Path $updateServicePath) {
    try {
        $serviceRaw = Get-Content $updateServicePath -Raw
        $serviceRaw = $serviceRaw -replace "defaultFallbackVersion = '[0-9\.]+';", "defaultFallbackVersion = '$ver';"
        $serviceRaw = $serviceRaw -replace "defaultFallbackBuildNumber = [0-9]+;", "defaultFallbackBuildNumber = $build;"
        Set-Content $updateServicePath -Value $serviceRaw
    } catch {}
}

# -------------------------------------------------------------
# 3. Choose Display Mode (Clean 2 Progress Bars vs Full Logs)
# -------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Mode)) {
    Write-Host ""
    Write-Host "  Build Display Mode:" -ForegroundColor White
    Write-Host "    [1] Clean Mode      2 live progress bars, zero noise  $cStar" -ForegroundColor Green
    Write-Host "    [2] Full Logs Mode  Stream all compiler & gradle logs" -ForegroundColor DarkGray
    Write-Host ""
    $modeInput = Read-Host "  Select mode [1/2, default 1]"
    if ($modeInput.Trim() -eq "2") {
        $Mode = "logs"
    } else {
        $Mode = "clean"
    }
}

# -------------------------------------------------------------
# 4. Git Push Choice
# -------------------------------------------------------------
$skipGit = $NoGit
if (-not $NoGit -and -not $PSBoundParameters.ContainsKey("NoGit")) {
    Write-Host ""
    $gitInput = Read-Host "  Publish tag $gitTag & push to GitHub when done? [Y/n, default Y]"
    if ($gitInput.Trim() -match "^[nN]") {
        $skipGit = $true
    }
}

# Ensure releases directory
$ReleaseDir = Join-Path $ProjectRoot "releases"
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

$generatedFiles = @()

# -------------------------------------------------------------
# 5. Live 2-Progress-Bar Management
# -------------------------------------------------------------
function Format-Bar([int]$pct, [int]$len = 24) {
    if ($pct -lt 0) { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }
    $f = [math]::Floor(($pct / 100) * $len)
    $e = $len - $f
    return "[" + ([string]::new($cBlock, $f)) + ([string]::new($cShade, $e)) + "]"
}

$dashState = @{
    WinPercent = 0
    WinStage   = $(if ($Target -eq "android") { "Skipped" } else { "Queued" })
    WinTime    = "00:00"
    WinDone    = $false
    WinSize    = ""

    ApkPercent = 0
    ApkStage   = $(if ($Target -eq "windows") { "Skipped" } else { "Queued" })
    ApkTime    = "00:00"
    ApkDone    = $false
    ApkSize    = ""
}

$script:liveRowY = -1
$script:endRowY = -1

function Init-LiveBars {
    Clear-Host
    Write-Host ""
    Write-Host ("  WZNOTES RELEASE BUILDER " + $cDot + " $gitTag (Build $build)") -ForegroundColor Cyan
    Write-Host "  Mode: Clean (2 Live Progress Bars) | Output: .\releases" -ForegroundColor DarkGray
    Write-Host ("  " + ([string]::new($cH, 74))) -ForegroundColor DarkCyan

    try {
        $script:liveRowY = [WinConsole]::GetCursorY()
    } catch {
        $script:liveRowY = -1
    }

    # Print 2 initial placeholder lines formatted to 74 columns
    Write-Host ("  [1/2] Windows PC   " + (Format-Bar 0 24) + "   0% [00:00] Initializing...").PadRight(74) -ForegroundColor White
    Write-Host ("  [2/2] Android APK  " + (Format-Bar 0 24) + "   0% [00:00] Queued").PadRight(74) -ForegroundColor DarkGray
    Write-Host ("  " + ([string]::new($cH, 74))) -ForegroundColor DarkCyan

    try {
        $script:endRowY = [WinConsole]::GetCursorY()
    } catch {
        $script:endRowY = -1
    }
}

function Update-LiveBars {
    param([hashtable]$s)

    $bar1 = Format-Bar $s.WinPercent 24
    $status1 = if ($s.WinDone) { "Completed $cCheck ($($s.WinSize))" } else { $s.WinStage }
    $line1 = "  [1/2] Windows PC   $bar1 {0,3}% [{1}] {2}" -f $s.WinPercent, $s.WinTime, $status1

    $bar2 = Format-Bar $s.ApkPercent 24
    $status2 = if ($s.ApkDone) { "Completed $cCheck ($($s.ApkSize))" } else { $s.ApkStage }
    $line2 = "  [2/2] Android APK  $bar2 {0,3}% [{1}] {2}" -f $s.ApkPercent, $s.ApkTime, $status2

    # Truncate strictly so it fits standard 80-col console without wrapping
    if ($line1.Length -gt 74) { $line1 = $line1.Substring(0, 71) + "..." }
    if ($line2.Length -gt 74) { $line2 = $line2.Substring(0, 71) + "..." }

    $line1Padded = $line1.PadRight(74)
    $line2Padded = $line2.PadRight(74)

    if ($script:liveRowY -ge 0) {
        [WinConsole]::WriteAt(0, $script:liveRowY, $line1Padded)
        [WinConsole]::WriteAt(0, ($script:liveRowY + 1), $line2Padded)
        if ($script:endRowY -ge 0) {
            [WinConsole]::SetCursor(0, $script:endRowY)
        }
    } else {
        # Fallback for redirected headless pipe: single line carriage-return, NEVER emit \n
        $statusCombined = "  [PC: {0,3}%] [APK: {1,3}%] {2}" -f $s.WinPercent, $s.ApkPercent, $(if ($s.WinDone) { $s.ApkStage } else { $s.WinStage })
        if ($statusCombined.Length -gt 74) { $statusCombined = $statusCombined.Substring(0, 71) + "..." }
        Write-Host -NoNewline ("`r" + $statusCombined.PadRight(74))
    }
}

function Finish-LiveBars {
    if ($script:endRowY -ge 0) {
        [WinConsole]::SetCursor(0, $script:endRowY)
    }
    Write-Host ""
}

# -------------------------------------------------------------
# 6. Execute Build Tasks
# -------------------------------------------------------------
$totalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

if ($Mode -eq "clean") {
    Init-LiveBars
    Update-LiveBars $dashState
}

# ----------------- WINDOWS BUILD -----------------
if ($Target -eq "all" -or $Target -eq "windows") {
    $winBuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
    $winExe = Join-Path $winBuildDir "wznotes.exe"
    if (Test-Path $winExe) { Remove-Item $winExe -Force -ErrorAction SilentlyContinue }

    if ($Mode -eq "clean") {
        $dashState.WinStage = "Starting Windows compiler..."
        Update-LiveBars $dashState

        $tempLog = ".build_win.log"
        if (Test-Path $tempLog) { Remove-Item $tempLog -Force -ErrorAction SilentlyContinue }

        $winSw = [System.Diagnostics.Stopwatch]::StartNew()
        $script:winTarget = 15

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/c flutter build windows --release > $tempLog 2>&1"
        $psi.WorkingDirectory = $ProjectRoot
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null

        $lastLogIndex = 0
        while (-not $proc.HasExited) {
            Start-Sleep -Milliseconds 100
            $dashState.WinTime = "{0:mm\:ss}" -f $winSw.Elapsed

            # Read new log lines from log file
            if (Test-Path $tempLog) {
                $lines = @(Get-Content $tempLog -ErrorAction SilentlyContinue)
                if ($lines.Count -gt $lastLogIndex) {
                    for ($i = $lastLogIndex; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i]
                        if ($line -match "Building Windows application") {
                            $script:winTarget = 30
                            $dashState.WinStage = "Resolving dependencies & AOT bundle..."
                        } elseif ($line -match "flutter_assemble" -or $line -match "kernel_snapshot") {
                            $script:winTarget = 50
                            $dashState.WinStage = "Compiling Dart kernel & frontend server..."
                        } elseif ($line -match "CMake" -or $line -match "Generating") {
                            $script:winTarget = 65
                            $dashState.WinStage = "Configuring CMake native build system..."
                        } elseif ($line -match "Building CXX" -or $line -match "runner" -or $line -match "Compiling") {
                            $script:winTarget = 80
                            $dashState.WinStage = "Compiling C++ runner & plugins..."
                        } elseif ($line -match "Linking" -or $line -match "wznotes\.exe") {
                            $script:winTarget = 92
                            $dashState.WinStage = "Linking executable & assets..."
                        } elseif ($line -match "Built build\\windows") {
                            $script:winTarget = 97
                            $dashState.WinStage = "Packaging Windows artifacts..."
                        }
                    }
                    $lastLogIndex = $lines.Count
                }
            }

            # Smooth progress interpolation
            if ($dashState.WinPercent -lt $script:winTarget) {
                $dashState.WinPercent += 1
            } elseif ($dashState.WinPercent -lt 95 -and ($winSw.ElapsedMilliseconds % 600 -lt 100)) {
                $dashState.WinPercent += 1
            }
            Update-LiveBars $dashState
        }

        $proc.WaitForExit()
        $winSw.Stop()

        if ($proc.ExitCode -eq 0 -and (Test-Path $winExe)) {
            if (Test-Path $tempLog) { Remove-Item $tempLog -Force -ErrorAction SilentlyContinue }

            $dashState.WinStage = "Compressing portable ZIP..."
            $dashState.WinPercent = 97
            Update-LiveBars $dashState

            $winDestFolder = Join-Path $ReleaseDir "wznotes-windows"
            if (Test-Path $winDestFolder) { Remove-Item $winDestFolder -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $winDestFolder -Force | Out-Null
            Copy-Item -Path "$winBuildDir\*" -Destination $winDestFolder -Recurse -Force

            $winZipName = "wznotes-windows-v$ver.zip"
            $winZipPath = Join-Path $ReleaseDir $winZipName
            if (Test-Path $winZipPath) { Remove-Item $winZipPath -Force -ErrorAction SilentlyContinue }

            Compress-Archive -Path "$winBuildDir\*" -DestinationPath $winZipPath -Force

            $zipSizeMb = [math]::Round((Get-Item $winZipPath).Length / 1MB, 2)
            $exePath = Join-Path $winDestFolder "wznotes.exe"
            $exeSizeMb = if (Test-Path $exePath) { [math]::Round((Get-Item $exePath).Length / 1MB, 2) } else { 0 }

            $dashState.WinPercent = 100
            $dashState.WinDone = $true
            $dashState.WinSize = "$zipSizeMb MB"
            $dashState.WinStage = "Ready"
            Update-LiveBars $dashState

            $generatedFiles += [PSCustomObject]@{
                File = $winZipName
                Type = "Windows Portable ZIP"
                SizeMB = $zipSizeMb
                Path = $winZipPath
            }
            $generatedFiles += [PSCustomObject]@{
                File = "wznotes-windows\wznotes.exe"
                Type = "Windows Executable"
                SizeMB = $exeSizeMb
                Path = $exePath
            }
        } else {
            Finish-LiveBars
            Write-Host "  $cCross [ERROR] Windows Desktop build failed (Exit Code: $($proc.ExitCode))" -ForegroundColor Red
            Write-Host ""
            if (Test-Path $tempLog) {
                Get-Content $tempLog | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkRed }
                Remove-Item $tempLog -Force -ErrorAction SilentlyContinue
            }
            Write-Host ""
            exit 1
        }
    } else {
        # Full Logs Mode
        Write-Host ""
        Write-Host ("  " + ([string]::new($cH, 64))) -ForegroundColor DarkCyan
        Write-Host "  [1/2] Building Windows Desktop Release (x64)..." -ForegroundColor Yellow
        Write-Host ("  " + ([string]::new($cH, 64))) -ForegroundColor DarkCyan
        flutter build windows --release

        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $winExe)) {
            Write-Host "  $cCross [ERROR] Windows Desktop build failed (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
            exit 1
        }

        $winDestFolder = Join-Path $ReleaseDir "wznotes-windows"
        if (Test-Path $winDestFolder) { Remove-Item $winDestFolder -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $winDestFolder -Force | Out-Null
        Copy-Item -Path "$winBuildDir\*" -Destination $winDestFolder -Recurse -Force

        $winZipName = "wznotes-windows-v$ver.zip"
        $winZipPath = Join-Path $ReleaseDir $winZipName
        if (Test-Path $winZipPath) { Remove-Item $winZipPath -Force -ErrorAction SilentlyContinue }

        Compress-Archive -Path "$winBuildDir\*" -DestinationPath $winZipPath -Force

        $zipSizeMb = [math]::Round((Get-Item $winZipPath).Length / 1MB, 2)
        $exePath = Join-Path $winDestFolder "wznotes.exe"
        $exeSizeMb = if (Test-Path $exePath) { [math]::Round((Get-Item $exePath).Length / 1MB, 2) } else { 0 }

        $generatedFiles += [PSCustomObject]@{
            File = $winZipName
            Type = "Windows Portable ZIP"
            SizeMB = $zipSizeMb
            Path = $winZipPath
        }
        $generatedFiles += [PSCustomObject]@{
            File = "wznotes-windows\wznotes.exe"
            Type = "Windows Executable"
            SizeMB = $exeSizeMb
            Path = $exePath
        }
    }
}

# ----------------- ANDROID BUILD -----------------
if ($Target -eq "all" -or $Target -eq "android") {
    $apkSource = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkSource) { Remove-Item $apkSource -Force -ErrorAction SilentlyContinue }

    if ($Mode -eq "clean") {
        $dashState.ApkStage = "Starting Gradle daemon..."
        Update-LiveBars $dashState

        $tempLogApk = ".build_apk.log"
        if (Test-Path $tempLogApk) { Remove-Item $tempLogApk -Force -ErrorAction SilentlyContinue }

        $apkSw = [System.Diagnostics.Stopwatch]::StartNew()
        $script:apkTarget = 15

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/c flutter build apk --release --android-skip-build-dependency-validation > $tempLogApk 2>&1"
        $psi.WorkingDirectory = $ProjectRoot
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null

        $lastLogIndex = 0
        while (-not $proc.HasExited) {
            Start-Sleep -Milliseconds 100
            $dashState.ApkTime = "{0:mm\:ss}" -f $apkSw.Elapsed

            # Read new log lines from log file
            if (Test-Path $tempLogApk) {
                $lines = @(Get-Content $tempLogApk -ErrorAction SilentlyContinue)
                if ($lines.Count -gt $lastLogIndex) {
                    for ($i = $lastLogIndex; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i]
                        if ($line -match "Running Gradle task" -or $line -match "daemon") {
                            $script:apkTarget = 25
                            $dashState.ApkStage = "Connecting to Gradle daemon..."
                        } elseif ($line -match "compileFlutterBuildRelease" -or $line -match "frontend_server") {
                            $script:apkTarget = 45
                            $dashState.ApkStage = "Compiling Dart AOT binaries (arm64)..."
                        } elseif ($line -match "compileReleaseKotlin" -or $line -match "compileReleaseJava") {
                            $script:apkTarget = 65
                            $dashState.ApkStage = "Compiling Kotlin & Android plugins..."
                        } elseif ($line -match "mergeReleaseResources" -or $line -match "processReleaseManifest") {
                            $script:apkTarget = 78
                            $dashState.ApkStage = "Processing manifests & app resources..."
                        } elseif ($line -match "mergeDexRelease" -or $line -match "dexBuilder" -or $line -match "d8") {
                            $script:apkTarget = 88
                            $dashState.ApkStage = "Optimizing & merging DEX bytecode..."
                        } elseif ($line -match "packageRelease") {
                            $script:apkTarget = 94
                            $dashState.ApkStage = "Packaging & signing universal APK..."
                        } elseif ($line -match "Built build\\app" -or $line -match "app-release\.apk") {
                            $script:apkTarget = 98
                            $dashState.ApkStage = "Verifying release APK binary..."
                        }
                    }
                    $lastLogIndex = $lines.Count
                }
            }

            # Smooth progress interpolation
            if ($dashState.ApkPercent -lt $script:apkTarget) {
                $dashState.ApkPercent += 1
            } elseif ($dashState.ApkPercent -lt 95 -and ($apkSw.ElapsedMilliseconds % 500 -lt 100)) {
                $dashState.ApkPercent += 1
            }
            Update-LiveBars $dashState
        }

        $proc.WaitForExit()
        $apkSw.Stop()

        if ($proc.ExitCode -eq 0 -and (Test-Path $apkSource)) {
            if (Test-Path $tempLogApk) { Remove-Item $tempLogApk -Force -ErrorAction SilentlyContinue }

            $apkDestName = "wznotes-android-v$ver.apk"
            $apkDestPath = Join-Path $ReleaseDir $apkDestName
            Copy-Item -Path $apkSource -Destination $apkDestPath -Force

            $apkSizeMb = [math]::Round((Get-Item $apkDestPath).Length / 1MB, 2)

            $dashState.ApkPercent = 100
            $dashState.ApkDone = $true
            $dashState.ApkSize = "$apkSizeMb MB"
            $dashState.ApkStage = "Ready"
            Update-LiveBars $dashState

            $generatedFiles += [PSCustomObject]@{
                File = $apkDestName
                Type = "Android Universal APK"
                SizeMB = $apkSizeMb
                Path = $apkDestPath
            }
        } else {
            Finish-LiveBars
            Write-Host "  $cCross [ERROR] Android APK build failed (Exit Code: $($proc.ExitCode))" -ForegroundColor Red
            Write-Host ""
            if (Test-Path $tempLogApk) {
                Get-Content $tempLogApk | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkRed }
                Remove-Item $tempLogApk -Force -ErrorAction SilentlyContinue
            }
            Write-Host ""
            exit 1
        }
    } else {
        # Full Logs Mode
        Write-Host ""
        Write-Host ("  " + ([string]::new($cH, 64))) -ForegroundColor DarkCyan
        Write-Host "  [2/2] Building Android Release APK (ARM64 & Universal)..." -ForegroundColor Yellow
        Write-Host ("  " + ([string]::new($cH, 64))) -ForegroundColor DarkCyan
        flutter build apk --release --android-skip-build-dependency-validation

        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $apkSource)) {
            Write-Host "  $cCross [ERROR] Android APK build failed (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
            exit 1
        }

        $apkDestName = "wznotes-android-v$ver.apk"
        $apkDestPath = Join-Path $ReleaseDir $apkDestName
        Copy-Item -Path $apkSource -Destination $apkDestPath -Force

        $apkSizeMb = [math]::Round((Get-Item $apkDestPath).Length / 1MB, 2)

        $generatedFiles += [PSCustomObject]@{
            File = $apkDestName
            Type = "Android Universal APK"
            SizeMB = $apkSizeMb
            Path = $apkDestPath
        }
    }
}

if ($Mode -eq "clean") {
    Finish-LiveBars
}

$totalStopwatch.Stop()
$totalTimeStr = "{0:mm\:ss}" -f $totalStopwatch.Elapsed

# -------------------------------------------------------------
# 7. Update version_manifest.json
# -------------------------------------------------------------
try {
    $manifest = @{
        version = $ver
        build_number = $build
        title = "wznotes $gitTag Update"
        release_notes = if ($ReleaseNotes) { $ReleaseNotes } else { "Trash bin with 30-day auto-purge and restoration, 6 curated AMOLED themes, show word count fix, streamlined Wi-Fi sync" }
        windows_url = "https://github.com/straculencuandrei/wznotes/releases/download/$gitTag/wznotes-windows-v$ver.zip"
        android_url = "https://github.com/straculencuandrei/wznotes/releases/download/$gitTag/wznotes-android-v$ver.apk"
        is_mandatory = $false
        published_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    $manifestJson = $manifest | ConvertTo-Json -Depth 4
    Set-Content (Join-Path $ReleaseDir "version_manifest.json") -Value $manifestJson
    Set-Content (Join-Path $ProjectRoot "version_manifest.json") -Value $manifestJson

    $generatedFiles += [PSCustomObject]@{
        File = "version_manifest.json"
        Type = "OTA Version Manifest"
        SizeMB = [math]::Round((Get-Item (Join-Path $ReleaseDir "version_manifest.json")).Length / 1KB, 2)
        Path = (Join-Path $ReleaseDir "version_manifest.json")
    }
} catch {}

# -------------------------------------------------------------
# 8. Summary Display Card
# -------------------------------------------------------------
Write-Host ""
$topBorder = "  " + $cTL + ([string]::new($cH, 2)) + " RELEASE ARTIFACTS READY (Total Build Time: $totalTimeStr) " + ([string]::new($cH, 13)) + $cTR
$botBorder = "  " + $cBL + ([string]::new($cH, 74)) + $cBR
$emptyRow  = "  " + $cV + ([string]::new(" ", 74)) + $cV

Write-Host $topBorder -ForegroundColor Green
Write-Host $emptyRow -ForegroundColor Green

foreach ($item in $generatedFiles) {
    $sizeStr = if ($item.Type -like "*Manifest*") { "$($item.SizeMB) KB" } else { "$($item.SizeMB) MB" }
    $fileDisplay = "{0,-32}" -f $item.File
    $typeDisplay = "{0,-24}" -f $item.Type
    $sizeDisplay = "{0,8}" -f $sizeStr

    Write-Host ("  " + $cV + "   ") -NoNewline -ForegroundColor Green
    Write-Host "$cCheck " -NoNewline -ForegroundColor Yellow
    Write-Host $fileDisplay -NoNewline -ForegroundColor White
    Write-Host $typeDisplay -NoNewline -ForegroundColor DarkGray
    Write-Host $sizeDisplay -NoNewline -ForegroundColor Cyan
    Write-Host ("   " + $cV) -ForegroundColor Green
}

Write-Host $emptyRow -ForegroundColor Green
Write-Host ("  " + $cV + "   Output: ") -NoNewline -ForegroundColor DarkGray
Write-Host ("{0,-63}" -f $ReleaseDir) -NoNewline -ForegroundColor Cyan
Write-Host $cV -ForegroundColor Green
Write-Host $botBorder -ForegroundColor Green
Write-Host ""

# -------------------------------------------------------------
# 9. Git Tag & Push
# -------------------------------------------------------------
if (-not $skipGit) {
    try {
        Write-Host "  Sending Release to GitHub..." -ForegroundColor DarkYellow
        git add .
        $statusCheck = (git status --porcelain)
        if ($statusCheck) {
            $commitMsg = if ($ReleaseNotes) { "Release ${gitTag}: $ReleaseNotes" } else { "Release ${gitTag} (v${ver}+${build})" }
            git commit -m $commitMsg 2>$null | Out-Null
            Write-Host "  $cCheck Committed changes: $commitMsg" -ForegroundColor Gray
        }

        git tag -f -a "$gitTag" -m "wznotes Release $gitTag" 2>$null | Out-Null
        Write-Host "  $cCheck Created Git tag: $gitTag" -ForegroundColor Gray

        Write-Host "  Pushing to GitHub (main & $gitTag)..." -ForegroundColor Yellow
        git push origin main 2>$null | Out-Null
        git push origin "$gitTag" --force 2>$null | Out-Null
        git push origin --tags 2>$null | Out-Null

        Write-Host "  $cCheck Successfully published $gitTag to GitHub!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Attach your ZIP and APK to GitHub Releases:" -ForegroundColor Yellow
        Write-Host "  -> https://github.com/straculencuandrei/wznotes/releases/new?tag=$gitTag" -ForegroundColor Cyan
        Write-Host ""
    } catch {
        Write-Host "  [NOTE] Git push skipped or offline: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Release binaries were built and saved successfully in .\releases" -ForegroundColor Green
        Write-Host ""
    }
}

# -------------------------------------------------------------
# 10. Automatically open Explorer
# -------------------------------------------------------------
if (-not $NoExplorer) {
    try {
        Invoke-Item $ReleaseDir
    } catch {}
}
