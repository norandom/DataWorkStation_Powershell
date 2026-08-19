# Shared implementations for diagnostic and workstation commands.

function global:Get-WorkstationConfiguration {
    $repositoryRoot = Join-Path $env:USERPROFILE 'Source\PowerShell'
    . (Join-Path $repositoryRoot 'scripts\Import-WorkstationConfiguration.ps1')
    Import-WorkstationConfiguration -RepositoryRoot $repositoryRoot
}

function global:Get-WorkstationTraceRoot {
    [string] (Get-WorkstationConfiguration).Paths.Traces
}

function global:Find-NativeTool {
    param([Parameter(Mandatory = $true)][string] $Name, [string] $WinGetId)
    $command = Get-Command $Name -CommandType Application -ErrorAction Ignore
    if ($command) { return $command.Source }
    if ($WinGetId) {
        $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
        $package = Get-ChildItem -LiteralPath $packageRoot -Directory -ErrorAction Ignore |
            Where-Object Name -like "$WinGetId`_*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($package) {
            $executable = Get-ChildItem -LiteralPath $package.FullName -Recurse -Filter $Name -File -ErrorAction Ignore | Select-Object -First 1
            if ($executable) { return $executable.FullName }
        }
    }
}

function global:Get-CodeQLPath {
    $command = Get-Command codeql.exe -CommandType Application -ErrorAction Ignore
    if ($command) { return $command.Source }
    Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Programs\CodeQL\*\codeql\codeql.exe') -File -ErrorAction Ignore |
        Sort-Object { [version]$_.Directory.Parent.Name } -Descending | Select-Object -First 1 -ExpandProperty FullName
}

function global:Get-RcloneMountStateDirectory {
    $directory = Join-Path $env:LOCALAPPDATA 'PowerShellWorkstation\rclone-mounts'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $directory
}

function global:Mount-RcloneRemote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Remote,
        [Parameter(Mandatory = $true, Position = 1)][string] $MountPoint,
        [ValidateSet('off', 'minimal', 'writes', 'full')][string] $VfsCacheMode = 'writes',
        [string[]] $Option
    )
    $rclone = Find-NativeTool -Name rclone.exe -WinGetId 'Rclone.Rclone'
    if (-not $rclone) { throw 'rclone.exe is not installed.' }
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning 'Mount from a non-elevated shell so Explorer and normal applications can see the drive.'
    }
    $key = ($MountPoint -replace '[^a-zA-Z0-9_-]', '_').Trim('_')
    if (-not $key) { throw 'MountPoint must contain at least one letter or digit.' }
    $stateFile = Join-Path (Get-RcloneMountStateDirectory) "$key.json"
    if (Test-Path -LiteralPath $stateFile) {
        $old = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        if (Get-Process -Id $old.ProcessId -ErrorAction Ignore) { throw "A managed rclone process already owns $MountPoint (PID $($old.ProcessId))." }
    }
    $arguments = @('mount', $Remote, $MountPoint, '--network-mode', "--vfs-cache-mode=$VfsCacheMode") + @($Option)
    $process = Start-Process -FilePath $rclone -ArgumentList $arguments -WindowStyle Hidden -PassThru
    [pscustomobject]@{ Remote=$Remote; MountPoint=$MountPoint; ProcessId=$process.Id; Started=(Get-Date).ToString('o'); Arguments=$arguments } |
        ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
    Write-Host "Mounted $Remote at $MountPoint (PID $($process.Id))."
}

function global:Dismount-RcloneRemote {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory = $true, Position = 0)][string] $MountPoint)
    $key = ($MountPoint -replace '[^a-zA-Z0-9_-]', '_').Trim('_')
    $stateFile = Join-Path (Get-RcloneMountStateDirectory) "$key.json"
    if (-not (Test-Path -LiteralPath $stateFile)) { throw "No managed rclone mount state found for $MountPoint." }
    $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $process = Get-Process -Id $state.ProcessId -ErrorAction Ignore
    if ($process -and $PSCmdlet.ShouldProcess("$MountPoint (PID $($state.ProcessId))", 'Stop rclone mount')) {
        Stop-Process -Id $state.ProcessId
        $process.WaitForExit(10000) | Out-Null
    }
    Remove-Item -LiteralPath $stateFile -Force
    Write-Host "Unmounted $MountPoint."
}

