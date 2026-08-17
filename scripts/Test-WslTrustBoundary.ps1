# Test-WslTrustBoundary is the observational 'Test' command and never starts a stopped distribution.
[CmdletBinding()]
param(
    [ValidateSet('TrustedUtility', 'MalwareAnalysis', 'DevOps', 'AiAgent')]
    [string[]] $Role = @('TrustedUtility', 'MalwareAnalysis', 'DevOps', 'AiAgent'),
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
. (Join-Path $PSScriptRoot 'WslBoundary.Core.ps1')
$selection = Import-WslEnvironment $repositoryRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\wsl-trust-boundaries.psd1')
$configuration.Distributions = @($configuration.Distributions | Where-Object { $_.Role -in $Role })
$state = Get-WslTrustBoundaryState $configuration $selection
if ($Json) { $state | ConvertTo-Json -Depth 10 } else { Get-WslTrustBoundaryHumanText $state | Write-Host }
if ($state.Status -eq 'compliant') { exit 0 }
exit 1
