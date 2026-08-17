[CmdletBinding()]
param(
    [ValidateSet('All', 'HarnessSelfTest', 'Modules', 'ModulePlanning', 'PlanSafety', 'StateSafety', 'WindowsSafety', 'DebloatSafety', 'Capabilities', 'TrickyOutput', 'DiagnosticSkills', 'Contour', 'DeveloperTools', 'SpecDrivenDevelopment', 'DeveloperEnvironment', 'Documentation', 'PublicationGates', 'SpecificationWorkflow', 'SkillOptSafety', 'Governance', 'BootstrapStages', 'PowerShellRuntimes', 'WindowsTerminal')]
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

function Invoke-External {
    param([string] $FilePath, [string[]] $ArgumentList, [hashtable] $Environment)

    $previous = @{}
    if ($Environment) {
        foreach ($name in $Environment.Keys) {
            $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, [string] $Environment[$name], 'Process')
        }
    }
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = @(& $FilePath @ArgumentList 2>&1)
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    } finally {
        if ($Environment) {
            foreach ($name in $Environment.Keys) {
                [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
            }
        }
    }
}

function Get-BaselineModuleNames {
    $specPath = Join-Path $repositoryRoot 'specs\001-workstation-baseline\spec.md'
    $names = [Collections.Generic.List[string]]::new()
    $insideTable = $false
    foreach ($line in @(Get-Content -LiteralPath $specPath)) {
        if ($line -eq '## Module Coverage Baseline') {
            $insideTable = $true
            continue
        }
        if ($insideTable -and $line -match '^## ') { break }
        if ($insideTable -and $line -match '^\|\s*([A-Za-z0-9]+)\s*\|') {
            $name = $Matches[1]
            if ($name -ne 'Module') { $names.Add($name) }
        }
    }
    @($names)
}

function Get-BaselineCapabilityNames {
    $specPath = Join-Path $repositoryRoot 'specs\001-workstation-baseline\spec.md'
    $names = [Collections.Generic.List[string]]::new()
    $insideTable = $false
    foreach ($line in @(Get-Content -LiteralPath $specPath)) {
        if ($line -eq '## Capability Coverage Baseline') {
            $insideTable = $true
            continue
        }
        if ($insideTable -and $line -match '^## ') { break }
        if ($insideTable -and $line -match '^\|\s*([a-z0-9-]+)\s*\|') {
            $name = $Matches[1]
            if ($name -ne 'Capability' -and $name -notmatch '^-+$') { $names.Add($name) }
        }
    }
    @($names)
}

function Get-ScriptValidateSet {
    param([string] $Path, [string] $ParameterName)
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $errors)
    Assert-True ($errors.Count -eq 0) "'$Path' parses cleanly"
    $parameter = @($ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq $ParameterName })[0]
    Assert-True ($null -ne $parameter) "'$Path' declares parameter '$ParameterName'"
    if (-not $parameter) { return @() }
    $attribute = @($parameter.Attributes | Where-Object { $_.TypeName.FullName -eq 'ValidateSet' })[0]
    Assert-True ($null -ne $attribute) "'$ParameterName' in '$Path' has a ValidateSet"
    if (-not $attribute) { return @() }
    @($attribute.PositionalArguments | ForEach-Object { [string] $_.SafeGetValue() })
}

function Invoke-WorkstationPlan {
    param([string[]] $Modules = @('All'), [string] $Mode = 'Test')
    $runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') {
        Join-Path $PSHOME 'powershell.exe'
    } else {
        (Get-Command pwsh.exe -ErrorAction Stop).Source
    }
    $arguments = @('-NoLogo', '-NoProfile', '-File', (Join-Path $repositoryRoot 'Apply-Workstation.ps1'), '-Mode', $Mode, '-Module') + @($Modules) + @('-Plan', '-Json')
    $result = Invoke-External -FilePath $runtime -ArgumentList $arguments
    Assert-True ($result.ExitCode -eq 0) "workstation plan succeeds for '$($Modules -join ', ')': $($result.Output -join ' ')"
    if ($result.ExitCode -eq 0) {
        return (($result.Output -join [Environment]::NewLine) | ConvertFrom-Json)
    }
}

function Get-ExpectedModuleClosure {
    param([hashtable] $Catalog, [string[]] $Roots)
    $byName = @{}
    foreach ($module in @($Catalog.Modules)) { $byName[$module.Name] = $module }
    $stageByName = @{}
    foreach ($stage in @($Catalog.Stages)) { $stageByName[$stage.Name] = $stage }
    $included = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $pending = [Collections.Generic.Queue[string]]::new()
    foreach ($root in @($Roots)) {
        if ($included.Add($root)) { $pending.Enqueue($root) }
    }
    while ($pending.Count -gt 0) {
        $name = $pending.Dequeue()
        $module = $byName[$name]
        foreach ($dependency in @($module.DependsOn) + @($stageByName[$module.Stage].DependsOn)) {
            if ($included.Add($dependency)) { $pending.Enqueue($dependency) }
        }
    }
    @($included | Sort-Object)
}

function Assert-CatalogAcyclic {
    param([hashtable] $Catalog)
    $byName = @{}
    foreach ($module in @($Catalog.Modules)) { $byName[$module.Name] = $module }
    $stageByName = @{}
    foreach ($stage in @($Catalog.Stages)) { $stageByName[$stage.Name] = $stage }
    $remaining = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($module in @($Catalog.Modules)) { [void] $remaining.Add($module.Name) }
    $completed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    while ($remaining.Count -gt 0) {
        $ready = @($remaining | Where-Object {
            $module = $byName[$_]
            @(@($module.DependsOn) + @($stageByName[$module.Stage].DependsOn) | Where-Object { -not $completed.Contains($_) }).Count -eq 0
        })
        Assert-True ($ready.Count -gt 0) 'the complete workstation module graph is acyclic'
        if ($ready.Count -eq 0) { return }
        foreach ($name in $ready) {
            [void] $remaining.Remove($name)
            [void] $completed.Add($name)
        }
    }
    Assert-True ($completed.Count -eq @($Catalog.Modules).Count) 'the acyclic walk covers every workstation module'
}

function Test-HarnessSelfTest {
    $malformedCatalog = [pscustomobject]@{
        Stages = @([pscustomobject]@{ Name = 'Inbox' }, [pscustomobject]@{ Name = 'Inbox' })
    }
    $caught = $false
    try {
        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($stage in $malformedCatalog.Stages) {
            if (-not $names.Add($stage.Name)) { throw "Duplicate synthetic stage: $($stage.Name)" }
        }
    } catch { $caught = $_.Exception.Message -match 'Duplicate synthetic stage' }
    Assert-True $caught 'the harness rejects a deliberately malformed catalog fixture'

    $assertionCaught = $false
    try { Assert-True $false 'synthetic failure proves the harness rejects drift' } catch { $assertionCaught = $_.Exception.Message -match 'synthetic failure' }
    Assert-True $assertionCaught 'the harness returns a catchable nonzero assertion boundary'
}

function Test-Modules {
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $baselineNames = @(Get-BaselineModuleNames)
    $specText = Get-Content -LiteralPath (Join-Path $repositoryRoot 'specs\001-workstation-baseline\spec.md') -Raw
    Assert-True ($specText -match 'SC-001.*All\s+(\d+)\s+declared workstation modules') 'SC-001 declares the frozen module count'
    $declaredCount = [int] $Matches[1]
    Assert-True ($baselineNames.Count -eq $declaredCount) "the module baseline table contains its declared $declaredCount entries"

    $catalogNames = @($catalog.Modules.Name)
    Assert-True ($catalogNames.Count -eq $declaredCount) "the live catalog contains exactly the declared $declaredCount modules"
    Assert-True (@($catalogNames | Sort-Object -Unique).Count -eq $catalogNames.Count) 'workstation module names are unique'
    Assert-True (@(Compare-Object -ReferenceObject ($baselineNames | Sort-Object) -DifferenceObject ($catalogNames | Sort-Object)).Count -eq 0) 'the live catalog exactly matches the frozen module baseline'

    $requiredFields = @('Name', 'Order', 'Default', 'DependsOn', 'SupportedModes', 'Privileged', 'Destructive', 'Description', 'Stage', 'Runtime')
    foreach ($module in @($catalog.Modules)) {
        foreach ($field in $requiredFields) {
            Assert-True $module.ContainsKey($field) "module '$($module.Name)' declares '$field'"
        }
        Assert-True (-not [string]::IsNullOrWhiteSpace([string] $module.Name)) 'every module has a nonempty name'
        Assert-True ($module.Order -is [int]) "module '$($module.Name)' has an integer order"
        Assert-True ($module.Default -is [bool]) "module '$($module.Name)' has a Boolean default flag"
        Assert-True ($module.Privileged -is [bool]) "module '$($module.Name)' has a Boolean privilege flag"
        Assert-True ($module.Destructive -is [bool]) "module '$($module.Name)' has a Boolean destructive flag"
        Assert-True (@($module.SupportedModes).Count -gt 0 -and @($module.SupportedModes | Where-Object { $_ -notin @('Test', 'Ensure', 'Reinitialize') }).Count -eq 0) "module '$($module.Name)' declares supported modes"
        Assert-True (-not [string]::IsNullOrWhiteSpace([string] $module.Description)) "module '$($module.Name)' has a description"
    }

    $tokens = $null
    $errors = $null
    $applyAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repositoryRoot 'Apply-Workstation.ps1'), [ref] $tokens, [ref] $errors)
    Assert-True ($errors.Count -eq 0) 'the workstation orchestrator parses cleanly'
    $moduleParameter = @($applyAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Module' })[0]
    $validateSet = @($moduleParameter.Attributes | Where-Object { $_.TypeName.FullName -eq 'ValidateSet' })[0]
    $publicModules = @($validateSet.PositionalArguments | ForEach-Object { [string] $_.SafeGetValue() } | Where-Object { $_ -ne 'All' })
    Assert-True (@(Compare-Object -ReferenceObject ($catalogNames | Sort-Object) -DifferenceObject ($publicModules | Sort-Object)).Count -eq 0) 'every catalog module is selectable through the public orchestrator'
}