function global:Get-RcloneMounts {
    Get-ChildItem -LiteralPath (Get-RcloneMountStateDirectory) -Filter '*.json' -File -ErrorAction Ignore | ForEach-Object {
        $state = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
        [pscustomobject]@{ Remote=$state.Remote; MountPoint=$state.MountPoint; ProcessId=$state.ProcessId; Running=[bool](Get-Process -Id $state.ProcessId -ErrorAction Ignore); Started=$state.Started }
    }
}

function global:Invoke-CrashDumpCapture {
    [CmdletBinding(DefaultParameterSetName = 'Launch')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Launch')][string] $Executable,
        [Parameter(ParameterSetName = 'Launch')][string[]] $Argument,
        [Parameter(Mandatory = $true, ParameterSetName = 'Attach')][int] $ProcessId,
        [string] $OutputDirectory = (Join-Path (Get-WorkstationTraceRoot) 'dumps')
    )
    $procdump = (Get-Command procdump.exe -CommandType Application -ErrorAction Stop).Source
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $output = [IO.Path]::GetFullPath($OutputDirectory)
    if ($PSCmdlet.ParameterSetName -eq 'Attach') {
        & $procdump -accepteula -ma -e 1 $ProcessId $output
    } else {
        $target = (Get-Command $Executable -CommandType Application -ErrorAction Ignore).Source
        if (-not $target) { $target = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).Path }
        & $procdump -accepteula -ma -e 1 -x $output $target @Argument
    }
}

function global:Start-WinDbgSession {
    param(
        [Parameter(Mandatory = $true)][string] $Executable,
        [string[]] $Breakpoint,
        [string[]] $Argument
    )
    $target = (Get-Command $Executable -CommandType Application -ErrorAction Ignore).Source
    if (-not $target) { $target = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).Path }
    $commands = @('.symfix', '.reload') + @($Breakpoint | ForEach-Object { "bu $_" }) + 'g'
    & WinDbgX.exe -c ($commands -join '; ') $target @Argument
}

function global:Invoke-TtdRecord {
    [CmdletBinding(DefaultParameterSetName = 'Launch')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Launch')][string] $Executable,
        [Parameter(ParameterSetName = 'Launch')][string[]] $Argument,
        [Parameter(Mandatory = $true, ParameterSetName = 'Attach')][int] $ProcessId,
        [string] $OutputDirectory = (Join-Path (Get-WorkstationTraceRoot) 'ttd'),
        [ValidateRange(64, 32768)][int] $MaxFileMiB = 2048
    )
    $ttd = (Get-Command TTD.exe -CommandType Application -ErrorAction Stop).Source
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $output = [IO.Path]::GetFullPath($OutputDirectory)
    $options = @('-accepteula', '-out', $output, '-timestampFilename', '-ring', '-maxFile', "$MaxFileMiB")
    if ($PSCmdlet.ParameterSetName -eq 'Attach') {
        & sudo.exe $ttd @options -attach $ProcessId
    } else {
        $target = (Get-Command $Executable -CommandType Application -ErrorAction Ignore).Source
        if (-not $target) { $target = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).Path }
        & sudo.exe $ttd @options -launch $target @Argument
    }
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
                elseif ($_.Protocol -eq 'TCP' -and $_.LocalPort -in 22, 3389, 8080, 8081) { 'ExternalAllowed' }
                elseif ($_.Protocol -eq 'UDP' -and $_.LocalPort -eq 41641) { 'TailscaleTransport' }
                elseif ($allowlistActive) { 'TailnetOrInternal' }
                else { 'CheckRules' }
            } }
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

function global:Invoke-ManagedFirewall {
    param([ValidateSet('Ensure', 'Reinitialize', 'Remove', 'Disable', 'Enable', 'Status')][string] $Mode)

    $firewallScript = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-FirewallState.ps1'
    if (-not (Test-Path -LiteralPath $firewallScript)) {
        Write-Warning "Firewall script not found: $firewallScript"
        return
    }
    & sudo.exe pwsh.exe -NoLogo -NoProfile -File $firewallScript -Mode $Mode
}

function global:Invoke-ManagedSmartScreenState {
    param([ValidateSet('Off', 'Medium', 'Full', 'Status')][string] $Mode)

    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-SmartScreenState.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Warning "SmartScreen script not found: $script"
        return
    }
    & sudo.exe powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $script -Mode $Mode
}

