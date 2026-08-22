[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [string[]] $Product = @('All'),
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$asJson = [bool] $Json
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'AiTools.Core.ps1')
. (Join-Path $PSScriptRoot 'SoftwareRelease.Core.ps1')
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\ai-tools.psd1')

function Resolve-SelectedAiToolsConfiguration {
    param(
        [Parameter(Mandatory = $true)][hashtable] $Configuration,
        [Parameter(Mandatory = $true)][string[]] $Product
    )

    $requested = @($Product | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($requested.Count -eq 0) { throw 'Select at least one AI product or use All.' }
    if ($requested -contains 'All') {
        if ($requested.Count -ne 1) { throw 'All cannot be combined with named AI products.' }
        return $Configuration
    }

    if ($requested -contains 'OpenCode') {
        $requested = @($requested | Where-Object { $_ -ne 'OpenCode' }) + @('OpenCode Desktop', 'OpenCode CLI')
        $requested = @($requested | Select-Object -Unique)
    }

    $available = @($Configuration.Products | ForEach-Object Name)
    $unknown = @($requested | Where-Object { $available -notcontains $_ })
    if ($unknown.Count -gt 0) { throw "Unknown AI product(s): $($unknown -join ', '). Available: $($available -join ', ')." }

    @{
        SchemaVersion = $Configuration.SchemaVersion
        Products = @($Configuration.Products | Where-Object { $requested -contains $_.Name })
    }
}

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
    $release = Resolve-PinnedSoftwareReleaseAsset -Name 'OpenCode' -Version $Product.Version -AssetIndex 0
    $downloadDirectory = Join-Path $repositoryRoot "state\ai-tools\opencode\$($Product.Version)"
    $installer = Join-Path $downloadDirectory 'opencode-desktop-win-x64.exe'
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf) -or
        (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Product.Sha256) {
        Invoke-WebRequest -UseBasicParsing -Uri $release.Uri -OutFile $installer
    }
    $digest = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($digest -ne $Product.Sha256) { throw 'OpenCode Desktop installer SHA-256 mismatch.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    if ($signature.Status -ne 'Valid') { throw "OpenCode Desktop installer signature is $($signature.Status)." }

    $targetExecutable = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string] $Product.InstallPath))
    $targetDirectory = Split-Path -Parent $targetExecutable
    $allowedParent = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs')) + [IO.Path]::DirectorySeparatorChar
    if (-not $targetDirectory.StartsWith($allowedParent, [StringComparison]::OrdinalIgnoreCase)) {
        throw "OpenCode Desktop target is outside the per-user Programs directory: $targetDirectory"
    }

    $needsPayload = -not (Test-Path -LiteralPath $targetExecutable -PathType Leaf) -or
        [string] (Get-Item -LiteralPath $targetExecutable -ErrorAction Ignore).VersionInfo.FileVersion -ne [string] $Product.Version
    if ($needsPayload) {
        $stagingDirectory = Join-Path $downloadDirectory "desktop-staging-$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $stagingDirectory -Force | Out-Null
        & tar.exe -xf $installer -C $stagingDirectory
        if ($LASTEXITCODE -ne 0) { throw "Windows tar failed to extract the OpenCode Desktop payload (exit $LASTEXITCODE)." }
        $stagedExecutable = Join-Path $stagingDirectory 'OpenCode.exe'
        if (-not (Test-Path -LiteralPath $stagedExecutable -PathType Leaf)) { throw 'The OpenCode Desktop release did not contain OpenCode.exe.' }
        if ([string] (Get-Item -LiteralPath $stagedExecutable).VersionInfo.FileVersion -ne [string] $Product.Version) {
            throw 'The extracted OpenCode Desktop version does not match the declaration.'
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $targetDirectory) -Force | Out-Null
        $backupDirectory = $null
        if (Test-Path -LiteralPath $targetDirectory -PathType Container) {
            $backupRoot = Join-Path $repositoryRoot 'state\ai-tools\opencode\backups'
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            $backupDirectory = Join-Path $backupRoot "OpenCode-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))"
            Move-Item -LiteralPath $targetDirectory -Destination $backupDirectory
        }
        try {
            Move-Item -LiteralPath $stagingDirectory -Destination $targetDirectory
        } catch {
            if ($backupDirectory -and -not (Test-Path -LiteralPath $targetDirectory) -and (Test-Path -LiteralPath $backupDirectory)) {
                Move-Item -LiteralPath $backupDirectory -Destination $targetDirectory
            }
            throw
        }
    }

    $shortcutPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string] $Product.ShortcutPath))
    New-Item -ItemType Directory -Path (Split-Path -Parent $shortcutPath) -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetExecutable
    $shortcut.WorkingDirectory = $targetDirectory
    $shortcut.Save()
}