function Test-ModulePlanning {
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    Assert-CatalogAcyclic -Catalog $catalog

    $stageByName = @{}
    foreach ($stage in @($catalog.Stages)) { $stageByName[$stage.Name] = $stage }
    $fullPlan = Invoke-WorkstationPlan -Modules @('All')
    $previousStageOrder = [int]::MinValue
    foreach ($entry in @($fullPlan.ExecutionOrder)) {
        $stageOrder = [int] $stageByName[$entry.Stage].Order
        Assert-True ($stageOrder -ge $previousStageOrder) "full planning does not move backwards from a later stage to '$($entry.Stage)'"
        $previousStageOrder = $stageOrder
    }

    $roots = @('MalwareAnalysisTools')
    $plan = Invoke-WorkstationPlan -Modules $roots
    $repeat = Invoke-WorkstationPlan -Modules $roots
    $actualNames = @($plan.ExecutionOrder.Name)
    $expectedNames = @(Get-ExpectedModuleClosure -Catalog $catalog -Roots $roots)
    Assert-True (@(Compare-Object -ReferenceObject $expectedNames -DifferenceObject ($actualNames | Sort-Object)).Count -eq 0) 'focused planning contains exactly the transitive dependency closure'
    Assert-True (($actualNames -join '|') -eq (@($repeat.ExecutionOrder.Name) -join '|')) 'focused planning order is deterministic'

    $indexByName = @{}
    for ($index = 0; $index -lt $actualNames.Count; $index++) { $indexByName[$actualNames[$index]] = $index }
    foreach ($module in @($catalog.Modules | Where-Object { $indexByName.ContainsKey($_.Name) })) {
        foreach ($dependency in @($module.DependsOn) + @($stageByName[$module.Stage].DependsOn)) {
            Assert-True ($indexByName[$dependency] -lt $indexByName[$module.Name]) "dependency '$dependency' precedes '$($module.Name)'"
        }
    }

    foreach ($root in @('ContourTerminal', 'WindowsFeatures', 'Debloat', 'MsvcBuildTools')) {
        $privilegedPlan = Invoke-WorkstationPlan -Modules @($root)
        $names = @($privilegedPlan.ExecutionOrder.Name)
        Assert-True ($names -contains 'Sudo') "focused '$root' planning includes the Windows sudo prerequisite"
        Assert-True ([array]::IndexOf($names, 'Sudo') -lt [array]::IndexOf($names, $root)) "Sudo precedes '$root'"
    }
}

function Test-PlanSafety {
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $defaultRoots = @($catalog.Modules | Where-Object Default | ForEach-Object Name)
    $expectedDefault = @(Get-ExpectedModuleClosure -Catalog $catalog -Roots $defaultRoots)
    $plan = Invoke-WorkstationPlan -Modules @('All')
    $actualDefault = @($plan.ExecutionOrder.Name)
    Assert-True (@(Compare-Object -ReferenceObject $expectedDefault -DifferenceObject ($actualDefault | Sort-Object)).Count -eq 0) 'default planning contains only default roots and their dependencies'
    Assert-True ($actualDefault -notcontains 'Debloat') 'the destructive Debloat module is excluded from the default plan'

    foreach ($entry in @($plan.ExecutionOrder)) {
        foreach ($field in @('Stage', 'Runtime', 'Order', 'DependsOn', 'Privileged', 'Destructive', 'Description')) {
            Assert-True ($null -ne $entry.PSObject.Properties[$field]) "plan entry '$($entry.Name)' exposes '$field'"
        }
        Assert-True ($entry.Privileged -is [bool]) "plan entry '$($entry.Name)' exposes Boolean privilege risk"
        Assert-True ($entry.Destructive -is [bool]) "plan entry '$($entry.Name)' exposes Boolean destructive risk"
    }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('workstation-plan-safety-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'config') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts') -Force | Out-Null
    try {
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'Apply-Workstation.ps1') -Destination (Join-Path $tempRoot 'Apply-Workstation.ps1')
        $fixtureCatalog = @'
@{
    SchemaVersion = 2
    Stages = @(@{ Name = 'Inbox'; Order = 0; DependsOn = @(); Description = 'fixture' })
    Modules = @(@{ Name = 'Sudo'; Stage = 'Inbox'; Runtime = 'Inbox'; Order = 1; Default = $true; DependsOn = @(); SupportedModes = @('Test','Ensure','Reinitialize'); Privileged = $false; Destructive = $false; Description = 'sentinel' })
}
'@
        [IO.File]::WriteAllText((Join-Path $tempRoot 'config\workstation-modules.psd1'), $fixtureCatalog, [Text.UTF8Encoding]::new($false))
        $markerPath = Join-Path $tempRoot 'dispatch.marker'
        $sentinel = "[IO.File]::WriteAllText('$($markerPath.Replace("'", "''"))', 'dispatched')"
        [IO.File]::WriteAllText((Join-Path $tempRoot 'scripts\Set-SudoState.ps1'), $sentinel, [Text.UTF8Encoding]::new($false))
        $runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe -ErrorAction Stop).Source }
        $result = Invoke-External -FilePath $runtime -ArgumentList @('-NoLogo', '-NoProfile', '-File', (Join-Path $tempRoot 'Apply-Workstation.ps1'), '-Mode', 'Ensure', '-Module', 'Sudo', '-Plan', '-Json')
        Assert-True ($result.ExitCode -eq 0) "sentinel plan succeeds without dispatch: $($result.Output -join ' ')"
        Assert-True (-not (Test-Path -LiteralPath $markerPath)) 'plan mode does not invoke a resource script'
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction Ignore
    }
}

function Test-StateSafety {
    $applyPath = Join-Path $repositoryRoot 'Apply-Workstation.ps1'
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $modeValues = @(Get-ScriptValidateSet -Path $applyPath -ParameterName 'Mode')
    Assert-True (@(Compare-Object @('Ensure', 'Reinitialize', 'Test') ($modeValues | Sort-Object)).Count -eq 0) 'the orchestrator declares Test, Ensure, and Reinitialize'

    $resourceModes = @{
        WindowsFeatures = @{ Path = 'scripts\Set-WindowsFeatureState.ps1'; Expected = @('Plan', 'Test', 'Ensure', 'Reinitialize') }
        Hardening = @{ Path = 'scripts\Set-HardeningState.ps1'; Expected = @('Plan', 'Test', 'Ensure', 'Reinitialize') }
        ExploitProtection = @{ Path = 'scripts\Set-ExploitProtectionState.ps1'; Expected = @('Plan', 'Test', 'Ensure', 'Reinitialize') }
        Debloat = @{ Path = 'scripts\Set-DebloatState.ps1'; Expected = @('Plan', 'Test', 'Ensure') }
    }
    foreach ($name in $resourceModes.Keys) {
        $definition = $resourceModes[$name]
        $path = Join-Path $repositoryRoot $definition.Path
        $actual = @(Get-ScriptValidateSet -Path $path -ParameterName 'Mode')
        Assert-True (@(Compare-Object ($definition.Expected | Sort-Object) ($actual | Sort-Object)).Count -eq 0) "'$name' exposes only its declared resource modes"
        $catalogModule = @($catalog.Modules | Where-Object Name -eq $name)[0]
        $expectedCatalogModes = @($definition.Expected | Where-Object { $_ -ne 'Plan' } | Sort-Object)
        Assert-True (@(Compare-Object $expectedCatalogModes (@($catalogModule.SupportedModes) | Sort-Object)).Count -eq 0) "'$name' catalog modes match its resource"
    }

    $windowsSudoModules = @('ContourTerminal', 'Autopsy', 'WindowsFeatures', 'Hardening', 'ExploitProtection', 'MsvcBuildTools', 'DefenderExclusions', 'SmartScreen', 'Pagefile', 'EventLogs', 'Firewall', 'Debloat')
    foreach ($name in $windowsSudoModules) {
        $module = @($catalog.Modules | Where-Object Name -eq $name)[0]
        Assert-True ($module.DependsOn -contains 'Sudo') "Windows-elevated module '$name' has an explicit Sudo edge"
    }
    foreach ($module in @($catalog.Modules | Where-Object Destructive)) {
        Assert-True (-not $module.Default) "destructive module '$($module.Name)' is opt-in"
    }

    $featureSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-WindowsFeatureState.ps1') -Raw
    $hardeningSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-HardeningState.ps1') -Raw
    $exploitProtectionSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-ExploitProtectionState.ps1') -Raw
    $exploitProtectionTests = Get-Content -LiteralPath (Join-Path $repositoryRoot 'tests\Test-ExploitProtectionState.ps1') -Raw
    $debloatSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-DebloatState.ps1') -Raw
    Assert-True ($featureSource.IndexOf("if (`$Mode -eq 'Test')") -lt $featureSource.IndexOf('Enable-WindowsOptionalFeature')) 'Windows feature Test exits before mutation'
    Assert-True ($hardeningSource.IndexOf("if (`$Mode -eq 'Test')") -lt $hardeningSource.IndexOf('New-ItemProperty')) 'hardening Test exits before mutation'
    Assert-True ($exploitProtectionSource -match 'ExploitProtectionState\.Core\.ps1' -and $exploitProtectionTests -match 'function Test-TestMode') 'Exploit Protection delegates Test non-mutation to its focused transition suite'
    Assert-True ($debloatSource.IndexOf("if (`$Mode -eq 'Test')") -lt $debloatSource.IndexOf('Remove-AppxPackage')) 'debloat Test exits before mutation'
    Assert-True ($featureSource.IndexOf('$snapshotPath = Save-WindowsFeatureSnapshot') -ge 0 -and $featureSource.IndexOf('$snapshotPath = Save-WindowsFeatureSnapshot') -lt $featureSource.IndexOf('Enable-WindowsOptionalFeature')) 'Windows feature Reinitialize saves recovery evidence before mutation'
    Assert-True ($hardeningSource.IndexOf('$snapshotPath = Save-HardeningSnapshot') -ge 0 -and $hardeningSource.IndexOf('$snapshotPath = Save-HardeningSnapshot') -lt $hardeningSource.IndexOf('New-ItemProperty')) 'hardening Reinitialize saves recovery evidence before mutation'
    Assert-True ($exploitProtectionTests -match 'function Test-ReinitializeOrdering' -and $exploitProtectionTests -match 'function Test-SnapshotFailure') 'Exploit Protection delegates snapshot ordering and failure safety to its focused transition suite'

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('workstation-destructive-safety-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'config') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts') -Force | Out-Null
    try {
        Copy-Item -LiteralPath $applyPath -Destination (Join-Path $tempRoot 'Apply-Workstation.ps1')
        $fixtureCatalog = @'
@{
    SchemaVersion = 2
    Stages = @(@{ Name = 'Inbox'; Order = 0; DependsOn = @(); Description = 'fixture' })
    Modules = @(
        @{ Name = 'Sudo'; Stage = 'Inbox'; Runtime = 'Inbox'; Order = 1; Default = $false; DependsOn = @(); SupportedModes = @('Test','Ensure','Reinitialize'); Privileged = $false; Destructive = $false; Description = 'gate' }
        @{ Name = 'Debloat'; Stage = 'Inbox'; Runtime = 'Inbox'; Order = 2; Default = $false; DependsOn = @('Sudo'); SupportedModes = @('Test','Ensure'); Privileged = $true; Destructive = $true; Description = 'sentinel' }
        @{ Name = 'LegacyDockerCleanup'; Stage = 'Inbox'; Runtime = 'Inbox'; Order = 3; Default = $false; DependsOn = @(); SupportedModes = @('Test','Ensure'); Privileged = $false; Destructive = $true; Description = 'sentinel' }
    )
}
'@
        [IO.File]::WriteAllText((Join-Path $tempRoot 'config\workstation-modules.psd1'), $fixtureCatalog, [Text.UTF8Encoding]::new($false))
        $markerPath = Join-Path $tempRoot 'dispatch.marker'
        $sentinel = "[IO.File]::WriteAllText('$($markerPath.Replace("'", "''"))', 'dispatched')"
        foreach ($scriptName in @('Set-SudoState.ps1', 'Set-DebloatState.ps1', 'Remove-LegacyDockerMwState.ps1')) {
            [IO.File]::WriteAllText((Join-Path $tempRoot "scripts\$scriptName"), $sentinel, [Text.UTF8Encoding]::new($false))
        }
        $runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe -ErrorAction Stop).Source }
        foreach ($name in @('Debloat', 'LegacyDockerCleanup')) {
            $result = Invoke-External -FilePath $runtime -ArgumentList @('-NoLogo', '-NoProfile', '-File', (Join-Path $tempRoot 'Apply-Workstation.ps1'), '-Mode', 'Ensure', '-Module', $name)
            Assert-True ($result.ExitCode -ne 0) "destructive '$name' refuses Ensure without confirmation"
            Assert-True (-not (Test-Path -LiteralPath $markerPath)) "destructive '$name' refusal occurs before any resource dispatch"
        }
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction Ignore
    }
}

