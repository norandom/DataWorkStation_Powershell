# BEGIN CODEX LINUX SHELL

# PSReadLine: Emacs/readline editing, searchable history and menu completion.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Emacs -BellStyle None -HistorySearchCursorMovesToEnd

    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Shift+Tab -Function TabCompletePrevious
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord Ctrl+r -Function ReverseSearchHistory

    # PSReadLine 2.1+ can show fish/Kali-like history suggestions. Windows
    # PowerShell 5.1 ships an older version, so enable this only when supported.
    $psReadLineOptions = (Get-Command Set-PSReadLineOption).Parameters
    if ($psReadLineOptions.ContainsKey('PredictionSource') -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
    }
    if ($psReadLineOptions.ContainsKey('PredictionViewStyle') -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
}

# Prefer native Unix-style commands over Windows PowerShell's built-in aliases.
# An alias is removed only when the corresponding executable actually exists.
$nativeCommands = @(
    'cat', 'cp', 'cut', 'date', 'dir', 'echo', 'env', 'expand', 'factor',
    'false', 'head', 'hostname', 'join', 'link', 'ln', 'ls', 'md5sum',
    'mkdir', 'mktemp', 'mv', 'nl', 'nproc', 'od', 'paste', 'pathchk',
    'printenv', 'printf', 'pwd', 'readlink', 'realpath', 'rm', 'rmdir',
    'sha1sum', 'sha256sum', 'sha512sum', 'sleep', 'sort', 'split', 'stat',
    'sum', 'tac', 'tail', 'tee', 'test', 'touch', 'tr', 'true', 'truncate',
    'uname', 'uniq', 'wc', 'whoami'
)

foreach ($commandName in $nativeCommands) {
    if ((Get-Command "$commandName.exe" -CommandType Application -ErrorAction Ignore) -and
        (Test-Path "Alias:$commandName")) {
        Remove-Item "Alias:$commandName" -Force
    }
}

# Windows includes curl.exe, while Windows PowerShell 5.1 masks it with curl/wget aliases.
if (Get-Command curl.exe -CommandType Application -ErrorAction Ignore) {
    foreach ($commandName in 'curl', 'wget') {
        if (Test-Path "Alias:$commandName") {
            Remove-Item "Alias:$commandName" -Force
        }
    }

    function global:wget { & curl.exe @args }
}

function global:prompt {
    "$env:USERNAME@$env:COMPUTERNAME $($executionContext.SessionState.Path.CurrentLocation)> "
}

function global:Get-PortProcess {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateRange(1, 65535)]
        [int] $Port,

        [Parameter()]
        [Alias('PID')]
        [ValidateRange(0, 2147483647)]
        [int] $ProcessId,

        [switch] $Listen
    )

    $rows = @()

    if (Get-Command Get-NetTCPConnection -ErrorAction Ignore) {
        $rows += Get-NetTCPConnection -ErrorAction Ignore | ForEach-Object {
            [pscustomobject]@{
                Protocol      = 'TCP'
                LocalAddress  = $_.LocalAddress
                LocalPort     = $_.LocalPort
                RemoteAddress = $_.RemoteAddress
                RemotePort    = $_.RemotePort
                State         = $_.State
                ProcessId     = $_.OwningProcess
            }
        }
    }

    if (Get-Command Get-NetUDPEndpoint -ErrorAction Ignore) {
        $rows += Get-NetUDPEndpoint -ErrorAction Ignore | ForEach-Object {
            [pscustomobject]@{
                Protocol      = 'UDP'
                LocalAddress  = $_.LocalAddress
                LocalPort     = $_.LocalPort
                RemoteAddress = $null
                RemotePort    = $null
                State         = 'Bound'
                ProcessId     = $_.OwningProcess
            }
        }
    }

    if ($PSBoundParameters.ContainsKey('Port')) {
        $rows = $rows | Where-Object { $_.LocalPort -eq $Port -or $_.RemotePort -eq $Port }
    }
    if ($PSBoundParameters.ContainsKey('ProcessId')) {
        $rows = $rows | Where-Object ProcessId -eq $ProcessId
    }
    if ($Listen) {
        $rows = $rows | Where-Object { $_.Protocol -eq 'UDP' -or $_.State -eq 'Listen' }
    }

    $processNames = @{}
    $serviceNames = @{}
    foreach ($row in $rows) {
        if (-not $processNames.ContainsKey($row.ProcessId)) {
            $processNames[$row.ProcessId] = (Get-Process -Id $row.ProcessId -ErrorAction Ignore).ProcessName
        }
        if (-not $serviceNames.ContainsKey($row.ProcessId)) {
            if ($row.ProcessId -eq 4) {
                $serviceNames[$row.ProcessId] = 'System'
            } else {
                $serviceNames[$row.ProcessId] = (Get-CimInstance Win32_Service -Filter "ProcessId=$($row.ProcessId)" -ErrorAction Ignore).Name -join ','
            }
        }

        $localOnly = $row.LocalAddress -eq '::1' -or $row.LocalAddress -like '127.*'
        $row | Add-Member -NotePropertyName Process -NotePropertyValue $processNames[$row.ProcessId]
        $row | Add-Member -NotePropertyName Service -NotePropertyValue $serviceNames[$row.ProcessId]
        $row | Add-Member -NotePropertyName Exposure -NotePropertyValue $(if ($localOnly) { 'LocalOnly' } else { 'Network' }) -PassThru
    }
}