function Remove-FormerScoopPackage {
    param([Parameter(Mandatory = $true)][hashtable] $Product)
    if (-not $Product.ContainsKey('FormerScoopPath') -or -not $Product.ContainsKey('FormerScoopPackage')) { return }
    $formerPath = [Environment]::ExpandEnvironmentVariables([string] $Product.FormerScoopPath)
    if (-not (Test-Path -LiteralPath $formerPath -PathType Leaf)) { return }
    $scoop = Get-Command scoop -CommandType ExternalScript,Application -ErrorAction Stop | Select-Object -First 1
    Write-Host "Removing former Scoop package $($Product.FormerScoopPackage) after replacement installation."
    & $scoop.Source uninstall $Product.FormerScoopPackage
    if ($LASTEXITCODE -ne 0) { throw "Scoop failed to uninstall $($Product.FormerScoopPackage)." }
}

$selectedConfiguration = Resolve-SelectedAiToolsConfiguration -Configuration $configuration -Product $Product
$before = Get-AiToolsState $selectedConfiguration
if ($Mode -eq 'Plan') {
    Write-Result $before
    exit 0
}
if ($Mode -eq 'Test') {
    Write-Result $before
    if ($before.Status -eq 'compliant') { exit 0 }
    exit 1
}

foreach ($item in @($selectedConfiguration.Products | Where-Object Enabled)) {
    $record = @($before.Products | Where-Object { $_.Name -eq $item.Name })[0]
    if ($record.Status -eq 'compliant' -and $Mode -ne 'Reinitialize') { continue }
    Write-Host "Reconciling $($item.Name) through $($item.Channel)."
    switch ($item.Channel) {
        'OfficialPowerShell' {
            if ($item.Name -eq 'Claude Code' -and $record.WrongChannel) {
                & winget.exe uninstall --id Anthropic.ClaudeCode --exact --source winget --disable-interactivity
                if ($LASTEXITCODE -ne 0) { throw 'Failed to remove the former Claude Code WinGet installation.' }
            }
            Invoke-OfficialPowerShellInstaller $item.InstallCommand
        }
        'NpmGlobal' {
            & npm.cmd install --global $item.NpmPackage
            if ($LASTEXITCODE -ne 0) { throw "npm failed to install $($item.NpmPackage)." }
        }
        'Scoop' {
            $scoop = Get-Command scoop -CommandType ExternalScript,Application -ErrorAction Stop | Select-Object -First 1
            $verb = if ($record.Installed) { 'update' } else { 'install' }
            & $scoop.Source $verb $item.ScoopPackage
            if ($LASTEXITCODE -ne 0) { throw "Scoop failed to $verb $($item.ScoopPackage)." }
        }
        'GitHubRelease' {
            if (-not $record.Installed -or $record.Status -in @('version-drift', 'shortcut-missing', 'wrong-channel')) { Install-OpenCodeDesktop $item }
        }
        default { throw "Unsupported AI tool channel: $($item.Channel)" }
    }
    Remove-FormerScoopPackage $item
}

$after = Get-AiToolsState $selectedConfiguration
Write-Result $after
if ($after.Status -ne 'compliant') { throw 'AI tools did not reach the declared state.' }