function Test-WindowsSafety {
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $features = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\windows-features.psd1')
    $hardening = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\hardening-profiles.psd1')
    $exploitProtection = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\exploit-protection.psd1')
    $featureById = @{}
    foreach ($feature in @($features.WindowsOptionalFeatures)) {
        Assert-True (-not $featureById.ContainsKey($feature.Id)) "Windows feature '$($feature.Id)' is unique"
        $featureById[$feature.Id] = $feature
    }
    Assert-True $featureById.ContainsKey('hyper-v') 'Hyper-V is declared'
    Assert-True $featureById.ContainsKey('windows-sandbox') 'Windows Sandbox is declared'
    Assert-True ($featureById['windows-sandbox'].DependsOn -contains 'hyper-v') 'Windows Sandbox explicitly depends on Hyper-V'
    Assert-True ([bool] $featureById['hyper-v'].IncludeAllParents -and [bool] $featureById['windows-sandbox'].IncludeAllParents) 'Hyper-V and Sandbox enable required parent features'

    $featureSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-WindowsFeatureState.ps1') -Raw
    Assert-True ($featureSource -match 'Windows feature dependency cycle detected') 'the Windows feature graph rejects cycles'
    Assert-True ($featureSource -match 'Enable-WindowsOptionalFeature\s+@enableParameters' -and $featureSource -match 'NoRestart\s*=\s*\$true') 'feature enablement explicitly suppresses automatic restart'
    Assert-True ($featureSource -notmatch 'Restart-Computer|shutdown\.exe|wpeutil\s+reboot') 'the feature resource has no restart command'

    $securityModules = @('Hardening', 'ExploitProtection', 'DefenderExclusions', 'SmartScreen', 'Firewall', 'Debloat')
    foreach ($name in $securityModules) {
        Assert-True (@($catalog.Modules | Where-Object Name -eq $name).Count -eq 1) "security boundary '$name' is a separate module"
    }
    $hardeningControls = @($hardening.Profiles.DeveloperBaseline.RegistryValues)
    $uacNames = @('EnableLUA', 'ConsentPromptBehaviorAdmin', 'PromptOnSecureDesktop', 'LocalAccountTokenFilterPolicy')
    Assert-True (@($hardeningControls | Where-Object { $_.Category -eq 'UAC' -or $_.Name -in $uacNames }).Count -eq 0) 'DeveloperBaseline leaves UAC outside managed scope'
    $hardeningSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-HardeningState.ps1') -Raw
    Assert-True ($hardeningSource -notmatch 'Set-MpPreference|Set-NetFirewallProfile|Remove-AppxPackage') 'hardening does not absorb Defender, Firewall, or Debloat mutation'
    Assert-True ($exploitProtection.DefaultProfile -eq 'Recommended') 'Exploit Protection selects the reviewed recommendation by default'
    Assert-True ($null -ne $exploitProtection.Profiles.CapturedDefault -and $null -ne $exploitProtection.Profiles.Recommended) 'Exploit Protection declares recommended and captured-default profiles'
    $capturedById = @{}
    foreach ($setting in $exploitProtection.Profiles.CapturedDefault.ManagedSettings) { $capturedById[$setting.Id] = $setting.Desired }
    $recommendedById = @{}
    foreach ($setting in $exploitProtection.Profiles.Recommended.ManagedSettings) { $recommendedById[$setting.Id] = $setting.Desired }
    Assert-True (@(Compare-Object ($capturedById.Keys | Sort-Object) ($recommendedById.Keys | Sort-Object)).Count -eq 0) 'Exploit Protection rollback covers every managed recommended setting identity'
    $profileDifferences = @($capturedById.Keys | Where-Object { $capturedById[$_] -ne $recommendedById[$_] })
    Assert-True ($profileDifferences.Count -eq 1 -and $profileDifferences[0] -eq 'seh-overwrite-telemetry-only' -and $capturedById[$profileDifferences[0]] -eq 'ON' -and $recommendedById[$profileDifferences[0]] -eq 'OFF') 'the recommendation differs only in SEHOP telemetry-only enforcement state'
    $capturedPolicyPath = Join-Path $repositoryRoot ('config\' + $exploitProtection.CapturedPolicy.Path)
    Assert-True (Test-Path -LiteralPath $capturedPolicyPath -PathType Leaf) 'the complete captured Exploit Protection policy is versioned'
    Assert-True ((Get-FileHash -LiteralPath $capturedPolicyPath -Algorithm SHA256).Hash -eq $exploitProtection.CapturedPolicy.Sha256) 'the captured Exploit Protection policy matches its pinned SHA-256'
    $exploitProtectionSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-ExploitProtectionState.ps1') -Raw
    Assert-True ($exploitProtectionSource -notmatch 'Set-MpPreference|Set-NetFirewallProfile|Remove-AppxPackage') 'Exploit Protection remains separate from antivirus, Firewall, and Debloat mutation'
    $firewallSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-FirewallState.ps1') -Raw
    Assert-True ($firewallSource -match '-DefaultInboundAction Block') 'firewall keeps the unmatched inbound default at Block'
    Assert-True ($firewallSource -match '-AllowInboundRules True' -and $firewallSource -match '-AllowLocalFirewallRules True') 'all profiles honor expert-approved local application rules'
    Assert-True ($firewallSource -match '-NotifyOnListen True') 'application listener prompts remain enabled'
    Assert-True ($firewallSource -notmatch 'LinuxShell-Block-Other|Get-BlockedPortRanges') 'blanket explicit block rules cannot override expert-created allow rules'
    $windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $hardeningPlan = Invoke-External -FilePath $windowsPowerShell -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $repositoryRoot 'scripts\Set-HardeningState.ps1'), '-Mode', 'Plan')
    Assert-True ($hardeningPlan.ExitCode -eq 0) "the human hardening plan succeeds: $($hardeningPlan.Output -join ' ')"
    Assert-True (($hardeningPlan.Output -join [Environment]::NewLine) -match 'disable-llmnr') 'the human hardening plan renders declared control IDs'
    Assert-True (($hardeningPlan.Output -join [Environment]::NewLine) -notmatch 'uac-enabled|uac-admin-consent|uac-secure-desktop') 'the human hardening plan does not advertise UAC controls'
    $exploitProtectionPlan = Invoke-External -FilePath $windowsPowerShell -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $repositoryRoot 'scripts\Set-ExploitProtectionState.ps1'), '-Mode', 'Plan')
    Assert-True ($exploitProtectionPlan.ExitCode -eq 0) "the human Exploit Protection plan succeeds: $($exploitProtectionPlan.Output -join ' ')"
    Assert-True (($exploitProtectionPlan.Output -join [Environment]::NewLine) -match 'seh-overwrite-telemetry-only') 'the Exploit Protection plan renders the recommended SEHOP change'
}

