[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure')]
    [string] $Mode = 'Test',

    [ValidateSet('DeveloperMinimal')]
    [Alias('Profile')]
    [string] $ProfileName = 'DeveloperMinimal',

    [switch] $ConfirmRemoval,

    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$configurationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\config\debloat-profiles.psd1'))
$configuration = Import-PowerShellDataFile -LiteralPath $configurationPath
$profileConfiguration = $configuration.Profiles[$ProfileName]
if (-not $profileConfiguration) { throw "Unknown debloat profile: $ProfileName" }

function Assert-Administrator {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator rights are required. Run this script through sudo.'
    }
}

function Get-DebloatInventory {
    [pscustomobject]@{
        InstalledAppx = @(Get-AppxPackage -AllUsers -PackageTypeFilter Main,Bundle)
        ProvisionedAppx = @(Get-AppxProvisionedPackage -Online)
        Capabilities = @(Get-WindowsCapability -Online)
        OptionalFeatures = @(Get-WindowsOptionalFeature -Online)
    }
}

function Get-MatchingInstalledAppx {
    param([object] $Inventory, [string] $Pattern)
    @($Inventory.InstalledAppx | Where-Object Name -like $Pattern)
}

function Get-MatchingProvisionedAppx {
    param([object] $Inventory, [string] $Pattern)
    @($Inventory.ProvisionedAppx | Where-Object DisplayName -like $Pattern)
}

function Get-DebloatState {
    param([object] $Inventory)

    $controls = [Collections.Generic.List[object]]::new()

    foreach ($control in $profileConfiguration.AppxPackages) {
        $installed = @(Get-MatchingInstalledAppx -Inventory $Inventory -Pattern $control.NamePattern)
        $provisioned = @(Get-MatchingProvisionedAppx -Inventory $Inventory -Pattern $control.NamePattern)
        $controls.Add([pscustomobject]@{
            Id = $control.Id
            Kind = 'Appx'
            Target = $control.NamePattern
            Reason = $control.Reason
            Actual = "$($installed.Count) installed, $($provisioned.Count) provisioned"
            Desired = 'Absent'
            Compliant = $installed.Count -eq 0 -and $provisioned.Count -eq 0
            Details = [pscustomobject]@{
                Installed = @($installed | Select-Object Name,PackageFullName,PackageFamilyName,InstallLocation,NonRemovable)
                Provisioned = @($provisioned | Select-Object DisplayName,PackageName)
            }
        })
    }

    foreach ($control in $profileConfiguration.Capabilities) {
        $capabilityMatches = @($Inventory.Capabilities | Where-Object Name -like $control.NamePattern)
        $present = @($capabilityMatches | Where-Object State -ne 'NotPresent')
        $controls.Add([pscustomobject]@{
            Id = $control.Id
            Kind = 'Capability'
            Target = $control.NamePattern
            Reason = $control.Reason
            Actual = if ($capabilityMatches.Count -eq 0) { 'Absent' } else { ($capabilityMatches | ForEach-Object { "$($_.Name)=$($_.State)" }) -join '; ' }
            Desired = 'NotPresent'
            Compliant = $present.Count -eq 0
            Details = @($capabilityMatches | Select-Object Name,State)
        })
    }

    foreach ($control in $profileConfiguration.OptionalFeatures) {
        $feature = @($Inventory.OptionalFeatures | Where-Object FeatureName -eq $control.FeatureName | Select-Object -First 1)
        $actual = if ($feature.Count -eq 0) { 'Absent' } else { "$($feature[0].State)" }
        $controls.Add([pscustomobject]@{
            Id = $control.Id
            Kind = 'OptionalFeature'
            Target = $control.FeatureName
            Reason = $control.Reason
            Actual = $actual
            Desired = 'Disabled'
            Compliant = $actual -in @('Absent', 'Disabled', 'DisabledWithPayloadRemoved')
            Details = @($feature | Select-Object FeatureName,State)
        })
    }

    $drift = @($controls | Where-Object { -not $_.Compliant })
    [pscustomobject]@{
        SchemaVersion = 1
        Profile = $ProfileName
        DisplayName = $profileConfiguration.DisplayName
        Compliant = $drift.Count -eq 0
        DriftCount = $drift.Count
        Controls = @($controls)
    }
}

