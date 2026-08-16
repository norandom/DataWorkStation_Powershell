[CmdletBinding()]
param(
    [ValidateSet('All', 'StateContract', 'RunnerContract', 'JsonContract', 'FailureContract', 'ParallelContract', 'CompatibilityContract', 'Adapters', 'CommandSurface')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-Source {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$RelativePath exists"
    Get-Content -LiteralPath $path -Raw
}

function Test-StateContract {
    $configurationPath = Join-Path $repositoryRoot 'config\pester.psd1'
    Assert-True (Test-Path -LiteralPath $configurationPath -PathType Leaf) 'focused Pester configuration exists'
    $configuration = Import-PowerShellDataFile $configurationPath
    Assert-True ($configuration.Version -eq '6.1.0') 'Pester is pinned to 6.1.0'
    Assert-True ($configuration.Repository -eq 'PSGallery') 'the official gallery is declared'
    Assert-True ($configuration.ModuleBase -match 'WindowsPowerShell') 'the shared per-user module tree is selected'
    $state = Get-Source 'scripts/Set-PesterState.ps1'
    Assert-True ($state -match 'if \(\$Mode -eq ''Test''\)') 'Test has an observational branch'
    Assert-True ($state -match 'Save-PSResource') 'Ensure uses PSResourceGet explicitly'
    Assert-True ($state -match 'PowerShell7Version' -and $state -match 'WindowsPowerShellVersion') 'both runtime resolutions are reported'
    Assert-True ($state -match 'ConvertTo-Json') 'state supports machine output'
}

function Test-RunnerContract {
    $runner = Get-Source 'scripts/Invoke-PowerShellTests.ps1'
    Assert-True ($runner -match 'Import-Module Pester.*RequiredVersion') 'runner imports the declared exact version'
    Assert-True ($runner -match 'New-PesterConfiguration') 'runner uses one Pester configuration'
    Assert-True ($runner -match 'Invoke-Pester -Configuration') 'runner uses one aggregate framework invocation'
    Assert-True ($runner -notmatch 'Install-PSResource|Save-PSResource|Install-Module') 'runner never repairs its dependency'
    Assert-True ($runner -match 'Run\.Path') 'runner configures file-based discovery'
}

function Test-JsonContract {
    $runner = Get-Source 'scripts/Invoke-PowerShellTests.ps1'
    foreach ($field in @('SchemaVersion', 'Status', 'Runtime', 'FrameworkVersion', 'Parallel', 'ThrottleLimit', 'TotalCount', 'PassedCount', 'FailedCount', 'SkippedCount', 'DurationMilliseconds', 'Failures')) {
        Assert-True ($runner -match $field) "JSON summary declares $field"
    }
    Assert-True ($runner -match 'ConvertTo-Json') 'runner serializes machine output'
}

function Test-FailureContract {
    $runner = Get-Source 'scripts/Invoke-PowerShellTests.ps1'
    Assert-True ($runner -match 'FailedCount') 'runner inspects aggregate failures'
    Assert-True ($runner -match 'exit 1') 'runner returns nonzero for failed tests'
    Assert-True ($runner -match 'FailureMessageLimit') 'failure records are bounded'
}

function Test-ParallelContract {
    $runner = Get-Source 'scripts/Invoke-PowerShellTests.ps1'
    Assert-True ($runner -match 'Run\.Parallel') 'modern lane enables framework parallelism'
    Assert-True ($runner -match 'ParallelThrottleLimit') 'parallelism has an explicit throttle'
    Assert-True ($runner -match 'ValidateRange[\s\S]*ThrottleLimit') 'the operator throttle is bounded'
    Assert-True ($runner -match 'PSVersion.*7\.4|Version.*7, 4') 'parallelism requires the supported runtime'
    $exclusive = Get-Source 'tests/pester/PowerShellTesting.Exclusive.Tests.ps1'
    Assert-True ($exclusive -match '#pester:no-parallel') 'exclusive tests use the framework directive'
}

function Test-CompatibilityContract {
    $runner = Get-Source 'scripts/Invoke-PowerShellTests.ps1'
    Assert-True ($runner -match 'Compatibility') 'runner exposes a compatibility lane'
    Assert-True ($runner -match 'powershell\.exe') 'compatibility dispatch uses inbox Windows PowerShell'
    Assert-True ($runner -match 'Parallel.*false|Parallel\s*=\s*\$false') 'compatibility lane is sequential'
    Assert-True ($runner -match 'FallbackReason') 'sequential fallback is reported'
}

function Test-Adapters {
    $adapters = @(
        @{ Path = 'tests/pester/WorkstationBaseline.Tests.ps1'; Script = 'Test-WorkstationBaseline.ps1'; Section = 'BootstrapStages' },
        @{ Path = 'tests/pester/RootlessPodman.Tests.ps1'; Script = 'Test-RootlessDockerState.ps1'; Section = 'PodmanState' },
        @{ Path = 'tests/pester/MalwareAnalysis.Tests.ps1'; Script = 'Test-MalwareAnalysis.ps1'; Section = 'RootlessContainer' },
        @{ Path = 'tests/pester/MalwareContainerAnalysis.Tests.ps1'; Script = 'Test-MalwareContainerAnalysis.ps1'; Section = 'Planning' }
        @{ Path = 'tests/pester/NativeDevelopment.Tests.ps1'; Script = 'Test-NativeDevelopmentState.ps1'; Section = 'JavaContract' }
        @{ Path = 'tests/pester/WorkstationUpdate.Tests.ps1'; Script = 'Test-WorkstationUpdate.ps1'; Section = 'PlanContract' }
        @{ Path = 'tests/pester/AnalysisDifferencing.Tests.ps1'; Script = 'Test-AnalysisDifferencing.ps1'; Section = 'GraphArtifacts' }
        @{ Path = 'tests/pester/NativeForensicVerification.Tests.ps1'; Script = 'Test-NativeForensicVerification.ps1'; Section = 'ReportContract' }
        @{ Path = 'tests/pester/AutopsyState.Tests.ps1'; Script = 'Test-AutopsyState.ps1'; Section = 'CatalogContract' }
        @{ Path = 'tests/pester/QuantResearchEnvironment.Tests.ps1'; Script = 'Test-QuantResearchEnvironment.ps1'; Section = 'ObservationalStatus' }
    )
    foreach ($adapter in $adapters) {
        $source = Get-Source $adapter.Path
        Assert-True ($source -match 'Describe' -and $source -match 'It ') "$($adapter.Path) is a standard test file"
        Assert-True ($source -match [regex]::Escape($adapter.Script)) "$($adapter.Path) retains its section runner"
        Assert-True ($source -match [regex]::Escape($adapter.Section)) "$($adapter.Path) retains traceable selectors"
    }
}

function Test-CommandSurface {
    $aliases = Get-Source 'profile/Aliases.ps1'
    Assert-True ($aliases -match 'function global:test-powershell') 'human test command is exposed'
    $capabilities = Get-Source 'config/capabilities.psd1'
    Assert-True ($capabilities -match 'Invoke-PowerShellTests\.ps1') 'capability catalog routes the test command'
    $catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $module = @($catalog.Modules | Where-Object Name -eq 'PowerShellTesting')
    Assert-True ($module.Count -eq 1 -and $module[0].Default) 'PowerShellTesting is a default focused module'
    Assert-True ($module[0].DependsOn -contains 'PowerShell7') 'PowerShellTesting depends on PowerShell 7'
}

$sections = if ($Section -eq 'All') {
    @('StateContract', 'RunnerContract', 'JsonContract', 'FailureContract', 'ParallelContract', 'CompatibilityContract', 'Adapters', 'CommandSurface')
} else { @($Section) }

foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}

Write-Host "PowerShell testing contract tests passed ($script:assertions assertions)."
