[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Capture,

    [ValidateSet('Packets', 'Protocols', 'Ports', 'Endpoints', 'Firewall')]
    [string] $View = 'Packets',

    [ValidateRange(1, 65535)]
    [int] $Port,

    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string] $Protocol,

    [switch] $Failures,

    [ValidateRange(1, 10000)]
    [int] $Count = 100,

    [string] $WorkingDirectory = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$workingRoot = [IO.Path]::GetFullPath($WorkingDirectory)
$candidate = if (Test-Path -LiteralPath $Capture) {
    (Resolve-Path -LiteralPath $Capture).Path
} else {
    Join-Path $workingRoot "pcap-$Capture"
}
if (Test-Path -LiteralPath $candidate -PathType Leaf) { $captureRoot = Split-Path -Parent $candidate }
elseif (Test-Path -LiteralPath $candidate -PathType Container) { $captureRoot = $candidate }
else { throw "PktMon capture not found: $candidate" }

$etlFile = Join-Path $captureRoot 'capture.etl'
if (-not (Test-Path -LiteralPath $etlFile -PathType Leaf)) {
    if ([IO.Path]::GetExtension($candidate) -ieq '.etl') { $etlFile = $candidate }
    else { throw "The PktMon ETL required for native parsing was not found: $etlFile" }
}
$textFile = Join-Path $captureRoot 'capture.txt'
$etlItem = Get-Item -LiteralPath $etlFile
if (-not (Test-Path -LiteralPath $textFile -PathType Leaf) -or (Get-Item -LiteralPath $textFile).LastWriteTimeUtc -lt $etlItem.LastWriteTimeUtc) {
    & pktmon.exe etl2txt $etlFile --out $textFile --brief --timestamp | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "PktMon could not format: $etlFile" }
}

function Convert-PktMonEndpoint {
    param([string] $Token)
    $tokenValue = $Token.Trim().Trim('[', ']')
    if ($tokenValue -match '^(?<Address>(?:\d{1,3}\.){3}\d{1,3})\.(?<Port>\d+)$') {
        return [pscustomobject]@{ Address = $Matches.Address; Port = [int]$Matches.Port }
    }
    if ($tokenValue -match '^(?<Address>.+)\.(?<Port>\d+)$' -and $Matches.Address -match ':') {
        return [pscustomobject]@{ Address = $Matches.Address; Port = [int]$Matches.Port }
    }
    return [pscustomobject]@{ Address = $tokenValue; Port = $null }
}

$components = @{}
foreach ($line in [IO.File]::ReadLines($textFile)) {
    if ($line -match '^\S+\s+Component (?<Id>\d+), Type .*?, Name (?<Name>.+?)\s*$') {
        $components[[int]$Matches.Id] = $Matches.Name.Trim()
    }
}

