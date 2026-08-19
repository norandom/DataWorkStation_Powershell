[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}

$configurationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\config\defender-exclusions.psd1'))
$configuration = Import-PowerShellDataFile -LiteralPath $configurationPath
$desiredPreferences = $configuration.Preferences
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'Import-WorkstationConfiguration.ps1')
$localConfiguration = Import-WorkstationConfiguration -RepositoryRoot $repositoryRoot
$declaredPaths = @($localConfiguration.Defender.Exclusions)

$desiredPaths = @($declaredPaths | ForEach-Object {
    $expanded = [regex]::Replace($_, '(?i)\$(?:HOME|USERPROFILE)(?=\\|/|$)', { $env:USERPROFILE })
    $expanded = [Environment]::ExpandEnvironmentVariables($expanded)
    if ($expanded -match '%[^%]+%' -or $expanded -match '(?i)\$(?:HOME|USERPROFILE)') {
        throw "Defender exclusion path contains an unresolved variable in $($localConfiguration.ConfigurationPath): $_"
    }
    if (-not (Test-Path -LiteralPath $expanded)) {
        throw "Defender exclusion path does not exist: $expanded"
    }
    (Resolve-Path -LiteralPath $expanded).Path.TrimEnd('\') + $(if ($expanded -match '^[A-Za-z]:\\$') { '\' } else { '' })
} | Sort-Object -Unique)

function Get-CurrentExclusions {
    @((Get-MpPreference).ExclusionPath | Where-Object { $_ -and $_ -notlike 'N/A:*' })
}

function Test-PathIncluded {
    param([string] $Path, [string[]] $Current)
    return @($Current | Where-Object { $_.TrimEnd('\') -ieq $Path.TrimEnd('\') }).Count -gt 0
}

$currentPaths = @(Get-CurrentExclusions)
$missingPaths = @($desiredPaths | Where-Object { -not (Test-PathIncluded -Path $_ -Current $currentPaths) })
$currentPreference = Get-MpPreference
$driftedPreferences = @($configuration.Preferences.GetEnumerator() | Where-Object {
    $actual = $currentPreference.($_.Key)
    "$actual" -ine "$($_.Value)"
})

if ($Mode -eq 'Test') {
    if ($missingPaths.Count -eq 0 -and $driftedPreferences.Count -eq 0) {
        Write-Host 'Microsoft Defender exclusions and performance policy: compliant.'
        exit 0
    }
    Write-Host 'Microsoft Defender exclusions or performance policy: drift detected.'
    $missingPaths | ForEach-Object { Write-Host "- Missing: $_" }
    $driftedPreferences | ForEach-Object { Write-Host "- $($_.Key): actual '$($currentPreference.($_.Key))', desired '$($_.Value)'" }
    exit 1
}

if ($Mode -eq 'Reinitialize') {
    foreach ($path in $desiredPaths) {
        if (Test-PathIncluded -Path $path -Current $currentPaths) {
            Remove-MpPreference -ExclusionPath $path
        }
    }
    $missingPaths = $desiredPaths
}

foreach ($path in $missingPaths) {
    Add-MpPreference -ExclusionPath $path
    Write-Host "Added Microsoft Defender path exclusion: $path"
}

if ($driftedPreferences.Count -gt 0 -or $Mode -eq 'Reinitialize') {
    Set-MpPreference @desiredPreferences
    Write-Host 'Applied the Microsoft Defender low-impact performance policy.'
}

$remaining = @($desiredPaths | Where-Object { -not (Test-PathIncluded -Path $_ -Current @(Get-CurrentExclusions)) })
if ($remaining.Count -gt 0) {
    throw "Microsoft Defender exclusions did not converge: $($remaining -join ', ')"
}
$verifiedPreference = Get-MpPreference
$remainingPreferenceDrift = @($configuration.Preferences.GetEnumerator() | Where-Object {
    "$($verifiedPreference.($_.Key))" -ine "$($_.Value)"
})
if ($remainingPreferenceDrift.Count -gt 0) {
    throw "Microsoft Defender performance policy did not converge: $($remainingPreferenceDrift.Key -join ', ')"
}
if ($missingPaths.Count -eq 0 -and $driftedPreferences.Count -eq 0 -and $Mode -ne 'Reinitialize') {
    Write-Host 'Microsoft Defender exclusions and performance policy are already active; no changes were made.'
} else {
    Write-Host 'Microsoft Defender exclusions and performance policy: compliant.'
}
