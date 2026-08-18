[CmdletBinding()]
param(
    [string] $Source = 'C:\Users\mariu\Source',
    [string] $Target = 'D:\Source',
    [string] $Backup = 'C:\Users\mariu\Source.pre-junction-20260816-182952',
    [string] $ExpectedFingerprint = '81aaf48aed879eadbcc7749aba42ddffd4b021290ccdd154e59a46e7d3300040',
    [switch] $ConfirmCutover
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedPath {
    param([Parameter(Mandatory)][string] $Path)

    [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Test-NestedPath {
    param(
        [Parameter(Mandatory)][string] $Parent,
        [Parameter(Mandatory)][string] $Candidate
    )

    $parentPath = Get-NormalizedPath $Parent
    $candidatePath = Get-NormalizedPath $Candidate
    $candidatePath.Equals($parentPath, [StringComparison]::OrdinalIgnoreCase) -or
        $candidatePath.StartsWith($parentPath + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Test-ExcludedRelativePath {
    param(
        [Parameter(Mandatory)][string] $RelativePath,
        [Parameter(Mandatory)][string[]] $ExcludedPaths
    )

    foreach ($excludedPath in $ExcludedPaths) {
        if ($RelativePath.Equals($excludedPath, [StringComparison]::OrdinalIgnoreCase) -or
            $RelativePath.StartsWith($excludedPath + '\', [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-TreeFingerprint {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string[]] $ExcludedPaths
    )

    $manifest = [Text.StringBuilder]::new()
    $files = @(Get-ChildItem -LiteralPath $Root -Force -Recurse -File | ForEach-Object {
        $relativePath = [IO.Path]::GetRelativePath($Root, $_.FullName)
        if (-not (Test-ExcludedRelativePath -RelativePath $relativePath -ExcludedPaths $ExcludedPaths)) {
            [pscustomobject]@{
                RelativePath = $relativePath
                FullName = $_.FullName
                Length = [long] $_.Length
            }
        }
    } | Sort-Object RelativePath)

    foreach ($file in $files) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $null = $manifest.Append($file.RelativePath.Replace('\', '/')).
            Append('|').Append($file.Length).Append('|').Append($hash).Append("`n")
    }

    $manifestBytes = [Text.Encoding]::UTF8.GetBytes($manifest.ToString())
    [pscustomobject]@{
        FileCount = $files.Count
        Fingerprint = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($manifestBytes)
        ).ToLowerInvariant()
    }
}

if (-not $ConfirmCutover) {
    throw 'Cutover is state-changing. Re-run with -ConfirmCutover after closing every Source handle.'
}

$sourcePath = Get-NormalizedPath $Source
$targetPath = Get-NormalizedPath $Target
$backupPath = Get-NormalizedPath $Backup
$workingDirectory = Get-NormalizedPath (Get-Location).Path
$excludedRelativePaths = @(
    'PowerShell\.venv'
    'quant-research\projects\thesis\.venv'
    'quant-research\quant-base\.venv'
    'ragflow-claude-desktop-local-mcp\.venv'
    'spec-kit-ears-tdd\.venv'
    'watermarks-remover\.venv'
    'x_likes_scraper\.venv'
)

if ((Test-NestedPath -Parent $sourcePath -Candidate $workingDirectory) -or
    (Test-NestedPath -Parent $targetPath -Candidate $workingDirectory)) {
    throw "Run this script from outside both trees. Current directory: $workingDirectory"
}
if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
    throw "Source directory is missing: $sourcePath"
}
$sourceItem = Get-Item -LiteralPath $sourcePath -Force
if ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Source is already a reparse point.'
}
if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
    throw "Verified target directory is missing: $targetPath"
}
$targetItem = Get-Item -LiteralPath $targetPath -Force
if ($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Target must be a normal directory, not a reparse point.'
}
if (Test-Path -LiteralPath $backupPath) {
    throw "Backup path already exists: $backupPath"
}
if ((Split-Path -Parent $backupPath) -ne (Split-Path -Parent $sourcePath)) {
    throw 'Backup must be a same-volume rename beside Source.'
}
if ((Test-NestedPath -Parent $sourcePath -Candidate $targetPath) -or
    (Test-NestedPath -Parent $targetPath -Candidate $sourcePath)) {
    throw 'Source and target must not be equal or nested.'
}

$reparsePoints = @(Get-ChildItem -LiteralPath $sourcePath -Force -Recurse |
    Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
if ($reparsePoints.Count -gt 0) {
    throw "Source now contains $($reparsePoints.Count) reparse point(s); verification is stale."
}

$handleCommand = Get-Command handle.exe -ErrorAction SilentlyContinue
if (-not $handleCommand) {
    throw 'handle.exe is required to prove that Source has no live directory handles.'
}
$handleOutput = @(& $handleCommand.Source -nobanner $sourcePath 2>&1)
if ($handleOutput -match 'pid:\s*\d+') {
    $handleOutput | ForEach-Object { Write-Host $_ }
    throw 'Close every process listed above, then run the script again.'
}

$robocopyExcludes = @($excludedRelativePaths | ForEach-Object { Join-Path $sourcePath $_ })
$auditArguments = @(
    $sourcePath
    $targetPath
    '/MIR'
    '/L'
    '/COPY:DAT'
    '/DCOPY:DAT'
    '/XJ'
    '/SL'
    '/R:0'
    '/W:0'
)
foreach ($excludedPath in $robocopyExcludes) {
    $auditArguments += @('/XD', $excludedPath)
}

Write-Host 'Running the read-only Robocopy mirror audit...'
& robocopy.exe @auditArguments
if ($LASTEXITCODE -ne 0) {
    throw "Robocopy audit reported drift or an error (exit $LASTEXITCODE). Do not cut over."
}

Write-Host 'Recomputing source and target SHA-256 tree fingerprints...'
$sourceFingerprint = Get-TreeFingerprint -Root $sourcePath -ExcludedPaths $excludedRelativePaths
$targetFingerprint = Get-TreeFingerprint -Root $targetPath -ExcludedPaths $excludedRelativePaths
if ($sourceFingerprint.FileCount -ne $targetFingerprint.FileCount -or
    $sourceFingerprint.Fingerprint -ne $targetFingerprint.Fingerprint -or
    $sourceFingerprint.Fingerprint -ne $ExpectedFingerprint) {
    throw "Fingerprint verification failed. Source=$($sourceFingerprint.Fingerprint); Target=$($targetFingerprint.Fingerprint); Expected=$ExpectedFingerprint"
}

$renamed = $false
try {
    Rename-Item -LiteralPath $sourcePath -NewName (Split-Path -Leaf $backupPath)
    $renamed = $true

    if (Test-Path -LiteralPath $sourcePath) {
        throw 'Source still exists after the backup rename.'
    }
    if (-not (Test-Path -LiteralPath $backupPath -PathType Container)) {
        throw 'The renamed backup is not readable.'
    }

    $null = New-Item -ItemType Junction -Path $sourcePath -Target $targetPath
    $junction = Get-Item -LiteralPath $sourcePath -Force
    $junctionTarget = [string] ($junction.Target -join '')
    if ($junction.LinkType -ne 'Junction' -or
        (Get-NormalizedPath $junctionTarget) -ne $targetPath) {
        throw "Junction verification failed. Observed target: $junctionTarget"
    }

    foreach ($representativePath in @('PowerShell\README.md', 'quant-research')) {
        if (-not (Test-Path -LiteralPath (Join-Path $sourcePath $representativePath))) {
            throw "Representative path is unavailable through the junction: $representativePath"
        }
    }
}
catch {
    $cutoverError = $_
    if (Test-Path -LiteralPath $sourcePath) {
        $observedSource = Get-Item -LiteralPath $sourcePath -Force
        $observedTarget = [string] ($observedSource.Target -join '')
        if ($observedSource.LinkType -eq 'Junction' -and
            (Get-NormalizedPath $observedTarget) -eq $targetPath) {
            # This removes only the verified junction, never its D:\Source target.
            Remove-Item -LiteralPath $sourcePath -Force
        }
    }
    if ($renamed -and -not (Test-Path -LiteralPath $sourcePath) -and
        (Test-Path -LiteralPath $backupPath -PathType Container)) {
        Rename-Item -LiteralPath $backupPath -NewName (Split-Path -Leaf $sourcePath)
    }
    throw $cutoverError
}

[pscustomobject]@{
    CutoverSucceeded = $true
    SourcePath = $sourcePath
    LinkType = (Get-Item -LiteralPath $sourcePath -Force).LinkType
    JunctionTarget = [string] ((Get-Item -LiteralPath $sourcePath -Force).Target -join '')
    BackupPath = $backupPath
    BackupRetained = Test-Path -LiteralPath $backupPath -PathType Container
    VerifiedFileCount = $sourceFingerprint.FileCount
    Fingerprint = $sourceFingerprint.Fingerprint
    AclPolicy = 'Inherited D: permissions accepted by user'
}
