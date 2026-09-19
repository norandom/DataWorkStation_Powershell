[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Start', 'Stop', 'Status', 'Summary')][string] $Action,
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string] $Name,
    [string] $ProcessName,
    [ValidateRange(1, 2147483647)][int] $ProcessId,
    [Alias('Profile')][ValidateSet('HttpAuth', 'TlsHandshake')][string] $CaptureProfile = 'HttpAuth',
    [ValidateRange(5, 600)][int] $Seconds = 90,
    [ValidateRange(16, 256)][int] $MaxSizeMiB = 32,
    [string] $WorkingDirectory,
    [string] $ConfigurationPath,
    [string] $HostName,
    [datetime] $From = [datetime]::MinValue,
    [datetime] $To = [datetime]::MaxValue,
    [switch] $FailuresOnly,
    [switch] $Plan,
    [switch] $Json
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Import-WorkstationConfiguration.ps1')
. (Join-Path $PSScriptRoot 'HttpDiagnostics.ps1')
if (-not $WorkingDirectory) { $WorkingDirectory = (Import-WorkstationConfiguration -ConfigurationPath $ConfigurationPath).Paths.Traces }
$root = [IO.Path]::GetFullPath($WorkingDirectory)
$directory = Join-Path $root "http-$Name"
$sessionFile = Join-Path $directory 'session.json'
if ($ProcessName -and $ProcessId) { throw 'Use ProcessName or ProcessId, not both.' }
if ($From -gt $To) { throw 'From must precede To.' }
if ($Plan -and $Action -ne 'Start') { throw 'Plan is only available for Start.' }

function Write-HttpResult {
    param($Value, [switch] $AsJson)
    if ($AsJson) { $Value | ConvertTo-Json -Depth 10 } else {
        $Value | Select-Object * -ExcludeProperty Requests, Transport | Format-List
        if ($Value.PSObject.Properties['Requests']) { $Value.Requests | Format-Table StartedUtc, ProcessId, Method, HostName, StatusCode, DurationMs -AutoSize }
        if ($Value.PSObject.Properties['Transport']) { $Value.Transport | Format-Table -AutoSize }
    }
}
function Invoke-HttpLogman {
    param([string[]] $Arguments, [switch] $AllowFailure)
    & logman.exe @Arguments 2>&1 | Out-Null
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) { throw "Logman operation '$($Arguments[0])' failed (exit $code)." }
    $code
}

