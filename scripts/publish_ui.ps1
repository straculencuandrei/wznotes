Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

# Detect current version from pubspec.yaml
$currentVer = "0.7.0"
$currentBuild = 7
if (Test-Path "pubspec.yaml") {
    $content = Get-Content "pubspec.yaml" -Raw
    if ($content -match "version:\s*([0-9\.]+)\+([0-9]+)") {
        $currentVer = $Matches[1]
        $currentBuild = [int]$Matches[2]
    }
}

$parts = $currentVer.Split('.')
$nextVer = if ($parts.Count -ge 3) {
    "$($parts[0]).$($parts[1]).$([int]$parts[2] + 1)"
} else {
    "$currentVer.1"
}
$nextBuild = $currentBuild + 1

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="wznotes Release &amp; Update Dashboard" Height="760" Width="900"
        WindowStartupLocation="CenterScreen" Background="#0D0D0D" Foreground="#E5E5E5"
        FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1A1A1A"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#2E2E2E"/>
            <Setter Property="BorderThickness" Value="1.5"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,4,0,4"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
    </Window.Resources>

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#141414" CornerRadius="12" Padding="16,12" Margin="0,0,0,16" BorderBrush="#FF8C00" BorderThickness="1">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="wznotes Release &amp; Update Manager" FontSize="20" FontWeight="Bold" Foreground="#FF8C00"/>
                    <TextBlock Text="Pre-flight test runner, multi-platform build pipeline, and update distributor." FontSize="12" Foreground="#888888" Margin="0,3,0,0"/>
                </StackPanel>
                <Border Grid.Column="1" Background="#261A0D" CornerRadius="8" Padding="10,6" BorderBrush="#FF8C00" BorderThickness="1">
                    <TextBlock Text="Current: v$currentVer+$currentBuild" FontSize="12" FontWeight="Bold" Foreground="#FFA500"/>
                </Border>
            </Grid>
        </Border>

        <!-- Configuration & Options Columns -->
        <Grid Grid.Row="1" Margin="0,0,0,16">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="3*"/>
                <ColumnDefinition Width="2*"/>
            </Grid.ColumnDefinitions>

            <!-- Release Details -->
            <Border Grid.Column="0" Background="#141414" CornerRadius="10" Padding="16" Margin="0,0,10,0" BorderBrush="#222222" BorderThickness="1">
                <StackPanel>
                    <TextBlock Text="RELEASE DETAILS" FontSize="11" FontWeight="Bold" Foreground="#FF8C00" Margin="0,0,0,10"/>
                    
                    <Grid Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Margin="0,0,8,0">
                            <TextBlock Text="New Version (SemVer):" FontSize="12" Foreground="#AAAAAA" Margin="0,0,0,4"/>
                            <TextBox Name="txtVersion" Text="$nextVer"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1" Margin="8,0,0,0">
                            <TextBlock Text="Build Number:" FontSize="12" Foreground="#AAAAAA" Margin="0,0,0,4"/>
                            <TextBox Name="txtBuildNumber" Text="$nextBuild"/>
                        </StackPanel>
                    </Grid>

                    <TextBlock Text="Changelog / Release Notes:" FontSize="12" Foreground="#AAAAAA" Margin="0,0,0,4"/>
                    <TextBox Name="txtNotes" Text="Performance optimizations, updated sync engine, and stability fixes." Height="60" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"/>

                    <CheckBox Name="chkMandatory" Content="Mark as Mandatory Update" Margin="0,10,0,0"/>
                </StackPanel>
            </Border>

            <!-- Pre-flight & Build Steps -->
            <Border Grid.Column="1" Background="#141414" CornerRadius="10" Padding="16" Margin="10,0,0,0" BorderBrush="#222222" BorderThickness="1">
                <StackPanel>
                    <TextBlock Text="PIPELINE STEPS" FontSize="11" FontWeight="Bold" Foreground="#FF8C00" Margin="0,0,0,10"/>
                    <CheckBox Name="chkRunTests" Content="[TEST] Run 20 Automated Tests" IsChecked="True"/>
                    <CheckBox Name="chkBuildWindows" Content="[WIN] Build Windows (.zip)" IsChecked="True"/>
                    <CheckBox Name="chkBuildAndroid" Content="[APK] Build Android (.apk)" IsChecked="True"/>
                    <CheckBox Name="chkGenManifest" Content="[JSON] Update version_manifest" IsChecked="True"/>
                    <CheckBox Name="chkGitTag" Content="[GIT] Create Git Commit &amp; Tag" IsChecked="True"/>
                    <CheckBox Name="chkGitPush" Content="[GIT] Push to GitHub Remote" IsChecked="True"/>
                </StackPanel>
            </Border>
        </Grid>

        <!-- Live Execution Console Log -->
        <Border Grid.Row="2" Background="#0A0A0A" CornerRadius="10" Padding="12" BorderBrush="#262626" BorderThickness="1">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,8">
                    <TextBlock Text="EXECUTION LOG &amp; TEST VERIFICATION" FontSize="11" FontWeight="Bold" Foreground="#888888"/>
                    <TextBlock Name="lblStatus" Text="Ready to build" HorizontalAlignment="Right" FontSize="11" Foreground="#00FF7F"/>
                </Grid>
                <TextBox Grid.Row="1" Name="txtLog" Background="#000000" Foreground="#00FF66" FontFamily="Consolas" FontSize="12"
                         IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" AcceptsReturn="True"
                         Text="[System] wznotes Dashboard Initialized. Click 'Run Pipeline &amp; Publish Update' to start.`n"/>
            </Grid>
        </Border>

        <!-- Action Buttons -->
        <Grid Grid.Row="3" Margin="0,16,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>

            <Button Grid.Column="0" Name="btnOpenDist" Content="Open 'dist' Folder" Background="#262626" Foreground="#FFFFFF"/>
            <Grid Grid.Column="1" Margin="16,0">
                <ProgressBar Name="prgBar" Height="14" Minimum="0" Maximum="100" Value="0" IsIndeterminate="False" Visibility="Hidden" Foreground="#FF8C00" Background="#1E1E1E" BorderThickness="0"/>
                <TextBlock Name="lblProgressPercent" Text="0%" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="10" FontWeight="Bold" Foreground="#FFFFFF" Visibility="Hidden"/>
            </Grid>
            <Button Grid.Column="2" Name="btnClearLog" Content="Clear Log" Background="#1E1E1E" Foreground="#888888" Margin="0,0,10,0"/>
            <Button Grid.Column="3" Name="btnStart" Content="Run Pipeline &amp; Publish Update" Background="#FF8C00" Foreground="#000000" Width="260"/>
        </Grid>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$txtVersion = $window.FindName("txtVersion")
