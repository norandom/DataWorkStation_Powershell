[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Run', 'Report')]
    [string] $Action = 'Plan',
    [string] $Baseline,
    [string] $Candidate,
    [string] $Case,
    [string] $CaseRoot,
    [switch] $ConfirmContainer,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\malware-container.psd1')
$imageReference = "$($configuration.ImageRepository):$($configuration.ImageTag)"
$inventoryPath = Join-Path $repositoryRoot $configuration.Inventory
$toolInventoryFingerprint = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash

function Write-JsonFile {
    param([string] $LiteralPath, [object] $Value)
    [IO.File]::WriteAllText(
        $LiteralPath,
        ($Value | ConvertTo-Json -Depth 20),
        [Text.UTF8Encoding]::new($false)
    )
}

function Write-Result {
    param([object] $Value, [switch] $AsJson)
    if ($AsJson) { $Value | ConvertTo-Json -Depth 20; return }
    $Value | Format-List | Out-Host
}

function ConvertTo-WslPath {
    param([Parameter(Mandatory = $true)][string] $WindowsPath)
    $fullPath = [IO.Path]::GetFullPath($WindowsPath)
    if ($fullPath -notmatch '^([A-Za-z]):\\(.*)$') { throw "Unsupported Windows path: $fullPath" }
    "/mnt/$($Matches[1].ToLowerInvariant())/$($Matches[2].Replace('\', '/'))"
}

function Get-BuildContextFingerprint {
    $records = foreach ($relativePath in @($configuration.BuildInputs | Sort-Object)) {
        $inputPath = Join-Path $repositoryRoot $relativePath
        if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
            throw "Declared malware image build input is missing: $relativePath"
        }
        "$(([string] $relativePath).Replace('\', '/')):$((Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash)"
    }
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($records -join "`n"))
        ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '')
    } finally {
        $algorithm.Dispose()
    }
}

function Get-IsolationPolicyFingerprint {
    $policy = [ordered]@{
        Backend = 'RootlessContainer'
        AnalysisKind = 'BinaryDiff'
        Network = 'none'
        ReadOnlyRoot = $true
        Inputs = 'read-only'
        CapDrop = 'ALL'
        NoNewPrivileges = $true
        RuntimeUser = $configuration.RuntimeUser
        Pids = $configuration.Limits.Pids
        Memory = $configuration.Limits.Memory
        Cpus = $configuration.Limits.Cpus
    } | ConvertTo-Json -Compress
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($policy))
        ([BitConverter]::ToString($hash)).Replace('-', '')
    } finally {
        $algorithm.Dispose()
    }
}

function Get-RegularInput {
    param([Parameter(Mandatory = $true)][string] $LiteralPath, [string] $Role)
    $item = Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "$Role must be a regular, non-reparse-point file."
    }
    if ($item.Length -gt [int64] $configuration.Limits.MaxSampleBytes) {
        throw "$Role exceeds the static-container limit of $($configuration.Limits.MaxSampleBytes) bytes."
    }
    $item
}

function Convert-ValidatedReport {
    param([object] $Validated, [string] $CaseDirectory)
    $display = $Validated.Display
    [pscustomobject]@{
        SchemaVersion = 1
        Status = [string] $display.Status
        AnalysisKind = 'BinaryDiff'
        Backend = 'RootlessContainer'
        Case = $CaseDirectory
        BaselineSha256 = [string] $display.BaselineSha256
        CandidateSha256 = [string] $display.CandidateSha256
        PrimaryComparison = [string] $display.PrimaryComparison
        OverallSimilarity = $display.OverallSimilarity
        OverallConfidence = $display.OverallConfidence
        MatchedFunctions = [int] $display.MatchedFunctions
        ChangedFunctions = [int] $display.ChangedFunctions
        AddedFunctions = [int] $display.AddedFunctions
        RemovedFunctions = [int] $display.RemovedFunctions
        AmbiguousFunctions = [int] $display.AmbiguousFunctions
        ToolStatus = @($display.ToolStatus)
        Failures = @($display.Failures)
        OpaqueArtifacts = @($Validated.OpaqueArtifacts)
        Execution = 'not-run'
        Verdict = 'undetermined'
    }
}

if ($Action -eq 'Run' -and -not $ConfirmContainer) {
    throw 'Run requires -ConfirmContainer. This explicitly permits non-executing graph parsers to read both binaries inside the rootless container.'
}