function Test-DebloatSafety {
    $configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\debloat-profiles.psd1')
    $debloatProfile = $configuration.Profiles.DeveloperMinimal
    $protectedSamples = @(
        'Microsoft.DesktopAppInstaller', 'Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp',
        'Microsoft.SecHealthUI', 'Microsoft.NET.Native.Runtime.2.2', 'Microsoft.VCLibs.140.00',
        'Microsoft.UI.Xaml.2.8', 'Microsoft.WindowsAppRuntime.1.6', 'Microsoft.WindowsTerminal',
        'MicrosoftCorporationII.WindowsSubsystemForLinux', 'TheDebianProject.DebianGNULinux', 'OpenAI.Codex'
    )
    foreach ($sample in $protectedSamples) {
        Assert-True (@($debloatProfile.ProtectedAppxPatterns | Where-Object { $sample -like $_ }).Count -gt 0) "protected package rules cover '$sample'"
        Assert-True (@($debloatProfile.AppxPackages | Where-Object { $sample -like $_.NamePattern }).Count -eq 0) "no removal rule targets protected package '$sample'"
    }

    $source = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-DebloatState.ps1') -Raw
    $protectionCall = $source.IndexOf('Test-ProtectedTargets -Inventory $inventory')
    $confirmationGuard = $source.IndexOf('if (-not $ConfirmRemoval)')
    $snapshotCall = $source.IndexOf('$snapshotPath = Save-DebloatSnapshot -State $before')
    $firstRemoval = $source.IndexOf('Remove-AppxPackage')
    Assert-True ($source -match 'NonRemovable') 'non-removable AppX packages are rejected'
    Assert-True ($protectionCall -ge 0 -and $protectionCall -lt $confirmationGuard) 'protected-target validation precedes destructive confirmation'
    Assert-True ($confirmationGuard -ge 0 -and $confirmationGuard -lt $snapshotCall) 'explicit removal confirmation precedes snapshot creation'
    Assert-True ($snapshotCall -ge 0 -and $snapshotCall -lt $firstRemoval) 'pre-removal snapshot is saved before the first removal command'
    Assert-True ($source -match 'CapturedUtc' -and $source -match 'Profile\s*=\s*\$ProfileName' -and $source -match 'State\s*=\s*\$State') 'the debloat snapshot records time, profile, and exact pre-removal state'
    Assert-True ($source -match 'Disable-WindowsOptionalFeature[^\r\n]+-NoRestart') 'debloat optional-feature removal never restarts Windows automatically'
    $windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $debloatPlan = Invoke-External -FilePath $windowsPowerShell -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $repositoryRoot 'scripts\Set-DebloatState.ps1'), '-Mode', 'Plan')
    Assert-True ($debloatPlan.ExitCode -eq 0) "the human debloat plan succeeds: $($debloatPlan.Output -join ' ')"
    Assert-True (($debloatPlan.Output -join [Environment]::NewLine) -match 'remove-bing-weather') 'the human debloat plan renders declared removal IDs'
    Assert-True (($debloatPlan.Output -join [Environment]::NewLine) -match 'explicit -ConfirmRemoval') 'the human debloat plan renders its destructive confirmation boundary'
}

function Test-Capabilities {
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\capabilities.psd1')
    $baselineNames = @(Get-BaselineCapabilityNames)
    $specText = Get-Content -LiteralPath (Join-Path $repositoryRoot 'specs\001-workstation-baseline\spec.md') -Raw
    Assert-True ($specText -match 'SC-002.*All\s+(\d+)\s+declared capability routes') 'SC-002 declares the frozen capability count'
    $declaredCount = [int] $Matches[1]
    Assert-True ($baselineNames.Count -eq $declaredCount) "the capability baseline table contains its declared $declaredCount entries"

    Assert-True ($catalog.SchemaVersion -eq 1) 'the capability catalog declares its supported schema version'
    $catalogNames = @($catalog.Capabilities.Id)
    Assert-True ($catalogNames.Count -eq $declaredCount) "the live catalog contains exactly the declared $declaredCount capability routes"
    Assert-True (@($catalogNames | Sort-Object -Unique).Count -eq $catalogNames.Count) 'capability route IDs are unique'
    Assert-True (@(Compare-Object -ReferenceObject ($baselineNames | Sort-Object) -DifferenceObject ($catalogNames | Sort-Object)).Count -eq 0) 'the live catalog exactly matches the frozen capability baseline'

    $requiredFields = @('Id', 'Title', 'Triggers', 'EvidenceKinds', 'InspectCommands', 'CaptureCommand')
    foreach ($capability in @($catalog.Capabilities)) {
        foreach ($field in $requiredFields) {
            Assert-True $capability.ContainsKey($field) "capability '$($capability.Id)' declares '$field'"
        }
        Assert-True ([string] $capability.Id -match '^[a-z0-9]+(?:-[a-z0-9]+)*$') "capability '$($capability.Id)' has a stable kebab-case ID"
        Assert-True (-not [string]::IsNullOrWhiteSpace([string] $capability.Title)) "capability '$($capability.Id)' has a human title"
        Assert-True (@($capability.Triggers).Count -gt 0 -and @($capability.Triggers | Where-Object { [string]::IsNullOrWhiteSpace([string] $_) }).Count -eq 0) "capability '$($capability.Id)' has nonempty triggers"
        Assert-True (@($capability.EvidenceKinds).Count -gt 0 -and @($capability.EvidenceKinds | Where-Object { [string]::IsNullOrWhiteSpace([string] $_) }).Count -eq 0) "capability '$($capability.Id)' has nonempty evidence kinds"
        Assert-True (@($capability.InspectCommands).Count -gt 0 -and @($capability.InspectCommands | Where-Object { [string]::IsNullOrWhiteSpace([string] $_) }).Count -eq 0) "capability '$($capability.Id)' has human-readable inspection commands"
        Assert-True (-not [string]::IsNullOrWhiteSpace([string] $capability.CaptureCommand)) "capability '$($capability.Id)' has one explicit capture command"
        Assert-True (@($capability.InspectCommands | Where-Object { $_ -eq $capability.CaptureCommand }).Count -eq 0) "capability '$($capability.Id)' keeps capture separate from inspection"
    }
}

function Test-TrickyOutput {
    $runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe -ErrorAction Stop).Source }
    $scriptPath = Join-Path $repositoryRoot 'scripts\Invoke-Tricky.ps1'
    $human = Invoke-External -FilePath $runtime -ArgumentList @('-NoLogo', '-NoProfile', '-File', $scriptPath, 'capabilities')
    Assert-True ($human.ExitCode -eq 0) "Tricky human capability discovery succeeds: $($human.Output -join ' ')"
    $humanText = ($human.Output -join [Environment]::NewLine) -replace '\x1b\[[0-9;]*m', ''
    Assert-True ($humanText -match 'memory-pressure' -and $humanText -match 'Memory pressure') 'human discovery renders route IDs and titles'
    Assert-True ($humanText -match '(?m)^Inspect\s*:' -and $humanText -match '(?m)^Capture\s*:') 'human discovery labels inspection and explicit capture commands'
    Assert-True ($humanText.IndexOf('memapps', [StringComparison]::OrdinalIgnoreCase) -lt $humanText.IndexOf('profile-native-record', [StringComparison]::OrdinalIgnoreCase)) 'human discovery presents memory inspection before capture'
    Assert-True ($humanText -notmatch '^\s*[\{\[]') 'human discovery is not raw JSON'

    $structured = Invoke-External -FilePath $runtime -ArgumentList @('-NoLogo', '-NoProfile', '-File', $scriptPath, 'capabilities', '-Json')
    Assert-True ($structured.ExitCode -eq 0) "Tricky JSON capability discovery succeeds: $($structured.Output -join ' ')"
    $parsed = $null
    try { $parsed = ($structured.Output -join [Environment]::NewLine) | ConvertFrom-Json } catch { $parsed = $null }
    Assert-True ($null -ne $parsed) 'Tricky structured discovery emits parseable JSON'
    if ($parsed) {
        Assert-True ([int] $parsed.SchemaVersion -eq 1) 'Tricky JSON exposes the capability schema version'
        Assert-True (@($parsed.Capabilities).Count -eq @(Get-BaselineCapabilityNames).Count) 'Tricky JSON exposes every frozen capability route'
        Assert-True (@($parsed.Capabilities | Where-Object Id -eq 'network-path').Count -eq 1) 'Tricky JSON preserves stable route IDs'
    }
}

function Test-DiagnosticSkills {
    $skillNames = @('diagnose-memory', 'diagnose-network', 'diagnose-problem', 'investigate-crash', 'profile-native', 'profile-python', 'profile-dotnet')
    $skillText = @{}
    foreach ($name in $skillNames) {
        $path = Join-Path $repositoryRoot ".agents\skills\$name\SKILL.md"
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "focused skill '$name' has its own package"
        $text = Get-Content -LiteralPath $path -Raw
        $skillText[$name] = $text
        Assert-True ($text -match "(?m)^name:\s*$([regex]::Escape($name))\s*$") "focused skill '$name' declares its package name"
    }

    $evidenceBeforeCapture = @(
        @{ Skill = 'diagnose-memory'; Evidence = 'existing ETL'; Capture = 'WPR capture' },
        @{ Skill = 'diagnose-network'; Evidence = 'existing PktMon'; Capture = 'pcap-debug-start' },
        @{ Skill = 'diagnose-problem'; Evidence = 'Add existing evidence'; Capture = 'smallest exact capture command' },
        @{ Skill = 'investigate-crash'; Evidence = 'Add existing EVTX'; Capture = 'eventlog-start/stop' },
        @{ Skill = 'profile-native'; Evidence = 'Inspect existing ETL first'; Capture = 'profile-native-record' },
        @{ Skill = 'profile-python'; Evidence = 'Inspect an existing SVG'; Capture = 'profile-python -?' },
        @{ Skill = 'profile-dotnet'; Evidence = 'Inspect existing `.nettrace`'; Capture = 'bounded capture' }
    )
    foreach ($expectation in $evidenceBeforeCapture) {
        $text = $skillText[$expectation.Skill]
        $evidenceIndex = $text.IndexOf($expectation.Evidence, [StringComparison]::OrdinalIgnoreCase)
        $captureIndex = $text.IndexOf($expectation.Capture, [StringComparison]::OrdinalIgnoreCase)
        Assert-True ($evidenceIndex -ge 0 -and $captureIndex -gt $evidenceIndex) "skill '$($expectation.Skill)' inspects existing evidence before capture"
    }

    foreach ($name in @('profile-native', 'profile-python', 'profile-dotnet')) {
        Assert-True ($skillText[$name] -match '(?i)explicit operator authorization') "capture-capable skill '$name' requires explicit operator authorization"
    }
    Assert-True ($skillText['diagnose-problem'] -match '(?i)Do not start it without user authorization') 'the general diagnostic router prohibits silent capture or state changes'
    Assert-True ($skillText['investigate-crash'] -match '(?i)without explicit authorization') 'crash diagnosis prohibits silent debugger or logging state changes'

    $capabilities = (Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\capabilities.psd1')).Capabilities
    $native = @($capabilities | Where-Object Id -eq 'native-performance')[0]
    $python = @($capabilities | Where-Object Id -eq 'python-performance')[0]
    $dotnet = @($capabilities | Where-Object Id -eq 'dotnet-performance')[0]
    Assert-True ($native.EvidenceKinds -contains 'ETW trace' -and $native.CaptureCommand -match '^profile-native-record\b') 'native and system-wide profiling routes to bounded ETW capture'
    Assert-True ($python.EvidenceKinds -contains 'Python profile' -and $python.CaptureCommand -match '^profile-python\b' -and $python.CaptureCommand -match '\.svg\b') 'Python profiling routes to an SVG sampled profile'
    Assert-True ($dotnet.EvidenceKinds -contains '.NET profile' -and $dotnet.CaptureCommand -match '^profile-dotnet\b' -and @($dotnet.InspectCommands | Where-Object { $_ -match 'speedscope\.json' }).Count -gt 0) '.NET profiling routes EventPipe output to Speedscope inspection'

    $runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe -ErrorAction Stop).Source }
    $status = Invoke-External -FilePath $runtime -ArgumentList @('-NoLogo', '-NoProfile', '-File', (Join-Path $repositoryRoot 'scripts\Get-ProfilerStatus.ps1'), '-Json')
    Assert-True ($status.ExitCode -eq 0) "profiler status JSON succeeds: $($status.Output -join ' ')"
    $rows = $null
    try { $rows = @(($status.Output -join [Environment]::NewLine) | ConvertFrom-Json) } catch { $rows = $null }
    Assert-True ($null -ne $rows -and @($rows).Count -gt 0) 'profiler status is machine-readable'
    foreach ($tool in @('WPR', 'WPA', 'PySpy', 'DotNetTrace')) {
        Assert-True (@($rows | Where-Object { $_.Tool -eq $tool }).Count -eq 1) "profiler status exposes '$tool'"
    }
}

