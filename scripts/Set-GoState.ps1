[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\go.psd1')
$packageConfiguration = Join-Path $repositoryRoot $configuration.PackageConfiguration
$declaredGoPath = Join-Path $env:USERPROFILE $configuration.GoPath
$declaredBinPath = Join-Path $declaredGoPath 'bin'

function Test-UserPathEntry {
    param([string] $Entry)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    @($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ieq $Entry.TrimEnd('\') }).Count -gt 0
}

function Add-UserPathEntry {
    param([string] $Entry)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = [Collections.Generic.List[string]]::new()
    foreach ($item in @($userPath -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($item) -and
            $item.TrimEnd('\') -ine $Entry.TrimEnd('\')) {
            $entries.Add($item)
        }
    }
    $entries.Add($Entry)
    [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
    if (-not (Test-UserPathEntry -Entry $Entry)) { throw "Failed to add '$Entry' to the user PATH." }
}

function Test-WinGetPackage {
    param([switch] $Quiet)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $packageOutput = @(& winget configure test --file $packageConfiguration `
            --accept-configuration-agreements --disable-interactivity 2>&1)
        $packageExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if (-not $Quiet) { $packageOutput | Out-Host }
    $packageExitCode -eq 0
}

function Get-GoState {
    $goCommand = Get-Command go.exe -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    $goVersion = $null
    $effectiveGoPath = $null
    $effectiveGoBin = $null
    $effectiveToolchain = $null
    $effectiveGoRoot = $null
    if ($goCommand) {
        $versionText = @(& $goCommand.Source version 2>$null) -join ''
        if ($versionText -match 'go([0-9]+\.[0-9]+(?:\.[0-9]+)?)') { $goVersion = $Matches[1] }
        $effectiveGoPath = @(& $goCommand.Source env GOPATH 2>$null) -join ''
        $effectiveGoBin = @(& $goCommand.Source env GOBIN 2>$null) -join ''
        $effectiveToolchain = @(& $goCommand.Source env GOTOOLCHAIN 2>$null) -join ''
        $effectiveGoRoot = @(& $goCommand.Source env GOROOT 2>$null) -join ''
    }
    $checks = [ordered]@{
        Package = [bool] $goCommand
        MinimumVersion = ($goVersion -and [version] $goVersion -ge [version] $configuration.MinimumVersion)
        GoPath = ($effectiveGoPath -ieq $declaredGoPath)
        GoBin = ([string]::IsNullOrWhiteSpace($effectiveGoBin) -or $effectiveGoBin -ieq $declaredBinPath)
        GoBinOnUserPath = Test-UserPathEntry -Entry $declaredBinPath
        ToolchainManager = ($effectiveToolchain -eq $configuration.Toolchain)
        GoRootUnmanaged = [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('GOROOT', 'User'))
    }
    [pscustomobject]@{
        Status = if ($checks.Values -contains $false) { 'drift-detected' } else { 'compliant' }
        PackageId = $configuration.PackageId
        Version = $goVersion
        Executable = if ($goCommand) { $goCommand.Source } else { $null }
        GoPath = $effectiveGoPath
        GoBin = if ($effectiveGoBin) { $effectiveGoBin } else { $declaredBinPath }
        GoRoot = $effectiveGoRoot
        GoToolchain = $effectiveToolchain
        VersionManager = 'Go built-in toolchain selection (go.mod/go.work + GOTOOLCHAIN)'
        Checks = [pscustomobject] $checks
    }
}

function Write-State {
    param([object] $State)
    if ($Json) { $State | ConvertTo-Json -Depth 6; return }
    Write-Host "Go: $($State.Status) ($($State.Version), $($State.GoToolchain))"
    $State.Checks.PSObject.Properties | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Name, $(if ($_.Value) { 'compliant' } else { 'drift detected' }))
    }
    Write-Host "  GOPATH: $($State.GoPath)"
    Write-Host "  command bin: $($State.GoBin)"
}

$before = Get-GoState
$packageCompliant = Test-WinGetPackage -Quiet:($Json -or $Mode -ne 'Test')
$before.Checks.Package = $before.Checks.Package -and $packageCompliant
if (-not $packageCompliant) { $before.Status = 'drift-detected' }
if ($Mode -eq 'Test') {
    Write-State $before
    if ($before.Status -ne 'compliant') { exit 1 }
    exit 0
}

if (-not $before.Checks.Package -or $Mode -eq 'Reinitialize') {
    & winget configure --file $packageConfiguration `
        --accept-configuration-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Go WinGet Configuration failed with exit code $LASTEXITCODE." }
}

$go = (Get-Command go.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
if ($before.GoPath -ine $declaredGoPath -or $Mode -eq 'Reinitialize') {
    [Environment]::SetEnvironmentVariable('GOPATH', $declaredGoPath, 'User')
    $env:GOPATH = $declaredGoPath
}
New-Item -ItemType Directory -Path $declaredBinPath -Force | Out-Null
Add-UserPathEntry -Entry $declaredBinPath
if (@($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $declaredBinPath.TrimEnd('\') }).Count -eq 0) {
    $env:Path = "$env:Path;$declaredBinPath"
}
& $go env -w "GOTOOLCHAIN=$($configuration.Toolchain)"
if ($LASTEXITCODE -ne 0) { throw 'Failed to enable Go built-in toolchain selection.' }

$after = Get-GoState
Write-State $after
if ($after.Status -ne 'compliant') { throw 'Go did not reach the declared package and environment state.' }