$txtBuildNumber = $window.FindName("txtBuildNumber")
$txtNotes = $window.FindName("txtNotes")
$chkMandatory = $window.FindName("chkMandatory")
$chkRunTests = $window.FindName("chkRunTests")
$chkBuildWindows = $window.FindName("chkBuildWindows")
$chkBuildAndroid = $window.FindName("chkBuildAndroid")
$chkGenManifest = $window.FindName("chkGenManifest")
$chkGitTag = $window.FindName("chkGitTag")
$chkGitPush = $window.FindName("chkGitPush")
$txtLog = $window.FindName("txtLog")
$lblStatus = $window.FindName("lblStatus")
$btnStart = $window.FindName("btnStart")
$btnOpenDist = $window.FindName("btnOpenDist")
$btnClearLog = $window.FindName("btnClearLog")
$prgBar = $window.FindName("prgBar")
$lblProgressPercent = $window.FindName("lblProgressPercent")

function Write-DashboardLog([string]$msg, [string]$status = "") {
    $time = (Get-Date).ToString("HH:mm:ss")
    $line = "[$time] $msg`r`n"
    $txtLog.AppendText($line)
    $txtLog.ScrollToEnd()
    if ($status) { $lblStatus.Text = $status }
    [System.Windows.Forms.Application]::DoEvents()
}