function Write-HumanState {
    param(
        [object] $State,
        [string[]] $Changes = @(),
        [string] $SnapshotPath
    )

    $status = if ($State.Compliant) { 'compliant' } else { "$($State.DriftCount) removal target(s) still present" }
    Write-Host "Debloat profile '$($State.Profile)': $status."
    $drift = @($State.Controls | Where-Object { -not $_.Compliant })
    if ($drift.Count -gt 0) {
        $drift | Select-Object Kind,Id,Target,Actual,Reason | Format-Table -AutoSize -Wrap | Out-Host
    }
    if ($Changes.Count -gt 0) {
        Write-Host 'Applied removals:'
        $Changes | ForEach-Object { Write-Host "- $_" }
    }
    if ($SnapshotPath) { Write-Host "Pre-removal inventory: $SnapshotPath" }
}

function Test-ProtectedTargets {
    param([object] $Inventory)

    foreach ($control in $profileConfiguration.AppxPackages) {
        $targetMatches = @(
            Get-MatchingInstalledAppx -Inventory $Inventory -Pattern $control.NamePattern
            Get-MatchingProvisionedAppx -Inventory $Inventory -Pattern $control.NamePattern
        )
        foreach ($match in $targetMatches) {
            $name = if ($match.Name) { $match.Name } else { $match.DisplayName }
            foreach ($protectedPattern in $profileConfiguration.ProtectedAppxPatterns) {
                if ($name -like $protectedPattern) {
                    throw "Refusing to remove protected AppX package '$name' matched by '$($control.NamePattern)'."
                }
            }
        }
    }

    $nonRemovable = @($Inventory.InstalledAppx | Where-Object {
        $package = $_
        $package.NonRemovable -and @($profileConfiguration.AppxPackages | Where-Object {
            $package.Name -like $_.NamePattern
        }).Count -gt 0
    })
    if ($nonRemovable.Count -gt 0) {
        throw "Refusing to remove packages marked NonRemovable: $($nonRemovable.Name -join ', ')"
    }
}

function Save-DebloatSnapshot {
    param([object] $State)

    $snapshotDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\state\debloat-snapshots'))
    New-Item -ItemType Directory -Path $snapshotDirectory -Force | Out-Null
    $snapshotPath = Join-Path $snapshotDirectory ("debloat-before-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    [pscustomobject]@{
        SchemaVersion = 1
        CapturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        ComputerName = $env:COMPUTERNAME
        Profile = $ProfileName
        State = $State
    } | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
    return $snapshotPath
}

if ($Mode -eq 'Plan') {
    $plan = [pscustomobject]@{
        SchemaVersion = 1
        Profile = $ProfileName
        DisplayName = $profileConfiguration.DisplayName
        AppxPackages = @($profileConfiguration.AppxPackages)
        Capabilities = @($profileConfiguration.Capabilities)
        OptionalFeatures = @($profileConfiguration.OptionalFeatures)
        ProtectedAppxPatterns = @($profileConfiguration.ProtectedAppxPatterns)
        EnsureRequires = '-ConfirmRemoval'
    }
    if ($Json) {
        $plan | ConvertTo-Json -Depth 7
    } else {
        Write-Host "Debloat profile plan: $($plan.DisplayName)"
        $plan.AppxPackages | Select-Object Id,NamePattern,Reason | Format-Table -AutoSize -Wrap | Out-Host
        $plan.Capabilities | Select-Object Id,NamePattern,Reason | Format-Table -AutoSize -Wrap | Out-Host
        $plan.OptionalFeatures | Select-Object Id,FeatureName,Reason | Format-Table -AutoSize -Wrap | Out-Host
        Write-Host 'Ensure is destructive and requires the explicit -ConfirmRemoval switch.'
    }
    exit 0
}

