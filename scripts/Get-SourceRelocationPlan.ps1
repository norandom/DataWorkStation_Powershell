[CmdletBinding()]
param(
    [string] $Source,
    [string] $Target,
    [switch] $Json,
    [string] $ConfigurationPath = (Join-Path $PSScriptRoot '..\config\quant-research.psd1')
)

$ErrorActionPreference = 'Stop'

function Expand-RelocationPath {
    param([string] $Value)
    [regex]::Replace($Value, '%([^%]+)%', [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $resolved = [Environment]::GetEnvironmentVariable($match.Groups[1].Value)
        if ([string]::IsNullOrWhiteSpace($resolved)) { throw "Missing environment variable: $($match.Groups[1].Value)" }
        $resolved
    })
}

function Get-VolumeRecord {
    param([string] $Path)

    $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    $drive = $root.TrimEnd('\')
    $letter = $drive.TrimEnd(':')
    $volume = Get-Volume -DriveLetter $letter -ErrorAction Ignore
    $logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'" -ErrorAction Ignore
    [pscustomobject]@{
        drive = $drive
        driveType = if ($logical) { [int] $logical.DriveType } else { $null }
        local = [bool] ($logical -and [int] $logical.DriveType -eq 3)
        fileSystem = if ($volume) { [string] $volume.FileSystem } elseif ($logical) { [string] $logical.FileSystem } else { $null }
        health = if ($volume) { [string] $volume.HealthStatus } else { $null }
        sizeBytes = if ($volume) { [long] $volume.Size } elseif ($logical) { [long] $logical.Size } else { $null }
        freeBytes = if ($volume) { [long] $volume.SizeRemaining } elseif ($logical) { [long] $logical.FreeSpace } else { $null }
    }
}

function Test-PathNested {
    param([string] $Parent, [string] $Candidate)
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
    $candidateFull = [IO.Path]::GetFullPath($Candidate)
    $candidateFull -eq $parentFull -or $candidateFull.StartsWith($parentFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Get-RepositoryRecord {
    param([string] $RepositoryPath, [string] $SourcePath)

    $relative = [IO.Path]::GetRelativePath($SourcePath, $RepositoryPath)
    $headText = @(& git --no-optional-locks -C $RepositoryPath rev-parse HEAD 2>$null)
    $headExit = $LASTEXITCODE
    $statusText = @(& git --no-optional-locks -C $RepositoryPath status --porcelain=v2 --branch 2>$null) -join "`n"
    $statusExit = $LASTEXITCODE
    $statusDigest = if ($statusExit -eq 0) {
        $bytes = [Text.Encoding]::UTF8.GetBytes($statusText)
        [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    } else { $null }
    [pscustomobject]@{
        relativePath = $relative
        head = if ($headExit -eq 0 -and $headText.Count -gt 0) { [string] $headText[0] } else { $null }
        statusDigest = $statusDigest
        fsckPlanned = $true
    }
}

function Get-PlanFingerprint {
    param([object] $Value)
    $json = $Value | ConvertTo-Json -Depth 10 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Write-RelocationResult {
    param([object] $Result, [switch] $AsJson)
    if ($AsJson) { $Result | ConvertTo-Json -Depth 12 -Compress; return }
    Write-Host 'Source relocation plan (observational only)'
    Write-Host "Source: $($Result.sourcePath)"
    Write-Host "Target: $($Result.targetPath)"
    Write-Host "Capacity suitable: $($Result.capacitySuitable)"
    Write-Host "Execution available: $($Result.executionAvailable)"
    if ($Result.blockers.Count -gt 0) {
        Write-Host 'Blockers:'
        $Result.blockers | ForEach-Object { Write-Host "- $_" }
    }
    Write-Host "Future dry-run copy preview: $($Result.copyCommandPreview)"
}

$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
$relocation = $configuration.Relocation
if ($relocation.ExecutionEnabled) { throw 'This feature supports relocation planning only; ExecutionEnabled must remain false.' }
$sourcePath = [IO.Path]::GetFullPath((Expand-RelocationPath $(if ($Source) { $Source } else { [string] $relocation.Source })))
$targetPath = [IO.Path]::GetFullPath((Expand-RelocationPath $(if ($Target) { $Target } else { [string] $relocation.Target })))
$backupPath = Join-Path (Split-Path -Parent $sourcePath) ((Split-Path -Leaf $sourcePath) + '.pre-junction-backup')
$sourceExists = Test-Path -LiteralPath $sourcePath -PathType Container
$sourceItem = if ($sourceExists) { Get-Item -LiteralPath $sourcePath -Force } else { $null }
$sourceIsReparsePoint = [bool] ($sourceItem -and ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint))
$targetExists = Test-Path -LiteralPath $targetPath
$backupConflict = Test-Path -LiteralPath $backupPath
$sourceVolume = Get-VolumeRecord $sourcePath
$targetVolume = Get-VolumeRecord $targetPath
$reserveBytes = [long] $relocation.ReserveBytes

$reparsePoints = @()
$encryptedFiles = @()
$generatedEnvironments = @()
$repositories = @()
$sourceLogicalBytes = [long] 0
if ($sourceExists) {
    $allItems = @(Get-ChildItem -LiteralPath $sourcePath -Force -Recurse -ErrorAction Stop | Sort-Object FullName)
    $regularFiles = @($allItems | Where-Object { -not $_.PSIsContainer -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
    $sourceLogicalBytes = [long] (($regularFiles | Measure-Object Length -Sum).Sum)
    $reparsePoints = @($allItems | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | ForEach-Object {
        [pscustomobject]@{
            path = $_.FullName
            type = if ($_.PSObject.Properties.Name -contains 'LinkType') { [string] $_.LinkType } else { $null }
            target = if ($_.PSObject.Properties.Name -contains 'Target') { [string] ($_.Target -join ';') } else { $null }
            disposition = 'block'
            blocker = $true
        }
    })
    $encryptedFiles = @($regularFiles | Where-Object { $_.Attributes -band [IO.FileAttributes]::Encrypted } | Select-Object -ExpandProperty FullName)
    $generatedEnvironments = @($allItems | Where-Object {
        $_.PSIsContainer -and $_.Name -eq [string] $configuration.EnvironmentName -and
        (Test-Path -LiteralPath (Join-Path $_.Parent.FullName 'pyproject.toml') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $_.Parent.FullName 'uv.lock') -PathType Leaf)
    } | ForEach-Object {
        [pscustomobject]@{
            projectPath = $_.Parent.FullName
            environmentPath = $_.FullName
            lockPath = Join-Path $_.Parent.FullName 'uv.lock'
            excludeFromCopy = $true
        }
    })
    $gitRoots = @($sourcePath)
    $gitRoots += @($allItems | Where-Object { $_.PSIsContainer -and $_.Name -eq '.git' } | ForEach-Object { $_.Parent.FullName })
    $repositories = @($gitRoots | Select-Object -Unique | Where-Object {
        Test-Path -LiteralPath (Join-Path $_ '.git')
    } | ForEach-Object { Get-RepositoryRecord $_ $sourcePath })
}

$targetFreeBytes = if ($null -ne $targetVolume.freeBytes) { [long] $targetVolume.freeBytes } else { [long] 0 }
$capacitySuitable = $targetFreeBytes -ge ($sourceLogicalBytes + $reserveBytes)
$blockers = [Collections.Generic.List[string]]::new()
if (-not $sourceExists) { $blockers.Add("Source directory does not exist: $sourcePath") }
if ($sourceIsReparsePoint) { $blockers.Add('Source is already a reparse point.') }
if (Test-PathNested $sourcePath $targetPath -or Test-PathNested $targetPath $sourcePath) { $blockers.Add('Source and target must not be equal or nested.') }
if ($targetExists) { $blockers.Add("Target already exists: $targetPath") }
if ($backupConflict) { $blockers.Add("Backup candidate already exists: $backupPath") }
if (-not $targetVolume.local -or $targetVolume.driveType -ne 3) { $blockers.Add('Target is not a local fixed DriveType 3 volume.') }
if ($targetVolume.fileSystem -ne [string] $relocation.ExpectedFileSystem) { $blockers.Add("Target file system is not $($relocation.ExpectedFileSystem).") }
if ($targetVolume.health -and $targetVolume.health -ne 'Healthy') { $blockers.Add("Target volume health is $($targetVolume.health).") }
if (-not $capacitySuitable) { $blockers.Add('Target free capacity is below source bytes plus reserve.') }
if ($reparsePoints.Count -gt 0) { $blockers.Add('Source contains ReparsePoint entries that require explicit disposition.') }
if ($encryptedFiles.Count -gt 0) { $blockers.Add('Source contains Encrypted files that require a separate EFS procedure.') }

$activeUseRisks = @(
    'Close Jupyter servers, IDEs, terminals, Git clients, and background jobs using Source before any future preparation.',
    'Run any future commit command from outside both source and target trees; never terminate processes or close handles automatically.'
)
$environmentExcludes = @($generatedEnvironments | ForEach-Object { ' /XD "' + $_.environmentPath + '"' }) -join ''
$copyCommandPreview = "robocopy `"$sourcePath`" `"$targetPath`" /E /Z /COPY:DATS /DCOPY:DAT /XJ /SL /R:2 /W:2 /MT:16 /L$environmentExcludes"
$verificationSteps = @(
    'Quiesce applications, repeat the non-purging copy to convergence, and invalidate approval on any source change.',
    'Require a Robocopy /MIR /L audit exit 0 and compare relative path, length, SHA-256, empty directory, and approved link manifests.',
    'Compare Git status snapshots and run git fsck --full for every destination repository.'
)
$rollbackSteps = @(
    'Before any future cutover, retain the readable original under the declared backup path.',
    'If junction verification fails, remove only the exact expected junction and restore the backup name; retain the destination.'
)
$rebuildSteps = @(
    'Do not copy project .venv directories; preserve every pyproject.toml and uv.lock.',
    'After a separately approved cutover, run uv lock --check and explicit Reinitialize -Project All, then verify relative bases, imports, OpenBB metadata, notebooks, and global kernels.'
)
$warnings = @('This is a plan-only report. It does not authorize or execute relocation.')
$fingerprintInput = [ordered]@{
    sourcePath = $sourcePath; targetPath = $targetPath; backupPath = $backupPath
    sourceLogicalBytes = $sourceLogicalBytes; targetFreeBytes = $targetFreeBytes; reserveBytes = $reserveBytes
    reparsePoints = $reparsePoints; encryptedFiles = $encryptedFiles; generatedEnvironments = $generatedEnvironments
    repositories = $repositories; blockers = @($blockers)
}
$result = [pscustomobject]@{
    schemaVersion = 1
    planOnly = $true
    executionAvailable = $false
    authorized = $false
    mutationPerformed = $false
    sourcePath = $sourcePath
    targetPath = $targetPath
    backupPath = $backupPath
    sourceExists = $sourceExists
    sourceIsReparsePoint = $sourceIsReparsePoint
    targetExists = $targetExists
    backupConflict = $backupConflict
    sourceVolume = $sourceVolume
    targetVolume = $targetVolume
    sourceLogicalBytes = $sourceLogicalBytes
    targetFreeBytes = $targetFreeBytes
    requiredReserveBytes = $reserveBytes
    capacitySuitable = $capacitySuitable
    reparsePoints = @($reparsePoints)
    encryptedFiles = @($encryptedFiles)
    generatedEnvironments = @($generatedEnvironments)
    repositories = @($repositories)
    activeUseRisks = $activeUseRisks
    copyCommandPreview = $copyCommandPreview
    verificationSteps = $verificationSteps
    rollbackSteps = $rollbackSteps
    rebuildSteps = $rebuildSteps
    blockers = @($blockers)
    warnings = $warnings
    planFingerprint = Get-PlanFingerprint $fingerprintInput
    commitRequiresFreshVerification = $true
}
Write-RelocationResult $result -AsJson:$Json
if ($blockers.Count -gt 0) { exit 1 }
