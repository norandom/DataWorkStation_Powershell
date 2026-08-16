[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Injected test seams use fixed callback signatures; individual cases intentionally ignore some arguments.')]
[CmdletBinding()]
param(
    [ValidateSet(
        'All', 'HumanInterface', 'NativeWindowsBoundary', 'Planning', 'EvidenceReadOnly',
        'SegmentInventory', 'SegmentIntegrity', 'MediaDigests', 'HashlessEvidence',
        'FormatCertification', 'InvocationEvidence', 'ReportContract', 'JsonParity',
        'HostileOutput', 'CatalogSchema', 'InstallIntegrity', 'ToolDrift', 'UpdatePolicy',
        'UpgradeCertification', 'CertificationCorpus', 'HistoricalAttribution',
        'OfflineExecution', 'ReportPersistence', 'DocumentationRouting',
        'RuntimeCompatibility', 'ReleasePackageContract', 'InstallWithoutBuild',
        'BuildRevisionPolicy', 'ReleaseTrustAnchor'
    )]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0
. (Join-Path $PSScriptRoot 'helpers\NativeForensicTestSupport.ps1')

function Assert-True {
    param([bool] $Condition, [string] $Message)
    [void] ($script:assertions++)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Assert-Equal {
    param($Actual, $Expected, [string] $Message)
    [void] ($script:assertions++)
    if ($Actual -ne $Expected) {
        throw "Assertion failed: $Message (expected '$Expected', observed '$Actual')"
    }
}

function Get-Source {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$RelativePath exists"
    Get-Content -LiteralPath $path -Raw
}

function Get-StableVerificationFacts {
    param([Parameter(Mandatory)] $Result)

    [ordered]@{
        status = $Result.status
        verified = $Result.verified
        tool = [ordered]@{
            toolId = $Result.tool.toolId
            upstreamVersion = $Result.tool.upstreamVersion
            buildRevision = $Result.tool.buildRevision
            catalogFileSha256 = $Result.tool.catalogFileSha256
            packageSha256 = $Result.tool.packageSha256
            files = @($Result.tool.files | ForEach-Object { [ordered]@{ relativePath = $_.relativePath; size = $_.size; sha256 = $_.sha256 } })
            sourceArtifacts = @($Result.tool.sourceArtifacts | ForEach-Object { [ordered]@{ name = $_.name; size = $_.size; sha256 = $_.sha256; origin = $_.origin } })
        }
        evidence = [ordered]@{
            formatProfile = $Result.evidence.formatProfile
            totalBytes = $Result.evidence.totalBytes
            segments = @($Result.evidence.segments | ForEach-Object {
                [ordered]@{ ordinal = $_.ordinal; name = $_.name; extension = $_.extension; preLength = $_.preLength; preSha256 = $_.preSha256; postLength = $_.postLength; postSha256 = $_.postSha256; unchanged = $_.unchanged }
            })
        }
        invocation = [ordered]@{ exitCode = $Result.invocation.exitCode; parserProfile = $Result.invocation.parserProfile }
        mediaDigests = @($Result.mediaDigests)
        warnings = @($Result.warnings | Where-Object { $_ -notmatch 'Catalog commit is unavailable' })
        failure = $Result.failure
    }
}

function New-US1TestContext {
    param([string] $Name = 'us1')

    $root = New-NativeForensicTestRoot -Name $Name
    $evidenceRoot = Join-Path $root 'evidence'
    [void] (New-Item -ItemType Directory -Path $evidenceRoot)
    $fixtureRoot = Join-Path $repositoryRoot 'tests\fixtures\ewf'
    Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.E*' -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $evidenceRoot
    }
    $package = New-SyntheticNativeForensicPackage -Root $root
    $catalog = New-SyntheticNativeForensicCatalog -Root $root -Package $package
    [pscustomobject]@{
        Root = $root
        EvidenceRoot = $evidenceRoot
        ReportRoot = New-NativeForensicReportRoot -Root $root
        Catalog = $catalog
        Ordinary = Join-Path $evidenceRoot 'ordinary.E01'
        OrdinaryLaterSegment = Join-Path $evidenceRoot 'ordinary.E02'
        Hashless = Join-Path $evidenceRoot 'hashless.E01'
    }
}

function Invoke-US1Verifier {
    param(
        [Parameter(Mandatory)] $Context,
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][scriptblock] $NativeProcessRunner,
        [switch] $Plan,
        [scriptblock] $FileIdentityProvider,
        [scriptblock] $SegmentCandidateProvider,
        [string] $ReportDirectory,
        [scriptblock] $RunIdProvider,
        [scriptblock] $PersistenceFaultProvider,
        [scriptblock] $PreInvocationHook,
        [scriptblock] $CatalogCommitProvider
    )

    $scriptPath = Join-Path $repositoryRoot 'scripts\Invoke-EwfVerification.ps1'
    Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) 'scripts/Invoke-EwfVerification.ps1 exists'
    $invokeParameters = @{
        Path = $Path
        ReportDirectory = if ($PSBoundParameters.ContainsKey('ReportDirectory')) { $ReportDirectory } else { $Context.ReportRoot }
        CatalogPath = $Context.Catalog.Path
        NativeProcessRunner = $NativeProcessRunner
        PassThru = $true
    }
    if ($Plan) { $invokeParameters.Plan = $true }
    if ($null -ne $FileIdentityProvider) {
        $invokeParameters.FileIdentityProvider = $FileIdentityProvider
    }
    if ($null -ne $SegmentCandidateProvider) {
        $invokeParameters.SegmentCandidateProvider = $SegmentCandidateProvider
    }
    if ($null -ne $RunIdProvider) { $invokeParameters.RunIdProvider = $RunIdProvider }
    if ($null -ne $PersistenceFaultProvider) { $invokeParameters.PersistenceFaultProvider = $PersistenceFaultProvider }
    if ($null -ne $PreInvocationHook) { $invokeParameters.PreInvocationHook = $PreInvocationHook }
    if ($null -ne $CatalogCommitProvider) { $invokeParameters.CatalogCommitProvider = $CatalogCommitProvider }
    $output = @(. $scriptPath @invokeParameters)
    $results = @($output | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties['status'] })
    Assert-Equal $results.Count 1 'the test seam returns exactly one result object'
    $results[0]
}

function Invoke-ForensicToolState {
    param(
        [ValidateSet('Plan', 'Test', 'Ensure')][string] $Mode,
        [Parameter(Mandatory)][string] $CatalogPath,
        [string] $PackagePath,
        [scriptblock] $InstallFaultProvider
    )
    $scriptPath = Join-Path $repositoryRoot 'scripts\Set-NativeForensicToolsState.ps1'
    Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) 'scripts/Set-NativeForensicToolsState.ps1 exists'
    $parameters = @{ Mode = $Mode; CatalogPath = $CatalogPath; PassThru = $true }
    if ($PackagePath) {
        $parameters.PackagePath = $PackagePath
        $parameters.AttestationVerifier = { param($LiteralPath, $Record) $null = $LiteralPath; $null = $Record; $true }
    }
    if ($null -ne $InstallFaultProvider) { $parameters.InstallFaultProvider = $InstallFaultProvider }
    $output = @(. $scriptPath @parameters)
    $results = @($output | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties['state'] })
    Assert-Equal $results.Count 1 'tool state seam returns exactly one result object'
    $results[0]
}

function Test-HumanInterface {
    $scriptSource = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    $profileSource = Get-Source 'profile/ForensicTools.ps1'
    $profilePath = Join-Path $repositoryRoot 'profile\ForensicTools.ps1'
    . $profilePath
    $command = Get-Command ewf-verify -CommandType Function -ErrorAction Stop
    Assert-True ($scriptSource -match '\[switch\]\s*\$Json') 'direct command offers JSON on the human interface'
    Assert-True ($scriptSource -match '\[Parameter\(Mandatory[^\]]*\)\][^\r\n]*\$Path') 'direct command requires an evidence path'
    Assert-True ($scriptSource -match '\$ReportDirectory') 'direct command requires a report destination'
    Assert-True ($profileSource -match 'ewf-verify') 'profile exposes the human command'
    Assert-True ($command.Definition -match 'scripts\\Invoke-EwfVerification\.ps1') 'human command resolves the repository verifier script'
    Assert-True ($command.Parameters.ContainsKey('Path') -and $command.Parameters.ContainsKey('ReportDirectory')) 'human command preserves the required public parameters'
    Assert-True ($command.Parameters.ContainsKey('Plan') -and $command.Parameters.ContainsKey('Json')) 'human command preserves plan and machine-output switches'
    Assert-True ((Get-Source 'profile/Shell.ps1') -match 'ForensicTools\.ps1') 'profile loader imports the forensic component'
    Assert-True ((Get-Source 'scripts/Set-PowerShellProfile.ps1') -match 'ForensicTools\.ps1') 'profile desired state deploys the forensic component'
}

