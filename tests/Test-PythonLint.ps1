[CmdletBinding()]
param([ValidateSet('All', 'Interfaces')] [string] $Section = 'All')

$ErrorActionPreference = 'Stop'
$null = $Section # retained for the standard focused-test interface
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

$pyproject = Get-Content -LiteralPath (Join-Path $repositoryRoot 'pyproject.toml') -Raw
Assert-True ($pyproject -match 'ruff==0\.16\.3') 'Ruff is release-pinned in the repository environment'
Assert-True ($pyproject -match '\[tool\.ruff\]') 'Ruff policy is repository-owned'
$scriptPath = Join-Path $repositoryRoot 'scripts\Invoke-PythonLint.ps1'
Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) 'human Python lint command exists'
$source = Get-Content -LiteralPath $scriptPath -Raw
Assert-True ($source -match 'uv(?:\.exe)?') 'Python lint uses the locked repository environment'
Assert-True ($source -match 'ruff') 'Python lint invokes Ruff'
Assert-True ($source -match 'linux') 'default Python lint includes pyinfra and the container runner'
Assert-True ($source -match 'test_binary_diff_runner\.py') 'default Python lint includes the graph SQL regression test'
$aliases = Get-Content -LiteralPath (Join-Path $repositoryRoot 'profile\Aliases.ps1') -Raw
Assert-True ($aliases -match 'function global:lint-python') 'managed profile exposes lint-python'
$precommit = Get-Content -LiteralPath (Join-Path $repositoryRoot '.pre-commit-config.yaml') -Raw
Assert-True ($precommit -match 'python-lint') 'pre-commit has a Python lint hook'
Assert-True ($precommit -match 'Invoke-PythonLint\.ps1') 'pre-commit and humans share the same wrapper'
$pythonFiles = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'linux') -Recurse -File -Filter '*.py')
Assert-True ($pythonFiles.Count -ge 4) 'lint scope includes pyinfra deploys and the container runner'

Write-Host "Python lint interface tests passed ($script:assertions assertions)."
