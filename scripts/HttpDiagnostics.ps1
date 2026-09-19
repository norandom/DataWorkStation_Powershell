# Shared, output-allowlisted HTTP ETW analysis. No event Message is formatted.
function ConvertTo-HttpEvent {
    param([Parameter(Mandatory = $true)] $Record)
    $xml = [xml] $Record.ToXml()
    $data = @{}
    foreach ($field in $xml.Event.EventData.Data) { $data[[string] $field.Name] = [string] $field.'#text' }
    [pscustomobject]@{ Provider = $Record.ProviderName; Id = $Record.Id; ProcessId = $Record.ProcessId; TimeUtc = $Record.TimeCreated.ToUniversalTime(); Data = $data }
}

function Get-HttpTraceAnalysis {
    param(
        [AllowEmptyCollection()][object[]] $Events,
        [AllowEmptyCollection()][object[]] $Targets = @(),
        [string] $ProcessName,
        [string] $HostName,
        [datetime] $From = [datetime]::MinValue,
        [datetime] $To = [datetime]::MaxValue,
        [switch] $FailuresOnly
    )
    $From = $From.ToUniversalTime()
    $To = $To.ToUniversalTime()
    $instances = @{}
    foreach ($target in $Targets) {
        $instances[[string] $target.ProcessId] = @{ Selected = $true; StartedUtc = ([datetime] $target.StartedUtc).ToUniversalTime() }
    }
    $requests = [Collections.Generic.List[object]]::new()
    $transport = [Collections.Generic.List[object]]::new()
    $pending = @{}
    $providerEvents = 0
    $targetEvents = 0
    $unmappedEvents = 0
    $unmatchedResponses = 0
    $lostEvents = $null
    foreach ($traceEvent in @($Events | Sort-Object TimeUtc)) {
        $data = $traceEvent.Data
        $eventTime = ([datetime] $traceEvent.TimeUtc).ToUniversalTime()
        if ($data.ContainsKey('EventsLost')) { $lostEvents = [long] $data.EventsLost }
        if ($traceEvent.Provider -eq 'Microsoft-Windows-Kernel-Process' -and $traceEvent.Id -in @(1, 2)) {
            $instanceId = [string] $data.ProcessID
            if ($traceEvent.Id -eq 2) { $instances.Remove($instanceId); continue }
            $imageName = [IO.Path]::GetFileNameWithoutExtension([string] $data.ImageName)
            $selected = $ProcessName -and $imageName -ieq [IO.Path]::GetFileNameWithoutExtension($ProcessName)
            $instances[$instanceId] = @{ Selected = [bool] $selected; StartedUtc = $eventTime }
            continue
        }
        if ($traceEvent.Provider -ne 'Microsoft-Windows-WebIO') { continue }
        $providerEvents++
        $instance = $instances[[string] $traceEvent.ProcessId]
        if (-not $instance) { $unmappedEvents++; continue }
        if (-not $instance.Selected -or $eventTime -lt $instance.StartedUtc) { continue }
        $targetEvents++
        $instanceKey = '{0}@{1:o}' -f $traceEvent.ProcessId, $instance.StartedUtc
        $requestKey = $instanceKey + '/' + [string] $data.Request
        if ($traceEvent.Id -eq 100) {
            $headers = [string] $data.Headers
            $method = [regex]::Match($headers, '^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|CONNECT|TRACE)\s').Groups[1].Value
            $destination = [regex]::Match($headers, '(?im)^Host:\s*([a-z0-9.\-\[\]:]+)\s*$').Groups[1].Value
            $row = [pscustomobject]@{
                ProcessId = $traceEvent.ProcessId; ProcessInstance = $instanceKey; Request = [string] $data.Request
                StartedUtc = ([datetime] $traceEvent.TimeUtc).ToUniversalTime().ToString('o'); CompletedUtc = $null
                Method = $method; HostName = $destination; Path = '[omitted]'; StatusCode = $null
                AuthorizationPresent = [regex]::IsMatch($headers, '(?im)^Authorization:')
                CookiePresent = [regex]::IsMatch($headers, '(?im)^Cookie:'); DurationMs = $null
            }
            $requests.Add($row)
            $pending[$requestKey] = $row
        } elseif ($traceEvent.Id -eq 101) {
            $status = [regex]::Match([string] $data.Headers, '(?im)^HTTP/\d(?:\.\d)?\s+(\d{3})(?:\s|$)')
            if (-not $status.Success) { continue }
            if (-not $pending.ContainsKey($requestKey)) { $unmatchedResponses++; continue }
            $row = $pending[$requestKey]
            $row.StatusCode = [int] $status.Groups[1].Value
            $row.CompletedUtc = ([datetime] $traceEvent.TimeUtc).ToUniversalTime().ToString('o')
            $row.DurationMs = [Math]::Round(($eventTime - ([datetime] $row.StartedUtc).ToUniversalTime()).TotalMilliseconds, 2)
        } elseif ($traceEvent.Id -eq 703 -or $data.ContainsKey('Error')) {
            $code = 0L
            $value = if ($traceEvent.Id -eq 703) { $data.Result } else { $data.Error }
            if (-not [long]::TryParse([string] $value, [ref] $code)) { continue }
            # Pending I/O, EOF, cancellation and incomplete TLS records are not final failures.
            $classification = if ($traceEvent.Id -eq 703 -and $code -eq 0) { 'TlsHandshakeSucceeded' }
                elseif ($code -in @(0, 38, 997, 590610, 590625, 2148074264)) { 'Progress' }
                elseif ($code -eq 995) { 'Cancelled' } else { 'ErrorCandidate' }
            if ($classification -eq 'Progress') { continue }
            $transport.Add([pscustomobject]@{ TimeUtc = ([datetime] $traceEvent.TimeUtc).ToUniversalTime().ToString('o'); ProcessInstance = $instanceKey; EventId = $traceEvent.Id; Code = $code; Classification = $classification })
        }
    }
    $windowRequests = @($requests | Where-Object {
        ([datetime] $_.StartedUtc).ToUniversalTime() -ge $From -and ([datetime] $_.StartedUtc).ToUniversalTime() -le $To -and
        (-not $HostName -or $_.HostName -ieq $HostName)
    })
    $filteredRequests = @($windowRequests | Where-Object { -not $FailuresOnly -or $_.StatusCode -ge 400 })
    $coverage = if ($providerEvents -eq 0) { 'NoProviderEvents' } elseif ($targetEvents -eq 0) { 'NoTargetEvents' }
        elseif ($requests.Count -eq 0) { 'NoHttpRequests' } elseif ($windowRequests.Count -eq 0) { 'NoMatchingRequests' } else { 'RequestsObserved' }
    [pscustomobject]@{
        SchemaVersion = 1; Kind = 'HttpDiagnosticSummary'; Coverage = $coverage
        ProviderEvents = $providerEvents; TargetEvents = $targetEvents; UnmappedEvents = $unmappedEvents
        WindowRequestCount = $windowRequests.Count; ReturnedRequestCount = $filteredRequests.Count
        FromUtc = $From.ToString('o'); ToUtc = $To.ToString('o')
        UnmatchedResponses = $unmatchedResponses; LostEvents = $lostEvents
        LossAssessment = if ($null -eq $lostEvents) { 'Unknown' } elseif ($lostEvents -gt 0) { 'EventsLost' } else { 'NoneReported' }
        CaptureScope = 'System-wide providers'; ExportScope = 'Selected process instances'
        Redaction = 'Allowlist; paths, queries, header values and bodies omitted'
        Requests = $filteredRequests
        Transport = @($transport | Where-Object {
            ([datetime] $_.TimeUtc).ToUniversalTime() -ge $From -and ([datetime] $_.TimeUtc).ToUniversalTime() -le $To -and
            (-not $FailuresOnly -or $_.Classification -eq 'ErrorCandidate')
        })
        Interpretation = 'HTTP errors are observations, not root causes. Correlate challenges, retries and final application outcome. Transport rows are not host-filtered.'
    }
}
