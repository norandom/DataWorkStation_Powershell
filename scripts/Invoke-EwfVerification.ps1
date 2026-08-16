#requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Public and injected parameters are consumed by the nested verification transaction.')]
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $Path,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $ReportDirectory,
    [switch] $Plan,
    [switch] $Json,
    [Parameter(DontShow = $true)][string] $CatalogPath,
    [Parameter(DontShow = $true)][scriptblock] $NativeProcessRunner,
    [Parameter(DontShow = $true)][scriptblock] $FileIdentityProvider,
    [Parameter(DontShow = $true)][scriptblock] $SegmentCandidateProvider,
    [Parameter(DontShow = $true)][scriptblock] $RunIdProvider,
    [Parameter(DontShow = $true)][scriptblock] $PersistenceFaultProvider,
    [Parameter(DontShow = $true)][scriptblock] $PreInvocationHook,
    [Parameter(DontShow = $true)][scriptblock] $CatalogCommitProvider,
    [Parameter(DontShow = $true)][switch] $PassThru
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CatalogPath)) { $CatalogPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\forensic-tools.psd1' }
$maximumNativeOutputBytes = 1048576
$maximumDisplayCharacters = 8192

function ConvertTo-HexString {
    param([Parameter(Mandatory = $true)][byte[]] $Bytes)
    ([BitConverter]::ToString($Bytes) -replace '-', '').ToUpperInvariant()
}

function Get-ByteArraySHA256 {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]] $Bytes)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        ConvertTo-HexString -Bytes $algorithm.ComputeHash($Bytes)
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-BoundedByteCapture {
    param(
        [AllowEmptyCollection()][byte[]] $Bytes,
        [Parameter(Mandatory = $true)][int] $MaximumBytes
    )

    if ($null -eq $Bytes) { $Bytes = [byte[]] @() }
    $capturedLength = [Math]::Min($Bytes.Length, $MaximumBytes)
    $captured = New-Object byte[] $capturedLength
    if ($capturedLength -gt 0) { [Array]::Copy($Bytes, 0, $captured, 0, $capturedLength) }
    [pscustomobject]@{
        Bytes = [byte[]] $captured
        Size = [int64] $capturedLength
        Sha256 = Get-ByteArraySHA256 -Bytes $captured
        SourceSize = [int64] $Bytes.Length
        SourceSha256 = Get-ByteArraySHA256 -Bytes $Bytes
        Truncated = $Bytes.Length -gt $MaximumBytes
    }
}

function ConvertTo-SafeDisplayText {
    param(
        [AllowEmptyCollection()][byte[]] $Bytes,
        [Parameter(Mandatory = $true)][int] $MaximumCharacters
    )

    if ($null -eq $Bytes) { $Bytes = [byte[]] @() }
    $encoding = New-Object Text.UTF8Encoding($false, $false)
    $text = $encoding.GetString($Bytes)
    $escape = [regex]::Escape([string] [char] 27)
    $bell = [regex]::Escape([string] [char] 7)
    $text = [regex]::Replace($text, "$escape\][^$bell]*(?:$bell|$escape\\)", '')
    $text = [regex]::Replace($text, "$escape\[[0-?]*[ -/]*[@-~]", '')
    $builder = New-Object Text.StringBuilder
    foreach ($character in $text.ToCharArray()) {
        $code = [int] $character
        if ($character -eq "`r" -or $character -eq "`n" -or $character -eq "`t" -or ($code -ge 0x20 -and $code -ne 0x7f)) {
            [void] $builder.Append($character)
        }
        else {
            [void] $builder.Append([char]0xfffd)
        }
        if ($builder.Length -ge $MaximumCharacters) { break }
    }
    $builder.ToString()
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string] $LiteralPath,
        [AllowEmptyString()][string] $Content
    )
    [IO.File]::WriteAllText($LiteralPath, $Content, (New-Object Text.UTF8Encoding($false)))
}

function Get-FileArtifactRecord {
    param(
        [Parameter(Mandatory = $true)][string] $LiteralPath,
        [Parameter(Mandatory = $true)][string] $Name,
        [int64] $SourceSize = -1,
        [string] $SourceSha256,
        [switch] $Truncated
    )
    $item = Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
    $sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($SourceSize -lt 0) { $SourceSize = [int64] $item.Length }
    if ([string]::IsNullOrEmpty($SourceSha256)) { $SourceSha256 = $sha256 }
    [pscustomobject]@{
        name = $Name
        size = [int64] $item.Length
        sha256 = $sha256
        sourceSize = $SourceSize
        sourceSha256 = $SourceSha256.ToUpperInvariant()
        truncated = [bool] $Truncated
    }
}