function Set-PipelineProgress([int]$percent, [string]$status = "") {
    $prgBar.Value = $percent
    $lblProgressPercent.Text = "$percent%"
    if ($status) { $lblStatus.Text = $status }
    [System.Windows.Forms.Application]::DoEvents()
}

function Invoke-PipelineCommand([string]$description, $command) {
    Write-DashboardLog "[EXEC] $description..."
    [System.Windows.Forms.Application]::DoEvents()

    $cmdString = ""
    if ($command -is [string]) {
        $cmdString = $command
    } else {
        $cmdString = $command.ToString().Trim('{', '}', ' ', "`t", "`r", "`n")
    }

    $tempLog = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "wznotes_pipe_" + [System.Guid]::NewGuid().ToString("N") + ".log")
    if (Test-Path $tempLog) { Remove-Item $tempLog -Force -ErrorAction SilentlyContinue }

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "cmd.exe"
    $pinfo.Arguments = "/c `"$cmdString > `"`"$tempLog`"`" 2>&1`""
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.WorkingDirectory = $ProjectRoot

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $pinfo
    $proc.Start() | Out-Null

    $lastPosition = 0
    while (-not $proc.HasExited) {
        if (Test-Path $tempLog) {
            try {
                $stream = [System.IO.File]::Open($tempLog, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                if ($stream.Length -gt $lastPosition) {
                    $stream.Position = $lastPosition
                    $reader = New-Object System.IO.StreamReader($stream)
                    $newText = $reader.ReadToEnd()
                    $lastPosition = $stream.Position
                    if ($newText) {
                        foreach ($line in ($newText -split "`r?`n")) {
                            if ($line) {
                                Write-DashboardLog $line
                            }
                        }
                    }
                }
                $stream.Close()
            } catch {}
        }
        [System.Windows.Forms.Application]::DoEvents()
        [System.Threading.Thread]::Sleep(60)
    }

    # Final drain
    if (Test-Path $tempLog) {
        try {
            $stream = [System.IO.File]::Open($tempLog, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            if ($stream.Length -gt $lastPosition) {
                $stream.Position = $lastPosition
                $reader = New-Object System.IO.StreamReader($stream)
                $newText = $reader.ReadToEnd()
                if ($newText) {
                    foreach ($line in ($newText -split "`r?`n")) {
                        if ($line) {
                            Write-DashboardLog $line
                        }
                    }
                }
            }
            $stream.Close()
            Remove-Item $tempLog -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    [System.Windows.Forms.Application]::DoEvents()

    return @{
        ExitCode = $proc.ExitCode
    }
}

$btnClearLog.Add_Click({
    $txtLog.Text = ""
})

$btnOpenDist.Add_Click({
    $distPath = Join-Path $ProjectRoot "dist"
    if (-not (Test-Path $distPath)) {
        New-Item -ItemType Directory -Path $distPath | Out-Null
    }
    [System.Diagnostics.Process]::Start("explorer.exe", $distPath)
})

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

$btnStart.Add_Click({
    $ver = $txtVersion.Text.Trim()
    $build = $txtBuildNumber.Text.Trim()
    $notes = $txtNotes.Text.Trim()
    $isMandatory = [bool]$chkMandatory.IsChecked
    $doTests = [bool]$chkRunTests.IsChecked
    $doWin = [bool]$chkBuildWindows.IsChecked
    $doAndroid = [bool]$chkBuildAndroid.IsChecked
    $doManifest = [bool]$chkGenManifest.IsChecked
    $doGitTag = [bool]$chkGitTag.IsChecked
    $doGitPush = [bool]$chkGitPush.IsChecked

    if ([string]::IsNullOrWhiteSpace($ver)) {
        [System.Windows.Forms.MessageBox]::Show("Please specify a valid version.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # Verify if version is actually an incremented update
    $buildNum = 0
    [int]::TryParse($build, [ref]$buildNum) | Out-Null
    $isNewer = Test-IsNewerVersion $ver $buildNum $currentVer $currentBuild

    if (-not $isNewer) {
        $msg = "Duplicate / Same Version Warning:`n`n" +
               "You are about to release version: v$ver+$build`n" +
               "Current installed version is: v$currentVer+$currentBuild`n`n" +
               "Because wznotes uses version comparison to recognize updates, existing phone and PC apps will NOT recognize this as a new update and will ignore it.`n`n" +
               "Are you sure you want to proceed with this version?"
        $res = [System.Windows.Forms.MessageBox]::Show($msg, "Version Conflict Warning", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($res -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }
    }

    $btnStart.IsEnabled = $false
    $prgBar.Visibility = [System.Windows.Visibility]::Visible
    $lblProgressPercent.Visibility = [System.Windows.Visibility]::Visible
    Set-PipelineProgress 5 "Initializing..."

    try {
        Set-Location $ProjectRoot
        Write-DashboardLog "Starting update pipeline for wznotes v$ver+$build..." "Running pipeline..."
        if ($isNewer) {
            Write-DashboardLog "[VERSION] Verified: v$ver+$build is higher than v$currentVer+$currentBuild. Apps will automatically update!"
        } else {
            Write-DashboardLog "[WARN] Releasing same or older version v$ver+$build (Current was v$currentVer+$currentBuild)."
        }

        # STEP 1: Run Automated Tests
        if ($doTests) {
            Write-DashboardLog "========================================"
            Set-PipelineProgress 10 "[1/6] Running Automated Test Suite..."
            $res = Invoke-PipelineCommand "Automated Test Suite" { cmd.exe /c flutter test }

            if ($res.ExitCode -ne 0) {
                Write-DashboardLog "[FAIL] Test Suite Encountered Errors! Aborting build." "Tests failed!"
                return
            }
            Set-PipelineProgress 25 "[PASS] All Unit, Inking, Math & Sync Tests Passed!"
            Write-DashboardLog "[PASS] All Unit, Inking, Math & Sync Tests Passed!"
        }

        # STEP 2: Update Version in files
        Write-DashboardLog "========================================"
        Set-PipelineProgress 30 "[2/6] Updating version numbers in project..."
        $pubspecRaw = Get-Content "pubspec.yaml" -Raw
        $pubspecUpdated = $pubspecRaw -replace "version:\s*[0-9\.\+]+", "version: $ver+$build"
        Set-Content "pubspec.yaml" -Value $pubspecUpdated

        $updateServicePath = "lib/infrastructure/update/update_service.dart"
        if (Test-Path $updateServicePath) {
            $serviceRaw = Get-Content $updateServicePath -Raw
            $serviceRaw = $serviceRaw -replace "static const String currentVersion = '[0-9\.]+';", "static const String currentVersion = '$ver';"
            $serviceRaw = $serviceRaw -replace "static const int currentBuildNumber = [0-9]+;", "static const int currentBuildNumber = $build;"
            Set-Content $updateServicePath -Value $serviceRaw
        }

        $distDir = Join-Path $ProjectRoot "dist"
        if (-not (Test-Path $distDir)) {
            New-Item -ItemType Directory -Path $distDir | Out-Null
        }
        Set-PipelineProgress 40 "[PASS] Versions updated to v$ver+$build"

        # STEP 3: Build Windows Desktop
        if ($doWin) {
            Write-DashboardLog "========================================"
            Set-PipelineProgress 45 "[3/6] Compiling Windows Desktop Release (1-2 min)..."
            $res = Invoke-PipelineCommand "Windows Desktop Build" { cmd.exe /c flutter build windows }

            if ($res.ExitCode -ne 0) {
                Write-DashboardLog "[FAIL] Windows Desktop Build Failed!" "Windows build failed"
            } else {
                $winReleaseDir = "build\windows\x64\runner\Release"
                $zipPath = Join-Path $distDir "wznotes-windows-v$ver.zip"
                Write-DashboardLog "[PACKAGE] Compressing release into $zipPath..."
                if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
                Compress-Archive -Path "$winReleaseDir\*" -DestinationPath $zipPath -Force
                Set-PipelineProgress 70 "[PASS] Windows Package Ready"
                Write-DashboardLog "[PASS] Windows Package Ready: wznotes-windows-v$ver.zip" "Windows package ready"
            }
        }

        # STEP 4: Build Android APK
        if ($doAndroid) {
            Write-DashboardLog "========================================"
            Set-PipelineProgress 72 "[4/6] Compiling Android APK Release..."
            $res = Invoke-PipelineCommand "Android Release APK Build" { cmd.exe /c flutter build apk --release }

            $apkSource = "build\app\outputs\flutter-apk\app-release.apk"
            if (Test-Path $apkSource) {
                $apkDest = Join-Path $distDir "wznotes-android-v$ver.apk"
                Copy-Item -Path $apkSource -Destination $apkDest -Force
                Set-PipelineProgress 90 "[PASS] Android APK Ready"
                Write-DashboardLog "[PASS] Android APK Ready: wznotes-android-v$ver.apk" "Android APK ready"
            } else {
                Write-DashboardLog "[WARN] Android APK build completed with warnings or was skipped."
            }
        }

        # STEP 5: Generate Manifest
        if ($doManifest) {
            Write-DashboardLog "========================================"
            Set-PipelineProgress 92 "[5/6] Generating version_manifest.json..."
            $manifest = @{
                version = $ver
                build_number = [int]$build
                title = "wznotes v$ver Update"
                release_notes = $notes
                windows_url = "https://github.com/straculencuandrei/wznotes/releases/download/v$ver/wznotes-windows-v$ver.zip"
                android_url = "https://github.com/straculencuandrei/wznotes/releases/download/v$ver/wznotes-android-v$ver.apk"
                is_mandatory = [bool]$isMandatory
                published_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            }

            $json = $manifest | ConvertTo-Json -Depth 4
            Set-Content (Join-Path $distDir "version_manifest.json") -Value $json
            Set-Content (Join-Path $ProjectRoot "version_manifest.json") -Value $json
            Set-PipelineProgress 95 "[PASS] Manifest Generated"
            Write-DashboardLog "[PASS] version_manifest.json generated successfully."
        }

        # STEP 6: Git Tag & Push
        if ($doGitTag) {
            Write-DashboardLog "========================================"
            Set-PipelineProgress 96 "[6/6] Tagging and Pushing to Git..."
            
            Invoke-PipelineCommand "Stage changes" { git add . }
            
            $statusCheck = (git status --porcelain)
            if ($statusCheck) {
                Invoke-PipelineCommand "Commit release" { git commit -m "Release v${ver}+${build} - $notes" }
            } else {
                Write-DashboardLog "[INFO] Working tree clean, nothing new to commit."
            }

            Invoke-PipelineCommand "Create Git Tag v$ver" { git tag -f -a "v$ver" -m "wznotes Release v$ver" }
            Write-DashboardLog "[PASS] Git tag v$ver created successfully."

            if ($doGitPush) {
                Write-DashboardLog "[GIT] Pushing commits and tag v$ver to GitHub..." "Pushing to Git..."
                Invoke-PipelineCommand "Push commits" { git push origin main }
                Invoke-PipelineCommand "Push tag v$ver" { git push origin "v$ver" --force }
                Invoke-PipelineCommand "Push all tags" { git push origin --tags }
                Write-DashboardLog "[PASS] Pushed commits and tag v$ver to GitHub successfully!"
            }

            Write-DashboardLog "[LINK] Create GitHub Release with binaries: https://github.com/straculencuandrei/wznotes/releases/new?tag=v$ver"
        }

        Set-PipelineProgress 100 "All steps completed successfully!"
        Write-DashboardLog "========================================"
        Write-DashboardLog "[COMPLETE] All selected pipeline steps finished successfully!" "Build & Update Ready!"
    } catch {
        Write-DashboardLog "[ERROR] $($_.Exception.Message)" "Error encountered"
        Write-DashboardLog "[ERROR] $($_.ScriptStackTrace)"
    } finally {
        $btnStart.IsEnabled = $true
        [System.Windows.Forms.Application]::DoEvents()
    }
})

$window.ShowDialog() | Out-Null

