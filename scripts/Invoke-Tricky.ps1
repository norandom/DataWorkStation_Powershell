[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('new', 'list', 'add', 'inspect', 'report', 'capabilities')]
    [string] $Action,

    [Parameter(Position = 1)]
    [string] $Case,

    [string] $Problem,
    [string] $Target,
    [string] $Path,
    [string] $Root = (Get-Location).Path,
    [switch] $Copy,
    [switch] $Hash,
    [switch] $Open,
    [switch] $Json,
    [switch] $AsObject
)

$ErrorActionPreference = 'Stop'
$script:RepositoryRoot = Split-Path -Parent $PSScriptRoot
$script:CapabilityFile = Join-Path $script:RepositoryRoot 'config\capabilities.psd1'

function ConvertTo-SafeName {
    param([Parameter(Mandatory = $true)][string] $Value)
    $safe = ($Value.Trim().ToLowerInvariant() -replace '[^a-z0-9._-]+', '-') -replace '^-|-$', ''
    if (-not $safe) { throw 'The case name does not contain any usable characters.' }
    $safe
}

function Resolve-CaseDirectory {
    param([Parameter(Mandatory = $true)][string] $Value, [switch] $MustExist)
    if (Test-Path -LiteralPath $Value -PathType Container) {
        $directory = (Resolve-Path -LiteralPath $Value).Path
    } else {
        $directory = Join-Path (Resolve-Path -LiteralPath $Root).Path ("tricky-{0}" -f (ConvertTo-SafeName $Value))
    }
    if ($MustExist -and -not (Test-Path -LiteralPath (Join-Path $directory 'case.json') -PathType Leaf)) {
        throw "Tricky case not found: $Value"
    }
    $directory
}

function Read-Case {
    param([Parameter(Mandatory = $true)][string] $Directory)
    Get-Content -LiteralPath (Join-Path $Directory 'case.json') -Raw | ConvertFrom-Json
}

function Write-Case {
    param([Parameter(Mandatory = $true)][string] $Directory, [Parameter(Mandatory = $true)] $Value)
    $Value.UpdatedUtc = [DateTime]::UtcNow.ToString('o')
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Directory 'case.json') -Encoding UTF8
}

function Get-EvidenceKind {
    param([Parameter(Mandatory = $true)][IO.FileInfo] $File)
    $name = $File.Name.ToLowerInvariant()
    switch -Regex ($name) {
        '\.evtx$' { return 'Event log' }
        '\.pcap(ng)?$' { return 'Packet capture' }
        '\.(dmp|mdmp)$' { return 'Crash dump' }
        '\.nettrace$' { return '.NET profile' }
        '\.speedscope\.json$' { return '.NET profile' }
        '\.svg$' { return 'Python profile' }
        '\.etl$' {
            if ($File.DirectoryName -match 'pcap|packet|pktmon') { return 'Packet capture' }
            return 'ETW trace'
        }
        '\.(json|jsonl|csv|log|txt)$' { return 'Snapshot' }
        default { return 'Other' }
    }
}

function Get-EvtxSummary {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)
    try {
        $events = @(Get-WinEvent -Path $LiteralPath -MaxEvents 2000 -ErrorAction Stop)
        if ($events.Count -eq 0) { return [pscustomobject]@{ Events = 0 } }
        [pscustomobject]@{
            Events = $events.Count
            Errors = @($events | Where-Object Level -eq 2).Count
            Warnings = @($events | Where-Object Level -eq 3).Count
            FirstUtc = ($events | Sort-Object TimeCreated | Select-Object -First 1).TimeCreated.ToUniversalTime().ToString('o')
            LastUtc = ($events | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated.ToUniversalTime().ToString('o')
            TopProviders = @($events | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 5 Name, Count)
        }
    } catch {
        [pscustomobject]@{ Error = $_.Exception.Message }
    }
}

function Get-ReferenceEntries {
    param([Parameter(Mandatory = $true)][string] $Directory)
    $file = Join-Path $Directory 'evidence\references.json'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return @() }
    @((Get-Content -LiteralPath $file -Raw | ConvertFrom-Json))
}