if ($Action -eq 'Start') {
    if (-not $ProcessName -and -not $ProcessId) { throw 'Start requires ProcessName or ProcessId.' }
    $targets = @(if ($ProcessId) { Get-Process -Id $ProcessId } else { Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($ProcessName)) -ErrorAction SilentlyContinue })
    $targetRecords = @($targets | ForEach-Object {
        [pscustomobject]@{ ProcessId = $_.Id; Name = $_.ProcessName; StartedUtc = $_.StartTime.ToUniversalTime().ToString('o'); Executable = $_.Path; Version = $_.FileVersion }
    })
    $session = [pscustomobject]@{
        SchemaVersion = 1; Name = $Name; Collector = ('HttpDiag-' + [guid]::NewGuid().ToString('N'))
        Status = 'Planned'; StartedUtc = $null; Profile = $CaptureProfile; Seconds = $Seconds; MaxSizeMiB = $MaxSizeMiB
        ProcessName = $ProcessName; Targets = $targetRecords; CaptureDirectory = $directory
        CaptureScope = 'System-wide WebIO and process lifecycle ETW; process selection applies only to summary'
        ContainsSecrets = $true; RequiresAdministrator = $true
        Context = @{ User = [Security.Principal.WindowsIdentity]::GetCurrent().Name; Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value; Repository = (Split-Path $PSScriptRoot); PowerShell = $PSVersionTable.PSVersion.ToString() }
    }
    if ($Plan) { Write-HttpResult $session -AsJson:$Json; return }
    if (Test-Path -LiteralPath $directory) { throw 'Capture directory exists; choose a new Name.' }
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Start requires administrator rights; use sudo.' }
    # Validate provider availability before recording. This does not establish event coverage.
    Get-WinEvent -ListProvider Microsoft-Windows-WebIO -ErrorAction Stop | Out-Null
    Get-WinEvent -ListProvider Microsoft-Windows-Kernel-Process -ErrorAction Stop | Out-Null
    New-Item -ItemType Directory -Path $directory | Out-Null
    $flags = if ($CaptureProfile -eq 'HttpAuth') { '0xffffffffffffffff' } else { '0x0000002000000000' }
    $providers = Join-Path $directory 'providers.txt'
    @("Microsoft-Windows-WebIO $flags 5", 'Microsoft-Windows-Kernel-Process 0x10 5') | Set-Content -LiteralPath $providers -Encoding ascii
    $duration = [timespan]::FromSeconds($Seconds).ToString('hh\:mm\:ss')
    try {
        Invoke-HttpLogman -Arguments @('create', 'trace', $session.Collector, '-ln', $session.Collector, '-pf', $providers, '-o', (Join-Path $directory 'capture.etl'), '-f', 'bincirc', '-max', "$MaxSizeMiB", '-rf', $duration, '-ft', '1') | Out-Null
        $session.StartedUtc = [datetime]::UtcNow.ToString('o')
        $session.Status = 'Starting'
        $session | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sessionFile -Encoding utf8
        Invoke-HttpLogman -Arguments @('start', $session.Collector) | Out-Null
        $session.Status = 'Active'
    } catch {
        Invoke-HttpLogman -Arguments @('stop', $session.Collector) -AllowFailure | Out-Null
        Invoke-HttpLogman -Arguments @('delete', $session.Collector) -AllowFailure | Out-Null
        throw
    }
    $session | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sessionFile -Encoding utf8
    Write-HttpResult $session -AsJson:$Json
    return
}
$session = Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
if ($session.Collector -notmatch '^HttpDiag-[a-f0-9]{32}$') { throw 'Unrecognized collector identity.' }
if ($Action -in @('Stop', 'Status')) {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Stop and Status require administrator rights; use sudo.' }
    $running = (Invoke-HttpLogman -Arguments @('query', $session.Collector, '-ets') -AllowFailure) -eq 0
    if ($Action -eq 'Stop' -and $session.Status -ne 'Completed') {
        if ($running) { Invoke-HttpLogman -Arguments @('stop', $session.Collector) | Out-Null }
        $exists = (Invoke-HttpLogman -Arguments @('query', $session.Collector) -AllowFailure) -eq 0
        if ($exists) { Invoke-HttpLogman -Arguments @('delete', $session.Collector) | Out-Null }
        $session.Status = 'Completed'
        $session | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sessionFile -Encoding utf8
    } elseif ($Action -eq 'Status') {
        $session.Status = if ($running) { 'Active' } elseif ($session.Status -eq 'Completed') { 'Completed' } else { 'Stopped; run Stop to remove collector' }
    }
    Write-HttpResult $session -AsJson:$Json
    return
}
$traces = @(Get-ChildItem -LiteralPath $directory -Filter '*.etl' -File)
if ($traces.Count -eq 0) { throw 'No ETL found; capture has not produced evidence.' }
$events = @(foreach ($trace in $traces) {
    Get-WinEvent -Path $trace.FullName -Oldest -ErrorAction Stop | ForEach-Object { ConvertTo-HttpEvent $_ }
})
$analysis = Get-HttpTraceAnalysis -Events $events -Targets @($session.Targets) -ProcessName $session.ProcessName -HostName $HostName -From $From -To $To -FailuresOnly:$FailuresOnly
$analysis | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $directory 'http-summary.json') -Encoding utf8
Write-HttpResult $analysis -AsJson:$Json
