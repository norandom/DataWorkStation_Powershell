[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z][a-z0-9-]{1,62}$')][string] $Name,
    [string[]] $Dependency = @(),
    [switch] $Run,
    [switch] $Json,
    [string] $ConfigurationPath = (Join-Path $PSScriptRoot '..\config\quant-research.psd1')
)

$ErrorActionPreference = 'Stop'

function Expand-OverlayPath {
    param([string] $Value)
    [regex]::Replace($Value, '%([^%]+)%', [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $resolved = [Environment]::GetEnvironmentVariable($match.Groups[1].Value)
        if ([string]::IsNullOrWhiteSpace($resolved)) { throw "Missing environment variable: $($match.Groups[1].Value)" }
        $resolved
    })
}

function Resolve-OverlayContainedPath {
    param([string] $Root, [string] $Path, [string] $Label)
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($fullRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label resolves outside the research root: $fullPath"
    }
    $fullPath
}

function Get-RecordedProjectDigests {
    param([string] $Root)
    $result = @{}
    Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object Name -in @('pyproject.toml', 'uv.lock') | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Root, $_.FullName)
        $result[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $result
}

function Compare-RecordedProjectDigests {
    param([hashtable] $Before, [hashtable] $After)
    foreach ($key in $Before.Keys) {
        if (-not $After.ContainsKey($key) -or $After[$key] -ne $Before[$key]) { return $false }
    }
    $true
}

function Invoke-OverlayUv {
    param([string] $WorkingDirectory, [string[]] $ArgumentList)
    $uv = Get-Command uv -CommandType Application -ErrorAction Stop | Select-Object -First 1
    Push-Location -LiteralPath $WorkingDirectory
    try {
        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = @(& $uv.Source @ArgumentList 2>&1 | ForEach-Object { [string] $_ })
            $exitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $oldPreference }
    } finally { Pop-Location }
    if ($exitCode -ne 0) { throw "uv $($ArgumentList -join ' ') failed: $($output -join "`n")" }
}

function Write-Utf8File {
    param([string] $Path, [string] $Content)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Write-OverlayResult {
    param([object] $Result, [switch] $AsJson)
    if ($AsJson) { $Result | ConvertTo-Json -Depth 8 -Compress; return }
    Write-Host "Overlay '$($Result.name)': $($Result.state)"
    Write-Host "Destination: $($Result.destination)"
    Write-Host "Base source: $($Result.baseSource)"
    if (-not $Result.mutationPerformed) { Write-Host 'Plan only. Add -Run to create the overlay.' }
}

$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
$researchRoot = [IO.Path]::GetFullPath((Expand-OverlayPath ([string] $configuration.Root)))
$overlayRoot = Resolve-OverlayContainedPath $researchRoot (Join-Path $researchRoot $configuration.OverlayRoot) 'Overlay root'
$destination = Resolve-OverlayContainedPath $researchRoot (Join-Path $overlayRoot $Name) 'Overlay destination'
$basePath = Resolve-OverlayContainedPath $researchRoot (Join-Path $researchRoot $configuration.Base.Path) 'Base project'
if (-not (Test-Path -LiteralPath (Join-Path $basePath 'pyproject.toml') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $basePath 'uv.lock') -PathType Leaf)) {
    throw "The base project is incomplete: $basePath"
}
if (Test-Path -LiteralPath $destination) { throw "Overlay destination already exists: $destination" }
foreach ($requested in $Dependency) {
    if ($requested -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*(?:\[[A-Za-z0-9,_.-]+\])?(?:[<>=!~].*)?$' -or $requested -match '["''\r\n]') {
        throw "Unsafe or unsupported dependency declaration: $requested"
    }
}

$baseSource = '../../quant-base'
$plannedCommands = @(
    'uv lock',
    'uv sync --locked',
    'uv run --frozen --no-sync python -B -c "import quant_base"'
)
$plan = [pscustomobject]@{
    schemaVersion = 1
    name = $Name
    destination = $destination
    baseSource = $baseSource
    dependencies = @($Dependency)
    plannedCommands = $plannedCommands
    mutationPerformed = $false
    state = 'planned'
    warnings = @()
    blockers = @()
}
if (-not $Run) { Write-OverlayResult $plan -AsJson:$Json; exit 0 }

[IO.Directory]::CreateDirectory($overlayRoot) | Out-Null
$before = Get-RecordedProjectDigests $researchRoot
$staging = Join-Path $overlayRoot ('.' + $Name + '.staging-' + [guid]::NewGuid().ToString('N'))
$completed = $false
try {
    [IO.Directory]::CreateDirectory((Join-Path $staging ('src\' + $Name.Replace('-', '_')))) | Out-Null
    $dependencies = @('quant-base') + @($Dependency)
    $dependencyLines = ($dependencies | ForEach-Object { '    "' + $_ + '",' }) -join "`n"
    $manifest = @"
[project]
name = "$Name"
version = "0.1.0"
requires-python = ">=$($configuration.Python)"
dependencies = [
$dependencyLines
]

[build-system]
requires = ["uv_build>=0.12.3,<0.13.0"]
build-backend = "uv_build"

[tool.uv.sources]
quant-base = { path = "$baseSource", editable = true }

[dependency-groups]
dev = ["jupyterlab>=4", "ipykernel>=6"]
"@
    Write-Utf8File (Join-Path $staging 'pyproject.toml') $manifest
    Write-Utf8File (Join-Path $staging 'README.md') "# $Name`n"
    Write-Utf8File (Join-Path $staging ('src\' + $Name.Replace('-', '_') + '\__init__.py')) '__version__ = "0.1.0"'
    Invoke-OverlayUv $staging @('lock')
    Invoke-OverlayUv $staging @('sync', '--locked')
    Invoke-OverlayUv $staging @('run', '--frozen', '--no-sync', 'python', '-B', '-c', 'import quant_base')
    foreach ($required in @('pyproject.toml', 'uv.lock', [string] $configuration.EnvironmentName)) {
        if (-not (Test-Path -LiteralPath (Join-Path $staging $required))) { throw "Staged overlay validation is missing $required." }
    }
    $after = Get-RecordedProjectDigests $researchRoot
    if (-not (Compare-RecordedProjectDigests $before $after)) { throw 'An existing project declaration or lock changed during overlay creation.' }
    Move-Item -LiteralPath $staging -Destination $destination
    $completed = $true
    $plan.mutationPerformed = $true
    $plan.state = 'created'
    Write-OverlayResult $plan -AsJson:$Json
} finally {
    if (-not $completed -and (Test-Path -LiteralPath $staging -PathType Container)) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