function Test-NativeWindowsBoundary {
    $verification = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    $installer = Get-Source 'scripts/Set-NativeForensicToolsState.ps1'
    $builder = Get-Source 'scripts/Build-NativeForensicTool.ps1'
    $candidate = Get-Source 'scripts/Test-ForensicReleaseCandidate.ps1'
    $nativeSources = $verification + $installer + $builder + $candidate
    Assert-True ($verification -notmatch 'wsl\.exe|docker|podman|cygwin|msys|mingw|git bash') 'verification has no non-native compatibility runtime'
    Assert-True ($verification -match 'Platform.*Win32NT|IsWindows|Windows') 'runtime fails closed outside native Windows'
    Assert-True ($nativeSources -notmatch 'wsl\.exe|docker|podman|cygwin|msys2|mingw|git bash') 'all forensic package paths exclude compatibility runtimes'
    Assert-True ($builder -match 'AMD64|x64' -and $candidate -match 'AMD64|x64') 'build and candidate inspection require native x64 PE files'
    Assert-True ($candidate -match 'Import|Dependency') 'candidate inspection checks imports and dependencies'
}

function Test-Planning {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match '\[switch\]\s*\$Plan') 'verification has explicit plan mode'
    Assert-True ($source -match 'if\s*\(\s*\$Plan\s*\)') 'plan returns before native invocation'

    $context = New-US1TestContext -Name 'plan'
    try {
        $script:planInvocations = 0
        $runner = {
            param($Executable, $Arguments)
            $script:planInvocations++
            throw 'plan attempted native execution'
        }
        $before = @(Get-ChildItem -LiteralPath $context.ReportRoot -Force).Count
        $result = Invoke-US1Verifier -Context $context -Path $context.OrdinaryLaterSegment -Plan -NativeProcessRunner $runner
        Assert-Equal $result.schemaVersion '1.0' 'plan schema version is explicit'
        Assert-Equal $result.action 'Plan' 'plan action is distinct from verification'
        Assert-Equal $result.status 'planned' 'plan status cannot impersonate verified'
        Assert-True ([IO.Path]::IsPathRooted($result.selectedPath)) 'plan retains the selected absolute path'
        Assert-Equal $result.toolRecord.toolId 'ewfverify' 'plan identifies the selected tool record'
        Assert-Equal $result.segmentCandidates.Count 3 'plan identifies all segment candidates by name only'
        Assert-True (@($result.operations | Where-Object { $_.readsMediaData -or $_.changesSystemState }).Count -eq 0) 'plan operations neither read media nor change state'
        Assert-True ($null -eq $result.PSObject.Properties['mediaDigests']) 'plan contains no media digest result'
        Assert-Equal $script:planInvocations 0 'plan does not invoke the native verifier'
        Assert-Equal (@(Get-ChildItem -LiteralPath $context.ReportRoot -Force).Count) $before 'plan writes no report'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-EvidenceReadOnly {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'FileAccess\]::Read') 'segments are opened read-only'
    Assert-True ($source -match 'FileShare\]::Read') 'held handles deny writers and deletion'

    $context = New-US1TestContext -Name 'readonly'
    try {
        $script:writeDenied = $false
        $selectedPath = $context.Ordinary
        $runner = {
            param($Executable, $Arguments)
            try {
                $stream = [IO.File]::Open($selectedPath, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None)
                $stream.Dispose()
            }
            catch [IO.IOException] {
                $script:writeDenied = $true
            }
            New-SyntheticNativeProcessResult
        }
        $before = Get-Item -LiteralPath $selectedPath
        $result = Invoke-US1Verifier -Context $context -Path $selectedPath -NativeProcessRunner $runner
        $after = Get-Item -LiteralPath $selectedPath
        Assert-True $script:writeDenied 'held evidence handle denies a writer during verification'
        Assert-Equal $after.Length $before.Length 'verification leaves evidence length unchanged'
        Assert-Equal $after.LastWriteTimeUtc $before.LastWriteTimeUtc 'verification leaves evidence metadata unchanged'
        Assert-Equal $result.status 'verified' 'read-only transaction can still verify'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-SegmentInventory {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'ordinal|segment') 'ordered segment inventory is explicit'
    Assert-True ($source -match 'gap|duplicate|ambiguous') 'invalid segment sets are rejected'

    $context = New-US1TestContext -Name 'inventory'
    try {
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult }
        $result = Invoke-US1Verifier -Context $context -Path $context.OrdinaryLaterSegment -NativeProcessRunner $runner
        Assert-Equal (($result.evidence.segments.name) -join ',') 'ordinary.E01,ordinary.E02,ordinary.E03' 'later-segment selection resolves deterministic ordinal order'
        Assert-Equal (($result.evidence.segments.ordinal) -join ',') '1,2,3' 'segment ordinals are contiguous'

        $candidateRoot = $context.EvidenceRoot
        $duplicateProvider = {
            param($Directory, $BaseName)
            @(
                (Join-Path $candidateRoot 'ordinary.E01'),
                (Join-Path $candidateRoot 'ordinary.E01'),
                (Join-Path $candidateRoot 'ordinary.E02'),
                (Join-Path $candidateRoot 'ordinary.E03')
            )
        }
        $duplicateResult = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner -SegmentCandidateProvider $duplicateProvider
        Assert-Equal $duplicateResult.status 'unsupported' 'duplicate segment ordinal is rejected'
        Assert-True ($duplicateResult.failure.message -match 'duplicate.*E01') 'duplicate result identifies the affected ordinal'

        Copy-Item -LiteralPath (Join-Path $context.EvidenceRoot 'ordinary.E02') -Destination (Join-Path $context.EvidenceRoot 'conflict.E02')
        $ambiguousProvider = {
            param($Directory, $BaseName)
            @(
                (Join-Path $candidateRoot 'ordinary.E01'),
                (Join-Path $candidateRoot 'conflict.E02'),
                (Join-Path $candidateRoot 'ordinary.E03')
            )
        }
        $ambiguousResult = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner -SegmentCandidateProvider $ambiguousProvider
        Assert-Equal $ambiguousResult.status 'unsupported' 'conflicting basename is rejected as ambiguous'
        Assert-True ($ambiguousResult.failure.message -match 'ambiguous|conflicting|basename') 'ambiguity result identifies the conflict'

        $caseTemporary = Join-Path $context.EvidenceRoot 'ordinary.case-temporary'
        $lowercaseFirst = Join-Path $context.EvidenceRoot 'ordinary.e01'
        [IO.File]::Move($context.Ordinary, $caseTemporary)
        [IO.File]::Move($caseTemporary, $lowercaseFirst)
        $mixedCaseResult = Invoke-US1Verifier -Context $context -Path $lowercaseFirst -NativeProcessRunner $runner
        Assert-Equal (($mixedCaseResult.evidence.segments.ordinal) -join ',') '1,2,3' 'mixed-case extension resolves the same ordered set'

        Move-Item -LiteralPath (Join-Path $context.EvidenceRoot 'ordinary.E02') -Destination (Join-Path $context.EvidenceRoot 'ordinary.missing')
        $script:gapInvoked = $false
        $gapRunner = { param($Executable, $Arguments) $script:gapInvoked = $true; New-SyntheticNativeProcessResult }
        $gapResult = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $gapRunner
        Assert-Equal $gapResult.status 'unsupported' 'a segment gap is rejected'
        Assert-True ($gapResult.failure.message -match 'E02|gap|missing') 'gap result identifies the affected ordinal'
        Assert-True (-not $script:gapInvoked) 'a gap is rejected before native execution'

        Move-Item -LiteralPath (Join-Path $context.EvidenceRoot 'ordinary.missing') -Destination (Join-Path $context.EvidenceRoot 'ordinary.E02')
        Copy-Item -LiteralPath (Join-Path $context.EvidenceRoot 'ordinary.E03') -Destination (Join-Path $context.EvidenceRoot 'ordinary.E100')
        $suffixResult = Invoke-US1Verifier -Context $context -Path $lowercaseFirst -NativeProcessRunner $gapRunner
        Assert-Equal $suffixResult.status 'unsupported' 'unexpected segment suffix is rejected'
        Assert-True ($suffixResult.failure.message -match 'E100|suffix|ordinal') 'unexpected suffix is identified'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-SegmentIntegrity {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'preSha256|PreSha256') 'pre-verification segment hashes are recorded'
    Assert-True ($source -match 'postSha256|PostSha256') 'post-verification segment hashes are recorded'
    Assert-True ($source -match 'evidence-changed') 'a changed segment overrides tool success'

    $context = New-US1TestContext -Name 'changed'
    try {
        $script:identityCalls = @{}
        $identityProvider = {
            param($Stream, $Path, $Phase)
            if (-not $script:identityCalls.ContainsKey($Path)) { $script:identityCalls[$Path] = 0 }
            $script:identityCalls[$Path]++
            $item = Get-Item -LiteralPath $Path
            $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
            if ($Phase -eq 'Post' -and $Path -like '*.E02') { $hash = ('0' * 64) }
            [pscustomobject]@{ Length = [int64]$item.Length; Sha256 = $hash }
        }
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult }
        $result = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner -FileIdentityProvider $identityProvider
        Assert-Equal $result.status 'evidence-changed' 'post-hash mismatch overrides parser success'
        Assert-True (-not $result.verified) 'changed evidence is never verified'
        $changed = @($result.evidence.segments | Where-Object { -not $_.unchanged })
        Assert-Equal $changed.Count 1 'one changed segment is isolated'
        Assert-Equal $changed[0].name 'ordinary.E02' 'changed segment is identified'
        $invalidPreHashes = @($result.evidence.segments | Where-Object { $_.preSha256 -notmatch '^[0-9A-F]{64}$' })
        Assert-True ($invalidPreHashes.Count -eq 0) 'every segment has a pre-verification SHA-256'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-MediaDigests {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'mediaDigests|MediaDigests') 'stored and calculated media digests are reported'
    Assert-True ($source -match 'sha256') 'SHA-256 calculation is requested'

    $context = New-US1TestContext -Name 'digests'
    try {
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult }
        $result = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner
        $md5 = @($result.mediaDigests | Where-Object algorithm -eq 'MD5')[0]
        $sha256 = @($result.mediaDigests | Where-Object algorithm -eq 'SHA256')[0]
        Assert-Equal $md5.stored '91d8ae3beabcd4f8469a2fcb8055ba14' 'stored MD5 is retained as format evidence'
        Assert-Equal $md5.calculated '91d8ae3beabcd4f8469a2fcb8055ba14' 'calculated MD5 is retained'
        Assert-True $md5.matches 'stored/calculated MD5 comparison is explicit'
        Assert-Equal $sha256.calculated 'EDFAD2B84481209605168A88120F414883D6A4072E3C283D792E2524D4EAD324' 'media SHA-256 is retained'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-HashlessEvidence {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'readable-no-stored-hash') 'hashless evidence is a distinct non-success'

    $context = New-US1TestContext -Name 'hashless'
    try {
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult -StoredMD5 $null }
        $result = Invoke-US1Verifier -Context $context -Path $context.Hashless -NativeProcessRunner $runner
        Assert-Equal $result.status 'readable-no-stored-hash' 'readable hashless evidence has a non-verdict status'
        Assert-True (-not $result.verified) 'hashless evidence is not verified'
        $md5 = @($result.mediaDigests | Where-Object algorithm -eq 'MD5')[0]
        Assert-True ($null -eq $md5.stored -and $null -eq $md5.matches) 'missing stored hash is represented as null, not a match'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-FormatCertification {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'SupportedFormats') 'runtime consumes the cataloged format allowlist'
    Assert-True ($source -match 'ParserProfile') 'runtime consumes the pinned parser profile'

    $context = New-US1TestContext -Name 'unsupported'
    try {
        $runner = {
            param($Executable, $Arguments)
            New-SyntheticNativeProcessResult -ExitCode 1 -StdOut "ewfverify 20231119`nUnsupported compression method.`n"
        }
        $result = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner
        Assert-Equal $result.status 'unsupported' 'recognized unsupported parser output has a bounded status'
        Assert-True (-not $result.verified) 'unsupported evidence is never verified'

        $corruptPath = Join-Path $context.EvidenceRoot 'ordinary.E02'
        $corruptStream = [IO.File]::Open($corruptPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            [void] $corruptStream.Seek(4096, [IO.SeekOrigin]::Begin)
            $originalByte = $corruptStream.ReadByte()
            [void] $corruptStream.Seek(-1, [IO.SeekOrigin]::Current)
            $corruptStream.WriteByte([byte]($originalByte -bxor 0xff))
        }
        finally {
            $corruptStream.Dispose()
        }
        $corruptRunner = {
            param($Executable, $Arguments)
            New-SyntheticNativeProcessResult -ExitCode 1 -StdOut "ewfverify 20231119`nErrors were detected in the image.`newfverify: FAILURE`n"
        }
        $corruptResult = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $corruptRunner
        Assert-Equal $corruptResult.status 'integrity-failed' 'derived corrupt input has an integrity-failed status'

        $unrecognizedRunner = {
            param($Executable, $Arguments)
            New-SyntheticNativeProcessResult -StdOut "ewfverify 20231119`nOutput grammar changed.`n"
        }
        $unrecognizedResult = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $unrecognizedRunner
        Assert-Equal $unrecognizedResult.status 'parser-output-unrecognized' 'unrecognized successful output fails closed'
        $allowedStatuses = @('verified', 'readable-no-stored-hash', 'integrity-failed', 'evidence-changed', 'unsupported', 'tool-integrity-failed', 'parser-output-unrecognized', 'report-failed')
        Assert-True ($allowedStatuses -contains $corruptResult.status) 'verification status remains inside the bounded contract'
        Assert-True ($source -match "'readable-no-stored-hash'\s*=\s*2" -and $source -match 'unsupported\s*=\s*3') 'non-verdict statuses have stable command exit codes'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-InvocationEvidence {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'arguments|ArgumentVector') 'exact native arguments are retained'
    Assert-True ($source -match 'exitCode|ExitCode') 'native exit code is retained'

    $context = New-US1TestContext -Name 'invocation'
    try {
        $script:capturedExecutable = $null
        $script:capturedArguments = $null
        $runner = {
            param($Executable, $Arguments)
            $script:capturedExecutable = $Executable
            $script:capturedArguments = @($Arguments)
            New-SyntheticNativeProcessResult -StdErr 'synthetic warning'
        }
        $result = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner
        Assert-True ([IO.Path]::IsPathRooted($result.invocation.executable)) 'invocation retains an absolute executable path'
        Assert-Equal $result.invocation.executable $script:capturedExecutable 'reported executable is the invoked executable'
        Assert-Equal ($result.invocation.arguments -join '|') ($script:capturedArguments -join '|') 'reported argument vector is exact'
        Assert-Equal $result.invocation.exitCode 0 'native exit code is retained'
        Assert-Equal $result.startedAtUtc '2026-08-16T10:00:00.0000000Z' 'native start time is normalized to UTC'
        Assert-Equal $result.endedAtUtc '2026-08-16T10:00:01.0000000Z' 'native end time is normalized to UTC'
        Assert-True (@($result.artifacts | Where-Object name -eq 'stdout.bin').sha256 -match '^[0-9A-F]{64}$') 'stdout has a cryptographic identity'
        Assert-True (@($result.artifacts | Where-Object name -eq 'stderr.bin').sha256 -match '^[0-9A-F]{64}$') 'stderr has a cryptographic identity'
        $stdoutArtifact = @($result.artifacts | Where-Object name -eq 'stdout.bin')[0]
        $stderrArtifact = @($result.artifacts | Where-Object name -eq 'stderr.bin')[0]
        Assert-True ($stdoutArtifact.sourceSha256 -match '^[0-9A-F]{64}$') 'complete stdout has a source-stream identity'
        Assert-True ($stderrArtifact.sourceSha256 -match '^[0-9A-F]{64}$') 'complete stderr has a source-stream identity'
        Assert-True (Test-Path -LiteralPath (Join-Path $result.reportDirectory 'stdout.bin') -PathType Leaf) 'raw stdout is durably retained'
        Assert-True (Test-Path -LiteralPath (Join-Path $result.reportDirectory 'stderr.bin') -PathType Leaf) 'raw stderr is durably retained'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-ReportContract {
    $schemaSource = Get-Source 'specs/008-native-forensic-verification/contracts/ewf-verification-report.schema.json'
    $schema = $schemaSource | ConvertFrom-Json
    Assert-True ($schema.properties.status.enum -contains 'verified') 'schema declares verified status'
    Assert-True ($null -ne $schema.properties.evidence) 'schema declares evidence inventory'
    Assert-True ($schema.required -contains 'reportDirectory') 'schema identifies the committed report directory'
    Assert-True ($schema.'$defs'.tool.required -contains 'sourceArtifacts') 'schema requires source provenance'

    $context = New-US1TestContext -Name 'report-contract'
    try {
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult -UpstreamLogBytes ([Text.Encoding]::UTF8.GetBytes('synthetic upstream log')) }
        $result = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner
        Assert-Equal $result.status 'verified' 'a committed successful report can be verified'
        Assert-True (Test-Path -LiteralPath $result.reportDirectory -PathType Container) 'result identifies a committed report directory'
        Assert-Equal $result.tool.sourceArtifacts.Count $context.Catalog.Record.SourceArtifacts.Count 'report attributes every source artifact'
        Assert-Equal $result.tool.files.Count $context.Catalog.Record.PackageFiles.Count 'report attributes the executable and dependencies'
        Assert-Equal $result.tool.catalogFileSha256 (Get-FileHash -LiteralPath $context.Catalog.Path -Algorithm SHA256).Hash 'report pins the exact catalog bytes'
        Assert-True ($null -eq $result.tool.catalogCommit) 'unresolvable synthetic catalog commit remains null'
        Assert-True (($result.warnings -join ' ') -match 'catalog.*commit') 'missing clean catalog commit is explained'
        $artifactNames = @($result.artifacts | ForEach-Object name | Sort-Object)
        Assert-Equal ($artifactNames -join ',') 'ewfverify.log,report.txt,stderr.bin,stdout.bin' 'artifact inventory covers human, raw, and upstream evidence'
        $durable = Get-Content -LiteralPath (Join-Path $result.reportDirectory 'report.json') -Raw | ConvertFrom-Json
        Assert-Equal $durable.runId $result.runId 'durable JSON and returned result identify the same run'
        Assert-Equal $durable.status $result.status 'durable JSON and returned result have the same status'
        Assert-Equal $durable.tool.packageSha256 $result.tool.packageSha256 'durable JSON preserves package identity'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-JsonParity {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'ConvertTo-Json') 'machine output is JSON'
    Assert-True ($source -match '\$Json') 'same command selects JSON output'

    $context = New-US1TestContext -Name 'json-parity'
    try {
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult }
        $scriptPath = Join-Path $repositoryRoot 'scripts\Invoke-EwfVerification.ps1'
        $jsonText = (. $scriptPath -Path $context.Ordinary -ReportDirectory $context.ReportRoot -CatalogPath $context.Catalog.Path -NativeProcessRunner $runner -Json | Out-String).Trim()
        $jsonResult = $jsonText | ConvertFrom-Json
        Assert-Equal @($jsonResult).Count 1 'JSON mode emits exactly one object'
        $durable = Get-Content -LiteralPath (Join-Path $jsonResult.reportDirectory 'report.json') -Raw | ConvertFrom-Json
        Assert-Equal ($jsonResult | ConvertTo-Json -Depth 16 -Compress) ($durable | ConvertTo-Json -Depth 16 -Compress) 'machine output exactly matches the durable report facts'

        $humanOutput = @(. $scriptPath -Path $context.Ordinary -ReportDirectory $context.ReportRoot -CatalogPath $context.Catalog.Path -NativeProcessRunner $runner) -join "`n"
        Assert-True ($humanOutput -match 'EWF verification:\s+verified') 'human output reports the same outcome'
        Assert-True ($humanOutput -match [regex]::Escape($context.Ordinary)) 'human output identifies the same evidence'
        Assert-True ($humanOutput -match 'ewfverify\s+20231119-b1') 'human output identifies the same tool revision'
        Assert-True ($humanOutput -match 'Report:') 'human output identifies the committed report'

        $first = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner
        $second = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner
        Assert-True ($first.runId -ne $second.runId) 'run identity is intentionally volatile'
        Assert-True ($first.reportDirectory -ne $second.reportDirectory) 'committed report path is intentionally volatile'
        Assert-Equal ((Get-StableVerificationFacts -Result $first) | ConvertTo-Json -Depth 16 -Compress) ((Get-StableVerificationFacts -Result $second) | ConvertTo-Json -Depth 16 -Compress) 'stable report facts normalize identically across runs and runtimes'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-HostileOutput {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'StandardOutput|stdout') 'stdout is captured as an artifact'
    Assert-True ($source -match 'StandardError|stderr') 'stderr is captured as an artifact'
    Assert-True ($source -match 'truncat|bound|max') 'native output has a fixed bound'

    $context = New-US1TestContext -Name 'hostile-output'
    try {
        $prefix = [Text.Encoding]::UTF8.GetBytes("ewfverify 20231119`n")
        $hostile = New-Object byte[] (1048576 + 257)
        [Array]::Copy($prefix, $hostile, $prefix.Length)
        for ($index = $prefix.Length; $index -lt $hostile.Length; $index++) { $hostile[$index] = [byte]0x41 }
        $hostile[32] = [byte]0x1b
        $hostile[33] = [byte]0x5b
        $hostile[34] = [byte]0x32
        $hostile[35] = [byte]0x4a
        $hostile[40] = [byte]0xff
        $hostile[41] = [byte]0x00
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult -ExitCode 1 -RawStdOut $hostile -RawStdErr ([byte[]](0x1b,0x5b,0x33,0x31,0x6d,0xff)) }
        $result = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner
        Assert-Equal $result.status 'integrity-failed' 'a nonzero exit cannot be overridden by misleading output'
        $stdoutArtifact = @($result.artifacts | Where-Object name -eq 'stdout.bin')[0]
        Assert-True $stdoutArtifact.truncated 'oversized stdout is explicitly truncated'
        Assert-Equal $stdoutArtifact.size 1048576 'retained raw stdout obeys the fixed byte bound'
        Assert-Equal $stdoutArtifact.sourceSize $hostile.Length 'full source-stream length is retained as metadata'
        Assert-Equal $stdoutArtifact.sourceSha256 (Get-TestByteArraySha256 -Bytes $hostile) 'full source-stream identity survives truncation'
        $rawPath = Join-Path $result.reportDirectory 'stdout.bin'
        Assert-Equal (Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash $stdoutArtifact.sha256 'raw artifact identity matches retained bytes'
        $reportText = Get-Content -LiteralPath (Join-Path $result.reportDirectory 'report.txt') -Raw
        Assert-True ($reportText -notmatch ([char]0x1b)) 'human report contains no terminal escape byte'
        Assert-True ($reportText -notmatch ([char]0x00)) 'human report contains no NUL control byte'
        Assert-True ($reportText.Length -lt 65536) 'human rendering is independently bounded'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-CatalogSchema {
    $catalogSource = Get-Source 'config/forensic-tools.psd1'
    foreach ($field in @('ToolId', 'UpstreamVersion', 'BuildRevision', 'ReviewState', 'SupportedFormats', 'ParserProfile', 'ReleaseIdentity', 'SourceArtifacts', 'BuildIdentity', 'PackageFiles', 'LicenseSummary', 'Certification')) {
        Assert-True ($catalogSource -match $field) "catalog contains $field"
    }
    Assert-True ($catalogSource -notmatch '(?i)latest|refs/heads/|/main(?:/|''|")|/master(?:/|''|")') 'catalog contains no floating release or source reference'
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\forensic-tools.psd1')
    Assert-True (@($catalog.Records).Count -ge 1) 'catalog contains at least one attributable verifier record'
    $approved = @($catalog.Records | Where-Object ReviewState -eq 'Approved')
    Assert-True ($approved.Count -le 1) 'catalog selects no more than one current approved verifier'
    $record = @($catalog.Records | Where-Object ReviewState -in @('Approved','Candidate'))[0]
    Assert-True ($record.ReleaseIdentity.Tag -match '^forensic-ewfverify-20231119-b[1-9][0-9]*$') 'release tag is immutable and revisioned'
    if ($record.ReviewState -eq 'Approved') {
        Assert-True ($record.ReleaseIdentity.AssetSize -gt 0 -and $record.ReleaseIdentity.PackageSha256 -match '^[0-9A-F]{64}$') 'approved release asset has independent size and digest pins'
        Assert-True (@($record.PackageFiles | Where-Object { $_.Sha256 -notmatch '^[0-9A-F]{64}$' }).Count -eq 0) 'every approved package file has a SHA-256 pin'
    }
    else {
        Assert-True ($null -eq $record.ReleaseIdentity.AssetSize -and $null -eq $record.ReleaseIdentity.PackageSha256) 'candidate does not invent final release bytes before the draft exists'
    }
    Assert-True (@($record.PackageFiles).Count -ge 2) 'package allowlist covers executable and dependencies'
    Assert-True (@($record.SourceArtifacts | Where-Object { -not $_.Authenticity }).Count -eq 0) 'every source records authenticity evidence'
    Assert-True ($record.BuildIdentity.ConverterCommit -match '^[0-9a-f]{40}$') 'converter is pinned to a full commit'
    Assert-True ($record.BuildIdentity.BuildRecordSha256 -match '^[0-9A-F]{64}$') 'build recipe bytes have an independent revision identity'
    if ($record.ReviewState -eq 'Approved') {
        Assert-True ($record.Certification.Result -eq 'Passed' -and @($record.Certification.Lanes).Count -eq 2) 'approval records both-shell certification'
    }
    else {
        Assert-True ($record.Certification.Result -eq 'Pending' -and @($record.Certification.Lanes).Count -eq 2) 'candidate declares both required certification lanes without claiming they passed'
    }
    foreach ($historical in @($catalog.Records | Where-Object ReviewState -in @('Withdrawn','Superseded'))) {
        Assert-True ($historical.ReleaseIdentity.Tag -and $historical.ReleaseIdentity.PackageSha256) 'historical records retain immutable release identity'
    }
}

function Test-InstallIntegrity {
    $source = Get-Source 'scripts/Set-NativeForensicToolsState.ps1'
    Assert-True ($source -match 'Get-FileHash|SHA256') 'installer verifies the package and files'
    Assert-True ($source -match 'Approved') 'installer accepts approved records only'
    Assert-True ($source -match 'Compression\.ZipFile|Expand-Archive') 'installer handles the approved archive explicitly'
    Assert-True ($source -match 'staging' -and $source -match 'Directory.*Move') 'installer stages and commits atomically'

    $root = New-NativeForensicTestRoot -Name 'install-integrity'
    try {
        $package = New-SyntheticNativeForensicPackage -Root $root
        $release = New-SyntheticNativeForensicRelease -Package $package -Root $root
        $installRoot = Join-Path $root 'install\ewfverify-20231119-b1'
        $catalog = New-SyntheticNativeForensicCatalog -Root $root -Package $package -Release $release -DoNotInstall -InstallRoot $installRoot
        $plan = Invoke-ForensicToolState -Mode Plan -CatalogPath $catalog.Path -PackagePath $release.Path
        Assert-Equal $plan.state 'Planned' 'plan reports prospective installation distinctly'
        Assert-True (-not (Test-Path -LiteralPath $installRoot)) 'plan creates no installation'
        $ensured = Invoke-ForensicToolState -Mode Ensure -CatalogPath $catalog.Path -PackagePath $release.Path
        Assert-Equal $ensured.state 'Compliant' 'matching approved package installs compliantly'
        Assert-True (Test-Path -LiteralPath (Join-Path $installRoot 'ewfverify.exe') -PathType Leaf) 'atomic installation exposes the verifier only after validation'
        Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $installRoot) -Directory -Force | Where-Object Name -like '*.staging-*').Count -eq 0) 'successful installation leaves no staging directory'
        $beforeRollbackHash = (Get-FileHash -LiteralPath (Join-Path $installRoot 'ewfverify.exe') -Algorithm SHA256).Hash
        $fault = { param($Stage, $Path) $null = $Path; if ($Stage -eq 'AfterCommitBeforeValidation') { throw 'synthetic post-commit validation fault' } }
        $rolledBack = Invoke-ForensicToolState -Mode Ensure -CatalogPath $catalog.Path -PackagePath $release.Path -InstallFaultProvider $fault
        Assert-True ($null -ne $rolledBack.failure -and $rolledBack.failure.message -match 'synthetic post-commit') 'post-commit validation failure is reported'
        Assert-Equal (Get-FileHash -LiteralPath (Join-Path $installRoot 'ewfverify.exe') -Algorithm SHA256).Hash $beforeRollbackHash 'previous compliant installation is restored after commit failure'
        Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $installRoot) -Directory -Force | Where-Object Name -like '*.rollback-*').Count -eq 0) 'restored installation leaves no orphan rollback directory'

        $extraRelease = New-SyntheticNativeForensicRelease -Package $package -Root $root -AdditionalEntries @{ 'unexpected.dll' = 'not allowlisted' }
        $extraCatalog = New-SyntheticNativeForensicCatalog -Root (Join-Path $root 'extra') -Package $package -Release $extraRelease -DoNotInstall -InstallRoot (Join-Path $root 'extra-install')
        $extra = Invoke-ForensicToolState -Mode Ensure -CatalogPath $extraCatalog.Path -PackagePath $extraRelease.Path
        Assert-True ($extra.state -ne 'Compliant' -and $extra.failure.message -match 'unexpected|allowlist|extra') 'archive with an extra file is rejected'

        $traversalRelease = New-SyntheticNativeForensicRelease -Package $package -Root $root -AdditionalEntries @{ '../escape.dll' = 'escape' }
        $traversalCatalog = New-SyntheticNativeForensicCatalog -Root (Join-Path $root 'traversal') -Package $package -Release $traversalRelease -DoNotInstall -InstallRoot (Join-Path $root 'traversal-install')
        $traversal = Invoke-ForensicToolState -Mode Ensure -CatalogPath $traversalCatalog.Path -PackagePath $traversalRelease.Path
        Assert-True ($traversal.state -ne 'Compliant' -and $traversal.failure.message -match 'traversal|unsafe|path') 'archive traversal entry is rejected before extraction'

        $wrongRelease = [pscustomobject]@{ Path = $release.Path; Size = $release.Size; Sha256 = ('0' * 64) }
        $wrongCatalog = New-SyntheticNativeForensicCatalog -Root (Join-Path $root 'wrong-hash') -Package $package -Release $wrongRelease -DoNotInstall -InstallRoot (Join-Path $root 'wrong-install')
        $wrong = Invoke-ForensicToolState -Mode Ensure -CatalogPath $wrongCatalog.Path -PackagePath $release.Path
        Assert-True ($wrong.state -ne 'Compliant' -and $wrong.failure.message -match 'hash|SHA-256') 'package digest mismatch fails closed'
    }
    finally { Remove-NativeForensicTestRoot -Root $root }
}

