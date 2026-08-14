[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [ValidateSet(
        'All', 'Sudo', 'Git', 'PowerShell7', 'Packages', 'Scoop', 'TerminalFonts', 'ContourTerminal', 'WindowsFeatures', 'Hardening', 'LinuxHomebrew', 'LinuxAutomation', 'DeveloperTools',
        'ProfilingTools', 'SkillOpt', 'PowerShellProfile', 'FocusFollowsMouse',
        'DefenderExclusions', 'SmartScreen', 'WslMemory', 'Pagefile', 'EventLogs',
        'Firewall', 'Debloat'
    )]
    [string[]] $Module = @('All'),
    [switch] $Plan,
    [switch] $Json,
    [switch] $ConfirmRemoval,
    [switch] $SkipPackages,
    [switch] $SkipWindowsFeatures,
    [switch] $SkipHardening,
    [switch] $SkipFocusFollowsMouse,
    [switch] $SkipDeveloperTools,
    [switch] $SkipProfilingTools,
    [switch] $SkipSkillOpt,
    [switch] $SkipFirewall,
    [switch] $SkipDefender,
    [switch] $SkipSmartScreen,
    [switch] $SkipMemoryPolicy,
    [switch] $SkipEventLogs
)

$ErrorActionPreference = 'Stop'
$configurationFile = Join-Path $PSScriptRoot '.config\configuration.winget'
$gitConfigurationFile = Join-Path $PSScriptRoot '.config\git.winget'
$powerShell7ConfigurationFile = Join-Path $PSScriptRoot '.config\powershell7.winget'
$moduleCatalogPath = Join-Path $PSScriptRoot 'config\workstation-modules.psd1'
$scoopScript = Join-Path $PSScriptRoot 'scripts\Set-ScoopState.ps1'
$terminalFontScript = Join-Path $PSScriptRoot 'scripts\Set-TerminalFontState.ps1'
$contourTerminalScript = Join-Path $PSScriptRoot 'scripts\Set-ContourTerminalState.ps1'
$windowsFeaturesScript = Join-Path $PSScriptRoot 'scripts\Set-WindowsFeatureState.ps1'
$hardeningScript = Join-Path $PSScriptRoot 'scripts\Set-HardeningState.ps1'
$debloatScript = Join-Path $PSScriptRoot 'scripts\Set-DebloatState.ps1'
$focusFollowsMouseScript = Join-Path $PSScriptRoot 'scripts\Set-FocusFollowsMouseState.ps1'
$profileScript = Join-Path $PSScriptRoot 'scripts\Set-PowerShellProfile.ps1'
$developerToolsScript = Join-Path $PSScriptRoot 'scripts\Set-DeveloperToolsState.ps1'
$linuxHomebrewScript = Join-Path $PSScriptRoot 'scripts\Set-LinuxHomebrewState.ps1'
$linuxAutomationScript = Join-Path $PSScriptRoot 'scripts\Set-LinuxAutomationState.ps1'
$profilingToolsScript = Join-Path $PSScriptRoot 'scripts\Set-ProfilingToolsState.ps1'
$skillOptScript = Join-Path $PSScriptRoot 'scripts\Set-SkillOptState.ps1'
$sudoScript = Join-Path $PSScriptRoot 'scripts\Set-SudoState.ps1'
$defenderScript = Join-Path $PSScriptRoot 'scripts\Set-DefenderExclusionState.ps1'
$smartScreenScript = Join-Path $PSScriptRoot 'scripts\Set-SmartScreenState.ps1'
$wslScript = Join-Path $PSScriptRoot 'scripts\Set-WslState.ps1'
$pagefileScript = Join-Path $PSScriptRoot 'scripts\Set-PagefileState.ps1'
$eventLogScript = Join-Path $PSScriptRoot 'scripts\Set-EventLogState.ps1'
$firewallScript = Join-Path $PSScriptRoot 'scripts\Set-FirewallState.ps1'
$pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$failures = [Collections.Generic.List[string]]::new()
$moduleCatalog = Import-PowerShellDataFile -LiteralPath $moduleCatalogPath

