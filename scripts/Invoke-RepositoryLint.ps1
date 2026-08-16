[CmdletBinding()]
param(
    [ValidateSet('All', 'Docker', 'Actions')]
    [string] $Category = 'All',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Path
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\repository-lint.psd1')
. (Join-Path $PSScriptRoot 'Resolve-RepositoryLinter.ps1')

function Get-LintTargets {
    param(
        [ValidateSet('Docker', 'Actions')] [string] $Kind,
        [string[]] $CandidatePath
    )

    $candidates = if ($CandidatePath -and $CandidatePath.Count -gt 0) {
        @($CandidatePath)
    } else {
        $tracked = @(git -C $repositoryRoot ls-files)
        if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate tracked repository files.' }
        $tracked
    }

    $pattern = if ($Kind -eq 'Docker') {
        '(?i)(^|/)(Dockerfile(?:\.[^/]+)?|[^/]+\.Dockerfile)$'
    } else {
        '(?i)^\.github/workflows/[^/]+\.(?:yml|yaml)$'
    }

    @($candidates | ForEach-Object { ([string] $_).Replace('\', '/') } |
        Where-Object { $_ -match $pattern } |
        Where-Object { Test-Path -LiteralPath (Join-Path $repositoryRoot $_) -PathType Leaf } |
        Sort-Object -Unique)
}

function Invoke-NativeLint {
    param(
        [ValidateSet('Docker', 'Actions')] [string] $Kind,
        [hashtable] $Tool,
        [string[]] $Targets
    )

    if ($Targets.Count -eq 0) {
        Write-Host "$Kind lint skipped: no matching files."
        return 0
    }

    $executable = Resolve-RepositoryLinter -Tool $Tool -Require
    $arguments = if ($Kind -eq 'Docker') {
        @('--no-color', '--config', (Join-Path $repositoryRoot '.hadolint.yaml'))
    } else {
        @('-no-color')
    }
    Write-Verbose ("{0}: {1}" -f $Kind, ($Targets -join ', '))
    $commandArguments = @($arguments) + @($Targets)
    & $executable @commandArguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { Write-Host "$Kind lint passed for $($Targets.Count) file(s)." }
    $exitCode
}

$toolByName = @{}
foreach ($tool in @($configuration.Tools)) { $toolByName[[string] $tool.Name] = $tool }
$categories = if ($Category -eq 'All') { @('Docker', 'Actions') } else { @($Category) }
$failed = $false

Push-Location -LiteralPath $repositoryRoot
try {
    foreach ($name in $categories) {
        $toolName = if ($name -eq 'Docker') { 'Hadolint' } else { 'Actionlint' }
        $targets = @(Get-LintTargets -Kind $name -CandidatePath $Path)
        $exitCode = Invoke-NativeLint -Kind $name -Tool $toolByName[$toolName] -Targets $targets
        if ($exitCode -ne 0) { $failed = $true }
    }
} finally {
    Pop-Location
}

if ($failed) { exit 1 }
