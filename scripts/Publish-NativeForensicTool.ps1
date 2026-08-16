#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string] $CatalogPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $RecordId,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $BuildRecord,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $PackagePath,
    [switch] $Publish,
    [switch] $ConfirmPublication,
    [switch] $Json,
    [Parameter(DontShow = $true)][switch] $PassThru,
    [Parameter(DontShow = $true)][scriptblock] $GitRunner,
    [Parameter(DontShow = $true)][scriptblock] $GitHubRunner,
    [Parameter(DontShow = $true)][scriptblock] $CandidateValidator,
    [Parameter(DontShow = $true)][string] $RepositoryPath
)

$ErrorActionPreference = 'Stop'
$null = $GitRunner, $GitHubRunner # consumed by nested command boundaries
$repositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryPath)) { Split-Path -Parent $PSScriptRoot } else { [IO.Path]::GetFullPath($RepositoryPath) }
if ([string]::IsNullOrWhiteSpace($CatalogPath)) { $CatalogPath = Join-Path $repositoryRoot 'config\forensic-tools.psd1' }

function Invoke-GitRead {
    param([string[]] $Arguments)
    if ($null -ne $GitRunner) { return @(& $GitRunner $Arguments) }
    $output = @(& git.exe -C $repositoryRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "git failed: git $($Arguments -join ' ') :: $($output -join ' ')" }
    $output
}

function Invoke-GitHubCommand {
    param([string[]] $Arguments)
    if ($null -ne $GitHubRunner) { return @(& $GitHubRunner $Arguments) }
    $output = @(& gh.exe @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "gh failed: gh $($Arguments -join ' ') :: $($output -join ' ')" }
    $output
}

