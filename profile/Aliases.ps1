# Short, user-facing command wrappers and Linux-style tool mappings.

function global:Get-WorkstationHelp {
    [CmdletBinding()]
    param(
        [ValidateSet('All', 'Commands', 'Aliases', 'Skills')]
        [string] $Type = 'All',
        [string] $Name = '*',
        [switch] $Json
    )

    $repositoryRoot = Join-Path $env:USERPROFILE 'Source\PowerShell'
    $items = [Collections.Generic.List[object]]::new()
    $managedCommands = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    if ($Type -in @('All', 'Commands', 'Aliases')) {
        foreach ($profileFile in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'profile') -Filter '*.ps1' -File) {
            $tokens = $null
            $errors = $null
            $ast = [Management.Automation.Language.Parser]::ParseFile($profileFile.FullName, [ref] $tokens, [ref] $errors)
            if ($errors.Count -gt 0) { throw "Cannot inventory managed commands because $($profileFile.FullName) has parse errors." }
            foreach ($functionAst in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
                $commandName = $functionAst.Name -replace '^global:', ''
                [void] $managedCommands.Add($commandName)
                if ($Type -in @('All', 'Commands') -and $commandName -like $Name) {
                    $items.Add([pscustomobject]@{
                        Kind = 'Command'
                        Name = $commandName
                        Description = ''
                        Source = "profile/$($profileFile.Name)"
                    })
                }
            }
        }
    }

    if ($Type -in @('All', 'Aliases')) {
        foreach ($alias in Get-Alias | Where-Object { $managedCommands.Contains($_.Definition) -and $_.Name -like $Name }) {
            $items.Add([pscustomobject]@{
                Kind = 'Alias'
                Name = $alias.Name
                Description = "Alias for $($alias.Definition)"
                Source = 'loaded profile'
            })
        }
    }

    if ($Type -in @('All', 'Skills')) {
        $skillRoot = Join-Path $repositoryRoot '.agents\skills'
        foreach ($skillFile in Get-ChildItem -LiteralPath $skillRoot -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue) {
            $content = Get-Content -LiteralPath $skillFile.FullName -Raw
            $skillName = [regex]::Match($content, '(?m)^name:\s*(.+)$').Groups[1].Value.Trim()
            $description = [regex]::Match($content, '(?m)^description:\s*(.+)$').Groups[1].Value.Trim()
            if ($skillName -and $skillName -like $Name) {
                $items.Add([pscustomobject]@{
                    Kind = 'Skill'
                    Name = $skillName
                    Description = $description
                    Source = [IO.Path]::GetRelativePath($repositoryRoot, $skillFile.FullName).Replace('\', '/')
                })
            }
        }
    }

    $result = @($items | Sort-Object Kind, Name -Unique)
    if ($Json) { return $result | ConvertTo-Json -Depth 4 }
    $result | Format-Table Kind, Name, Description, Source -AutoSize -Wrap
}
Set-Alias -Name workstation-help -Value Get-WorkstationHelp -Scope Global
Set-Alias -Name wshelp -Value Get-WorkstationHelp -Scope Global

function global:tricky {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-Tricky.ps1') @args
}

function global:skillopt {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-SkillOpt.ps1') @args
}
function global:skillopt-status { skillopt status @args }
function global:skillopt-harvest { skillopt harvest @args }
function global:skillopt-review { skillopt review @args }
function global:skillopt-approve-tasks { skillopt approve-tasks @args }
function global:skillopt-dry-run { skillopt dry-run @args }
function global:skillopt-run { skillopt run @args }
function global:skillopt-adopt { skillopt adopt @args }
function global:skills-validate { skillopt validate @args }

function global:lint-powershell {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-PowerShellLint.ps1') @args
}
function global:test-powershell {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-PowerShellTests.ps1') @args
}
function global:precommit-install {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Install-PreCommitHook.ps1') @args
}
function global:precommit-run {
    Push-Location (Join-Path $env:USERPROFILE 'Source\PowerShell')
    try { & pre-commit.exe run --all-files @args } finally { Pop-Location }
}