function Test-ToolDrift {
    $source = Get-Source 'scripts/Set-NativeForensicToolsState.ps1'
    Assert-True ($source -match 'Absent|Compliant|Drifted|Unapproved') 'tool states are bounded'
    Assert-True ($source -match "'Test'") 'read-only drift test exists'

    $root = New-NativeForensicTestRoot -Name 'tool-drift'
    try {
        $package = New-SyntheticNativeForensicPackage -Root $root
        $release = New-SyntheticNativeForensicRelease -Package $package -Root $root
        $installRoot = Join-Path $root 'install\ewfverify-20231119-b1'
        $catalog = New-SyntheticNativeForensicCatalog -Root $root -Package $package -Release $release -DoNotInstall -InstallRoot $installRoot
        Assert-Equal (Invoke-ForensicToolState -Mode Test -CatalogPath $catalog.Path).state 'Absent' 'missing approved installation is observed without repair'
        Assert-Equal (Invoke-ForensicToolState -Mode Ensure -CatalogPath $catalog.Path -PackagePath $release.Path).state 'Compliant' 'explicit ensure installs approved state'
        Assert-Equal (Invoke-ForensicToolState -Mode Test -CatalogPath $catalog.Path).state 'Compliant' 'matching installed state remains observationally compliant'
        [IO.File]::AppendAllText((Join-Path $installRoot 'libewf.dll'), 'drift')
        Assert-Equal (Invoke-ForensicToolState -Mode Test -CatalogPath $catalog.Path).state 'Drifted' 'changed dependency is detected'
        Assert-Equal (Invoke-ForensicToolState -Mode Ensure -CatalogPath $catalog.Path -PackagePath $release.Path).state 'Compliant' 'explicit ensure repairs drift from the approved package'

        $candidateCatalog = New-SyntheticNativeForensicCatalog -Root (Join-Path $root 'candidate') -Package $package -Release $release -ReviewState Candidate -InstallRoot $installRoot
        Assert-Equal (Invoke-ForensicToolState -Mode Test -CatalogPath $candidateCatalog.Path).state 'Unapproved' 'candidate identity is never accepted for installation'
        $supersededCatalog = New-SyntheticNativeForensicCatalog -Root (Join-Path $root 'superseded') -Package $package -Release $release -ReviewState Superseded -InstallRoot $installRoot
        Assert-Equal (Invoke-ForensicToolState -Mode Ensure -CatalogPath $supersededCatalog.Path -PackagePath $release.Path).state 'Unapproved' 'superseded history remains attributable but cannot be reinstalled'
        Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent $installRoot) -Directory -Force | Where-Object Name -like '*.rollback-*').Count -eq 0) 'repair removes rollback only after compliant validation'

        $verificationContext = New-US1TestContext -Name 'pre-invocation-drift'
        try {
            $script:driftRunnerInvoked = $false
            $runner = { param($Executable, $Arguments) $script:driftRunnerInvoked = $true; New-SyntheticNativeProcessResult }
            $hook = { param($Record) [IO.File]::AppendAllText((Join-Path $Record.InstallRoot 'libewf.dll'), 'last-moment drift') }
            $refused = Invoke-US1Verifier -Context $verificationContext -Path $verificationContext.Ordinary -NativeProcessRunner $runner -PreInvocationHook $hook
            Assert-Equal $refused.status 'tool-integrity-failed' 'last-moment dependency drift is rejected immediately before invocation'
            Assert-True (-not $script:driftRunnerInvoked) 'drifted native verifier is never executed'
        }
        finally { Remove-NativeForensicTestRoot -Root $verificationContext.Root }
    }
    finally { Remove-NativeForensicTestRoot -Root $root }
}