function Test-Contour {
    $configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\contour-terminal.psd1')
    $source = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-ContourTerminalState.ps1') -Raw
    Assert-True ($configuration.Package.Version -match '^\d+\.\d+\.\d+\.\d+$') 'Contour declares a four-part release version'
    Assert-True ($configuration.Package.Uri -match '/releases/download/v' + [regex]::Escape($configuration.Package.Version) + '/.+\.msi$') 'Contour uses the declared official release MSI'
    Assert-True ($configuration.Package.Sha256 -match '^[a-f0-9]{64}$') 'Contour pins the MSI SHA-256'
    Assert-True ($configuration.Package.ProductCode -match '^\{[0-9A-Fa-f-]{36}\}$') 'Contour declares the MSI product code'
    Assert-True ($configuration.LegacyScoopAppName -eq 'contour') 'Contour identifies the legacy Scoop package explicitly'

    $scoopGuard = $source.IndexOf('if ($state.ScoopInstalled)', [StringComparison]::Ordinal)
    $scoopUninstall = $source.IndexOf('& $state.ScoopCommand uninstall $configuration.LegacyScoopAppName', [StringComparison]::Ordinal)
    $scoopVerification = $source.IndexOf("throw 'The legacy Scoop Contour package still exists after uninstall; the MSI was not installed.'", [StringComparison]::Ordinal)
    $msiDownload = $source.IndexOf('Invoke-WebRequest -Uri $package.Uri', [StringComparison]::Ordinal)
    $msiInstall = $source.IndexOf('Invoke-MsiOperation -Operation Install', [StringComparison]::Ordinal)
    Assert-True ($scoopGuard -ge 0 -and $scoopUninstall -gt $scoopGuard) 'Contour checks for the legacy Scoop package before removing it'
    Assert-True ($scoopVerification -gt $scoopUninstall -and $msiDownload -gt $scoopVerification -and $msiInstall -gt $msiDownload) 'Contour verifies Scoop removal before downloading or installing the MSI'
    Assert-True ($source.IndexOf('Get-FileHash -LiteralPath $installerPath -Algorithm SHA256', [StringComparison]::Ordinal) -lt $msiInstall) 'Contour hashes the downloaded MSI before installation'

    $gate = $configuration.GraphicsCompatibilityGate
    Assert-True ([bool] $gate.Enabled) 'the Contour graphics compatibility gate is enabled'
    Assert-True ([int] $gate.MinimumRuntimeSeconds -gt 0) 'the Contour gate requires a positive renderer lifetime'
    Assert-True ([int] $gate.TimeoutSeconds -gt [int] $gate.MinimumRuntimeSeconds -and [int] $gate.TimeoutSeconds -le 30) 'the Contour gate has a bounded timeout'
    Assert-True ([int] $gate.PingCount -gt 0) 'the Contour gate uses a bounded self-exiting workload'
    Assert-True ($source -match 'Get-ContourTerminalState -IncludeGraphicsGate:\(\$Mode -eq ''Test''\)') 'Contour Test mode requests the graphics gate'
    Assert-True ($source -match 'Compliant\s*=\s*\$staticCompliant -and \$graphicsState\.Compatible') 'a graphics failure rejects Contour compliance'
    Assert-True ($source -match 'WaitForExit\(\[int\] \$graphicsGate\.TimeoutSeconds \* 1000\)') 'the graphics process is bounded by the declared timeout'
    Assert-True ($source -match 'OpenGL, GLSL, or shader initialization' -and $source -match 'Get-DisplayDriverSummary') 'graphics failures direct the operator to verify the active driver and INF'
    Assert-True ($source -notmatch 'pnputil|devcon|Update-PnpDevice|Install-WindowsUpdate') 'the Contour gate never changes display-driver state'
}

function Test-DeveloperTools {
    $native = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\native-text-tools.psd1')
    $nativeSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-NativeTextToolsState.ps1') -Raw
    $nativeWinget = Get-Content -LiteralPath (Join-Path $repositoryRoot '.config\native-text-tools.winget') -Raw
    Assert-True ($native.PackageId -eq 'frippery.busybox-w32' -and $nativeWinget -match 'id:\s*frippery\.busybox-w32') 'native text tools use the declared WinGet BusyBox-W32 package'
    Assert-True (@(Compare-Object -ReferenceObject @('awk', 'sed') -DifferenceObject @($native.Applets | Sort-Object)).Count -eq 0) 'the native text-tool surface is exactly awk and sed'
    Assert-True ($nativeSource -match 'Copy-Item -LiteralPath \$busyBoxPath' -and $nativeSource -match 'Test-Applets') 'native awk and sed are copied as Win32 applets and smoke tested'
    foreach ($prohibited in @('Git Bash', 'MinGit', 'MSYS', 'MSYS2', 'Cygwin')) {
        Assert-True ($nativeSource -notmatch [regex]::Escape($prohibited) -and $nativeWinget -notmatch [regex]::Escape($prohibited)) "native text-tool installation does not invoke '$prohibited'"
    }

    $sample = Get-Content -LiteralPath (Join-Path $repositoryRoot '.wsl-env.sample') -Raw
    $importSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Import-WslEnvironment.ps1') -Raw
    Assert-True ($sample -match '(?m)^WSL_DISTRIBUTION=Debian$' -and $sample -match '(?m)^WSL_MALWARE_DISTRIBUTION=Debian-MW$') 'the public WSL sample separates developer Debian from Debian-MW'
    Assert-True ($importSource -match 'Developer Debian, malware Debian, and NixOS distribution names must be different') 'the WSL selector requires three distinct distribution boundaries'

    $homebrew = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\linux-homebrew.psd1')
    $automation = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\linux-automation.psd1')
    $developer = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\developer-tools.psd1')
    $homebrewSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-LinuxHomebrewState.ps1') -Raw
    $automationSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-LinuxAutomationState.ps1') -Raw
    $developerSource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-DeveloperToolsState.ps1') -Raw
    $deploySource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'linux\developer_tools.py') -Raw
    Assert-True ($homebrew.Prefix -eq '/home/linuxbrew/.linuxbrew' -and $automation.Homebrew -like '/home/linuxbrew/*') 'Homebrew and uv remain inside the selected Debian distribution'
    Assert-True ($automation.PyinfraVersion -match '^\d+\.\d+\.\d+$' -and $automationSource -match 'uv tool install --force "pyinfra==\$\(\$configuration\.PyinfraVersion\)"') 'pyinfra is pinned in an isolated uv tool environment inside Debian'
    Assert-True ($developer.Dagger.Version -match '^\d+\.\d+\.\d+$' -and $developer.Dagger.Formula -eq 'dagger/tap/dagger') 'Dagger declares a version and official Homebrew formula'
    Assert-True ($deploySource -match 'from pyinfra\.operations import brew, files' -and $deploySource -match 'packages=\["dagger"\]') 'the local pyinfra deploy installs Dagger through Homebrew'
    Assert-True ($developerSource -match '\$pyinfra ''@local'' \$deploy ''-y''') 'developer-tool desired state executes the reviewed pyinfra deploy locally in Debian'
    Assert-True ($developerSource -match '& \$uv tool install --upgrade semgrep') 'Semgrep uses an isolated host uv tool environment'
    Assert-True (($automationSource + $developerSource) -notmatch '(?i)\bpip(?:3)?\s+install\b') 'developer automation does not install into an unrelated Python environment'
    foreach ($source in @($homebrewSource, $automationSource, $developerSource)) {
        Assert-True ($source -match '\$wslEnvironment\.WSL_DISTRIBUTION') 'each developer WSL resource selects the declared developer distribution'
        Assert-True ($source -notmatch 'WSL_MALWARE_DISTRIBUTION') 'developer WSL resources do not target the malware-analysis distribution'
    }

    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $developerModule = @($catalog.Modules | Where-Object Name -eq 'DeveloperTools')[0]
    $malwareModule = @($catalog.Modules | Where-Object Name -eq 'RootlessPodman')[0]
    Assert-True ($developerModule.DependsOn -contains 'DeveloperDocker' -and $developerModule.DependsOn -notcontains 'RootlessPodman') 'developer tools use the developer engine rather than Debian-MW Podman'
    Assert-True ($malwareModule.DependsOn -notcontains 'DeveloperTools') 'the malware-analysis engine does not inherit developer tools'
}

