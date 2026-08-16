#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $PackagePath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $BuildRecord,
    [switch] $Json,
    [Parameter(DontShow = $true)][switch] $PassThru,
    [Parameter(DontShow = $true)][switch] $SkipPeInspection,
    [Parameter(DontShow = $true)][switch] $SkipCompatibilityCertification,
    [Parameter(DontShow = $true)][scriptblock] $CertificationResultProvider
)

$ErrorActionPreference = 'Stop'

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)
    $stream = [IO.File]::OpenRead($LiteralPath)
    $reader = New-Object IO.BinaryReader($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5a4d) { throw "Not a PE image: $LiteralPath" }
        [void] $stream.Seek(0x3c, [IO.SeekOrigin]::Begin)
        $peOffset = $reader.ReadUInt32()
        [void] $stream.Seek($peOffset, [IO.SeekOrigin]::Begin)
        if ($reader.ReadUInt32() -ne 0x00004550) { throw "Invalid PE signature: $LiteralPath" }
        $machine = $reader.ReadUInt16()
        switch ($machine) {
            0x8664 { 'AMD64' }
            0x014c { 'I386' }
            0xaa64 { 'ARM64' }
            default { '0x{0:X4}' -f $machine }
        }
    }
    finally { $reader.Dispose(); $stream.Dispose() }
}

function Get-DumpbinPath {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) { throw 'vswhere.exe is required for offline PE dependency inspection.' }
    $installation = @(& $vswhere -latest -products Microsoft.VisualStudio.Product.BuildTools -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
    if (-not $installation) { throw 'MSVC Build Tools are required for offline PE dependency inspection.' }
    $toolsVersionFile = Join-Path $installation 'VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt'
    $toolsVersion = (Get-Content -LiteralPath $toolsVersionFile -Raw).Trim()
    $dumpbin = Join-Path $installation "VC\Tools\MSVC\$toolsVersion\bin\Hostx64\x64\dumpbin.exe"
    if (-not (Test-Path -LiteralPath $dumpbin -PathType Leaf)) { throw "dumpbin.exe not found: $dumpbin" }
    $dumpbin
}

function Test-AllowedImport {
    param([string] $Import, [string[]] $Allowlist)
    foreach ($allowed in $Allowlist) {
        if ($Import -like $allowed) { return $true }
    }
    $false
}

function Get-SafeZipEntries {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($LiteralPath)
    try {
        $entries = @{}
        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }
            $name = $entry.FullName.Replace('\', '/')
            if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or @($name.Split('/') | Where-Object { $_ -eq '..' }).Count -gt 0) { throw "Unsafe archive path: $name" }
            if ($entries.ContainsKey($name)) { throw "Duplicate archive path: $name" }
            $entries[$name] = $entry
        }
        [pscustomobject]@{ Archive = $archive; Entries = $entries }
        $archive = $null
    }
    finally { if ($null -ne $archive) { $archive.Dispose() } }
}