function Limit-FileToBound {
    param(
        [Parameter(Mandatory = $true)][string] $LiteralPath,
        [Parameter(Mandatory = $true)][int] $MaximumBytes
    )

    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $hash = [Security.Cryptography.SHA256]::Create()
    $capture = New-Object IO.MemoryStream
    $buffer = New-Object byte[] 8192
    [int64] $sourceSize = 0
    try {
        while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            [void] $hash.TransformBlock($buffer, 0, $count, $null, 0)
            $sourceSize += $count
            $remaining = $MaximumBytes - [int] $capture.Length
            if ($remaining -gt 0) { $capture.Write($buffer, 0, [Math]::Min($count, $remaining)) }
        }
        [void] $hash.TransformFinalBlock([byte[]] @(), 0, 0)
        $bytes = $capture.ToArray()
        $sourceSha256 = ConvertTo-HexString -Bytes $hash.Hash
    }
    finally {
        $stream.Dispose()
        $hash.Dispose()
        $capture.Dispose()
    }
    if ($sourceSize -gt $MaximumBytes) { [IO.File]::WriteAllBytes($LiteralPath, $bytes) }
    [pscustomobject]@{
        SourceSize = $sourceSize
        SourceSha256 = $sourceSha256
        Truncated = $sourceSize -gt $MaximumBytes
    }
}

function Get-ExactCatalogCommit {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)

    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $warning = $null
    $commit = $null
    $git = Get-Command git.exe -CommandType Application -ErrorAction Ignore
    if ($null -eq $git) {
        $warning = 'Catalog commit is unavailable because Git is not installed.'
    }
    else {
        $catalogDirectory = Split-Path -Parent $LiteralPath
        $root = (& $git.Source -C $catalogDirectory rev-parse --show-toplevel 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
            $warning = 'Catalog commit is unavailable because the catalog is outside a Git worktree.'
        }
        else {
            $root = [IO.Path]::GetFullPath([string] $root)
            $relative = [IO.Path]::GetFullPath($LiteralPath).Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
            $headBlob = (& $git.Source -C $root rev-parse "HEAD:$relative" 2>$null | Select-Object -First 1)
            $worktreeBlob = (& $git.Source -C $root hash-object -- $LiteralPath 2>$null | Select-Object -First 1)
            $status = (& $git.Source -C $root status --porcelain=v1 -- $relative 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $headBlob -eq $worktreeBlob -and [string]::IsNullOrEmpty($status)) {
                $head = (& $git.Source -C $root rev-parse HEAD 2>$null | Select-Object -First 1)
                if ($head -match '^[0-9a-f]{40}$') { $commit = $head }
            }
            if ($null -eq $commit) { $warning = 'Catalog commit is unavailable because the exact catalog bytes are untracked or dirty.' }
        }
    }
    $ErrorActionPreference = $savedErrorActionPreference
    [pscustomobject]@{ Commit = $commit; Warning = $warning }
}

