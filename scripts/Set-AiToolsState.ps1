[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$asJson = [bool] $Json
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'AiTools.Core.ps1')
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\ai-tools.psd1')

function Write-Result {
    param([Parameter(Mandatory = $true)] $State)
    if ($asJson) { $State | ConvertTo-Json -Depth 8; return }
    Get-AiToolsHumanText $State | Write-Host
}

function Invoke-OfficialPowerShellInstaller {
    param([Parameter(Mandatory = $true)][string] $InstallCommand)
    $powerShell = (Get-Command pwsh.exe -CommandType Application -ErrorAction Stop).Source
    & $powerShell -NoLogo -NoProfile -Command $InstallCommand
    if ($LASTEXITCODE -ne 0) { throw "Official installer failed with exit code $LASTEXITCODE." }
}

function Install-OpenCodeDesktop {
    param([Parameter(Mandatory = $true)][hashtable] $Product)
    $downloadDirectory = Join-Path $repositoryRoot "state\ai-tools\opencode\$($Product.Version)"
    $installer = Join-Path $downloadDirectory 'opencode-desktop-win-x64.exe'
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf) -or
        (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Product.Sha256) {
        Invoke-WebRequest -UseBasicParsing -Uri $Product.Uri -OutFile $installer
    }
    $digest = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($digest -ne $Product.Sha256) { throw 'OpenCode Desktop installer SHA-256 mismatch.' }
    $process = Start-Process -FilePath $installer -ArgumentList @($Product.InstallArguments) -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "OpenCode Desktop installer failed with exit code $($process.ExitCode)." }
}

$before = Get-AiToolsState $configuration
if ($Mode -eq 'Plan') {
    Write-Result $before
    exit 0
}
if ($Mode -eq 'Test') {
    Write-Result $before
    if ($before.Status -eq 'compliant') { exit 0 }
    exit 1
}

foreach ($product in @($configuration.Products | Where-Object Enabled)) {
    $record = @($before.Products | Where-Object Name -eq $product.Name)[0]
    if ($record.Status -eq 'compliant' -and $Mode -ne 'Reinitialize') { continue }
    Write-Host "Reconciling $($product.Name) through $($product.Channel)."
    switch ($product.Channel) {
        'OfficialPowerShell' {
            if ($product.Name -eq 'Claude Code' -and $record.WrongChannel) {
                & winget.exe uninstall --id Anthropic.ClaudeCode --exact --source winget --disable-interactivity
                if ($LASTEXITCODE -ne 0) { throw 'Failed to remove the former Claude Code WinGet installation.' }
            }
            Invoke-OfficialPowerShellInstaller $product.InstallCommand
        }
        'NpmGlobal' {
            & npm.cmd install --global $product.NpmPackage
            if ($LASTEXITCODE -ne 0) { throw "npm failed to install $($product.NpmPackage)." }
        }
        'GitHubRelease' { Install-OpenCodeDesktop $product }
        default { throw "Unsupported AI tool channel: $($product.Channel)" }
    }
}

$after = Get-AiToolsState $configuration
Write-Result $after
if ($after.Status -ne 'compliant') { throw 'AI tools did not reach the declared state.' }
