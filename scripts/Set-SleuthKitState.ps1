[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [string] $PackagePath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\sleuthkit.psd1')
$package = $configuration.Package
$installRoot = [Environment]::ExpandEnvironmentVariables($package.InstallRoot)
$binPath = Join-Path $installRoot $package.BinDirectory
$versionCommand = Join-Path $binPath 'mmls.exe'

function Get-UserPathEntries {
    $value = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $value) { return @() }
    @($value -split ';' | Where-Object { $_ })
}

function Test-PathEntry {
    param([string] $Path)
    @((Get-UserPathEntries) | Where-Object { $_.TrimEnd('\') -ieq $Path.TrimEnd('\') }).Count -gt 0
}

function Get-InstalledTreeIdentity {
    if (-not (Test-Path -LiteralPath $installRoot -PathType Container)) {
        return [pscustomobject]@{ FileCount = 0; Sha256 = '' }
    }
    $records = @(Get-ChildItem -LiteralPath $installRoot -Recurse -File | Sort-Object {
        $_.FullName.Substring($installRoot.Length).TrimStart('\').ToLowerInvariant()
    } | ForEach-Object {
        $relativePath = $_.FullName.Substring($installRoot.Length).TrimStart('\').Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        "$relativePath|$($_.Length)|$hash`n"
    })
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = [BitConverter]::ToString($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes(($records -join '')))).Replace('-', '')
    } finally { $sha256.Dispose() }
    [pscustomobject]@{ FileCount = $records.Count; Sha256 = $digest }
}

function Get-SleuthKitState {
    $missing = @($configuration.Commands | Where-Object { -not (Test-Path -LiteralPath (Join-Path $binPath "$_.exe") -PathType Leaf) })
    $version = ''
    if ($missing.Count -eq 0) {
        $output = & $versionCommand -V 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $output -match '4\.15\.0') { $version = '4.15.0' }
    }
    $tree = Get-InstalledTreeIdentity
    [pscustomobject]@{
        Version = $version
        DesiredVersion = $package.Version
        InstallRoot = $installRoot
        BinPath = $binPath
        MissingCommands = $missing
        InstalledFileCount = $tree.FileCount
        InstalledTreeSha256 = $tree.Sha256
        TreeCompliant = $tree.FileCount -eq $package.InstalledFileCount -and $tree.Sha256 -eq $package.InstalledTreeSha256
        PathConfigured = Test-PathEntry -Path $binPath
        Compliant = $version -eq $package.Version -and $missing.Count -eq 0 -and
            $tree.FileCount -eq $package.InstalledFileCount -and $tree.Sha256 -eq $package.InstalledTreeSha256 -and
            (Test-PathEntry -Path $binPath)
    }
}

function Write-SleuthKitState {
    param($State)
    @(
        [pscustomobject]@{ Resource = 'SleuthKitCli'; State = if ($State.Version -eq $State.DesiredVersion) { 'compliant' } else { 'drift detected' }; Detail = "$($State.Version) installed; $($State.DesiredVersion) required" }
        [pscustomobject]@{ Resource = 'SleuthKitCommands'; State = if ($State.MissingCommands.Count -eq 0) { 'complete' } else { 'drift detected' }; Detail = if ($State.MissingCommands.Count) { $State.MissingCommands -join ', ' } else { "$($configuration.Commands.Count) commands" } }
        [pscustomobject]@{ Resource = 'SleuthKitTree'; State = if ($State.TreeCompliant) { 'verified' } else { 'drift detected' }; Detail = "$($State.InstalledFileCount) files; SHA-256 $($State.InstalledTreeSha256)" }
        [pscustomobject]@{ Resource = 'SleuthKitPath'; State = if ($State.PathConfigured) { 'compliant' } else { 'drift detected' }; Detail = $State.BinPath }
    ) | Format-Table -AutoSize -Wrap
}

function Test-PackageIdentity {
    param([string] $Path)
    if ((Get-Item -LiteralPath $Path).Length -ne [long] $package.Size) { throw 'Sleuth Kit archive size does not match the catalog.' }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($hash -ine $package.Sha256) { throw "Sleuth Kit archive SHA-256 mismatch: $hash" }
}

$state = Get-SleuthKitState
if ($Mode -eq 'Test') {
    Write-SleuthKitState $state
    if (-not $state.Compliant) { exit 1 }
    exit 0
}

if ($Mode -eq 'Reinitialize' -and (Test-Path -LiteralPath $installRoot)) {
    Remove-Item -LiteralPath $installRoot -Recurse -Force
    $state = Get-SleuthKitState
}

if ($state.Version -ne $package.Version -or $state.MissingCommands.Count -gt 0 -or -not $state.TreeCompliant) {
    $downloaded = $false
    if (-not $PackagePath) {
        $PackagePath = Join-Path ([IO.Path]::GetTempPath()) "sleuthkit-$($package.Version)-$([guid]::NewGuid().ToString('N')).zip"
        Invoke-WebRequest -Uri $package.Uri -OutFile $PackagePath -UseBasicParsing
        $downloaded = $true
    }
    $stageRoot = Join-Path ([IO.Path]::GetTempPath()) "dws-sleuthkit-$([guid]::NewGuid().ToString('N'))"
    try {
        Test-PackageIdentity -Path $PackagePath
        Expand-Archive -LiteralPath $PackagePath -DestinationPath $stageRoot
        $sourceRoot = Join-Path $stageRoot $package.ArchiveRoot
        if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot 'bin\mmls.exe') -PathType Leaf)) { throw 'Sleuth Kit archive layout is unexpected.' }
        if (Test-Path -LiteralPath $installRoot) { Remove-Item -LiteralPath $installRoot -Recurse -Force }
        New-Item -ItemType Directory -Path (Split-Path -Parent $installRoot) -Force | Out-Null
        Move-Item -LiteralPath $sourceRoot -Destination $installRoot
    } finally {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
        if ($downloaded) { Remove-Item -LiteralPath $PackagePath -Force -ErrorAction SilentlyContinue }
    }
}

if (-not (Test-PathEntry -Path $binPath)) {
    $entries = @(Get-UserPathEntries) + $binPath
    [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
    $env:Path = "$env:Path;$binPath"
}

$result = Get-SleuthKitState
Write-SleuthKitState $result
if (-not $result.Compliant) { throw 'Sleuth Kit CLI state did not converge.' }
