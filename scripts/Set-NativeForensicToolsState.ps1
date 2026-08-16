#requires -Version 5.1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Injected package and attestation callbacks use fixed testable signatures.')]
[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure')]
    [string] $Mode = 'Test',
    [switch] $Json,
    [Parameter(DontShow = $true)]
    [string] $CatalogPath,
    [Parameter(DontShow = $true)]
    [string] $PackagePath,
    [Parameter(DontShow = $true)]
    [scriptblock] $DownloadProvider,
    [Parameter(DontShow = $true)]
    [scriptblock] $AttestationVerifier,
    [Parameter(DontShow = $true)]
    [scriptblock] $InstallFaultProvider,
    [Parameter(DontShow = $true)]
    [switch] $PassThru
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CatalogPath)) { $CatalogPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\forensic-tools.psd1' }

function New-ToolStateResult {
    param(
        [Parameter(Mandatory = $true)][string] $State,
        [Parameter(Mandatory = $true)][string] $ModeName,
        $Record,
        [string[]] $Operations = @(),
        [string[]] $Warnings = @(),
        $Failure = $null
    )
    [pscustomobject]@{
        schemaVersion = '1.0'
        mode = $ModeName
        state = $State
        toolRecord = if ($null -eq $Record) { $null } else { [pscustomobject]@{ toolId = $Record.ToolId; upstreamVersion = $Record.UpstreamVersion; buildRevision = $Record.BuildRevision; reviewState = $Record.ReviewState } }
        installRoot = if ($null -eq $Record) { $null } else { [Environment]::ExpandEnvironmentVariables([string] $Record.InstallRoot) }
        operations = @($Operations)
        warnings = @($Warnings)
        failure = $Failure
    }
}

function Get-CurrentToolRecord {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) { throw "Forensic tool catalog not found: $LiteralPath" }
    $catalog = Import-PowerShellDataFile -LiteralPath $LiteralPath
    if ([int] $catalog.SchemaVersion -ne 1) { throw "Unsupported forensic tool catalog schema: $($catalog.SchemaVersion)" }
    $records = @($catalog.Records | Where-Object ToolId -eq 'ewfverify')
    if ($records.Count -eq 0) { throw 'The forensic tool catalog has no ewfverify record.' }
    $approved = @($records | Where-Object ReviewState -eq 'Approved')
    if ($approved.Count -gt 1) { throw 'The forensic tool catalog has more than one Approved ewfverify record.' }
    if ($approved.Count -eq 1) { return $approved[0] }
    @($records | Sort-Object UpstreamVersion, BuildRevision -Descending | Select-Object -First 1)[0]
}

function Assert-InstallableRecord {
    param([Parameter(Mandatory = $true)] $Record)

    if ($Record.ReviewState -ne 'Approved') { throw "Forensic tool record is $($Record.ReviewState), not Approved." }
    if ($Record.ReleaseIdentity.AssetSize -isnot [int] -and $Record.ReleaseIdentity.AssetSize -isnot [long]) { throw 'Approved release asset size is missing.' }
    if ([string] $Record.ReleaseIdentity.PackageSha256 -notmatch '^[0-9A-Fa-f]{64}$') { throw 'Approved release package SHA-256 is missing or invalid.' }
    if (@($Record.PackageFiles).Count -eq 0) { throw 'Approved package file allowlist is empty.' }
    foreach ($file in $Record.PackageFiles) {
        if ([string]::IsNullOrWhiteSpace([string] $file.RelativePath) -or [string] $file.Sha256 -notmatch '^[0-9A-Fa-f]{64}$' -or $null -eq $file.Size) {
            throw "Approved package file identity is incomplete: $($file.RelativePath)"
        }
    }
}

