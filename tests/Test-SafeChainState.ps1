[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0
function Assert-True { param([bool] $Condition, [string] $Message); $script:assertions++; if (-not $Condition) { throw "Assertion failed: $Message" } }

$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\safe-chain.psd1')
$source = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-SafeChainState.ps1') -Raw
$catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
$capabilities = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\capabilities.psd1')

Assert-True ($configuration.Version -match '^\d+\.\d+\.\d+$') 'Safe-Chain declares a release version'
Assert-True ($configuration.Repository -eq 'AikidoSec/safe-chain') 'Safe-Chain declares the upstream repository'
foreach ($platform in @($configuration.Windows, $configuration.Linux)) {
    Assert-True ($platform.InstallerSha256 -match '^[a-f0-9]{64}$') 'each Safe-Chain installer is hash pinned'
    Assert-True ($platform.BinarySha256 -match '^[a-f0-9]{64}$') 'each Safe-Chain binary is hash pinned'
}
Assert-True ($source.IndexOf('Get-FileHash -LiteralPath $path -Algorithm SHA256', [StringComparison]::Ordinal) -lt $source.IndexOf('& $installer', [StringComparison]::Ordinal)) 'the Windows installer is verified before execution'
Assert-True ($source -match '\$wslEnvironment\.WSL_DISTRIBUTION' -and $source -notmatch 'WSL_MALWARE_DISTRIBUTION|NixOS-AI|Debian-MW') 'Safe-Chain targets only the declared trusted developer distribution'
Assert-True ($source -match 'PowerShell initialization script' -and $source -match 'bash initialization script') 'PowerShell and Bash registrations are tested'
$module = @($catalog.Modules | Where-Object Name -eq 'SafeChain')
Assert-True ($module.Count -eq 1 -and $module[0].Default -and $module[0].DependsOn -contains 'PowerShellProfile') 'Safe-Chain is a focused default module after managed profiles'
$capability = @($capabilities.Capabilities | Where-Object Id -eq 'package-supply-chain')
Assert-True ($capability.Count -eq 1 -and $capability[0].StateCommands -contains '.\Apply-Workstation.ps1 -Mode Ensure -Module SafeChain') 'the human Safe-Chain repair command is routed'
Assert-True ($module[0].FeatureSpec -eq 'specs/013-default-workstation-utilities' -and $capability[0].FeatureSpec -eq $module[0].FeatureSpec -and $capability[0].Modules -contains 'SafeChain') 'Safe-Chain module and route share one feature governance owner'
Write-Host "Safe-Chain state tests passed ($script:assertions assertions)."
