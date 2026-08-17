[CmdletBinding()]
param(
    [ValidateSet('All', 'ConfigurationContract', 'CommandContract', 'BaseDeclaration',
        'LockReproducibility', 'RelativeBaseRelationship', 'NotebookEntryPoint',
        'KernelRegistryIsolation', 'OverlayIsolation', 'OverlayMutationIsolation',
        'OutputParity', 'ObservationalStatus', 'OpenBbExtensions', 'FailureAtomicity',
        'ReconciliationScope', 'UserContentPreservation', 'CredentialBoundary',
        'CapabilityRouting', 'RelocationNonMutation', 'RelocationPlanContract',
        'RelocationGuard', 'MovedRootRebuild', 'FocusedBoundary', 'PyXllDeclaration',
        'PyXllStatus', 'PyXllActivation', 'PyXllLicenseBoundary',
        'PyXllInteractivePlots', 'PyXllFailureAtomicity', 'PyXllJupyterRibbon')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('dws-quant-tests-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
. (Join-Path $PSScriptRoot 'helpers\QuantResearchTestSupport.ps1')

function New-SectionFixture {
    param([string] $Name)
    $root = Join-Path $temporaryRoot ($Name + '-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($root) | Out-Null
    New-QuantResearchFixture -Root $root
}

function Get-FixtureEnvironment {
    param([object] $Fixture, [string] $LogName)
    @{
        PATH = "$($Fixture.Bin);$env:PATH"
        QUANT_UV_LOG = Join-Path (Split-Path -Parent $Fixture.Root) $LogName
    }
}

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Assert-Equal {
    param($Expected, $Actual, [string] $Message)
    $script:assertions++
    if ($Expected -ne $Actual) { throw "Assertion failed: $Message (expected '$Expected', got '$Actual')" }
}

function Get-Source {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
    Get-Content -LiteralPath $path -Raw
}

function Get-PublicConfig {
    $path = Join-Path $repositoryRoot 'config\quant-research.psd1'
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) 'portable quantitative configuration exists'
    Import-PowerShellDataFile -LiteralPath $path
}

function Test-ConfigurationContract {
    $config = Get-PublicConfig
    Assert-Equal 1 $config.SchemaVersion 'configuration schema is version 1'
    Assert-Equal '3.12' $config.Python 'Python 3.12 is selected'
    Assert-Equal '.venv' $config.EnvironmentName 'generated environment has a conventional name'
    Assert-Equal 'quant-base' $config.Base.Name 'shared base has a stable name'
    Assert-Equal 'projects' $config.OverlayRoot 'overlay discovery is bounded to direct project children'
    Assert-True (-not [bool] $config.Relocation.ExecutionEnabled) 'relocation execution is disabled'
}

function Test-CommandContract {
    foreach ($path in @(
        'scripts/Set-QuantResearchEnvironmentState.ps1',
        'scripts/New-QuantResearchOverlay.ps1',
        'scripts/Start-QuantResearchNotebook.ps1',
        'scripts/Get-SourceRelocationPlan.ps1'
    )) {
        Assert-True ((Get-Source $path).Length -gt 0) "$path is a direct human command"
    }
    $state = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    foreach ($term in @('Test', 'Ensure', 'Reinitialize', 'Project', 'Json')) {
        Assert-True ($state -match [regex]::Escape($term)) "state command exposes $term"
    }
    $profileSource = Get-Source 'profile/QuantResearch.ps1'
    foreach ($name in @('quant-status', 'quant-sync', 'quant-rebuild', 'quant-overlay', 'quant-notebook', 'source-relocation-plan')) {
        Assert-True ($profileSource -match ('function global:' + [regex]::Escape($name))) "$name is a thin human wrapper"
    }
}

function Test-BaseDeclaration {
    $config = Get-PublicConfig
    foreach ($dependency in @('openbb', 'numpy', 'pandas', 'polars', 'pyarrow', 'scipy', 'statsmodels', 'duckdb')) {
        Assert-True ($dependency -in @($config.Base.RequiredDependencies)) "base declares $dependency"
    }
    $manifest = 'C:\Users\mariu\Source\quant-research\quant-base\pyproject.toml'
    if (Test-Path -LiteralPath $manifest -PathType Leaf) {
        $source = Get-Content -LiteralPath $manifest -Raw
        Assert-True ($source -match 'requires-python\s*=\s*">=3\.12"') 'existing base declares Python 3.12'
        Assert-True ($source -match 'openbb' -and $source -match 'build-backend\s*=\s*"uv_build"') 'existing base is an installable OpenBB project'
    }
}

function Test-LockReproducibility {
    $state = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    Assert-True ($state -match "'lock',\s*'--check'|lock --check") 'status verifies manifest/lock consistency'
    Assert-True ($state -match "'sync',\s*'--locked'|sync --locked") 'reconciliation restores reviewed lock state'
    foreach ($path in @(
        'C:\Users\mariu\Source\quant-research\quant-base\uv.lock',
        'C:\Users\mariu\Source\quant-research\projects\thesis\uv.lock'
    )) {
        if (Test-Path -LiteralPath (Split-Path -Parent $path)) {
            Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$path exists"
        }
    }
}

function Test-RelativeBaseRelationship {
    $config = Get-PublicConfig
    $thesis = @($config.RequiredOverlays | Where-Object Name -eq 'thesis')
    Assert-Equal 1 $thesis.Count 'thesis is a required overlay'
    Assert-Equal '../../quant-base' $thesis[0].BaseSource 'thesis base source is relative'
    $state = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    Assert-True ($state -match 'GetFullPath' -and $state -match 'StartsWith') 'resolved base source is constrained to the research root'
}

function Test-NotebookEntryPoint {
    $source = Get-Source 'scripts/Start-QuantResearchNotebook.ps1'
    Assert-True ($source -match "'run',\s*'--locked',\s*'--no-sync'" -or $source -match 'run --locked --no-sync') 'notebook uses locked no-sync execution'
    Assert-True ($source -match "'jupyter',\s*'lab'" -or $source -match 'jupyter lab') 'JupyterLab is the notebook entry point'
    Assert-True ($source -match 'ValueFromRemainingArguments|JupyterArguments') 'arguments are forwarded as an array'
}

function Test-KernelRegistryIsolation {
    $source = Get-Source 'scripts/Start-QuantResearchNotebook.ps1'
    Assert-True ($source -match 'GlobalKernelRoots|Kernel') 'kernel inventory is checked'
    Assert-True ($source -notmatch '(?i)kernelspec\s+install|kernel\s+install|ipython.+install') 'notebook workflow never registers a kernel'
}

function Test-OverlayIsolation {
    $source = (Get-Source 'scripts/New-QuantResearchOverlay.ps1') + "`n" + (Get-Source 'config/quant-research.psd1')
    foreach ($term in @('pyproject.toml', 'uv.lock', '.venv', '../../quant-base', 'editable')) {
        Assert-True ($source -match [regex]::Escape($term)) "overlay command preserves $term boundary"
    }
    Assert-True ($source -notmatch '(?i)uv\s+workspace|tool\.uv\.workspace') 'overlay command does not create a uv workspace'

    $fixture = New-SectionFixture 'overlay'
    $environment = Get-FixtureEnvironment $fixture 'uv-overlay.log'
    $command = Join-Path $repositoryRoot 'scripts\New-QuantResearchOverlay.ps1'
    $baseDigest = (Get-FileHash -LiteralPath (Join-Path $fixture.Base 'pyproject.toml') -Algorithm SHA256).Hash
    $plan = Invoke-TestPowerShellScript -Path $command -ArgumentList @('-Name', 'event-study', '-Dependency', 'polars', '-ConfigurationPath', $fixture.Config, '-Json') -Environment $environment
    Assert-Equal 0 $plan.ExitCode "overlay plan succeeds: $($plan.Text)"
    $destination = Join-Path $fixture.Root 'projects\event-study'
    Assert-True (-not (Test-Path -LiteralPath $destination)) 'overlay planning changes nothing'
    $created = Invoke-TestPowerShellScript -Path $command -ArgumentList @('-Name', 'event-study', '-Dependency', 'polars', '-ConfigurationPath', $fixture.Config, '-Run', '-Json') -Environment $environment
    Assert-Equal 0 $created.ExitCode "overlay creation succeeds: $($created.Text)"
    Assert-True ((Test-Path -LiteralPath (Join-Path $destination 'pyproject.toml')) -and (Test-Path -LiteralPath (Join-Path $destination 'uv.lock')) -and (Test-Path -LiteralPath (Join-Path $destination '.venv'))) 'overlay has independent declaration, lock, and environment'
    Assert-Equal $baseDigest (Get-FileHash -LiteralPath (Join-Path $fixture.Base 'pyproject.toml') -Algorithm SHA256).Hash 'overlay creation preserves base declaration'
}

function Test-OverlayMutationIsolation {
    $source = Get-Source 'scripts/New-QuantResearchOverlay.ps1'
    Assert-True ($source -match 'Get-FileHash|SHA256') 'existing declarations are fingerprinted'
    Assert-True ($source -match 'destination.*exist|already exists') 'existing destinations are refused'
    Assert-True ($source -match 'staging') 'new overlays are staged outside the destination'
}

function Test-OutputParity {
    $source = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    $schema = Get-Source 'specs/009-quant-research-environment/contracts/quant-research-status.schema.json' | ConvertFrom-Json
    Assert-True ($source -match 'ConvertTo-Json') 'machine output is explicit JSON'
    Assert-True ($source -match 'Write-Host|Format-') 'human output is the default'
    foreach ($field in @($schema.required)) {
        Assert-True ($source -match [regex]::Escape($field)) "shared result contains $field"
    }
}

function Test-ObservationalStatus {
    $source = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    foreach ($term in @('lock', '--check', 'sync', '--check', '--frozen', '--no-sync', 'PYTHONDONTWRITEBYTECODE', 'OPENBB_AUTO_BUILD')) {
        Assert-True ($source -match [regex]::Escape($term)) "status uses observational $term control"
    }
    $testBranch = [regex]::Match($source, '(?s)if\s*\(\$Mode\s+-eq\s*["'']Test["'']\).*?(?=\nforeach\s*\(\$definition)').Value
    Assert-True ($testBranch -notmatch 'openbb-build|--locked') 'Test branch does not reconcile or build'

    $fixture = New-SectionFixture 'status'
    $environment = Get-FixtureEnvironment $fixture 'uv-status.log'
    $before = Get-TestTreeDigest $fixture.Root
    $command = Join-Path $repositoryRoot 'scripts\Set-QuantResearchEnvironmentState.ps1'
    $result = Invoke-TestPowerShellScript -Path $command -ArgumentList @('-Mode', 'Test', '-Project', 'thesis', '-ConfigurationPath', $fixture.Config, '-Json') -Environment $environment
    Assert-Equal 0 $result.ExitCode "disposable observational status succeeds: $($result.Text)"
    $status = $result.Text | ConvertFrom-Json
    Assert-Equal 'compliant' $status.state 'disposable thesis is compliant'
    Assert-True (-not [bool] $status.mutationPerformed) 'status reports no mutation'
    Assert-Equal $before (Get-TestTreeDigest $fixture.Root) 'status leaves the complete research fixture unchanged'
}

function Test-OpenBbExtensions {
    $source = (Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1') + "`n" + (Get-Source 'config/quant-research.psd1')
    foreach ($term in @('openbb_core_extension', 'openbb_provider_extension', 'openbb_obbject_extension', 'reference.json', 'openbb-build')) {
        Assert-True ($source -match [regex]::Escape($term)) "OpenBB lifecycle covers $term"
    }
    Assert-True ($source -match 'OPENBB_AUTO_BUILD') 'OpenBB import probes suppress auto-build'
}

function Test-FailureAtomicity {
    $overlay = Get-Source 'scripts/New-QuantResearchOverlay.ps1'
    $state = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    Assert-True ($overlay -match 'staging' -and $overlay -match 'finally') 'overlay staging cleans up on failure'
    Assert-True ($state -match 'backup' -and $state -match 'Move-Item') 'environment replacement retains a backup transaction'
    Assert-True ($state -match 'catch' -and $state -match 'restore|restored') 'failed replacement restores the prior environment'

    $fixture = New-SectionFixture 'failure'
    $environment = Get-FixtureEnvironment $fixture 'uv-failure.log'
    $environment.QUANT_UV_FAIL_SYNC = '1'
    $sentinel = Join-Path $fixture.Thesis '.venv\sentinel.txt'
    Write-TestUtf8File $sentinel 'last-working-environment'
    $digest = (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
    $command = Join-Path $repositoryRoot 'scripts\Set-QuantResearchEnvironmentState.ps1'
    $result = Invoke-TestPowerShellScript -Path $command -ArgumentList @('-Mode', 'Reinitialize', '-Project', 'thesis', '-ConfigurationPath', $fixture.Config, '-Json') -Environment $environment
    Assert-True ($result.ExitCode -ne 0) 'failed locked sync returns nonzero'
    Assert-True (Test-Path -LiteralPath $sentinel -PathType Leaf) 'failed replacement restores the prior environment'
    Assert-Equal $digest (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash 'restored environment identity is unchanged'
}

function Test-ReconciliationScope {
    $source = (Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1') + "`n" + (Get-Source 'config/quant-research.psd1')
    Assert-True ($source -match [regex]::Escape('.venv')) 'generated environment is the replacement boundary'
    Assert-True ($source -match "'sync',\s*'--locked'|sync --locked") 'reconciliation uses the reviewed lock'
    Assert-True ($source -notmatch '(?i)uv\s+(add|remove)|lock\s+--upgrade') 'reconciliation never changes dependency declarations'
}

function Test-UserContentPreservation {
    $config = Get-PublicConfig
    foreach ($pattern in @('*.ipynb', '*.csv', '.env*', 'data', 'exports')) {
        Assert-True ($pattern -in @($config.ProtectedPatterns)) "protected patterns include $pattern"
    }
    $source = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    $removeLines = @($source -split "`r?`n" | Where-Object { $_ -match 'Remove-Item' })
    Assert-True (@($removeLines | Where-Object { $_ -notmatch '\$(environment|backup)' }).Count -eq 0) 'reconciliation deletes only validated generated environment paths'
}

function Test-CredentialBoundary {
    $source = Get-Source 'config/quant-research.psd1'
    Assert-True ($source -match '%USERPROFILE%') 'public root remains portable'
    Assert-True ($source -notmatch '(?i)(api[_-]?key|token|secret)\s*=\s*[''"][^''"]+[''"]') 'public configuration contains no credential value'
    Assert-True ($source -match 'ProtectedPatterns') 'credential/data patterns are explicitly outside ownership'
}

function Test-CapabilityRouting {
    $catalog = Get-Source 'config/capabilities.psd1'
    Assert-True ($catalog -match "Id\s*=\s*'quant-research-environment'") 'focused capability is registered'
    foreach ($command in @('quant-status', 'quant-sync', 'quant-overlay', 'quant-notebook', 'source-relocation-plan')) {
        Assert-True ($catalog -match [regex]::Escape($command)) "capability routes $command"
    }
    $apply = Get-Source 'Apply-Workstation.ps1'
    Assert-True ($apply -match 'QuantResearchEnvironment') 'top-level desired-state dispatcher exposes the module'
}

function Test-RelocationNonMutation {
    $source = Get-Source 'scripts/Get-SourceRelocationPlan.ps1'
    foreach ($term in @('planOnly', 'executionAvailable', 'authorized', 'mutationPerformed')) {
        Assert-True ($source -match [regex]::Escape($term)) "relocation result contains $term"
    }
    Assert-True ($source -match 'executionAvailable\s*=\s*\$false') 'relocation execution is unavailable'
    Assert-True ($source -match 'mutationPerformed\s*=\s*\$false') 'plan reports no mutation'
}

function Test-RelocationPlanContract {
    $source = Get-Source 'scripts/Get-SourceRelocationPlan.ps1'
    $schema = Get-Source 'specs/009-quant-research-environment/contracts/source-relocation-plan.schema.json' | ConvertFrom-Json
    foreach ($field in @($schema.required)) {
        Assert-True ($source -match [regex]::Escape($field)) "relocation plan contains $field"
    }
    Assert-True ($source -match 'ConvertTo-Json' -and $source -match 'Write-Host') 'relocation plan has JSON and human renderers'

    $fixture = New-SectionFixture 'relocation'
    $target = Join-Path (Split-Path -Parent $fixture.Root) 'relocated'
    $before = Get-TestTreeDigest $fixture.Root
    $command = Join-Path $repositoryRoot 'scripts\Get-SourceRelocationPlan.ps1'
    $planResult = Invoke-TestPowerShellScript -Path $command -ArgumentList @('-Source', $fixture.Root, '-Target', $target, '-ConfigurationPath', $fixture.Config, '-Json')
    Assert-Equal 0 $planResult.ExitCode "suitable disposable relocation plan succeeds: $($planResult.Text)"
    $plan = $planResult.Text | ConvertFrom-Json
    Assert-True ($plan.planOnly -and -not $plan.executionAvailable -and -not $plan.authorized -and -not $plan.mutationPerformed) 'relocation constants prohibit execution'
    Assert-Equal $before (Get-TestTreeDigest $fixture.Root) 'relocation planning leaves source unchanged'
    Assert-True (-not (Test-Path -LiteralPath $target)) 'relocation planning does not create target'
    $schemaText = Get-Source 'specs/009-quant-research-environment/contracts/source-relocation-plan.schema.json'
    Assert-True ($planResult.Text | Test-Json -Schema $schemaText) 'relocation JSON conforms to its schema'
}

function Test-RelocationGuard {
    $source = (Get-Source 'scripts/Get-SourceRelocationPlan.ps1') + "`n" + (Get-Source 'config/quant-research.psd1')
    foreach ($term in @('NTFS', 'DriveType', 'ReparsePoint', 'Encrypted', '/L', 'blockers')) {
        Assert-True ($source -match [regex]::Escape($term)) "relocation gate covers $term"
    }
    Assert-True ($source -notmatch 'New-Item\s+-ItemType\s+Junction|&\s*mklink|Start-Process.+robocopy') 'no relocation executor is present'
}

function Test-MovedRootRebuild {
    $source = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    Assert-True ($source -match "Project.+All|All.+Project") 'all projects can be selected for rebuild'
    Assert-True ($source -match 'Reinitialize') 'generated environments can be recreated'
    Assert-True ($source -match 'GetFullPath' -and $source -match '--locked') 'moved roots are path-checked and restored from locks'

    $fixture = New-SectionFixture 'moved'
    $oldRoot = [IO.Path]::GetFullPath($fixture.Root)
    $oldEnvironment = [IO.Path]::GetFullPath((Join-Path $fixture.Thesis '.venv'))
    Assert-True ($oldEnvironment.StartsWith($oldRoot, [StringComparison]::OrdinalIgnoreCase)) 'fixture environment is contained before removal'
    [IO.Directory]::Delete($oldEnvironment, $true)
    $movedRoot = Join-Path (Split-Path -Parent $oldRoot) 'moved-research'
    Move-Item -LiteralPath $oldRoot -Destination $movedRoot
    $configText = (Get-Content -LiteralPath $fixture.Config -Raw).Replace($oldRoot, $movedRoot)
    [IO.File]::WriteAllText($fixture.Config, $configText, [Text.UTF8Encoding]::new($false))
    $environment = Get-FixtureEnvironment $fixture 'uv-moved.log'
    $command = Join-Path $repositoryRoot 'scripts\Set-QuantResearchEnvironmentState.ps1'
    $result = Invoke-TestPowerShellScript -Path $command -ArgumentList @('-Mode', 'Reinitialize', '-Project', 'All', '-ConfigurationPath', $fixture.Config, '-Json') -Environment $environment
    Assert-Equal 0 $result.ExitCode "moved root rebuild succeeds: $($result.Text)"
    Assert-True ((Test-Path -LiteralPath (Join-Path $movedRoot 'quant-base\.venv')) -and (Test-Path -LiteralPath (Join-Path $movedRoot 'projects\thesis\.venv'))) 'all generated environments are recreated'
    Assert-True ((Get-Content -LiteralPath (Join-Path $movedRoot 'projects\thesis\pyproject.toml') -Raw) -match '\.\./\.\./quant-base') 'moved overlay keeps the relative base source'
}

function Test-FocusedBoundary {
    $catalog = Get-Source 'config/workstation-modules.psd1'
    $moduleMatches = [regex]::Matches($catalog, "Name\s*=\s*'QuantResearchEnvironment'")
    Assert-Equal 1 $moduleMatches.Count 'one focused desired-state module exists'
    $entry = [regex]::Match($catalog, "(?s)@\{\s*Name\s*=\s*'QuantResearchEnvironment'.*?\n\s*\}").Value
    Assert-True ($entry -match 'Default\s*=\s*\$false') 'module is opt-in'
    Assert-True ($entry -match 'Privileged\s*=\s*\$false' -and $entry -match 'Destructive\s*=\s*\$false') 'module is non-privileged and non-destructive'
}

function Test-PyXllDeclaration {
    $config = Get-PublicConfig
    foreach ($dependency in @('pyxll', 'plotly', 'kaleido')) {
        Assert-True ($dependency -in @($config.Base.RequiredDependencies)) "base declares $dependency"
    }
    Assert-True ([bool] $config.PyXLL.Enabled) 'PyXLL integration is explicitly enabled in quant desired state'
    Assert-Equal '5.12.4' ([string] $config.PyXLL.Version) 'the reviewed PyXLL version is exact'

    $manifest = Join-Path ([Environment]::ExpandEnvironmentVariables($config.Root)) 'quant-base\pyproject.toml'
    if (Test-Path -LiteralPath $manifest -PathType Leaf) {
        $manifestText = Get-Content -LiteralPath $manifest -Raw
        foreach ($dependency in @('pyxll', 'plotly', 'kaleido')) {
            Assert-True ($manifestText -match ('(?i)' + [regex]::Escape($dependency))) "live base declares $dependency"
        }
    }
}

function Test-PyXllStatus {
    $state = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    $core = Get-Source 'scripts/PyXll.Core.ps1'
    foreach ($term in @('pyxll-package', 'pyxll-architecture', 'pyxll-addin', 'pyxll-config', 'pyxll-webview2', 'pyxll-license')) {
        Assert-True (($state + $core) -match [regex]::Escape($term)) "PyXLL status reports $term"
    }
    Assert-True (($state + $core) -match 'Get-ItemProperty' -and ($state + $core) -match 'OPEN') 'Excel add-in registration is observed'
    Assert-True (($state + $core) -match 'WebView2') 'WebView2 availability is observed'
}

function Test-PyXllActivation {
    $state = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    Assert-True ($state -match 'ConfirmPyXllInstall') 'first install requires a dedicated confirmation switch'
    Assert-True ($state -match "'pyxll',\s*'install'|pyxll install") 'confirmed first install uses the official module command'
    Assert-True ($state -match "'pyxll',\s*'activate',\s*'--non-interactive'|pyxll activate --non-interactive") 'an existing payload is activated non-interactively'
    Assert-True ($state -match 'Get-Process.+EXCEL|EXCEL.+Get-Process') 'activation refuses a running Excel process'
}

function Test-PyXllLicenseBoundary {
    $ignore = Get-Source '.gitignore'
    $sample = Get-Source '.licenses.yaml.sample'
    $corePath = Join-Path $repositoryRoot 'scripts\PyXll.Core.ps1'
    Assert-True ($ignore -match '(?m)^\.licenses\.yaml$') 'the local license store is ignored'
    Assert-True ($sample -match '(?m)^\s*key:\s*$') 'the tracked sample contains an empty key'
    Assert-True ($sample -notmatch '(?i)[a-f0-9]{32,}') 'the tracked sample contains no key-like value'
    Assert-True (Test-Path -LiteralPath $corePath -PathType Leaf) 'the focused PyXLL core exists'

    . $corePath
    $fixture = Join-Path $temporaryRoot ('pyxll-license-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($fixture) | Out-Null
    $licensePath = Join-Path $fixture '.licenses.yaml'
    $dummyKey = 'fixture-' + [guid]::NewGuid().ToString('N')
    Write-TestUtf8File $licensePath "schema_version: 1`npyxll:`n  key: $dummyKey`n"
    $parsed = Get-PyXllLicenseKey -Path $licensePath
    Assert-Equal $dummyKey $parsed 'bounded local license parser returns the fixture value'
    $rendered = Merge-PyXllConfiguration -ExistingText "[PYXLL]`nlog_level = info`n[LICENSE]`nkey = old`n" -PythonExecutable 'X:\base\.venv\Scripts\pythonw.exe' -WebView2UserDataFolder 'X:\local\webview2' -LicenseKey $parsed
    Assert-True ($rendered.EndsWith("[LICENSE]`r`nkey = $dummyKey`r`n")) 'license is the final configuration section'
    Assert-Equal 1 ([regex]::Matches($rendered, '(?m)^\[LICENSE\]\r?$').Count) 'configuration contains one license section'

    $tracked = @(git -C $repositoryRoot ls-files | ForEach-Object { Join-Path $repositoryRoot $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    foreach ($path in $tracked) {
        Assert-True ((Get-Content -LiteralPath $path -Raw) -notmatch [regex]::Escape($dummyKey)) "fixture key is absent from tracked $path"
    }
}

function Test-PyXllInteractivePlots {
    $config = Get-PublicConfig
    Assert-True ([bool] $config.PyXLL.Plotting.AllowHtml) 'interactive HTML plots are enabled'
    Assert-True ([bool] $config.PyXLL.Plotting.AllowSvg) 'SVG plots are enabled'
    Assert-True ([bool] $config.PyXLL.Plotting.AllowResize) 'plot resizing is enabled'
    Assert-True ([string] $config.PyXLL.Plotting.WebView2UserDataFolder -match '%LOCALAPPDATA%') 'WebView2 data remains machine-local'

    $corePath = Join-Path $repositoryRoot 'scripts\PyXll.Core.ps1'
    Assert-True (Test-Path -LiteralPath $corePath -PathType Leaf) 'the focused PyXLL core exists'
    . $corePath
    $rendered = Merge-PyXllConfiguration -ExistingText "[PYXLL]`nlog_level = info`n" -PythonExecutable 'X:\base\.venv\Scripts\pythonw.exe' -WebView2UserDataFolder 'X:\local\webview2' -LicenseKey 'fixture-key'
    foreach ($setting in @('plot_allow_html = 1', 'plot_allow_svg = 1', 'plot_allow_resize = 1', 'webview2_userdata_folder = X:\local\webview2')) {
        Assert-True ($rendered -match [regex]::Escape($setting)) "rendered config contains $setting"
    }
    Assert-True ($rendered -match 'log_level = info') 'unmanaged PyXLL settings are preserved'
}

function Test-PyXllFailureAtomicity {
    $state = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    $core = Get-Source 'scripts/PyXll.Core.ps1'
    foreach ($term in @('license', 'architecture', 'WebView2', 'EXCEL', 'temporary', 'Move-Item')) {
        Assert-True (($state + $core) -match [regex]::Escape($term)) "PyXLL prerequisite/transaction covers $term"
    }
    Assert-True (($state + $core) -notmatch '(?i)Write-(Host|Output|Verbose|Debug|Warning).*(LicenseKey|license\.key)') 'license value is never passed to output commands'
}

function Test-PyXllJupyterRibbon {
    $config = Get-PublicConfig
    foreach ($dependency in @('pyxll-jupyter', 'jupyterlab')) {
        Assert-True ($dependency -in @($config.Base.RequiredDependencies)) "base declares $dependency"
    }
    Assert-Equal '0.7.1' ([string] $config.PyXLL.Jupyter.Version) 'the PyXLL Jupyter integration version is exact'
    Assert-Equal 'lab' ([string] $config.PyXLL.Jupyter.Subcommand) 'JupyterLab is the embedded interface'
    Assert-Equal 'Explicit' ([string] $config.PyXLL.Jupyter.RibbonMode) 'the packaged Jupyter ribbon is loaded explicitly for deterministic startup'
    Assert-True ([bool] $config.PyXLL.Jupyter.UseWorkbookDirectory) 'saved workbooks select their own notebook directory'

    $corePath = Join-Path $repositoryRoot 'scripts\PyXll.Core.ps1'
    . $corePath
    $jupyter = [ordered]@{
        use_workbook_dir = '1'
        notebook_dir = 'X:\quant-research'
        subcommand = 'lab'
        qt = 'PySide6'
        timeout = '60'
        disable_ribbon = '1'
    }
    $rendered = Merge-PyXllConfiguration -ExistingText "[PYXLL]`nmodules = pyxll_jupyter.pyxll`n    misc`nribbon = X:\base\.venv\Lib\site-packages\pyxll_jupyter\resources\ribbon.xml`n    ./examples/ribbon/ribbon.xml`nlog_level = info`n" -PythonExecutable 'X:\base\.venv\Scripts\pythonw.exe' -WebView2UserDataFolder 'X:\local\webview2' -LicenseKey 'fixture-key' -JupyterSettings $jupyter -JupyterRibbonPath 'X:\base\.venv\Lib\site-packages\pyxll_jupyter\resources\ribbon.xml' -UseExplicitJupyterRibbon
    foreach ($setting in @('[JUPYTER]', 'use_workbook_dir = 1', 'notebook_dir = X:\quant-research', 'subcommand = lab', 'qt = PySide6', 'timeout = 60', 'disable_ribbon = 1')) {
        Assert-True ($rendered -match [regex]::Escape($setting)) "rendered config contains $setting"
    }
    Assert-True ($rendered.IndexOf('[JUPYTER]') -lt $rendered.IndexOf('[LICENSE]')) 'Jupyter configuration precedes the terminal license section'
    Assert-True ($rendered -match '(?m)^modules = misc\r?$') 'unrelated example modules remain configured'
    Assert-True ($rendered -notmatch 'pyxll_jupyter\.pyxll') 'the Jupyter callback module is loaded only through its package entry point'
    Assert-Equal 1 ([regex]::Matches($rendered, [regex]::Escape('X:\base\.venv\Lib\site-packages\pyxll_jupyter\resources\ribbon.xml')).Count) 'the packaged Jupyter ribbon is configured exactly once'
    Assert-True ($rendered -notmatch '(?i)examples[/\\]ribbon[/\\]ribbon\.xml') 'the example ribbon cannot take ownership of the shared PyXLL tab id'
    Assert-True ($rendered -notmatch '(?im)^\s*ribbon\s*=\s*$') 'an empty ribbon setting cannot produce a PyXLL startup warning'

    $state = Get-Source 'scripts/Set-QuantResearchEnvironmentState.ps1'
    foreach ($check in @('pyxll-jupyter-package', 'pyxll-jupyterlab', 'pyxll-jupyter-ribbon', 'pyxll-jupyter-config')) {
        Assert-True ($state -match [regex]::Escape($check)) "status includes $check"
    }
}

$sections = [ordered]@{
    ConfigurationContract = ${function:Test-ConfigurationContract}
    CommandContract = ${function:Test-CommandContract}
    BaseDeclaration = ${function:Test-BaseDeclaration}
    LockReproducibility = ${function:Test-LockReproducibility}
    RelativeBaseRelationship = ${function:Test-RelativeBaseRelationship}
    NotebookEntryPoint = ${function:Test-NotebookEntryPoint}
    KernelRegistryIsolation = ${function:Test-KernelRegistryIsolation}
    OverlayIsolation = ${function:Test-OverlayIsolation}
    OverlayMutationIsolation = ${function:Test-OverlayMutationIsolation}
    OutputParity = ${function:Test-OutputParity}
    ObservationalStatus = ${function:Test-ObservationalStatus}
    OpenBbExtensions = ${function:Test-OpenBbExtensions}
    FailureAtomicity = ${function:Test-FailureAtomicity}
    ReconciliationScope = ${function:Test-ReconciliationScope}
    UserContentPreservation = ${function:Test-UserContentPreservation}
    CredentialBoundary = ${function:Test-CredentialBoundary}
    CapabilityRouting = ${function:Test-CapabilityRouting}
    RelocationNonMutation = ${function:Test-RelocationNonMutation}
    RelocationPlanContract = ${function:Test-RelocationPlanContract}
    RelocationGuard = ${function:Test-RelocationGuard}
    MovedRootRebuild = ${function:Test-MovedRootRebuild}
    FocusedBoundary = ${function:Test-FocusedBoundary}
    PyXllDeclaration = ${function:Test-PyXllDeclaration}
    PyXllStatus = ${function:Test-PyXllStatus}
    PyXllActivation = ${function:Test-PyXllActivation}
    PyXllLicenseBoundary = ${function:Test-PyXllLicenseBoundary}
    PyXllInteractivePlots = ${function:Test-PyXllInteractivePlots}
    PyXllFailureAtomicity = ${function:Test-PyXllFailureAtomicity}
    PyXllJupyterRibbon = ${function:Test-PyXllJupyterRibbon}
}

$selected = if ($Section -eq 'All') { @($sections.Keys) } else { @($Section) }
try {
    foreach ($name in $selected) {
        & $sections[$name]
        Write-Host "PASS $name"
    }
    Write-Host "Quantitative research environment tests passed: $script:assertions assertions."
} finally {
    $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
    $systemTemporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemporaryRoot.StartsWith($systemTemporaryRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTemporaryRoot -PathType Container)) {
        [IO.Directory]::Delete($resolvedTemporaryRoot, $true)
    }
}