function Get-SelectedModuleDefinitions {
    param(
        [hashtable] $Catalog,
        [string[]] $Requested,
        [string[]] $Excluded
    )

    $definitions = @($Catalog.Modules)
    $byName = @{}
    foreach ($definition in $definitions) {
        if ($byName.ContainsKey($definition.Name)) { throw "Duplicate workstation module: $($definition.Name)" }
        $byName[$definition.Name] = $definition
    }
    foreach ($definition in $definitions) {
        foreach ($dependency in @($definition.DependsOn)) {
            if (-not $byName.ContainsKey($dependency)) {
                throw "Workstation module '$($definition.Name)' has unknown dependency '$dependency'."
            }
        }
    }

    $excludedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $Excluded) { [void] $excludedSet.Add($name) }

    $requestedNames = [Collections.Generic.List[string]]::new()
    if ($Requested -contains 'All') {
        foreach ($definition in @($definitions | Where-Object Default | Sort-Object Order,Name)) {
            $requestedNames.Add($definition.Name)
        }
    }
    foreach ($name in @($Requested | Where-Object { $_ -ne 'All' })) {
        if (-not $requestedNames.Contains($name)) { $requestedNames.Add($name) }
    }

    $included = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $requestedNames) {
        if (-not $excludedSet.Contains($name)) { [void] $included.Add($name) }
    }

    do {
        $changed = $false
        foreach ($name in @($included)) {
            foreach ($dependency in @($byName[$name].DependsOn)) {
                if (-not $excludedSet.Contains($dependency) -and $included.Add($dependency)) {
                    $changed = $true
                }
            }
        }
    } while ($changed)

    $ordered = [Collections.Generic.List[object]]::new()
    $completed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    while ($completed.Count -lt $included.Count) {
        $ready = @($definitions | Where-Object {
            $definition = $_
            $included.Contains($definition.Name) -and
                -not $completed.Contains($definition.Name) -and
                @($definition.DependsOn | Where-Object {
                    $included.Contains($_) -and -not $completed.Contains($_)
                }).Count -eq 0
        } | Sort-Object Order,Name)
        if ($ready.Count -eq 0) { throw 'Workstation module dependency cycle detected.' }
        foreach ($definition in $ready) {
            $ordered.Add($definition)
            [void] $completed.Add($definition.Name)
        }
    }

    return @($ordered)
}

function Invoke-CheckedProcess {
    param([string] $Label, [scriptblock] $Command)
    & $Command
    if ($LASTEXITCODE -ne 0) { $failures.Add("$Label failed with exit code $LASTEXITCODE.") }
}