function Test-SpecDrivenDevelopment {
    $configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\spec-driven-development.psd1')
    $source = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-SpecDrivenDevelopmentState.ps1') -Raw
    Assert-True ($configuration.Version -match '^\d+\.\d+\.\d+$') 'the EARS/TDD bundle declares a release version'
    Assert-True ($configuration.ReleaseTag -eq "v$($configuration.Version)") 'the EARS/TDD release tag matches its version'
    Assert-True ($configuration.Url -match '/releases/download/' + [regex]::Escape($configuration.ReleaseTag) + '/.+-' + [regex]::Escape($configuration.Version) + '-.+\.whl$') 'the EARS/TDD bundle uses its published release wheel rather than Git state'
    Assert-True ($configuration.Sha256 -match '^[a-f0-9]{64}$') 'the EARS/TDD release wheel has a pinned SHA-256'
    Assert-True ($configuration.SpecifyCliVersion -match '^\d+\.\d+\.\d+$') 'the published Specify CLI dependency is versioned'
    Assert-True ($source.IndexOf('Get-FileHash -LiteralPath $wheel -Algorithm SHA256', [StringComparison]::Ordinal) -lt $source.IndexOf('& $uv tool install --force $wheel', [StringComparison]::Ordinal)) 'the release wheel is hash-verified before uv installs it'
    Assert-True ($source -match 'function Get-SpecifyCliVersion' -and $source -match "metadata\.version\('specify-cli'\)") 'resource state inspects the installed Specify CLI dependency directly'
    Assert-True ($source -match "Resource = 'SpecifyCliDependency'") 'resource output reports the upstream Specify CLI dependency separately'

    $runtimes = @(
        (Get-Command pwsh.exe -ErrorAction Stop).Source,
        (Get-Command powershell.exe -ErrorAction Stop).Source
    )
    foreach ($runtime in $runtimes) {
        $arguments = @('-NoLogo', '-NoProfile')
        if ([IO.Path]::GetFileName($runtime) -ieq 'powershell.exe') { $arguments += @('-ExecutionPolicy', 'Bypass') }
        $arguments += @('-File', (Join-Path $repositoryRoot 'scripts\Set-SpecDrivenDevelopmentState.ps1'), '-Mode', 'Test')
        $result = Invoke-External -FilePath $runtime -ArgumentList $arguments
        Assert-True ($result.ExitCode -eq 0) "Spec Kit resource Test succeeds in '$runtime': $($result.Output -join ' ')"
        $text = $result.Output -join [Environment]::NewLine
        Assert-True ($text -match 'SpecKitEarsTddPackage\s+compliant') "'$runtime' reports the released EARS/TDD package compliant"
        Assert-True ($text -match 'SpecifyCliDependency\s+compliant') "'$runtime' reports its published Specify CLI dependency compliant"
        Assert-True ($text -match 'EarsSddCommand\s+compliant') "'$runtime' reports the EARS/TDD command compliant"
    }
}

function Test-DeveloperEnvironment {
    Test-PowerShellRuntimes
    Test-Contour
    Test-DeveloperTools
    Test-SpecDrivenDevelopment
}

function Test-Documentation {
    $readme = Get-Content -LiteralPath (Join-Path $repositoryRoot 'README.md') -Raw
    $gettingStarted = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\getting-started.md') -Raw
    Assert-True ($readme -match 'Windows 11 Pro is required') 'the developer README names Windows 11 Pro as required'
    Assert-True ($gettingStarted -match 'Windows 11 Pro is required') 'getting started names Windows 11 Pro as required'

    $gitignore = @(Get-Content -LiteralPath (Join-Path $repositoryRoot '.gitignore'))
    $localSelections = @(
        [pscustomobject]@{ Sample = '.excluded.sample'; Local = '.excluded' }
        [pscustomobject]@{ Sample = '.wsl-env.sample'; Local = '.wsl-env' }
        [pscustomobject]@{ Sample = '.terminal-fonts-sample'; Local = '.terminal-fonts' }
    )
    foreach ($selection in $localSelections) {
        Assert-True (Test-Path -LiteralPath (Join-Path $repositoryRoot $selection.Sample) -PathType Leaf) "public sample '$($selection.Sample)' exists"
        Assert-True (@($gitignore | Where-Object { $_.Trim() -eq $selection.Local }).Count -eq 1) "local selection '$($selection.Local)' is ignored exactly once"
        $copyPattern = 'Copy-Item\s+' + [regex]::Escape($selection.Sample) + '\s+' + [regex]::Escape($selection.Local)
        Assert-True ($gettingStarted -match $copyPattern) "getting started shows how to create '$($selection.Local)' from its sample"
    }

    $sampleOutputs = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\sample-outputs.md') -Raw
    $hardening = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\hardening.md') -Raw
    $exploitProtection = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\exploit-protection.md') -Raw
    $debloat = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\debloat.md') -Raw
    $malware = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\malware-analysis.md') -Raw
    Assert-True ($sampleOutputs -match '(?m)^PS> ' -and $sampleOutputs -match '(?i)json') 'operator documentation contains representative human and structured output'
    Assert-True ($hardening -match '(?i)sudo|elevat|privileg') 'hardening documentation states its privilege boundary'
    Assert-True ($exploitProtection -match '(?i)sudo|elevat|privileg') 'Exploit Protection documentation states its privilege boundary'
    Assert-True ($exploitProtection -match 'CapturedDefault' -and $exploitProtection -match 'Recommended') 'Exploit Protection documentation provides forward and rollback profiles'
    Assert-True ($debloat -match '(?i)ConfirmRemoval' -and $debloat -match '(?im)^## Rollback limits') 'debloat documentation states confirmation and recovery limits'
    Assert-True ($hardening -match '(?im)^## Residual attack surface' -and $malware -match '(?im)^## Isolation and residual attack surface') 'security workflows document residual attack surface'

    $capabilityDocument = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\capabilities\index.md') -Raw
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\capabilities.psd1')
    foreach ($capability in @($catalog.Capabilities)) {
        Assert-True ($capabilityDocument -match ('`' + [regex]::Escape($capability.Id) + '`')) "capability documentation includes route '$($capability.Id)'"
    }
    Assert-True ($capabilityDocument -match [regex]::Escape('config/capabilities.psd1')) 'operator documentation identifies the routing catalog as authoritative'
    foreach ($target in @('../sample-outputs.md', '../hardening.md#residual-attack-surface', '../debloat.md#rollback-limits', '../malware-analysis.md#isolation-and-residual-attack-surface')) {
        Assert-True ($capabilityDocument -match [regex]::Escape("($target)")) "capability decision page links directly to '$target'"
    }
}

function Test-PublicationGates {
    $powerShell = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $lint = Invoke-External -FilePath $powerShell -ArgumentList @('-NoLogo', '-NoProfile', '-File', (Join-Path $repositoryRoot 'scripts\Invoke-PowerShellLint.ps1'))
    Assert-True ($lint.ExitCode -eq 0) "publication PowerShell lint succeeds: $($lint.Output -join ' ')"

    $trickyScript = Join-Path $repositoryRoot 'scripts\Invoke-Tricky.ps1'
    $human = Invoke-External -FilePath $powerShell -ArgumentList @('-NoLogo', '-NoProfile', '-File', $trickyScript, 'capabilities')
    Assert-True ($human.ExitCode -eq 0 -and ($human.Output -join [Environment]::NewLine) -match 'memory-pressure') 'publication Tricky human smoke succeeds'
    $structured = Invoke-External -FilePath $powerShell -ArgumentList @('-NoLogo', '-NoProfile', '-File', $trickyScript, 'capabilities', '-Json')
    $parsed = $null
    try { $parsed = ($structured.Output -join [Environment]::NewLine) | ConvertFrom-Json } catch { $parsed = $null }
    Assert-True ($structured.ExitCode -eq 0 -and $null -ne $parsed -and @($parsed.Capabilities).Count -eq @(Get-BaselineCapabilityNames).Count) 'publication Tricky JSON smoke succeeds'

    $uv = (Get-Command uv.exe -ErrorAction Stop).Source
    $docs = Invoke-External -FilePath $uv -ArgumentList @('run', '--group', 'docs', 'mkdocs', 'build', '--strict')
    Assert-True ($docs.ExitCode -eq 0) "publication strict documentation build succeeds: $($docs.Output -join ' ')"

    $releaseWorkflow = Get-Content -LiteralPath (Join-Path $repositoryRoot '.github\workflows\release.yml') -Raw
    Assert-True ($releaseWorkflow -match 'Invoke-PowerShellLint\.ps1') 'release workflow declares the PowerShell lint gate'
    Assert-True ($releaseWorkflow -match 'Invoke-Tricky\.ps1\s+capabilities(?:\s|$)') 'release workflow declares the Tricky human smoke gate'
    Assert-True ($releaseWorkflow -match 'Invoke-Tricky\.ps1\s+capabilities\s+-Json') 'release workflow declares the Tricky JSON smoke gate'
    Assert-True ($releaseWorkflow -match 'mkdocs\s+build\s+--strict') 'release workflow declares the strict documentation gate'
}