function global:update {
    [CmdletBinding()]
    param(
        [ValidateSet('All', 'Windows', 'WinGet', 'Scoop', 'Wsl', 'Linux', 'Homebrew', 'Containers', 'PowerShellEnvironment')]
        [string[]] $Target = @('All'),
        [switch] $Run,
        [switch] $Json
    )
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-WorkstationUpdate.ps1'
    & $script -Target $Target -Run:$Run -Json:$Json
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
Set-Alias -Name wget -Value aria2c -Scope Global

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

function global:rsync { wsl-dev rsync @args }
function global:wslpath { wsl-dev wslpath @args }

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
function global:dump-analyze {
    & (Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-HeadlessDumpAnalysis.ps1') @args
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

# Generic WSL boundaries keep the developer and malware distributions explicit.
# Developer Docker remains a temporary fallback until Docker Desktop is declared;
# Debian-MW uses local daemonless Podman only through its high-level analysis tools.
function global:Invoke-ConfiguredWsl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Developer', 'Malware')]
        [string] $Target,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $ArgumentList
    )
    $repositoryRoot = Join-Path $env:USERPROFILE 'Source\PowerShell'
    . (Join-Path $repositoryRoot 'scripts\Import-WslEnvironment.ps1')
    $wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
    $distribution = if ($Target -eq 'Developer') { $wslEnvironment.WSL_DISTRIBUTION } else { $wslEnvironment.WSL_MALWARE_DISTRIBUTION }
    $user = if ($Target -eq 'Developer') { $wslEnvironment.WSL_USER } else { $wslEnvironment.WSL_MALWARE_USER }
    if ($ArgumentList.Count -gt 0) {
        & wsl.exe -d $distribution --user $user --exec @ArgumentList
    } else {
        & wsl.exe -d $distribution --user $user
    }
}

function global:wsl-dev {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $ArgumentList)
    Invoke-ConfiguredWsl -Target Developer -ArgumentList $ArgumentList
}

function global:wsl-mw {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $ArgumentList)
    Invoke-ConfiguredWsl -Target Malware -ArgumentList $ArgumentList
}

if (-not (Get-Command docker.exe -CommandType Application -ErrorAction Ignore)) {
    function global:docker {
        wsl-dev docker @args
    }
}

if (-not (Get-Command docker-compose.exe -CommandType Application -ErrorAction Ignore)) {
    function global:docker-compose {
        wsl-dev docker compose @args
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

# Zhorn Software Caffeine is installed by WinGet as caffeine64.exe/caffeine32.exe
# without a stable portable-command link. This wrapper starts that real tray tool.
function global:caffeine {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $ArgumentList)
    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    $executable = Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter 'caffeine64.exe' -ErrorAction Ignore |
        Where-Object FullName -Like '*ZhornSoftware.Caffeine*' |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $executable) {
        $executable = Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter 'caffeine32.exe' -ErrorAction Ignore |
            Where-Object FullName -Like '*ZhornSoftware.Caffeine*' |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $executable) { throw 'Zhorn Software Caffeine is not installed. Run: .\Apply-Workstation.ps1 -Mode Ensure -Module Caffeine' }
    Start-Process -FilePath $executable -ArgumentList $ArgumentList
}

function global:is-this-malware {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)][string] $Path, [switch] $Json)
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-MalwareAnalysis.ps1'
    & $script -Action Inspect -Path $Path -Json:$Json
}
function global:lint-python {
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-PythonLint.ps1'
    & $script @args
}
Set-Alias -Name host-static -Value is-this-malware -Scope Global

function global:malware-container-status {
    [CmdletBinding()]
    param([switch] $Json)
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Test-MalwareContainerIsolation.ps1'
    & $script -Json:$Json
}

function global:malware-container-image {
    [CmdletBinding()]
    param(
        [ValidateSet('Test', 'Ensure', 'Reinitialize')][string] $Mode = 'Test',
        [switch] $Json
    )
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-MalwareContainerImageState.ps1'
    & $script -Mode $Mode -Json:$Json
}

function global:malware-container {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Path,
        [ValidateSet('Control', 'Target')][string] $Role = 'Target',
        [switch] $Run,
        [switch] $ConfirmContainer,
        [switch] $Json
    )
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-MalwareContainerAnalysis.ps1'
    $action = if ($Run) { 'Run' } else { 'Plan' }
    & $script -Action $action -Path $Path -Role $Role -ConfirmContainer:$ConfirmContainer -Json:$Json
}

function global:malware-container-control {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Path,
        [switch] $Run,
        [switch] $ConfirmContainer,
        [switch] $Json
    )
    malware-container -Path $Path -Role Control -Run:$Run -ConfirmContainer:$ConfirmContainer -Json:$Json
}

function global:malware-sandbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Path,
        [ValidateSet('Dissect', 'Disassemble', 'Decompile', 'Detonate')][string] $Mode = 'Dissect',
        [ValidateRange(5, 900)][int] $DurationSeconds = 30,
        [switch] $Run,
        [switch] $ConfirmSandbox,
        [switch] $ConfirmExecution,
        [switch] $AllowNetwork,
        [switch] $Control,
        [switch] $KeepSandboxOpen,
        [switch] $Json
    )
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-MalwareAnalysis.ps1'
    $action = if ($Run) { 'Run' } else { 'Plan' }
    & $script -Action $action -Mode $Mode -Path $Path -DurationSeconds $DurationSeconds `
        -ConfirmSandbox:$ConfirmSandbox -ConfirmExecution:$ConfirmExecution -AllowNetwork:$AllowNetwork `
        -Control:$Control -KeepSandboxOpen:$KeepSandboxOpen -Json:$Json
}
Set-Alias -Name sandbox-static -Value malware-sandbox -Scope Global