function Invoke-WorkstationModule {
    param([string] $Name)

    switch ($Name) {
        'Sudo' {
            Invoke-CheckedProcess 'Windows sudo state' {
                & $pwsh -NoLogo -NoProfile -File $sudoScript -Mode $Mode
            }
        }
        'Packages' {
            if ($Mode -eq 'Test') {
                Invoke-CheckedProcess 'WinGet configuration test' {
                    & winget configure test --file $configurationFile --accept-configuration-agreements --disable-interactivity
                }
            } else {
                Invoke-CheckedProcess 'WinGet configuration' {
                    & winget configure --file $configurationFile --accept-configuration-agreements --disable-interactivity
                }
            }
        }
        'PowerShell7' {
            if ($Mode -eq 'Test') {
                Invoke-CheckedProcess 'PowerShell 7 WinGet configuration test' {
                    & winget configure test --file $powerShell7ConfigurationFile --accept-configuration-agreements --disable-interactivity
                }
            } else {
                Invoke-CheckedProcess 'PowerShell 7 WinGet configuration' {
                    & winget configure --file $powerShell7ConfigurationFile --accept-configuration-agreements --disable-interactivity
                }
            }
        }
        'Git' {
            if ($Mode -eq 'Test') {
                Invoke-CheckedProcess 'Git WinGet configuration test' {
                    & winget configure test --file $gitConfigurationFile --accept-configuration-agreements --disable-interactivity
                }
            } else {
                Invoke-CheckedProcess 'Git WinGet configuration' {
                    & winget configure --file $gitConfigurationFile --accept-configuration-agreements --disable-interactivity
                }
            }
        }
        'Scoop' {
            Invoke-CheckedProcess 'Scoop state' {
                & $pwsh -NoLogo -NoProfile -File $scoopScript -Mode $Mode
            }
        }
        'TerminalFonts' {
            Invoke-CheckedProcess 'Terminal font state' {
                & $pwsh -NoLogo -NoProfile -File $terminalFontScript -Mode $Mode
            }
        }
        'ContourTerminal' {
            Invoke-CheckedProcess 'Contour Terminal state' {
                & $pwsh -NoLogo -NoProfile -File $contourTerminalScript -Mode $Mode
            }
        }
        'WindowsFeatures' {
            Invoke-CheckedProcess 'Windows optional-feature state' {
                & sudo.exe $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $windowsFeaturesScript -Mode $Mode
            }
        }
        'Hardening' {
            Invoke-CheckedProcess 'Windows hardening profile' {
                & sudo.exe $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $hardeningScript -Profile DeveloperBaseline -Mode $Mode
            }
        }
        'LinuxHomebrew' {
            Invoke-CheckedProcess 'Linux Homebrew state' {
                & $pwsh -NoLogo -NoProfile -File $linuxHomebrewScript -Mode $Mode
            }
        }
        'LinuxAutomation' {
            Invoke-CheckedProcess 'Linux automation state' {
                & $pwsh -NoLogo -NoProfile -File $linuxAutomationScript -Mode $Mode
            }
        }
        'DeveloperTools' {
            Invoke-CheckedProcess 'Developer tool state' {
                & $pwsh -NoLogo -NoProfile -File $developerToolsScript -Mode $Mode
            }
        }
        'ProfilingTools' {
            Invoke-CheckedProcess 'Profiling tool state' {
                & $pwsh -NoLogo -NoProfile -File $profilingToolsScript -Mode $Mode
            }
        }
        'SkillOpt' {
            Invoke-CheckedProcess 'SkillOpt state' {
                & $pwsh -NoLogo -NoProfile -File $skillOptScript -Mode $Mode
            }
        }
        'PowerShellProfile' {
            Invoke-CheckedProcess 'PowerShell profile state' {
                & $pwsh -NoLogo -NoProfile -File $profileScript -Mode $Mode
            }
        }
        'FocusFollowsMouse' {
            Invoke-CheckedProcess 'Focus-follows-mouse state' {
                & $pwsh -NoLogo -NoProfile -File $focusFollowsMouseScript -Mode $Mode
            }
        }
        'DefenderExclusions' {
            Invoke-CheckedProcess 'Microsoft Defender exclusion state' {
                & sudo.exe $pwsh -NoLogo -NoProfile -File $defenderScript -Mode $Mode
            }
        }
        'SmartScreen' {
            Invoke-CheckedProcess 'Microsoft Defender SmartScreen state' {
                & sudo.exe $pwsh -NoLogo -NoProfile -File $smartScreenScript -Mode $Mode
            }
        }
        'WslMemory' {
            Invoke-CheckedProcess 'WSL memory state' {
                & $pwsh -NoLogo -NoProfile -File $wslScript -Mode $Mode
            }
        }
        'Pagefile' {
            Invoke-CheckedProcess 'Windows pagefile state' {
                & sudo.exe $pwsh -NoLogo -NoProfile -File $pagefileScript -Mode $Mode
            }
        }
        'EventLogs' {
            Invoke-CheckedProcess 'Windows event-log state' {
                & sudo.exe $pwsh -NoLogo -NoProfile -File $eventLogScript -Mode $Mode
            }
        }
        'Firewall' {
            if ($Mode -eq 'Test') {
                Invoke-CheckedProcess 'Firewall state' {
                    & $pwsh -NoLogo -NoProfile -File $firewallScript -Mode Test
                }
            } else {
                Invoke-CheckedProcess 'Firewall state' {
                    & sudo.exe $pwsh -NoLogo -NoProfile -File $firewallScript -Mode $Mode
                }
            }
        }
        'Debloat' {
            Invoke-CheckedProcess 'Opt-in debloat state' {
                if ($ConfirmRemoval) {
                    & sudo.exe $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $debloatScript -Profile DeveloperMinimal -Mode $Mode -ConfirmRemoval
                } else {
                    & sudo.exe $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $debloatScript -Profile DeveloperMinimal -Mode $Mode
                }
            }
        }
        default { throw "No workstation module implementation exists for '$Name'." }
    }
}