function Get-EvidenceInventory {
    param([Parameter(Mandatory = $true)][string] $Directory, [switch] $IncludeHash)
    $items = [Collections.Generic.List[object]]::new()
    $evidenceRoot = Join-Path $Directory 'evidence'
    $files = @(Get-ChildItem -LiteralPath $evidenceRoot -File -Recurse -ErrorAction Ignore |
        Where-Object Name -ne 'references.json')
    foreach ($file in $files) {
        $kind = Get-EvidenceKind $file
        $detail = $null
        if ($kind -eq 'Event log') { $detail = Get-EvtxSummary $file.FullName }
        $sha = $null
        if ($IncludeHash) { $sha = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
        $items.Add([pscustomobject]@{
            Kind = $kind
            Name = $file.Name
            Path = $file.FullName
            RelativePath = $file.FullName.Substring($Directory.Length).TrimStart('\')
            Source = 'contained'
            Exists = $true
            Bytes = $file.Length
            ModifiedUtc = $file.LastWriteTimeUtc.ToString('o')
            Sha256 = $sha
            Detail = $detail
        })
    }
    foreach ($reference in @(Get-ReferenceEntries $Directory)) {
        if (-not $reference.Path) { continue }
        $resolved = Resolve-Path -LiteralPath $reference.Path -ErrorAction Ignore
        if (-not $resolved) {
            $items.Add([pscustomobject]@{ Kind = $reference.Kind; Name = [IO.Path]::GetFileName($reference.Path); Path = $reference.Path; RelativePath = $null; Source = 'reference'; Exists = $false; Bytes = 0; ModifiedUtc = $null; Sha256 = $null; Detail = $null })
            continue
        }
        $referenceFiles = if (Test-Path -LiteralPath $resolved.Path -PathType Container) {
            @(Get-ChildItem -LiteralPath $resolved.Path -File -Recurse -ErrorAction Ignore)
        } else { @(Get-Item -LiteralPath $resolved.Path) }
        foreach ($file in $referenceFiles) {
            $kind = Get-EvidenceKind $file
            $detail = $null
            if ($kind -eq 'Event log') { $detail = Get-EvtxSummary $file.FullName }
            $sha = $null
            if ($IncludeHash) { $sha = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
            $items.Add([pscustomobject]@{ Kind = $kind; Name = $file.Name; Path = $file.FullName; RelativePath = $null; Source = 'reference'; Exists = $true; Bytes = $file.Length; ModifiedUtc = $file.LastWriteTimeUtc.ToString('o'); Sha256 = $sha; Detail = $detail })
        }
    }
    @($items)
}

function Get-Recommendations {
    param(
        [Parameter(Mandatory = $true)] $CaseData,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]] $Evidence
    )
    $catalog = Import-PowerShellDataFile -LiteralPath $script:CapabilityFile
    $text = ("{0} {1}" -f $CaseData.Problem, $CaseData.Target).ToLowerInvariant()
    $matchedCapabilities = @($catalog.Capabilities | Where-Object {
        $capability = $_
        @($capability.Triggers | Where-Object { $text.Contains($_) }).Count -gt 0
    })
    if ($matchedCapabilities.Count -eq 0) { $matchedCapabilities = @($catalog.Capabilities | Where-Object Id -eq 'event-history') }
    $knownKinds = @($Evidence | Where-Object Exists | Select-Object -ExpandProperty Kind -Unique)
    $result = [Collections.Generic.List[object]]::new()
    foreach ($capability in $matchedCapabilities) {
        $missing = @($capability.EvidenceKinds | Where-Object { $_ -notin $knownKinds })
        $result.Add([pscustomobject]@{
            Capability = $capability.Id
            Title = $capability.Title
            State = if ($missing.Count -eq 0) { 'evidence-present' } else { 'capture-gap' }
            Reason = if ($missing.Count -eq 0) { 'Relevant evidence is already present; inspect it before recording more.' } else { "Missing evidence: $($missing -join ', ')." }
            Inspect = @($capability.InspectCommands)
            NextCapture = if ($missing.Count -gt 0) { $capability.CaptureCommand.Replace('{case}', $CaseData.Name) } else { $null }
        })
    }
    @($result)
}

function Get-Inspection {
    param([Parameter(Mandatory = $true)][string] $Directory, [switch] $IncludeHash)
    $caseData = Read-Case $Directory
    $evidence = @(Get-EvidenceInventory $Directory -IncludeHash:$IncludeHash)
    $groups = @($evidence | Group-Object Kind | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{ Kind = $_.Name; Files = $_.Count; Bytes = [long](($_.Group | Measure-Object Bytes -Sum).Sum) }
    })
    [pscustomobject]@{
        SchemaVersion = 1
        Case = $caseData
        CaseDirectory = $Directory
        InspectedUtc = [DateTime]::UtcNow.ToString('o')
        EvidenceCount = $evidence.Count
        TotalBytes = [long](($evidence | Measure-Object Bytes -Sum).Sum)
        Kinds = $groups
        Evidence = $evidence
        Recommendations = @(Get-Recommendations $caseData $evidence)
    }
}