function global:ports {
    Get-PortProcess -Listen @args | Sort-Object Protocol, LocalPort, ProcessId
}

function global:connections {
    Get-PortProcess @args | Sort-Object Protocol, LocalPort, ProcessId
}

function global:daemons {
    $firewallEnabled = @(Get-NetFirewallProfile -ErrorAction Ignore | Where-Object Enabled).Count -gt 0
    $allowlistActive = @(Get-NetFirewallRule -Group 'Linux Shell - Inbound Allowlist' -Enabled True -ErrorAction Ignore).Count -gt 0

    Get-PortProcess -Listen @args |
        Sort-Object Protocol, LocalPort, ProcessId |
        Select-Object Protocol, LocalAddress, LocalPort, ProcessId, Process, Service, Exposure,
            @{ Name = 'Firewall'; Expression = {
                if (-not $firewallEnabled) { 'FirewallOff' }
                elseif (-not $allowlistActive) { 'CheckRules' }
                elseif ($_.Exposure -eq 'LocalOnly') { 'LocalOnly' }
                elseif ($_.Protocol -eq 'TCP' -and $_.LocalPort -in 8080, 8081) { 'ExternalAllowed' }
                elseif ($_.Protocol -eq 'UDP' -and $_.LocalPort -eq 41641) { 'TailscaleTransport' }
                elseif ($allowlistActive) { 'TailnetOrInternal' }
                else { 'CheckRules' }
            } }
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

function global:fw-status {
    Get-NetFirewallProfile |
        Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, AllowInboundRules
}

function global:fw-rules {
    Get-NetFirewallRule -Group 'Linux Shell - Inbound Allowlist' -ErrorAction Ignore |
        Sort-Object Action, DisplayName |
        ForEach-Object {
            $rule = $_
            $portFilter = $rule | Get-NetFirewallPortFilter
            [pscustomobject]@{
                Name      = $rule.DisplayName
                Enabled   = $rule.Enabled
                Action    = $rule.Action
                Protocol  = $portFilter.Protocol
                LocalPort = $portFilter.LocalPort -join ','
            }
        }
}

function global:fw-on {
    & sudo.exe pwsh.exe -NoLogo -NoProfile -Command 'Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True'
    fw-status
}

function global:fw-off {
    Write-Warning 'Windows Firewall will be disabled for every profile.'
    & sudo.exe pwsh.exe -NoLogo -NoProfile -Command 'Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False'
    fw-status
}

function global:Invoke-ManagedFirewall {
    param([ValidateSet('Ensure', 'Reinitialize', 'Remove')][string] $Mode)

    $firewallScript = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-FirewallState.ps1'
    if (-not (Test-Path -LiteralPath $firewallScript)) {
        Write-Warning "Firewall script not found: $firewallScript"
        return
    }
    & sudo.exe pwsh.exe -NoLogo -NoProfile -File $firewallScript -Mode $Mode
}

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

function global:Invoke-EventTriage {
    param([Parameter(Mandatory = $true)][string] $View)
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1'
    & $script -View $View @args
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

function global:Get-BtopPath {
    $btopCommand = Get-Command btop4win.exe -ErrorAction Ignore
    if ($btopCommand) {
        return $btopCommand.Source
    }

    $wingetBtop = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\aristocratos.btop4win_*\btop4win\btop4win.exe') -File -ErrorAction Ignore |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($wingetBtop) {
        return $wingetBtop.FullName
    }

    $btopAlias = Get-Command btop.exe -CommandType Application -ErrorAction Ignore
    if ($btopAlias) {
        return $btopAlias.Source
    }
}

function global:btop {
    $btopPath = Get-BtopPath
    if ($btopPath) {
        & $btopPath @args
        return
    }

    Get-Process | Sort-Object WorkingSet64 -Descending |
        Select-Object -First 25 Id, ProcessName,
            @{ Name = 'RAM_MiB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 1) } },
            @{ Name = 'Private_MiB'; Expression = { [math]::Round($_.PrivateMemorySize64 / 1MB, 1) } }
}

function global:top {
    btop @args
}

function global:mem {
    $os = Get-CimInstance Win32_OperatingSystem
    $memory = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
    $pagefiles = @(Get-CimInstance Win32_PageFileUsage)
    $wsl = Get-Process vmmemWSL -ErrorAction Ignore

    [pscustomobject]@{
        RAMTotalGiB       = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        RAMAvailableGiB   = [math]::Round($memory.AvailableMBytes / 1024, 2)
        CommitUsedGiB     = [math]::Round($memory.CommittedBytes / 1GB, 2)
        CommitLimitGiB    = [math]::Round($memory.CommitLimit / 1GB, 2)
        CommitHeadroomGiB = [math]::Round(($memory.CommitLimit - $memory.CommittedBytes) / 1GB, 2)
        PagefileGiB       = [math]::Round((($pagefiles | Measure-Object AllocatedBaseSize -Sum).Sum) / 1024, 2)
        NonPagedPoolGiB   = [math]::Round($memory.PoolNonpagedBytes / 1GB, 2)
        PagedPoolGiB      = [math]::Round($memory.PoolPagedBytes / 1GB, 2)
        CacheGiB          = [math]::Round($memory.CacheBytes / 1GB, 2)
        WSLPrivateGiB     = if ($wsl) { [math]::Round($wsl.PrivateMemorySize64 / 1GB, 2) } else { 0 }
    }
}

function global:memapps {
    Get-Process | Group-Object ProcessName | ForEach-Object {
        [pscustomobject]@{
            Name          = $_.Name
            Processes     = $_.Count
            PrivateGiB    = [math]::Round((($_.Group | Measure-Object PrivateMemorySize64 -Sum).Sum) / 1GB, 2)
            WorkingSetGiB = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1GB, 2)
            Handles       = ($_.Group | Measure-Object Handles -Sum).Sum
        }
    } | Sort-Object PrivateGiB -Descending | Select-Object -First 25
}

function global:memproc {
    Get-Process | Sort-Object PrivateMemorySize64 -Descending |
        Select-Object -First 30 Id, ProcessName,
            @{ Name = 'PrivateGiB'; Expression = { [math]::Round($_.PrivateMemorySize64 / 1GB, 3) } },
            @{ Name = 'WorkingSetGiB'; Expression = { [math]::Round($_.WorkingSet64 / 1GB, 3) } },
            CPU, Handles
}

function global:wslmem {
    & wsl.exe -d Debian -- bash -lc 'free -h; printf "\nContainers:\n"; docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"'
}

function global:killapp {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name
    )

    $processes = @(Get-Process -Name $Name -ErrorAction Stop)
    $summary = '{0} process(es), {1:N2} GiB private memory' -f $processes.Count,
        ((($processes | Measure-Object PrivateMemorySize64 -Sum).Sum) / 1GB)
    if ($PSCmdlet.ShouldProcess("$Name ($summary)", 'Stop complete application group')) {
        $processes | Stop-Process -Force
    }
}

