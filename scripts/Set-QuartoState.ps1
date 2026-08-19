[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json,
    [string] $ConfigurationPath
)

$ErrorActionPreference = 'Stop'
$jsonRequested = [bool] $Json
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'SoftwareRelease.Core.ps1')
if (-not $ConfigurationPath) { $ConfigurationPath = Join-Path $repositoryRoot 'config\quarto.psd1' }
$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
$package = $configuration.Package
$packageRelease = Resolve-PinnedSoftwareReleaseAsset -Name 'Quarto' -Version $package.Version
$quantConfigurationPath = Join-Path $repositoryRoot $configuration.QuantConfiguration
$quantConfiguration = Import-PowerShellDataFile -LiteralPath $quantConfigurationPath
$installRoot = [Environment]::ExpandEnvironmentVariables($package.InstallRoot)
$quartoCommand = Join-Path $installRoot $package.Command
$quartoBin = Split-Path -Parent $quartoCommand
$tinyTexRoot = [Environment]::ExpandEnvironmentVariables($configuration.TinyTeX.InstallRoot)
$quantRoot = [Environment]::ExpandEnvironmentVariables($quantConfiguration.Root)
$quantBase = Join-Path $quantRoot $quantConfiguration.Base.Path
$quantPython = Join-Path $quantBase "$($quantConfiguration.EnvironmentName)\Scripts\python.exe"
$quantJupyter = Join-Path $quantBase "$($quantConfiguration.EnvironmentName)\Scripts\jupyter.exe"

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
    $items = [Collections.Generic.List[string]]::new()
    foreach ($item in @($userPath -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($item) -and $item.TrimEnd('\') -ine $Entry.TrimEnd('\')) {
            $items.Add($item)
        }
    }
    $items.Add($Entry)
    [Environment]::SetEnvironmentVariable('Path', ($items -join ';'), 'User')
    if (-not (Test-UserPathEntry -Entry $Entry)) { throw "Failed to add '$Entry' to the user PATH." }
}

function Invoke-CapturedCommand {
    param([string] $FilePath, [string[]] $ArgumentList)

    try {
        $output = @(& $FilePath @ArgumentList 2>&1) -join [Environment]::NewLine
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = $output.Trim() }
    } catch {
        [pscustomobject]@{ ExitCode = 1; Text = $_.Exception.Message }
    }
}

function Get-TinyTexBinary {
    foreach ($relative in @('bin\windows\pdflatex.exe', 'bin\win32\pdflatex.exe')) {
        $candidate = Join-Path $tinyTexRoot $relative
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    $null
}

function Get-QuartoState {
    $quartoExists = Test-Path -LiteralPath $quartoCommand -PathType Leaf
    $quartoVersion = $null
    $pandocVersion = $null
    if ($quartoExists) {
        $versionResult = Invoke-CapturedCommand -FilePath $quartoCommand -ArgumentList @('--version')
        if ($versionResult.ExitCode -eq 0) { $quartoVersion = $versionResult.Text }
        $pandocResult = Invoke-CapturedCommand -FilePath $quartoCommand -ArgumentList @('pandoc', '--version')
        if ($pandocResult.ExitCode -eq 0 -and $pandocResult.Text -match '(?im)^pandoc\s+([^\s]+)') {
            $pandocVersion = $Matches[1]
        }
    }
    $tinyTexVersionFile = Join-Path $tinyTexRoot 'version'
    $tinyTexVersion = if (Test-Path -LiteralPath $tinyTexVersionFile -PathType Leaf) {
        (Get-Content -LiteralPath $tinyTexVersionFile -Raw).Trim()
    } else { $null }
    $tinyTexBinary = Get-TinyTexBinary
    $tinyTexBin = if ($tinyTexBinary) { Split-Path -Parent $tinyTexBinary } else { Join-Path $tinyTexRoot 'bin\windows' }
    $tinyTexOnUserPath = Test-UserPathEntry -Entry $tinyTexBin
    $configuredPython = [Environment]::GetEnvironmentVariable('QUARTO_PYTHON', 'User')
    $checks = [ordered]@{
        QuartoCommand = $quartoExists
        QuartoVersion = ($quartoVersion -eq [string] $package.Version)
        BundledPandoc = [bool] $pandocVersion
        TinyTeX = [bool]($tinyTexVersion -and $tinyTexBinary)
        TinyTeXPrivate = -not $tinyTexOnUserPath
        QuantPython = (Test-Path -LiteralPath $quantPython -PathType Leaf)
        QuantJupyter = (Test-Path -LiteralPath $quantJupyter -PathType Leaf)
        QuartoPython = ($configuredPython -and [IO.Path]::GetFullPath($configuredPython) -ieq [IO.Path]::GetFullPath($quantPython))
        CommandBinOnUserPath = Test-UserPathEntry -Entry $quartoBin
    }
    [pscustomobject]@{
        SchemaVersion = 1
        Resource = 'QuartoQuantPublishing'
        Status = if ($checks.Values -contains $false) { 'drift-detected' } else { 'compliant' }
        QuartoVersion = $quartoVersion
        ExpectedQuartoVersion = [string] $package.Version
        Command = $quartoCommand
        PandocVersion = $pandocVersion
        PandocCommand = 'quarto pandoc'
        TinyTeXVersion = $tinyTexVersion
        TinyTeXRoot = $tinyTexRoot
        TinyTeXBinary = $tinyTexBinary
        TinyTeXOnUserPath = $tinyTexOnUserPath
        QuartoPython = $configuredPython
        ExpectedQuartoPython = $quantPython
        Checks = [pscustomobject] $checks
    }
}

function Write-QuartoState {
    param([object] $State)

    if ($jsonRequested) { $State | ConvertTo-Json -Depth 5; return }
    Write-Host "Quarto quantitative publishing: $($State.Status)"
    Write-Host "  Quarto: $($State.QuartoVersion); Pandoc: $($State.PandocVersion)"
    Write-Host "  TinyTeX: $($State.TinyTeXVersion); private=$(-not $State.TinyTeXOnUserPath)"
    Write-Host "  QUARTO_PYTHON: $($State.QuartoPython)"
    $State.Checks.PSObject.Properties | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Name, $(if ($_.Value) { 'compliant' } else { 'drift detected' }))
    }
}

