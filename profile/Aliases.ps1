# Short, user-facing command wrappers and Linux-style tool mappings.

function global:tricky {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-Tricky.ps1') @args
}

function global:docs-serve {
    Push-Location (Join-Path $env:USERPROFILE 'Source\PowerShell')
    try { & uv.exe run --group docs mkdocs serve @args } finally { Pop-Location }
}

function global:docs-build {
    Push-Location (Join-Path $env:USERPROFILE 'Source\PowerShell')
    try { & uv.exe run --group docs mkdocs build --strict @args } finally { Pop-Location }
}

function global:aria2c {
    $executable = Find-NativeTool -Name aria2c.exe -WinGetId 'aria2.aria2'
    if (-not $executable) { throw 'aria2c.exe is not installed.' }
    & $executable --continue=true --max-connection-per-server=3 --split=3 @args
}
function global:aria { aria2c @args }

function global:rclone {
    $executable = Find-NativeTool -Name rclone.exe -WinGetId 'Rclone.Rclone'
    if (-not $executable) { throw 'rclone.exe is not installed.' }
    & $executable @args
}
function global:rclone-config { rclone config @args }
function global:rclone-remotes { rclone listremotes @args }
function global:rclone-mount { Mount-RcloneRemote @args }
function global:rclone-unmount { Dismount-RcloneRemote @args }
function global:rclone-mounts { Get-RcloneMounts }

function global:rsync { & wsl.exe -d Debian -- rsync @args }
function global:wslpath { & wsl.exe -d Debian -- wslpath @args }

function global:codeql {
    $executable = Get-CodeQLPath
    if (-not $executable) { throw 'codeql.exe is not installed.' }
    & $executable @args
}
function global:codeql-tob {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Database,
        [ValidateSet('cpp', 'go', 'java')][string] $Language = 'cpp',
        [string] $Output = 'trailofbits.sarif'
    )
    codeql database analyze $Database --format=sarif-latest --output=$Output -- "trailofbits/$Language-queries"
}

function global:semgrep {
    $executable = (Get-Command semgrep.exe -CommandType Application -ErrorAction Ignore).Source
    if (-not $executable) {
        $candidate = Join-Path $env:USERPROFILE '.local\bin\semgrep.exe'
        if (Test-Path -LiteralPath $candidate) { $executable = $candidate }
    }
    if (-not $executable) { throw 'Semgrep CE is not installed in the uv tool environment.' }
    & $executable @args
}
function global:semgrep-scan {
    param(
        [Parameter(Position = 0)][string] $Path = '.',
        [string] $Config = 'auto'
    )
    semgrep scan --config $Config $Path @args
}

function global:poolmon {
    $launcher = Join-Path $env:LOCALAPPDATA 'Programs\PoolMon\PoolMon.cmd'
    if (-not (Test-Path -LiteralPath $launcher)) { throw "PoolMon launcher is missing: $launcher" }
    & $launcher @args
}
function global:pooltag {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Tag)
    $database = Join-Path $env:LOCALAPPDATA 'Programs\PoolMon\pooltag.txt'
    Select-String -LiteralPath $database -Pattern "^$([regex]::Escape($Tag))\s" -CaseSensitive:$false
}

function global:windbg { & WinDbgX.exe @args }
function global:dump-open {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Path)
    & WinDbgX.exe -z (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
}
function global:debug-run { Start-WinDbgSession @args }
function global:dump-on-crash { Invoke-CrashDumpCapture @args }
function global:ttd-record { Invoke-TtdRecord @args }
function global:ttd-open {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Path)
    & WinDbgX.exe -z (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
}

