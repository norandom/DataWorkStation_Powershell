[CmdletBinding()]
param(
    [ValidateSet('Problems','Crashes','Logons','LoginFailures','Services','Defender','PowerShell','Remote','Tasks','Hardware','Audit')]
    [string] $View = 'Problems',
    [ValidateRange(1, 8760)][int] $Hours = 24,
    [ValidateRange(1, 5000)][int] $MaxEvents = 100
)

$ErrorActionPreference = 'Stop'
$securityViews = @('Logons','LoginFailures','Audit')
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if ($View -in $securityViews -and -not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    & sudo.exe pwsh.exe -NoLogo -NoProfile -File $PSCommandPath -View $View -Hours $Hours -MaxEvents $MaxEvents
    exit $LASTEXITCODE
}

$start = (Get-Date).AddHours(-$Hours)
$queries = switch ($View) {
    'Problems' { @(@{ LogName=@('System','Application'); StartTime=$start; Level=@(1,2,3) }) }
    'Crashes' { @(
        @{ LogName='Application'; StartTime=$start; Id=@(1000,1001,1002,1026) }
        @{ LogName='System'; StartTime=$start; Id=@(41,1001,6008) }
    ) }
    'Logons' { @(@{ LogName='Security'; StartTime=$start; Id=@(4624,4625,4634,4647,4648,4672) }) }
    'LoginFailures' { @(@{ LogName='Security'; StartTime=$start; Id=@(4625,4771,4776) }) }
    'Services' { @(@{ LogName='System'; ProviderName='Service Control Manager'; StartTime=$start; Id=@(7000,7001,7009,7011,7022,7023,7024,7031,7034,7040,7045) }) }
    'Defender' { @(@{ LogName='Microsoft-Windows-Windows Defender/Operational'; StartTime=$start; Id=@(1006,1007,1116,1117,1118,5001,5004,5007,5010,5012) }) }
    'PowerShell' { @(
        @{ LogName='Microsoft-Windows-PowerShell/Operational'; StartTime=$start; Id=@(4100,4103,4104,4105,4106) }
        @{ LogName='Windows PowerShell'; StartTime=$start; Id=@(400,403,600,800) }
    ) }
    'Remote' { @(
        @{ LogName='Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational'; StartTime=$start }
        @{ LogName='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'; StartTime=$start }
        @{ LogName='OpenSSH/Operational'; StartTime=$start }
    ) }
    'Tasks' { @(@{ LogName='Microsoft-Windows-TaskScheduler/Operational'; StartTime=$start; Id=@(106,129,140,141,142,200,201,202,203) }) }
    'Hardware' { @(@{ LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$start }) }
    'Audit' { @(@{ LogName='Security'; StartTime=$start; Id=@(1102,4688,4697,4698,4719,4720,4722,4724,4725,4726,4732,4733) }) }
}

$events = foreach ($query in $queries) {
    Get-WinEvent -FilterHashtable $query -ErrorAction Ignore
}

$events | Sort-Object TimeCreated -Descending | Select-Object -First $MaxEvents | ForEach-Object {
    $eventRecord = $_
    $data = @{}
    try {
        $xml = [xml]$eventRecord.ToXml()
        foreach ($item in @($xml.Event.EventData.Data)) {
            if ($item.Name) { $data[$item.Name] = [string]$item.'#text' }
        }
    } catch { Write-Verbose "Event XML could not be parsed: $($_.Exception.Message)" }

    $message = if ($eventRecord.Message) { ($eventRecord.Message -replace '\s+', ' ').Trim() } else { '' }
    [pscustomobject]@{
        Time       = $eventRecord.TimeCreated
        Level      = $eventRecord.LevelDisplayName
        Id         = $eventRecord.Id
        Provider   = $eventRecord.ProviderName
        User       = @($data.TargetUserName,$data.SubjectUserName | Where-Object { $_ -and $_ -ne '-' })[0]
        SourceIP   = @($data.IpAddress,$data.ClientAddress,$data.SourceAddress | Where-Object { $_ -and $_ -ne '-' })[0]
        LogonType  = $data.LogonType
        Process    = @($data.ProcessName,$data.NewProcessName | Where-Object { $_ })[0]
        Service    = $data.ServiceName
        Log        = $eventRecord.LogName
        Message    = if ($message.Length -gt 500) { $message.Substring(0,500) + '...' } else { $message }
    }
}
