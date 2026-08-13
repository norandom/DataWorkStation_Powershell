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

$configurationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\config\eventlogs.psd1'))
$exportScriptPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Export-EventLogs.ps1'))
$configuration = Import-PowerShellDataFile -LiteralPath $configurationPath
$managedRoot = Join-Path $env:ProgramData 'LinuxShell\EventLogs'
$managedBin = Join-Path $managedRoot 'bin'
$managedExporter = Join-Path $managedBin 'Export-EventLogs.ps1'
$managedConfiguration = Join-Path $managedBin 'eventlogs.psd1'
$archiveRoot = [Environment]::ExpandEnvironmentVariables($configuration.ArchiveRoot)
$taskPath = '\LinuxShell\'
$taskName = 'EventLogArchive'

function Test-AuditSetting {
    param($Setting)
    $rows = @(& "$env:SystemRoot\System32\auditpol.exe" /get "/subcategory:$($Setting.Guid)" /r | ConvertFrom-Csv)
    if ($rows.Count -eq 0) { return $false }
    $value = "$($rows[0].'Inclusion Setting')"
    if ($Setting.Success -and $value -notmatch 'Success') { return $false }
    if ($Setting.Failure -and $value -notmatch 'Failure') { return $false }
    return $true
}

function Get-StateDrift {
    $issues = [Collections.Generic.List[string]]::new()
    foreach ($channel in $configuration.Channels) {
        try { $log = Get-WinEvent -ListLog $channel.Name -ErrorAction Stop } catch {
            $issues.Add("Unavailable channel: $($channel.Name)")
            continue
        }
        if ($channel.Enable -and -not $log.IsEnabled) { $issues.Add("Disabled channel: $($channel.Name)") }
        if ($log.MaximumSizeInBytes -lt ([int64]$channel.MaxSizeMiB * 1MB)) { $issues.Add("Undersized channel: $($channel.Name)") }
        if ("$($log.LogMode)" -ne 'Circular') { $issues.Add("Non-circular channel: $($channel.Name)") }
    }
    foreach ($audit in $configuration.AuditSubcategories) {
        if (-not (Test-AuditSetting $audit)) { $issues.Add("Audit policy drift: $($audit.Name)") }
    }
    if ((Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name ProcessCreationIncludeCmdLine_Enabled -ErrorAction Ignore) -ne 1) {
        $issues.Add('Process command-line auditing is disabled.')
    }
    if ((Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name EnableScriptBlockLogging -ErrorAction Ignore) -ne 1) {
        $issues.Add('PowerShell script-block logging is disabled.')
    }
    if (-not (Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Ignore)) { $issues.Add('Event-log archive task is missing.') }
    return $issues
}

$drift = @(Get-StateDrift)
if ($Mode -eq 'Test') {
    if ($drift.Count -eq 0) { Write-Host 'Event-log collection and 14-day archive policy: compliant.'; exit 0 }
    Write-Host 'Event-log policy drift detected.'
    $drift | ForEach-Object { Write-Host "- $_" }
    exit 1
}

if ($Mode -eq 'Ensure' -and $drift.Count -eq 0) {
    Write-Host 'Event-log collection and 14-day archive policy are already active; no changes were made.'
    exit 0
}

foreach ($channel in $configuration.Channels) {
    try { Get-WinEvent -ListLog $channel.Name -ErrorAction Stop | Out-Null } catch {
        Write-Warning "Skipping unavailable channel: $($channel.Name)"
        continue
    }
    $arguments = @('sl', $channel.Name, '/rt:false', '/ab:false', "/ms:$([int64]$channel.MaxSizeMiB * 1MB)")
    if ($channel.Enable) { $arguments += '/e:true' }
    & "$env:SystemRoot\System32\wevtutil.exe" @arguments
    if ($LASTEXITCODE -ne 0) { throw "wevtutil failed for $($channel.Name) with exit code $LASTEXITCODE." }
}

foreach ($audit in $configuration.AuditSubcategories) {
    $arguments = @('/set', "/subcategory:$($audit.Guid)")
    if ($audit.Success) { $arguments += '/success:enable' }
    if ($audit.Failure) { $arguments += '/failure:enable' }
    & "$env:SystemRoot\System32\auditpol.exe" @arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "auditpol failed for $($audit.Name) with exit code $LASTEXITCODE." }
}

$processAuditPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
New-Item -Path $processAuditPath -Force | Out-Null
New-ItemProperty -LiteralPath $processAuditPath -Name ProcessCreationIncludeCmdLine_Enabled -PropertyType DWord -Value 1 -Force | Out-Null
$scriptBlockPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
New-Item -Path $scriptBlockPath -Force | Out-Null
New-ItemProperty -LiteralPath $scriptBlockPath -Name EnableScriptBlockLogging -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -LiteralPath $scriptBlockPath -Name EnableScriptBlockInvocationLogging -PropertyType DWord -Value 0 -Force | Out-Null

New-Item -ItemType Directory -Path $managedBin -Force | Out-Null
New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
Copy-Item -LiteralPath $exportScriptPath -Destination $managedExporter -Force
Copy-Item -LiteralPath $configurationPath -Destination $managedConfiguration -Force

$acl = [Security.AccessControl.DirectorySecurity]::new()
$acl.SetAccessRuleProtection($true, $false)
$inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
$propagation = [Security.AccessControl.PropagationFlags]::None
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new('SYSTEM','FullControl',$inheritance,$propagation,'Allow'))
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new('BUILTIN\Administrators','FullControl',$inheritance,$propagation,'Allow'))
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.WindowsIdentity]::GetCurrent().User,'ReadAndExecute',$inheritance,$propagation,'Allow'))
Set-Acl -LiteralPath $managedRoot -AclObject $acl
Set-Acl -LiteralPath $archiveRoot -AclObject $acl

$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$managedExporter`""
$trigger = New-ScheduledTaskTrigger -Daily -At '03:00'
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Export relevant Windows event logs and retain generated archives for 14 days.' -Force | Out-Null

$remaining = @(Get-StateDrift)
if ($remaining.Count -gt 0) { throw "Event-log policy did not converge: $($remaining -join ' ')" }
Write-Host 'Event-log collection and 14-day archive policy: compliant.'
