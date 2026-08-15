[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\native-development.psd1')
$cargoHome = Join-Path $env:USERPROFILE $configuration.Environment.CargoHome
$rustupHome = Join-Path $env:USERPROFILE $configuration.Environment.RustupHome
$cargoBin = Join-Path $cargoHome 'bin'

function Get-RustCommand {
    param([string] $Name)
    $command = Get-Command $Name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($command) { return $command.Source }
    $candidate = Join-Path $cargoBin $Name
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    $null
}

function Test-UserPathEntry {
    $path = [Environment]::GetEnvironmentVariable('Path', 'User')
    @($path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $cargoBin.TrimEnd('\') }).Count -eq 1
}

function Add-UserPathEntry {
    $path = [Environment]::GetEnvironmentVariable('Path', 'User')
    $items = [Collections.Generic.List[string]]::new()
    foreach ($item in @($path -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($item) -and $item.TrimEnd('\') -ine $cargoBin.TrimEnd('\')) { $items.Add($item) }
    }
    $items.Add($cargoBin)
    [Environment]::SetEnvironmentVariable('Path', ($items -join ';'), 'User')
}

function Get-RustState {
    $rustup = Get-RustCommand 'rustup.exe'
    $rustc = Get-RustCommand 'rustc.exe'
    $cargo = Get-RustCommand 'cargo.exe'
    $active = if ($rustup) { (@(& $rustup show active-toolchain 2>$null) -join '').Trim() } else { $null }
    $checks = [ordered]@{
        Package = [bool] $rustup
        Rustc = [bool] $rustc
        Cargo = [bool] $cargo
        StableMsvc = $active -match '^stable-x86_64-pc-windows-msvc'
        CARGO_HOME = [Environment]::GetEnvironmentVariable('CARGO_HOME', 'User') -ieq $cargoHome
        RUSTUP_HOME = [Environment]::GetEnvironmentVariable('RUSTUP_HOME', 'User') -ieq $rustupHome
        CargoBinOnUserPath = Test-UserPathEntry
        ProjectToolchainUnforced = [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('RUSTUP_TOOLCHAIN', 'User'))
        ProjectTargetUnforced = [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('CARGO_BUILD_TARGET', 'User'))
    }
    [pscustomobject]@{
        SchemaVersion = 1; Resource = 'RustToolchain'; State = if ($checks.Values -contains $false) { 'drift detected' } else { 'compliant' }
        Changed = $false; PackageId = $configuration.Packages.Rustup; Toolchain = $active
        CARGO_HOME = $cargoHome; RUSTUP_HOME = $rustupHome; Checks = [pscustomobject] $checks
    }
}

function Write-RustState {
    param([object] $State, [switch] $AsJson)
    if ($AsJson) { $State | ConvertTo-Json -Depth 6; return }
    Write-Host "Rust toolchain: $($State.State)"
    Write-Host "  active: $($State.Toolchain)"
    $State.Checks.PSObject.Properties | ForEach-Object { Write-Host ("  {0}: {1}" -f $_.Name, $(if ($_.Value) { 'compliant' } else { 'drift detected' })) }
}

$before = Get-RustState
if ($Mode -eq 'Test') {
    Write-RustState $before -AsJson:$Json
    if ($before.State -ne 'compliant') { exit 1 }
    exit 0
}
if (-not $before.Checks.Package -or $Mode -eq 'Reinitialize') {
    & winget.exe configure --file (Join-Path $repositoryRoot '.config\rustup.winget') --accept-configuration-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "rustup WinGet Configuration failed with exit code $LASTEXITCODE." }
}
[Environment]::SetEnvironmentVariable('CARGO_HOME', $cargoHome, 'User')
[Environment]::SetEnvironmentVariable('RUSTUP_HOME', $rustupHome, 'User')
$env:CARGO_HOME = $cargoHome
$env:RUSTUP_HOME = $rustupHome
New-Item -ItemType Directory -Path $cargoBin,$rustupHome -Force | Out-Null
Add-UserPathEntry
if (@($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $cargoBin.TrimEnd('\') }).Count -eq 0) { $env:Path = "$cargoBin;$env:Path" }
$rustup = Get-RustCommand 'rustup.exe'
if (-not $rustup) { throw 'rustup installed, but rustup.exe could not be resolved.' }
& $rustup set profile $configuration.Rust.Profile
if ($LASTEXITCODE -ne 0) { throw 'rustup profile selection failed.' }
& $rustup default $configuration.Rust.Toolchain
if ($LASTEXITCODE -ne 0) { throw 'rustup default stable-x86_64-pc-windows-msvc failed.' }
$after = Get-RustState
$after.Changed = ($before.State -ne 'compliant' -or $Mode -eq 'Reinitialize')
Write-RustState $after -AsJson:$Json
if ($after.State -ne 'compliant') { throw 'Rust toolchain did not reach the declared state.' }