$workRoot = $null
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Forensic candidate inspection requires native Windows.' }
    $package = Get-Item -LiteralPath ([IO.Path]::GetFullPath($PackagePath)) -ErrorAction Stop
    $record = Import-PowerShellDataFile -LiteralPath ([IO.Path]::GetFullPath($BuildRecord))
    if ($record.Target.OperatingSystem -ne 'Windows' -or $record.Target.PeMachine -ne 'AMD64') { throw 'Build record does not require native Windows AMD64.' }
    $packageFileAllowlist = @($record.Package.AllowedRuntimeFiles) + @($record.Package.RequiredMetadataFiles)
    $inventory = Get-SafeZipEntries -LiteralPath $package.FullName
    try {
        $observed = @($inventory.Entries.Keys | Sort-Object)
        $expected = @($packageFileAllowlist | Sort-Object)
        if (($observed -join "`n") -cne ($expected -join "`n")) { throw "PackageFiles allowlist mismatch. Expected: $($expected -join ', '); observed: $($observed -join ', ')." }
        $workRoot = Join-Path ([IO.Path]::GetTempPath()) ("dws-forensic-candidate-$([guid]::NewGuid().ToString('N'))")
        [void] (New-Item -ItemType Directory -Path $workRoot)
        foreach ($name in $inventory.Entries.Keys) {
            $destination = Join-Path $workRoot $name
            $parent = Split-Path -Parent $destination
            [void] (New-Item -ItemType Directory -Path $parent -Force)
            $inputStream = $inventory.Entries[$name].Open()
            $outputStream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $inputStream.Dispose() }
        }
    }
    finally { $inventory.Archive.Dispose() }

    foreach ($required in 'manifest.json','checksums.sha256','LICENSE-libewf.txt','LICENSE-zlib.txt','LICENSE-bzip2.txt','sbom.spdx.json','provenance.json') {
        if (-not (Test-Path -LiteralPath (Join-Path $workRoot $required) -PathType Leaf)) { throw "Required package artifact is missing: $required" }
    }
    $manifest = Get-Content -LiteralPath (Join-Path $workRoot 'manifest.json') -Raw | ConvertFrom-Json
    $sbom = Get-Content -LiteralPath (Join-Path $workRoot 'sbom.spdx.json') -Raw | ConvertFrom-Json
    $provenance = Get-Content -LiteralPath (Join-Path $workRoot 'provenance.json') -Raw | ConvertFrom-Json
    if ($manifest.ToolId -ne $record.ToolId -or $manifest.UpstreamVersion -ne $record.UpstreamVersion -or $manifest.BuildRevision -ne $record.BuildRevision) { throw 'Manifest identity does not match the build record.' }
    if ($sbom.spdxVersion -notmatch '^SPDX-') { throw 'SBOM is not an SPDX document.' }
    if ($provenance.BuildRevision -ne $record.BuildRevision -or -not $provenance.SourceArtifacts) { throw 'Build provenance is incomplete or mismatched.' }
    $buildRecordSha256 = (Get-FileHash -LiteralPath ([IO.Path]::GetFullPath($BuildRecord)) -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($provenance.BuildRecordSha256 -ne $buildRecordSha256) { throw 'Build provenance does not identify the exact build-record bytes.' }

    $checksums = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $workRoot 'checksums.sha256')) {
        if ($line -match '^([0-9A-Fa-f]{64})\s+\*?(.+)$') { $checksums[$matches[2].Replace('\','/')] = $matches[1].ToUpperInvariant() }
    }
    foreach ($name in $packageFileAllowlist | Where-Object { $_ -ne 'checksums.sha256' }) {
        if (-not $checksums.ContainsKey($name)) { throw "Checksum manifest omits package file: $name" }
        if ((Get-FileHash -LiteralPath (Join-Path $workRoot $name) -Algorithm SHA256).Hash -ne $checksums[$name]) { throw "Checksum mismatch for package file: $name" }
    }

    $imports = @{}
    if (-not $SkipPeInspection) {
        $dumpbin = Get-DumpbinPath
        foreach ($name in $record.Package.AllowedRuntimeFiles) {
            $path = Join-Path $workRoot $name
            if ((Get-PeMachine -LiteralPath $path) -ne 'AMD64') { throw "Package PE is not AMD64: $name" }
            $dependencyOutput = @(& $dumpbin /nologo /dependents $path 2>&1)
            if ($LASTEXITCODE -ne 0) { throw "dumpbin dependency inspection failed for $name" }
            $fileImports = @($dependencyOutput | ForEach-Object { if ([string] $_ -match '^\s*([A-Za-z0-9_.-]+\.dll)\s*$') { $matches[1].ToLowerInvariant() } } | Where-Object { $_ } | Sort-Object -Unique)
            foreach ($import in $fileImports) {
                if ($record.Package.ForbiddenImports -contains $import) { throw "Forbidden runtime dependency in $name`: $import" }
                if (-not (Test-AllowedImport -Import $import -Allowlist $record.Package.AllowedImports)) { throw "Dependency import is outside the allowlist in $name`: $import" }
            }
            $imports[$name] = $fileImports
        }
    }

    $requiredCertificationCases = @('valid', 'corrupt', 'incomplete', 'hashless', 'unsupported', 'hostile-output', 'persistence-failure')
    $requiredCertificationLanes = @('WindowsPowerShell-5.1', 'PowerShell-7')
    $certification = @()
    if (-not $SkipCompatibilityCertification) {
        if ($null -ne $CertificationResultProvider) {
            $certification = @(& $CertificationResultProvider $package.FullName $workRoot $record $requiredCertificationLanes $requiredCertificationCases)
        }
        else {
            $certificationScript = Join-Path $PSScriptRoot 'Test-ForensicCandidateCompatibility.ps1'
            $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $powerShell7 = (Get-Command pwsh.exe -CommandType Application -ErrorAction Stop).Source
            foreach ($lane in @(
                @{ Name = 'WindowsPowerShell-5.1'; Executable = $windowsPowerShell },
                @{ Name = 'PowerShell-7'; Executable = $powerShell7 }
            )) {
                $laneOutput = @(& $lane.Executable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $certificationScript -PackageRoot $workRoot -BuildRecord $BuildRecord -Json 2>&1)
                if ($LASTEXITCODE -ne 0) { throw "Compatibility certification failed in $($lane.Name): $($laneOutput -join ' ')" }
                try { $certification += (($laneOutput -join "`n") | ConvertFrom-Json -ErrorAction Stop) }
                catch { throw "Compatibility certification returned invalid JSON in $($lane.Name)." }
            }
        }

        foreach ($requiredLane in $requiredCertificationLanes) {
            $laneResults = @($certification | Where-Object lane -eq $requiredLane)
            if ($laneResults.Count -ne 1 -or $laneResults[0].status -ne 'Passed') { throw "Compatibility certification failed or is missing for lane: $requiredLane" }
            $caseNames = @($laneResults[0].cases | ForEach-Object { [string] $_.name } | Sort-Object)
            if (($caseNames -join "`n") -cne (@($requiredCertificationCases | Sort-Object) -join "`n")) { throw "Compatibility certification case set is incomplete for lane: $requiredLane" }
            $mismatches = @($laneResults[0].cases | Where-Object { -not $_.passed -or $_.observedStatus -ne $_.expectedStatus })
            if ($mismatches.Count -gt 0) { throw "Compatibility certification failed for $($mismatches.Count) case(s) in lane: $requiredLane" }
        }
    }

    $result = [pscustomobject]@{
        schemaVersion = '1.0'
        status = 'Passed'
        packagePath = $package.FullName
        packageSize = [int64] $package.Length
        packageSha256 = (Get-FileHash -LiteralPath $package.FullName -Algorithm SHA256).Hash
        toolId = $record.ToolId
        upstreamVersion = $record.UpstreamVersion
        buildRevision = $record.BuildRevision
        files = @($packageFileAllowlist | ForEach-Object { $item = Get-Item -LiteralPath (Join-Path $workRoot $_); [pscustomobject]@{ path = $_; size = [int64] $item.Length; sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash } })
        imports = $imports
        certification = $certification
        warnings = @(
            $(if ($SkipPeInspection) { 'PE/import inspection was explicitly skipped by the test seam.' })
            $(if ($SkipCompatibilityCertification) { 'Compatibility certification was explicitly skipped by the structural test seam.' })
        )
        failure = $null
    }
}
catch {
    $result = [pscustomobject]@{ schemaVersion = '1.0'; status = 'Failed'; packagePath = $PackagePath; packageSize = $null; packageSha256 = $null; toolId = $null; upstreamVersion = $null; buildRevision = $null; files = @(); imports = @{}; certification = @(); warnings = @(); failure = [pscustomobject]@{ code = 'candidate-validation-failed'; message = $_.Exception.Message } }
}
finally {
    if ($null -ne $workRoot -and (Test-Path -LiteralPath $workRoot)) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction Ignore }
}

if ($PassThru) { $result }
elseif ($Json) { $result | ConvertTo-Json -Depth 10 -Compress }
else {
    "Forensic release candidate: $($result.status)"
    if ($result.packageSha256) { "Package SHA-256: $($result.packageSha256)" }
    if ($result.failure) { "Detail: $($result.failure.message)" }
}
if (-not $PassThru -and $MyInvocation.InvocationName -ne '.' -and $result.status -ne 'Passed') { exit 1 }