function Test-UpdatePolicy {
    $update = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    $state = Get-Source 'scripts/Set-NativeForensicToolsState.ps1'
    Assert-True ($update -notmatch 'Build-NativeForensicTool') 'ordinary update never builds forensic tools'
    Assert-True ($update -notmatch 'Publish-NativeForensicTool') 'ordinary update never publishes forensic tools'
    Assert-True ($update -match 'ForensicToolCandidates' -and $update -match 'ForensicCatalogPath') 'ordinary update reports candidates from an injected or checked-out catalog'
    Assert-True ($update -match "ReviewState\s+-eq\s+'Candidate'" -and $update -match "ReviewState\s+-eq\s+'Approved'") 'ordinary update distinguishes candidates from the pinned approved record'
    Assert-True ($update -notmatch 'api\.github|Invoke-RestMethod|Invoke-WebRequest') 'ordinary candidate reporting performs no upstream discovery'
    Assert-True ($state -match "ReviewState\s+-eq\s+'Approved'") 'installation remains bound to an explicitly approved record'

    $root = New-NativeForensicTestRoot -Name 'update-policy'
    try {
        $installRoot = Join-Path $root 'must-not-be-created'
        $catalogPath = Join-Path $root 'forensic-tools.psd1'
        $catalogText = @"
@{ Records = @(
    @{ RecordId = 'ewf-old'; ToolId = 'ewfverify'; UpstreamVersion = '20231119'; BuildRevision = 'b1'; ReviewState = 'Approved'; InstallRoot = '$($installRoot.Replace("'", "''"))'; ReleaseIdentity = @{ Tag = 'forensic-ewfverify-20231119-b1' } }
    @{ RecordId = 'ewf-new'; ToolId = 'ewfverify'; UpstreamVersion = '20231119'; BuildRevision = 'b2'; ReviewState = 'Candidate'; InstallRoot = '$($installRoot.Replace("'", "''"))'; ReleaseIdentity = @{ Tag = 'forensic-ewfverify-20231119-b2' } }
) }
"@
        [IO.File]::WriteAllText($catalogPath, $catalogText, [Text.UTF8Encoding]::new($false))
        $updateScript = Join-Path $repositoryRoot 'scripts\Invoke-WorkstationUpdate.ps1'
        $planned = @(. $updateScript -Target WinGet -ForensicCatalogPath $catalogPath -PassThru | Where-Object { $_.PSObject.Properties['ForensicToolCandidates'] })[0]
        Assert-Equal @($planned.ForensicToolApproved).Count 1 'ordinary update retains the approved forensic identity'
        Assert-Equal @($planned.ForensicToolCandidates).Count 1 'ordinary update reports one explicit candidate'
        Assert-Equal $planned.ForensicToolCandidates[0].BuildRevision 'b2' 'candidate report identifies the proposed build revision'
        Assert-True (-not (Test-Path -LiteralPath $installRoot)) 'ordinary update planning does not install the candidate'
    }
    finally { Remove-NativeForensicTestRoot -Root $root }
}

function Test-UpgradeCertification {
    $build = Get-Source '.github/workflows/forensic-tool-build.yml'
    $candidate = Get-Source 'scripts/Test-ForensicReleaseCandidate.ps1'
    Assert-True ($build -match 'Test-NativeForensicVerification') 'candidate workflow runs certification tests'
    Assert-True ($build -match 'powershell' -and $build -match 'pwsh') 'both PowerShell lanes certify a candidate'
    foreach ($caseName in 'valid','corrupt','incomplete','hashless','unsupported','hostile-output','persistence-failure') {
        Assert-True ($candidate -match [regex]::Escape($caseName)) "candidate certification requires the $caseName case"
    }
    Assert-True ($candidate -match 'CertificationResultProvider|CertificationEvidence') 'candidate validation has a deterministic offline certification boundary'
    Assert-True ($candidate -match 'WindowsPowerShell-5\.1' -and $candidate -match 'PowerShell-7') 'candidate validation requires both supported shell lanes'
    Assert-True ($candidate -match 'certification.*failed|certification-failed') 'any certification mismatch fails closed'
    Assert-True ($build -match 'draft') 'certified output remains a draft pending explicit approval'

    $root = New-NativeForensicTestRoot -Name 'upgrade-certification'
    try {
        $buildRecord = Join-Path $repositoryRoot 'config\forensic-builds\ewfverify-20231119-b1.psd1'
        $release = New-SyntheticForensicCandidatePackage -Root $root -BuildRecord $buildRecord
        $candidateScript = Join-Path $repositoryRoot 'scripts\Test-ForensicReleaseCandidate.ps1'
        $passingProvider = {
            param($PackagePath, $PackageRoot, $Record, $Lanes, $Cases)
            $null = $PackagePath, $PackageRoot, $Record
            foreach ($lane in $Lanes) {
                [pscustomobject]@{
                    status = 'Passed'
                    lane = $lane
                    cases = @($Cases | ForEach-Object { [pscustomobject]@{ name = $_; expectedStatus = 'expected'; observedStatus = 'expected'; passed = $true } })
                }
            }
        }
        $passed = @(. $candidateScript -PackagePath $release.Path -BuildRecord $buildRecord -SkipPeInspection -CertificationResultProvider $passingProvider -PassThru | Where-Object { $_.PSObject.Properties['status'] })[0]
        Assert-Equal $passed.status 'Passed' 'complete two-lane certification permits candidate validation'
        Assert-Equal @($passed.certification).Count 2 'candidate result retains both certification lanes'

        $incompleteProvider = {
            param($PackagePath, $PackageRoot, $Record, $Lanes, $Cases)
            $null = $PackagePath, $PackageRoot, $Record
            foreach ($lane in $Lanes) {
                [pscustomobject]@{
                    status = 'Passed'
                    lane = $lane
                    cases = @($Cases | Select-Object -Skip 1 | ForEach-Object { [pscustomobject]@{ name = $_; expectedStatus = 'expected'; observedStatus = 'expected'; passed = $true } })
                }
            }
        }
        $blocked = @(. $candidateScript -PackagePath $release.Path -BuildRecord $buildRecord -SkipPeInspection -CertificationResultProvider $incompleteProvider -PassThru | Where-Object { $_.PSObject.Properties['status'] })[0]
        Assert-Equal $blocked.status 'Failed' 'missing certification case blocks candidate validation'
        Assert-True ($blocked.failure.message -match 'case set is incomplete') 'certification failure identifies the missing case set'
    }
    finally { Remove-NativeForensicTestRoot -Root $root }
}

function Test-CertificationCorpus {
    $expected = Get-Source 'tests/fixtures/ewf/expected.psd1'
    $readme = Get-Source 'tests/fixtures/ewf/README.md'
    Assert-True ($expected -match 'Segment|Media|Sha256') 'fixture expectations pin evidence identities'
    Assert-True ($readme -match 'non-case|benign') 'fixture provenance states that data is benign'

    $fixtureRoot = Join-Path $repositoryRoot 'tests\fixtures\ewf'
    $fixtureContract = Import-PowerShellDataFile -LiteralPath (Join-Path $fixtureRoot 'expected.psd1')
    foreach ($fixtureSet in $fixtureContract.Sets) {
        Assert-True ($fixtureSet.Segments.Count -eq $fixtureSet.ExpectedSegmentCount) "$($fixtureSet.Name) segment count is pinned"
        foreach ($segment in $fixtureSet.Segments) {
            $segmentPath = Join-Path $fixtureRoot $segment.Name
            Assert-True (Test-Path -LiteralPath $segmentPath -PathType Leaf) "$($segment.Name) exists"
            $segmentFile = Get-Item -LiteralPath $segmentPath
            Assert-True ($segmentFile.Length -eq $segment.Length) "$($segment.Name) length matches"
            $segmentHash = (Get-FileHash -LiteralPath $segmentPath -Algorithm SHA256).Hash
            Assert-True ($segmentHash -eq $segment.SHA256) "$($segment.Name) SHA-256 matches"
        }
    }
    $buildOutputs = @(Get-ChildItem -LiteralPath $fixtureRoot -Recurse -File | Where-Object {
        $_.Extension -in @('.exe', '.dll', '.lib', '.obj', '.pdb', '.ilk')
    })
    Assert-True ($buildOutputs.Count -eq 0) 'fixture corpus contains no generator executable or build output'

    $helper = Get-Source 'tests/helpers/NativeForensicTestSupport.ps1'
    Assert-True ($helper -match 'New-DerivedEwfCertificationCorpus') 'derived certification corpus has one reusable recipe'
    foreach ($caseName in 'valid','corrupt','incomplete','hashless','unsupported','hostile-output','persistence-failure') {
        Assert-True ($helper -match [regex]::Escape($caseName)) "derived corpus defines the $caseName case"
    }

    $derivedRoot = New-NativeForensicTestRoot -Name 'certification-derived'
    try {
        $derived = New-DerivedEwfCertificationCorpus -FixtureRoot $fixtureRoot -DestinationRoot (Join-Path $derivedRoot 'corpus')
        Assert-Equal @($derived.Cases).Count 7 'certification recipe returns every required case'
        Assert-True (@($derived.Cases | Where-Object Name -eq 'corrupt').Count -eq 1) 'corrupt evidence is derived explicitly'
        Assert-True (@($derived.Cases | Where-Object Name -eq 'incomplete').Count -eq 1) 'incomplete evidence is derived explicitly'
        Assert-True (@($derived.Cases | Where-Object Name -eq 'unsupported').Count -eq 1) 'unsupported evidence is derived explicitly'
        Assert-True (@($derived.Cases | Where-Object { -not $_.Path.StartsWith($derivedRoot, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) 'all derived cases stay under test-temporary storage'
        foreach ($committedSet in $fixtureContract.Sets) {
            foreach ($segment in $committedSet.Segments) {
                $path = Join-Path $fixtureRoot $segment.Name
                Assert-Equal (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash $segment.SHA256 "committed fixture $($segment.Name) remains unchanged"
            }
        }
    }
    finally { Remove-NativeForensicTestRoot -Root $derivedRoot }
}

function Test-HistoricalAttribution {
    $context = New-US1TestContext -Name 'historical-attribution'
    try {
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult }
        $commitProvider = { param($CatalogPath) $null = $CatalogPath; '1234567890abcdef1234567890abcdef12345678' }
        $result = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner -CatalogCommitProvider $commitProvider
        Assert-Equal $result.tool.toolId $context.Catalog.Record.ToolId 'historical report retains tool identity'
        Assert-Equal $result.tool.upstreamVersion $context.Catalog.Record.UpstreamVersion 'historical report retains upstream version'
        Assert-Equal $result.tool.buildRevision $context.Catalog.Record.BuildRevision 'historical report retains build revision'
        Assert-Equal $result.tool.releaseTag $context.Catalog.Record.ReleaseIdentity.Tag 'historical report retains immutable release tag'
        Assert-Equal $result.tool.packageSha256 $context.Catalog.Record.ReleaseIdentity.PackageSha256 'historical report retains package digest'
        Assert-Equal $result.tool.sourceArtifacts[0].sha256 $context.Catalog.Record.SourceArtifacts[0].Sha256 'historical report retains source digest'
        Assert-Equal $result.tool.catalogFileSha256 $context.Catalog.Sha256 'historical report retains the exact catalog-file digest'
        Assert-Equal $result.tool.catalogCommit '1234567890abcdef1234567890abcdef12345678' 'historical report resolves a containing commit outside the self-contained catalog record'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-OfflineExecution {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -notmatch 'Invoke-WebRequest|Invoke-RestMethod|curl|aria2|Start-BitsTransfer|System\.Net\.|HttpClient|WebClient') 'verification performs no network access'
}

function Test-ReportPersistence {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    Assert-True ($source -match 'staging|temporary') 'reports are staged before commit'
    Assert-True ($source -match 'Move-Item|Directory\.Move') 'report directory is committed atomically'
    Assert-True ($source -match 'report-failed') 'persistence failure is explicit'

    $context = New-US1TestContext -Name 'report-persistence'
    try {
        $runner = { param($Executable, $Arguments) New-SyntheticNativeProcessResult }
        $fixedRunId = { '11111111-2222-3333-4444-555555555555' }
        $first = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner -RunIdProvider $fixedRunId
        Assert-Equal $first.status 'verified' 'first unique report commits successfully'
        $reportJson = Join-Path $first.reportDirectory 'report.json'
        $beforeHash = (Get-FileHash -LiteralPath $reportJson -Algorithm SHA256).Hash
        $second = Invoke-US1Verifier -Context $context -Path $context.Ordinary -NativeProcessRunner $runner -RunIdProvider $fixedRunId
        Assert-Equal $second.status 'report-failed' 'existing run identity is never overwritten'
        Assert-Equal (Get-FileHash -LiteralPath $reportJson -Algorithm SHA256).Hash $beforeHash 'existing completed report remains byte-identical'

        foreach ($faultMessage in 'disk full', 'access denied') {
            $fault = { param($Stage, $Path) if ($Stage -eq 'BeforeCommit') { throw $faultMessage } }
            $failed = Invoke-US1Verifier -Context $context -Path $context.Hashless -NativeProcessRunner $runner -PersistenceFaultProvider $fault
            Assert-Equal $failed.status 'report-failed' "$faultMessage becomes report-failed"
        }
        Assert-True (@(Get-ChildItem -LiteralPath $context.ReportRoot -Directory -Force | Where-Object Name -like '*.staging-*').Count -eq 0) 'failed staging directories are cleaned up'

        $insideEvidence = Invoke-US1Verifier -Context $context -Path $context.Hashless -NativeProcessRunner $runner -ReportDirectory $context.EvidenceRoot
        Assert-Equal $insideEvidence.status 'report-failed' 'report destination inside evidence is rejected'

        $notDirectory = Join-Path $context.Root 'not-a-directory'
        [IO.File]::WriteAllText($notDirectory, 'existing file')
        $invalidDestination = Invoke-US1Verifier -Context $context -Path $context.Hashless -NativeProcessRunner $runner -ReportDirectory $notDirectory
        Assert-Equal $invalidDestination.status 'report-failed' 'non-directory report destination fails closed'
        Assert-Equal (Get-Content -LiteralPath $notDirectory -Raw) 'existing file' 'invalid destination is not altered'
    }
    finally {
        Remove-NativeForensicTestRoot -Root $context.Root
    }
}

function Test-DocumentationRouting {
    $capabilities = Get-Source 'config/capabilities.psd1'
    $docs = Get-Source 'docs/ewf-verification.md'
    $lifecycle = Get-Source 'docs/forensic-tools.md'
    $samples = Get-Source 'docs/sample-outputs.md'
    $readme = Get-Source 'README.md'
    $navigation = Get-Source 'mkdocs.yml'
    $skill = Get-Source '.agents/skills/verify-forensic-evidence/SKILL.md'
    Assert-True ($capabilities -match 'ewf-verify') 'capability catalog routes the command'
    Assert-True ($docs -match 'ewf-verify') 'operator documentation starts from the human command'
    foreach ($status in 'planned','verified','integrity-failed','evidence-changed','parser-output-unrecognized','readable-no-stored-hash','unsupported','tool-integrity-failed','report-failed') {
        Assert-True ($docs -match [regex]::Escape($status)) "operator documentation defines $status"
    }
    Assert-True ($docs -match 'read-only' -and $docs -match 'attack surface') 'operator documentation explains evidence boundary and parser risk'
    Assert-True ($docs -match 'report\.json' -and $docs -match 'artifacts\.json' -and $docs -match 'stdout\.bin') 'operator documentation explains durable artifacts'
    Assert-True ($lifecycle -match 'Candidate' -and $lifecycle -match 'Approved' -and $lifecycle -match 'build revision') 'lifecycle documentation explains review and revision states'
    Assert-True ($lifecycle -match 'WSL' -and $lifecycle -match 'MSYS' -and $lifecycle -match 'no.*clobber|never uses `--clobber`') 'lifecycle documentation states native and immutable boundaries'
    Assert-True ($samples -match 'EWF verification' -and $samples -match 'readable-no-stored-hash') 'sample outputs show success and an evidence gap'
    Assert-True ($readme -match 'EWF verification' -and $readme -match 'forensic-tools') 'developer README links the public workflow and lifecycle'
    Assert-True ($navigation -match 'ewf-verification\.md' -and $navigation -match 'forensic-tools\.md') 'MkDocs navigation exposes both pages'
    Assert-True ($skill -match 'ewf-verify' -and $skill -match 'Inspect any existing report') 'focused skill starts from existing evidence and the human command'
}

function Test-RuntimeCompatibility {
    $source = Get-Source 'scripts/Invoke-EwfVerification.ps1'
    $profileSource = Get-Source 'profile/ForensicTools.ps1'
    Assert-True ($source -notmatch '\?\?|\?\.|ForEach-Object\s+-Parallel') 'script avoids PowerShell 7-only syntax'
    Assert-True ($source -match '#requires -Version 5\.1') 'runtime floor is explicit'
    Assert-True ($profileSource -notmatch '\?\?|\?\.|ForEach-Object\s+-Parallel') 'human wrapper avoids PowerShell 7-only syntax'
    . (Join-Path $repositoryRoot 'profile\ForensicTools.ps1')
    $resolved = Get-Command ewf-verify -CommandType Function -ErrorAction Stop
    $expectedResolution = "Join-Path `$env:USERPROFILE 'Source\PowerShell\scripts\Invoke-EwfVerification.ps1'"
    Assert-True ($resolved.Definition.Contains($expectedResolution)) 'both runtimes resolve the same verifier location'
}

function Test-ReleasePackageContract {
    $build = Get-Source 'scripts/Build-NativeForensicTool.ps1'
    $candidate = Get-Source 'scripts/Test-ForensicReleaseCandidate.ps1'
    $workflow = Get-Source '.github/workflows/forensic-tool-build.yml'
    Assert-True ($build -match 'ewfverify\.exe') 'package includes verifier'
    Assert-True ($build -notmatch 'ewfacquire|ewfmount|ewfexport|ewfrecover') 'package excludes out-of-scope tools'
    Assert-True ($build -match 'SBOM|spdx') 'package includes an SBOM'
    foreach ($artifact in 'manifest.json','checksums.sha256','LICENSE','provenance.json','sbom.spdx.json') {
        Assert-True (($build + $candidate) -match [regex]::Escape($artifact)) "package lifecycle requires $artifact"
    }
    Assert-True ($candidate -match 'PackageFiles|allowlist') 'offline candidate test rejects files outside the manifest'
    Assert-True ($candidate -match 'Get-PeMachine' -and $candidate -match 'AMD64') 'offline candidate test verifies PE architecture'
    Assert-True ($candidate -match 'ForbiddenImports' -and $candidate -match 'AllowedImports') 'offline candidate test applies an import allowlist'
    Assert-True ($candidate -match 'AuthenticodeState|provenance') 'offline candidate test retains truthful signing provenance'
    Assert-True ($workflow -match 'workflow_dispatch') 'build is manual rather than an ordinary update side effect'
    Assert-True ($workflow -notmatch '--clobber') 'candidate asset is never replaced'

    $root = New-NativeForensicTestRoot -Name 'candidate-package'
    try {
        $buildRecord = Join-Path $repositoryRoot 'config\forensic-builds\ewfverify-20231119-b1.psd1'
        $release = New-SyntheticForensicCandidatePackage -Root $root -BuildRecord $buildRecord
        $candidateScript = Join-Path $repositoryRoot 'scripts\Test-ForensicReleaseCandidate.ps1'
        $valid = @(. $candidateScript -PackagePath $release.Path -BuildRecord $buildRecord -SkipPeInspection -SkipCompatibilityCertification -PassThru | Where-Object { $_.PSObject.Properties['status'] })[0]
        Assert-Equal $valid.status 'Passed' 'complete synthetic package passes structural offline certification'

        $package = [pscustomobject]@{ Root = Split-Path -Parent $release.Path; Files = @() }
        $extra = New-SyntheticNativeForensicRelease -Package $package -Root $root -AdditionalEntries @{ 'unexpected.exe' = 'extra' }
        $invalid = @(. $candidateScript -PackagePath $extra.Path -BuildRecord $buildRecord -SkipPeInspection -SkipCompatibilityCertification -PassThru | Where-Object { $_.PSObject.Properties['status'] })[0]
        Assert-Equal $invalid.status 'Failed' 'candidate with an unexpected file fails closed'
    }
    finally { Remove-NativeForensicTestRoot -Root $root }
}

function Test-InstallWithoutBuild {
    $install = Get-Source 'scripts/Set-NativeForensicToolsState.ps1'
    $modules = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $apply = Get-Source 'Apply-Workstation.ps1'
    Assert-True ($install -notmatch 'MSBuild|cl\.exe|Build-NativeForensicTool') 'runtime installation does not build'
    Assert-True ($install -match 'ReleaseIdentity|Asset') 'runtime installs the approved release asset'
    $module = @($modules.Modules | Where-Object Name -eq 'NativeForensicTools')
    Assert-Equal $module.Count 1 'forensic installation is one selectable workstation module'
    Assert-True (-not $module[0].Default) 'forensic package installation is opt-in'
    Assert-True (@($module[0].DependsOn) -contains 'PowerShell7' -and @($module[0].DependsOn) -contains 'PowerShellProfile') 'forensic module declares runtime and human-command dependencies'
    Assert-True ($apply -match "'NativeForensicTools'" -and $apply -match 'Set-NativeForensicToolsState\.ps1') 'workstation orchestration routes the forensic module to its state script'
}

function Test-BuildRevisionPolicy {
    $publish = Get-Source 'scripts/Publish-NativeForensicTool.ps1'
    $workflow = Get-Source '.github/workflows/forensic-tool-publish.yml'
    Assert-True (($publish + $workflow) -notmatch '--clobber') 'forensic publication never replaces an asset'
    Assert-True ($publish -match 'BuildRevision') 'publication binds the build revision'
    Assert-True ($publish -match 'BuildIdentity|build record' -and $publish -match 'changed|distinct|increment') 'changed build inputs require a distinct build revision'
    Assert-True ($publish -match 'isDraft' -and $publish -match 'assets') 'publication validates the existing draft and exact asset'
    Assert-True ($publish -match 'Confirm|ShouldProcess|Approved') 'publication requires an explicit approved action'
    Assert-True ($workflow -match 'workflow_dispatch' -and $workflow -match 'Publish-NativeForensicTool') 'publication is a separate manual workflow'

    $root = New-NativeForensicTestRoot -Name 'publication-policy'
    try {
        $package = New-SyntheticNativeForensicPackage -Root $root
        $release = New-SyntheticNativeForensicRelease -Package $package -Root $root
        $buildRecord = Join-Path $repositoryRoot 'config\forensic-builds\ewfverify-20231119-b1.psd1'
        $buildRecordSha256 = (Get-FileHash -LiteralPath $buildRecord -Algorithm SHA256).Hash
        $catalog = New-SyntheticNativeForensicCatalog -Root (Join-Path $root 'repository') -Package $package -Release $release -DoNotInstall -BuildRecordSha256 $buildRecordSha256
        $syntheticReleaseSize = [int64] $release.Size
        $gitRunner = {
            param($Arguments)
            $verb = @($Arguments) -join ' '
            if ($verb -match '^log ') { '1234567890abcdef1234567890abcdef12345678' }
            elseif ($verb -match '^(hash-object|rev-parse) ') { 'abcdefabcdefabcdefabcdefabcdefabcdefabcd' }
            elseif ($verb -match '^ls-files ') { 'forensic-tools.psd1' }
        }
        $script:syntheticReleasePublished = $false
        $githubRunner = {
            param($Arguments)
            $verb = @($Arguments) -join ' '
            if ($verb -match '^release view ') {
                [pscustomobject]@{ isDraft = -not $script:syntheticReleasePublished; tagName = 'forensic-ewfverify-20231119-b1'; assets = @([pscustomobject]@{ name = 'ewfverify-20231119-windows-x64-b1.zip'; size = $syntheticReleaseSize }) } | ConvertTo-Json -Compress
            }
            elseif ($verb -match '^release edit .+--draft=false') { $script:syntheticReleasePublished = $true; 'published' }
            else { 'verified' }
        }
        $candidateValidator = { param($PackagePath, $RecordPath) $null = $PackagePath, $RecordPath; [pscustomobject]@{ status = 'Passed'; failure = $null } }
        $publishScript = Join-Path $repositoryRoot 'scripts\Publish-NativeForensicTool.ps1'
        $common = @{
            CatalogPath = $catalog.Path; RecordId = $catalog.Record.RecordId; BuildRecord = $buildRecord; PackagePath = $release.Path
            RepositoryPath = (Join-Path $root 'repository'); GitRunner = $gitRunner; GitHubRunner = $githubRunner
            CandidateValidator = $candidateValidator; PassThru = $true
        }
        $plan = @(. $publishScript @common | Where-Object { $_.PSObject.Properties['status'] })[0]
        Assert-Equal $plan.status 'Ready' 'publication plan validates approved local identities without publishing'
        Assert-True (-not $plan.published -and -not $script:syntheticReleasePublished) 'publication plan leaves the draft unchanged'
        $blocked = @(. $publishScript @common -Publish | Where-Object { $_.PSObject.Properties['status'] })[0]
        Assert-Equal $blocked.status 'Failed' 'publication without explicit confirmation is blocked'
        Assert-True (-not $script:syntheticReleasePublished) 'missing confirmation causes no publication call'
        $published = @(. $publishScript @common -Publish -ConfirmPublication -Confirm:$false | Where-Object { $_.PSObject.Properties['status'] })[0]
        Assert-Equal $published.status 'Published' "confirmed synthetic publication validates the post-state: $($published.failure.message)"
        Assert-True ($script:syntheticReleasePublished) 'confirmed path crosses the publication boundary once'
    }
    finally {
        Remove-Variable -Name syntheticReleasePublished -Scope Script -ErrorAction Ignore
        Remove-NativeForensicTestRoot -Root $root
    }
}

function Test-ReleaseTrustAnchor {
    $catalog = Get-Source 'config/forensic-tools.psd1'
    $buildRecord = Get-Source 'config/forensic-builds/ewfverify-20231119-b1.psd1'
    $key = Get-Source 'config/forensic-builds/keys/libyal-0ED9020DA90D3F6E70BD3945D9625E5D7AD0177E.asc'
    Assert-True ($catalog -match 'PackageSha256') 'Git catalog independently pins package digest'
    Assert-True ($buildRecord -match '6246C925A73167253444AFC24A0DEB83A3F43B7D636AF84D6AAF48A98A62F024') 'standalone native GnuPG installer is hash pinned'
    Assert-True ($buildRecord -match '83CC4E382E5E4AF554C66E429E8F66FFE499910D') 'GnuPG Authenticode signer is pinned'
    Assert-True ($buildRecord -match '0ED9020DA90D3F6E70BD3945D9625E5D7AD0177E') 'isolated libyal signer fingerprint is pinned'
    Assert-True ($key -match 'BEGIN PGP PUBLIC KEY BLOCK') 'reviewed public key is isolated in the repository'
    Assert-True ($catalog -notmatch 'CatalogCommit\s*=|ApprovalCommit\s*=') 'catalog does not self-reference its containing commit'
    $publish = Get-Source 'scripts/Publish-NativeForensicTool.ps1'
    $generalRelease = Get-Source '.github/workflows/release.yml'
    Assert-True ($publish -match 'CatalogFileSha256' -and $publish -match 'git.*status|clean') 'publish resolves the catalog digest only from a clean checkout'
    Assert-True ($publish -match 'rev-list|log.*--format|ContainingCommit') 'publish resolves the commit containing the exact approved catalog bytes'
    Assert-True ($publish -match "'attestation',\s*'verify'") 'publish independently verifies package attestation'
    Assert-True ($generalRelease -notmatch '--clobber') 'general release workflow never replaces existing assets'
    Assert-True ($generalRelease -match '--draft' -and $generalRelease -match 'isDraft') 'general release validates a draft before publication'
}

$allSections = @(
    'HumanInterface', 'NativeWindowsBoundary', 'Planning', 'EvidenceReadOnly',
    'SegmentInventory', 'SegmentIntegrity', 'MediaDigests', 'HashlessEvidence',
    'FormatCertification', 'InvocationEvidence', 'ReportContract', 'JsonParity',
    'HostileOutput', 'CatalogSchema', 'InstallIntegrity', 'ToolDrift', 'UpdatePolicy',
    'UpgradeCertification', 'CertificationCorpus', 'HistoricalAttribution',
    'OfflineExecution', 'ReportPersistence', 'DocumentationRouting',
    'RuntimeCompatibility', 'ReleasePackageContract', 'InstallWithoutBuild',
    'BuildRevisionPolicy', 'ReleaseTrustAnchor'
)

$sections = if ($Section -eq 'All') { $allSections } else { @($Section) }
foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}

Write-Host "Native forensic verification tests passed ($script:assertions assertions)."