$packets = [Collections.Generic.List[object]]::new()
$header = $null
$requestedProtocol = if ($Protocol) { $Protocol.ToUpperInvariant() } else { $null }
$aggregateView = $View -in 'Protocols', 'Ports', 'Endpoints'
foreach ($line in [IO.File]::ReadLines($textFile)) {
    if ($line -match '^(?<Time>\d{2}:\d{2}:\d{2}\.\d+)\s+(?<Dropped>Drop:\s+)?PktGroupId .*?Direction (?<Direction>Rx|Tx)\s*, Type (?<Type>[^,]+)\s*, Component (?<Component>\d+).*?OriginalSize (?<Size>\d+)') {
        $time = $Matches.Time
        $direction = $Matches.Direction
        $type = $Matches.Type.Trim()
        $component = [int]$Matches.Component
        $dropped = -not [string]::IsNullOrEmpty($Matches.Dropped)
        $size = [int]$Matches.Size
        $filterNumber = if ($line -match ', Filter (?<Value>\d+),') { $Matches.Value } else { $null }
        $dropReason = if ($line -match 'DropReason (?<Value>.+?)\s*, DropLocation') { $Matches.Value.Trim() } else { $null }
        $dropLocation = if ($line -match 'DropLocation (?<Value>0x[0-9A-Fa-f]+),') { $Matches.Value } else { $null }
        $header = [pscustomobject]@{
            Time = $time
            Direction = $direction
            Type = $type
            Component = $component
            Filter = $filterNumber
            Dropped = $dropped
            DropReason = $dropReason
            DropLocation = $dropLocation
            Size = $size
        }
        continue
    }
    if (-not $header -or $line -notmatch '^\s+.*?(?<Source>[0-9A-Fa-f:.]+(?:\.\d+)?)\s+>\s+(?<Destination>[0-9A-Fa-f:.]+(?:\.\d+)?):\s+(?<Protocol>TCP|UDP|ICMP6?|ICMPv6)(?<Info>.*)$') { continue }

    $sourceToken = $Matches.Source
    $destinationToken = $Matches.Destination
    $protocolToken = $Matches.Protocol
    $infoText = "$($Matches.Info)"
    $source = Convert-PktMonEndpoint $sourceToken
    $destination = Convert-PktMonEndpoint $destinationToken
    $protocolName = $protocolToken.ToUpperInvariant() -replace '^ICMP6$', 'ICMPV6'
    $ipVersion = if ($source.Address -match ':' -or $destination.Address -match ':') { 'IPv6' } else { 'IPv4' }
    $failureText = if ($header.Dropped) { $header.DropReason } elseif ($protocolName -like 'ICMP*') { 'ICMP diagnostic' } else { $null }
    $packet = [pscustomobject]@{
        Time = $header.Time
        Direction = $header.Direction
        Source = if ($null -ne $source.Port) { "$($source.Address):$($source.Port)" } else { $source.Address }
        Destination = if ($null -ne $destination.Port) { "$($destination.Address):$($destination.Port)" } else { $destination.Address }
        Protocol = if ($source.Port -eq 53 -or $destination.Port -eq 53) { 'DNS' } else { $protocolName }
        IPVersion = $ipVersion
        Bytes = $header.Size
        Component = $header.Component
        ComponentName = $components[$header.Component]
        Dropped = $header.Dropped
        Failure = $failureText
        DropLocation = $header.DropLocation
        SourcePort = $source.Port
        DestinationPort = $destination.Port
        SourceAddress = $source.Address
        DestinationAddress = $destination.Address
        Info = $infoText.Trim(' ', ',')
    }
    $header = $null

    if ($PSBoundParameters.ContainsKey('Port') -and $packet.SourcePort -ne $Port -and $packet.DestinationPort -ne $Port) { continue }
    if ($requestedProtocol) {
        $protocolMatches = if ($requestedProtocol -eq 'IPV6') { $packet.IPVersion -eq 'IPv6' }
            elseif ($requestedProtocol -eq 'DNS') { $packet.Protocol -eq 'DNS' }
            else { $packet.Protocol -eq $requestedProtocol }
        if (-not $protocolMatches) { continue }
    }
    if ($Failures -and -not ($packet.Dropped -or $packet.Protocol -like 'ICMP*')) { continue }
    if ($View -eq 'Firewall' -and -not $packet.Dropped) { continue }
    $packets.Add($packet)
    if (-not $aggregateView -and $packets.Count -ge $Count) { break }
}

$selected = @($packets)

switch ($View) {
    'Packets' {
        $selected | Select-Object -First $Count Time, Direction, Source, Destination, Protocol, IPVersion, Bytes, Component, Failure
    }
    'Protocols' {
        $selected | Group-Object Protocol | Sort-Object Count -Descending |
            Select-Object -First $Count @{n='Protocol';e={$_.Name}}, @{n='Observations';e={$_.Count}}
    }
    'Ports' {
        @($selected.SourcePort; $selected.DestinationPort) | Where-Object { $null -ne $_ } | Group-Object | Sort-Object Count -Descending |
            Select-Object -First $Count @{n='Port';e={[int]$_.Name}}, @{n='Observations';e={$_.Count}}
    }
    'Endpoints' {
        @($selected.SourceAddress; $selected.DestinationAddress) | Where-Object { $_ } | Group-Object | Sort-Object Count -Descending |
            Select-Object -First $Count @{n='Endpoint';e={$_.Name}}, @{n='Observations';e={$_.Count}}
    }
    'Firewall' {
        Write-Host 'PktMon capture statistics:'
        & pktmon.exe etl2txt $etlFile --stats
        if ($LASTEXITCODE -ne 0) { throw "PktMon could not read capture statistics from: $etlFile" }
        Write-Host "`nComponent drop evidence:"
        $selected | Select-Object -First $Count Time, Direction, Source, Destination, Protocol, Component, ComponentName, Failure, DropLocation
    }
}
