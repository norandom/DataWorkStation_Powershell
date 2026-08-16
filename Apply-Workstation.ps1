[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [ValidateSet(
        'All', 'Sudo', 'Git', 'PowerShell7', 'PowerShellTesting', 'Go', 'Packages', 'NativeTextTools', 'Caffeine', 'Scoop', 'TerminalFonts', 'ContourTerminal', 'WindowsTerminal', 'WindowsFeatures', 'Hardening', 'LinuxHomebrew', 'LinuxAutomation', 'NixOsWsl', 'SharedSshConfig', 'DeveloperDocker', 'RootlessPodman', 'DeveloperTools', 'SpecDrivenDevelopment',
        'MalwareHashes', 'MalwareAnalysisTools', 'NativeForensicTools', 'MalwareContainerImage', 'LegacyDockerCleanup', 'ProfilingTools', 'SkillOpt', 'PowerShellProfile', 'MsvcBuildTools', 'CMake', 'RustToolchain', 'JavaToolchain', 'NativeDevelopment', 'FocusFollowsMouse',
        'DefenderExclusions', 'SmartScreen', 'WslMemory', 'Pagefile', 'EventLogs',
        'Firewall', 'Debloat'
    )]
    [string[]] $Module = @('All'),
    [switch] $Plan,
    [switch] $Json,
    [switch] $ConfirmRemoval,
    [switch] $ConfirmDestructive,
    [switch] $SkipPackages,
    [switch] $SkipWindowsFeatures,
    [switch] $SkipHardening,
    [switch] $SkipFocusFollowsMouse,
    [switch] $SkipDeveloperTools,
    [switch] $SkipNixOsWsl,
    [switch] $SkipSpecDrivenDevelopment,
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
$windowsTerminalConfigurationFile = Join-Path $PSScriptRoot '.config\windows-terminal.winget'
$windowsTerminalStateScript = Join-Path $PSScriptRoot 'scripts\Set-WindowsTerminalState.ps1'
$pesterStateScript = Join-Path $PSScriptRoot 'scripts\Set-PesterState.ps1'
$goStateScript = Join-Path $PSScriptRoot 'scripts\Set-GoState.ps1'
$msvcBuildToolsScript = Join-Path $PSScriptRoot 'scripts\Set-MsvcBuildToolsState.ps1'
$cmakeStateScript = Join-Path $PSScriptRoot 'scripts\Set-CMakeState.ps1'
$rustStateScript = Join-Path $PSScriptRoot 'scripts\Set-RustState.ps1'
$javaStateScript = Join-Path $PSScriptRoot 'scripts\Set-JavaState.ps1'
$nativeDevelopmentScript = Join-Path $PSScriptRoot 'scripts\Set-NativeDevelopmentState.ps1'
$malwareHashesScript = Join-Path $PSScriptRoot 'scripts\Set-MalwareHashesState.ps1'
$moduleCatalogPath = Join-Path $PSScriptRoot 'config\workstation-modules.psd1'
$nativeTextToolsScript = Join-Path $PSScriptRoot 'scripts\Set-NativeTextToolsState.ps1'
$caffeineScript = Join-Path $PSScriptRoot 'scripts\Set-CaffeineState.ps1'
$scoopScript = Join-Path $PSScriptRoot 'scripts\Set-ScoopState.ps1'
$terminalFontScript = Join-Path $PSScriptRoot 'scripts\Set-TerminalFontState.ps1'
$contourTerminalScript = Join-Path $PSScriptRoot 'scripts\Set-ContourTerminalState.ps1'
$windowsFeaturesScript = Join-Path $PSScriptRoot 'scripts\Set-WindowsFeatureState.ps1'
$hardeningScript = Join-Path $PSScriptRoot 'scripts\Set-HardeningState.ps1'
$debloatScript = Join-Path $PSScriptRoot 'scripts\Set-DebloatState.ps1'
$focusFollowsMouseScript = Join-Path $PSScriptRoot 'scripts\Set-FocusFollowsMouseState.ps1'
$profileScript = Join-Path $PSScriptRoot 'scripts\Set-PowerShellProfile.ps1'
$developerToolsScript = Join-Path $PSScriptRoot 'scripts\Set-DeveloperToolsState.ps1'
$specDrivenDevelopmentScript = Join-Path $PSScriptRoot 'scripts\Set-SpecDrivenDevelopmentState.ps1'
$malwareAnalysisToolsScript = Join-Path $PSScriptRoot 'scripts\Set-MalwareAnalysisToolsState.ps1'
$nativeForensicToolsScript = Join-Path $PSScriptRoot 'scripts\Set-NativeForensicToolsState.ps1'
$malwareContainerImageScript = Join-Path $PSScriptRoot 'scripts\Set-MalwareContainerImageState.ps1'
$linuxHomebrewScript = Join-Path $PSScriptRoot 'scripts\Set-LinuxHomebrewState.ps1'
$linuxAutomationScript = Join-Path $PSScriptRoot 'scripts\Set-LinuxAutomationState.ps1'
$nixOsWslScript = Join-Path $PSScriptRoot 'scripts\Set-NixOsWslState.ps1'
$sharedSshConfigScript = Join-Path $PSScriptRoot 'scripts\Set-SharedSshConfigState.ps1'
$rootlessPodmanScript = Join-Path $PSScriptRoot 'scripts\Set-RootlessPodmanState.ps1'
$legacyDockerCleanupScript = Join-Path $PSScriptRoot 'scripts\Remove-LegacyDockerMwState.ps1'
$developerDockerScript = Join-Path $PSScriptRoot 'scripts\Set-DeveloperDockerState.ps1'
$profilingToolsScript = Join-Path $PSScriptRoot 'scripts\Set-ProfilingToolsState.ps1'
$skillOptScript = Join-Path $PSScriptRoot 'scripts\Set-SkillOptState.ps1'
$sudoScript = Join-Path $PSScriptRoot 'scripts\Set-SudoState.ps1'
$defenderScript = Join-Path $PSScriptRoot 'scripts\Set-DefenderExclusionState.ps1'
$smartScreenScript = Join-Path $PSScriptRoot 'scripts\Set-SmartScreenState.ps1'
$wslScript = Join-Path $PSScriptRoot 'scripts\Set-WslState.ps1'
$pagefileScript = Join-Path $PSScriptRoot 'scripts\Set-PagefileState.ps1'
$eventLogScript = Join-Path $PSScriptRoot 'scripts\Set-EventLogState.ps1'
$firewallScript = Join-Path $PSScriptRoot 'scripts\Set-FirewallState.ps1'
$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$script:powerShell7Path = $null
$failures = [Collections.Generic.List[string]]::new()
$moduleCatalog = Import-PowerShellDataFile -LiteralPath $moduleCatalogPath

function Get-PowerShell7Path {
    if ($script:powerShell7Path) { return $script:powerShell7Path }

    $command = Get-Command pwsh.exe -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($command) {
        $script:powerShell7Path = $command.Source
        return $script:powerShell7Path
    }

    $standardPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if (Test-Path -LiteralPath $standardPath -PathType Leaf) {
        $script:powerShell7Path = $standardPath
        return $script:powerShell7Path
    }

    throw 'PowerShell 7 is required for this module but pwsh.exe was not found. Run the PowerShell7 module first.'
}

function Get-SelectedModuleDefinitions {
    param(
        [hashtable] $Catalog,
        [string[]] $Requested,
        [string[]] $Excluded
    )

    $definitions = @($Catalog.Modules)
    $stageByName = @{}
    $stageOrder = @{}
    foreach ($stage in @($Catalog.Stages)) {
        if (-not $stage.Name) { throw 'Every workstation dependency stage requires a name.' }
        if ($stageByName.ContainsKey($stage.Name)) { throw "Duplicate workstation dependency stage: $($stage.Name)" }
        if ($stageOrder.ContainsKey([string] $stage.Order)) { throw "Duplicate workstation dependency stage order: $($stage.Order)" }
        $stageByName[$stage.Name] = $stage
        $stageOrder[[string] $stage.Order] = $stage.Name
    }
    if ($stageByName.Count -eq 0) { throw 'The workstation module catalog declares no dependency stages.' }
    $byName = @{}
    foreach ($definition in $definitions) {
        if ($byName.ContainsKey($definition.Name)) { throw "Duplicate workstation module: $($definition.Name)" }
        $byName[$definition.Name] = $definition
    }
    foreach ($definition in $definitions) {
        if (-not $stageByName.ContainsKey($definition.Stage)) {
            throw "Workstation module '$($definition.Name)' has unknown stage '$($definition.Stage)'."
        }
        if ($definition.Runtime -notin @('Inbox', 'PowerShell7', 'Native')) {
            throw "Workstation module '$($definition.Name)' has unsupported runtime '$($definition.Runtime)'."
        }
        foreach ($dependency in @($definition.DependsOn)) {
            if (-not $byName.ContainsKey($dependency)) {
                throw "Workstation module '$($definition.Name)' has unknown dependency '$dependency'."
            }
            if ([int] $stageByName[$byName[$dependency].Stage].Order -gt [int] $stageByName[$definition.Stage].Order) {
                throw "Workstation module '$($definition.Name)' in stage '$($definition.Stage)' cannot depend on later-stage module '$dependency'."
            }
        }
    }
    foreach ($stage in @($Catalog.Stages)) {
        foreach ($dependency in @($stage.DependsOn)) {
            if (-not $byName.ContainsKey($dependency)) {
                throw "Workstation dependency stage '$($stage.Name)' has unknown gate module '$dependency'."
            }
            if ([int] $stageByName[$byName[$dependency].Stage].Order -gt [int] $stage.Order) {
                throw "Workstation dependency stage '$($stage.Name)' cannot depend on later-stage module '$dependency'."
            }
        }
    }

    $excludedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $Excluded) { [void] $excludedSet.Add($name) }

    $requestedNames = [Collections.Generic.List[string]]::new()
    if ($Requested -contains 'All') {
        foreach ($definition in @($definitions | Where-Object Default | Sort-Object @{ Expression = { [int] $stageByName[$_.Stage].Order } },Order,Name)) {
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
            $definition = $byName[$name]
            $dependencies = @($definition.DependsOn) + @($stageByName[$definition.Stage].DependsOn)
            foreach ($dependency in $dependencies) {
                if ($excludedSet.Contains($dependency)) {
                    throw "Workstation module '$name' requires excluded stage dependency '$dependency'."
                }
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
        } | Sort-Object @{ Expression = { [int] $stageByName[$_.Stage].Order } },Order,Name | Select-Object -First 1)
        if ($ready.Count -eq 0) { throw 'Workstation module dependency cycle detected.' }
        foreach ($definition in $ready) {
            $ordered.Add($definition)
            [void] $completed.Add($definition.Name)
        }
    }

    foreach ($definition in $ordered) {
        Write-Output -InputObject $definition -NoEnumerate
    }
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
                & $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $sudoScript -Mode $Mode
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
        'NativeTextTools' {
            Invoke-CheckedProcess 'Native awk and sed state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $nativeTextToolsScript -Mode $Mode
            }
        }
        'Caffeine' {
            Invoke-CheckedProcess 'Caffeine package state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $caffeineScript -Mode $Mode
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
        'Go' {
            Invoke-CheckedProcess 'Go package and environment state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $goStateScript -Mode $Mode
            }
        }
        'MsvcBuildTools' {
            Invoke-CheckedProcess 'Standalone MSVC Build Tools state' {
                if ($Mode -eq 'Test') {
                    & (Get-PowerShell7Path) -NoLogo -NoProfile -File $msvcBuildToolsScript -Mode Test
                } else {
                    & sudo.exe (Get-PowerShell7Path) -NoLogo -NoProfile -File $msvcBuildToolsScript -Mode $Mode
                }
            }
        }
        'CMake' {
            Invoke-CheckedProcess 'CMake and Ninja state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $cmakeStateScript -Mode $Mode
            }
        }
        'RustToolchain' {
            Invoke-CheckedProcess 'Rust MSVC toolchain state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $rustStateScript -Mode $Mode
            }
        }
        'JavaToolchain' {
            Invoke-CheckedProcess 'Microsoft OpenJDK state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $javaStateScript -Mode $Mode
            }
        }
        'NativeDevelopment' {
            Invoke-CheckedProcess 'Native development integration state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $nativeDevelopmentScript -Mode Test
            }
        }
        'PowerShellTesting' {
            Invoke-CheckedProcess 'PowerShell test framework state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $pesterStateScript -Mode $Mode
            }
        }
        'MalwareHashes' {
            Invoke-CheckedProcess 'malware_hashes GitHub release state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $malwareHashesScript -Mode $Mode
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
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $scoopScript -Mode $Mode
            }
        }
        'TerminalFonts' {
            Invoke-CheckedProcess 'Terminal font state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $terminalFontScript -Mode $Mode
            }
        }
        'ContourTerminal' {
            Invoke-CheckedProcess 'Contour Terminal state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $contourTerminalScript -Mode $Mode
            }
        }
        'WindowsTerminal' {
            if ($Mode -eq 'Test') {
                Invoke-CheckedProcess 'Windows Terminal package test' {
                    & winget configure test --file $windowsTerminalConfigurationFile --accept-configuration-agreements --disable-interactivity
                }
            } else {
                Invoke-CheckedProcess 'Windows Terminal package state' {
                    & winget configure --file $windowsTerminalConfigurationFile --accept-configuration-agreements --disable-interactivity
                }
            }
            Invoke-CheckedProcess 'Windows Terminal settings state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $windowsTerminalStateScript -Mode $Mode
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
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $linuxHomebrewScript -Mode $Mode
            }
        }
        'LinuxAutomation' {
            Invoke-CheckedProcess 'Linux automation state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $linuxAutomationScript -Mode $Mode
            }
        }
        'NixOsWsl' {
            Invoke-CheckedProcess 'NixOS WSL state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $nixOsWslScript -Mode $Mode
            }
        }
        'SharedSshConfig' {
            Invoke-CheckedProcess 'Shared SSH configuration state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $sharedSshConfigScript -Mode $Mode
            }
        }
        'RootlessPodman' {
            Invoke-CheckedProcess 'Rootless Podman state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $rootlessPodmanScript -Mode $Mode
            }
        }
        'DeveloperDocker' {
            Invoke-CheckedProcess 'Developer Docker state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $developerDockerScript -Mode $Mode
            }
        }
        'DeveloperTools' {
            Invoke-CheckedProcess 'Developer tool state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $developerToolsScript -Mode $Mode
            }
        }
        'SpecDrivenDevelopment' {
            Invoke-CheckedProcess 'Spec-driven development state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $specDrivenDevelopmentScript -Mode $Mode
            }
        }
        'MalwareAnalysisTools' {
            Invoke-CheckedProcess 'Optional malware analysis tool state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $malwareAnalysisToolsScript -Mode $Mode
            }
        }
        'NativeForensicTools' {
            Invoke-CheckedProcess 'Native forensic tool state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $nativeForensicToolsScript -Mode $Mode
            }
        }
        'MalwareContainerImage' {
            Invoke-CheckedProcess 'Rootless malware parser image state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $malwareContainerImageScript -Mode $Mode
            }
        }
        'LegacyDockerCleanup' {
            Invoke-CheckedProcess 'Retained Debian-MW Docker data cleanup' {
                if ($ConfirmDestructive) {
                    & (Get-PowerShell7Path) -NoLogo -NoProfile -File $legacyDockerCleanupScript -Mode $Mode -ConfirmDestructive
                } else {
                    & (Get-PowerShell7Path) -NoLogo -NoProfile -File $legacyDockerCleanupScript -Mode $Mode
                }
            }
        }
        'ProfilingTools' {
            Invoke-CheckedProcess 'Profiling tool state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $profilingToolsScript -Mode $Mode
            }
        }
        'SkillOpt' {
            Invoke-CheckedProcess 'SkillOpt state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $skillOptScript -Mode $Mode
            }
        }
        'PowerShellProfile' {
            Invoke-CheckedProcess 'PowerShell profile state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $profileScript -Mode $Mode
            }
        }
        'FocusFollowsMouse' {
            Invoke-CheckedProcess 'Focus-follows-mouse state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $focusFollowsMouseScript -Mode $Mode
            }
        }
        'DefenderExclusions' {
            Invoke-CheckedProcess 'Microsoft Defender exclusion state' {
                & sudo.exe (Get-PowerShell7Path) -NoLogo -NoProfile -File $defenderScript -Mode $Mode
            }
        }
        'SmartScreen' {
            Invoke-CheckedProcess 'Microsoft Defender SmartScreen state' {
                & sudo.exe (Get-PowerShell7Path) -NoLogo -NoProfile -File $smartScreenScript -Mode $Mode
            }
        }
        'WslMemory' {
            Invoke-CheckedProcess 'WSL memory state' {
                & (Get-PowerShell7Path) -NoLogo -NoProfile -File $wslScript -Mode $Mode
            }
        }
        'Pagefile' {
            Invoke-CheckedProcess 'Windows pagefile state' {
                & sudo.exe (Get-PowerShell7Path) -NoLogo -NoProfile -File $pagefileScript -Mode $Mode
            }
        }
        'EventLogs' {
            Invoke-CheckedProcess 'Windows event-log state' {
                & sudo.exe (Get-PowerShell7Path) -NoLogo -NoProfile -File $eventLogScript -Mode $Mode
            }
        }
        'Firewall' {
            if ($Mode -eq 'Test') {
                Invoke-CheckedProcess 'Firewall state' {
                    & (Get-PowerShell7Path) -NoLogo -NoProfile -File $firewallScript -Mode Test
                }
            } else {
                Invoke-CheckedProcess 'Firewall state' {
                    & sudo.exe (Get-PowerShell7Path) -NoLogo -NoProfile -File $firewallScript -Mode $Mode
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
    $SkipFocusFollowsMouse -or $SkipDeveloperTools -or $SkipNixOsWsl -or $SkipSpecDrivenDevelopment -or $SkipProfilingTools -or
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
if ($SkipNixOsWsl) {
    $excludedModules.Add('NixOsWsl')
    $excludedModules.Add('SharedSshConfig')
}
if ($SkipSpecDrivenDevelopment) { $excludedModules.Add('SpecDrivenDevelopment') }
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
if ($ConfirmDestructive -and @($selectedModules | Where-Object Destructive).Count -eq 0) {
    throw '-ConfirmDestructive is valid only when a destructive module is selected.'
}
if (-not $Plan -and $Mode -eq 'Ensure' -and @($selectedModules | Where-Object Destructive).Count -gt 0 -and -not $ConfirmDestructive -and 'Debloat' -notin @($selectedModules.Name)) {
    throw 'Destructive module Ensure requires -ConfirmDestructive. No workstation module was invoked.'
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
        ExecutionOrder = @($selectedModules | ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                Stage = $_.Stage
                Runtime = $_.Runtime
                Order = $_.Order
                DependsOn = @($_.DependsOn)
                Privileged = $_.Privileged
                Destructive = $_.Destructive
                Description = $_.Description
            }
        })
    }
    if ($Json) {
        $planResult | ConvertTo-Json -Depth 6
    } else {
        Write-Host "Workstation module plan for mode '$Mode':"
        $planResult.ExecutionOrder | Format-Table Stage,Order,Name,Runtime,@{ Name='DependsOn'; Expression={ $_.DependsOn -join ', ' } },Privileged,Destructive,Description -AutoSize -Wrap | Out-Host
    }
    exit 0
}
if ($Json) { throw '-Json is supported only with -Plan.' }