function Get-CatalogContainingCommit {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)

    $catalogFullPath = [IO.Path]::GetFullPath($LiteralPath)
    $repositoryFullPath = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\')
    if (-not $catalogFullPath.StartsWith($repositoryFullPath + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Catalog must be inside the repository.' }
    $status = @(Invoke-GitRead -Arguments @('status', '--porcelain'))
    if ($status.Count -gt 0) { throw 'Publish requires a clean Git checkout; commit or remove every change first.' }
    $relativePath = $catalogFullPath.Substring($repositoryFullPath.Length + 1).Replace('\', '/')
    [void] (Invoke-GitRead -Arguments @('ls-files', '--error-unmatch', '--', $relativePath))
    $commit = (@(Invoke-GitRead -Arguments @('log', '-n', '1', '--format=%H', '--', $relativePath)) | Select-Object -First 1).ToString().Trim()
    if ($commit -notmatch '^[0-9a-f]{40}$') { throw 'Unable to resolve the commit containing the catalog.' }
    $workingBlob = (@(Invoke-GitRead -Arguments @('hash-object', '--', $relativePath)) | Select-Object -First 1).ToString().Trim()
    $committedBlob = (@(Invoke-GitRead -Arguments @('rev-parse', "$commit`:$relativePath")) | Select-Object -First 1).ToString().Trim()
    if ($workingBlob -ne $committedBlob) { throw 'The exact catalog bytes do not match their containing commit.' }
    [pscustomobject]@{
        ContainingCommit = $commit
        CatalogFileSha256 = (Get-FileHash -LiteralPath $catalogFullPath -Algorithm SHA256).Hash.ToUpperInvariant()
        RelativePath = $relativePath
    }
}

function Assert-ApprovedRecord {
    param($Catalog, [string] $Identity, $Build)
    $records = @($Catalog.Records | Where-Object RecordId -eq $Identity)
    if ($records.Count -ne 1) { throw "Expected one catalog record named '$Identity'." }
    $record = $records[0]
    if ($record.ReviewState -ne 'Approved') { throw "Record '$Identity' is not Approved; candidate review must be committed first." }
    if ($record.ToolId -ne $Build.ToolId -or $record.UpstreamVersion -ne $Build.UpstreamVersion -or $record.BuildRevision -ne $Build.BuildRevision) {
        throw 'Approved catalog identity differs from the reviewed build record.'
    }
    $buildRecordSha256 = (Get-FileHash -LiteralPath ([IO.Path]::GetFullPath($BuildRecord)) -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($record.BuildIdentity.BuildRecordSha256 -ne $buildRecordSha256) {
        throw 'Build record changed without a distinct approved BuildRevision; create a new build revision.'
    }
    foreach ($historical in @($Catalog.Records | Where-Object { $_.ReviewState -in @('Superseded', 'Withdrawn') })) {
        if ([string]::IsNullOrWhiteSpace([string] $historical.ReleaseIdentity.Tag) -or [string]::IsNullOrWhiteSpace([string] $historical.ReleaseIdentity.PackageSha256)) {
            throw "Historical record '$($historical.RecordId)' lost immutable release attribution."
        }
    }
    $record
}

$notesPath = $null
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Native forensic publication must run on Windows.' }
    $catalogFullPath = [IO.Path]::GetFullPath($CatalogPath)
    $package = Get-Item -LiteralPath ([IO.Path]::GetFullPath($PackagePath)) -ErrorAction Stop
    $buildRecordFullPath = [IO.Path]::GetFullPath($BuildRecord)
    $catalog = Import-PowerShellDataFile -LiteralPath $catalogFullPath
    $build = Import-PowerShellDataFile -LiteralPath $buildRecordFullPath
    $trust = Get-CatalogContainingCommit -LiteralPath $catalogFullPath
    $record = Assert-ApprovedRecord -Catalog $catalog -Identity $RecordId -Build $build

    if ([int64] $package.Length -ne [int64] $record.ReleaseIdentity.AssetSize) { throw 'Draft asset size differs from the approved catalog.' }
    $packageSha256 = (Get-FileHash -LiteralPath $package.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($packageSha256 -ne [string] $record.ReleaseIdentity.PackageSha256) { throw 'Draft asset SHA-256 differs from the approved catalog.' }

    if ($null -ne $CandidateValidator) { $candidateResult = & $CandidateValidator $package.FullName $buildRecordFullPath }
    else { $candidateResult = . (Join-Path $PSScriptRoot 'Test-ForensicReleaseCandidate.ps1') -PackagePath $package.FullName -BuildRecord $buildRecordFullPath -PassThru }
    if ($candidateResult.status -ne 'Passed') { throw "Candidate validation failed: $($candidateResult.failure.message)" }

    [void] (Invoke-GitHubCommand -Arguments @('attestation', 'verify', $package.FullName, '--repo', [string] $record.ReleaseIdentity.Repository))
    $release = ((Invoke-GitHubCommand -Arguments @('release', 'view', [string] $record.ReleaseIdentity.Tag, '--repo', [string] $record.ReleaseIdentity.Repository, '--json', 'isDraft,tagName,assets')) -join "`n") | ConvertFrom-Json
    if (-not $release.isDraft) { throw 'The approved candidate release is not a draft.' }
    $assets = @($release.assets | Where-Object name -eq $record.ReleaseIdentity.AssetName)
    if ($assets.Count -ne 1) { throw 'The draft does not contain exactly one approved asset.' }
    if ($assets[0].PSObject.Properties.Name -contains 'size' -and [int64] $assets[0].size -ne [int64] $record.ReleaseIdentity.AssetSize) { throw 'The draft asset size differs from the approved catalog.' }

    $result = [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        action = if ($Publish) { 'Publish' } else { 'Plan' }
        status = 'Ready'
        recordId = [string] $record.RecordId
        buildRevision = [string] $record.BuildRevision
        releaseTag = [string] $record.ReleaseIdentity.Tag
        assetName = [string] $record.ReleaseIdentity.AssetName
        packageSha256 = $packageSha256
        CatalogFileSha256 = $trust.CatalogFileSha256
        ContainingCommit = $trust.ContainingCommit
        published = $false
        failure = $null
    }

    if ($Publish) {
        if (-not $ConfirmPublication) { throw 'Publish requires -ConfirmPublication after review of the plan.' }
        if (-not $PSCmdlet.ShouldProcess($record.ReleaseIdentity.Tag, 'Publish immutable native forensic release')) { throw 'Publication was not confirmed.' }
        $notesPath = Join-Path ([IO.Path]::GetTempPath()) ("dws-forensic-release-notes-$([guid]::NewGuid().ToString('N')).md")
        $notes = @"
Native Windows forensic verifier package.

Catalog file SHA-256: $($trust.CatalogFileSha256)
Catalog containing commit: $($trust.ContainingCommit)
Package SHA-256: $packageSha256
Build revision: $($record.BuildRevision)
"@
        [IO.File]::WriteAllText($notesPath, $notes, [Text.UTF8Encoding]::new($false))
        [void] (Invoke-GitHubCommand -Arguments @('release', 'edit', [string] $record.ReleaseIdentity.Tag, '--repo', [string] $record.ReleaseIdentity.Repository, '--notes-file', $notesPath))
        [void] (Invoke-GitHubCommand -Arguments @('release', 'edit', [string] $record.ReleaseIdentity.Tag, '--repo', [string] $record.ReleaseIdentity.Repository, '--draft=false'))
        $publishedRelease = ((Invoke-GitHubCommand -Arguments @('release', 'view', [string] $record.ReleaseIdentity.Tag, '--repo', [string] $record.ReleaseIdentity.Repository, '--json', 'isDraft,tagName,assets')) -join "`n") | ConvertFrom-Json
        if ($publishedRelease.isDraft -or @($publishedRelease.assets | Where-Object name -eq $record.ReleaseIdentity.AssetName).Count -ne 1) { throw 'Published release verification failed.' }
        $result.status = 'Published'
        $result.published = $true
    }
}
catch {
    $result = [pscustomobject][ordered]@{
        schemaVersion = '1.0'; action = if ($Publish) { 'Publish' } else { 'Plan' }; status = 'Failed'; recordId = $RecordId
        buildRevision = $null; releaseTag = $null; assetName = $null; packageSha256 = $null; CatalogFileSha256 = $null
        ContainingCommit = $null; published = $false; failure = [pscustomobject]@{ code = 'forensic-publication-failed'; message = $_.Exception.Message }
    }
}
finally { if ($null -ne $notesPath -and (Test-Path -LiteralPath $notesPath)) { Remove-Item -LiteralPath $notesPath -Force -ErrorAction Ignore } }

if ($PassThru) { $result }
elseif ($Json) { $result | ConvertTo-Json -Depth 8 -Compress }
else {
    "Native forensic release: $($result.status)"
    if ($result.releaseTag) { "Release: $($result.releaseTag)" }
    if ($result.CatalogFileSha256) { "Catalog SHA-256: $($result.CatalogFileSha256)" }
    if ($result.ContainingCommit) { "Catalog commit: $($result.ContainingCommit)" }
    if (-not $Publish -and $result.status -eq 'Ready') { 'No release was published. Rerun with -Publish -ConfirmPublication after review.' }
    if ($result.failure) { "Detail: $($result.failure.message)" }
}
if (-not $PassThru -and $MyInvocation.InvocationName -ne '.' -and $result.status -eq 'Failed') { exit 1 }