# Profiling: native/system ETW, Python sampling, .NET EventPipe, and AMD counters.
function global:profile-status {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-ProfilerStatus.ps1') @args
}
function global:profile-native {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-NativeCpuProfile.ps1') @args
}
function global:profile-native-start {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Name, [string] $Path = (Get-Location).Path)
    profile-native Start $Name -WorkingDirectory $Path
}
function global:profile-native-stop {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Name, [string] $Path = (Get-Location).Path)
    profile-native Stop $Name -WorkingDirectory $Path
}
function global:profile-native-cancel {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Name, [string] $Path = (Get-Location).Path)
    profile-native Cancel $Name -WorkingDirectory $Path
}
function global:profile-native-record {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Name,
        [ValidateRange(1, 3600)][int] $Seconds = 15,
        [string] $Path = (Get-Location).Path
    )
    profile-native Start $Name -WorkingDirectory $Path
    try { Start-Sleep -Seconds $Seconds }
    finally {
        $state = profile-native Status $Name -WorkingDirectory $Path
        if ($state.Active) { profile-native Stop $Name -WorkingDirectory $Path }
    }
}
function global:profile-native-open {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Name, [string] $Path = (Get-Location).Path)
    profile-native Open $Name -WorkingDirectory $Path
}
function global:profile-python {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-PythonProfile.ps1') @args
}
function global:profile-dotnet {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-DotNetProfile.ps1') @args
}
function global:profile-dotnet-ps {
    & (Join-Path $env:USERPROFILE '.dotnet\tools\dotnet-trace.exe') ps @args
}
function global:profile-view {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Open-Profile.ps1') @args
}
function global:speedscope {
    $launcher = Join-Path $env:APPDATA 'npm\speedscope.cmd'
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw "Speedscope is missing: $launcher" }
    & $launcher @args
}
function global:wpa {
    $executable = 'C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\wpa.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "WPA is missing: $executable" }
    & $executable @args
}
function global:uprof {
    $executable = 'C:\Program Files\AMD\AMDuProf\bin\AMDuProf.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'AMD uProf is not installed. Run uprof-install to open the EULA-gated AMD download page.' }
    & $executable @args
}
function global:uprof-cli {
    $executable = 'C:\Program Files\AMD\AMDuProf\bin\AMDuProfCLI.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'AMD uProf is not installed. Run uprof-install to open the EULA-gated AMD download page.' }
    & $executable @args
}
function global:uprof-install { Start-Process 'https://www.amd.com/en/developer/uprof.html' }

function global:ports {
    Get-PortProcess -Listen @args | Sort-Object Protocol, LocalPort, ProcessId
}

function global:connections {
    Get-PortProcess @args | Sort-Object Protocol, LocalPort, ProcessId
}

function global:port {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateRange(1, 65535)]
        [int] $Number
    )
    Get-PortProcess -Port $Number | Sort-Object Protocol, LocalPort, ProcessId
}

function global:pidports {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int] $ProcessId
    )
    Get-PortProcess -ProcessId $ProcessId | Sort-Object Protocol, LocalPort
}

function global:enable-firewall { Invoke-ManagedFirewall -Mode Enable }
function global:disable-firewall { Invoke-ManagedFirewall -Mode Disable }
function global:firewall-status { Invoke-ManagedFirewall -Mode Status }
function global:fw-on { enable-firewall }
function global:fw-off { disable-firewall }

function global:set-smartscreen {
    param([Parameter(Mandatory = $true, Position = 0)][ValidateSet('Off', 'Medium', 'Full')][string] $Mode)
    Invoke-ManagedSmartScreenState -Mode $Mode
}
function global:disable-smartscreen { Invoke-ManagedSmartScreenState -Mode Off }
function global:enable-smartscreen { Invoke-ManagedSmartScreenState -Mode Medium }
function global:smartscreen-off { Invoke-ManagedSmartScreenState -Mode Off }
function global:smartscreen-medium { Invoke-ManagedSmartScreenState -Mode Medium }
function global:smartscreen-full { Invoke-ManagedSmartScreenState -Mode Full }
function global:smartscreen-status { Invoke-ManagedSmartScreenState -Mode Status }

function global:disable-savezone { Invoke-ManagedSaveZoneState -Mode Disable }
function global:enable-savezone { Invoke-ManagedSaveZoneState -Mode Enable }
function global:savezone-status { Invoke-ManagedSaveZoneState -Mode Status }

