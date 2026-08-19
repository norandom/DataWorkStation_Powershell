[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Output and injected-command parameters are consumed by nested transaction functions.')]
[CmdletBinding()]
param(
    [switch] $Run,
    [switch] $ConfirmRestorePoints,
    [switch] $Json,
    [string] $ConfigurationPath,
    [Parameter(DontShow = $true)][switch] $PassThru,
    [Parameter(DontShow = $true)][scriptblock] $CommandRunner
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigurationPath)) { $ConfigurationPath = Join-Path $repositoryRoot 'config\windows-cleanup.psd1' }
$configuration = Import-PowerShellDataFile -LiteralPath ([IO.Path]::GetFullPath($ConfigurationPath))
if ([int] $configuration.SchemaVersion -ne 1) { throw "Unsupported Windows cleanup schema: $($configuration.SchemaVersion)" }
if ([string] $configuration.Volume -notmatch '^[A-Za-z]:$') { throw "Invalid cleanup volume: $($configuration.Volume)" }

$volumeCacheRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
$availableHandlers = if (Test-Path -LiteralPath $volumeCacheRoot) {
    @(Get-ChildItem -LiteralPath $volumeCacheRoot | Select-Object -ExpandProperty PSChildName)
} else { @() }
$missingHandlers = @($configuration.DiskCleanupHandlers | Where-Object { $_ -notin $availableHandlers })
$selectedHandlers = @($configuration.DiskCleanupHandlers | Where-Object { $_ -in $availableHandlers })

function Get-VolumeShadowCopyInventory {
    try {
        $drive = [string] $configuration.Volume
        $volume = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='$drive'" -ErrorAction Stop
        if (-not $volume) { throw "Volume $drive was not found." }
        $copies = @(Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop |
            Where-Object VolumeName -eq $volume.DeviceID |
            Sort-Object InstallDate)
        [pscustomobject]@{ Succeeded = $true; Copies = @($copies); Detail = "Shadow-copy inventory completed for $drive." }
    } catch {
        [pscustomobject]@{ Succeeded = $false; Copies = @(); Detail = "Shadow-copy inventory failed: $($_.Exception.Message)" }
    }
}

function Invoke-CleanupCommand {
    param([string] $FilePath, [string[]] $ArgumentList)
    if ($CommandRunner) {
        $response = & $CommandRunner ([pscustomobject]@{ FilePath = $FilePath; ArgumentList = @($ArgumentList) })
        if ($null -eq $response -or $response.PSObject.Properties.Name -notcontains 'ExitCode') { throw 'Synthetic cleanup command returned no ExitCode.' }
        if ([int] $response.ExitCode -ne 0) { throw "$FilePath failed with exit code $($response.ExitCode)." }
        return
    }
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) { throw "$FilePath failed with exit code $LASTEXITCODE." }
}

$shadowInventory = Get-VolumeShadowCopyInventory
$shadowCopies = @($shadowInventory.Copies)
$keepNewest = [int] $configuration.RestorePoints.KeepNewest
$shadowDeleteCount = [Math]::Max(0, $shadowCopies.Count - $keepNewest)
$actions = @(
    [pscustomobject]@{ Name = 'ComponentStore'; Enabled = [bool] $configuration.ComponentStoreCleanup; Detail = 'DISM StartComponentCleanup; ResetBase is excluded.' }
    [pscustomobject]@{ Name = 'DiskCleanup'; Enabled = $selectedHandlers.Count -gt 0; Detail = "$($selectedHandlers.Count) allowlisted handler(s) across the eligible volumes enumerated by cleanmgr /sagerun." }
    [pscustomobject]@{ Name = 'RestorePointsAndShadows'; Enabled = [bool] $configuration.RestorePoints.Enabled -and $shadowInventory.Succeeded -and $shadowDeleteCount -gt 0; Detail = if ($shadowInventory.Succeeded) { "Delete $shadowDeleteCount oldest $($configuration.Volume) shadow copy/copies and keep $keepNewest newest." } else { $shadowInventory.Detail } }
)
$result = [pscustomobject][ordered]@{
    SchemaVersion = 1
    Action = if ($Run) { 'Run' } else { 'Plan' }
    RequiresAdministrator = $true
    SystemVolume = [string] $configuration.Volume
    DiskCleanupScope = 'All eligible volumes enumerated by cleanmgr /sagerun'
    Actions = @($actions)
    SelectedDiskCleanupHandlers = @($selectedHandlers)
    MissingDiskCleanupHandlers = @($missingHandlers)
    Preserved = @($configuration.Preserved)
    ShadowCopiesFound = $shadowCopies.Count
    ShadowCopiesToDelete = $shadowDeleteCount
    ShadowInventorySucceeded = [bool] $shadowInventory.Succeeded
    ShadowInventoryDetail = [string] $shadowInventory.Detail
    RestorePointConfirmationRequired = [bool] $configuration.RestorePoints.Enabled -and $shadowInventory.Succeeded -and $shadowDeleteCount -gt 0
    Succeeded = $true
    Detail = if ($Run) { 'Cleanup completed.' } else { 'No files, restore points, shadow copies, event logs, or caches were changed.' }
}

