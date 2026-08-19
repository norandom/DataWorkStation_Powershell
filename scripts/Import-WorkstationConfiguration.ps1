function Expand-WorkstationConfigurationPath {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string] $Path)

    $expanded = [regex]::Replace($Path, '(?i)\$(?:HOME|USERPROFILE)(?=\\|/|$)', { $env:USERPROFILE })
    $expanded = [Environment]::ExpandEnvironmentVariables($expanded)
    if ($expanded -match '%[^%]+%' -or $expanded -match '(?i)\$(?:HOME|USERPROFILE)') {
        throw "Local configuration path contains an unresolved variable: $Path"
    }
    if (-not [IO.Path]::IsPathRooted($expanded)) { throw "Local configuration path must be absolute: $Path" }
    [IO.Path]::GetFullPath($expanded)
}

function Import-WorkstationConfiguration {
    [CmdletBinding()]
    param(
        [string] $RepositoryRoot,
        [string] $ConfigurationPath
    )

    if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
    $RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
    if ([string]::IsNullOrWhiteSpace($ConfigurationPath)) { $ConfigurationPath = Join-Path $RepositoryRoot 'config.json' }
    if (-not [IO.Path]::IsPathRooted($ConfigurationPath)) { $ConfigurationPath = Join-Path $RepositoryRoot $ConfigurationPath }
    $ConfigurationPath = [IO.Path]::GetFullPath($ConfigurationPath)
    if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) {
        throw "Local workstation configuration is missing: $ConfigurationPath. Copy config.sample.json to config.json and customize it."
    }

    try { $configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json -ErrorAction Stop } catch {
        throw "Local workstation configuration is invalid JSON: $ConfigurationPath. $($_.Exception.Message)"
    }
    if ([int] $configuration.schemaVersion -ne 1) { throw "Unsupported local workstation configuration schema: $($configuration.schemaVersion)" }
    if ([string]::IsNullOrWhiteSpace([string] $configuration.fonts.terminalFamily)) { throw 'Local terminal font family is missing.' }

    $roles = @('developer', 'malware', 'nixos', 'ai')
    foreach ($role in $roles) {
        $target = $configuration.wsl.$role
        if (-not $target -or [string] $target.distribution -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid WSL distribution for role '$role'." }
        if ([string] $target.user -notmatch '^[a-z_][a-z0-9_-]*$') { throw "Invalid WSL user for role '$role'." }
    }
    $distributionNames = @($roles | ForEach-Object { [string] $configuration.wsl.$_.distribution })
    if (@($distributionNames | Sort-Object -Unique).Count -ne $distributionNames.Count) {
        throw 'Developer Debian, malware Debian, DevOps NixOS, and AI NixOS distribution names must be different.'
    }

    $tracePath = Expand-WorkstationConfigurationPath -Path ([string] $configuration.paths.traces)
    $eventLogPath = Expand-WorkstationConfigurationPath -Path ([string] $configuration.paths.eventLogs)
    if ($tracePath.TrimEnd('\') -ieq $eventLogPath.TrimEnd('\')) { throw 'Trace and event-log archive roots must be different.' }
    $exclusions = @($configuration.defender.exclusions | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($exclusions.Count -eq 0) { throw 'At least one Defender exclusion path must be declared.' }
    $retentionDays = [int] $configuration.cleanup.traces.retentionDays
    if ($retentionDays -lt 0 -or $retentionDays -gt 3650) { throw 'Trace retentionDays must be between 0 and 3650.' }

    [pscustomobject][ordered]@{
        SchemaVersion = 1
        ConfigurationPath = $ConfigurationPath
        Fonts = [pscustomobject]@{ TerminalFamily = [string] $configuration.fonts.terminalFamily }
        Wsl = $configuration.wsl
        Paths = [pscustomobject]@{ Traces = $tracePath; EventLogs = $eventLogPath }
        Defender = [pscustomobject]@{ Exclusions = @($exclusions) }
        Cleanup = [pscustomobject]@{ Traces = [pscustomobject]@{ RetentionDays = $retentionDays } }
    }
}
