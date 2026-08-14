[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',

    [ValidateSet('DeveloperBaseline')]
    [Alias('Profile')]
    [string] $ProfileName = 'DeveloperBaseline',

    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$configurationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\config\hardening-profiles.psd1'))
$configuration = Import-PowerShellDataFile -LiteralPath $configurationPath
$profileConfiguration = $configuration.Profiles[$ProfileName]
if (-not $profileConfiguration) { throw "Unknown hardening profile: $ProfileName" }

function Assert-Administrator {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator rights are required. Run this script through sudo.'
    }
}

function Get-RegistryValue {
    param([hashtable] $Control)

    try {
        return Get-ItemPropertyValue -LiteralPath $Control.Path -Name $Control.Name -ErrorAction Stop
    } catch {
        return $null
    }
}

function Test-RegistryValue {
    param([hashtable] $Control, [object] $Actual)

    if ($null -eq $Actual) { return $false }
    if ($Control.Type -eq 'DWord') {
        return [int64] $Actual -eq [int64] $Control.Value
    }
    return "$Actual" -ceq "$($Control.Value)"
}

function Get-OptionalFeatureValue {
    param([hashtable] $Control)

    try {
        $state = "$(Get-WindowsOptionalFeature -Online -FeatureName $Control.FeatureName -ErrorAction Stop | Select-Object -ExpandProperty State)"
        if ([string]::IsNullOrWhiteSpace($state)) {
            if ($Control.AllowAbsent) { return 'Absent' }
            throw "Optional feature was not found: $($Control.FeatureName)"
        }
        return $state
    } catch {
        if ($Control.AllowAbsent) { return 'Absent' }
        throw
    }
}

function Test-OptionalFeatureValue {
    param([hashtable] $Control, [string] $Actual)

    if ($Control.DesiredState -eq 'Disabled') {
        return $Actual -in @('Disabled', 'DisabledWithPayloadRemoved', 'Absent')
    }
    return $Actual -eq $Control.DesiredState
}

function ConvertTo-DisplayValue {
    param([object] $Value)

    if ($null -eq $Value) { return '<missing>' }
    if ($Value -is [array]) { return ($Value -join ', ') }
    return "$Value"
}

function Get-HardeningState {
    $controls = [Collections.Generic.List[object]]::new()

    foreach ($control in $profileConfiguration.RegistryValues) {
        $actual = Get-RegistryValue -Control $control
        $controls.Add([pscustomobject]@{
            Id = $control.Id
            Category = $control.Category
            Kind = 'Registry'
            Actual = $actual
            Desired = $control.Value
            Compliant = Test-RegistryValue -Control $control -Actual $actual
            Managed = $true
            RestartRequired = [bool] $control.RestartRequired
        })
    }

    foreach ($control in $profileConfiguration.OptionalFeatures) {
        $actual = Get-OptionalFeatureValue -Control $control
        $controls.Add([pscustomobject]@{
            Id = $control.Id
            Category = $control.Category
            Kind = 'OptionalFeature'
            Actual = $actual
            Desired = $control.DesiredState
            Compliant = Test-OptionalFeatureValue -Control $control -Actual $actual
            Managed = $true
            RestartRequired = $true
        })
    }

    $smbClient = Get-SmbClientConfiguration
    foreach ($setting in $profileConfiguration.SmbClient.GetEnumerator()) {
        $actual = $smbClient.($setting.Key)
        $controls.Add([pscustomobject]@{
            Id = "smb-client-$($setting.Key)"
            Category = 'SMB'
            Kind = 'SmbClient'
            Actual = $actual
            Desired = $setting.Value
            Compliant = "$actual" -ieq "$($setting.Value)"
            Managed = $true
            RestartRequired = $false
        })
    }

    $smbServer = Get-SmbServerConfiguration
    foreach ($setting in $profileConfiguration.SmbServer.GetEnumerator()) {
        $actual = $smbServer.($setting.Key)
        $controls.Add([pscustomobject]@{
            Id = "smb-server-$($setting.Key)"
            Category = 'SMB'
            Kind = 'SmbServer'
            Actual = $actual
            Desired = $setting.Value
            Compliant = "$actual" -ieq "$($setting.Value)"
            Managed = $true
            RestartRequired = $false
        })
    }

    $adapters = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True')
    foreach ($adapter in $adapters) {
        $controls.Add([pscustomobject]@{
            Id = "$($profileConfiguration.Netbios.Id):$($adapter.Index)"
            Category = $profileConfiguration.Netbios.Category
            Kind = 'NetBIOS'
            Actual = $adapter.TcpipNetbiosOptions
            Desired = $profileConfiguration.Netbios.DesiredOption
            Compliant = [int] $adapter.TcpipNetbiosOptions -eq [int] $profileConfiguration.Netbios.DesiredOption
            Managed = $true
            RestartRequired = $true
            Target = $adapter.Description
        })
    }

    foreach ($control in $profileConfiguration.ObservedRegistryValues) {
        $controls.Add([pscustomobject]@{
            Id = $control.Id
            Category = $control.Category
            Kind = 'RegistryObservation'
            Actual = Get-RegistryValue -Control $control
            Desired = '<observed only>'
            Compliant = $null
            Managed = $false
            RestartRequired = $false
        })
    }

    $drift = @($controls | Where-Object { $_.Managed -and -not $_.Compliant })
    return [pscustomobject]@{
        SchemaVersion = 1
        Profile = $ProfileName
        DisplayName = $profileConfiguration.DisplayName
        Compliant = $drift.Count -eq 0
        DriftCount = $drift.Count
        Controls = @($controls)
    }
}

