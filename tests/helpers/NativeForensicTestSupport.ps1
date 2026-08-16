#requires -Version 5.1

function New-NativeForensicTestRoot {
    [CmdletBinding()]
    param([string] $Name = 'run')

    $safeName = $Name -replace '[^A-Za-z0-9._-]', '_'
    $root = Join-Path ([IO.Path]::GetTempPath()) ('dws-native-forensic-{0}-{1}' -f $safeName, [guid]::NewGuid().ToString('N'))
    [void] (New-Item -ItemType Directory -Path $root)
    $root
}

function Get-TestFileIdentity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)

    $item = Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
    [pscustomobject]@{
        RelativePath = $item.Name
        Size = [int64] $item.Length
        Sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    }
}

function Get-TestByteArraySha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]] $Bytes)

    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($algorithm.ComputeHash($Bytes)) -replace '-', '').ToUpperInvariant()
    }
    finally {
        $algorithm.Dispose()
    }
}

function New-SyntheticNativeForensicPackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Root)

    $payload = Join-Path $Root 'payload'
    [void] (New-Item -ItemType Directory -Path $payload -Force)
    $files = [ordered]@{
        'ewfverify.exe' = 'synthetic verifier - never execute'
        'libewf.dll' = 'synthetic libewf'
        'zlib.dll' = 'synthetic zlib'
        'bzip2.dll' = 'synthetic bzip2'
        'LICENSE.txt' = 'synthetic test license'
        'manifest.json' = '{"schemaVersion":"1.0","synthetic":true}'
        'sbom.spdx.json' = '{"spdxVersion":"SPDX-2.3","name":"synthetic"}'
        'provenance.json' = '{"schemaVersion":"1.0","synthetic":true}'
    }
    foreach ($entry in $files.GetEnumerator()) {
        [IO.File]::WriteAllText((Join-Path $payload $entry.Key), $entry.Value, [Text.UTF8Encoding]::new($false))
    }
    $identities = @(
        Get-ChildItem -LiteralPath $payload -File | Sort-Object Name | ForEach-Object {
            $identity = Get-TestFileIdentity -LiteralPath $_.FullName
            $identity.RelativePath = $_.Name
            $identity
        }
    )
    [pscustomobject]@{ Root = $payload; Files = $identities }
}

function New-NativeForensicReportRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Root)

    $reportRoot = Join-Path $Root 'reports'
    [void] (New-Item -ItemType Directory -Path $reportRoot -Force)
    $reportRoot
}

function New-SyntheticNativeForensicRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Package,
        [Parameter(Mandatory)][string] $Root,
        [hashtable] $AdditionalEntries = @{},
        [string[]] $EntryNames
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archivePath = Join-Path $Root ("ewfverify-synthetic-$([guid]::NewGuid().ToString('N')).zip")
    $archive = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $names = if ($EntryNames) { @($EntryNames) } else { @($Package.Files | ForEach-Object RelativePath) }
        foreach ($name in $names) {
            $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $entryStream = $entry.Open()
            try {
                $sourcePath = Join-Path $Package.Root ([IO.Path]::GetFileName($name))
                if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
                    $source = [IO.File]::OpenRead($sourcePath)
                    try { $source.CopyTo($entryStream) } finally { $source.Dispose() }
                }
                elseif ($AdditionalEntries.ContainsKey($name)) {
                    $bytes = [Text.Encoding]::UTF8.GetBytes([string] $AdditionalEntries[$name])
                    $entryStream.Write($bytes, 0, $bytes.Length)
                }
            }
            finally { $entryStream.Dispose() }
        }
        foreach ($entryName in $AdditionalEntries.Keys) {
            if ($names -contains $entryName) { continue }
            $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
            $entryStream = $entry.Open()
            try {
                $bytes = [Text.Encoding]::UTF8.GetBytes([string] $AdditionalEntries[$entryName])
                $entryStream.Write($bytes, 0, $bytes.Length)
            }
            finally { $entryStream.Dispose() }
        }
    }
    finally { $archive.Dispose() }
    $item = Get-Item -LiteralPath $archivePath
    [pscustomobject]@{
        Path = $archivePath
        Size = [int64] $item.Length
        Sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    }
}

function New-SyntheticForensicCandidatePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $BuildRecord
    )

    $payload = Join-Path $Root ("candidate-payload-$([guid]::NewGuid().ToString('N'))")
    [void] (New-Item -ItemType Directory -Path $payload)
    foreach ($name in 'ewfverify.exe','libewf.dll','zlib.dll') {
        [IO.File]::WriteAllText((Join-Path $payload $name), "synthetic $name - never execute", (New-Object Text.UTF8Encoding($false)))
    }
    foreach ($name in 'LICENSE-libewf.txt','LICENSE-zlib.txt','LICENSE-bzip2.txt') {
        [IO.File]::WriteAllText((Join-Path $payload $name), "synthetic license $name", (New-Object Text.UTF8Encoding($false)))
    }
    [IO.File]::WriteAllText((Join-Path $payload 'manifest.json'), '{"SchemaVersion":"1.0","ToolId":"ewfverify","UpstreamVersion":"20231119","BuildRevision":"b1","Architecture":"x64"}', (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $payload 'sbom.spdx.json'), '{"spdxVersion":"SPDX-2.3","name":"synthetic candidate"}', (New-Object Text.UTF8Encoding($false)))
    $buildRecordSha256 = (Get-FileHash -LiteralPath $BuildRecord -Algorithm SHA256).Hash
    [IO.File]::WriteAllText((Join-Path $payload 'provenance.json'), (ConvertTo-Json -Compress -Depth 5 ([ordered]@{ SchemaVersion = '1.0'; ToolId = 'ewfverify'; BuildRevision = 'b1'; BuildRecordSha256 = $buildRecordSha256; SourceArtifacts = @([ordered]@{ Name = 'synthetic' }); AuthenticodeState = 'Unsigned' })), (New-Object Text.UTF8Encoding($false)))
    $checksumLines = @(Get-ChildItem -LiteralPath $payload -File | Sort-Object Name | ForEach-Object { "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)  $($_.Name)" })
    [IO.File]::WriteAllText((Join-Path $payload 'checksums.sha256'), (($checksumLines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
    $package = [pscustomobject]@{
        Root = $payload
        Files = @(Get-ChildItem -LiteralPath $payload -File | Sort-Object Name | ForEach-Object { Get-TestFileIdentity -LiteralPath $_.FullName })
    }
    New-SyntheticNativeForensicRelease -Package $package -Root $Root
}

function New-SyntheticNativeForensicCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)] $Package,
        [ValidateSet('Candidate', 'Approved', 'Withdrawn', 'Superseded')]
        [string] $ReviewState = 'Approved',
        $Release,
        [switch] $DoNotInstall,
        [string] $InstallRoot,
        [string] $BuildRecordSha256 = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
    )

    [void] (New-Item -ItemType Directory -Path $Root -Force)
    $installedRoot = if ($InstallRoot) { $InstallRoot } else { Join-Path $Root 'installed\ewfverify-20231119-b1' }
    if (-not $DoNotInstall) {
        [void] (New-Item -ItemType Directory -Path $installedRoot -Force)
        foreach ($file in Get-ChildItem -LiteralPath $Package.Root -File) {
            Copy-Item -LiteralPath $file.FullName -Destination $installedRoot
        }
    }

    $fileRecords = foreach ($file in $Package.Files) {
        "            @{ RelativePath = '$($file.RelativePath.Replace("'", "''"))'; Size = $($file.Size); Sha256 = '$($file.Sha256)' }"
    }
    $escapedInstallRoot = $installedRoot.Replace("'", "''")
    $releaseSize = if ($null -ne $Release) { [int64] $Release.Size } else { 1 }
    $releaseSha256 = if ($null -ne $Release) { [string] $Release.Sha256 } else { 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' }
    $catalogText = @"
@{
    SchemaVersion = '1.0'
    Records = @(
        @{
            RecordId = 'forensic-ewfverify-20231119-b1'
            ToolId = 'ewfverify'
            UpstreamVersion = '20231119'
            BuildRevision = 'b1'
            ReviewState = '$ReviewState'
            InstallRoot = '$escapedInstallRoot'
            SupportedFormats = @(
                @{ ProfileId = 'encase6-classic-e01'; Family = 'E01'; FirstExtension = '.E01'; MaximumOrdinal = 99 }
            )
            ParserProfile = @{
                Id = 'libewf-20231119-en-us-v1'
                Banner = 'ewfverify 20231119'
            }
            ReleaseIdentity = @{
                Repository = 'norandom/PowerShell'
                Tag = 'forensic-ewfverify-20231119-b1'
                AssetName = 'ewfverify-20231119-windows-x64-b1.zip'
                AssetUrl = 'https://github.com/norandom/PowerShell/releases/download/forensic-ewfverify-20231119-b1/ewfverify-20231119-windows-x64-b1.zip'
                AssetSize = $releaseSize
                PackageSha256 = '$releaseSha256'
                AttestationIdentity = 'synthetic-test-attestation'
            }
            SourceArtifacts = @(
                @{ Name = 'libewf-experimental-20231119.tar.gz'; Size = 1; Sha256 = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'; Origin = 'https://example.invalid/libewf'; SignatureSha256 = 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'; Authenticity = 'DetachedSignatureVerified' }
            )
            BuildIdentity = @{ BuildRecordSha256 = '$BuildRecordSha256'; Commit = '1111111111111111111111111111111111111111'; Workflow = '.github/workflows/forensic-tool-build.yml'; Runner = 'windows-2025'; Architecture = 'x64'; Compiler = 'MSVC 19.44'; Linker = '14.44'; MSBuild = '17.14'; WindowsSdk = '10.0.26100.0'; ConverterCommit = 'ce1bd73b3e23b34e98c206b26df4c2d663500554'; Arguments = @('Release','x64'); SbomSha256 = 'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' }
            PackageFiles = @(
$($fileRecords -join "`r`n")
            )
            LicenseSummary = @{ Spdx = @('LGPL-3.0-or-later','Zlib','bzip2-1.0.6'); Paths = @('LICENSE.txt') }
            Certification = @{
                CorpusVersion = '008-v1'
                Lanes = @('WindowsPowerShell-5.1','PowerShell-7')
                Result = 'Passed'
                AttestationIdentity = 'synthetic-test-attestation'
                ReviewedBuildSha256 = 'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE'
                ApprovalDecision = 'approved-for-test'
                Reviewer = 'synthetic'
                ReviewedAtUtc = '2026-08-16T12:00:00Z'
            }
        }
    )
}
"@
    $catalogPath = Join-Path $Root 'forensic-tools.psd1'
    [IO.File]::WriteAllText($catalogPath, $catalogText, [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{
        Path = $catalogPath
        InstallRoot = $installedRoot
        Sha256 = (Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash
        Record = (Import-PowerShellDataFile -LiteralPath $catalogPath).Records[0]
    }
}

function New-SyntheticNativeProcessResult {
    [CmdletBinding()]
    param(
        [int] $ExitCode = 0,
        [AllowNull()][string] $StoredMD5 = '91d8ae3beabcd4f8469a2fcb8055ba14',
        [AllowNull()][string] $CalculatedMD5 = '91d8ae3beabcd4f8469a2fcb8055ba14',
        [AllowNull()][string] $CalculatedSHA256 = 'EDFAD2B84481209605168A88120F414883D6A4072E3C283D792E2524D4EAD324',
        [string] $StdOut,
        [string] $StdErr = '',
        [byte[]] $RawStdOut,
        [byte[]] $RawStdErr,
        [byte[]] $UpstreamLogBytes = @(),
        [datetime] $StartedAtUtc = [datetime]::SpecifyKind([datetime]'2026-08-16T10:00:00', [DateTimeKind]::Utc),
        [datetime] $EndedAtUtc = [datetime]::SpecifyKind([datetime]'2026-08-16T10:00:01', [DateTimeKind]::Utc)
    )
    if (-not $PSBoundParameters.ContainsKey('StdOut')) {
        $storedText = if ([string]::IsNullOrEmpty($StoredMD5)) { 'N/A' } else { $StoredMD5 }
        $calculatedText = if ([string]::IsNullOrEmpty($CalculatedMD5)) { 'N/A' } else { $CalculatedMD5 }
        $sha256Text = if ([string]::IsNullOrEmpty($CalculatedSHA256)) { 'N/A' } else { $CalculatedSHA256 }
        $StdOut = @"
ewfverify 20231119

Verify completed at: 2026-08-16 10:00:01
Read: 2,5 MiB (2621440 bytes) in 1 second(s)

MD5 hash stored in file:        $storedText
MD5 hash calculated over data:  $calculatedText
SHA256 hash calculated over data: $sha256Text

ewfverify: SUCCESS
"@
    }
    [byte[]] $stdoutBytes = @()
    [byte[]] $stderrBytes = @()
    if ($PSBoundParameters.ContainsKey('RawStdOut')) { $stdoutBytes = $RawStdOut } else { $stdoutBytes = [Text.Encoding]::UTF8.GetBytes($StdOut) }
    if ($PSBoundParameters.ContainsKey('RawStdErr')) { $stderrBytes = $RawStdErr } else { $stderrBytes = [Text.Encoding]::UTF8.GetBytes($StdErr) }
    [pscustomobject]@{
        ExitCode = $ExitCode
        StdOutBytes = $stdoutBytes
        StdErrBytes = $stderrBytes
        UpstreamLogBytes = $UpstreamLogBytes
        StartedAtUtc = $StartedAtUtc
        EndedAtUtc = $EndedAtUtc
    }
}

function New-DerivedEwfCertificationCorpus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $FixtureRoot,
        [Parameter(Mandatory)][string] $DestinationRoot
    )

    $fixturePath = [IO.Path]::GetFullPath($FixtureRoot)
    $destinationPath = [IO.Path]::GetFullPath($DestinationRoot)
    if ($destinationPath.StartsWith($fixturePath, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Derived certification cases must not be created inside the committed fixture tree.'
    }
    [void] (New-Item -ItemType Directory -Path $destinationPath -Force)

    function Copy-CertificationSet {
        param([string] $SourcePrefix, [string] $CaseName, [string] $DestinationPrefix = $SourcePrefix)
        $caseRoot = Join-Path $destinationPath $CaseName
        [void] (New-Item -ItemType Directory -Path $caseRoot -Force)
        foreach ($source in Get-ChildItem -LiteralPath $fixturePath -File | Where-Object BaseName -eq $SourcePrefix | Sort-Object Extension) {
            $targetName = $DestinationPrefix + $source.Extension
            Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $caseRoot $targetName)
        }
        [pscustomobject]@{ Root = $caseRoot; FirstSegment = Join-Path $caseRoot ($DestinationPrefix + '.E01') }
    }

    $cases = @()

    $valid = Copy-CertificationSet -SourcePrefix 'ordinary' -CaseName 'valid'
    $cases += [pscustomobject]@{ Name = 'valid'; Path = $valid.FirstSegment; ExpectedStatus = 'verified'; Recipe = 'copy-ordinary' }

    $corrupt = Copy-CertificationSet -SourcePrefix 'ordinary' -CaseName 'corrupt'
    $corruptSegment = Join-Path $corrupt.Root 'ordinary.E02'
    $stream = [IO.File]::Open($corruptSegment, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        [void] $stream.Seek([Math]::Min(4096, $stream.Length - 1), [IO.SeekOrigin]::Begin)
        $value = $stream.ReadByte()
        [void] $stream.Seek(-1, [IO.SeekOrigin]::Current)
        $stream.WriteByte([byte] ($value -bxor 0x5a))
    }
    finally { $stream.Dispose() }
    $cases += [pscustomobject]@{ Name = 'corrupt'; Path = $corrupt.FirstSegment; ExpectedStatus = 'integrity-failed'; Recipe = 'flip-one-byte-in-second-segment' }

    $incomplete = Copy-CertificationSet -SourcePrefix 'ordinary' -CaseName 'incomplete'
    Remove-Item -LiteralPath (Join-Path $incomplete.Root 'ordinary.E03') -Force
    $cases += [pscustomobject]@{ Name = 'incomplete'; Path = $incomplete.FirstSegment; ExpectedStatus = 'integrity-failed'; Recipe = 'remove-final-segment' }

    $hashless = Copy-CertificationSet -SourcePrefix 'hashless' -CaseName 'hashless'
    $cases += [pscustomobject]@{ Name = 'hashless'; Path = $hashless.FirstSegment; ExpectedStatus = 'readable-no-stored-hash'; Recipe = 'copy-hashless' }

    $unsupported = Copy-CertificationSet -SourcePrefix 'ordinary' -CaseName 'unsupported'
    foreach ($segment in Get-ChildItem -LiteralPath $unsupported.Root -Filter 'ordinary.E*' -File) {
        Rename-Item -LiteralPath $segment.FullName -NewName ($segment.Name -replace '\.E(?<ordinal>\d{2})$', '.S${ordinal}')
    }
    $unsupportedPath = Join-Path $unsupported.Root 'ordinary.S01'
    $cases += [pscustomobject]@{ Name = 'unsupported'; Path = $unsupportedPath; ExpectedStatus = 'unsupported'; Recipe = 'rename-to-uncertified-family' }

    $hostile = Copy-CertificationSet -SourcePrefix 'ordinary' -CaseName 'hostile-output'
    $hostileBytes = [byte[]] (0xff, 0xfe, 0x1b, 0x5b, 0x32, 0x4a, 0x00) + [Text.Encoding]::UTF8.GetBytes(('misleading SUCCESS ' * 8192))
    $cases += [pscustomobject]@{ Name = 'hostile-output'; Path = $hostile.FirstSegment; ExpectedStatus = 'parser-output-unrecognized'; Recipe = 'inject-bounded-invalid-utf8-and-terminal-controls'; NativeStdOutBytes = $hostileBytes }

    $persistence = Copy-CertificationSet -SourcePrefix 'ordinary' -CaseName 'persistence-failure'
    $cases += [pscustomobject]@{ Name = 'persistence-failure'; Path = $persistence.FirstSegment; ExpectedStatus = 'report-failed'; Recipe = 'inject-before-commit-failure'; PersistenceFailure = 'synthetic certification persistence failure' }

    [pscustomobject]@{
        SchemaVersion = '1.0'
        SourceFixtureRoot = $fixturePath
        DestinationRoot = $destinationPath
        Cases = $cases
    }
}

function Remove-NativeForensicTestRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Root)

    $resolved = [IO.Path]::GetFullPath($Root)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notlike 'dws-native-forensic-*') {
        throw "Refusing to remove non-test path: $resolved"
    }
    if (Test-Path -LiteralPath $resolved) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