function global:Invoke-ManagedSaveZoneState {
    param([ValidateSet('Disable', 'Enable', 'Status')][string] $Mode)

    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-SaveZoneState.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Warning "SaveZone script not found: $script"
        return
    }
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $script -Mode $Mode
}

function global:Invoke-ManagedDefenderState {
    param([ValidateSet('Disable', 'Enable', 'Status')][string] $Mode)

    $defenderScript = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-DefenderState.ps1'
    if (-not (Test-Path -LiteralPath $defenderScript)) {
        Write-Warning "Defender script not found: $defenderScript"
        return
    }
    if ($Mode -eq 'Status') {
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $defenderScript -Mode $Mode
    } else {
        & sudo.exe --inline powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $defenderScript -Mode $Mode
    }
}

function global:Invoke-EventTriage {
    param([Parameter(Mandatory = $true)][string] $View)
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-EventTriage.ps1'
    & $script -View $View @args
}

function global:Invoke-DevEventLogSession {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Start', 'Check', 'Stop')][string] $Action,
        [Parameter(Mandatory = $true)][string] $Name,
        [string] $Executable,
        [string] $WorkingDirectory = (Get-WorkstationTraceRoot),
        [int] $MaxEvents = 100
    )

    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-DevEventLogSession.ps1'
    $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script, '-Action', $Action, '-Name', $Name, '-WorkingDirectory', $WorkingDirectory, '-MaxEvents', "$MaxEvents")
    if ($Executable) { $arguments += @('-Executable', $Executable) }
    & sudo.exe powershell.exe @arguments
}

function global:Invoke-ManagedPacketCapture {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Start', 'Stop', 'Status', 'Counters')][string] $Action,
        [string] $Name,
        [int[]] $Port,
        [string] $WorkingDirectory = (Get-WorkstationTraceRoot),
        [switch] $AllComponents
    )

    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-PacketCapture.ps1'
    $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script, '-Action', $Action, '-WorkingDirectory', $WorkingDirectory)
    if ($Name) { $arguments += @('-Name', $Name) }
    if ($Port) { $arguments += @('-Port', ($Port -join ',')) }
    if ($AllComponents) { $arguments += '-AllComponents' }
    & sudo.exe powershell.exe @arguments
}

function global:Invoke-PcapTriage {
    param(
        [Parameter(Mandatory = $true)][string] $Capture,
        [ValidateSet('Packets', 'Protocols', 'Ports', 'Endpoints', 'Firewall')][string] $View = 'Packets',
        [ValidateRange(1, 65535)][int] $Port,
        [string] $Protocol,
        [switch] $Failures,
        [ValidateRange(1, 10000)][int] $Count = 100,
        [string] $WorkingDirectory = (Get-WorkstationTraceRoot)
    )

    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-PcapTriage.ps1'
    $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script, '-Capture', $Capture, '-View', $View, '-Count', "$Count", '-WorkingDirectory', $WorkingDirectory)
    if ($PSBoundParameters.ContainsKey('Port')) { $arguments += @('-Port', "$Port") }
    if ($Protocol) { $arguments += @('-Protocol', $Protocol) }
    if ($Failures) { $arguments += '-Failures' }
    & powershell.exe @arguments
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

function global:unblock-downloads {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string] $Path = (Join-Path $env:USERPROFILE 'Downloads'))

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $blockedFiles = @(Get-ChildItem -LiteralPath $resolvedPath -File -Recurse -ErrorAction Stop | Where-Object {
        Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction Ignore
    })
    if ($blockedFiles.Count -eq 0) {
        Write-Host "No Mark-of-the-Web streams found under: $resolvedPath"
        return
    }
    if ($PSCmdlet.ShouldProcess("$($blockedFiles.Count) files under $resolvedPath", 'Remove Mark-of-the-Web')) {
        $blockedFiles | Unblock-File
        Write-Host "Removed Mark-of-the-Web from $($blockedFiles.Count) files."
    }
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
        Write-Warning 'No fan sensors found. Start a supported hardware-monitor provider with the permissions required to publish sensor data.'
        return
    }

    Get-CimInstance -Namespace $namespace -ClassName Sensor |
        Where-Object SensorType -eq 'Fan' |
        Select-Object Name, Value, Min, Max, Identifier
}
