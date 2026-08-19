[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'SoftwareRelease.Core.ps1')
. (Join-Path $PSScriptRoot 'Import-WorkstationConfiguration.ps1')
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\contour-terminal.psd1')
$localConfiguration = Import-WorkstationConfiguration -RepositoryRoot $repositoryRoot
$package = $configuration.Package
$packageRelease = Resolve-PinnedSoftwareReleaseAsset -Name 'Contour' -Version $package.Version
$scoopRoot = [Environment]::ExpandEnvironmentVariables($configuration.ScoopRoot)
$desiredConfigPath = Join-Path $repositoryRoot $configuration.DesiredConfig
$userConfigPath = [Environment]::ExpandEnvironmentVariables($configuration.UserConfig)
$backupDirectory = Join-Path $repositoryRoot $configuration.BackupDirectory
$binaryPath = Join-Path ([Environment]::ExpandEnvironmentVariables($package.InstallRoot)) $package.Binary
$scoopAppDirectory = Join-Path $scoopRoot "apps\$($configuration.LegacyScoopAppName)"
$scoopManifestPath = Join-Path $scoopAppDirectory 'current\manifest.json'
$desktopDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonDesktopDirectory)
$desktopShortcutPath = Join-Path $desktopDirectory $configuration.DesktopShortcutName
$userDesktopDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
$legacyDesktopShortcutPath = Join-Path $userDesktopDirectory $configuration.LegacyDesktopShortcutName
$graphicsGate = $configuration.GraphicsCompatibilityGate
$uninstallRoots = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

function Get-ScoopCommand {
    $command = Get-Command scoop.ps1 -CommandType ExternalScript -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $fallback = Join-Path $scoopRoot 'shims\scoop.ps1'
    if (Test-Path -LiteralPath $fallback -PathType Leaf) { return $fallback }
    $null
}

function Get-ScoopManifestVersion {
    if (-not (Test-Path -LiteralPath $scoopManifestPath -PathType Leaf)) { return $null }
    try {
        (Get-Content -LiteralPath $scoopManifestPath -Raw | ConvertFrom-Json).version
    } catch {
        throw "Scoop manifest is not valid JSON: $scoopManifestPath"
    }
}

function Get-ContourMsiEntries {
    @(
        Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -eq $package.DisplayName -or
                $_.PSChildName -eq $package.ProductCode
            } |
            ForEach-Object {
                [pscustomobject]@{
                    ProductCode = [string] $_.PSChildName
                    DisplayName = [string] $_.DisplayName
                    DisplayVersion = [string] $_.DisplayVersion
                    InstallLocation = [string] $_.InstallLocation
                    UninstallString = [string] $_.UninstallString
                }
            }
    )
}

function Get-TerminalFontFamily {
    $family = [string] $localConfiguration.Fonts.TerminalFamily
    if (-not $family -or $family -match '[\r\n\x00]') {
        throw "Terminal font preference must contain exactly one non-empty family name in $($localConfiguration.ConfigurationPath)."
    }
    $family
}

function Get-DesiredContourConfigContent {
    param([string] $FontFamily)

    $template = Get-Content -LiteralPath $desiredConfigPath -Raw
    $placeholder = [string] $configuration.FontFamilyPlaceholder
    if (-not $placeholder -or @($template.Split($placeholder)).Count -ne 2) {
        throw "Managed Contour template must contain exactly one font placeholder '$placeholder': $desiredConfigPath"
    }
    $template.Replace($placeholder, $FontFamily.Replace("'", "''"))
}

function Test-FileContentEqual {
    param([string] $Path, [string] $ExpectedContent)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    (Get-Content -LiteralPath $Path -Raw) -ceq $ExpectedContent
}

function Get-ShortcutState {
    if (-not (Test-Path -LiteralPath $desktopShortcutPath -PathType Leaf)) {
        return [pscustomobject]@{ Exists = $false; TargetPath = ''; Compliant = $false }
    }
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($desktopShortcutPath)
    $targetPath = [string] $shortcut.TargetPath
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut)
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    [pscustomobject]@{
        Exists = $true
        TargetPath = $targetPath
        Compliant = $targetPath -and [string]::Equals(
            [IO.Path]::GetFullPath($targetPath),
            [IO.Path]::GetFullPath($binaryPath),
            [StringComparison]::OrdinalIgnoreCase
        )
    }
}

function Get-DisplayDriverSummary {
    $drivers = @(
        Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
            Where-Object DeviceClass -EQ 'DISPLAY' |
            ForEach-Object {
                "$($_.DeviceName): $($_.DriverVersion), $($_.InfName)"
            }
    )
    if ($drivers.Count -eq 0) { return 'no active display driver found' }
    $drivers -join '; '
}

