#pester:no-parallel
[CmdletBinding()]
param(
    [ValidateSet('All', 'HumanCommand', 'OutputParity', 'ModuleReference', 'StateRouteReference',
        'PathBoundary', 'RequiredArtifacts', 'FinalGate', 'ActionableFailure', 'PairedReference',
        'LegacyBoundary', 'LegacyFingerprint', 'NonMutation', 'PreCommitHook',
        'DocumentationAndRouting', 'UnrelatedDraft')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$corePath = Join-Path $repositoryRoot 'scripts\FeatureGovernance.Core.ps1'
$publicScriptPath = Join-Path $repositoryRoot 'scripts\Test-SpecFeatureGovernance.ps1'
$script:assertions = 0
$script:adapterCalls = [Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-TestLegacyFingerprint {
    param([string[]] $Modules, [string[]] $StateCapabilities)
    $canonical = "Modules`n$(@($Modules | Sort-Object) -join "`n")`nStateCapabilities`n$(@($StateCapabilities | Sort-Object) -join "`n")`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical))) -replace '-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function New-TestFixture {
    param(
        [object[]] $Modules,
        [object[]] $Capabilities,
        [string[]] $LegacyModules = @('LegacyModule'),
        [string[]] $LegacyStateCapabilities = @('legacy-state'),
        [string[]] $Files,
        [hashtable] $GateResults
    )
    if (-not $Modules) {
        $Modules = @(
            @{ Name = 'LegacyModule' },
            @{ Name = 'ExploitProtection'; FeatureSpec = 'specs/011-exploit-protection' }
        )
    }
    if (-not $Capabilities) {
        $Capabilities = @(
            @{ Id = 'legacy-state'; StateCommands = @('legacy ensure') },
            @{ Id = 'windows-exploit-protection'; StateCommands = @('exploit ensure'); Modules = @('ExploitProtection'); FeatureSpec = 'specs/011-exploit-protection' }
        )
    }
    if (-not $Files) {
        $Files = @('spec.md', 'plan.md', 'tasks.md', 'traceability.toml') | ForEach-Object {
            'specs/011-exploit-protection/' + $_
        }
    }
    if (-not $GateResults) { $GateResults = @{ 'specs/011-exploit-protection' = $true } }
    $configuration = @{
        SchemaVersion = 1
        RequiredArtifacts = @('spec.md', 'plan.md', 'tasks.md', 'traceability.toml')
        LegacyBoundary = @{
            CapturedUtc = '2026-08-17T00:00:00Z'
            Modules = $LegacyModules
            StateCapabilities = $LegacyStateCapabilities
            Sha256 = Get-TestLegacyFingerprint -Modules $LegacyModules -StateCapabilities $LegacyStateCapabilities
        }
    }
    $fileSet = @{}
    foreach ($file in $Files) { $fileSet[$file.Replace('\', '/')] = $true }
    $callLog = [Collections.Generic.List[string]]::new()
    $script:adapterCalls = $callLog
    $adapter = @{
        TestFile = {
            param([string] $RelativePath)
            $normalized = $RelativePath.Replace('\', '/')
            $callLog.Add("TestFile:$normalized")
            return $fileSet.ContainsKey($normalized)
        }.GetNewClosure()
        InvokeFinalGate = {
            param([string] $FeatureSpec)
            $callLog.Add("InvokeFinalGate:$FeatureSpec")
            $passed = $GateResults.ContainsKey($FeatureSpec) -and [bool] $GateResults[$FeatureSpec]
            return [pscustomobject]@{ Passed = $passed; Detail = if ($passed) { 'PASS' } else { 'FAIL' } }
        }.GetNewClosure()
    }
    [pscustomobject]@{
        Modules = $Modules
        Capabilities = $Capabilities
        Configuration = $configuration
        Adapter = $adapter
    }
}

function Invoke-Fixture {
    param([object] $Fixture)
    Invoke-SpecFeatureGovernanceEvaluation -RepositoryRoot 'C:\Repository' -Modules $Fixture.Modules `
        -Capabilities $Fixture.Capabilities -Configuration $Fixture.Configuration -Adapter $Fixture.Adapter
}

function Test-HumanCommand {
    $fixture = New-TestFixture
    $result = Invoke-Fixture $fixture
    $text = Get-SpecFeatureGovernanceHumanText -Result $result
    Assert-True ($result.Compliant -and $text -match 'Spec feature governance: compliant') 'human result reports compliance'
    Assert-True ($text -match 'ExploitProtection' -and $text -match 'windows-exploit-protection') 'human result names governed declarations'
    Assert-True ($text -match $result.LegacyFingerprint.ActualSha256) 'human result exposes the legacy fingerprint'
}

function Test-OutputParity {
    $fixture = New-TestFixture
    $result = Invoke-Fixture $fixture
    $roundTrip = $result | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $text = Get-SpecFeatureGovernanceHumanText -Result $result
    Assert-True ($roundTrip.SchemaVersion -eq 1 -and $roundTrip.Compliant -eq $result.Compliant) 'JSON preserves schema and compliance'
    Assert-True ($roundTrip.ModuleCount -eq $result.ModuleCount -and $roundTrip.StateRouteCount -eq $result.StateRouteCount) 'JSON preserves checked counts'
    Assert-True ($text -match $roundTrip.LegacyFingerprint.ActualSha256 -and $text -match $roundTrip.ReferencedFeatures[0].FeatureSpec) 'human and JSON expose the same fingerprint and feature'
}

function Test-ModuleReference {
    $fixture = New-TestFixture -Modules @(@{ Name = 'LegacyModule' }, @{ Name = 'NewModule' })
    $result = Invoke-Fixture $fixture
    $failure = @($result.Failures | Where-Object { $_.Code -eq 'MissingFeatureSpec' -and $_.Identity -eq 'NewModule' })
    Assert-True (-not $result.Compliant -and $failure.Count -eq 1) 'new module without a feature reference fails'
}

function Test-StateRouteReference {
    $fixture = New-TestFixture -Capabilities @(
        @{ Id = 'legacy-state'; StateCommands = @('legacy ensure') },
        @{ Id = 'new-state'; StateCommands = @('new ensure'); Modules = @('LegacyModule') }
    )
    $result = Invoke-Fixture $fixture
    Assert-True (@($result.Failures | Where-Object { $_.Code -eq 'MissingFeatureSpec' -and $_.Identity -eq 'new-state' }).Count -eq 1) 'new state route without a feature reference fails'
}

function Test-PathBoundary {
    foreach ($invalid in @('..\outside', 'C:\outside', 'specs\..\outside', 'docs/feature')) {
        $fixture = New-TestFixture -Modules @(@{ Name = 'LegacyModule' }, @{ Name = 'NewModule'; FeatureSpec = $invalid })
        $result = Invoke-Fixture $fixture
        Assert-True (@($result.Failures | Where-Object Code -eq 'InvalidFeaturePath').Count -ge 1) "invalid feature path '$invalid' fails"
    }
}

function Test-RequiredArtifacts {
    $files = @('spec.md', 'tasks.md', 'traceability.toml') | ForEach-Object { 'specs/011-exploit-protection/' + $_ }
    $fixture = New-TestFixture -Files $files
    $result = Invoke-Fixture $fixture
    $failure = @($result.Failures | Where-Object { $_.Code -eq 'MissingArtifact' -and $_.Message -match 'plan.md' })
    Assert-True (-not $result.Compliant -and $failure.Count -eq 1) 'missing plan is attributed'
    Assert-True (@($script:adapterCalls | Where-Object { $_ -like 'InvokeFinalGate:*' }).Count -eq 0) 'final gate does not run when artifacts are incomplete'
}

function Test-FinalGate {
    $fixture = New-TestFixture -GateResults @{ 'specs/011-exploit-protection' = $false }
    $result = Invoke-Fixture $fixture
    Assert-True (@($result.Failures | Where-Object Code -eq 'FinalGateFailed').Count -eq 1) 'failed final gate is retained'
    Assert-True (@($script:adapterCalls | Where-Object { $_ -eq 'InvokeFinalGate:specs/011-exploit-protection' }).Count -eq 1) 'referenced feature is validated once'
}

function Test-ActionableFailure {
    $fixture = New-TestFixture -Modules @(@{ Name = 'LegacyModule' }, @{ Name = 'NewModule' })
    $result = Invoke-Fixture $fixture
    $failure = $result.Failures[0]
    Assert-True ($failure.Code -and $failure.Kind -eq 'Module' -and $failure.Identity -eq 'NewModule') 'failure identifies code, kind, and declaration'
    Assert-True ($failure.Message.Length -gt 20 -and $result.Outcome -eq 'failed') 'failure contains actionable detail and failed outcome'
}

function Test-PairedReference {
    $capabilities = @(
        @{ Id = 'legacy-state'; StateCommands = @('legacy ensure') },
        @{ Id = 'windows-exploit-protection'; StateCommands = @('exploit ensure'); Modules = @('ExploitProtection'); FeatureSpec = 'specs/012-other' }
    )
    $files = @('spec.md', 'plan.md', 'tasks.md', 'traceability.toml') | ForEach-Object { 'specs/012-other/' + $_ }
    $fixture = New-TestFixture -Capabilities $capabilities -Files $files -GateResults @{ 'specs/012-other' = $true; 'specs/011-exploit-protection' = $true }
    $result = Invoke-Fixture $fixture
    Assert-True (@($result.Failures | Where-Object Code -eq 'FeatureReferenceMismatch').Count -eq 1) 'paired module and route feature references must agree'
}

function Test-LegacyBoundary {
    $duplicate = New-TestFixture -LegacyModules @('LegacyModule', 'LegacyModule')
    $duplicateResult = Invoke-Fixture $duplicate
    Assert-True (@($duplicateResult.Failures | Where-Object Code -eq 'DuplicateLegacyIdentity').Count -eq 1) 'duplicate legacy module fails'
    $missing = New-TestFixture -LegacyModules @('MissingLegacyModule')
    $missingResult = Invoke-Fixture $missing
    Assert-True (@($missingResult.Failures | Where-Object Code -eq 'UnknownLegacyIdentity').Count -ge 1) 'unknown legacy identity fails'
}

function Test-LegacyFingerprint {
    $fixture = New-TestFixture
    $first = Invoke-Fixture $fixture
    $fixture.Configuration.LegacyBoundary.Modules = @('LegacyModule', 'AddedLegacyModule')
    $second = Invoke-Fixture $fixture
    Assert-True ($first.LegacyFingerprint.Valid) 'reviewed legacy fingerprint matches'
    Assert-True (-not $second.LegacyFingerprint.Valid -and @($second.Failures | Where-Object Code -eq 'LegacyFingerprintMismatch').Count -eq 1) 'legacy membership drift changes and fails the fingerprint'
}

function Test-NonMutation {
    $fixture = New-TestFixture
    $null = Invoke-Fixture $fixture
    Assert-True (@($script:adapterCalls | Where-Object { $_ -notlike 'TestFile:*' -and $_ -notlike 'InvokeFinalGate:*' }).Count -eq 0) 'evaluation adapter exposes only reads and final validation'
    $core = Get-Content -LiteralPath $corePath -Raw
    Assert-True ($core -notmatch 'Set-Content|Add-Content|Out-File|New-Item|Remove-Item|Move-Item|Copy-Item|git\s+(?:add|commit|reset)') 'core exposes no repository mutation commands'
    $public = Get-Content -LiteralPath $publicScriptPath -Raw
    Assert-True ($public -notmatch 'Set-Content|Add-Content|Out-File|New-Item|Remove-Item|Move-Item|Copy-Item|SPECIFY_FEATURE_DIRECTORY\s*=') 'public command exposes no repository or active-feature mutation'
}

function Test-PreCommitHook {
    $hook = Get-Content -LiteralPath (Join-Path $repositoryRoot '.pre-commit-config.yaml') -Raw
    Assert-True ($hook -match 'id:\s*spec-feature-governance') 'pre-commit declares a focused governance hook'
    Assert-True ($hook -match 'Test-SpecFeatureGovernance\.ps1' -and $hook -match 'pass_filenames:\s*false') 'hook invokes the human command without filenames'
}

function Test-DocumentationAndRouting {
    $capabilities = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\capabilities.psd1')
    $route = @($capabilities.Capabilities | Where-Object Id -eq 'spec-driven-development')[0]
    Assert-True (@($route.InspectCommands | Where-Object { $_ -match 'Test-SpecFeatureGovernance\.ps1' }).Count -ge 2) 'capability route publishes human and JSON commands'
    $documentation = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\spec-driven-development.md') -Raw
    $samples = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\sample-outputs.md') -Raw
    Assert-True ($documentation -match 'feature governance' -and $samples -match 'Spec feature governance') 'operator and sample documentation publish the guard'
}

function Test-UnrelatedDraft {
    $fixture = New-TestFixture -Files @(
        (@('spec.md', 'plan.md', 'tasks.md', 'traceability.toml') | ForEach-Object { 'specs/011-exploit-protection/' + $_ })
        'specs/010-unrelated/spec.md'
    )
    $result = Invoke-Fixture $fixture
    Assert-True $result.Compliant 'unreferenced draft does not affect compliance'
    Assert-True (@($script:adapterCalls | Where-Object { $_ -match '010-unrelated' }).Count -eq 0) 'unreferenced draft is never inspected or validated'
}

if (-not (Test-Path -LiteralPath $corePath -PathType Leaf)) {
    throw "Focused Spec feature governance core is missing: $corePath"
}
. $corePath

$sections = if ($Section -eq 'All') {
    @('HumanCommand', 'OutputParity', 'ModuleReference', 'StateRouteReference', 'PathBoundary',
        'RequiredArtifacts', 'FinalGate', 'ActionableFailure', 'PairedReference', 'LegacyBoundary',
        'LegacyFingerprint', 'NonMutation', 'PreCommitHook', 'DocumentationAndRouting', 'UnrelatedDraft')
} else {
    @($Section)
}

foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}
Write-Host "Spec feature governance tests passed ($script:assertions assertions)."