function Test-ReportDestinationBoundary {
    param(
        [Parameter(Mandatory = $true)][string] $ReportRoot,
        [Parameter(Mandatory = $true)][object[]] $Segments
    )
    if (-not (Test-Path -LiteralPath $ReportRoot -PathType Container)) {
        throw "Report destination is not an existing directory: $ReportRoot"
    }
    $normalizedReport = [IO.Path]::GetFullPath($ReportRoot).TrimEnd('\') + '\'
    foreach ($segment in $Segments) {
        $evidenceDirectory = [IO.Path]::GetDirectoryName($segment.Path).TrimEnd('\') + '\'
        if ($normalizedReport.StartsWith($evidenceDirectory, [StringComparison]::OrdinalIgnoreCase) -or
            $evidenceDirectory.StartsWith($normalizedReport, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Report destination must be outside the evidence directory tree.'
        }
    }
}

function Get-StreamIdentity {
    param(
        [Parameter(Mandatory = $true)][IO.Stream] $Stream,
        [Parameter(Mandatory = $true)][string] $LiteralPath,
        [Parameter(Mandatory = $true)][ValidateSet('Pre', 'Post')][string] $Phase
    )

    [void] $LiteralPath
    [void] $Phase
    [void] $Stream.Seek(0, [IO.SeekOrigin]::Begin)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = ConvertTo-HexString -Bytes $algorithm.ComputeHash($Stream)
    }
    finally {
        $algorithm.Dispose()
        [void] $Stream.Seek(0, [IO.SeekOrigin]::Begin)
    }
    [pscustomobject]@{
        Length = [int64] $Stream.Length
        Sha256 = $hash
    }
}

function Get-EwfSegmentSet {
    param(
        [Parameter(Mandatory = $true)][string] $SelectedPath,
        [scriptblock] $CandidateProvider
    )

    $selected = Get-Item -LiteralPath $SelectedPath -ErrorAction Stop
    if ($selected.PSIsContainer) { throw 'The selected evidence path is a directory.' }
    $match = [regex]::Match($selected.Name, '^(?<base>.+)\.[Ee](?<ordinal>[0-9]{2})$')
    if (-not $match.Success) { throw "Unsupported EWF segment suffix: $($selected.Name)" }

    $baseName = $match.Groups['base'].Value
    $prefix = $baseName + '.e'
    $related = if ($null -ne $CandidateProvider) {
        @(& $CandidateProvider $selected.DirectoryName $baseName)
    }
    else {
        @([IO.Directory]::EnumerateFiles($selected.DirectoryName) | Where-Object {
            [IO.Path]::GetFileName($_).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
        })
    }
    $segments = @()
    foreach ($candidatePath in $related) {
        $candidateName = [IO.Path]::GetFileName($candidatePath)
        $candidateMatch = [regex]::Match($candidateName, '^(?<base>.+)\.[Ee](?<ordinal>[0-9]{2})$')
        if (-not $candidateMatch.Success) {
            throw "Unexpected segment suffix or ordinal: $candidateName"
        }
        if (-not $candidateMatch.Groups['base'].Value.Equals($baseName, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Ambiguous or conflicting segment basename: $candidateName"
        }
        $segments += [pscustomobject]@{
            Ordinal = [int] $candidateMatch.Groups['ordinal'].Value
            Path = [IO.Path]::GetFullPath($candidatePath)
            Name = $candidateName
            Extension = [IO.Path]::GetExtension($candidateName)
        }
    }
    if ($segments.Count -eq 0) { throw 'No EWF segments were discovered.' }
    $duplicate = @($segments | Group-Object Ordinal | Where-Object Count -gt 1)
    if ($duplicate.Count -gt 0) {
        $duplicateOrdinal = [int] $duplicate[0].Name
        throw "Duplicate segment ordinal E$('{0:D2}' -f $duplicateOrdinal)."
    }
    $segments = @($segments | Sort-Object Ordinal)
    if ($segments[0].Ordinal -ne 1) { throw 'Segment gap: E01 is missing.' }
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $expectedOrdinal = $index + 1
        if ($segments[$index].Ordinal -ne $expectedOrdinal) {
            throw "Segment gap: E$('{0:D2}' -f $expectedOrdinal) is missing."
        }
    }
    $segments
}

function Get-ApprovedToolRecord {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "Forensic tool catalog not found: $LiteralPath"
    }
    $catalog = Import-PowerShellDataFile -LiteralPath $LiteralPath
    $records = @($catalog.Records | Where-Object {
        $_.ToolId -eq 'ewfverify' -and $_.ReviewState -eq 'Approved'
    })
    if ($records.Count -ne 1) {
        throw "Expected exactly one Approved ewfverify record; observed $($records.Count)."
    }
    $record = $records[0]
    if ($null -eq $record.SupportedFormats -or $null -eq $record.ParserProfile) {
        throw 'Approved record lacks SupportedFormats or ParserProfile.'
    }
    $record
}

function Test-InstalledToolFiles {
    param([Parameter(Mandatory = $true)] $ToolRecord)

    $installRoot = [Environment]::ExpandEnvironmentVariables([string] $ToolRecord.InstallRoot)
    $expectedPaths = @($ToolRecord.PackageFiles | ForEach-Object { ([string] $_.RelativePath).Replace('\', '/') })
    $observedPaths = @(Get-ChildItem -LiteralPath $installRoot -File -Recurse -ErrorAction Stop | ForEach-Object { $_.FullName.Substring($installRoot.TrimEnd('\').Length + 1).Replace('\', '/') })
    if ((@($expectedPaths | Sort-Object) -join "`n") -cne (@($observedPaths | Sort-Object) -join "`n")) { throw 'Installed tool file allowlist mismatch or unexpected file detected.' }
    $observed = @()
    foreach ($expectedFile in $ToolRecord.PackageFiles) {
        $filePath = Join-Path $installRoot $expectedFile.RelativePath
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            throw "Installed tool file is missing: $($expectedFile.RelativePath)"
        }
        $item = Get-Item -LiteralPath $filePath
        $sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($item.Length -ne [int64] $expectedFile.Size -or $sha256 -ne $expectedFile.Sha256) {
            throw "Installed tool file integrity mismatch: $($expectedFile.RelativePath)"
        }
        $observed += [pscustomobject]@{
            relativePath = $expectedFile.RelativePath
            size = [int64] $item.Length
            sha256 = $sha256
        }
    }
    $observed
}

function ConvertTo-WindowsArgument {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string] $Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}

function Invoke-DefaultNativeProcess {
    param(
        [Parameter(Mandatory = $true)][string] $Executable,
        [Parameter(Mandatory = $true)][string[]] $Arguments
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-WindowsArgument -Value $_ }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.WorkingDirectory = Split-Path -Parent $Executable
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $startedAtUtc = [datetime]::UtcNow
    if (-not $process.Start()) { throw 'Native verifier process did not start.' }
    $stdoutStream = $process.StandardOutput.BaseStream
    $stderrStream = $process.StandardError.BaseStream
    $stdoutBuffer = New-Object byte[] 8192
    $stderrBuffer = New-Object byte[] 8192
    $stdoutCapture = New-Object IO.MemoryStream
    $stderrCapture = New-Object IO.MemoryStream
    $stdoutHash = [Security.Cryptography.SHA256]::Create()
    $stderrHash = [Security.Cryptography.SHA256]::Create()
    [int64] $stdoutSize = 0
    [int64] $stderrSize = 0
    $stdoutTask = $stdoutStream.ReadAsync($stdoutBuffer, 0, $stdoutBuffer.Length)
    $stderrTask = $stderrStream.ReadAsync($stderrBuffer, 0, $stderrBuffer.Length)
    try {
        while ($null -ne $stdoutTask -or $null -ne $stderrTask) {
            if ($null -ne $stdoutTask -and $null -ne $stderrTask) {
                [void] [Threading.Tasks.Task]::WaitAny([Threading.Tasks.Task[]] @($stdoutTask, $stderrTask))
            }
            elseif ($null -ne $stdoutTask) { $stdoutTask.Wait() }
            else { $stderrTask.Wait() }

            if ($null -ne $stdoutTask -and $stdoutTask.IsCompleted) {
                $count = $stdoutTask.GetAwaiter().GetResult()
                if ($count -eq 0) { $stdoutTask = $null }
                else {
                    [void] $stdoutHash.TransformBlock($stdoutBuffer, 0, $count, $null, 0)
                    $stdoutSize += $count
                    $remaining = $maximumNativeOutputBytes - [int] $stdoutCapture.Length
                    if ($remaining -gt 0) { $stdoutCapture.Write($stdoutBuffer, 0, [Math]::Min($count, $remaining)) }
                    $stdoutTask = $stdoutStream.ReadAsync($stdoutBuffer, 0, $stdoutBuffer.Length)
                }
            }
            if ($null -ne $stderrTask -and $stderrTask.IsCompleted) {
                $count = $stderrTask.GetAwaiter().GetResult()
                if ($count -eq 0) { $stderrTask = $null }
                else {
                    [void] $stderrHash.TransformBlock($stderrBuffer, 0, $count, $null, 0)
                    $stderrSize += $count
                    $remaining = $maximumNativeOutputBytes - [int] $stderrCapture.Length
                    if ($remaining -gt 0) { $stderrCapture.Write($stderrBuffer, 0, [Math]::Min($count, $remaining)) }
                    $stderrTask = $stderrStream.ReadAsync($stderrBuffer, 0, $stderrBuffer.Length)
                }
            }
        }
        [void] $stdoutHash.TransformFinalBlock([byte[]] @(), 0, 0)
        [void] $stderrHash.TransformFinalBlock([byte[]] @(), 0, 0)
        $process.WaitForExit()
        $endedAtUtc = [datetime]::UtcNow
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOutBytes = $stdoutCapture.ToArray()
            StdErrBytes = $stderrCapture.ToArray()
            StdOutSourceSize = $stdoutSize
            StdErrSourceSize = $stderrSize
            StdOutSourceSha256 = ConvertTo-HexString -Bytes $stdoutHash.Hash
            StdErrSourceSha256 = ConvertTo-HexString -Bytes $stderrHash.Hash
            StdOutTruncated = $stdoutSize -gt $maximumNativeOutputBytes
            StdErrTruncated = $stderrSize -gt $maximumNativeOutputBytes
            StartedAtUtc = $startedAtUtc
            EndedAtUtc = $endedAtUtc
        }
    }
    finally {
        $stdoutHash.Dispose()
        $stderrHash.Dispose()
        $stdoutCapture.Dispose()
        $stderrCapture.Dispose()
        $process.Dispose()
    }
}

function Get-MediaDigestResults {
    param([Parameter(Mandatory = $true)][string] $OutputText)

    $storedMD5 = $null
    $calculatedMD5 = $null
    $calculatedSHA256 = $null
    $storedMatch = [regex]::Match($OutputText, '(?im)^MD5 hash stored in file:\s*([^\r\n]+)')
    if ($storedMatch.Success -and $storedMatch.Groups[1].Value.Trim() -ne 'N/A') {
        $storedMD5 = $storedMatch.Groups[1].Value.Trim().ToLowerInvariant()
    }
    $calculatedMatch = [regex]::Match($OutputText, '(?im)^MD5 hash calculated over data:\s*([0-9a-f]+)')
    if ($calculatedMatch.Success) { $calculatedMD5 = $calculatedMatch.Groups[1].Value.ToLowerInvariant() }
    $sha256Match = [regex]::Match($OutputText, '(?im)^SHA256 hash calculated over data:\s*([0-9a-f]+)')
    if ($sha256Match.Success) { $calculatedSHA256 = $sha256Match.Groups[1].Value.ToUpperInvariant() }

    $md5Matches = $null
    if ($null -ne $storedMD5 -and $null -ne $calculatedMD5) {
        $md5Matches = $storedMD5 -eq $calculatedMD5
    }
    @(
        [pscustomobject]@{ algorithm = 'MD5'; stored = $storedMD5; calculated = $calculatedMD5; matches = $md5Matches }
        [pscustomobject]@{ algorithm = 'SHA256'; stored = $null; calculated = $calculatedSHA256; matches = $null }
    )
}

function New-PreflightFailure {
    param(
        [Parameter(Mandatory = $true)][string] $Status,
        [Parameter(Mandatory = $true)][string] $Code,
        [Parameter(Mandatory = $true)][string] $Message
    )
    [pscustomobject]@{
        schemaVersion = '1.0'
        runId = [guid]::NewGuid().ToString()
        status = $Status
        verified = $false
        warnings = @()
        failure = [pscustomobject]@{ code = $Code; message = $Message }
    }
}

function Invoke-EwfVerificationCore {
    $stagingPath = $null
    try {
        if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
            return New-PreflightFailure -Status 'tool-integrity-failed' -Code 'native-windows-required' -Message 'EWF verification requires native Windows.'
        }
        $selectedPath = [IO.Path]::GetFullPath($Path)
        $reportPath = [IO.Path]::GetFullPath($ReportDirectory)
        $record = Get-ApprovedToolRecord -LiteralPath $CatalogPath
        $segments = @(Get-EwfSegmentSet -SelectedPath $selectedPath -CandidateProvider $SegmentCandidateProvider)
        Test-ReportDestinationBoundary -ReportRoot $reportPath -Segments $segments

        if ($Plan) {
            return [pscustomobject]@{
                schemaVersion = '1.0'
                action = 'Plan'
                status = 'planned'
                selectedPath = $selectedPath
                reportDestination = $reportPath
                toolRecord = [pscustomobject]@{
                    toolId = $record.ToolId
                    upstreamVersion = $record.UpstreamVersion
                    buildRevision = $record.BuildRevision
                    reviewState = $record.ReviewState
                }
                segmentCandidates = @($segments | ForEach-Object {
                    [pscustomobject]@{ ordinal = $_.Ordinal; path = $_.Path }
                })
                operations = @(
                    [pscustomobject]@{ name = 'validate-installed-tool'; readsMediaData = $false; changesSystemState = $false }
                    [pscustomobject]@{ name = 'hold-read-only-segments'; readsMediaData = $false; changesSystemState = $false }
                    [pscustomobject]@{ name = 'hash-and-verify'; readsMediaData = $false; changesSystemState = $false }
                    [pscustomobject]@{ name = 'write-new-report'; readsMediaData = $false; changesSystemState = $false }
                )
                warnings = @()
            }
        }
    }
    catch {
        $message = $_.Exception.Message
        $status = if ($message -match 'Report destination') { 'report-failed' } elseif ($message -match 'segment|suffix|ordinal|basename|E01') { 'unsupported' } else { 'tool-integrity-failed' }
        return New-PreflightFailure -Status $status -Code 'preflight-failed' -Message $message
    }

    try {
        $toolFiles = @(Test-InstalledToolFiles -ToolRecord $record)
    }
    catch {
        return New-PreflightFailure -Status 'tool-integrity-failed' -Code 'tool-integrity-failed' -Message $_.Exception.Message
    }

    try {
        $runIdText = if ($null -ne $RunIdProvider) { [string] (& $RunIdProvider) } else { [guid]::NewGuid().ToString() }
        $runId = ([guid]::Parse($runIdText)).ToString()
        $finalReportPath = Join-Path $reportPath ("ewf-$runId")
        if (Test-Path -LiteralPath $finalReportPath) { throw "A report already exists for run identity $runId." }
        $stagingPath = Join-Path $reportPath ("ewf-$runId.staging-$([guid]::NewGuid().ToString('N'))")
        if ($null -ne $PersistenceFaultProvider) { & $PersistenceFaultProvider 'BeforeStaging' $stagingPath }
        [void] (New-Item -ItemType Directory -Path $stagingPath -ErrorAction Stop)
    }
    catch {
        if ($null -ne $stagingPath -and (Test-Path -LiteralPath $stagingPath)) { Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction Ignore }
        return New-PreflightFailure -Status 'report-failed' -Code 'report-persistence-failed' -Message $_.Exception.Message
    }

    $streams = @()
    $segmentResults = @()
    try {
        foreach ($segment in $segments) {
            $stream = [IO.File]::Open($segment.Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            $streams += $stream
            $identity = if ($null -ne $FileIdentityProvider) {
                & $FileIdentityProvider $stream $segment.Path 'Pre'
            }
            else {
                Get-StreamIdentity -Stream $stream -LiteralPath $segment.Path -Phase 'Pre'
            }
            $segmentResults += [pscustomobject]@{
                ordinal = $segment.Ordinal
                name = $segment.Name
                path = $segment.Path
                extension = $segment.Extension
                preLength = [int64] $identity.Length
                preSha256 = $identity.Sha256.ToUpperInvariant()
                postLength = [int64] 0
                postSha256 = $null
                unchanged = $false
            }
        }

        if ($null -ne $PreInvocationHook) { & $PreInvocationHook $record }
        try { $toolFiles = @(Test-InstalledToolFiles -ToolRecord $record) }
        catch { throw "tool-integrity-failed: $($_.Exception.Message)" }
        $expandedInstallRoot = [Environment]::ExpandEnvironmentVariables([string] $record.InstallRoot)
        $executablePath = [IO.Path]::GetFullPath((Join-Path $expandedInstallRoot 'ewfverify.exe'))
        $upstreamLogPath = Join-Path $stagingPath 'ewfverify.log'
        $argumentVector = @('-d', 'sha256', '-l', $upstreamLogPath) + @($segments | ForEach-Object Path)
        $processResult = if ($null -ne $NativeProcessRunner) {
            & $NativeProcessRunner $executablePath $argumentVector
        }
        else {
            Invoke-DefaultNativeProcess -Executable $executablePath -Arguments $argumentVector
        }

        for ($index = 0; $index -lt $segments.Count; $index++) {
            $postIdentity = if ($null -ne $FileIdentityProvider) {
                & $FileIdentityProvider $streams[$index] $segments[$index].Path 'Post'
            }
            else {
                Get-StreamIdentity -Stream $streams[$index] -LiteralPath $segments[$index].Path -Phase 'Post'
            }
            $segmentResults[$index].postLength = [int64] $postIdentity.Length
            $segmentResults[$index].postSha256 = $postIdentity.Sha256.ToUpperInvariant()
            $segmentResults[$index].unchanged = (
                $segmentResults[$index].preLength -eq $segmentResults[$index].postLength -and
                $segmentResults[$index].preSha256 -eq $segmentResults[$index].postSha256
            )
        }
    }
    catch {
        if (Test-Path -LiteralPath $stagingPath) { Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction Ignore }
        if ($_.Exception.Message -match '^tool-integrity-failed:') {
            return New-PreflightFailure -Status 'tool-integrity-failed' -Code 'tool-integrity-failed' -Message $_.Exception.Message
        }
        return New-PreflightFailure -Status 'integrity-failed' -Code 'verification-failed' -Message $_.Exception.Message
    }
    finally {
        foreach ($stream in $streams) {
            if ($null -ne $stream) { $stream.Dispose() }
        }
    }

    if ($null -ne $processResult.PSObject.Properties['StdOutSourceSha256']) {
        $stdoutCapture = [pscustomobject]@{
            Bytes = [byte[]] @($processResult.StdOutBytes)
            Size = [int64] @($processResult.StdOutBytes).Count
            Sha256 = Get-ByteArraySHA256 -Bytes ([byte[]] @($processResult.StdOutBytes))
            SourceSize = [int64] $processResult.StdOutSourceSize
            SourceSha256 = [string] $processResult.StdOutSourceSha256
            Truncated = [bool] $processResult.StdOutTruncated
        }
        $stderrCapture = [pscustomobject]@{
            Bytes = [byte[]] @($processResult.StdErrBytes)
            Size = [int64] @($processResult.StdErrBytes).Count
            Sha256 = Get-ByteArraySHA256 -Bytes ([byte[]] @($processResult.StdErrBytes))
            SourceSize = [int64] $processResult.StdErrSourceSize
            SourceSha256 = [string] $processResult.StdErrSourceSha256
            Truncated = [bool] $processResult.StdErrTruncated
        }
    }
    else {
        $stdoutCapture = Get-BoundedByteCapture -Bytes ([byte[]] @($processResult.StdOutBytes)) -MaximumBytes $maximumNativeOutputBytes
        $stderrCapture = Get-BoundedByteCapture -Bytes ([byte[]] @($processResult.StdErrBytes)) -MaximumBytes $maximumNativeOutputBytes
    }
    $stdoutBytes = [byte[]] @($stdoutCapture.Bytes)
    $stderrBytes = [byte[]] @($stderrCapture.Bytes)
    $stdoutText = ConvertTo-SafeDisplayText -Bytes $stdoutBytes -MaximumCharacters $maximumNativeOutputBytes
    $stderrText = ConvertTo-SafeDisplayText -Bytes $stderrBytes -MaximumCharacters $maximumNativeOutputBytes
    $combinedText = $stdoutText + "`n" + $stderrText
    $mediaDigests = @(Get-MediaDigestResults -OutputText $combinedText)
    $md5 = @($mediaDigests | Where-Object algorithm -eq 'MD5')[0]
    $changed = @($segmentResults | Where-Object { -not $_.unchanged })

    $status = 'parser-output-unrecognized'
    if ($changed.Count -gt 0) {
        $status = 'evidence-changed'
    }
    elseif ($combinedText -match '(?i)unsupported') {
        $status = 'unsupported'
    }
    elseif ($processResult.ExitCode -ne 0 -or $combinedText -match '(?i)FAILURE|errors were detected|hash mismatch') {
        $status = 'integrity-failed'
    }
    elseif ($stdoutText -notmatch [regex]::Escape($record.ParserProfile.Banner) -or $null -eq $md5.calculated) {
        $status = 'parser-output-unrecognized'
    }
    elseif ($null -eq $md5.stored) {
        $status = 'readable-no-stored-hash'
    }
    elseif ($md5.matches -and $combinedText -match '(?i)ewfverify:\s*SUCCESS') {
        $status = 'verified'
    }
    else {
        $status = 'integrity-failed'
    }

    $catalogSha256 = (Get-FileHash -LiteralPath $CatalogPath -Algorithm SHA256).Hash.ToUpperInvariant()
    $catalogCommit = if ($null -ne $CatalogCommitProvider) {
        $providedCommit = & $CatalogCommitProvider $CatalogPath
        if ($providedCommit -is [string]) { [pscustomobject]@{ Commit = $providedCommit; Warning = $null } }
        else { $providedCommit }
    }
    else { Get-ExactCatalogCommit -LiteralPath $CatalogPath }
    $warnings = @()
    if (-not [string]::IsNullOrEmpty($catalogCommit.Warning)) { $warnings += $catalogCommit.Warning }
    if ($stdoutCapture.Truncated) { $warnings += "Native stdout exceeded $maximumNativeOutputBytes bytes and the retained artifact was truncated; the complete stream identity is recorded." }
    if ($stderrCapture.Truncated) { $warnings += "Native stderr exceeded $maximumNativeOutputBytes bytes and the retained artifact was truncated; the complete stream identity is recorded." }
    $failure = $null
    if ($status -ne 'verified') {
        $failure = [pscustomobject]@{ code = $status; message = "Verification completed with status: $status" }
    }
    $result = [pscustomobject]@{
        schemaVersion = '1.0'
        runId = $runId
        reportDirectory = $finalReportPath
        status = $status
        verified = $status -eq 'verified'
        startedAtUtc = $processResult.StartedAtUtc.ToUniversalTime().ToString('o')
        endedAtUtc = $processResult.EndedAtUtc.ToUniversalTime().ToString('o')
        host = [pscustomobject]@{
            computerName = [Environment]::MachineName
            windowsVersion = [Environment]::OSVersion.VersionString
            architecture = 'x64'
            powerShellVersion = $PSVersionTable.PSVersion.ToString()
        }
        tool = [pscustomobject]@{
            toolId = $record.ToolId
            upstreamVersion = $record.UpstreamVersion
            buildRevision = $record.BuildRevision
            catalogFileSha256 = $catalogSha256
            catalogCommit = $catalogCommit.Commit
            releaseTag = $record.ReleaseIdentity.Tag
            packageSha256 = $record.ReleaseIdentity.PackageSha256
            executablePath = $executablePath
            files = $toolFiles
            sourceArtifacts = @($record.SourceArtifacts | ForEach-Object {
                [pscustomobject]@{
                    name = [string] $_.Name
                    size = [int64] $_.Size
                    sha256 = ([string] $_.Sha256).ToUpperInvariant()
                    origin = [string] $_.Origin
                }
            })
        }
        evidence = [pscustomobject]@{
            selectedPath = $selectedPath
            formatProfile = $record.SupportedFormats[0].ProfileId
            totalBytes = [int64](($segmentResults | Measure-Object preLength -Sum).Sum)
            segments = $segmentResults
        }
        invocation = [pscustomobject]@{
            executable = $executablePath
            arguments = $argumentVector
            exitCode = [int] $processResult.ExitCode
            parserProfile = $record.ParserProfile.Id
        }
        mediaDigests = $mediaDigests
        artifacts = @()
        warnings = $warnings
        failure = $failure
    }

    try {
        $stdoutPath = Join-Path $stagingPath 'stdout.bin'
        $stderrPath = Join-Path $stagingPath 'stderr.bin'
        [IO.File]::WriteAllBytes($stdoutPath, $stdoutBytes)
        [IO.File]::WriteAllBytes($stderrPath, $stderrBytes)

        if ($null -ne $processResult.PSObject.Properties['UpstreamLogBytes']) {
            $logCapture = Get-BoundedByteCapture -Bytes ([byte[]] @($processResult.UpstreamLogBytes)) -MaximumBytes $maximumNativeOutputBytes
            [IO.File]::WriteAllBytes($upstreamLogPath, [byte[]] @($logCapture.Bytes))
            $logSource = [pscustomobject]@{ SourceSize = $logCapture.SourceSize; SourceSha256 = $logCapture.SourceSha256; Truncated = $logCapture.Truncated }
        }
        else {
            if (-not (Test-Path -LiteralPath $upstreamLogPath -PathType Leaf)) { [IO.File]::WriteAllBytes($upstreamLogPath, [byte[]] @()) }
            $logSource = Limit-FileToBound -LiteralPath $upstreamLogPath -MaximumBytes $maximumNativeOutputBytes
        }
        if ($logSource.Truncated) { $result.warnings += "Upstream log exceeded $maximumNativeOutputBytes bytes and was truncated; the complete source identity is recorded." }

        $stdoutPreview = ConvertTo-SafeDisplayText -Bytes $stdoutBytes -MaximumCharacters $maximumDisplayCharacters
        $stderrPreview = ConvertTo-SafeDisplayText -Bytes $stderrBytes -MaximumCharacters $maximumDisplayCharacters
        $reportLines = @(
            'EWF verification report'
            "Run: $runId"
            "Status: $status"
            "Verified: $($result.verified)"
            "Evidence: $selectedPath"
            "Segments: $($segmentResults.Count)"
            "Tool: $($record.ToolId) $($record.UpstreamVersion)-$($record.BuildRevision)"
            "Package SHA-256: $($record.ReleaseIdentity.PackageSha256)"
            "Catalog SHA-256: $catalogSha256"
            "Started UTC: $($result.startedAtUtc)"
            "Ended UTC: $($result.endedAtUtc)"
            ''
            'Warnings:'
            $(if ($result.warnings.Count -eq 0) { 'None.' } else { $result.warnings | ForEach-Object { "- $_" } })
            ''
            'Sanitized stdout preview:'
            $stdoutPreview
            ''
            'Sanitized stderr preview:'
            $stderrPreview
            ''
            'Limit: verification observes EWF integrity; it does not establish acquisition legality, chain of custody, evidentiary meaning, or absence of malicious content.'
        )
        $reportTextPath = Join-Path $stagingPath 'report.txt'
        Write-Utf8File -LiteralPath $reportTextPath -Content ($reportLines -join "`r`n")

        $result.artifacts = @(
            Get-FileArtifactRecord -LiteralPath $reportTextPath -Name 'report.txt'
            Get-FileArtifactRecord -LiteralPath $stdoutPath -Name 'stdout.bin' -SourceSize $stdoutCapture.SourceSize -SourceSha256 $stdoutCapture.SourceSha256 -Truncated:$stdoutCapture.Truncated
            Get-FileArtifactRecord -LiteralPath $stderrPath -Name 'stderr.bin' -SourceSize $stderrCapture.SourceSize -SourceSha256 $stderrCapture.SourceSha256 -Truncated:$stderrCapture.Truncated
            Get-FileArtifactRecord -LiteralPath $upstreamLogPath -Name 'ewfverify.log' -SourceSize $logSource.SourceSize -SourceSha256 $logSource.SourceSha256 -Truncated:$logSource.Truncated
        )
        Write-Utf8File -LiteralPath (Join-Path $stagingPath 'report.json') -Content ($result | ConvertTo-Json -Depth 16)
        Write-Utf8File -LiteralPath (Join-Path $stagingPath 'artifacts.json') -Content ($result.artifacts | ConvertTo-Json -Depth 6)
        if ($null -ne $PersistenceFaultProvider) { & $PersistenceFaultProvider 'BeforeCommit' $finalReportPath }
        [IO.Directory]::Move($stagingPath, $finalReportPath)
        $stagingPath = $null
    }
    catch {
        $persistenceMessage = $_.Exception.Message
        if ($null -ne $stagingPath -and (Test-Path -LiteralPath $stagingPath)) { Remove-Item -LiteralPath $stagingPath -Recurse -Force -ErrorAction Ignore }
        $result.status = 'report-failed'
        $result.verified = $false
        $result.failure = [pscustomobject]@{ code = 'report-persistence-failed'; message = $persistenceMessage }
    }
    $result
}

$result = Invoke-EwfVerificationCore
$exitCodes = @{
    verified = 0
    planned = 0
    'integrity-failed' = 1
    'evidence-changed' = 1
    'parser-output-unrecognized' = 1
    'readable-no-stored-hash' = 2
    unsupported = 3
    'tool-integrity-failed' = 4
    'report-failed' = 5
}
$resultExitCode = if ($exitCodes.ContainsKey($result.status)) { $exitCodes[$result.status] } else { 1 }

if ($PassThru) {
    $result
}
elseif ($Json) {
    $result | ConvertTo-Json -Depth 12 -Compress
}
elseif ($result.status -eq 'planned') {
    "Plan: $($result.segmentCandidates.Count) EWF segment(s), tool $($result.toolRecord.toolId) $($result.toolRecord.upstreamVersion)-$($result.toolRecord.buildRevision)."
    "Report destination: $($result.reportDestination)"
}
else {
    "EWF verification: $($result.status)"
    if ($null -ne $result.evidence) { "Evidence: $($result.evidence.selectedPath)" }
    if ($null -ne $result.tool) { "Tool: $($result.tool.toolId) $($result.tool.upstreamVersion)-$($result.tool.buildRevision)" }
    if ($null -ne $result.reportDirectory) { "Report: $($result.reportDirectory)" }
    if ($null -ne $result.failure) { "Detail: $($result.failure.message)" }
}

if (-not $PassThru -and $MyInvocation.InvocationName -ne '.') {
    exit $resultExitCode
}
