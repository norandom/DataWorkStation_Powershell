[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\scoop.psd1')
$scoopRoot = [Environment]::ExpandEnvironmentVariables($configuration.Install.Root)
$scoopConfigPath = Join-Path $env:USERPROFILE '.config\scoop\config.json'
$allowedExecutionPolicies = @('RemoteSigned', 'Unrestricted', 'Bypass')

function Get-NormalizedRepository {
    param([AllowNull()][string] $Repository)

    if ([string]::IsNullOrWhiteSpace($Repository)) { return '' }
    ($Repository.Trim().TrimEnd('/') -replace '\.git$', '').ToLowerInvariant()
}

function Get-ScoopCommand {
    $command = Get-Command scoop.ps1 -CommandType ExternalScript -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $fallback = Join-Path $scoopRoot 'shims\scoop.ps1'
    if (Test-Path -LiteralPath $fallback -PathType Leaf) { return $fallback }
    $null
}

function Get-ScoopConfiguration {
    if (-not (Test-Path -LiteralPath $scoopConfigPath -PathType Leaf)) { return $null }
    try {
        Get-Content -LiteralPath $scoopConfigPath -Raw | ConvertFrom-Json
    } catch {
        throw "Scoop configuration is not valid JSON: $scoopConfigPath"
    }
}

function Get-ScoopState {
    $command = Get-ScoopCommand
    $git = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue
    $languageOk = $ExecutionContext.SessionState.LanguageMode -eq $configuration.Install.RequiredLanguageMode
    $effectivePolicy = Get-ExecutionPolicy
    $policyOk = $effectivePolicy -in $allowedExecutionPolicies
    $scoopConfiguration = Get-ScoopConfiguration
    $configuredRepository = if ($scoopConfiguration -and $scoopConfiguration.repo) {
        [string] $scoopConfiguration.repo
    } else {
        [string] $configuration.Install.Repository
    }
    $repositoryOk = (Get-NormalizedRepository $configuredRepository) -eq
        (Get-NormalizedRepository $configuration.Install.Repository)

    $bucketStates = foreach ($bucket in $configuration.Buckets) {
        $path = Join-Path $scoopRoot "buckets\$($bucket.Name)"
        $installed = Test-Path -LiteralPath $path -PathType Container
        $actualRepository = ''
        if ($installed -and $git -and (Test-Path -LiteralPath (Join-Path $path '.git'))) {
            $actualRepository = (& $git.Source -C $path remote get-url origin 2>$null | Select-Object -First 1)
        }
        $sourceOk = if (-not $installed) {
            $false
        } elseif ($actualRepository) {
            (Get-NormalizedRepository $actualRepository) -eq (Get-NormalizedRepository $bucket.Repository)
        } else {
            $bucket.Name -eq 'main' -and $repositoryOk
        }
        [pscustomobject]@{
            Name = $bucket.Name
            Installed = $installed
            ExpectedRepository = $bucket.Repository
            ActualRepository = $actualRepository
            SourceCompliant = $sourceOk
        }
    }

    [pscustomobject]@{
        ScoopCommand = $command
        ScoopRoot = $scoopRoot
        PowerShellVersionCompliant = $PSVersionTable.PSVersion -ge [version]'5.1'
        LanguageMode = [string] $ExecutionContext.SessionState.LanguageMode
        LanguageModeCompliant = $languageOk
        ExecutionPolicy = [string] $effectivePolicy
        ExecutionPolicyCompliant = $policyOk
        GitCommand = if ($git) { $git.Source } else { $null }
        Repository = $configuredRepository
        RepositoryCompliant = $repositoryOk
        Buckets = @($bucketStates)
        Compliant = [bool](
            $command -and
            $git -and
            $languageOk -and
            $policyOk -and
            $repositoryOk -and
            @($bucketStates | Where-Object { -not $_.SourceCompliant }).Count -eq 0
        )
    }
}

function Write-ScoopState {
    param([pscustomobject] $State)

    @(
        [pscustomobject]@{ Resource = 'PowerShell'; State = if ($State.PowerShellVersionCompliant -and $State.LanguageModeCompliant -and $State.ExecutionPolicyCompliant) { 'compliant' } else { 'drift detected' }; Detail = "$($PSVersionTable.PSVersion); $($State.LanguageMode); policy $($State.ExecutionPolicy)" }
        [pscustomobject]@{ Resource = 'Git'; State = if ($State.GitCommand) { 'compliant' } else { 'drift detected' }; Detail = $State.GitCommand }
        [pscustomobject]@{ Resource = 'Scoop'; State = if ($State.ScoopCommand -and $State.RepositoryCompliant) { 'compliant' } else { 'drift detected' }; Detail = "$($State.ScoopCommand); $($State.Repository)" }
        foreach ($bucket in $State.Buckets) {
            [pscustomobject]@{ Resource = "ScoopBucket/$($bucket.Name)"; State = if ($bucket.SourceCompliant) { 'compliant' } else { 'drift detected' }; Detail = if ($bucket.ActualRepository) { $bucket.ActualRepository } else { $bucket.ExpectedRepository } }
        }
    ) | Format-Table -AutoSize -Wrap
}

$state = Get-ScoopState
if ($Mode -eq 'Test') {
    Write-ScoopState $state
    if (-not $state.Compliant) { exit 1 }
    exit 0
}

if (-not $state.PowerShellVersionCompliant) {
    throw 'Scoop requires PowerShell 5.1 or later.'
}
if (-not $state.LanguageModeCompliant) {
    throw "Scoop requires $($configuration.Install.RequiredLanguageMode); current language mode is $($state.LanguageMode)."
}
if (-not $state.GitCommand) {
    throw 'Git is required before Scoop buckets can be maintained. Run the Git module first.'
}
if ($state.ScoopCommand -and -not $state.RepositoryCompliant) {
    throw "Refusing to repair Scoop from an unexpected repository: $($state.Repository)"
}

if (-not $state.ExecutionPolicyCompliant) {
    Set-ExecutionPolicy -ExecutionPolicy $configuration.Install.RequiredExecutionPolicy -Scope CurrentUser -Force
}

if (-not $state.ScoopCommand) {
    $installerPath = Join-Path ([IO.Path]::GetTempPath()) "scoop-install-$([guid]::NewGuid().ToString('N')).ps1"
    try {
        Invoke-WebRequest -Uri $configuration.Install.Uri -OutFile $installerPath -UseBasicParsing
        $installerArguments = @()
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $installerArguments += '-RunAsAdmin'
        }
        & $installerPath @installerArguments
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            throw "The official Scoop installer failed with exit code $LASTEXITCODE."
        }
    } finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

$scoopCommand = Get-ScoopCommand
if (-not $scoopCommand) { throw 'Scoop was not available after installation.' }

$postInstallState = Get-ScoopState
if (-not $postInstallState.RepositoryCompliant) {
    throw "Scoop does not use the declared official repository: $($postInstallState.Repository)"
}

foreach ($bucket in $configuration.Buckets) {
    $bucketState = $postInstallState.Buckets | Where-Object Name -eq $bucket.Name
    if ($bucketState.Installed -and -not $bucketState.SourceCompliant) {
        throw "Refusing to replace Scoop bucket '$($bucket.Name)' from unexpected repository '$($bucketState.ActualRepository)'."
    }
    if (-not $bucketState.Installed) {
        & $scoopCommand bucket add $bucket.Name $bucket.Repository
        if ($LASTEXITCODE -ne 0) { throw "Unable to add Scoop bucket '$($bucket.Name)': $LASTEXITCODE" }
    }
}

$result = Get-ScoopState
Write-ScoopState $result
if (-not $result.Compliant) { throw 'Scoop did not reach the declared state.' }
Write-Host "Scoop state '$Mode' completed successfully with official Main and Extras buckets."
