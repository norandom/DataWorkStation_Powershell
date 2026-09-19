[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$runtime = (Get-Command pwsh.exe -ErrorAction Stop).Source
$apply = Join-Path $repositoryRoot 'Apply-Workstation.ps1'

# Protect the opt-in boundary using the real public planner, without invoking installers.
$defaultPlan = & $runtime -NoProfile -File $apply -Mode Test -Plan -Json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Default plan failed.' }
if ('ProcessLasso' -in $defaultPlan.ExecutionOrder.Name) { throw 'Process Lasso leaked into the default plan.' }
$focusedPlan = & $runtime -NoProfile -File $apply -Mode Ensure -Module ProcessLasso -Plan -Json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Focused Process Lasso plan failed.' }
if (($focusedPlan.ExecutionOrder.Name -join ',') -ne 'PowerShell7,ProcessLasso') {
    throw 'Focused plan must contain only PowerShell7 and ProcessLasso.'
}

# Extract the observation function to exercise missing/partial/complete installations in fixtures.
$tokens = $null
$parseErrors = $null
$resourcePath = Join-Path $repositoryRoot 'scripts\Set-ProcessLassoState.ps1'
$ast = [Management.Automation.Language.Parser]::ParseFile($resourcePath, [ref] $tokens, [ref] $parseErrors)
if ($parseErrors.Count) { throw 'Process Lasso resource does not parse.' }
$functionAst = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ProcessLassoState' }, $false)
. ([scriptblock]::Create($functionAst.Extent.Text))
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\process-lasso.psd1')
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('process-lasso-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $missing = Get-ProcessLassoState -InstallDirectory $fixtureRoot
    if ($missing.State -ne 'drift detected') { throw 'Missing installation was reported compliant.' }
    New-Item -ItemType File -Path (Join-Path $fixtureRoot $configuration.GuiExecutable) | Out-Null
    $partial = Get-ProcessLassoState -InstallDirectory $fixtureRoot
    if ($partial.State -ne 'drift detected') { throw 'Missing governor was reported compliant.' }
    New-Item -ItemType File -Path (Join-Path $fixtureRoot $configuration.GovernorExecutable) | Out-Null
    $complete = Get-ProcessLassoState -InstallDirectory $fixtureRoot
    if ($complete.State -ne 'compliant' -or -not $complete.Optional) { throw 'Complete optional package was not recognized.' }
    $roundTrip = $complete | ConvertTo-Json | ConvertFrom-Json
    if ($roundTrip.PackageId -ne 'BitSum.ProcessLasso') { throw 'Structured package identity was lost.' }
    if ($roundTrip.LicenseRequirement -notmatch 'commercial use' -or $roundTrip.LicenseUrl -ne 'https://bitsum.com/howfree/') { throw 'Commercial licensing requirement must be visible in package state.' }
    if ($roundTrip.LicenseStatus -notmatch '^not checked') { throw 'Installed files must not imply a verified license.' }
} finally {
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolvedFixture.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped the temporary directory.' }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
Write-Host 'Process Lasso opt-in planning and installation-state checks passed.'
