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
Assert-True (@($configuration.SupportedCommands | Where-Object { $_ -eq 'pnpm' }).Count -eq 1 -and @($configuration.SupportedCommands | Where-Object { $_ -eq 'pnpx' }).Count -eq 1) 'Safe-Chain explicitly declares pnpm and pnpx protection once each'
foreach ($platform in @($configuration.Windows, $configuration.Linux)) {
    Assert-True ($platform.InstallerSha256 -match '^[a-f0-9]{64}$') 'each Safe-Chain installer is hash pinned'
    Assert-True ($platform.BinarySha256 -match '^[a-f0-9]{64}$') 'each Safe-Chain binary is hash pinned'
}
Assert-True ($source.IndexOf('Get-FileHash -LiteralPath $path -Algorithm SHA256', [StringComparison]::Ordinal) -lt $source.IndexOf('& $installer', [StringComparison]::Ordinal)) 'the Windows installer is verified before execution'
Assert-True ($source -match '\$wslEnvironment\.WSL_DISTRIBUTION' -and $source -notmatch 'WSL_MALWARE_DISTRIBUTION|NixOS-AI|Debian-MW') 'Safe-Chain targets only the declared trusted developer distribution'
Assert-True ($source -match 'PowerShell initialization script' -and $source -match 'bash initialization script') 'PowerShell and Bash registrations are tested'
Assert-True ($source -match 'function Test-CommandWrappers' -and $source -match 'function Test-WindowsInitScript' -and $source -match 'function Test-LinuxInitScript') 'Safe-Chain semantically tests every declared command wrapper on Windows and Debian'
Assert-True ($source -match 'WindowsInitScript\s*=\s*Test-WindowsInitScript' -and $source -match 'DebianInitScript\s*=\s*Test-LinuxInitScript') 'wrapper coverage strengthens the existing initialization state contract'
Assert-True ($source -match '-not \$state\.WindowsInitScript' -and $source -match '-not \$state\.DebianInitScript') 'explicit repair reconciles missing initialization or declared wrappers'
Assert-True ($source -match 'Declared Safe-Chain wrappers') 'human Test output identifies the complete protected wrapper inventory even when the current PATH is stale'
$module = @($catalog.Modules | Where-Object Name -eq 'SafeChain')
Assert-True ($module.Count -eq 1 -and $module[0].Default -and $module[0].DependsOn -contains 'PowerShellProfile') 'Safe-Chain is a focused default module after managed profiles'
$capability = @($capabilities.Capabilities | Where-Object Id -eq 'package-supply-chain')
Assert-True ($capability.Count -eq 1 -and $capability[0].StateCommands -contains '.\Apply-Workstation.ps1 -Mode Ensure -Module SafeChain') 'the human Safe-Chain repair command is routed'
Assert-True ($capability[0].Triggers -contains 'pnpm safe-chain' -and $capability[0].Triggers -contains 'pnpx' -and $capability[0].InspectCommands -contains 'Get-Command pnpm,pnpx -CommandType Function | Format-List Name,Definition' -and $capability[0].InspectCommands -contains 'pnpm safe-chain-verify' -and $capability[0].InspectCommands -contains 'pnpx safe-chain-verify') 'the Safe-Chain route exposes pnpm/pnpx wrapper discovery and interception verification'
Assert-True ($module[0].FeatureSpec -eq 'specs/013-default-workstation-utilities' -and $capability[0].FeatureSpec -eq $module[0].FeatureSpec -and $capability[0].Modules -contains 'SafeChain') 'Safe-Chain module and route share one feature governance owner'
Write-Host "Safe-Chain state tests passed ($script:assertions assertions)."
