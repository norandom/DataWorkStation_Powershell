[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Start', 'Check', 'Stop')]
    [string] $Action,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
    [string] $Name,

    [string] $Executable,
    [string] $WorkingDirectory = (Get-Location).Path,
    [ValidateRange(1, 1000)]
    [int] $MaxEvents = 100
)

$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}

$workingRoot = [IO.Path]::GetFullPath($WorkingDirectory)
if (-not (Test-Path -LiteralPath $workingRoot -PathType Container)) {
    throw "Development directory does not exist: $workingRoot"
}
$sessionRoot = [IO.Path]::GetFullPath((Join-Path $workingRoot "eventlog-$Name"))
if (-not $sessionRoot.StartsWith($workingRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The resolved event-log session path is outside the development directory.'
}
$sessionFile = Join-Path $sessionRoot 'session.json'
$eventsDirectory = Join-Path $sessionRoot 'events'
$dumpsDirectory = Join-Path $sessionRoot 'dumps'
$werBackup = Join-Path $sessionRoot 'wer-before.reg'
$werBasePath = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
$channels = @(
    'Application'
    'System'
    'Microsoft-Windows-WER-Diag/Operational'
    'Microsoft-Windows-WER-PayloadHealth/Operational'
    'Microsoft-Windows-Fault-Tolerant-Heap/Operational'
    'Microsoft-Windows-CodeIntegrity/Operational'
    'Microsoft-Windows-CodeIntegrity/Verbose'
    'Microsoft-Windows-Application-Experience/Program-Telemetry'
    'Microsoft-Windows-Resource-Exhaustion-Detector/Operational'
    'Microsoft-Windows-Kernel-WHEA/Operational'
)

function Save-Session {
    param($Session)
    $Session | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sessionFile -Encoding UTF8
}

function Read-Session {
    if (-not (Test-Path -LiteralPath $sessionFile -PathType Leaf)) {
        throw "No event-log session named '$Name' exists under: $workingRoot"
    }
    return Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
}

function Get-ChannelState {
    $states = @()
    foreach ($channel in $channels) {
        try {
            $log = Get-WinEvent -ListLog $channel -ErrorAction Stop
            $states += [pscustomobject]@{
                Name = $channel
                Available = $true
                Enabled = [bool]$log.IsEnabled
                MaximumSizeInBytes = [int64]$log.MaximumSizeInBytes
                LogMode = "$($log.LogMode)"
                LogType = "$($log.LogType)"
            }
        } catch {
            $states += [pscustomobject]@{ Name = $channel; Available = $false }
        }
    }
    return $states
}

function Invoke-Wevtutil {
    param([Parameter(Mandatory = $true)][string[]] $Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & "$env:SystemRoot\System32\wevtutil.exe" @Arguments 2>$null | Out-Null
        return [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Set-ChannelDiagnosticState {
    param($ChannelStates)
    foreach ($channel in @($ChannelStates | Where-Object Available)) {
        if ($channel.LogType -in 'Analytical', 'Debug') {
            if (-not $channel.Enabled) {
                $exitCode = Invoke-Wevtutil -Arguments @('sl', $channel.Name, '/e:true')
                if ($exitCode -ne 0) { Write-Warning "Could not enable diagnostic channel: $($channel.Name)" }
            }
            continue
        }
        $size = [math]::Max([int64]$channel.MaximumSizeInBytes, 64MB)
        $exitCode = Invoke-Wevtutil -Arguments @('sl', $channel.Name, '/rt:false', '/ab:false', "/ms:$size")
        if ($exitCode -ne 0) {
            Write-Warning "Could not configure diagnostic channel: $($channel.Name)"
            continue
        }
        if (-not $channel.Enabled) {
            $exitCode = Invoke-Wevtutil -Arguments @('sl', $channel.Name, '/e:true')
            if ($exitCode -ne 0) { Write-Warning "Could not enable diagnostic channel: $($channel.Name)" }
        }
    }
}

function Restore-ChannelState {
    param($ChannelStates)
    foreach ($channel in @($ChannelStates | Where-Object Available)) {
        if ($channel.LogType -notin 'Analytical', 'Debug') {
            $retention = $channel.LogMode -ne 'Circular'
            $autoBackup = $channel.LogMode -eq 'AutoBackup'
            $exitCode = Invoke-Wevtutil -Arguments @('sl', $channel.Name, "/rt:$($retention.ToString().ToLowerInvariant())", "/ab:$($autoBackup.ToString().ToLowerInvariant())", "/ms:$($channel.MaximumSizeInBytes)")
            if ($exitCode -ne 0) { Write-Warning "Could not restore channel configuration: $($channel.Name)" }
        }
        $current = Get-WinEvent -ListLog $channel.Name -ErrorAction Ignore
        if ($current -and [bool]$current.IsEnabled -ne [bool]$channel.Enabled) {
            $exitCode = Invoke-Wevtutil -Arguments @('sl', $channel.Name, "/e:$($channel.Enabled.ToString().ToLowerInvariant())")
            if ($exitCode -ne 0) { Write-Warning "Could not restore channel enablement: $($channel.Name)" }
        }
    }
}

function Get-SessionEvents {
    param($Session)
    $started = [datetime]$Session.StartedUtc
    $rows = @()
    foreach ($channel in @($Session.Channels | Where-Object Available)) {
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = "$($channel.Name)"; StartTime = $started } -Oldest -ErrorAction Ignore)
        if ($channel.Name -in 'Application', 'System') {
            $events = @($events | Where-Object { $_.Level -le 3 -or $_.Id -in 41,1000,1001,1002,1026,6008 })
        }
        foreach ($eventRecord in $events) {
            $rows += [pscustomobject]@{
                Time = $eventRecord.TimeCreated
                Level = $eventRecord.LevelDisplayName
                Id = $eventRecord.Id
                Provider = $eventRecord.ProviderName
                Log = $eventRecord.LogName
                Message = ("$($eventRecord.Message)" -replace '\r?\n', ' ').Trim()
            }
        }
    }
    return @($rows | Sort-Object Time -Descending)
}

function Restore-WerState {
    param($Session)
    $imageName = "$($Session.Executable)"
    if (-not $imageName -or $imageName -notmatch '^[^\\/:*?"<>|]+\.exe$') { return }
    $keyPath = Join-Path $werBasePath $imageName
    if (Test-Path -LiteralPath $keyPath) { Remove-Item -LiteralPath $keyPath -Recurse -Force }
    if ($Session.WerKeyExisted -and (Test-Path -LiteralPath $werBackup -PathType Leaf)) {
        & "$env:SystemRoot\System32\reg.exe" import $werBackup | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning "Could not restore prior WER settings for $imageName." }
    }
    if (-not $Session.WerBaseExisted -and (Test-Path -LiteralPath $werBasePath)) {
        $children = @(Get-ChildItem -LiteralPath $werBasePath -ErrorAction Ignore)
        $values = @((Get-Item -LiteralPath $werBasePath).GetValueNames())
        if ($children.Count -eq 0 -and $values.Count -eq 0) { Remove-Item -LiteralPath $werBasePath -Force }
    }
}

if ($Action -eq 'Start') {
    if (-not $Executable) { throw 'Start requires -Executable, for example mytool.exe.' }
    $imageName = Split-Path -Leaf $Executable
    if ($imageName -notmatch '^[^\\/:*?"<>|]+\.exe$') { throw 'Executable must resolve to a valid .exe image name.' }
    if (Test-Path -LiteralPath $sessionRoot) {
        throw "Session directory already exists; choose another name or move it first: $sessionRoot"
    }

    New-Item -ItemType Directory -Path $eventsDirectory,$dumpsDirectory -Force | Out-Null
    $channelState = @(Get-ChannelState)
    $werKeyPath = Join-Path $werBasePath $imageName
    $werNativePath = "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps\$imageName"
    $werKeyExisted = Test-Path -LiteralPath $werKeyPath
    $werBaseExisted = Test-Path -LiteralPath $werBasePath
    if ($werKeyExisted) {
        & "$env:SystemRoot\System32\reg.exe" export $werNativePath $werBackup /y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not back up existing WER settings for $imageName." }
    }

    $session = [pscustomobject]@{
        Name = $Name
        Status = 'Active'
        StartedUtc = (Get-Date).ToUniversalTime().ToString('o')
        WorkingDirectory = $workingRoot
        SessionDirectory = $sessionRoot
        Executable = $imageName
        WerKeyExisted = $werKeyExisted
        WerBaseExisted = $werBaseExisted
        WprInstance = ('DevEventLog_' + ($Name -replace '[^A-Za-z0-9_]', '_'))
        WprStarted = $false
        Channels = $channelState
    }
    Save-Session $session

    try {
        Set-ChannelDiagnosticState $channelState
        New-Item -Path $werKeyPath -Force | Out-Null
        New-ItemProperty -LiteralPath $werKeyPath -Name DumpFolder -PropertyType ExpandString -Value $dumpsDirectory -Force | Out-Null
        New-ItemProperty -LiteralPath $werKeyPath -Name DumpCount -PropertyType DWord -Value 5 -Force | Out-Null
        New-ItemProperty -LiteralPath $werKeyPath -Name DumpType -PropertyType DWord -Value 2 -Force | Out-Null
        if (Get-Command wpr.exe -CommandType Application -ErrorAction Ignore) {
            & wpr.exe -start GeneralProfile -instancename $session.WprInstance 2>$null
            if ($LASTEXITCODE -eq 0) {
                $session.WprStarted = $true
                Save-Session $session
            } else {
                Write-Warning 'WPR could not start; EVTX and WER dump capture remain active.'
            }
        }
    } catch {
        if ($session.WprStarted) { & wpr.exe -cancel -instancename $session.WprInstance 2>$null | Out-Null }
        Restore-ChannelState $channelState
        Restore-WerState $session
        throw
    }

    Write-Host "Development event-log session started: $sessionRoot"
    Write-Host "Full crash dumps enabled for: $imageName"
    if ($session.WprStarted) { Write-Host 'ETW/WPR first-level triage capture is active.' }
    Write-Host "Reproduce the failure, then run: eventlog-check $Name; eventlog-stop $Name"
    exit 0
}

$session = Read-Session
if ($Action -eq 'Check') {
    $rows = @(Get-SessionEvents $session)
    $rows | Select-Object -First $MaxEvents
    Write-Host "Crash dumps: $(@(Get-ChildItem -LiteralPath $dumpsDirectory -Filter '*.dmp' -File -ErrorAction Ignore).Count)"
    if ($session.WprStarted) { & wpr.exe -status -instancename $session.WprInstance 2>$null }
    exit 0
}

$exportErrors = @()
try {
    if ($session.WprStarted) {
        $etlPath = Join-Path $sessionRoot 'trace.etl'
        & wpr.exe -stop $etlPath "Development crash session: $Name ($($session.Executable))" -compress -instancename $session.WprInstance 2>$null
        if ($LASTEXITCODE -ne 0) { $exportErrors += 'WPR/ETW trace' }
    }
    $started = [datetime]$session.StartedUtc
    $windowMilliseconds = [math]::Ceiling(((Get-Date).ToUniversalTime() - $started.ToUniversalTime()).TotalMilliseconds) + 60000
    $query = "*[System[TimeCreated[timediff(@SystemTime) <= $windowMilliseconds]]]"
    foreach ($channel in @($session.Channels | Where-Object Available)) {
        $safeName = $channel.Name -replace '[^A-Za-z0-9._-]', '_'
        $destination = Join-Path $eventsDirectory "$safeName.evtx"
        & "$env:SystemRoot\System32\wevtutil.exe" epl $channel.Name $destination "/q:$query" /ow:true 2>$null
        if ($LASTEXITCODE -ne 0) { $exportErrors += $channel.Name }
    }
    $rows = @(Get-SessionEvents $session)
    $rows | Export-Csv -LiteralPath (Join-Path $eventsDirectory 'events.csv') -NoTypeInformation -Encoding UTF8
    $rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $eventsDirectory 'events.json') -Encoding UTF8
} finally {
    Restore-ChannelState $session.Channels
    Restore-WerState $session
}

$session.Status = 'Completed'
$session | Add-Member -NotePropertyName CompletedUtc -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
Save-Session $session
Write-Host "Development event-log session stopped and previous logging state restored: $sessionRoot"
Write-Host "Events: $eventsDirectory"
Write-Host "Crash dumps: $dumpsDirectory"
if (Test-Path -LiteralPath (Join-Path $sessionRoot 'trace.etl')) { Write-Host "ETW trace: $(Join-Path $sessionRoot 'trace.etl')" }
if ($exportErrors.Count) {
    Write-Warning "Some channels could not be exported: $($exportErrors -join ', ')"
    exit 1
}