function Format-ContourDiagnosticText {
    param([string] $Text)

    if (-not $Text) { return '' }
    $plainText = $Text -replace "$([char] 27)\[[0-?]*[ -/]*[@-~]", ''
    $plainText = ($plainText -replace '\s+', ' ').Trim()
    if ($plainText.Length -le 2000) { return $plainText }
    "$($plainText.Substring(0, 2000))..."
}

function Test-ContourGraphicsCompatibility {
    if (-not $graphicsGate.Enabled) {
        return [pscustomobject]@{ Checked = $false; Compatible = $true; Detail = 'disabled by declaration' }
    }
    if (-not (Test-Path -LiteralPath $binaryPath -PathType Leaf)) {
        return [pscustomobject]@{ Checked = $false; Compatible = $false; Detail = 'not run because the declared binary is absent' }
    }

    $stdoutPath = Join-Path ([IO.Path]::GetTempPath()) "contour-graphics-$([guid]::NewGuid().ToString('N')).stdout.log"
    $stderrPath = Join-Path ([IO.Path]::GetTempPath()) "contour-graphics-$([guid]::NewGuid().ToString('N')).stderr.log"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $process = $null
    $timedOut = $false
    try {
        $arguments = @(
            'terminal'
            'early-exit-threshold'
            '0'
            '--'
            "$env:SystemRoot\System32\PING.EXE"
            '-n'
            [string] $graphicsGate.PingCount
            '127.0.0.1'
        )
        $process = Start-Process -FilePath $binaryPath -ArgumentList $arguments -WindowStyle Minimized `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
        if (-not $process.WaitForExit([int] $graphicsGate.TimeoutSeconds * 1000)) {
            $timedOut = $true
            [void] $process.CloseMainWindow()
            if (-not $process.WaitForExit(2000)) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                [void] $process.WaitForExit(2000)
            }
        }
        $timer.Stop()
        $stdout = if (Test-Path -LiteralPath $stdoutPath) { Format-ContourDiagnosticText (Get-Content -LiteralPath $stdoutPath -Raw) } else { '' }
        $stderr = if (Test-Path -LiteralPath $stderrPath) { Format-ContourDiagnosticText (Get-Content -LiteralPath $stderrPath -Raw) } else { '' }
        $exitCode = if ($process.HasExited) { $process.ExitCode } else { $null }
        $runtimeSeconds = [math]::Round($timer.Elapsed.TotalSeconds, 2)
        $compatible = -not $timedOut -and $exitCode -eq 0 -and
            $runtimeSeconds -ge [double] $graphicsGate.MinimumRuntimeSeconds
        $detailParts = @(
            "exit=$exitCode"
            "runtime=$runtimeSeconds s"
        )
        if ($timedOut) { $detailParts += "timed out after $($graphicsGate.TimeoutSeconds) s" }
        if (-not $compatible) {
            if ($stdout) { $detailParts += "stdout: $stdout" }
            if ($stderr) { $detailParts += "stderr: $stderr" }
            $detailParts += "active display driver: $(Get-DisplayDriverSummary)"
            $detailParts += 'If output identifies OpenGL, GLSL, or shader initialization, verify that the active display-driver version and INF match the installed vendor graphics stack.'
        }
        [pscustomobject]@{
            Checked = $true
            Compatible = $compatible
            Detail = $detailParts -join '; '
        }
    } catch {
        $timer.Stop()
        [pscustomobject]@{
            Checked = $true
            Compatible = $false
            Detail = "$($_.Exception.Message); active display driver: $(Get-DisplayDriverSummary)"
        }
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-ContourTerminalState {
    param([switch] $IncludeGraphicsGate)

    $msiEntries = Get-ContourMsiEntries
    $desiredMsi = @(
        $msiEntries | Where-Object {
            $_.ProductCode -eq $package.ProductCode -and
            $_.DisplayVersion -eq $package.Version
        }
    ) | Select-Object -First 1
    $observedMsi = if ($desiredMsi) { $desiredMsi } else { $msiEntries | Select-Object -First 1 }
    $scoopVersion = Get-ScoopManifestVersion
    $scoopInstalled = [bool](
        $scoopVersion -or
        (Test-Path -LiteralPath $scoopAppDirectory -PathType Container)
    )
    $binaryExists = Test-Path -LiteralPath $binaryPath -PathType Leaf
    $shortcutState = Get-ShortcutState
    $configCompliant = Test-FileContentEqual -Path $userConfigPath -ExpectedContent $script:desiredConfigContent
    $legacyShortcutExists = Test-Path -LiteralPath $legacyDesktopShortcutPath -PathType Leaf
    $packageCompliant = [bool]($desiredMsi -and $binaryExists -and -not $scoopInstalled)
    $staticCompliant = $packageCompliant -and $configCompliant -and
        $shortcutState.Compliant -and -not $legacyShortcutExists
    $graphicsState = if ($IncludeGraphicsGate -and $staticCompliant) {
        Test-ContourGraphicsCompatibility
    } elseif ($IncludeGraphicsGate) {
        [pscustomobject]@{ Checked = $false; Compatible = $false; Detail = 'not run because package, config, or shortcut state has drift' }
    } else {
        [pscustomobject]@{ Checked = $false; Compatible = $true; Detail = 'not requested for this intermediate state read' }
    }

    [pscustomobject]@{
        MsiEntries = $msiEntries
        ProductCode = if ($observedMsi) { $observedMsi.ProductCode } else { '' }
        InstalledVersion = if ($observedMsi) { $observedMsi.DisplayVersion } else { '' }
        DesiredVersion = $package.Version
        Binary = $binaryPath
        BinaryExists = $binaryExists
        PackageCompliant = $packageCompliant
        ScoopCommand = Get-ScoopCommand
        ScoopInstalled = $scoopInstalled
        ScoopVersion = $scoopVersion
        DesiredConfig = $desiredConfigPath
        UserConfig = $userConfigPath
        FontPreference = $localConfiguration.ConfigurationPath
        FontFamily = $script:terminalFontFamily
        ConfigCompliant = $configCompliant
        DesktopShortcut = $desktopShortcutPath
        ShortcutTarget = $shortcutState.TargetPath
        ShortcutCompliant = $shortcutState.Compliant
        LegacyDesktopShortcut = $legacyDesktopShortcutPath
        LegacyShortcutAbsent = -not $legacyShortcutExists
        GraphicsGateChecked = $graphicsState.Checked
        GraphicsCompatible = $graphicsState.Compatible
        GraphicsDetail = $graphicsState.Detail
        Compliant = $staticCompliant -and $graphicsState.Compatible
    }
}

function Write-ContourTerminalState {
    param([pscustomobject] $State)

    @(
        [pscustomobject]@{ Resource = 'ContourMsi'; State = if ($State.PackageCompliant) { 'compliant' } else { 'drift detected' }; Detail = "$($State.InstalledVersion) installed; $($State.DesiredVersion) required; $($State.ProductCode)" }
        [pscustomobject]@{ Resource = 'ContourScoopPackage'; State = if (-not $State.ScoopInstalled) { 'removed' } else { 'drift detected' }; Detail = if ($State.ScoopVersion) { "$($State.ScoopVersion) remains installed" } else { $scoopAppDirectory } }
        [pscustomobject]@{ Resource = 'ContourConfig'; State = if ($State.ConfigCompliant) { 'compliant' } else { 'drift detected' }; Detail = "$($State.UserConfig); font=$($State.FontFamily); starts=~" }
        [pscustomobject]@{ Resource = 'ContourDesktopShortcut'; State = if ($State.ShortcutCompliant) { 'compliant' } else { 'drift detected' }; Detail = "$($State.DesktopShortcut) -> $($State.ShortcutTarget)" }
        [pscustomobject]@{ Resource = 'LegacyContourShortcut'; State = if ($State.LegacyShortcutAbsent) { 'removed' } else { 'drift detected' }; Detail = $State.LegacyDesktopShortcut }
        [pscustomobject]@{ Resource = 'ContourGraphicsGate'; State = if ($State.GraphicsCompatible) { if ($State.GraphicsGateChecked) { 'compatible' } else { 'not run' } } else { 'failed' }; Detail = $State.GraphicsDetail }
    ) | Format-Table -AutoSize -Wrap
}

function Backup-ManagedFile {
    param([string] $Path, [string] $Prefix)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $extension = [IO.Path]::GetExtension($Path)
    $backupPath = Join-Path $backupDirectory "$Prefix-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))$extension"
    Copy-Item -LiteralPath $Path -Destination $backupPath
    Write-Host "Backed up $Path to $backupPath"
}

function Invoke-MsiOperation {
    param(
        [ValidateSet('Install', 'Uninstall')]
        [string] $Operation,
        [string] $Target
    )

    $msiexec = (Get-Command msiexec.exe -CommandType Application -ErrorAction Stop).Source
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $logPath = Join-Path $backupDirectory "contour-msi-$($Operation.ToLowerInvariant())-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss')).log"
    $argumentLine = if ($Operation -eq 'Install') {
        "/i `"$Target`" /qn /norestart /L*v `"$logPath`""
    } else {
        "/x `"$Target`" /qn /norestart /L*v `"$logPath`""
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $process = Start-Process -FilePath $msiexec -ArgumentList $argumentLine -Wait -PassThru
        $exitCode = $process.ExitCode
    } else {
        $sudo = (Get-Command sudo.exe -CommandType Application -ErrorAction Stop).Source
        $windowsPowerShell = (Get-Command powershell.exe -CommandType Application -ErrorAction Stop).Source
        $escapedMsiExec = $msiexec.Replace("'", "''")
        $escapedArguments = $argumentLine.Replace("'", "''")
        $elevatedCommand = "`$process = Start-Process -FilePath '$escapedMsiExec' -ArgumentList '$escapedArguments' -Wait -PassThru; exit `$process.ExitCode"
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($elevatedCommand))
        & $sudo --inline $windowsPowerShell -NoLogo -NoProfile -NonInteractive -EncodedCommand $encodedCommand
        $exitCode = $LASTEXITCODE
    }
    if ($exitCode -notin @(0, 3010)) {
        throw "Contour MSI $Operation failed with exit code $exitCode. Inspect $logPath"
    }
    Write-Host "Contour MSI $Operation log: $logPath"
    if ($exitCode -eq 3010) {
        Write-Warning "Contour MSI $Operation completed and requested a restart; this resource will not restart Windows."
    }
}

