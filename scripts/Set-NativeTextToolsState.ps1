[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$packageFile = Join-Path $repositoryRoot '.config\native-text-tools.winget'
$configurationFile = Join-Path $repositoryRoot 'config\native-text-tools.psd1'
$configuration = Import-PowerShellDataFile -LiteralPath $configurationFile
$shimDirectory = Join-Path $env:USERPROFILE $configuration.ShimDirectory

function Invoke-PackageState {
    $arguments = @(
        'configure'
        if ($Mode -eq 'Test') { 'test' }
        '--file'
        $packageFile
        '--accept-configuration-agreements'
        '--disable-interactivity'
    )
    & winget.exe @arguments | Out-Host
    $LASTEXITCODE
}

function Get-BusyBoxPath {
    $command = Get-Command $configuration.PackageCommand -CommandType Application -ErrorAction Ignore
    if ($command) { return $command.Source }

    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    $packageDirectories = @(Get-ChildItem -LiteralPath $packageRoot -Directory -ErrorAction Ignore |
        Where-Object Name -Like "$($configuration.PackageDirectoryPrefix)*")
    $packageMatches = @($packageDirectories | ForEach-Object {
        Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter $configuration.PackageExecutable -ErrorAction Ignore
    })
    if ($packageMatches.Count -eq 1) { return $packageMatches[0].FullName }
    if ($packageMatches.Count -gt 1) {
        throw "Multiple WinGet BusyBox package binaries found: $($packageMatches.FullName -join ', ')"
    }
    $null
}

function Get-AppletState {
    param([AllowNull()][string] $BusyBoxPath)

    $sourceHash = if ($BusyBoxPath -and (Test-Path -LiteralPath $BusyBoxPath -PathType Leaf)) {
        (Get-FileHash -LiteralPath $BusyBoxPath -Algorithm SHA256).Hash
    } else {
        $null
    }

    foreach ($applet in $configuration.Applets) {
        $path = Join-Path $shimDirectory "$applet.exe"
        $hash = if (Test-Path -LiteralPath $path -PathType Leaf) {
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        } else {
            $null
        }
        [pscustomobject]@{
            Applet = $applet
            Path = $path
            State = if ($sourceHash -and $hash -eq $sourceHash) { 'compliant' } else { 'drift detected' }
        }
    }
}

function Test-Applets {
    $awkPath = Join-Path $shimDirectory 'awk.exe'
    $sedPath = Join-Path $shimDirectory 'sed.exe'
    $awkResult = @('alpha beta' | & $awkPath '{print $2}')
    if ($LASTEXITCODE -ne 0 -or $awkResult -join "`n" -ne 'beta') {
        throw "awk smoke test failed: $($awkResult -join ' ')"
    }
    $sedResult = @('abc' | & $sedPath 's/b/B/')
    if ($LASTEXITCODE -ne 0 -or $sedResult -join "`n" -ne 'aBc') {
        throw "sed smoke test failed: $($sedResult -join ' ')"
    }
}

$packageExitCode = Invoke-PackageState
$busyBoxPath = Get-BusyBoxPath
$appletState = @(Get-AppletState -BusyBoxPath $busyBoxPath)

if ($Mode -eq 'Test') {
    $result = [Collections.Generic.List[object]]::new()
    $result.Add([pscustomobject]@{
        Resource = 'NativeTextToolsPackage'
        State = if ($packageExitCode -eq 0) { 'compliant' } else { 'drift detected' }
        Detail = $configuration.PackageId
    })
    $appletState | ForEach-Object {
        $result.Add([pscustomobject]@{ Resource = "$($_.Applet)Command"; State = $_.State; Detail = $_.Path })
    }
    $result | Format-Table Resource,State,Detail -AutoSize -Wrap | Out-Host
    if ($packageExitCode -ne 0 -or 'drift detected' -in $appletState.State) { exit 1 }
    Test-Applets
    Write-Host 'Native awk and sed state is compliant; functional smoke tests passed.'
    exit 0
}

if ($packageExitCode -ne 0) {
    throw "WinGet Configuration failed for $($configuration.PackageId) with exit code $packageExitCode."
}
$busyBoxPath = Get-BusyBoxPath
if (-not $busyBoxPath) {
    throw "WinGet reported success but $($configuration.PackageCommand) is not available on PATH. Open a new terminal and rerun Ensure if WinGet has just changed its portable-package links."
}

New-Item -ItemType Directory -Path $shimDirectory -Force | Out-Null
foreach ($applet in $configuration.Applets) {
    Copy-Item -LiteralPath $busyBoxPath -Destination (Join-Path $shimDirectory "$applet.exe") -Force
}

$appletState = @(Get-AppletState -BusyBoxPath $busyBoxPath)
if ('drift detected' -in $appletState.State) {
    throw 'One or more native text-tool applets do not match the WinGet-managed BusyBox binary.'
}
Test-Applets

[pscustomobject]@{ Resource = 'NativeTextToolsPackage'; State = 'compliant'; Detail = $configuration.PackageId }
$appletState | ForEach-Object {
    [pscustomobject]@{ Resource = "$($_.Applet)Command"; State = $_.State; Detail = $_.Path }
}
Write-Host "Native text-tool state '$Mode' completed successfully; awk and sed smoke tests passed."
