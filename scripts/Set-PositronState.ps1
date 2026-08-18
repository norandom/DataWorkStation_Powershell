[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $AcceptLicense,
    [switch] $Json,
    [string] $ConfigurationPath
)

$ErrorActionPreference = 'Stop'
$jsonRequested = [bool] $Json
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $ConfigurationPath) { $ConfigurationPath = Join-Path $repositoryRoot 'config\positron.psd1' }
$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
$product = $configuration.Product
$installRoot = [Environment]::ExpandEnvironmentVariables($product.InstallRoot)
$executable = Join-Path $installRoot $product.Executable
$command = Join-Path $installRoot $product.Command
$commandDirectory = Split-Path -Parent $command
$minimumVersion = [version] $product.MinimumProductVersion
$hostArchitecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()

function Test-UserPathEntry {
    param([string] $Entry)

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    @($userPath -split ';' | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and $_.TrimEnd('\') -ieq $Entry.TrimEnd('\')
    }).Count -gt 0
}

function Add-UserPathEntry {
    param([string] $Entry)

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = [Collections.Generic.List[string]]::new()
    foreach ($item in @($userPath -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($item) -and $item.TrimEnd('\') -ine $Entry.TrimEnd('\')) {
            $entries.Add($item)
        }
    }
    $entries.Add($Entry)
    [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), 'User')
    if (-not (Test-UserPathEntry -Entry $Entry)) { throw "Failed to add '$Entry' to the user PATH." }
}

function ConvertTo-ProductVersion {
    param([string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $match = [regex]::Match($Value, '(?<version>\d{4}\.\d{1,2}\.\d+(?:\.\d+)?)')
    if (-not $match.Success) { return $null }
    $parts = @($match.Groups['version'].Value.Split('.') | ForEach-Object { [int] $_ })
    while ($parts.Count -lt 4) { $parts += 0 }
    [version]::new($parts[0], $parts[1], $parts[2], $parts[3])
}

function Get-PositronState {
    $binaryExists = Test-Path -LiteralPath $executable -PathType Leaf
    $commandExists = Test-Path -LiteralPath $command -PathType Leaf
    $signatureStatus = 'NotFound'
    $publisher = $null
    $versionText = $null
    $actualVersion = $null
    if ($binaryExists) {
        $item = Get-Item -LiteralPath $executable
        $versionText = [string] $item.VersionInfo.ProductVersion
        if (-not $versionText) { $versionText = [string] $item.VersionInfo.FileVersion }
        $actualVersion = ConvertTo-ProductVersion -Value $versionText
        $signature = Get-AuthenticodeSignature -LiteralPath $executable
        $signatureStatus = [string] $signature.Status
        if ($signature.SignerCertificate) { $publisher = [string] $signature.SignerCertificate.Subject }
    }

    $checks = [ordered]@{
        Architecture = ($product.Architecture -eq 'x64' -and $hostArchitecture -eq 'X64')
        Executable = $binaryExists
        Command = $commandExists
        MinimumVersion = [bool]($actualVersion -and $actualVersion -ge $minimumVersion)
        Authenticode = ($signatureStatus -eq 'Valid')
        Publisher = [bool]($publisher -and $publisher -match $product.PublisherPattern)
        CommandBinOnUserPath = Test-UserPathEntry -Entry $commandDirectory
    }
    [pscustomobject]@{
        SchemaVersion = 1
        Resource = 'Positron'
        Status = if ($checks.Values -contains $false) { 'drift-detected' } else { 'compliant' }
        Release = [string] $product.Release
        MinimumVersion = [string] $minimumVersion
        InstalledVersion = $versionText
        Architecture = [string] $product.Architecture
        HostArchitecture = $hostArchitecture
        Executable = $executable
        Command = $command
        Publisher = $publisher
        SignatureStatus = $signatureStatus
        Source = [string] $product.DownloadPage
        License = [string] $product.LicenseUri
        LicenseAcceptanceRequired = $true
        Checks = [pscustomobject] $checks
    }
}

function Write-PositronState {
    param([object] $State)

    if ($jsonRequested) { $State | ConvertTo-Json -Depth 5; return }
    Write-Host "Positron: $($State.Status) ($($State.InstalledVersion))"
    $State.Checks.PSObject.Properties | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Name, $(if ($_.Value) { 'compliant' } else { 'drift detected' }))
    }
    Write-Host "  executable: $($State.Executable)"
    Write-Host "  release source: $($State.Source)"
    Write-Host "  license: $($State.License)"
}

function Assert-InstallerTrust {
    param([string] $Path)

    $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne ([string] $product.InstallerSha256).ToLowerInvariant()) {
        throw "Positron installer SHA-256 mismatch. Expected $($product.InstallerSha256), got $actualHash."
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    $subject = if ($signature.SignerCertificate) { [string] $signature.SignerCertificate.Subject } else { '' }
    if ($signature.Status -ne 'Valid' -or $subject -notmatch $product.PublisherPattern) {
        throw "Positron installer Authenticode validation failed (status '$($signature.Status)', signer '$subject')."
    }
}

$before = Get-PositronState
if ($Mode -eq 'Test') {
    Write-PositronState -State $before
    if ($before.Status -ne 'compliant') { exit 1 }
    exit 0
}

$installRequired = $Mode -eq 'Reinitialize' -or -not $before.Checks.Executable -or
    -not $before.Checks.Command -or -not $before.Checks.MinimumVersion -or
    -not $before.Checks.Authenticode -or -not $before.Checks.Publisher
if ($installRequired) {
    if (-not $before.Checks.Architecture) {
        throw "The declared Positron installer requires an x64 Windows host; detected '$hostArchitecture'."
    }
    if (-not $AcceptLicense) {
        throw "Installing Positron requires explicit acceptance of its license. Review $($product.LicenseUri), then rerun with -AcceptLicense."
    }

    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $temporaryDirectory = Join-Path $temporaryRoot ('dws-positron-' + [guid]::NewGuid().ToString('N'))
    $installerPath = Join-Path $temporaryDirectory "Positron-$($product.Release)-UserSetup-x64.exe"
    [IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
    try {
        Invoke-WebRequest -Uri $product.InstallerUri -OutFile $installerPath -UseBasicParsing
        Assert-InstallerTrust -Path $installerPath
        $process = Start-Process -FilePath $installerPath -ArgumentList @($product.InstallerArguments) `
            -WindowStyle Hidden -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Positron installer failed with exit code $($process.ExitCode)." }
    } finally {
        $resolvedTemporaryDirectory = [IO.Path]::GetFullPath($temporaryDirectory)
        if ($resolvedTemporaryDirectory.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $resolvedTemporaryDirectory -PathType Container)) {
            Remove-Item -LiteralPath $resolvedTemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if (Test-Path -LiteralPath $commandDirectory -PathType Container) {
    Add-UserPathEntry -Entry $commandDirectory
    if (@($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $commandDirectory.TrimEnd('\') }).Count -eq 0) {
        $env:Path = "$env:Path;$commandDirectory"
    }
}

$after = Get-PositronState
Write-PositronState -State $after
if ($after.Status -ne 'compliant') { throw 'Positron did not reach the declared quantitative-tool state.' }
