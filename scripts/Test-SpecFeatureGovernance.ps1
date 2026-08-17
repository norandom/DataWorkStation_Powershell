[CmdletBinding()]
param([switch] $Json)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'FeatureGovernance.Core.ps1')

$configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\spec-feature-governance.psd1')
$modules = (Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')).Modules
$capabilities = (Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\capabilities.psd1')).Capabilities

$adapter = @{
    TestFile = {
        param([string] $RelativePath)
        $path = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)))
        Test-Path -LiteralPath $path -PathType Leaf
    }
    InvokeFinalGate = {
        param([string] $FeatureSpec)
        $validator = Get-Command ears-sdd -CommandType Application -ErrorAction Stop
        $output = (& $validator.Source validate --project $repositoryRoot --feature $FeatureSpec --phase final --json 2>&1 | Out-String).Trim()
        $exitCode = $LASTEXITCODE
        $parsed = $null
        try { $parsed = $output | ConvertFrom-Json -ErrorAction Stop } catch { $parsed = $null }
        [pscustomobject]@{
            Passed = $exitCode -eq 0 -and $null -ne $parsed -and [bool] $parsed.ok
            Detail = if ($null -ne $parsed) {
                "errors=$($parsed.summary.errors); warnings=$($parsed.summary.warnings); requirements=$($parsed.summary.requirements)"
            } elseif ($output) {
                $output
            } else {
                "ears-sdd exited $exitCode without structured output"
            }
        }
    }
}

$result = Invoke-SpecFeatureGovernanceEvaluation -RepositoryRoot $repositoryRoot -Modules $modules `
    -Capabilities $capabilities -Configuration $configuration -Adapter $adapter

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    Write-Output (Get-SpecFeatureGovernanceHumanText -Result $result)
}

if (-not $result.Compliant) { exit 1 }