function Test-SpecificationWorkflow {
    $featureRoot = Join-Path $repositoryRoot 'specs\001-workstation-baseline'
    $specification = Get-Content -LiteralPath (Join-Path $featureRoot 'spec.md') -Raw
    $traceability = Get-Content -LiteralPath (Join-Path $featureRoot 'traceability.toml') -Raw
    $tasks = Get-Content -LiteralPath (Join-Path $featureRoot 'tasks.md') -Raw

    $requirements = @([regex]::Matches($specification, '(?m)^- (REQ-\d{3}): .*\bshall\b') | ForEach-Object { $_.Groups[1].Value })
    $traceIds = @([regex]::Matches($traceability, '(?m)^\[requirements\.(REQ-\d{3})\]\s*$') | ForEach-Object { $_.Groups[1].Value })
    Assert-True ($requirements.Count -gt 0) 'the specification exposes EARS requirements'
    Assert-True (@($requirements | Sort-Object -Unique).Count -eq $requirements.Count) 'EARS requirement IDs are unique'
    Assert-True (@($traceIds | Sort-Object -Unique).Count -eq $traceIds.Count) 'traceability requirement entries are unique'
    Assert-True (@(Compare-Object -ReferenceObject ($requirements | Sort-Object) -DifferenceObject ($traceIds | Sort-Object)).Count -eq 0) 'every EARS requirement has exactly one traceability entry'

    foreach ($requirement in $requirements) {
        $blockPattern = '(?ms)^\[requirements\.' + [regex]::Escape($requirement) + '\]\s*(.*?)(?=^\[requirements\.|\z)'
        $block = [regex]::Match($traceability, $blockPattern).Groups[1].Value
        $verification = [regex]::Match($block, '(?m)^verification\s*=\s*"(automated|manual)"\s*$').Groups[1].Value
        Assert-True ($verification -in @('automated', 'manual')) "traceability for '$requirement' declares an accepted verification mode"
        if ($verification -eq 'automated') {
            Assert-True ($block -match '(?m)^tests\s*=\s*\[\s*"[^"]+"') "automated traceability for '$requirement' names a selector"
        } else {
            Assert-True ($block -match '(?m)^rationale\s*=\s*"[^\"]{20,}"') "manual traceability for '$requirement' gives a concrete rationale"
        }
    }

    $taskIds = @([regex]::Matches($tasks, '(?m)^- \[(?: |x|X)\] T(\d{3})\b') | ForEach-Object { [int] $_.Groups[1].Value })
    Assert-True (@($taskIds | Sort-Object -Unique).Count -eq $taskIds.Count) 'task IDs are unique'
    Assert-True (@(Compare-Object -ReferenceObject @(1..52) -DifferenceObject ($taskIds | Sort-Object)).Count -eq 0) 'the declared T001 through T052 task sequence has no omissions'

    $coverageRows = @([regex]::Matches($tasks, '(?m)^\| (REQ-[^|]+) \| (T[^|]+) \| (T[^|]+) \|$'))
    $coveredRequirements = [Collections.Generic.List[string]]::new()
    foreach ($row in $coverageRows) {
        $rowRequirements = @([regex]::Matches($row.Groups[1].Value, 'REQ-\d{3}') | ForEach-Object { $_.Value })
        foreach ($requirement in $rowRequirements) { $coveredRequirements.Add($requirement) }
        $testTasks = @([regex]::Matches($row.Groups[2].Value, 'T(\d{3})') | ForEach-Object { [int] $_.Groups[1].Value })
        $implementationTasks = @([regex]::Matches($row.Groups[3].Value, 'T(\d{3})') | ForEach-Object { [int] $_.Groups[1].Value })
        Assert-True ($testTasks.Count -gt 0 -and $implementationTasks.Count -gt 0) "coverage row '$($row.Groups[1].Value.Trim())' names test and remediation tasks"
        Assert-True (($testTasks | Measure-Object -Maximum).Maximum -lt ($implementationTasks | Measure-Object -Minimum).Minimum) "coverage row '$($row.Groups[1].Value.Trim())' places failing tests before remediation"
    }
    Assert-True (@(Compare-Object -ReferenceObject ($requirements | Sort-Object) -DifferenceObject (@($coveredRequirements) | Sort-Object)).Count -eq 0) 'the task coverage matrix includes every EARS requirement exactly once'
}

function Test-SkillOptSafety {
    $configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\skillopt.psd1')
    $source = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Invoke-SkillOpt.ps1') -Raw
    Assert-True ($configuration.UserConfig.backend -eq 'mock') 'SkillOpt defaults to the non-provider mock backend'
    Assert-True ($configuration.UserConfig.gate_mode -eq 'on') 'SkillOpt gating is enabled'
    Assert-True ($configuration.UserConfig.gate_no_regression -eq $true) 'SkillOpt rejects regression at the gate'
    Assert-True ($configuration.UserConfig.target_task_filter -eq $true) 'SkillOpt gates against target-task evidence'
    Assert-True ($configuration.UserConfig.auto_adopt -eq $false) 'SkillOpt cannot auto-adopt a proposal'
    Assert-True ($configuration.UserConfig.evolve_memory -eq $false) 'SkillOpt cannot rewrite project memory'

    Assert-True ($source -match '\[Parameter\(Mandatory = \$true, Position = 0\)\]') 'SkillOpt requires one explicit action'
    Assert-True ($source -match 'function Resolve-TargetSkill' -and $source -match "requires a skill name from \.agents/skills") 'optimization actions require one explicit repository skill'
    Assert-True ($source -match 'if \(\$state\.gate_mode -ne ''on''\)') 'the runtime guard rejects disabled gating'
    Assert-True ($source -match 'if \(\$state\.gate_no_regression -ne \$true\)') 'the runtime guard rejects regression-tolerant gating'
    Assert-True ($source -match 'if \(\$state\.target_task_filter -ne \$true\)') 'the runtime guard requires target-task filtering'
    Assert-True ($source -match 'if \(\$state\.auto_adopt -ne \$false\)') 'the runtime guard rejects automatic adoption'
    Assert-True ($source -match "Backend = 'Mock'" -and $source -match 'AllowProviderCalls') 'provider use requires an explicit backend and acknowledgement'
    Assert-True ($source -match '\.skillopt-sleep\\staging' -and $source -match 'Staging path is outside this repository SkillOpt staging tree') 'proposals remain inside the ignored repository staging tree'
    Assert-True ($source -match 'ConfirmAdoption' -and $source -match 'Adoption requires -ConfirmAdoption') 'adoption requires explicit confirmation'
    Assert-True ($source -match 'Adoption requires an explicit -Staging path') 'adoption requires one reviewed staging path'
    Assert-True ($source -notmatch '(?i)Register-ScheduledTask|New-ScheduledTask|schtasks(?:\.exe)?|Start-Job|Register-ObjectEvent') 'the SkillOpt wrapper contains no scheduling path'
}

function Test-Governance {
    Test-Documentation
    Test-PublicationGates
    Test-SpecificationWorkflow
    Test-SkillOptSafety
}

function Test-BootstrapStages {
    $catalogPath = Join-Path $repositoryRoot 'config\workstation-modules.psd1'
    $catalog = Import-PowerShellDataFile -LiteralPath $catalogPath
    Assert-True ($catalog.Stages.Count -ge 3) 'the catalog declares Inbox, Core, and Extended stages'

    $stageByName = @{}
    foreach ($stage in @($catalog.Stages)) {
        Assert-True (-not $stageByName.ContainsKey($stage.Name)) "stage '$($stage.Name)' is unique"
        $stageByName[$stage.Name] = $stage
    }
    foreach ($name in @('Inbox', 'Core', 'Extended')) {
        Assert-True $stageByName.ContainsKey($name) "stage '$name' exists"
    }

    $moduleByName = @{}
    foreach ($module in @($catalog.Modules)) {
        Assert-True (-not $moduleByName.ContainsKey($module.Name)) "module '$($module.Name)' is unique"
        Assert-True $stageByName.ContainsKey($module.Stage) "module '$($module.Name)' declares a known stage"
        Assert-True ($module.Runtime -in @('Inbox', 'PowerShell7', 'Native')) "module '$($module.Name)' declares a supported runtime"
        $moduleByName[$module.Name] = $module
    }
    foreach ($module in @($catalog.Modules)) {
        foreach ($dependencyName in @($module.DependsOn)) {
            Assert-True $moduleByName.ContainsKey($dependencyName) "dependency '$dependencyName' exists"
            if ($moduleByName.ContainsKey($dependencyName) -and $stageByName.ContainsKey($module.Stage)) {
                $dependency = $moduleByName[$dependencyName]
                Assert-True ($stageByName[$dependency.Stage].Order -le $stageByName[$module.Stage].Order) "module '$($module.Name)' has no forward-stage dependency on '$dependencyName'"
            }
        }
    }
    Assert-True ($moduleByName.Sudo.Stage -eq 'Inbox' -and $moduleByName.Sudo.Runtime -eq 'Inbox') 'Sudo can bootstrap with Windows PowerShell 5.1'
    Assert-True ($moduleByName.PowerShell7.Stage -eq 'Inbox' -and $moduleByName.PowerShell7.Runtime -eq 'Native') 'PowerShell 7 installs through a native Inbox-stage command'

    $windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $systemPath = @(
        [Environment]::GetEnvironmentVariable('SystemRoot'),
        (Join-Path ([Environment]::GetEnvironmentVariable('SystemRoot')) 'System32'),
        (Join-Path ([Environment]::GetEnvironmentVariable('SystemRoot')) 'System32\WindowsPowerShell\v1.0'),
        (Join-Path ([Environment]::GetEnvironmentVariable('LOCALAPPDATA')) 'Microsoft\WindowsApps')
    ) -join ';'
    $apply = Join-Path $repositoryRoot 'Apply-Workstation.ps1'
    $plan = Invoke-External -FilePath $windowsPowerShell -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $apply, '-Mode', 'Test', '-Module', 'PowerShell7', '-Plan', '-Json') -Environment @{ PATH = $systemPath }
    Assert-True ($plan.ExitCode -eq 0) "an Inbox-only plan succeeds without pwsh on PATH: $($plan.Output -join ' ')"
    if ($plan.ExitCode -eq 0) {
        $json = ($plan.Output -join [Environment]::NewLine) | ConvertFrom-Json
        Assert-True ($json.ExecutionOrder[0].Stage -eq 'Inbox') 'plan JSON exposes the dependency stage'
        Assert-True ($json.ExecutionOrder[0].Runtime -eq 'Native') 'plan JSON exposes the runtime boundary'
    }

    $corePlan = Invoke-External -FilePath $windowsPowerShell -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $apply, '-Mode', 'Test', '-Module', 'WindowsTerminal', '-Plan', '-Json') -Environment @{ PATH = $systemPath }
    Assert-True ($corePlan.ExitCode -eq 0) "a Core plan succeeds without resolving pwsh: $($corePlan.Output -join ' ')"
    if ($corePlan.ExitCode -eq 0) {
        $coreJson = ($corePlan.Output -join [Environment]::NewLine) | ConvertFrom-Json
        Assert-True (@($coreJson.ExecutionOrder).Count -eq 2) 'the Core plan includes exactly its Inbox gate and requested module'
        Assert-True ($coreJson.ExecutionOrder[0].Name -eq 'PowerShell7' -and $coreJson.ExecutionOrder[1].Name -eq 'WindowsTerminal') 'the PowerShell 7 stage gate precedes the Core module'
    }

    $applySource = Get-Content -LiteralPath $apply -Raw
    Assert-True ($applySource -match 'cannot depend on later-stage module') 'the planner explicitly rejects forward-stage dependencies'
    Assert-True ($applySource -match '\$failedStages' -and $applySource -match 'earlier stages failed') 'the executor blocks later stages after an earlier-stage failure'
    Assert-True ($applySource -match 'function Get-PowerShell7Path' -and $applySource -notmatch '\$pwsh\s*=\s*\(Get-Command') 'PowerShell 7 resolution is lazy rather than eager'
}

