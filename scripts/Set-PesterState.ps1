[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\pester.psd1')
$moduleBase = [Environment]::ExpandEnvironmentVariables([string] $configuration.ModuleBase)
$declaredVersion = [string] $configuration.Version
$manifestPath = Join-Path $moduleBase "Pester\$declaredVersion\Pester.psd1"
$modulePathEntries = @($env:PSModulePath -split ';' | Where-Object { $_ })
if ($moduleBase -notin $modulePathEntries) { $env:PSModulePath = "$moduleBase;$env:PSModulePath" }

function Get-RuntimePesterVersion {
    param([Parameter(Mandatory = $true)][string] $Executable)
    $command = "`$module = Get-Module -ListAvailable Pester | Where-Object Version -eq '$declaredVersion' | Select-Object -First 1; if (`$module) { `$module.Version.ToString() }"
    $output = @(& $Executable -NoLogo -NoProfile -Command $command 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    (@($output | ForEach-Object { ([string] $_).Trim() } | Where-Object { $_ -match '^\d+\.\d+\.\d+' }) | Select-Object -First 1)
}

function Get-PesterState {
    $pwshCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    $windowsPowerShellCommand = Get-Command powershell.exe -ErrorAction SilentlyContinue
    $powerShell7Version = if ($pwshCommand) { Get-RuntimePesterVersion -Executable $pwshCommand.Source } else { $null }
    $windowsPowerShellVersion = if ($windowsPowerShellCommand) { Get-RuntimePesterVersion -Executable $windowsPowerShellCommand.Source } else { $null }
    $pending = [Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { $pending.Add("Save Pester $declaredVersion to the shared per-user module tree") }
    if ($powerShell7Version -ne $declaredVersion) { $pending.Add("Make PowerShell 7 resolve Pester $declaredVersion") }
    if ($windowsPowerShellVersion -ne $declaredVersion) { $pending.Add("Make Windows PowerShell resolve Pester $declaredVersion") }
    [pscustomobject]@{
        SchemaVersion = 1
        Status = if ($pending.Count -eq 0) { 'compliant' } else { 'drift-detected' }
        DeclaredVersion = $declaredVersion
        Repository = [string] $configuration.Repository
        ModuleBase = $moduleBase
        ManifestPath = $manifestPath
        PowerShell7Version = $powerShell7Version
        WindowsPowerShellVersion = $windowsPowerShellVersion
        PendingChanges = @($pending)
        Impact = 'Ensure performs a networked per-user module installation without elevation; test execution remains separate.'
    }
}

function Write-PesterState {
    param([Parameter(Mandatory = $true)][object] $State, [switch] $AsJson)
    if ($AsJson) { $State | ConvertTo-Json -Depth 5; return }
    Write-Host "PowerShellTesting: $($State.Status)"
    Write-Host "  Declared Pester: $($State.DeclaredVersion)"
    $powerShell7Display = if ($State.PowerShell7Version) { $State.PowerShell7Version } else { 'not resolved' }
    $windowsPowerShellDisplay = if ($State.WindowsPowerShellVersion) { $State.WindowsPowerShellVersion } else { 'not resolved' }
    Write-Host "  PowerShell 7: $powerShell7Display"
    Write-Host "  Windows PowerShell: $windowsPowerShellDisplay"
    Write-Host "  Shared module base: $($State.ModuleBase)"
    foreach ($change in $State.PendingChanges) { Write-Host "  Pending: $change" }
    Write-Host "  Impact: $($State.Impact)"
}

$before = Get-PesterState
if ($Mode -eq 'Test') {
    Write-PesterState $before -AsJson:$Json
    if ($before.Status -ne 'compliant') { exit 1 }
    exit 0
}

if ($before.Status -ne 'compliant') {
    $saveCommand = Get-Command Save-PSResource -ErrorAction SilentlyContinue
    if (-not $saveCommand) {
        throw 'Microsoft.PowerShell.PSResourceGet with Save-PSResource is required. Ensure the PowerShell7 dependency first.'
    }
    [void] (New-Item -ItemType Directory -Path $moduleBase -Force)
    Write-Host "Installing exact Pester $declaredVersion from $($configuration.Repository) into '$moduleBase'. This is a networked per-user change."
    Save-PSResource -Name Pester -Version $declaredVersion -Repository $configuration.Repository `
        -Path $moduleBase -TrustRepository -AcceptLicense -ErrorAction Stop
}

$after = Get-PesterState
Write-PesterState $after -AsJson:$Json
if ($after.Status -ne 'compliant') { throw "Pester $declaredVersion did not become resolvable in both supported runtimes." }
