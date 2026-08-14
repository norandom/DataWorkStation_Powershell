[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$configuration = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\config\windows-features.psd1')
$declaredFeatures = @($configuration.WindowsOptionalFeatures)
if ($declaredFeatures.Count -eq 0) { throw 'No Windows optional features are declared.' }

function Resolve-DeclaredFeatureOrder {
    $featureById = @{}
    foreach ($feature in $declaredFeatures) {
        if (-not $feature.Id) { throw "Windows feature '$($feature.DisplayName)' has no Id." }
        if ($featureById.ContainsKey($feature.Id)) { throw "Duplicate Windows feature Id '$($feature.Id)'." }
        $featureById[$feature.Id] = $feature
    }

    $resolved = [Collections.Generic.List[object]]::new()
    $visiting = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    function Add-FeatureWithDependencies {
        param([Parameter(Mandatory)][string] $Id)

        if ($visited.Contains($Id)) { return }
        if (-not $featureById.ContainsKey($Id)) { throw "Unknown Windows feature dependency '$Id'." }
        if (-not $visiting.Add($Id)) { throw "Windows feature dependency cycle detected at '$Id'." }
        foreach ($dependencyId in @($featureById[$Id].DependsOn)) {
            Add-FeatureWithDependencies -Id $dependencyId
        }
        [void] $visiting.Remove($Id)
        [void] $visited.Add($Id)
        $resolved.Add($featureById[$Id])
    }

    foreach ($feature in $declaredFeatures) {
        Add-FeatureWithDependencies -Id $feature.Id
    }
    return $resolved
}

$features = @(Resolve-DeclaredFeatureOrder)
if ($Mode -eq 'Plan') {
    $position = 0
    $features | ForEach-Object {
        $position++
        [pscustomobject]@{
            Order = $position
            Id = $_.Id
            DisplayName = $_.DisplayName
            FeatureName = $_.FeatureName
            DependsOn = @($_.DependsOn) -join ', '
        }
    } | Format-Table -AutoSize
    exit 0
}

$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}

function Get-DeclaredFeatureState {
    foreach ($feature in $features) {
        $current = Get-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName
        [pscustomobject]@{
            Id = $feature.Id
            DisplayName = $feature.DisplayName
            FeatureName = $feature.FeatureName
            State = [string] $current.State
        }
    }
}

$states = @(Get-DeclaredFeatureState)
if ($Mode -eq 'Test') {
    $states | Format-Table -AutoSize
    if (@($states | Where-Object State -ne 'Enabled').Count -gt 0) { exit 1 }
    exit 0
}

$restartRequired = $false
foreach ($feature in $features) {
    $current = $states | Where-Object FeatureName -eq $feature.FeatureName | Select-Object -First 1
    if ($current.State -eq 'Enabled') { continue }
    if ($current.State -eq 'EnablePending') {
        $restartRequired = $true
        continue
    }

    $enableParameters = @{
        Online = $true
        FeatureName = $feature.FeatureName
        NoRestart = $true
    }
    if ($feature.IncludeAllParents) { $enableParameters.All = $true }
    $result = Enable-WindowsOptionalFeature @enableParameters
    if ($result.RestartNeeded) { $restartRequired = $true }
}

$states = @(Get-DeclaredFeatureState)
$unresolved = @($states | Where-Object State -notin @('Enabled', 'EnablePending'))
if ($unresolved.Count -gt 0) {
    throw "Windows optional-feature drift remains: $($unresolved.FeatureName -join ', ')."
}

$states | Format-Table -AutoSize
if ($restartRequired -or @($states | Where-Object State -eq 'EnablePending').Count -gt 0) {
    Write-Warning 'A Windows restart is required before all declared optional features are active.'
}
Write-Host "Windows optional-feature state '$Mode' completed successfully."
