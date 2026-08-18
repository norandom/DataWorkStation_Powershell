[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [string] $SettingsPath,
    [string] $WslFragmentRoot,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\windows-terminal.psd1')
if (-not $SettingsPath) { $SettingsPath = Join-Path $env:LOCALAPPDATA $configuration.SettingsRelativePath }
$SettingsPath = [IO.Path]::GetFullPath($SettingsPath)
if (-not $WslFragmentRoot) { $WslFragmentRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\Microsoft.WSL' }
$WslFragmentRoot = [IO.Path]::GetFullPath($WslFragmentRoot)

function Set-ObjectProperty {
    param([object] $InputObject, [string] $Name, [object] $Value)
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { $property.Value = $Value } else { $InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Get-PropertyValue {
    param([object] $InputObject, [string] $Name)
    if (-not $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Get-TerminalSettings {
    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return [pscustomobject]@{}
    }
    $content = Get-Content -LiteralPath $SettingsPath -Raw
    if (-not $content.Trim()) { return [pscustomobject]@{} }
    return $content | ConvertFrom-Json -Depth 100 -ErrorAction Stop
}

function Get-ProfileByGuid {
    param([object[]] $Profiles, [string] $Guid)
    @($Profiles | Where-Object { [string]::Equals([string] $_.guid, $Guid, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
}

function Get-WslFragmentProfile {
    param([string] $Distribution)
    if (-not (Test-Path -LiteralPath $WslFragmentRoot -PathType Container)) { return $null }
    foreach ($fragment in Get-ChildItem -LiteralPath $WslFragmentRoot -Filter '*.json' -File -ErrorAction Ignore) {
        try {
            $document = Get-Content -LiteralPath $fragment.FullName -Raw | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        } catch {
            throw "Invalid Windows Terminal WSL fragment '$($fragment.FullName)': $($_.Exception.Message)"
        }
        $fragmentProfileCandidate = @($document.profiles | Where-Object { [string] $_.name -eq $Distribution -and [string] $_.guid } | Select-Object -First 1)
        if ($fragmentProfileCandidate.Count -eq 1) { return $fragmentProfileCandidate[0] }
    }
    return $null
}

function Get-DriftReasons {
    param([object] $Settings)
    $reasons = [Collections.Generic.List[string]]::new()
    if ([string] $Settings.defaultProfile -ne [string] $configuration.PowerShellCore.Guid) { $reasons.Add('defaultProfile') }

    $profiles = Get-PropertyValue $Settings 'profiles'
    $defaults = Get-PropertyValue $profiles 'defaults'
    if ([string] (Get-PropertyValue $defaults 'colorScheme') -ne [string] $configuration.ProfileDefaults.ColorScheme) { $reasons.Add('profiles.defaults.colorScheme') }
    if ([string] (Get-PropertyValue $defaults 'scrollbarState') -ne [string] $configuration.ProfileDefaults.ScrollbarState) { $reasons.Add('profiles.defaults.scrollbarState') }
    $profileList = @((Get-PropertyValue $profiles 'list'))
    $core = @(Get-ProfileByGuid -Profiles $profileList -Guid $configuration.PowerShellCore.Guid)
    $desktop = @(Get-ProfileByGuid -Profiles $profileList -Guid $configuration.WindowsPowerShell.Guid)
    if ($core.Count -ne 1 -or [bool] $core[0].hidden) { $reasons.Add('profiles.list.PowerShellCore') }
    if ($desktop.Count -ne 1 -or [bool] $desktop[0].hidden) { $reasons.Add('profiles.list.WindowsPowerShell') }
    foreach ($wslProfile in @($configuration.WslProfiles)) {
        $fragmentProfile = Get-WslFragmentProfile -Distribution $wslProfile.Distribution
        if (-not $fragmentProfile) { continue }
        $managedProfile = @(Get-ProfileByGuid -Profiles $profileList -Guid $fragmentProfile.guid)
        if ($managedProfile.Count -ne 1 -or [bool] $managedProfile[0].hidden -or
            [string] $managedProfile[0].name -ne [string] $wslProfile.Name -or
            [string] $managedProfile[0].source -ne [string] $wslProfile.Source) {
            $reasons.Add("profiles.list.$($wslProfile.Name -replace '\s+', '')")
        }
    }

    $blue = @(@((Get-PropertyValue $Settings 'schemes')) | Where-Object { [string] $_.name -eq [string] $configuration.ColorScheme.Name })
    if ($blue.Count -ne 1) {
        $reasons.Add('schemes.Blue')
    } else {
        foreach ($entry in $configuration.ColorScheme.GetEnumerator()) {
            $jsonName = $entry.Key.Substring(0, 1).ToLowerInvariant() + $entry.Key.Substring(1)
            if ([string] (Get-PropertyValue $blue[0] $jsonName) -ne [string] $entry.Value) {
                $reasons.Add("schemes.Blue.$jsonName")
            }
        }
    }
    return $reasons.ToArray()
}

function Set-ManagedTerminalSettings {
    param([object] $Settings)
    Set-ObjectProperty $Settings 'defaultProfile' ([string] $configuration.PowerShellCore.Guid)

    $profiles = Get-PropertyValue $Settings 'profiles'
    if (-not $profiles) {
        $profiles = [pscustomobject]@{}
        Set-ObjectProperty $Settings 'profiles' $profiles
    }
    $defaults = Get-PropertyValue $profiles 'defaults'
    if (-not $defaults) {
        $defaults = [pscustomobject]@{}
        Set-ObjectProperty $profiles 'defaults' $defaults
    }
    Set-ObjectProperty $defaults 'colorScheme' ([string] $configuration.ProfileDefaults.ColorScheme)
    Set-ObjectProperty $defaults 'scrollbarState' ([string] $configuration.ProfileDefaults.ScrollbarState)

    $profileList = @((Get-PropertyValue $profiles 'list'))
    $core = @(Get-ProfileByGuid -Profiles $profileList -Guid $configuration.PowerShellCore.Guid)
    if ($core.Count -eq 0) {
        $profileList += [pscustomobject]@{
            guid = [string] $configuration.PowerShellCore.Guid
            name = [string] $configuration.PowerShellCore.Name
            source = [string] $configuration.PowerShellCore.Source
            hidden = $false
        }
    } else {
        Set-ObjectProperty $core[0] 'hidden' $false
    }
    $desktop = @(Get-ProfileByGuid -Profiles $profileList -Guid $configuration.WindowsPowerShell.Guid)
    if ($desktop.Count -eq 0) {
        $profileList += [pscustomobject]@{
            commandline = [string] $configuration.WindowsPowerShell.Commandline
            guid = [string] $configuration.WindowsPowerShell.Guid
            hidden = $false
            name = [string] $configuration.WindowsPowerShell.Name
        }
    } else {
        Set-ObjectProperty $desktop[0] 'hidden' $false
    }
    foreach ($wslProfile in @($configuration.WslProfiles)) {
        $fragmentProfile = Get-WslFragmentProfile -Distribution $wslProfile.Distribution
        if (-not $fragmentProfile) { continue }
        $managedProfile = @(Get-ProfileByGuid -Profiles $profileList -Guid $fragmentProfile.guid)
        if ($managedProfile.Count -eq 0) {
            $profileList += [pscustomobject]@{
                guid = [string] $fragmentProfile.guid
                hidden = $false
                name = [string] $wslProfile.Name
                source = [string] $wslProfile.Source
            }
        } else {
            Set-ObjectProperty $managedProfile[0] 'hidden' $false
            Set-ObjectProperty $managedProfile[0] 'name' ([string] $wslProfile.Name)
            Set-ObjectProperty $managedProfile[0] 'source' ([string] $wslProfile.Source)
        }
    }
    Set-ObjectProperty $profiles 'list' @($profileList)

    $managedScheme = [ordered]@{}
    foreach ($entry in $configuration.ColorScheme.GetEnumerator() | Sort-Object Key) {
        $jsonName = $entry.Key.Substring(0, 1).ToLowerInvariant() + $entry.Key.Substring(1)
        $managedScheme[$jsonName] = [string] $entry.Value
    }
    $schemes = [Collections.Generic.List[object]]::new()
    foreach ($scheme in @((Get-PropertyValue $Settings 'schemes'))) {
        if ([string] $scheme.name -ne [string] $configuration.ColorScheme.Name) { $schemes.Add($scheme) }
    }
    $schemes.Add([pscustomobject] $managedScheme)
    Set-ObjectProperty $Settings 'schemes' $schemes.ToArray()
}

$settingsExisted = Test-Path -LiteralPath $SettingsPath -PathType Leaf
$settings = Get-TerminalSettings
$driftReasons = @(Get-DriftReasons -Settings $settings)
$compliant = $settingsExisted -and $driftReasons.Count -eq 0

if ($Mode -eq 'Test') {
    $result = [pscustomobject]@{
        SchemaVersion = 1
        Status = if ($compliant) { 'compliant' } else { 'drift' }
        SettingsPath = $SettingsPath
        Changed = $false
        BackupPath = $null
        Drift = $driftReasons
    }
    if ($Json) { $result | ConvertTo-Json -Depth 6 } elseif ($compliant) { Write-Host "Windows Terminal settings: compliant ($SettingsPath)." } else { Write-Host "Windows Terminal settings: drift detected ($($driftReasons -join ', '))." }
    if ($compliant) { exit 0 } else { exit 1 }
}

if ($compliant -and $Mode -eq 'Ensure') {
    $result = [pscustomobject]@{ SchemaVersion = 1; Status = 'compliant'; SettingsPath = $SettingsPath; Changed = $false; BackupPath = $null; Drift = @() }
    if ($Json) { $result | ConvertTo-Json -Depth 6 } else { Write-Host "Windows Terminal settings are already compliant; no changes were made ($SettingsPath)." }
    exit 0
}

Set-ManagedTerminalSettings -Settings $settings
$directory = Split-Path -Parent $SettingsPath
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$backupPath = $null
if ($settingsExisted) {
    $backupPath = "$SettingsPath.$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').bak"
    Copy-Item -LiteralPath $SettingsPath -Destination $backupPath -Force
}
$desiredJson = $settings | ConvertTo-Json -Depth 100
[IO.File]::WriteAllText($SettingsPath, $desiredJson + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$result = [pscustomobject]@{
    SchemaVersion = 1
    Status = 'compliant'
    SettingsPath = $SettingsPath
    Changed = $true
    BackupPath = $backupPath
    Drift = $driftReasons
}
if ($Json) { $result | ConvertTo-Json -Depth 6 } else { Write-Host "Windows Terminal settings updated: $SettingsPath"; if ($backupPath) { Write-Host "Backup: $backupPath" } }
exit 0
