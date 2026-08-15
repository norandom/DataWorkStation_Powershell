[CmdletBinding()]
param(
    [ValidateSet('All', 'Behavior', 'BehaviorInterfaces', 'BehaviorPlanning', 'BehaviorSafety',
        'BehaviorDifferential', 'BinaryGraph', 'BinaryPlanning', 'BinaryIsolation', 'GraphArtifacts',
        'GraphSafety', 'GraphSchema', 'Query', 'QuerySchema', 'BinaryReporting', 'EvidenceBoundary',
        'Interfaces', 'Compatibility', 'Documentation')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('dws-analysis-diff-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Assert-Equal {
    param($Expected, $Actual, [string] $Message)
    $script:assertions++
    if ($Expected -ne $Actual) { throw "Assertion failed: $Message (expected '$Expected', got '$Actual')" }
}

function Get-Source {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
    Get-Content -LiteralPath $path -Raw
}

function Invoke-CapturedNative {
    param([string] $Executable, [string[]] $ArgumentList)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $capturedText = @(& $Executable @ArgumentList 2>&1 | ForEach-Object { [string] $_ }) -join "`n"
        $capturedExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    [pscustomobject]@{ Text = $capturedText; ExitCode = $capturedExitCode }
}

function Test-BehaviorInterfaces {
    $aliases = Get-Source 'profile/Aliases.ps1'
    foreach ($command in @('sandbox-behavior-control', 'sandbox-behavior-target', 'sandbox-behavior-diff')) {
        Assert-True ($aliases -match "function global:$([regex]::Escape($command))") "$command is a public human command"
    }
    Assert-True ($aliases -match '(?s)sandbox-behavior-control.*malware-control.*Detonate') 'control delegates to the established Detonate control path'
    Assert-True ($aliases -match '(?s)sandbox-behavior-target.*malware-sandbox.*Detonate') 'target delegates to the established Detonate target path'
    Assert-True ($aliases -match '(?s)sandbox-behavior-diff.*malware-diff') 'behavior comparison delegates to the established bounded differ'
}

function Test-BehaviorPlanning {
    $aliases = Get-Source 'profile/Aliases.ps1'
    Assert-True ($aliases -match '(?s)sandbox-behavior-control.*DurationSeconds.*Run') 'control exposes plan-by-default and bounded duration'
    Assert-True ($aliases -match '(?s)sandbox-behavior-target.*DurationSeconds.*Run') 'target exposes plan-by-default and bounded duration'
    Assert-True ($aliases -match '(?s)sandbox-behavior-control.*AllowNetwork.*KeepSandboxOpen') 'control preserves explicit policy switches'
    Assert-True ($aliases -match '(?s)sandbox-behavior-target.*AllowNetwork.*KeepSandboxOpen') 'target preserves explicit policy switches'
}

function Test-BehaviorSafety {
    $aliases = Get-Source 'profile/Aliases.ps1'
    $control = [regex]::Match($aliases, '(?s)function global:sandbox-behavior-control \{.*?\n\}').Value
    $target = [regex]::Match($aliases, '(?s)function global:sandbox-behavior-target \{.*?\n\}').Value
    Assert-True ($control -match 'ConfirmSandbox') 'control launch confirmation remains explicit'
    Assert-True ($control -notmatch 'ConfirmExecution') 'clean control cannot accept execution approval'
    Assert-True ($target -match 'ConfirmSandbox' -and $target -match 'ConfirmExecution') 'target requires separate Sandbox and execution approvals'
    Assert-True ($target -match 'malware-sandbox') 'target cannot execute on the host'
}

function Test-BehaviorDifferential {
    $aliases = Get-Source 'profile/Aliases.ps1'
    $body = [regex]::Match($aliases, '(?s)function global:sandbox-behavior-diff \{.*?\n\}').Value
    Assert-True ($body -match 'ControlCase' -and $body -match 'TargetCase') 'comparison accepts completed pair cases'
    Assert-True ($body -match 'ShowDiff' -and $body -match 'Json') 'comparison preserves deliberate diff display and machine output'
    Assert-True ($body -match 'malware-diff') 'comparison reuses compatibility and canonicalization checks'
}

function Test-BinaryPlanning {
    $source = Get-Source 'scripts/Invoke-BinaryDiffAnalysis.ps1'
    Assert-True ($source.Length -gt 0) 'binary differencing has a dedicated public script'
    foreach ($term in @('Baseline', 'Candidate', 'ConfirmContainer', 'Action', 'Plan', 'Run', 'Report')) {
        Assert-True ($source -match [regex]::Escape($term)) "binary script exposes $term"
    }
    Assert-True ($source -match 'ReparsePoint') 'both inputs reject reparse points'
    Assert-True ($source -match 'BaselineSha256' -and $source -match 'CandidateSha256') 'the plan binds both source hashes'
    Assert-True ($source -match 'Execution.*not-run') 'planning and static results state that inputs are not executed'
}

function Test-BinaryIsolation {
    $source = Get-Source 'scripts/Invoke-BinaryDiffAnalysis.ps1'
    $arguments = [regex]::Match($source, '(?s)\$containerArguments\s*=\s*@\(.*?\n\)').Value
    foreach ($term in @("'--network', 'none'", "'--read-only'", "'--cap-drop', 'ALL'", "'no-new-privileges'", "'--user'")) {
        Assert-True ($source -match [regex]::Escape($term)) "container plan enforces $term"
    }
    Assert-True ($source -match 'readonly' -and $source -match 'baseline' -and $source -match 'candidate') 'both binary mounts are read-only and role-specific'
    Assert-True ($arguments -notmatch "'--privileged'|'--network',\s*'host'|'--pid',\s*'host'|docker\.sock|podman\.sock") 'unsafe container flags and engine sockets are absent from the container plan'
    Assert-True ($source -match 'Run requires -ConfirmContainer') 'static parser execution requires explicit confirmation'
}

function Test-GraphArtifacts {
    $configuration = Get-Source 'config/malware-container.psd1'
    $inventory = Get-Source 'linux/malware-analysis/tool-inventory.json'
    $dockerfile = Get-Source 'linux/malware-analysis/Dockerfile'
    $runner = Get-Source 'linux/malware-analysis/entrypoint.py'
    foreach ($tool in @('binexport', 'bindiff')) {
        Assert-True ($configuration -match "Id='$tool'") "$tool is declared in desired image state"
        Assert-True ($inventory -match ('"Id"\s*:\s*"' + $tool + '"')) "$tool is present in the fingerprinted inventory"
    }
    Assert-True ($dockerfile -match 'BinExport' -and $dockerfile -match 'bindiff') 'image installs and verifies both graph tools'
    Assert-True ($dockerfile -match 'openjdk-21-jdk-headless' -and $dockerfile -match '/usr/bin/javac') 'BinExport build has a verified Java 21 compiler toolchain'
    Assert-True ($dockerfile -match 'useradd[^\r\n]*--home-dir /tmp/analyst') 'Ghidra user home resolves to the writable noexec tmpfs'
    Assert-True ($runner -match 'Path\(ANALYSIS_HOME\)\.mkdir') 'runner prepares the isolated analysis home before Ghidra starts'
    Assert-True ($runner -match 'graph_script_root' -and $runner -match 'shutil\.copy2') 'graph exporter is isolated in a private script bundle'
    $analysisCommand = [regex]::Match($runner, '(?s)analysis_command\s*=\s*\[(.*?)\n\s*\]').Groups[1].Value
    Assert-True ($analysisCommand -match 'str\(graph_script_root\)' -and $analysisCommand -notmatch '/opt/analysis') 'graph analysis never compiles unrelated repository Java scripts as one bundle'
    Assert-True ($runner -match 'DEFAULT_MAX_OPEN_FILES\s*=\s*256' -and $runner -match 'GRAPH_MAX_OPEN_FILES\s*=\s*1024') 'graph compilation receives a bounded file limit without widening other parsers'
    Assert-True (([regex]::Matches($runner, 'max_open_files=GRAPH_MAX_OPEN_FILES')).Count -eq 2) 'only Ghidra analysis and BinExport receive the graph file limit'
    foreach ($artifact in @('baseline.BinExport', 'candidate.BinExport', 'baseline_vs_candidate.BinDiff')) {
        Assert-True ($runner -match [regex]::Escape($artifact)) "runner retains $artifact"
    }
    Assert-True ($runner -match 'InventoryIdentity' -and $runner -match 'Version') 'graph artifact status retains stable tool provenance'
}

function Test-GraphSafety {
    $runner = Get-Source 'linux/malware-analysis/entrypoint.py'
    Assert-True ($runner -match 'structural-graph') 'graph matching is identified as the primary comparison'
    Assert-True ($runner -match 'missing-tool' -and $runner -match 'timed-out' -and $runner -match 'partial') 'graph tool failures remain explicit'
    Assert-True ($runner -notmatch 'PrimaryComparison.*raw|PrimaryComparison.*version|PrimaryComparison.*decomp') 'raw/version/code diffs never become the primary comparison'
    Assert-True ($runner -match 'never-executed' -or $runner -match 'not-run') 'binary execution state remains explicit'
}

function Test-GraphSchema {
    $runner = Get-Source 'linux/malware-analysis/entrypoint.py'
    foreach ($table in @('metadata', 'file', 'function', 'basicblock', 'instruction')) {
        $quotedTable = "['`"]$([regex]::Escape($table))['`"]"
        Assert-True ($runner -match $quotedTable) "BinDiff schema validates $table"
    }
    foreach ($field in @('similarity', 'confidence', 'address1', 'address2', 'algorithm')) {
        Assert-True ($runner -match $field) "bounded match projection includes $field"
    }
    Assert-True ($runner -match 'query_only' -or $runner -match 'mode=ro') 'the BinDiff database is opened read-only for projection'
    $python = Join-Path $repositoryRoot '.venv\Scripts\python.exe'
    Assert-True (Test-Path -LiteralPath $python -PathType Leaf) 'repository Python is available for the synthetic graph SQL test'
    $result = Invoke-CapturedNative $python @((Join-Path $repositoryRoot 'tests\test_binary_diff_runner.py'))
    Assert-Equal 0 $result.ExitCode "synthetic graph SQL and immutable sidecar test passes: $($result.Text)"
}

function Test-QuerySchema {
    $exporter = Get-Source 'scripts/ExportGhidraAnalysis.java'
    $runner = Get-Source 'linux/malware-analysis/entrypoint.py'
    foreach ($concept in @('Function', 'Instruction', 'BasicBlock', 'Reference', 'Decompile')) {
        Assert-True ($exporter -match $concept) "Ghidra exporter covers $concept records"
    }
    foreach ($table in @('binaries', 'functions', 'basic_blocks', 'instructions', 'edges', 'calls', 'function_matches')) {
        Assert-True ($runner -match ('CREATE TABLE ' + $table)) "query sidecar creates $table"
    }
    Assert-True ($runner -match 'binary-analysis\.sqlite') 'query sidecar has a stable artifact name'
    Assert-True ($runner -match 'max_page_count') 'query sidecar growth is bounded inside the isolated parser'
    Assert-True ($runner -notmatch 'ALTER TABLE.*BinDiff|UPDATE.*BinDiff|INSERT INTO.*BinDiff') 'the official match database is not modified'
}

function Test-BinaryReporting {
    $source = Get-Source 'scripts/Invoke-BinaryDiffAnalysis.ps1'
    foreach ($field in @('OverallSimilarity', 'OverallConfidence', 'MatchedFunctions', 'ChangedFunctions', 'AddedFunctions', 'RemovedFunctions', 'AmbiguousFunctions', 'Verdict')) {
        Assert-True ($source -match $field) "binary report exposes $field"
    }
    Assert-True ($source -match 'Read-MalwareEvidence\.ps1') 'reports cross the existing bounded Python evidence boundary'
    Assert-True ($source -match 'undetermined') 'binary comparison remains a non-verdict'
}

function Test-EvidenceBoundary {
    $ingestor = Get-Source 'linux/malware-analysis/evidence_ingest.py'
    Assert-True ($ingestor -match 'BinaryDiff') 'bounded ingestor recognizes the binary-diff summary schema'
    Assert-True ($ingestor -match 'OpaqueArtifacts') 'databases and graph exports remain opaque host artifacts'
    Assert-True ($ingestor -match 'max_records' -and $ingestor -match 'max_string') 'binary summary retains record and string bounds'
    $reader = Get-Source 'scripts/Read-MalwareEvidence.ps1'
    Assert-True ($reader -match 'evidence_ingest\.py') 'PowerShell delegates raw evidence parsing to Python'

    $caseRoot = Join-Path $temporaryRoot 'binary-evidence'
    $output = Join-Path $caseRoot 'output'
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    $summary = Join-Path $output 'binary-diff-summary.json'
    $record = [ordered]@{
        SchemaVersion = 1; AnalysisKind = 'BinaryDiff'; Status = 'complete'; ResultFinalized = $true
        Backend = 'RootlessContainer'; PrimaryComparison = 'structural-graph'
        BaselineSha256 = ('A' * 64); CandidateSha256 = ('B' * 64)
        OverallSimilarity = 0.9; OverallConfidence = 0.8
        MatchedFunctions = 10; ChangedFunctions = 2; AddedFunctions = 1
        RemovedFunctions = 1; AmbiguousFunctions = 0
        ToolStatus = @(@{ Tool = 'bindiff'; State = 'complete'; Artifacts = @('baseline_vs_candidate.BinDiff') })
        Failures = @(); Findings = @(); Execution = 'not-run'; Verdict = 'undetermined'
    }
    [IO.File]::WriteAllText($summary, ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $python = Join-Path $repositoryRoot '.venv\Scripts\python.exe'
    Assert-True (Test-Path -LiteralPath $python -PathType Leaf) 'repository Python boundary is available'
    $validation = Invoke-CapturedNative $python @(
        (Join-Path $repositoryRoot 'linux\malware-analysis\evidence_ingest.py'),
        '--case-root', $caseRoot, '--summary', $summary
    )
    Assert-Equal 0 $validation.ExitCode 'valid graph summary crosses the bounded Python boundary'
    $validated = $validation.Text | ConvertFrom-Json
    Assert-Equal 'structural-graph' $validated.Display.PrimaryComparison 'validated display retains graph primacy'
    $record.PrimaryComparison = 'raw-version'
    [IO.File]::WriteAllText($summary, ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $rejected = Invoke-CapturedNative $python @(
        (Join-Path $repositoryRoot 'linux\malware-analysis\evidence_ingest.py'),
        '--case-root', $caseRoot, '--summary', $summary
    )
    Assert-True ($rejected.ExitCode -ne 0 -and $rejected.Text -match 'structural-graph') 'raw/version primary results fail closed'
    $record.PrimaryComparison = 'structural-graph'
    $record.ChangedFunctions = 11
    [IO.File]::WriteAllText($summary, ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $inconsistent = Invoke-CapturedNative $python @(
        (Join-Path $repositoryRoot 'linux\malware-analysis\evidence_ingest.py'),
        '--case-root', $caseRoot, '--summary', $summary
    )
    Assert-True ($inconsistent.ExitCode -ne 0 -and $inconsistent.Text -match 'count') 'inconsistent graph summary counts fail closed'
}

function Test-Interfaces {
    $aliases = Get-Source 'profile/Aliases.ps1'
    Assert-True ($aliases -match 'function global:binary-diff') 'binary-diff is a public human command'
    Assert-True ($aliases -match 'function global:binary-diff-report') 'binary-diff-report inspects existing evidence'
    $capabilities = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config/capabilities.psd1')
    $route = @($capabilities.Capabilities | Where-Object Id -eq 'malware-triage')
    Assert-Equal 1 $route.Count 'analysis commands remain in the focused malware/static capability'
    $commands = @($route[0].InspectCommands) + @($route[0].StateCommands)
    foreach ($command in @('sandbox-behavior-control', 'sandbox-behavior-target', 'sandbox-behavior-diff', 'binary-diff')) {
        Assert-True (($commands -join "`n") -match [regex]::Escape($command)) "$command is routed in the capability catalog"
    }
}

function Test-Compatibility {
    $aliases = Get-Source 'profile/Aliases.ps1'
    Assert-True ($aliases -notmatch '\?\?|\?\.|ForEach-Object\s+-Parallel|&&|\|\|') 'new profile functions avoid PowerShell 7-only syntax'
    $script = Get-Source 'scripts/Invoke-BinaryDiffAnalysis.ps1'
    Assert-True ($script -notmatch '\?\?|\?\.|ForEach-Object\s+-Parallel|&&|\|\|') 'binary script avoids PowerShell 7-only syntax'
}

function Test-Documentation {
    $guide = Get-Source 'docs/analysis-differencing.md'
    foreach ($term in @('host-static', 'Dissect', 'disass', 'decomp', 'binary-diff', 'sandbox-behavior', 'BinExport', 'BinDiff', 'SQLite', 'graph')) {
        Assert-True ($guide -match [regex]::Escape($term)) "case guide documents $term"
    }
    Assert-True ($guide -match 'not.*raw|raw.*not') 'guide rejects raw comparison as the graph-match substitute'
    Assert-True ($guide -match 'attack surface|residual') 'guide documents residual attack surface'
    $mkdocs = Get-Source 'mkdocs.yml'
    Assert-True ($mkdocs -match 'analysis-differencing\.md') 'case guide is in MkDocs navigation'
}

$sections = [ordered]@{
    BehaviorInterfaces = ${function:Test-BehaviorInterfaces}
    BehaviorPlanning = ${function:Test-BehaviorPlanning}
    BehaviorSafety = ${function:Test-BehaviorSafety}
    BehaviorDifferential = ${function:Test-BehaviorDifferential}
    BinaryPlanning = ${function:Test-BinaryPlanning}
    BinaryIsolation = ${function:Test-BinaryIsolation}
    GraphArtifacts = ${function:Test-GraphArtifacts}
    GraphSafety = ${function:Test-GraphSafety}
    GraphSchema = ${function:Test-GraphSchema}
    QuerySchema = ${function:Test-QuerySchema}
    BinaryReporting = ${function:Test-BinaryReporting}
    EvidenceBoundary = ${function:Test-EvidenceBoundary}
    Interfaces = ${function:Test-Interfaces}
    Compatibility = ${function:Test-Compatibility}
    Documentation = ${function:Test-Documentation}
}

try {
    $selected = switch ($Section) {
        All { @($sections.Keys) }
        Behavior { @('BehaviorInterfaces', 'BehaviorPlanning', 'BehaviorSafety', 'BehaviorDifferential') }
        BinaryGraph { @('BinaryPlanning', 'BinaryIsolation', 'GraphArtifacts', 'GraphSafety', 'GraphSchema', 'BinaryReporting') }
        Query { @('QuerySchema', 'EvidenceBoundary') }
        default { @($Section) }
    }
    foreach ($name in $selected) {
        & $sections[$name]
        Write-Host "PASS $name"
    }
    Write-Host "Analysis differencing tests passed: $script:assertions assertions."
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        [IO.Directory]::Delete($temporaryRoot, $true)
    }
}