if (-not (Test-Path -LiteralPath $desiredConfigPath -PathType Leaf)) {
    throw "Managed Contour configuration is missing: $desiredConfigPath"
}
$script:terminalFontFamily = Get-TerminalFontFamily
$script:desiredConfigContent = Get-DesiredContourConfigContent -FontFamily $script:terminalFontFamily

$state = Get-ContourTerminalState -IncludeGraphicsGate:($Mode -eq 'Test')
if ($Mode -eq 'Test') {
    Write-ContourTerminalState $state
    if (-not $state.Compliant) { exit 1 }
    exit 0
}

if ($state.ScoopInstalled) {
    if (-not $state.ScoopCommand) {
        throw "The legacy Scoop Contour package must be removed first, but Scoop is unavailable: $scoopAppDirectory"
    }
    & $state.ScoopCommand uninstall $configuration.LegacyScoopAppName
    if ($LASTEXITCODE -ne 0) {
        throw "Scoop failed to uninstall $($configuration.LegacyScoopAppName): $LASTEXITCODE"
    }
    $state = Get-ContourTerminalState
    if ($state.ScoopInstalled) {
        throw 'The legacy Scoop Contour package still exists after uninstall; the MSI was not installed.'
    }
    Write-Host 'Removed the legacy Scoop Contour package before MSI installation.'
}