if ($Action -eq 'Report') {
    if (-not $Case) { throw 'Report requires -Case.' }
    $caseDirectory = (Get-Item -LiteralPath $Case -ErrorAction Stop).FullName
    $summaryPath = Join-Path $caseDirectory 'output\binary-diff-summary.json'
    $validatedJson = & (Join-Path $PSScriptRoot 'Read-MalwareEvidence.ps1') `
        -Case $caseDirectory -Summary $summaryPath -Json
    $validated = $validatedJson | ConvertFrom-Json -ErrorAction Stop
    Write-Result (Convert-ValidatedReport -Validated $validated -CaseDirectory $caseDirectory) -AsJson:$Json
    exit 0
}

if (-not $Baseline -or -not $Candidate) { throw "$Action requires -Baseline and -Candidate." }
$baselineItem = Get-RegularInput -LiteralPath $Baseline -Role 'Baseline'
$candidateItem = Get-RegularInput -LiteralPath $Candidate -Role 'Candidate'
$baselinePath = $baselineItem.FullName
$candidatePath = $candidateItem.FullName
$baselineHash = (Get-FileHash -LiteralPath $baselinePath -Algorithm SHA256).Hash
$candidateHash = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash
$buildContextFingerprint = Get-BuildContextFingerprint

$root = if ($CaseRoot) { [IO.Path]::GetFullPath($CaseRoot) } else { Join-Path $repositoryRoot 'evidence\malware' }
New-Item -ItemType Directory -Path $root -Force | Out-Null
$caseDirectory = Join-Path $root ('binary-diff-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
$inputDirectory = Join-Path $caseDirectory 'input'
$outputDirectory = Join-Path $caseDirectory 'output'
New-Item -ItemType Directory -Path $inputDirectory, $outputDirectory -Force | Out-Null
$caseBaseline = Join-Path $inputDirectory 'baseline'
$caseCandidate = Join-Path $inputDirectory 'candidate'
[IO.File]::Copy($baselinePath, $caseBaseline, $false)
[IO.File]::Copy($candidatePath, $caseCandidate, $false)

$wslCase = ConvertTo-WslPath $caseDirectory
$containerName = 'dws-binary-diff-' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$containerArguments = @(
    'run', '--rm', '--name', $containerName,
    '--network', 'none',
    '--read-only',
    '--cap-drop', 'ALL',
    '--security-opt', 'no-new-privileges',
    '--pids-limit', [string] $configuration.Limits.Pids,
    '--memory', [string] $configuration.Limits.Memory,
    '--cpus', [string] $configuration.Limits.Cpus,
    '--user', [string] $configuration.RuntimeUser,
    '--tmpfs', "/tmp:rw,$($configuration.Limits.Tmpfs)",
    '--mount', "type=bind,source=$wslCase/input/baseline,target=/input/baseline,readonly",
    '--mount', "type=bind,source=$wslCase/input/candidate,target=/input/candidate,readonly",
    '--mount', "type=bind,source=$wslCase/output,target=/output",
    $imageReference,
    '--analysis-kind', 'binary-diff',
    '--baseline', '/input/baseline',
    '--candidate', '/input/candidate',
    '--baseline-hash', $baselineHash,
    '--candidate-hash', $candidateHash,
    '--tool-timeout', [string] $configuration.Limits.ToolSeconds,
    '--max-output', [string] $configuration.Limits.MaxOutputBytes,
    '--max-artifact', [string] $configuration.Limits.MaxArtifactBytes,
    '--max-sample', [string] $configuration.Limits.MaxSampleBytes,
    '--max-records', [string] $configuration.Limits.MaxRecords,
    '--max-string', [string] $configuration.Limits.MaxString
)

$manifestPath = Join-Path $caseDirectory 'manifest.json'
$planPath = Join-Path $caseDirectory 'container-plan.json'
$manifest = [ordered]@{
    SchemaVersion = 1
    Status = 'planned'
    Mode = 'BinaryDiff'
    AnalysisKind = 'BinaryDiff'
    Backend = 'RootlessContainer'
    RuntimeName = 'podman'
    RuntimeVersion = $null
    BaselineSourcePath = $baselinePath
    CandidateSourcePath = $candidatePath
    BaselineSha256 = $baselineHash
    CandidateSha256 = $candidateHash
    DurationSeconds = [int] $configuration.Limits.DurationSeconds
    NetworkEnabled = $false
    Image = $imageReference
    ImageId = $null
    ToolInventoryFingerprint = $toolInventoryFingerprint
    BuildContextFingerprint = $buildContextFingerprint
    IsolationPolicyFingerprint = Get-IsolationPolicyFingerprint
    PrimaryComparison = 'structural-graph'
    Execution = 'not-run'
    Verdict = 'undetermined'
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
}
$plan = [ordered]@{
    SchemaVersion = 1
    Distribution = [string] $configuration.RequiredDistribution
    Runtime = 'podman'
    Image = $imageReference
    AnalysisKind = 'BinaryDiff'
    Case = $caseDirectory
    ContainerArguments = $containerArguments
}
Write-JsonFile -LiteralPath $manifestPath -Value $manifest
Write-JsonFile -LiteralPath $planPath -Value $plan

if ($Action -eq 'Plan') {
    Write-Result ([pscustomobject]@{
        SchemaVersion = 1
        Status = 'planned'
        AnalysisKind = 'BinaryDiff'
        Backend = 'RootlessContainer'
        Distribution = [string] $configuration.RequiredDistribution
        Case = $caseDirectory
        Baseline = $baselinePath
        BaselineSha256 = $baselineHash
        Candidate = $candidatePath
        CandidateSha256 = $candidateHash
        PrimaryComparison = 'structural-graph'
        Network = 'none'
        Inputs = 'read-only'
        Manifest = $manifestPath
        ContainerPlan = $planPath
        Execution = 'not-run'
        Verdict = 'undetermined'
    }) -AsJson:$Json
    exit 0
}

. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
$distribution = [string] $wslEnvironment.WSL_MALWARE_DISTRIBUTION
$user = [string] $wslEnvironment.WSL_MALWARE_USER
if ($distribution -ne [string] $configuration.RequiredDistribution) {
    throw "Binary differencing requires WSL_MALWARE_DISTRIBUTION=$($configuration.RequiredDistribution)."
}

$podmanInfo = @(& wsl.exe -d $distribution --user $user --exec podman info --format json 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) { throw "Rootless engine inspection failed: $podmanInfo" }
$podmanActive = @(& wsl.exe -d $distribution --user $user --exec systemctl --user is-active podman.socket podman.service 2>$null)
$podmanEnabled = @(& wsl.exe -d $distribution --user $user --exec systemctl --user is-enabled podman.socket podman.service 2>$null)
$serviceState = [pscustomobject]@{
    Active = (@($podmanActive | Where-Object { ([string] $_).Trim() -eq 'active' }).Count -gt 0)
    Enabled = (@($podmanEnabled | Where-Object { ([string] $_).Trim() -in @('enabled', 'static', 'indirect') }).Count -gt 0)
} | ConvertTo-Json -Compress
& (Join-Path $PSScriptRoot 'Test-MalwareContainerIsolation.ps1') `
    -PodmanInfoJson $podmanInfo -PodmanServiceStateJson $serviceState `
    -ContainerArguments $containerArguments -CaseRoot $wslCase -RequireReady | Out-Null

$imageText = @(& wsl.exe -d $distribution --user $user --exec podman image inspect $imageReference --format '{{json .}}' 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'The reviewed local image is unavailable. Test or explicitly ensure MalwareContainerImage first.' }
if ([Text.Encoding]::UTF8.GetByteCount($imageText) -gt 1048576) { throw 'Local image inspection returned more than 1 MiB.' }
$image = $imageText | ConvertFrom-Json -ErrorAction Stop
if ([string] $image.Config.Labels.'org.dataworkstation.tool-inventory-sha256' -ne $toolInventoryFingerprint) {
    throw 'The local parser image tool inventory does not match the reviewed repository inventory.'
}
if ([string] $image.Config.Labels.'org.dataworkstation.build-context-sha256' -ne $buildContextFingerprint) {
    throw 'The local parser image is stale relative to the reviewed build inputs.'
}

$manifest.Status = 'running'
$manifest.ImageId = [string] $image.Id
$manifest.RuntimeVersion = [string] (($podmanInfo | ConvertFrom-Json -ErrorAction Stop).Version.Version)
Write-JsonFile -LiteralPath $manifestPath -Value $manifest
& wsl.exe -d $distribution --user $user --exec timeout --signal=TERM --kill-after=10s `
    "$($configuration.Limits.DurationSeconds)s" podman @containerArguments
$containerExitCode = $LASTEXITCODE
if ($containerExitCode -ne 0) {
    if ($containerExitCode -eq 124) { & wsl.exe -d $distribution --user $user --exec podman rm --force $containerName 2>$null | Out-Null }
    $manifest.Status = 'failed'
    Write-JsonFile -LiteralPath $manifestPath -Value $manifest
    throw "Binary-diff container exited with code $containerExitCode."
}

$manifest.Status = 'complete'
Write-JsonFile -LiteralPath $manifestPath -Value $manifest
try {
    $summaryPath = Join-Path $caseDirectory 'output\binary-diff-summary.json'
    $validatedJson = & (Join-Path $PSScriptRoot 'Read-MalwareEvidence.ps1') `
        -Case $caseDirectory -Summary $summaryPath -Json
} catch {
    $manifest.Status = 'untrusted-output-rejected'
    Write-JsonFile -LiteralPath $manifestPath -Value $manifest
    throw "Binary-diff output failed the hostile-evidence boundary. $($_.Exception.Message)"
}
$validated = $validatedJson | ConvertFrom-Json -ErrorAction Stop
Write-Result (Convert-ValidatedReport -Validated $validated -CaseDirectory $caseDirectory) -AsJson:$Json
