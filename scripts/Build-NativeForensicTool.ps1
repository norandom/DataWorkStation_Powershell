#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $BuildRecord,
    [string] $OutputDirectory,
    [switch] $Plan,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $repositoryRoot 'artifacts\forensic-tools' }

function Assert-FileIdentity {
    param([string] $LiteralPath, [int64] $Size, [string] $Sha256)
    $item = Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
    if ($item.Length -ne $Size) { throw "Size mismatch for $($item.Name)." }
    if ((Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash -ne $Sha256.ToUpperInvariant()) { throw "SHA-256 mismatch for $($item.Name)." }
}

function Invoke-CheckedNative {
    param([string] $Label, [string] $Executable, [string[]] $Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
}

function Write-Utf8NoBom {
    param([string] $LiteralPath, [string] $Content)
    [IO.File]::WriteAllText($LiteralPath, $Content, (New-Object Text.UTF8Encoding($false)))
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Forensic tool builds require native Windows.' }
$recordPath = [IO.Path]::GetFullPath($BuildRecord)
$record = Import-PowerShellDataFile -LiteralPath $recordPath
if ($record.Target.OperatingSystem -ne 'Windows' -or $record.Target.PeMachine -ne 'AMD64') { throw 'Build record target must be native Windows AMD64.' }
$requiredExecutable = 'ewfverify.exe'
if ($record.Package.AllowedRuntimeFiles -notcontains $requiredExecutable) { throw "Build record omits the required verifier: $requiredExecutable" }

$planResult = [pscustomobject]@{
    schemaVersion = '1.0'
    action = 'Build'
    status = 'planned'
    recordId = $record.RecordId
    outputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
    operations = @('download-and-hash-pinned-inputs', 'verify-detached-signature-with-isolated-gpgv', 'verify-vstools-commit', 'generate-vs2022-projects', 'build-ewfverify-x64-release', 'assemble-minimal-package', 'validate-pe-imports-and-package-contract')
    networkRequired = $true
    changesSystemState = $true
}
if ($Plan) {
    if ($Json) { $planResult | ConvertTo-Json -Depth 6 -Compress } else { $planResult; 'Plan only: no source, compiler, package, or release was changed.' }
    exit 0
}

$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("dws-forensic-build-$([guid]::NewGuid().ToString('N'))")
$downloadRoot = Join-Path $workRoot 'downloads'
$sourceRoot = Join-Path $workRoot 'src'
$packageRoot = Join-Path $workRoot 'package'
$gnupgRoot = Join-Path $workRoot 'gnupg'
$keyHome = Join-Path $workRoot 'keyring'
[void] (New-Item -ItemType Directory -Path $downloadRoot, $sourceRoot, $packageRoot, $keyHome -Force)
try {
    foreach ($artifact in $record.SourceArtifacts) {
        $destination = Join-Path $downloadRoot $artifact.FileName
        Invoke-WebRequest -Uri $artifact.Url -OutFile $destination -UseBasicParsing
        Assert-FileIdentity -LiteralPath $destination -Size $artifact.Size -Sha256 $artifact.Sha256
    }

    $gpgInstaller = Join-Path $downloadRoot $record.SignatureVerification.InstallerFileName
    Invoke-WebRequest -Uri $record.SignatureVerification.InstallerUrl -OutFile $gpgInstaller -UseBasicParsing
    Assert-FileIdentity -LiteralPath $gpgInstaller -Size $record.SignatureVerification.InstallerSize -Sha256 $record.SignatureVerification.InstallerSha256
    $signature = Get-AuthenticodeSignature -LiteralPath $gpgInstaller
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $record.SignatureVerification.AuthenticodeThumbprint) { throw 'Standalone GnuPG Authenticode identity mismatch.' }
    $installerArguments = @('/S', "/D=$gnupgRoot")
    $installerProcess = Start-Process -FilePath $gpgInstaller -ArgumentList $installerArguments -Wait -PassThru -WindowStyle Hidden
    if ($installerProcess.ExitCode -ne 0) { throw "Standalone GnuPG installer failed with exit code $($installerProcess.ExitCode)." }
    $gpg = Get-ChildItem -LiteralPath $gnupgRoot -Filter gpg.exe -File -Recurse | Select-Object -First 1
    $gpgv = Get-ChildItem -LiteralPath $gnupgRoot -Filter gpgv.exe -File -Recurse | Select-Object -First 1
    if ($null -eq $gpg -or $null -eq $gpgv) { throw 'Standalone GnuPG installation did not expose native gpg.exe and gpgv.exe.' }

    $keyPath = Join-Path (Split-Path -Parent $recordPath) $record.SignatureVerification.KeyFile
    $fingerprints = @(& $gpg.FullName --batch --with-colons --show-keys $keyPath | Where-Object { $_ -like 'fpr:*' } | ForEach-Object { ($_ -split ':')[9] })
    if ($fingerprints -notcontains $record.SignatureVerification.SignerFingerprint) { throw 'Reviewed libyal key fingerprint mismatch.' }
    Invoke-CheckedNative -Label 'isolated public-key import' -Executable $gpg.FullName -Arguments @('--batch', '--homedir', $keyHome, '--import', $keyPath)
    $sourceArchive = Join-Path $downloadRoot 'libewf-experimental-20231119.tar.gz'
    $sourceSignature = Join-Path $downloadRoot 'libewf-experimental-20231119.tar.gz.asc'
    Invoke-CheckedNative -Label 'libewf detached signature verification' -Executable $gpgv.FullName -Arguments @('--homedir', $keyHome, '--keyring', (Join-Path $keyHome 'pubring.kbx'), $sourceSignature, $sourceArchive)

    $tar = (Get-Command tar.exe -CommandType Application -ErrorAction Stop).Source
    Invoke-CheckedNative -Label 'libewf source extraction' -Executable $tar -Arguments @('-xf', $sourceArchive, '-C', $sourceRoot)
    Invoke-CheckedNative -Label 'bzip2 source extraction' -Executable $tar -Arguments @('-xf', (Join-Path $downloadRoot 'bzip2-1.0.8.tar.gz'), '-C', $sourceRoot)
    Expand-Archive -LiteralPath (Join-Path $downloadRoot 'zlib132.zip') -DestinationPath $sourceRoot
    $libewfRoot = Get-ChildItem -LiteralPath $sourceRoot -Directory -Filter 'libewf-*' | Select-Object -First 1
    $zlibRoot = Get-ChildItem -LiteralPath $sourceRoot -Directory -Filter 'zlib-*' | Select-Object -First 1
    $bzipRoot = Get-ChildItem -LiteralPath $sourceRoot -Directory -Filter 'bzip2-*' | Select-Object -First 1
    if ($null -eq $libewfRoot -or $null -eq $zlibRoot -or $null -eq $bzipRoot) { throw 'Pinned source extraction did not produce the expected sibling trees.' }
    Copy-Item -LiteralPath $zlibRoot.FullName -Destination (Join-Path $sourceRoot 'zlib') -Recurse
    Copy-Item -LiteralPath $bzipRoot.FullName -Destination (Join-Path $sourceRoot 'bzip2') -Recurse

    $vstoolsRoot = Join-Path $sourceRoot 'vstools-repository'
    Invoke-CheckedNative -Label 'vstools repository initialization' -Executable (Get-Command git.exe -ErrorAction Stop).Source -Arguments @('init', $vstoolsRoot)
    Invoke-CheckedNative -Label 'vstools pinned fetch' -Executable (Get-Command git.exe -ErrorAction Stop).Source -Arguments @('-C', $vstoolsRoot, 'fetch', '--depth', '1', $record.Converter.Repository, $record.Converter.Commit)
    Invoke-CheckedNative -Label 'vstools pinned checkout' -Executable (Get-Command git.exe -ErrorAction Stop).Source -Arguments @('-C', $vstoolsRoot, 'checkout', '--detach', 'FETCH_HEAD')
    $observedCommit = (& git.exe -C $vstoolsRoot rev-parse HEAD).Trim()
    if ($observedCommit -ne $record.Converter.Commit) { throw 'vstools checkout does not match the pinned full commit.' }
    $verification = gh.exe api "repos/libyal/vstools/commits/$($record.Converter.Commit)" --jq '.commit.verification.reason'
    if ($LASTEXITCODE -ne 0 -or $verification.Trim() -ne $record.Converter.GitHubVerification) { throw 'vstools commit signature verification is not valid.' }
    $python = (Get-Command python.exe -CommandType Application -ErrorAction Stop).Source
    if ((& $python --version 2>&1) -notmatch [regex]::Escape($record.Converter.PythonVersion)) { throw 'Pinned converter Python version is unavailable.' }
    $savedPythonPath = $env:PYTHONPATH
    try {
        $env:PYTHONPATH = $vstoolsRoot
        Invoke-CheckedNative -Label 'Visual Studio project generation' -Executable $python -Arguments @((Join-Path $vstoolsRoot 'vstools\scripts\msvscpp_convert.py'), $libewfRoot.FullName, '--output-format', '2022', '--extend-with-x64', '--no-python-dll')
    }
    finally { $env:PYTHONPATH = $savedPythonPath }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $installation = @(& $vswhere -latest -products $record.Toolchain.Product -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
    if (-not $installation) { throw 'Pinned MSVC Build Tools installation is unavailable.' }
    $msbuild = Join-Path $installation 'MSBuild\Current\Bin\MSBuild.exe'
    $solution = Join-Path $libewfRoot.FullName 'vs2022\libewf.sln'
    Invoke-CheckedNative -Label 'native ewfverify build' -Executable $msbuild -Arguments (@($solution, '/t:ewfverify') + @($record.Build.Arguments))
    $binaryRoot = Join-Path $libewfRoot.FullName 'vs2022\Release\x64'
    foreach ($name in $record.Package.AllowedRuntimeFiles) {
        $source = Join-Path $binaryRoot $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Expected native build output is missing: $name" }
        Copy-Item -LiteralPath $source -Destination $packageRoot
    }
    Copy-Item -LiteralPath (Join-Path $libewfRoot.FullName 'COPYING.LESSER') -Destination (Join-Path $packageRoot 'LICENSE-libewf.txt')
    Copy-Item -LiteralPath (Join-Path $zlibRoot.FullName 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE-zlib.txt')
    Copy-Item -LiteralPath (Join-Path $bzipRoot.FullName 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE-bzip2.txt')

    $runtimeFiles = @($record.Package.AllowedRuntimeFiles | ForEach-Object { $item = Get-Item -LiteralPath (Join-Path $packageRoot $_); [ordered]@{ Path = $_; Size = [int64] $item.Length; Sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash } })
    $manifest = [ordered]@{ SchemaVersion = '1.0'; ToolId = $record.ToolId; UpstreamVersion = $record.UpstreamVersion; BuildRevision = $record.BuildRevision; Architecture = 'x64'; Files = $runtimeFiles }
    Write-Utf8NoBom -LiteralPath (Join-Path $packageRoot 'manifest.json') -Content ($manifest | ConvertTo-Json -Depth 8)
    $sbom = [ordered]@{ spdxVersion = 'SPDX-2.3'; SPDXID = 'SPDXRef-DOCUMENT'; name = $record.RecordId; dataLicense = 'CC0-1.0'; packages = @(@{ name = 'libewf'; versionInfo = $record.UpstreamVersion; licenseConcluded = 'LGPL-3.0-or-later' }, @{ name = 'zlib'; versionInfo = '1.3.2'; licenseConcluded = 'Zlib' }, @{ name = 'bzip2'; versionInfo = '1.0.8'; licenseConcluded = 'bzip2-1.0.6' }) }
    Write-Utf8NoBom -LiteralPath (Join-Path $packageRoot 'sbom.spdx.json') -Content ($sbom | ConvertTo-Json -Depth 8)
    $provenance = [ordered]@{ SchemaVersion = '1.0'; ToolId = $record.ToolId; UpstreamVersion = $record.UpstreamVersion; BuildRevision = $record.BuildRevision; BuildRecordSha256 = (Get-FileHash -LiteralPath $recordPath -Algorithm SHA256).Hash; RepositoryCommit = (& git.exe -C $repositoryRoot rev-parse HEAD).Trim(); Workflow = $record.Build.Workflow; RunnerImage = $env:ImageVersion; Toolchain = $record.Toolchain; Converter = $record.Converter; SourceArtifacts = $record.SourceArtifacts; BuildArguments = $record.Build.Arguments; BuiltAtUtc = [datetime]::UtcNow.ToString('o'); AuthenticodeState = 'Unsigned' }
    Write-Utf8NoBom -LiteralPath (Join-Path $packageRoot 'provenance.json') -Content ($provenance | ConvertTo-Json -Depth 12)

    $checksumNames = @($record.Package.AllowedRuntimeFiles) + @('manifest.json', 'LICENSE-libewf.txt', 'LICENSE-zlib.txt', 'LICENSE-bzip2.txt', 'sbom.spdx.json', 'provenance.json')
    $checksumLines = @($checksumNames | Sort-Object | ForEach-Object { "$((Get-FileHash -LiteralPath (Join-Path $packageRoot $_) -Algorithm SHA256).Hash)  $_" })
    Write-Utf8NoBom -LiteralPath (Join-Path $packageRoot 'checksums.sha256') -Content (($checksumLines -join "`n") + "`n")

    [void] (New-Item -ItemType Directory -Path $OutputDirectory -Force)
    $assetPath = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) $record.Package.AssetName
    if (Test-Path -LiteralPath $assetPath) { throw "Refusing to replace existing candidate asset: $assetPath" }
    Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $assetPath -CompressionLevel Optimal
    & (Join-Path $PSScriptRoot 'Test-ForensicReleaseCandidate.ps1') -PackagePath $assetPath -BuildRecord $recordPath -SkipCompatibilityCertification
    if ($LASTEXITCODE -ne 0) { throw 'Built package failed offline candidate validation.' }
    $result = [pscustomobject]@{ schemaVersion = '1.0'; status = 'Built'; recordId = $record.RecordId; packagePath = $assetPath; packageSize = [int64] (Get-Item $assetPath).Length; packageSha256 = (Get-FileHash $assetPath -Algorithm SHA256).Hash; runtimeBuild = $false }
}
finally {
    if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction Ignore }
}

if ($Json) { $result | ConvertTo-Json -Depth 8 -Compress } else { $result; "Candidate package: $($result.packagePath)" }