function global:disable-defender { Invoke-ManagedDefenderState -Mode Disable }
function global:enable-defender { Invoke-ManagedDefenderState -Mode Enable }
function global:defender-status { Invoke-ManagedDefenderState -Mode Status }
function global:defender-settings { Start-Process 'windowsdefender://threatsettings/' }

function global:fw-ensure { Invoke-ManagedFirewall -Mode Ensure }
function global:fw-reinit { Invoke-ManagedFirewall -Mode Reinitialize }
function global:fw-lockdown { Invoke-ManagedFirewall -Mode Ensure }
function global:fw-unlock { Invoke-ManagedFirewall -Mode Remove }

function global:ts-status {
    & tailscale.exe status @args
}

function global:taildrive {
    & tailscale.exe drive list @args
}

function global:tailshare {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidatePattern('^[a-zA-Z_() ]+$')]
        [string] $Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    & tailscale.exe drive share $Name.ToLowerInvariant() $resolvedPath
}

function global:tailunshare {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name
    )
    & tailscale.exe drive unshare $Name.ToLowerInvariant()
}

# Docker Engine runs natively inside Debian WSL. Calling wsl.exe starts the
# distribution on demand; systemd then starts the enabled Docker service.
# A future native Windows Docker CLI takes precedence automatically.
if (-not (Get-Command docker.exe -CommandType Application -ErrorAction Ignore)) {
    function global:docker {
        & wsl.exe -d Debian -- docker @args
    }
}

if (-not (Get-Command docker-compose.exe -CommandType Application -ErrorAction Ignore)) {
    function global:docker-compose {
        & wsl.exe -d Debian -- docker compose @args
    }
}

if (-not (Get-Command ssh-copy-id.exe -CommandType Application -ErrorAction Ignore)) {
    function global:ssh-copy-id {
        $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\ssh-copy-id.ps1'
        & $script @args
    }
}

function global:problems { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Problems @args }
function global:crashes { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Crashes @args }
function global:logins { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Logons @args }
function global:loginfail { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View LoginFailures @args }
function global:service-errors { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Services @args }
function global:defender-events { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Defender @args }
function global:ps-events { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View PowerShell @args }
function global:remote-events { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Remote @args }
function global:task-events { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Tasks @args }
function global:hardware-events { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Hardware @args }
function global:audit-events { & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1') -View Audit @args }

function global:eventlog-status {
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-EventLogState.ps1'
    & sudo.exe pwsh.exe -NoLogo -NoProfile -File $script -Mode Test
    Get-ChildItem -LiteralPath 'E:\Logs' -File -Filter 'eventlogs-*.zip' -ErrorAction Ignore |
        Sort-Object LastWriteTime -Descending | Select-Object -First 14 Name, Length, LastWriteTime
}

function global:eventlog-export {
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Export-EventLogs.ps1'
    $configuration = Join-Path $env:USERPROFILE 'Source\PowerShell\config\eventlogs.psd1'
    & sudo.exe pwsh.exe -NoLogo -NoProfile -File $script -ConfigurationPath $configuration
}

function global:eventlog-start {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Executable,
        [string] $Path = (Get-Location).Path
    )
    Invoke-DevEventLogSession -Action Start -Name $Name -Executable $Executable -WorkingDirectory $Path
}

function global:eventlog-check {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Name,
        [string] $Path = (Get-Location).Path,
        [int] $MaxEvents = 100
    )
    Invoke-DevEventLogSession -Action Check -Name $Name -WorkingDirectory $Path -MaxEvents $MaxEvents
}

function global:eventlog-stop {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Name,
        [string] $Path = (Get-Location).Path
    )
    Invoke-DevEventLogSession -Action Stop -Name $Name -WorkingDirectory $Path
}

function global:pcap-start {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Name,
        [ValidateRange(1, 65535)][int[]] $Port,
        [string] $Path = (Get-Location).Path,
        [switch] $AllComponents
    )
    Invoke-ManagedPacketCapture -Action Start -Name $Name -Port $Port -WorkingDirectory $Path -AllComponents:$AllComponents
}