function Install-QuartoPortable {
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $temporaryDirectory = Join-Path $temporaryRoot ('dws-quarto-' + [guid]::NewGuid().ToString('N'))
    $archive = Join-Path $temporaryDirectory "quarto-$($package.Version)-win.zip"
    $expanded = Join-Path $temporaryDirectory 'expanded'
    $backup = "$installRoot.backup-$([guid]::NewGuid().ToString('N'))"
    $committed = $false
    [IO.Directory]::CreateDirectory($expanded) | Out-Null
    try {
        Invoke-WebRequest -Uri $packageRelease.Uri -OutFile $archive -UseBasicParsing
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne ([string] $package.Sha256).ToLowerInvariant()) {
            throw "Quarto archive SHA-256 mismatch. Expected $($package.Sha256), got $actualHash."
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
        $candidate = Get-ChildItem -LiteralPath $expanded -Filter 'quarto.cmd' -File -Recurse |
            Where-Object { $_.Directory.Name -eq 'bin' } | Select-Object -First 1
        if (-not $candidate) { throw 'The verified Quarto archive contains no bin\quarto.cmd.' }
        $payloadRoot = Split-Path -Parent $candidate.Directory.FullName
        $versionResult = Invoke-CapturedCommand -FilePath $candidate.FullName -ArgumentList @('--version')
        if ($versionResult.ExitCode -ne 0 -or $versionResult.Text -ne [string] $package.Version) {
            throw "The verified Quarto payload reported unexpected version '$($versionResult.Text)'."
        }
        if (Test-Path -LiteralPath $installRoot) { Move-Item -LiteralPath $installRoot -Destination $backup }
        Move-Item -LiteralPath $payloadRoot -Destination $installRoot
        $committed = $true
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
    } finally {
        if (-not $committed -and (Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $installRoot)) {
            Move-Item -LiteralPath $backup -Destination $installRoot
        }
        $resolvedTemporaryDirectory = [IO.Path]::GetFullPath($temporaryDirectory)
        if ($resolvedTemporaryDirectory.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $resolvedTemporaryDirectory -PathType Container)) {
            Remove-Item -LiteralPath $resolvedTemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$before = Get-QuartoState
if ($Mode -eq 'Test') {
    Write-QuartoState -State $before
    if ($before.Status -ne 'compliant') { exit 1 }
    exit 0
}

if (-not $before.Checks.QuantPython -or -not $before.Checks.QuantJupyter) {
    throw "The quant-base uv environment must contain Python and Jupyter before Quarto is reconciled: $quantBase"
}
if ($Mode -eq 'Reinitialize' -or -not $before.Checks.QuartoCommand -or -not $before.Checks.QuartoVersion -or
    -not $before.Checks.BundledPandoc) {
    Install-QuartoPortable
}
Add-UserPathEntry -Entry $quartoBin
[Environment]::SetEnvironmentVariable('QUARTO_PYTHON', $quantPython, 'User')
$env:QUARTO_PYTHON = $quantPython
if (@($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $quartoBin.TrimEnd('\') }).Count -eq 0) {
    $env:Path = "$env:Path;$quartoBin"
}

$current = Get-QuartoState
if (-not $current.Checks.TinyTeX) {
    $installResult = Invoke-CapturedCommand -FilePath $quartoCommand -ArgumentList @('install', 'tinytex', '--no-prompt')
    if ($installResult.ExitCode -ne 0) { throw "Quarto TinyTeX installation failed: $($installResult.Text)" }
}

$after = Get-QuartoState
Write-QuartoState -State $after
if ($after.Status -ne 'compliant') { throw 'Quarto quantitative publishing did not reach its declared state.' }
