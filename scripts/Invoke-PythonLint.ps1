[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Path
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$targets = @(if ($Path.Count -gt 0) { $Path } else { 'linux' })
$uv = Get-Command uv.exe -CommandType Application -ErrorAction Ignore | Select-Object -First 1
if (-not $uv) { $uv = Get-Command uv -CommandType Application -ErrorAction Stop | Select-Object -First 1 }

Push-Location -LiteralPath $repositoryRoot
try {
    & $uv.Source run --group lint ruff check -- @targets
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}