function Write-HumanState {
    param([object] $State, [string[]] $Changes = @())

    $status = if ($State.Compliant) { 'compliant' } else { "$($State.DriftCount) drifted control(s)" }
    Write-Host "Hardening profile '$($State.Profile)': $status."

    $drift = @($State.Controls | Where-Object { $_.Managed -and -not $_.Compliant })
    if ($drift.Count -gt 0) {
        $drift | Select-Object Category,Id,@{ Name='Target'; Expression={ if ($_.Target) { $_.Target } else { $_.Kind } } },
            @{ Name='Actual'; Expression={ ConvertTo-DisplayValue $_.Actual } },
            @{ Name='Desired'; Expression={ ConvertTo-DisplayValue $_.Desired } } |
            Format-Table -AutoSize | Out-Host
    }

    if ($Changes.Count -gt 0) {
        Write-Host 'Applied changes:'
        $Changes | ForEach-Object { Write-Host "- $_" }
    }

    $observed = @($State.Controls | Where-Object { -not $_.Managed })
    if ($observed.Count -gt 0) {
        Write-Host 'Observed but not modified:'
        $observed | Select-Object Id,@{ Name='Actual'; Expression={ ConvertTo-DisplayValue $_.Actual } } |
            Format-Table -AutoSize | Out-Host
    }
}

if ($Mode -eq 'Plan') {
    $plan = [pscustomobject]@{
        SchemaVersion = 1
        Profile = $ProfileName
        DisplayName = $profileConfiguration.DisplayName
        RegistryControls = @($profileConfiguration.RegistryValues | Select-Object Id,Category,Path,Name,Type,Value)
        OptionalFeatures = @($profileConfiguration.OptionalFeatures | Select-Object Id,FeatureName,DesiredState,AllowAbsent)
        SmbClient = $profileConfiguration.SmbClient
        SmbServer = $profileConfiguration.SmbServer
        Netbios = $profileConfiguration.Netbios
        ObservedRegistryValues = @($profileConfiguration.ObservedRegistryValues)
    }
    if ($Json) {
        $plan | ConvertTo-Json -Depth 7
    } else {
        Write-Host "Hardening profile plan: $($plan.DisplayName)"
        $plan.RegistryControls | Select-Object Category,Id,Name,Value | Format-Table -AutoSize | Out-Host
        $plan.OptionalFeatures | Select-Object Id,FeatureName,DesiredState | Format-Table -AutoSize | Out-Host
        Write-Host "SMB client: $($plan.SmbClient | ConvertTo-Json -Compress)"
        Write-Host "SMB server: $($plan.SmbServer | ConvertTo-Json -Compress)"
        Write-Host "NetBIOS option for every IP-enabled adapter: $($plan.Netbios.DesiredOption)"
    }
    exit 0
}

Assert-Administrator
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Use inbox Windows PowerShell for Test or Ensure: sudo powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Test'
}