function Write-CleanupResult {
    param([object] $Value)
    if ($PassThru) { $Value; return }
    if ($Json) { $Value | ConvertTo-Json -Depth 7; return }
    Write-Host "Windows cleanup $($Value.Action.ToLowerInvariant()); system volume $($Value.SystemVolume)"
    $Value.Actions | Format-Table Name, Enabled, Detail -AutoSize -Wrap
    Write-Host "Disk Cleanup scope: $($Value.DiskCleanupScope)"
    Write-Host "Disk Cleanup handlers: $($Value.SelectedDiskCleanupHandlers -join ', ')"
    Write-Host "Preserved: $($Value.Preserved -join ', ')"
    Write-Host $Value.Detail
    if ($Value.RestorePointConfirmationRequired -and -not $Run) { Write-Host 'Restore-point cleanup requires: cleanup-windows -Run -ConfirmRestorePoints' }
}

if (-not $Run) { Write-CleanupResult $result; return }
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run through the cleanup-windows profile command or sudo.'
}
if ([bool] $configuration.RestorePoints.Enabled -and -not $shadowInventory.Succeeded) {
    throw "Cleanup cannot run while restore-point and shadow-copy inventory is unavailable. $($shadowInventory.Detail)"
}
if ($result.RestorePointConfirmationRequired -and -not $ConfirmRestorePoints) {
    throw 'The profile includes deletion of old restore points and shadow copies. Add -ConfirmRestorePoints or run the plan without -Run.'
}

if ($configuration.ComponentStoreCleanup) {
    Invoke-CleanupCommand -FilePath "$env:SystemRoot\System32\Dism.exe" -ArgumentList @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/NoRestart')
}

if ($selectedHandlers.Count -gt 0) {
    $propertyName = 'StateFlags{0:D4}' -f [int] $configuration.StateFlag
    $originalValues = @{}
    try {
        foreach ($handler in $availableHandlers) {
            $key = Join-Path $volumeCacheRoot $handler
            $property = Get-ItemProperty -LiteralPath $key -Name $propertyName -ErrorAction Ignore
            if ($property) { $originalValues[$key] = [int] $property.$propertyName }
            $value = if ($handler -in $selectedHandlers) { 2 } else { 0 }
            New-ItemProperty -LiteralPath $key -Name $propertyName -PropertyType DWord -Value $value -Force | Out-Null
        }
        Invoke-CleanupCommand -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList @("/sagerun:$([int] $configuration.StateFlag)")
    } finally {
        foreach ($handler in $availableHandlers) {
            $key = Join-Path $volumeCacheRoot $handler
            if ($originalValues.ContainsKey($key)) {
                Set-ItemProperty -LiteralPath $key -Name $propertyName -Value $originalValues[$key]
            } else {
                Remove-ItemProperty -LiteralPath $key -Name $propertyName -ErrorAction Ignore
            }
        }
    }
}

if ($result.RestorePointConfirmationRequired) {
    for ($index = 0; $index -lt $shadowDeleteCount; $index++) {
        Invoke-CleanupCommand -FilePath "$env:SystemRoot\System32\vssadmin.exe" -ArgumentList @('delete', 'shadows', "/for=$($configuration.Volume)", '/oldest', '/quiet')
    }
}

$remainingInventory = Get-VolumeShadowCopyInventory
if (-not $remainingInventory.Succeeded) { throw "Cleanup completed, but shadow-copy verification failed. $($remainingInventory.Detail)" }
$remainingShadows = @($remainingInventory.Copies)
if ($remainingShadows.Count -gt [Math]::Max($keepNewest, $shadowCopies.Count - $shadowDeleteCount)) {
    throw 'Restore-point and shadow-copy cleanup did not converge to the planned count.'
}
$result.Detail = "Cleanup completed; $($remainingShadows.Count) shadow copy/copies remain on $($configuration.Volume)."
Write-CleanupResult $result