function global:unblock {
    param([Parameter(Mandatory = $true, Position = 0)][string[]] $Path)
    $Path | ForEach-Object { Unblock-File -LiteralPath $_ }
}

function global:memtop {
    $btopPath = Get-BtopPath
    if (-not $btopPath) {
        btop @args
        return
    }

    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        & $btopPath @args
    } else {
        & sudo.exe $btopPath @args
    }
}

function global:memmap {
    $ramMap = Get-Command RAMMap.exe -CommandType Application -ErrorAction Ignore
    if (-not $ramMap) {
        Write-Warning 'RAMMap is not installed.'
        return
    }

    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        & $ramMap.Source -accepteula
    } else {
        & sudo.exe $ramMap.Source -accepteula
    }
}

function global:sensors {
    $namespace = if (Get-CimInstance -Namespace root\LibreHardwareMonitor -ClassName Sensor -ErrorAction Ignore) {
        'root\LibreHardwareMonitor'
    } elseif (Get-CimInstance -Namespace root\OpenHardwareMonitor -ClassName Sensor -ErrorAction Ignore) {
        'root\OpenHardwareMonitor'
    }

    if (-not $namespace) {
        Write-Warning 'No sensor data found. Run LibreHardwareMonitor as administrator or start btop with sudo.'
        return
    }

    Get-CimInstance -Namespace $namespace -ClassName Sensor |
        Where-Object SensorType -in 'Temperature', 'Fan', 'Load', 'Power' |
        Select-Object Name, SensorType, Value, Min, Max, Identifier
}

function global:fanspeed {
    $namespace = if (Get-CimInstance -Namespace root\LibreHardwareMonitor -ClassName Sensor -ErrorAction Ignore) {
        'root\LibreHardwareMonitor'
    } elseif (Get-CimInstance -Namespace root\OpenHardwareMonitor -ClassName Sensor -ErrorAction Ignore) {
        'root\OpenHardwareMonitor'
    }

    if (-not $namespace) {
        Write-Warning 'No fan sensors found. For the GPD Pocket 4, run MotionAssistant or LibreHardwareMonitor as administrator.'
        return
    }

    Get-CimInstance -Namespace $namespace -ClassName Sensor |
        Where-Object SensorType -eq 'Fan' |
        Select-Object Name, Value, Min, Max, Identifier
}

# END CODEX LINUX SHELL