Assert-Administrator
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Use inbox Windows PowerShell: sudo powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Test'
}

$inventory = Get-DebloatInventory
Test-ProtectedTargets -Inventory $inventory
$before = Get-DebloatState -Inventory $inventory
if ($Mode -eq 'Test') {
    if ($Json) { $before | ConvertTo-Json -Depth 9 } else { Write-HumanState -State $before }
    if ($before.Compliant) { exit 0 } else { exit 1 }
}

if ($before.Compliant) {
    if ($Json) { $before | ConvertTo-Json -Depth 9 } else { Write-HumanState -State $before }
    exit 0
}
if (-not $ConfirmRemoval) {
    throw 'Debloat Ensure removes software and capabilities. Review Plan and Test, then repeat with -ConfirmRemoval.'
}

$snapshotPath = Save-DebloatSnapshot -State $before
$changes = [Collections.Generic.List[string]]::new()
$restartRequired = $false

foreach ($control in $profileConfiguration.AppxPackages) {
    $installed = @(Get-MatchingInstalledAppx -Inventory $inventory -Pattern $control.NamePattern)
    foreach ($package in @($installed | Sort-Object @{ Expression='IsBundle'; Descending=$true },PackageFullName -Unique)) {
        $stillPresent = @(Get-AppxPackage -AllUsers -PackageTypeFilter Main,Bundle |
            Where-Object PackageFullName -eq $package.PackageFullName)
        if ($stillPresent.Count -gt 0) {
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -Confirm:$false -ErrorAction Stop
            $changes.Add("AppX installed: $($package.Name)")
        }
    }

    $provisioned = @(Get-MatchingProvisionedAppx -Inventory $inventory -Pattern $control.NamePattern)
    foreach ($package in @($provisioned | Sort-Object PackageName -Unique)) {
        Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -AllUsers -ErrorAction Stop | Out-Null
        $changes.Add("AppX provisioned: $($package.DisplayName)")
    }
}

foreach ($control in $profileConfiguration.Capabilities) {
    $capabilityMatches = @($inventory.Capabilities | Where-Object { $_.Name -like $control.NamePattern -and $_.State -ne 'NotPresent' })
    foreach ($capability in $capabilityMatches) {
        $result = Remove-WindowsCapability -Online -Name $capability.Name -ErrorAction Stop
        $changes.Add("Capability: $($capability.Name)")
        if ($result.RestartNeeded) { $restartRequired = $true }
    }
}

foreach ($control in $profileConfiguration.OptionalFeatures) {
    $feature = @($inventory.OptionalFeatures | Where-Object FeatureName -eq $control.FeatureName | Select-Object -First 1)
    if ($feature.Count -gt 0 -and "$($feature[0].State)" -notin @('Disabled', 'DisabledWithPayloadRemoved')) {
        $result = Disable-WindowsOptionalFeature -Online -FeatureName $control.FeatureName -NoRestart -ErrorAction Stop
        $changes.Add("Optional feature: $($control.FeatureName)")
        if ($result.RestartNeeded) { $restartRequired = $true }
    }
}

$after = Get-DebloatState -Inventory (Get-DebloatInventory)
$after | Add-Member -NotePropertyName Changes -NotePropertyValue @($changes)
$after | Add-Member -NotePropertyName SnapshotPath -NotePropertyValue $snapshotPath
$after | Add-Member -NotePropertyName RestartRequired -NotePropertyValue $restartRequired
if (-not $after.Compliant) {
    if ($Json) { $after | ConvertTo-Json -Depth 9 } else { Write-HumanState -State $after -Changes @($changes) -SnapshotPath $snapshotPath }
    throw "Debloat profile did not converge; $($after.DriftCount) target(s) remain."
}

if ($Json) {
    $after | ConvertTo-Json -Depth 9
} else {
    Write-HumanState -State $after -Changes @($changes) -SnapshotPath $snapshotPath
    if ($restartRequired) { Write-Warning 'A Windows restart is required before every removal is fully effective.' }
}
