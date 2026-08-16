[CmdletBinding()]
param(
    [ValidateSet('All', 'Interfaces', 'Hooks', 'Dependencies', 'Documentation')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-Source {
    param([string] $RelativePath)
    Get-Content -LiteralPath (Join-Path $repositoryRoot $RelativePath) -Raw
}

function Test-Interfaces {
    $wrapperPath = Join-Path $repositoryRoot 'scripts\Invoke-RepositoryLint.ps1'
    Assert-True (Test-Path -LiteralPath $wrapperPath -PathType Leaf) 'shared repository lint command exists'
    $wrapper = Get-Source 'scripts\Invoke-RepositoryLint.ps1'
    Assert-True ($wrapper -match "ValidateSet\('All', 'Docker', 'Actions'\)") 'repository lint exposes bounded categories'
    Assert-True ($wrapper -match 'hadolint' -and $wrapper -match 'actionlint') 'repository lint invokes the declared native linters'

    $aliases = Get-Source 'profile\Aliases.ps1'
    foreach ($command in @('lint-repository', 'lint-docker', 'lint-actions')) {
        Assert-True ($aliases -match ('function global:' + [regex]::Escape($command))) "managed profile exposes $command"
    }

    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\capabilities.psd1')
    $capability = @($catalog.Capabilities | Where-Object Id -eq 'repository-quality')
    Assert-True ($capability.Count -eq 1) 'routing catalog declares repository-quality once'
    foreach ($command in @('lint-repository', 'lint-docker', 'lint-actions', 'precommit-run')) {
        Assert-True ((@($capability[0].InspectCommands) -join ';') -match [regex]::Escape($command)) "repository-quality routes $command"
    }
}

function Test-Hooks {
    $preCommit = Get-Source '.pre-commit-config.yaml'
    Assert-True ($preCommit -match 'pre-commit/pre-commit-hooks' -and $preCommit -match 'rev:\s*v6\.0\.0') 'portable stock hooks use an immutable release'
    foreach ($hook in @(
        'check-yaml', 'check-json', 'check-toml', 'check-merge-conflict', 'check-case-conflict',
        'check-added-large-files', 'detect-private-key', 'mixed-line-ending',
        'powershell-lint', 'python-lint', 'dockerfile-lint', 'github-actions-lint', 'docs-strict'
    )) {
        Assert-True ($preCommit -match ('id:\s*' + [regex]::Escape($hook) + '(?:\s|$)')) "pre-commit declares $hook"
    }
    Assert-True ($preCommit -match "--fix=no") 'mixed line-ending validation is non-mutating'
    Assert-True ($preCommit -match "exclude:\s*'\^\(\?:\\\.agents/\|\\\.specify/\)'") 'generated skill and Spec Kit metadata are excluded from line-ending policy'
    Assert-True ($preCommit -match "Invoke-RepositoryLint\.ps1[\s\S]*-Category[\s\S]*Docker") 'Dockerfile hook shares the human wrapper'
    Assert-True ($preCommit -match "Invoke-RepositoryLint\.ps1[\s\S]*-Category[\s\S]*Actions") 'Actions hook shares the human wrapper'
    Assert-True ($preCommit -match 'docs-strict[\s\S]*mkdocs[\s\S]*build[\s\S]*--strict') 'documentation hook shares the strict human build'
    Assert-True ($preCommit -notmatch 'trailing-whitespace|end-of-file-fixer|fix-byte-order-marker') 'pre-commit does not silently rewrite staged files'
}

function Test-Dependencies {
    $configurationPath = Join-Path $repositoryRoot 'config\repository-lint.psd1'
    Assert-True (Test-Path -LiteralPath $configurationPath -PathType Leaf) 'repository lint dependencies are declared'
    $configuration = Import-PowerShellDataFile -LiteralPath $configurationPath
    Assert-True ($configuration.PreCommitVersion -eq '4.6.2') 'pre-commit remains release-pinned'
    Assert-True ($configuration.PSScriptAnalyzerVersion -eq '1.25.0') 'PSScriptAnalyzer remains release-pinned'
    foreach ($expected in @(
        @{ Name = 'Hadolint'; Id = 'hadolint.hadolint'; Version = [version] '2.14.0' },
        @{ Name = 'Actionlint'; Id = 'rhysd.actionlint'; Version = [version] '1.7.12' }
    )) {
        $tool = @($configuration.Tools | Where-Object Name -eq $expected.Name)
        Assert-True ($tool.Count -eq 1) "$($expected.Name) is declared once"
        Assert-True ($tool[0].PackageId -eq $expected.Id) "$($expected.Name) uses the official WinGet package"
        Assert-True ([version] $tool[0].MinimumVersion -ge $expected.Version) "$($expected.Name) has a reviewed minimum version"
    }

    $installer = Get-Source 'scripts\Install-PreCommitHook.ps1'
    Assert-True ($installer -match 'repository-lint\.psd1') 'hook installer consumes the dependency declaration'
    Assert-True ($installer -match 'winget(?:\.exe)?' -and $installer -match '--disable-interactivity') 'missing native linters use non-interactive WinGet'
    Assert-True ($installer -match '--accept-package-agreements' -and $installer -match '--accept-source-agreements') 'WinGet agreements are explicit'
    Assert-True ($installer -match 'MinimumVersion') 'hook installer verifies minimum native tool versions'

    $hadolint = Get-Source '.hadolint.yaml'
    Assert-True ($hadolint -match 'DL3008' -and $hadolint -match 'digest-pinned') 'Docker package-pin exception has a repository-specific rationale'
}

function Test-Documentation {
    $readme = Get-Source 'README.md'
    $aliases = Get-Source 'docs\Aliases.md'
    $capabilities = Get-Source 'docs\capabilities\index.md'
    foreach ($term in @('Hadolint', 'actionlint', 'check-yaml', 'check-json', 'check-toml', 'MkDocs')) {
        Assert-True ($readme -match [regex]::Escape($term)) "README documents $term"
    }
    foreach ($command in @('lint-repository', 'lint-docker', 'lint-actions')) {
        Assert-True ($aliases -match [regex]::Escape($command)) "alias reference documents $command"
    }
    Assert-True ($capabilities -match '`repository-quality`') 'capability guide documents repository-quality'
}

$sections = if ($Section -eq 'All') { @('Interfaces', 'Hooks', 'Dependencies', 'Documentation') } else { @($Section) }
foreach ($name in $sections) {
    & "Test-$name"
    Write-Host "PASS $name"
}

Write-Host "Repository lint tests passed: $script:assertions assertions."