function ConvertTo-MarkdownValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    ($Value.ToString() -replace '\|', '\|') -replace "`r?`n", ' '
}

function ConvertTo-HtmlValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    [Net.WebUtility]::HtmlEncode($Value.ToString())
}

function New-BarChartSvg {
    param([AllowEmptyCollection()][object[]] $Groups)
    if ($Groups.Count -eq 0) { return '<p class="muted">No evidence has been added.</p>' }
    $width = 760
    $row = 34
    $height = 30 + ($Groups.Count * $row)
    $max = [Math]::Max(1, [double](($Groups | Measure-Object Bytes -Maximum).Maximum))
    $body = [Text.StringBuilder]::new()
    [void]$body.Append("<svg viewBox='0 0 $width $height' role='img' aria-label='Evidence bytes by type'>")
    $i = 0
    foreach ($group in $Groups) {
        $y = 18 + ($i * $row)
        $barWidth = [Math]::Max(2, [Math]::Round(480 * ($group.Bytes / $max)))
        $label = ConvertTo-HtmlValue $group.Kind
        $size = if ($group.Bytes -ge 1GB) { '{0:N2} GiB' -f ($group.Bytes / 1GB) } elseif ($group.Bytes -ge 1MB) { '{0:N1} MiB' -f ($group.Bytes / 1MB) } else { '{0:N1} KiB' -f ($group.Bytes / 1KB) }
        [void]$body.Append("<text x='0' y='$($y + 14)'>$label</text><rect x='180' y='$y' width='$barWidth' height='20' rx='4'/><text x='$($barWidth + 190)' y='$($y + 14)'>$size</text>")
        $i++
    }
    [void]$body.Append('</svg>')
    $body.ToString()
}

function New-TimelineSvg {
    param([AllowEmptyCollection()][object[]] $Evidence)
    $dated = @($Evidence | Where-Object { $_.Exists -and $_.ModifiedUtc } | Sort-Object ModifiedUtc)
    if ($dated.Count -eq 0) { return '<p class="muted">No dated evidence is available.</p>' }
    $width = 760
    $height = 135
    $left = 35
    $right = 725
    $first = [DateTime]::Parse($dated[0].ModifiedUtc).ToUniversalTime()
    $last = [DateTime]::Parse($dated[-1].ModifiedUtc).ToUniversalTime()
    $span = [Math]::Max(1, ($last - $first).TotalSeconds)
    $body = [Text.StringBuilder]::new()
    [void]$body.Append("<svg viewBox='0 0 $width $height' role='img' aria-label='Evidence modification timeline'><line x1='$left' y1='55' x2='$right' y2='55' stroke='#526879' stroke-width='2'/>")
    $index = 0
    foreach ($item in $dated) {
        $time = [DateTime]::Parse($item.ModifiedUtc).ToUniversalTime()
        $x = $left + [Math]::Round(($right - $left) * (($time - $first).TotalSeconds / $span))
        $labelY = if (($index % 2) -eq 0) { 28 } else { 91 }
        $lineY = if (($index % 2) -eq 0) { 35 } else { 72 }
        $label = ConvertTo-HtmlValue $item.Name
        if ($label.Length -gt 20) { $label = $label.Substring(0, 17) + '...' }
        [void]$body.Append("<line x1='$x' y1='55' x2='$x' y2='$lineY' stroke='#45b8ac'/><circle cx='$x' cy='55' r='5'/><text x='$x' y='$labelY' text-anchor='middle'>$label</text>")
        $index++
    }
    [void]$body.Append("<text x='$left' y='126' text-anchor='start'>$($first.ToString('u'))</text><text x='$right' y='126' text-anchor='end'>$($last.ToString('u'))</text></svg>")
    $body.ToString()
}