function Get-ProfileSurface {
    param([string] $Runtime)
    $loader = Join-Path $repositoryRoot 'profile\Shell.ps1'
    $escapedLoader = $loader.Replace("'", "''")
    $command = ". '$escapedLoader'; [pscustomobject]@{ Edition = `$PSVersionTable.PSEdition; Major = `$PSVersionTable.PSVersion.Major; Prompt = [bool](Get-Command prompt -CommandType Function -ErrorAction Ignore); Wget = [string](Get-Alias wget -ErrorAction Ignore).Definition; Help = [bool](Get-Command workstation-help -ErrorAction Ignore); TestCommand = [bool](Get-Command test-powershell -ErrorAction Ignore); QuantStatus = [bool](Get-Command quant-status -ErrorAction Ignore) } | ConvertTo-Json -Compress"
    $result = Invoke-External -FilePath $Runtime -ArgumentList @('-NoLogo', '-NoProfile', '-Command', $command)
    Assert-True ($result.ExitCode -eq 0) "profile loads in '$Runtime': $($result.Output -join ' ')"
    $jsonLine = @($result.Output | Where-Object { [string] $_ -match '^\s*\{' } | Select-Object -Last 1)
    Assert-True ($jsonLine.Count -eq 1) "profile surface is machine-readable in '$Runtime'"
    if ($jsonLine.Count -eq 1) { return ($jsonLine[0] | ConvertFrom-Json) }
}

function Test-PowerShellRuntimes {
    $profileConfig = Get-Content -LiteralPath (Join-Path $repositoryRoot 'profile\Config.ps1') -Raw
    $profileLoader = Get-Content -LiteralPath (Join-Path $repositoryRoot 'profile\Shell.ps1') -Raw
    $profileDeployer = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-PowerShellProfile.ps1') -Raw
    $nativeCatalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'profile\NativeCommands.psd1')
    Assert-True (@($nativeCatalog.Commands).Count -gt 40) 'native command preference has one declarative catalog'
    Assert-True ($profileConfig -match 'NativeCommands\.cache\.psd1' -and $profileConfig -match 'Test-NativeApplicationAvailable') 'profile consumes the generated native-command cache'
    Assert-True ($profileConfig -match 'Get-Command\s+"\$Name\.exe"') 'a missing or stale cache entry retains live command-discovery fallback'
    Assert-True ($profileDeployer -match 'Get-NativeCommandCacheContent' -and $profileDeployer -match 'Test-NativeCommandCacheDrift') 'profile desired state generates and validates the native-command cache'
    Assert-True ($profileDeployer -match 'Get-Command\s+"\$commandName\.exe"[\s\S]+?Select-Object\s+-First\s+1') 'cache records the first executable PowerShell would invoke when PATH contains duplicates'
    Assert-True ($profileLoader -match 'QuantResearch\.ps1' -and $profileDeployer -match 'QuantResearch\.ps1') 'profile loader and deployer agree on the quantitative research component'

    $windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $powerShell7 = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $desktop = Get-ProfileSurface -Runtime $windowsPowerShell
    $core = Get-ProfileSurface -Runtime $powerShell7
    Assert-True ($desktop.Edition -eq 'Desktop' -and [int] $desktop.Major -eq 5) 'Windows PowerShell 5.1 is characterized'
    Assert-True ($core.Edition -eq 'Core' -and [int] $core.Major -ge 7) 'newest installed PowerShell Core is characterized'
    foreach ($surface in @($desktop, $core)) {
        Assert-True $surface.Prompt 'managed prompt is available'
        Assert-True ($surface.Wget -eq 'aria2c') 'wget maps to the managed aria2c command'
        Assert-True $surface.Help 'workstation-help is available'
        Assert-True $surface.TestCommand 'test-powershell is available'
        Assert-True $surface.QuantStatus 'quant-status is available'
    }
}

function Test-WindowsTerminal {
    $stateScript = Join-Path $repositoryRoot 'scripts\Set-WindowsTerminalState.ps1'
    Assert-True (Test-Path -LiteralPath $stateScript -PathType Leaf) 'focused Windows Terminal state script exists'
    if (-not (Test-Path -LiteralPath $stateScript -PathType Leaf)) { return }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("workstation-terminal-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    try {
        $settingsPath = Join-Path $tempRoot 'settings.json'
        $fixture = @'
{
  "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
  "customSentinel": { "preserve": true },
  "actions": [ { "command": "copy", "keys": "ctrl+c" } ],
  "profiles": { "defaults": { "font": { "face": "Berkeley Mono" } }, "list": [
    { "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}", "name": "Windows PowerShell", "hidden": false },
    { "guid": "{aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa}", "name": "Keep Me", "commandline": "keep.exe" }
  ] },
  "schemes": [ { "name": "Keep Scheme", "background": "#101010" } ],
  "themes": [ { "name": "Keep Theme", "tab": { "background": "#111111" } } ]
}
'@
        [IO.File]::WriteAllText($settingsPath, $fixture, [Text.UTF8Encoding]::new($false))
        $beforeHash = (Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash
        $testResult = Invoke-External -FilePath (Get-Command pwsh.exe -ErrorAction Stop).Source -ArgumentList @('-NoLogo', '-NoProfile', '-File', $stateScript, '-Mode', 'Test', '-SettingsPath', $settingsPath, '-Json')
        Assert-True ($testResult.ExitCode -eq 1) 'Terminal Test reports drift without mutation'
        Assert-True ((Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash -eq $beforeHash) 'Terminal Test leaves settings byte-for-byte unchanged'

        $ensure = Invoke-External -FilePath (Get-Command pwsh.exe -ErrorAction Stop).Source -ArgumentList @('-NoLogo', '-NoProfile', '-File', $stateScript, '-Mode', 'Ensure', '-SettingsPath', $settingsPath, '-Json')
        Assert-True ($ensure.ExitCode -eq 0) "Terminal Ensure succeeds: $($ensure.Output -join ' ')"
        $updated = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        Assert-True ($updated.defaultProfile -eq '{574e775e-4f2a-5b96-ac1e-a2962a402336}') 'PowerShell Core is the Terminal default'
        Assert-True $updated.customSentinel.preserve 'unrelated root settings are preserved'
        Assert-True (@($updated.actions).Count -eq 1) 'unrelated keybindings are preserved'
        Assert-True (@($updated.themes).Count -eq 1) 'unrelated themes are preserved'
        Assert-True (@($updated.profiles.list | Where-Object name -eq 'Keep Me').Count -eq 1) 'unrelated profiles are preserved'
        Assert-True (@($updated.profiles.list | Where-Object guid -eq '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}').Count -eq 1) 'Windows PowerShell remains selectable'
        Assert-True ($updated.profiles.defaults.colorScheme -eq 'Blue') 'all profiles inherit the Blue theme'
        Assert-True ($updated.profiles.defaults.scrollbarState -eq 'visible') 'all profiles inherit the visible scrollbar'
        Assert-True (@($updated.schemes | Where-Object name -eq 'Keep Scheme').Count -eq 1) 'unrelated color schemes are preserved'
        Assert-True (@($updated.schemes | Where-Object name -eq 'Blue').Count -eq 1) 'managed Blue scheme exists once'
        $backups = @(Get-ChildItem -LiteralPath $tempRoot -Filter 'settings.json.*.bak')
        Assert-True ($backups.Count -eq 1) 'a backup is created before the changed write'

        $updatedHash = (Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash
        $secondEnsure = Invoke-External -FilePath (Get-Command pwsh.exe -ErrorAction Stop).Source -ArgumentList @('-NoLogo', '-NoProfile', '-File', $stateScript, '-Mode', 'Ensure', '-SettingsPath', $settingsPath, '-Json')
        Assert-True ($secondEnsure.ExitCode -eq 0) 'a second Terminal Ensure succeeds'
        Assert-True ((Get-FileHash -LiteralPath $settingsPath -Algorithm SHA256).Hash -eq $updatedHash) 'a second Terminal Ensure is byte-idempotent'
        Assert-True (@(Get-ChildItem -LiteralPath $tempRoot -Filter 'settings.json.*.bak').Count -eq 1) 'an idempotent Ensure creates no extra backup'
        $finalTest = Invoke-External -FilePath (Get-Command pwsh.exe -ErrorAction Stop).Source -ArgumentList @('-NoLogo', '-NoProfile', '-File', $stateScript, '-Mode', 'Test', '-SettingsPath', $settingsPath, '-Json')
        Assert-True ($finalTest.ExitCode -eq 0) 'Terminal Test reports compliance after Ensure'
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction Ignore
    }
}

$sections = if ($Section -eq 'All') { @('HarnessSelfTest', 'Modules', 'ModulePlanning', 'PlanSafety', 'StateSafety', 'WindowsSafety', 'DebloatSafety', 'Capabilities', 'TrickyOutput', 'DiagnosticSkills', 'Contour', 'DeveloperTools', 'SpecDrivenDevelopment', 'Governance', 'BootstrapStages', 'PowerShellRuntimes', 'WindowsTerminal') } else { @($Section) }
foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}
Write-Host "Workstation baseline tests passed ($script:assertions assertions)."