function global:pcap-stop {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Name,
        [string] $Path = (Get-Location).Path
    )
    Invoke-ManagedPacketCapture -Action Stop -Name $Name -WorkingDirectory $Path
}

function global:pcap-debug-start {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Name,
        [ValidateRange(1, 65535)][int[]] $Port,
        [string] $Path = (Get-Location).Path
    )
    Invoke-ManagedPacketCapture -Action Start -Name $Name -Port $Port -WorkingDirectory $Path -AllComponents
}

function global:pcap-status { Invoke-ManagedPacketCapture -Action Status }
function global:pcap-counters { Invoke-ManagedPacketCapture -Action Counters }

function global:pcap {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Capture,
        [ValidateRange(1, 65535)][int] $Port,
        [string] $Protocol,
        [switch] $Failures,
        [ValidateRange(1, 10000)][int] $Count = 100
    )
    $parameters = @{ Capture = $Capture; Count = $Count; Failures = $Failures }
    if ($PSBoundParameters.ContainsKey('Port')) { $parameters.Port = $Port }
    if ($Protocol) { $parameters.Protocol = $Protocol }
    Invoke-PcapTriage @parameters
}

function global:pcap-read { pcap @args }
function global:pcap-view { pcap @args }
function global:pcap-failures {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Capture, [ValidateRange(1, 10000)][int] $Count = 100)
    Invoke-PcapTriage -Capture $Capture -Failures -Count $Count
}
function global:pcap-protocols {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Capture, [ValidateRange(1, 10000)][int] $Count = 30)
    Invoke-PcapTriage -Capture $Capture -View Protocols -Count $Count
}
function global:pcap-ports {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Capture, [ValidateRange(1, 10000)][int] $Count = 30)
    Invoke-PcapTriage -Capture $Capture -View Ports -Count $Count
}
function global:pcap-endpoints {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Capture, [ValidateRange(1, 10000)][int] $Count = 30)
    Invoke-PcapTriage -Capture $Capture -View Endpoints -Count $Count
}
function global:pcap-dns {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Capture, [ValidateRange(1, 10000)][int] $Count = 100)
    Invoke-PcapTriage -Capture $Capture -Protocol dns -Count $Count
}
function global:pcap-ipv6 {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Capture, [ValidateRange(1, 10000)][int] $Count = 100)
    Invoke-PcapTriage -Capture $Capture -Protocol ipv6 -Count $Count
}
function global:pcap-firewall {
    param([Parameter(Mandatory = $true, Position = 0)][string] $Capture, [ValidateRange(1, 10000)][int] $Count = 100)
    Invoke-PcapTriage -Capture $Capture -View Firewall -Count $Count
}

# Linux-like front ends for the closest Sysinternals tools.
if (Get-Command pslist.exe -ErrorAction Ignore) {
    if (Test-Path Alias:ps) { Remove-Item Alias:ps -Force }
    function global:ps { & pslist.exe -accepteula @args }
    function global:pstree { & pslist.exe -accepteula -t @args }
}

if (Get-Command pskill.exe -ErrorAction Ignore) {
    if (Test-Path Alias:kill) { Remove-Item Alias:kill -Force }
    function global:kill { & pskill.exe -accepteula @args }
    function global:pkill { & pskill.exe -accepteula @args }
    function global:killtree { & pskill.exe -accepteula -t @args }
}

if (Get-Command handle.exe -ErrorAction Ignore) {
    function global:lsof {
        if ($args.Count -gt 0 -and $args[0] -match '^-i:?([0-9]+)$') {
            return Get-PortProcess -Port ([int] $Matches[1])
        }
        if ($args.Count -gt 1 -and $args[0] -eq '-i' -and $args[1] -match '^:?([0-9]+)$') {
            return Get-PortProcess -Port ([int] $Matches[1])
        }
        & handle.exe -accepteula @args
    }
}

function global:top {
    btop @args
}
