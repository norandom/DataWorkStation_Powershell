[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $repositoryRoot 'scripts\HttpDiagnostics.ps1')
function Assert-Http {
    param([bool] $Condition, [string] $Description)
    if (-not $Condition) { throw "FAIL: $Description" }
    Write-Host "PASS: $Description"
}
$start = [datetime] '2026-09-18T17:00:00Z'
function New-TestEvent {
    param([int] $Id, [hashtable] $Data, [int] $Second = 1, [int] $ProcessId = 42, [string] $Provider = 'Microsoft-Windows-WebIO')
    [pscustomobject]@{ Id = $Id; Data = $Data; ProcessId = $ProcessId; Provider = $Provider; TimeUtc = $start.AddSeconds($Second) }
}
$targets = @([pscustomobject]@{ ProcessId = 42; StartedUtc = $start.ToString('o') })
$secret = 'synthetic-secret-' + [guid]::NewGuid().ToString('N')
$events = @(
    New-TestEvent 100 @{ Request = 'handle1'; Headers = "GET /$secret?key=$secret HTTP/1.1`r`nHost: store.example`r`nAuthorization: t=$secret`r`nCookie: $secret" }
    New-TestEvent 101 @{ Request = 'handle1'; Headers = "X-Ignored: $secret`r`nHTTP/1.1 401 Unauthorized`r`nSet-Cookie: $secret" } 2
    New-TestEvent 100 @{ Request = 'handle1'; Headers = "GET / HTTP/1.1`r`nHost: store.example`r`nAuthorization: Bearer $secret" } 3
    New-TestEvent 101 @{ Request = 'handle1'; Headers = 'HTTP/1.1 200 OK' } 4
    New-TestEvent 131 @{ Request = 'handle1'; Error = '997' } 5
    New-TestEvent 703 @{ Result = '2148074264' } 6
    New-TestEvent 703 @{ Result = '0' } 7
    New-TestEvent 129 @{ Data = $secret; Length = $secret.Length } 8
    New-TestEvent 101 @{ Request = 'missing'; Headers = 'HTTP/1.1 403 Forbidden' } 9
    New-TestEvent 1 @{ ProcessID = '42'; ImageName = 'C:\other.exe' } 10 0 'Microsoft-Windows-Kernel-Process'
    New-TestEvent 100 @{ Request = 'handle1'; Headers = 'GET / HTTP/1.1' } 11
    New-TestEvent 1 @{ ProcessID = '77'; ImageName = 'C:\TestHttp.exe' } 12 0 'Microsoft-Windows-Kernel-Process'
    New-TestEvent 100 @{ Request = 'handle1'; Headers = "GET / HTTP/1.1`r`nHost: store.example" } 13 77
    New-TestEvent 101 @{ Request = 'handle1'; Headers = 'HTTP/1.1 403 Forbidden' } 14 77
)
$summary = Get-HttpTraceAnalysis -Events $events -Targets $targets -ProcessName TestHttp
Assert-Http ($summary.Coverage -eq 'RequestsObserved') 'Recognizes target HTTP coverage'
Assert-Http ($summary.Requests[0].DurationMs -eq 1000) 'Request durations use UTC regardless of the workstation timezone'
$utcEvents = @($events | ForEach-Object {
    [pscustomobject]@{ Id = $_.Id; Data = $_.Data; ProcessId = $_.ProcessId; Provider = $_.Provider; TimeUtc = ([datetime] $_.TimeUtc).ToUniversalTime() }
})
$mixedTimes = Get-HttpTraceAnalysis -Events $utcEvents -Targets $targets -ProcessName TestHttp
Assert-Http ($mixedTimes.Requests.Count -eq $summary.Requests.Count -and $mixedTimes.Requests[0].DurationMs -eq 1000) 'UTC ETW events correlate with ISO-offset process snapshots'
Assert-Http ($summary.Requests.Count -eq 3) 'Tracks handle reuse and restarted process, excluding recycled PID owned by another executable'
Assert-Http (($summary.Requests.StatusCode -join ',') -eq '401,200,403') 'Preserves failed challenge and subsequent successful response separately'
Assert-Http ($summary.Requests[0].AuthorizationPresent -and $summary.Requests[0].CookiePresent) 'Reports credential presence for non-Bearer token format'
Assert-Http (($summary | ConvertTo-Json -Depth 10) -notmatch [regex]::Escape($secret)) 'No secret escapes via headers, URL, cookie or body'
foreach ($authValue in @("Basic $secret", "UnknownScheme=$secret")) {
    $formatSummary = Get-HttpTraceAnalysis -Events @((New-TestEvent 100 @{ Request = 'handle2'; Headers = "GET / HTTP/1.1`r`nHost: store.example`r`nAuthorization: $authValue" })) -Targets $targets
    Assert-Http ($formatSummary.Requests[0].AuthorizationPresent -and ($formatSummary | ConvertTo-Json -Depth 8) -notmatch [regex]::Escape($secret)) 'Basic and unknown authentication formats stay redacted'
}
Assert-Http ($summary.Transport.Count -eq 1 -and $summary.Transport[0].Classification -eq 'TlsHandshakeSucceeded') 'Pending I/O and incomplete TLS records are not reported as failures'
Assert-Http ($summary.UnmatchedResponses -eq 1) 'Counts unmatched responses without assigning them to a different request'
Assert-Http ($null -eq $summary.LostEvents -and $summary.LossAssessment -eq 'Unknown') 'Unknown loss is not reported as zero'
$failures = Get-HttpTraceAnalysis -Events $events -Targets $targets -ProcessName TestHttp -FailuresOnly -From $start.AddSeconds(3)
Assert-Http ($failures.Requests.Count -eq 1 -and $failures.Requests[0].StatusCode -eq 403) 'Failure/time filtering retains the correct later attempt'
$outsideWindow = Get-HttpTraceAnalysis -Events $events -Targets $targets -From $start.AddHours(1)
Assert-Http ($outsideWindow.Coverage -eq 'NoMatchingRequests') 'Evidence outside the requested failure window is inconclusive'
$empty = Get-HttpTraceAnalysis -Events @() -Targets $targets
Assert-Http ($empty.Coverage -eq 'NoProviderEvents') 'Empty capture is inconclusive'
$wrong = Get-HttpTraceAnalysis -Events @((New-TestEvent 100 @{} 1 99)) -Targets $targets
Assert-Http ($wrong.Coverage -eq 'NoTargetEvents') 'Wrong process is not treated as valid coverage'

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('http-diagnostics-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
    $command = Join-Path $repositoryRoot 'scripts\Invoke-HttpDiagnostics.ps1'
    $plan = & $command -Action Start -Name test -ProcessId $PID -WorkingDirectory $temporaryRoot -Plan -Json | ConvertFrom-Json
    Assert-Http ($plan.Status -eq 'Planned' -and -not (Test-Path -LiteralPath (Join-Path $temporaryRoot 'http-test'))) 'HTTP plan records context without creating capture files'
    $packetPlan = & (Join-Path $repositoryRoot 'scripts\Invoke-PacketCapture.ps1') -Action Start -Name test -Port 443 -Seconds 12 -MaxSizeMiB 32 -PacketSizeBytes 0 -WorkingDirectory $temporaryRoot -Plan -Json | ConvertFrom-Json
    Assert-Http ($packetPlan.Seconds -eq 12 -and $packetPlan.PacketSizeBytes -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $temporaryRoot 'pcap-test'))) 'Packet plan forwards bounded/full-packet parameters without mutation'
    # Load only the new function definitions, avoiding unrelated profile initialization.
    foreach ($file in @('profile\Tools.ps1', 'profile\Aliases.ps1')) {
        $tokens = $null; $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repositoryRoot $file), [ref] $tokens, [ref] $parseErrors)
        foreach ($definition in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -match '^(global:)?(Invoke-ManagedHttpDiagnostics|http-debug-start)$' }, $true)) {
            . ([scriptblock]::Create($definition.Extent.Text))
        }
    }
    $script:HttpDiagnosticsScript = $command
    $wrapperPlan = http-debug-start wrapper -ProcessId $PID -Profile TlsHandshake -Seconds 12 -MaxSizeMiB 16 -WorkingDirectory $temporaryRoot -Plan -Json | ConvertFrom-Json
    Assert-Http ($wrapperPlan.Profile -eq 'TlsHandshake' -and $wrapperPlan.Seconds -eq 12 -and $wrapperPlan.MaxSizeMiB -eq 16) 'Human HTTP wrapper forwards aliases and explicit parameters to the standalone command'
    $tricky = Join-Path $repositoryRoot 'scripts\Invoke-Tricky.ps1'
    $case = & $tricky new test -Problem 'HTTP 401 add-in operation not working' -Target test.exe -Root $temporaryRoot -Json | ConvertFrom-Json
    $summaryPath = Join-Path $temporaryRoot 'http-summary.json'
    $empty | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath
    & $tricky add $case.Directory -Path $summaryPath -Json | Out-Null
    & $tricky note $case.Directory -NoteType Contradiction -Message 'TLS succeeds <test>' -Path $summaryPath -Json | Out-Null
    $inspection = & $tricky inspect $case.Directory -Json | ConvertFrom-Json
    Assert-Http (@($inspection.Recommendations | Where-Object State -eq 'coverage-gap').Count -eq 1) 'Tricky detects insufficient HTTP evidence rather than treating its existence as coverage'
    Assert-Http (@($inspection.Recommendations | Where-Object Capability -eq 'event-history').Count -eq 0) 'HTTP route avoids generic event-history fallback'
    $report = & $tricky report $case.Directory -Json | ConvertFrom-Json
    Assert-Http ((Get-Content -LiteralPath $report.Html -Raw) -match 'TLS succeeds &lt;test&gt;') 'Case notes are rendered with HTML escaping'
    Assert-Http ((Get-Content -LiteralPath $report.Json -Raw | ConvertFrom-Json).Notes.Count -eq 1) 'Structured report contains findings and change journal'
} finally {
    $resolved = [IO.Path]::GetFullPath($temporaryRoot)
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if ([IO.Path]::GetDirectoryName($resolved).TrimEnd('\') -ne $expectedParent -or [IO.Path]::GetFileName($resolved) -notmatch '^http-diagnostics-test-[a-f0-9]{32}$') { throw 'Test cleanup path validation failed' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
