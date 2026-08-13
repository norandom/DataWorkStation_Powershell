[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $SkipPackages,
    [switch] $SkipDeveloperTools,
    [switch] $SkipFirewall,
    [switch] $SkipDefender,
    [switch] $SkipSmartScreen,
    [switch] $SkipMemoryPolicy,
    [switch] $SkipEventLogs
)

$ErrorActionPreference = 'Stop'
$configurationFile = Join-Path $PSScriptRoot '.config\configuration.winget'
$profileScript = Join-Path $PSScriptRoot 'scripts\Set-PowerShellProfile.ps1'
$developerToolsScript = Join-Path $PSScriptRoot 'scripts\Set-DeveloperToolsState.ps1'
$sudoScript = Join-Path $PSScriptRoot 'scripts\Set-SudoState.ps1'
$defenderScript = Join-Path $PSScriptRoot 'scripts\Set-DefenderExclusionState.ps1'
$smartScreenScript = Join-Path $PSScriptRoot 'scripts\Set-SmartScreenState.ps1'
$wslScript = Join-Path $PSScriptRoot 'scripts\Set-WslState.ps1'
$pagefileScript = Join-Path $PSScriptRoot 'scripts\Set-PagefileState.ps1'
$eventLogScript = Join-Path $PSScriptRoot 'scripts\Set-EventLogState.ps1'
$firewallScript = Join-Path $PSScriptRoot 'scripts\Set-FirewallState.ps1'
$pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
$failures = [Collections.Generic.List[string]]::new()

function Invoke-CheckedProcess {
    param([string] $Label, [scriptblock] $Command)
    & $Command
    if ($LASTEXITCODE -ne 0) { $failures.Add("$Label failed with exit code $LASTEXITCODE.") }
}

if (-not $SkipPackages) {
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

if (-not $SkipDeveloperTools) {
    Invoke-CheckedProcess 'Developer tool state' {
        & $pwsh -NoLogo -NoProfile -File $developerToolsScript -Mode $Mode
    }
}

Invoke-CheckedProcess 'PowerShell profile state' {
    & $pwsh -NoLogo -NoProfile -File $profileScript -Mode $Mode
}
Invoke-CheckedProcess 'Windows sudo state' {
    & $pwsh -NoLogo -NoProfile -File $sudoScript -Mode $Mode
}

if (-not $SkipDefender) {
    Invoke-CheckedProcess 'Microsoft Defender exclusion state' {
        & sudo.exe $pwsh -NoLogo -NoProfile -File $defenderScript -Mode $Mode
    }
}

if (-not $SkipSmartScreen) {
    Invoke-CheckedProcess 'Microsoft Defender SmartScreen state' {
        & sudo.exe $pwsh -NoLogo -NoProfile -File $smartScreenScript -Mode $Mode
    }
}

if (-not $SkipMemoryPolicy) {
    Invoke-CheckedProcess 'WSL memory state' {
        & $pwsh -NoLogo -NoProfile -File $wslScript -Mode $Mode
    }
    Invoke-CheckedProcess 'Windows pagefile state' {
        & sudo.exe $pwsh -NoLogo -NoProfile -File $pagefileScript -Mode $Mode
    }
}

if (-not $SkipEventLogs) {
    Invoke-CheckedProcess 'Windows event-log state' {
        & sudo.exe $pwsh -NoLogo -NoProfile -File $eventLogScript -Mode $Mode
    }
}

if (-not $SkipFirewall) {
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

if ($failures.Count -gt 0) { throw ($failures -join [Environment]::NewLine) }
Write-Host "Workstation desired state '$Mode' completed successfully."
