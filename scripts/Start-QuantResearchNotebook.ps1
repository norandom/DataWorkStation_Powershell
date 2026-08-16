[CmdletBinding()]
param(
    [string] $Project = 'thesis',
    [string] $ConfigurationPath = (Join-Path $PSScriptRoot '..\config\quant-research.psd1'),
    [Parameter(ValueFromRemainingArguments)]
    [string[]] $JupyterArguments = @()
)

$ErrorActionPreference = 'Stop'

function Expand-NotebookPath {
    param([string] $Value)
    [regex]::Replace($Value, '%([^%]+)%', [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $value = [Environment]::GetEnvironmentVariable($match.Groups[1].Value)
        if ([string]::IsNullOrWhiteSpace($value)) { throw "Missing environment variable: $($match.Groups[1].Value)" }
        $value
    })
}

function Get-GlobalKernelInventory {
    param([hashtable] $Configuration)
    @($Configuration.GlobalKernelRoots | ForEach-Object {
        $path = Expand-NotebookPath ([string] $_)
        if (Test-Path -LiteralPath $path -PathType Container) {
            Get-ChildItem -LiteralPath $path -Recurse -Force | Sort-Object FullName | ForEach-Object {
                $relative = [IO.Path]::GetRelativePath($path, $_.FullName)
                if ($_.PSIsContainer) { "directory|$relative" }
                else {
                    $digest = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                    "file|$relative|$($_.Length)|$digest"
                }
            }
        }
    })
}

$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
$researchRoot = [IO.Path]::GetFullPath((Expand-NotebookPath ([string] $configuration.Root)))
$definition = @($configuration.RequiredOverlays | Where-Object Name -eq $Project) | Select-Object -First 1
$relative = if ($definition) { [string] $definition.Path } else { Join-Path $configuration.OverlayRoot $Project }
$projectPath = [IO.Path]::GetFullPath((Join-Path $researchRoot $relative))
$rootPrefix = $researchRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $projectPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Project resolves outside the research root: $projectPath" }
foreach ($required in @('pyproject.toml', 'uv.lock', [string] $configuration.EnvironmentName)) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectPath $required))) { throw "Notebook project is not synchronized; missing $required in $projectPath" }
}

$before = @(Get-GlobalKernelInventory $configuration)
$uv = Get-Command uv -CommandType Application -ErrorAction Stop | Select-Object -First 1
$forwarded = @($JupyterArguments)
if ($forwarded.Count -gt 0 -and $forwarded[0] -eq '--') { $forwarded = @($forwarded | Select-Object -Skip 1) }
$arguments = @('run', '--locked', '--no-sync', 'jupyter', 'lab') + $forwarded
Push-Location -LiteralPath $projectPath
try {
    & $uv.Source @arguments
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
$after = @(Get-GlobalKernelInventory $configuration)
if (($before -join "`n") -cne ($after -join "`n")) { throw 'The notebook workflow changed the global kernel registry.' }
if ($exitCode -ne 0) { exit $exitCode }