function Write-Reports {
    param([Parameter(Mandatory = $true)] $Inspection)
    $directory = $Inspection.CaseDirectory
    $caseData = $Inspection.Case
    $markdown = [Text.StringBuilder]::new()
    [void]$markdown.AppendLine("# $($caseData.Name)")
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine("**Problem:** $(ConvertTo-MarkdownValue $caseData.Problem)")
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine("**Target:** $(ConvertTo-MarkdownValue $caseData.Target)")
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine("Generated: $($Inspection.InspectedUtc)")
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine('## Evidence')
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine('| Type | File | Source | Size (bytes) | Modified UTC |')
    [void]$markdown.AppendLine('|---|---|---:|---:|---|')
    foreach ($item in $Inspection.Evidence) {
        [void]$markdown.AppendLine("| $(ConvertTo-MarkdownValue $item.Kind) | $(ConvertTo-MarkdownValue $item.Name) | $($item.Source) | $($item.Bytes) | $($item.ModifiedUtc) |")
    }
    if ($Inspection.EvidenceCount -eq 0) { [void]$markdown.AppendLine('| — | No evidence yet | — | 0 | — |') }
    [void]$markdown.AppendLine()
    [void]$markdown.AppendLine('## Routing')
    foreach ($recommendation in $Inspection.Recommendations) {
        [void]$markdown.AppendLine()
        [void]$markdown.AppendLine("### $($recommendation.Title)")
        [void]$markdown.AppendLine()
        [void]$markdown.AppendLine($recommendation.Reason)
        [void]$markdown.AppendLine()
        [void]$markdown.AppendLine('Inspect first:')
        foreach ($command in $recommendation.Inspect) { [void]$markdown.AppendLine("- ``$command``") }
        if ($recommendation.NextCapture) { [void]$markdown.AppendLine("- Capture gap: ``$($recommendation.NextCapture)``") }
    }

    $rows = [Text.StringBuilder]::new()
    foreach ($item in $Inspection.Evidence) {
        [void]$rows.Append("<tr><td>$(ConvertTo-HtmlValue $item.Kind)</td><td>$(ConvertTo-HtmlValue $item.Name)</td><td>$($item.Source)</td><td>$('{0:N0}' -f $item.Bytes)</td><td>$(ConvertTo-HtmlValue $item.ModifiedUtc)</td></tr>")
    }
    if ($Inspection.EvidenceCount -eq 0) { [void]$rows.Append('<tr><td colspan="5" class="muted">No evidence yet.</td></tr>') }
    $routing = [Text.StringBuilder]::new()
    foreach ($recommendation in $Inspection.Recommendations) {
        $commands = @($recommendation.Inspect | ForEach-Object { "<code>$(ConvertTo-HtmlValue $_)</code>" }) -join ' '
        $capture = if ($recommendation.NextCapture) { "<p><strong>Capture gap:</strong> <code>$(ConvertTo-HtmlValue $recommendation.NextCapture)</code></p>" } else { '' }
        [void]$routing.Append("<article><h3>$(ConvertTo-HtmlValue $recommendation.Title)</h3><p>$(ConvertTo-HtmlValue $recommendation.Reason)</p><p><strong>Inspect first:</strong> $commands</p>$capture</article>")
    }
    $chart = New-BarChartSvg $Inspection.Kinds
    $timeline = New-TimelineSvg $Inspection.Evidence
    $html = @"
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tricky: $(ConvertTo-HtmlValue $caseData.Name)</title>
<style>:root{color-scheme:dark;--bg:#101418;--panel:#182027;--ink:#e8edf2;--muted:#9fb0bf;--accent:#45b8ac}*{box-sizing:border-box}body{font:15px/1.5 system-ui,sans-serif;background:var(--bg);color:var(--ink);margin:0}main{max-width:1100px;margin:auto;padding:2rem}h1{margin-bottom:.2rem}header p,.muted{color:var(--muted)}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:1rem}.card,section,article{background:var(--panel);border:1px solid #2a3945;border-radius:10px;padding:1rem;margin:1rem 0}.metric{font-size:1.8rem;font-weight:700;color:var(--accent)}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:.55rem;border-bottom:1px solid #30404c}code{background:#0b1014;padding:.15rem .35rem;border-radius:4px}svg{width:100%;max-height:430px}svg rect{fill:var(--accent)}svg text{fill:var(--ink);font-size:12px}</style></head>
<body><main><header><h1>$(ConvertTo-HtmlValue $caseData.Name)</h1><p>$(ConvertTo-HtmlValue $caseData.Problem)</p><p><strong>Target:</strong> $(ConvertTo-HtmlValue $caseData.Target)</p></header>
<div class="cards"><div class="card"><div class="metric">$($Inspection.EvidenceCount)</div>evidence files</div><div class="card"><div class="metric">$('{0:N1}' -f ($Inspection.TotalBytes / 1MB)) MiB</div>total evidence</div><div class="card"><div class="metric">$($Inspection.Kinds.Count)</div>evidence types</div></div>
<section><h2>Evidence footprint</h2>$chart</section><section><h2>Evidence timeline</h2>$timeline</section><section><h2>Evidence inventory</h2><table><thead><tr><th>Type</th><th>File</th><th>Source</th><th>Bytes</th><th>Modified UTC</th></tr></thead><tbody>$rows</tbody></table></section>
<section><h2>Evidence-first routing</h2>$routing</section><p class="muted">Generated $($Inspection.InspectedUtc) by Tricky schema $($Inspection.SchemaVersion).</p></main></body></html>
"@
    $reportMd = Join-Path $directory 'report.md'
    $reportHtml = Join-Path $directory 'report.html'
    $reportJson = Join-Path $directory 'report.json'
    $markdown.ToString() | Set-Content -LiteralPath $reportMd -Encoding UTF8
    $html | Set-Content -LiteralPath $reportHtml -Encoding UTF8
    $Inspection | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportJson -Encoding UTF8
    [pscustomobject]@{ Markdown = $reportMd; Html = $reportHtml; Json = $reportJson }
}

function Show-Inspection {
    param([Parameter(Mandatory = $true)] $Inspection)
    Write-Host "Case: $($Inspection.Case.Name)"
    Write-Host "Problem: $($Inspection.Case.Problem)"
    Write-Host ("Evidence: {0} files, {1:N1} MiB" -f $Inspection.EvidenceCount, ($Inspection.TotalBytes / 1MB))
    if ($Inspection.Kinds.Count -gt 0) { $Inspection.Kinds | Format-Table Kind, Files, Bytes -AutoSize | Out-Host }
    foreach ($recommendation in $Inspection.Recommendations) {
        Write-Host "[$($recommendation.State)] $($recommendation.Title): $($recommendation.Reason)"
        foreach ($command in $recommendation.Inspect) { Write-Host "  inspect: $command" }
        if ($recommendation.NextCapture) { Write-Host "  capture: $($recommendation.NextCapture)" }
    }
}

switch ($Action.ToLowerInvariant()) {
    'new' {
        if (-not $Case) { throw 'Usage: tricky new <name> -Problem <description> [-Target <path-or-process>]' }
        if (-not $Problem) { throw 'New cases require -Problem so routing remains explainable.' }
        $directory = Resolve-CaseDirectory $Case
        if (Test-Path -LiteralPath $directory) { throw "The case directory already exists: $directory" }
        foreach ($relative in 'evidence\events', 'evidence\traces', 'evidence\packets', 'evidence\dumps', 'evidence\profiles', 'evidence\snapshots', 'normalized') {
            New-Item -ItemType Directory -Path (Join-Path $directory $relative) -Force | Out-Null
        }
        $now = [DateTime]::UtcNow.ToString('o')
        $data = [pscustomobject]@{
            SchemaVersion = 1; Name = ConvertTo-SafeName $Case; Problem = $Problem; Target = $Target; Status = 'open'; CreatedUtc = $now; UpdatedUtc = $now
            Host = [pscustomobject]@{ ComputerName = $env:COMPUTERNAME; UserName = $env:USERNAME; OsVersion = [Environment]::OSVersion.VersionString; PowerShellVersion = $PSVersionTable.PSVersion.ToString() }
        }
        Write-Case $directory $data
        $result = [pscustomobject]@{ Name = $data.Name; Directory = $directory; Problem = $Problem }
        if ($Json) { $result | ConvertTo-Json -Depth 5 } elseif ($AsObject) { $result } else { Write-Host "Created Tricky case: $directory" }
    }
    'list' {
        $cases = @(Get-ChildItem -LiteralPath $Root -Directory -Filter 'tricky-*' -ErrorAction Ignore | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'case.json') } | ForEach-Object {
            $data = Read-Case $_.FullName
            [pscustomobject]@{ Name = $data.Name; Status = $data.Status; UpdatedUtc = $data.UpdatedUtc; Problem = $data.Problem; Directory = $_.FullName }
        } | Sort-Object UpdatedUtc -Descending)
        if ($Json) { ConvertTo-Json -InputObject $cases -Depth 5 } else { $cases | Format-Table Name, Status, UpdatedUtc, Problem -AutoSize }
    }
    'add' {
        if (-not $Case -or -not $Path) { throw 'Usage: tricky add <case> -Path <file-or-directory> [-Copy]' }
        $directory = Resolve-CaseDirectory $Case -MustExist
        $source = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
        if ($Copy) {
            $item = Get-Item -LiteralPath $source
            $kind = if ($item -is [IO.FileInfo]) { Get-EvidenceKind $item } else { 'Other' }
            $folder = switch ($kind) { 'Event log' { 'events' } 'Packet capture' { 'packets' } 'Crash dump' { 'dumps' } 'Python profile' { 'profiles' } '.NET profile' { 'profiles' } 'ETW trace' { 'traces' } default { 'snapshots' } }
            $destination = Join-Path (Join-Path $directory 'evidence') (Join-Path $folder $item.Name)
            if (Test-Path -LiteralPath $destination) { throw "Evidence already exists: $destination" }
            Copy-Item -LiteralPath $source -Destination $destination -Recurse
            $result = [pscustomobject]@{ Mode = 'copy'; Source = $source; Destination = $destination; Kind = $kind }
        } else {
            $referenceFile = Join-Path $directory 'evidence\references.json'
            $references = @(Get-ReferenceEntries $directory)
            if (@($references | Where-Object Path -eq $source).Count -eq 0) {
                $entryItem = Get-Item -LiteralPath $source
                $kind = if ($entryItem -is [IO.FileInfo]) { Get-EvidenceKind $entryItem } else { 'Directory' }
                $references += [pscustomobject]@{ Id = [Guid]::NewGuid().ToString(); Path = $source; Kind = $kind; AddedUtc = [DateTime]::UtcNow.ToString('o') }
                ConvertTo-Json -InputObject @($references) -Depth 5 | Set-Content -LiteralPath $referenceFile -Encoding UTF8
            }
            $result = [pscustomobject]@{ Mode = 'reference'; Source = $source; Destination = $referenceFile; Kind = $kind }
        }
        $caseData = Read-Case $directory
        Write-Case $directory $caseData
        if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result | Format-List }
    }
    'inspect' {
        if (-not $Case) { throw 'Usage: tricky inspect <case> [-Hash] [-Json|-AsObject]' }
        $directory = Resolve-CaseDirectory $Case -MustExist
        $inspection = Get-Inspection $directory -IncludeHash:$Hash
        if ($Json) { $inspection | ConvertTo-Json -Depth 10 } elseif ($AsObject) { $inspection } else { Show-Inspection $inspection }
    }
    'report' {
        if (-not $Case) { throw 'Usage: tricky report <case> [-Hash] [-Open] [-Json]' }
        $directory = Resolve-CaseDirectory $Case -MustExist
        $inspection = Get-Inspection $directory -IncludeHash:$Hash
        $result = Write-Reports $inspection
        if ($Open) { Start-Process $result.Html }
        if ($Json) { $result | ConvertTo-Json } else { $result | Format-List }
    }
    'capabilities' {
        $catalog = Import-PowerShellDataFile -LiteralPath $script:CapabilityFile
        if ($Json) { $catalog | ConvertTo-Json -Depth 8 } else { $catalog.Capabilities | Select-Object Id, Title, @{ Name = 'Inspect'; Expression = { $_.InspectCommands -join '; ' } } | Format-Table -Wrap }
    }
}