$before = Get-HardeningState
if ($Mode -eq 'Test') {
    if ($Json) { $before | ConvertTo-Json -Depth 7 } else { Write-HumanState -State $before }
    if ($before.Compliant) { exit 0 } else { exit 1 }
}

$changes = [Collections.Generic.List[string]]::new()
$restartRequired = $false

foreach ($control in $profileConfiguration.RegistryValues) {
    $actual = Get-RegistryValue -Control $control
    if (-not (Test-RegistryValue -Control $control -Actual $actual)) {
        New-Item -Path $control.Path -Force | Out-Null
        New-ItemProperty -LiteralPath $control.Path -Name $control.Name -PropertyType $control.Type -Value $control.Value -Force | Out-Null
        $changes.Add("$($control.Id): $(ConvertTo-DisplayValue $actual) -> $(ConvertTo-DisplayValue $control.Value)")
        if ($control.RestartRequired) { $restartRequired = $true }
    }
}

foreach ($control in $profileConfiguration.OptionalFeatures) {
    $actual = Get-OptionalFeatureValue -Control $control
    if (-not (Test-OptionalFeatureValue -Control $control -Actual $actual)) {
        if ($control.DesiredState -ne 'Disabled') {
            throw "Unsupported optional-feature target '$($control.DesiredState)' for $($control.FeatureName)."
        }
        $result = Disable-WindowsOptionalFeature -Online -FeatureName $control.FeatureName -NoRestart -ErrorAction Stop
        $changes.Add("$($control.Id): $actual -> Disabled")
        if ($result.RestartNeeded) { $restartRequired = $true }
    }
}

$smbClient = Get-SmbClientConfiguration
$smbClientChanges = @{}
foreach ($setting in $profileConfiguration.SmbClient.GetEnumerator()) {
    if ("$($smbClient.($setting.Key))" -ine "$($setting.Value)") {
        $smbClientChanges[$setting.Key] = $setting.Value
        $changes.Add("smb-client-$($setting.Key): $($smbClient.($setting.Key)) -> $($setting.Value)")
    }
}
if ($smbClientChanges.Count -gt 0) {
    Set-SmbClientConfiguration @smbClientChanges -Confirm:$false
}

$smbServer = Get-SmbServerConfiguration
$smbServerChanges = @{}
foreach ($setting in $profileConfiguration.SmbServer.GetEnumerator()) {
    if ("$($smbServer.($setting.Key))" -ine "$($setting.Value)") {
        $smbServerChanges[$setting.Key] = $setting.Value
        $changes.Add("smb-server-$($setting.Key): $($smbServer.($setting.Key)) -> $($setting.Value)")
    }
}
if ($smbServerChanges.Count -gt 0) {
    Set-SmbServerConfiguration @smbServerChanges -Confirm:$false
}

$driftedAdapterIds = @($before.Controls | Where-Object { $_.Kind -eq 'NetBIOS' -and -not $_.Compliant } | ForEach-Object {
    [int] ($_.Id -split ':')[-1]
})
foreach ($adapter in Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True') {
    if ([int] $adapter.Index -in $driftedAdapterIds) {
        $result = Invoke-CimMethod -InputObject $adapter -MethodName SetTcpipNetbios -Arguments @{
            TcpipNetbiosOptions = [uint32] $profileConfiguration.Netbios.DesiredOption
        }
        if ($result.ReturnValue -notin @(0, 1)) {
            throw "NetBIOS configuration failed for '$($adapter.Description)' with return value $($result.ReturnValue)."
        }
        $changes.Add("disable-netbios: $($adapter.Description)")
        if ($result.ReturnValue -eq 1) { $restartRequired = $true }
    }
}

$after = Get-HardeningState
$after | Add-Member -NotePropertyName Changes -NotePropertyValue @($changes)
$after | Add-Member -NotePropertyName RestartRequired -NotePropertyValue $restartRequired
if (-not $after.Compliant) {
    if ($Json) { $after | ConvertTo-Json -Depth 7 } else { Write-HumanState -State $after -Changes @($changes) }
    throw "Hardening profile did not converge; $($after.DriftCount) control(s) remain drifted."
}

if ($Json) {
    $after | ConvertTo-Json -Depth 7
} else {
    Write-HumanState -State $after -Changes @($changes)
    if ($restartRequired) { Write-Warning 'A Windows restart is required before every changed control is fully effective.' }
}