$moduleStatus = @{}
$failedStages = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$stageByName = @{}
foreach ($stage in @($moduleCatalog.Stages)) { $stageByName[$stage.Name] = $stage }
foreach ($definition in $selectedModules) {
    $blockedStages = @($failedStages | Where-Object { [int] $stageByName[$_].Order -lt [int] $stageByName[$definition.Stage].Order })
    if ($blockedStages.Count -gt 0) {
        $moduleStatus[$definition.Name] = 'Skipped'
        $failures.Add("$($definition.Name) skipped because earlier stages failed: $($blockedStages -join ', ').")
        continue
    }
    $blockedDependencies = @(@($definition.DependsOn) | Where-Object {
        $_ -and $moduleStatus.ContainsKey($_) -and $moduleStatus[$_] -ne 'Succeeded'
    })
    if ($blockedDependencies.Count -gt 0) {
        $moduleStatus[$definition.Name] = 'Skipped'
        $failures.Add("$($definition.Name) skipped because dependencies failed: $($blockedDependencies -join ', ').")
        continue
    }

    $failureCount = $failures.Count
    Invoke-WorkstationModule -Name $definition.Name
    $moduleStatus[$definition.Name] = if ($failures.Count -eq $failureCount) { 'Succeeded' } else { 'Failed' }
    if ($moduleStatus[$definition.Name] -eq 'Failed') { [void] $failedStages.Add($definition.Stage) }
}

if ($failures.Count -gt 0) { throw ($failures -join [Environment]::NewLine) }
Write-Host "Workstation desired state '$Mode' completed successfully for modules: $($selectedModules.Name -join ', ')."