$skipSwitchUsed = $SkipPackages -or $SkipWindowsFeatures -or $SkipHardening -or
    $SkipFocusFollowsMouse -or $SkipDeveloperTools -or $SkipProfilingTools -or
    $SkipSkillOpt -or $SkipFirewall -or $SkipDefender -or $SkipSmartScreen -or
    $SkipMemoryPolicy -or $SkipEventLogs
$explicitModules = @($Module | Where-Object { $_ -ne 'All' })
if ($explicitModules.Count -gt 0 -and $skipSwitchUsed) {
    throw 'Do not combine explicit -Module selection with legacy -Skip switches.'
}

$excludedModules = [Collections.Generic.List[string]]::new()
if ($SkipPackages) { $excludedModules.Add('Packages') }
if ($SkipWindowsFeatures) { $excludedModules.Add('WindowsFeatures') }
if ($SkipHardening) { $excludedModules.Add('Hardening') }
if ($SkipFocusFollowsMouse) { $excludedModules.Add('FocusFollowsMouse') }
if ($SkipDeveloperTools) { $excludedModules.Add('DeveloperTools') }
if ($SkipProfilingTools) { $excludedModules.Add('ProfilingTools') }
if ($SkipSkillOpt) { $excludedModules.Add('SkillOpt') }
if ($SkipFirewall) { $excludedModules.Add('Firewall') }
if ($SkipDefender) { $excludedModules.Add('DefenderExclusions') }
if ($SkipSmartScreen) { $excludedModules.Add('SmartScreen') }
if ($SkipMemoryPolicy) {
    $excludedModules.Add('WslMemory')
    $excludedModules.Add('Pagefile')
}
if ($SkipEventLogs) { $excludedModules.Add('EventLogs') }

$selectedModules = @(Get-SelectedModuleDefinitions -Catalog $moduleCatalog -Requested $Module -Excluded @($excludedModules))
foreach ($definition in $selectedModules) {
    if ($Mode -notin @($definition.SupportedModes)) {
        throw "Workstation module '$($definition.Name)' does not support mode '$Mode'."
    }
}
if ($ConfirmRemoval -and 'Debloat' -notin @($selectedModules.Name)) {
    throw '-ConfirmRemoval is valid only when the Debloat module is selected.'
}
if (-not $Plan -and $Mode -eq 'Ensure' -and 'Debloat' -in @($selectedModules.Name) -and -not $ConfirmRemoval) {
    throw 'Debloat Ensure requires -ConfirmRemoval. No workstation module was invoked.'
}

if ($Plan) {
    $planResult = [pscustomobject]@{
        SchemaVersion = 1
        Mode = $Mode
        Requested = @($Module)
        Excluded = @($excludedModules)
        ExecutionOrder = @($selectedModules | Select-Object Name,Order,DependsOn,Privileged,Destructive,Description)
    }
    if ($Json) {
        $planResult | ConvertTo-Json -Depth 6
    } else {
        Write-Host "Workstation module plan for mode '$Mode':"
        $planResult.ExecutionOrder | Format-Table Order,Name,@{ Name='DependsOn'; Expression={ $_.DependsOn -join ', ' } },Privileged,Destructive,Description -AutoSize -Wrap | Out-Host
    }
    exit 0
}
if ($Json) { throw '-Json is supported only with -Plan.' }

$moduleStatus = @{}
foreach ($definition in $selectedModules) {
    $blockedDependencies = @($definition.DependsOn | Where-Object {
        $moduleStatus.ContainsKey($_) -and $moduleStatus[$_] -ne 'Succeeded'
    })
    if ($blockedDependencies.Count -gt 0) {
        $moduleStatus[$definition.Name] = 'Skipped'
        $failures.Add("$($definition.Name) skipped because dependencies failed: $($blockedDependencies -join ', ').")
        continue
    }

    $failureCount = $failures.Count
    Invoke-WorkstationModule -Name $definition.Name
    $moduleStatus[$definition.Name] = if ($failures.Count -eq $failureCount) { 'Succeeded' } else { 'Failed' }
}

if ($failures.Count -gt 0) { throw ($failures -join [Environment]::NewLine) }
Write-Host "Workstation desired state '$Mode' completed successfully for modules: $($selectedModules.Name -join ', ')."