function Get-InstalledToolState {
    param([Parameter(Mandatory = $true)] $Record)

    if ($Record.ReviewState -ne 'Approved') { return 'Unapproved' }
    $installRoot = [Environment]::ExpandEnvironmentVariables([string] $Record.InstallRoot)
    if (-not (Test-Path -LiteralPath $installRoot -PathType Container)) { return 'Absent' }
    $expected = @{}
    foreach ($file in $Record.PackageFiles) { $expected[[string] $file.RelativePath] = $file }
    $observed = @(Get-ChildItem -LiteralPath $installRoot -File -Recurse)
    if ($observed.Count -ne $expected.Count) { return 'Drifted' }
    foreach ($item in $observed) {
        $relative = $item.FullName.Substring($installRoot.TrimEnd('\').Length + 1).Replace('\', '/')
        if (-not $expected.ContainsKey($relative)) { return 'Drifted' }
        $identity = $expected[$relative]
        if ([int64] $item.Length -ne [int64] $identity.Size) { return 'Drifted' }
        if ((Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash -ne ([string] $identity.Sha256).ToUpperInvariant()) { return 'Drifted' }
    }
    foreach ($relative in $expected.Keys) {
        if (-not (Test-Path -LiteralPath (Join-Path $installRoot $relative) -PathType Leaf)) { return 'Drifted' }
    }
    'Compliant'
}

function Get-SafeArchiveInventory {
    param(
        [Parameter(Mandatory = $true)][string] $LiteralPath,
        [Parameter(Mandatory = $true)] $Record
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($LiteralPath)
    try {
        $expected = @{}
        foreach ($file in $Record.PackageFiles) { $expected[([string] $file.RelativePath).Replace('\', '/')] = $file }
        $observed = @{}
        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }
            $name = $entry.FullName.Replace('\', '/')
            if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or @($name.Split('/') | Where-Object { $_ -eq '..' }).Count -gt 0) {
                throw "Unsafe archive traversal path: $name"
            }
            if ($observed.ContainsKey($name)) { throw "Duplicate archive path: $name" }
            if (-not $expected.ContainsKey($name)) { throw "Unexpected archive file outside the allowlist: $name" }
            $observed[$name] = $entry
        }
        foreach ($name in $expected.Keys) {
            if (-not $observed.ContainsKey($name)) { throw "Expected package file is missing from the archive: $name" }
        }
        [pscustomobject]@{ Archive = $archive; Entries = $observed; Expected = $expected }
        $archive = $null
    }
    finally {
        if ($null -ne $archive) { $archive.Dispose() }
    }
}

function Expand-ValidatedArchive {
    param(
        [Parameter(Mandatory = $true)][string] $LiteralPath,
        [Parameter(Mandatory = $true)] $Record,
        [Parameter(Mandatory = $true)][string] $Destination
    )

    $inventory = Get-SafeArchiveInventory -LiteralPath $LiteralPath -Record $Record
    try {
        foreach ($name in $inventory.Entries.Keys) {
            $destinationPath = Join-Path $Destination $name
            $parent = Split-Path -Parent $destinationPath
            [void] (New-Item -ItemType Directory -Path $parent -Force)
            $inputStream = $inventory.Entries[$name].Open()
            $outputStream = [IO.File]::Open($destinationPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $inputStream.CopyTo($outputStream) }
            finally { $outputStream.Dispose(); $inputStream.Dispose() }
        }
    }
    finally { $inventory.Archive.Dispose() }
}

function Assert-InstalledFiles {
    param(
        [Parameter(Mandatory = $true)] $Record,
        [Parameter(Mandatory = $true)][string] $Root
    )
    foreach ($expected in $Record.PackageFiles) {
        $path = Join-Path $Root $expected.RelativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Installed file is missing: $($expected.RelativePath)" }
        $item = Get-Item -LiteralPath $path
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ([int64] $item.Length -ne [int64] $expected.Size -or $hash -ne ([string] $expected.Sha256).ToUpperInvariant()) {
            throw "Installed file hash or size mismatch: $($expected.RelativePath)"
        }
    }
}

$record = $null
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Native forensic tools require native Windows.' }
    $record = Get-CurrentToolRecord -LiteralPath $CatalogPath
    if ($Mode -eq 'Plan') {
        if ($record.ReviewState -ne 'Approved') {
            $result = New-ToolStateResult -State 'Unapproved' -ModeName $Mode -Record $record -Operations @('validate-approved-record', 'validate-release-package', 'extract-allowlisted-files', 'commit-versioned-install') -Failure ([pscustomobject]@{ code = 'record-not-approved'; message = "Record is $($record.ReviewState), not Approved." })
        }
        else {
            Assert-InstallableRecord -Record $record
            $result = New-ToolStateResult -State 'Planned' -ModeName $Mode -Record $record -Operations @('validate-approved-record', 'validate-release-package', 'verify-attestation', 'extract-allowlisted-files', 'verify-installed-files', 'commit-versioned-install')
        }
    }
    elseif ($Mode -eq 'Test') {
        if ($record.ReviewState -eq 'Approved') { Assert-InstallableRecord -Record $record }
        $result = New-ToolStateResult -State (Get-InstalledToolState -Record $record) -ModeName $Mode -Record $record
    }
    else {
        Assert-InstallableRecord -Record $record
        $installRoot = [Environment]::ExpandEnvironmentVariables([string] $record.InstallRoot)
        $installParent = Split-Path -Parent $installRoot
        [void] (New-Item -ItemType Directory -Path $installParent -Force)
        $downloadedPackage = $false
        if ([string]::IsNullOrWhiteSpace($PackagePath)) {
            $PackagePath = Join-Path ([IO.Path]::GetTempPath()) ("dws-forensic-package-$([guid]::NewGuid().ToString('N')).zip")
            if ($null -ne $DownloadProvider) { & $DownloadProvider $record.ReleaseIdentity.AssetUrl $PackagePath }
            else { Invoke-WebRequest -Uri $record.ReleaseIdentity.AssetUrl -OutFile $PackagePath -UseBasicParsing }
            $downloadedPackage = $true
        }
        $packageItem = Get-Item -LiteralPath $PackagePath -ErrorAction Stop
        if ([int64] $packageItem.Length -ne [int64] $record.ReleaseIdentity.AssetSize) { throw 'Release package size mismatch.' }
        if ((Get-FileHash -LiteralPath $packageItem.FullName -Algorithm SHA256).Hash -ne ([string] $record.ReleaseIdentity.PackageSha256).ToUpperInvariant()) { throw 'Release package SHA-256 mismatch.' }
        if ($null -ne $AttestationVerifier) {
            if (-not (& $AttestationVerifier $packageItem.FullName $record)) { throw 'Release package attestation verification failed.' }
        }
        elseif (-not [string]::IsNullOrWhiteSpace([string] $record.ReleaseIdentity.AttestationIdentity)) {
            $gh = Get-Command gh.exe -CommandType Application -ErrorAction Stop
            & $gh.Source attestation verify $packageItem.FullName --repo $record.ReleaseIdentity.Repository | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'GitHub release package attestation verification failed.' }
        }

        $leaf = Split-Path -Leaf $installRoot
        $staging = Join-Path $installParent ("$leaf.staging-$([guid]::NewGuid().ToString('N'))")
        $rollback = Join-Path $installParent ("$leaf.rollback-$([guid]::NewGuid().ToString('N'))")
        [void] (New-Item -ItemType Directory -Path $staging)
        $movedOld = $false
        try {
            Expand-ValidatedArchive -LiteralPath $packageItem.FullName -Record $record -Destination $staging
            Assert-InstalledFiles -Record $record -Root $staging
            if (Test-Path -LiteralPath $installRoot) { [IO.Directory]::Move($installRoot, $rollback); $movedOld = $true }
            [IO.Directory]::Move($staging, $installRoot)
            if ($null -ne $InstallFaultProvider) { & $InstallFaultProvider 'AfterCommitBeforeValidation' $installRoot }
            if ((Get-InstalledToolState -Record $record) -ne 'Compliant') { throw 'Installed forensic tool did not test compliant after atomic commit.' }
            if ($movedOld -and (Test-Path -LiteralPath $rollback)) { Remove-Item -LiteralPath $rollback -Recurse -Force }
        }
        catch {
            if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction Ignore }
            if ($movedOld -and (Test-Path -LiteralPath $rollback)) {
                if (Test-Path -LiteralPath $installRoot) { Remove-Item -LiteralPath $installRoot -Recurse -Force -ErrorAction Ignore }
                [IO.Directory]::Move($rollback, $installRoot)
            }
            throw
        }
        finally {
            if ($downloadedPackage -and (Test-Path -LiteralPath $PackagePath)) { Remove-Item -LiteralPath $PackagePath -Force -ErrorAction Ignore }
        }
        $result = New-ToolStateResult -State 'Compliant' -ModeName $Mode -Record $record -Operations @('validated-release-package', 'verified-attestation', 'extracted-allowlisted-files', 'verified-installed-files', 'committed-versioned-install')
    }
}
catch {
    $state = if ($null -eq $record -or $record.ReviewState -ne 'Approved') { 'Unapproved' } else { Get-InstalledToolState -Record $record }
    $result = New-ToolStateResult -State $state -ModeName $Mode -Record $record -Failure ([pscustomobject]@{ code = 'forensic-tool-state-failed'; message = $_.Exception.Message })
}

if ($PassThru) { $result }
elseif ($Json) { $result | ConvertTo-Json -Depth 10 -Compress }
else {
    "Native forensic tools: $($result.state)"
    if ($result.installRoot) { "Install root: $($result.installRoot)" }
    if ($result.failure) { "Detail: $($result.failure.message)" }
}

if (-not $PassThru -and $MyInvocation.InvocationName -ne '.') {
    if ($Mode -eq 'Plan' -or $result.state -eq 'Compliant') { exit 0 }
    exit 1
}