if (-not $state.LegacyShortcutAbsent) {
    Backup-ManagedFile -Path $legacyDesktopShortcutPath -Prefix 'contour-scoop-shortcut'
    Remove-Item -LiteralPath $legacyDesktopShortcutPath -Force
}

if ($Mode -eq 'Reinitialize' -and $state.ProductCode -eq $package.ProductCode) {
    Invoke-MsiOperation -Operation Uninstall -Target $package.ProductCode
    $state = Get-ContourTerminalState
}

if (-not $state.PackageCompliant) {
    $installerPath = Join-Path ([IO.Path]::GetTempPath()) "contour-$($package.Version)-$([guid]::NewGuid().ToString('N')).msi"
    try {
        Invoke-WebRequest -Uri $packageRelease.Uri -OutFile $installerPath -UseBasicParsing
        $actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $package.Sha256.ToLowerInvariant()) {
            throw "Contour MSI SHA-256 mismatch. Expected $($package.Sha256), got $actualHash."
        }
        Invoke-MsiOperation -Operation Install -Target $installerPath
    } finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-FileContentEqual -Path $userConfigPath -ExpectedContent $script:desiredConfigContent)) {
    if (Test-Path -LiteralPath $userConfigPath -PathType Leaf) {
        Backup-ManagedFile -Path $userConfigPath -Prefix 'contour'
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $userConfigPath) -Force | Out-Null
    [IO.File]::WriteAllText($userConfigPath, $script:desiredConfigContent, [Text.UTF8Encoding]::new($false))
}

$result = Get-ContourTerminalState -IncludeGraphicsGate
Write-ContourTerminalState $result
if (-not $result.Compliant) { throw 'Contour Terminal did not reach the declared MSI, configuration, shortcut, and graphics-compatibility state.' }
Write-Host "Contour Terminal state '$Mode' completed successfully with the official release MSI, managed BlueTerm theme, and graphics gate."