function global:malware-control {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Path,
        [ValidateSet('Dissect', 'Disassemble', 'Decompile', 'Detonate')][string] $Mode = 'Dissect',
        [ValidateRange(5, 900)][int] $DurationSeconds = 30,
        [switch] $Run,
        [switch] $ConfirmSandbox,
        [switch] $AllowNetwork,
        [switch] $KeepSandboxOpen,
        [switch] $Json
    )
    malware-sandbox -Path $Path -Mode $Mode -DurationSeconds $DurationSeconds -Run:$Run `
        -ConfirmSandbox:$ConfirmSandbox -AllowNetwork:$AllowNetwork -Control `
        -KeepSandboxOpen:$KeepSandboxOpen -Json:$Json
}

function global:malware-diff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $ControlCase,
        [Parameter(Mandatory = $true)][string] $TargetCase,
        [string] $OutputRoot,
        [switch] $ShowDiff,
        [switch] $Json
    )
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Compare-MalwareEvidence.ps1'
    $parameters = @{ ControlCase = $ControlCase; TargetCase = $TargetCase; ShowDiff = $ShowDiff; Json = $Json }
    if ($OutputRoot) { $parameters.OutputRoot = $OutputRoot }
    & $script @parameters
}

# General-purpose names for the same reviewed clean-control Sandbox engine.
# Planning remains the default; these wrappers do not introduce another runner.
function global:sandbox-behavior-control {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Path,
        [ValidateRange(5, 900)][int] $DurationSeconds = 30,
        [switch] $Run,
        [switch] $ConfirmSandbox,
        [switch] $AllowNetwork,
        [switch] $KeepSandboxOpen,
        [switch] $Json
    )
    malware-control -Path $Path -Mode Detonate -DurationSeconds $DurationSeconds -Run:$Run `
        -ConfirmSandbox:$ConfirmSandbox -AllowNetwork:$AllowNetwork `
        -KeepSandboxOpen:$KeepSandboxOpen -Json:$Json
}

function global:sandbox-behavior-target {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Path,
        [ValidateRange(5, 900)][int] $DurationSeconds = 30,
        [switch] $Run,
        [switch] $ConfirmSandbox,
        [switch] $ConfirmExecution,
        [switch] $AllowNetwork,
        [switch] $KeepSandboxOpen,
        [switch] $Json
    )
    malware-sandbox -Path $Path -Mode Detonate -DurationSeconds $DurationSeconds -Run:$Run `
        -ConfirmSandbox:$ConfirmSandbox -ConfirmExecution:$ConfirmExecution `
        -AllowNetwork:$AllowNetwork -KeepSandboxOpen:$KeepSandboxOpen -Json:$Json
}

function global:sandbox-behavior-diff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $ControlCase,
        [Parameter(Mandatory = $true)][string] $TargetCase,
        [string] $OutputRoot,
        [switch] $ShowDiff,
        [switch] $Json
    )
    $parameters = @{
        ControlCase = $ControlCase
        TargetCase = $TargetCase
        ShowDiff = $ShowDiff
        Json = $Json
    }
    if ($OutputRoot) { $parameters.OutputRoot = $OutputRoot }
    malware-diff @parameters
}

function global:binary-diff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Baseline,
        [Parameter(Mandatory = $true, Position = 1)][string] $Candidate,
        [switch] $Run,
        [switch] $ConfirmContainer,
        [switch] $Json
    )
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-BinaryDiffAnalysis.ps1'
    $action = if ($Run) { 'Run' } else { 'Plan' }
    & $script -Action $action -Baseline $Baseline -Candidate $Candidate `
        -ConfirmContainer:$ConfirmContainer -Json:$Json
}

function global:binary-diff-report {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Case,
        [switch] $Json
    )
    $script = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-BinaryDiffAnalysis.ps1'
    & $script -Action Report -Case $Case -Json:$Json
}

function global:disass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Path,
        [switch] $Run,
        [switch] $ConfirmSandbox,
        [switch] $KeepSandboxOpen,
        [switch] $Json
    )
    malware-sandbox -Path $Path -Mode Disassemble -Run:$Run -ConfirmSandbox:$ConfirmSandbox -KeepSandboxOpen:$KeepSandboxOpen -Json:$Json
}

function global:decomp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string] $Path,
        [switch] $Run,
        [switch] $ConfirmSandbox,
        [switch] $KeepSandboxOpen,
        [switch] $Json
    )
    malware-sandbox -Path $Path -Mode Decompile -Run:$Run -ConfirmSandbox:$ConfirmSandbox -KeepSandboxOpen:$KeepSandboxOpen -Json:$Json
}
