[CmdletBinding()]
param(
    [ValidateSet('All', 'Declaration', 'StateContract', 'ModuleRouting', 'Documentation')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$failures = [Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if ($Condition) { Write-Host "PASS: $Message"; return }
    $failures.Add($Message)
    Write-Host "FAIL: $Message"
}

function Get-Source {
    param([string] $Path)
    Get-Content -LiteralPath (Join-Path $repositoryRoot $Path) -Raw
}

function Test-Declaration {
    $configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\opencode-extensions.psd1')
    Assert-True ($configuration.Themes.Commit -eq '7cef8d00dccd2c459df6bc1fe867a80bef668790') 'Cream Blue is commit-pinned'
    Assert-True ($configuration.Themes.Default -eq 'cream-blue-cobalt') 'Cobalt is the declared default theme'
    Assert-True (@($configuration.Themes.Files).Count -eq 3) 'all three declared Cream Blue themes are managed'
    Assert-True (@($configuration.Themes.Files | Where-Object Sha256 -notmatch '^[a-f0-9]{64}$').Count -eq 0) 'every theme has an exact SHA-256'
    Assert-True ($configuration.OpenUltraCode.Version -eq '0.1.3' -and $configuration.OpenUltraCode.Sha256 -match '^[a-f0-9]{64}$') 'OpenUltraCode uses a hash-pinned release'
    Assert-True ($configuration.OpenUltraCode.InventorySha256 -match '^[a-f0-9]{64}$' -and $configuration.OpenUltraCode.FileCount -eq 46) 'OpenUltraCode declares its complete extracted inventory'
    Assert-True (@($configuration.OpenUltraCode.Commands).Count -eq 8 -and @($configuration.OpenUltraCode.Agents).Count -eq 10) 'OpenUltraCode commands and agents are explicit inventory'
}

function Test-StateContract {
    $source = Get-Source 'scripts\Set-OpenCodeExtensionsState.ps1'
    Assert-True ($source -match "ValidateSet\('Plan', 'Test', 'Ensure', 'Reinitialize'\)" -and $source -match '\[switch\] \$Json') 'the resource exposes standard human and JSON modes'
    Assert-True ($source -match 'Get-LiveState' -and $source -match 'if \(\$Mode -eq ''Plan'' -or \$Mode -eq ''Test''\)') 'Plan and Test observe state before reconciliation'
    Assert-True ($source -match 'Get-VerifiedDownload' -and $source -match 'Get-InventoryIdentity') 'downloads and extracted release inventory are verified'
    Assert-True ($source -match 'Backup-File' -and $source -match 'Read-JsonHashtable') 'configuration updates are merge-preserved and backed up'
    Assert-True ($source -match "'https://opencode.ai/tui.json'" -and $source.Contains('$tui[''theme'']')) 'the default theme is written through the OpenCode TUI configuration'
    Assert-True ($source.Contains('PluginRelativePath') -and $source.Contains('$openCodeConfig[''plugin'']')) 'the release-local OpenUltraCode plugin is registered'
}

function Test-ModuleRouting {
    $catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $module = @($catalog.Modules | Where-Object Name -eq 'OpenCodeExtensions')
    Assert-True ($module.Count -eq 1 -and $module[0].Default) 'OpenCodeExtensions is one default focused module'
    Assert-True (-not $module[0].Privileged -and -not $module[0].Destructive) 'OpenCodeExtensions is nonprivileged and nondestructive'
    $apply = Get-Source 'Apply-Workstation.ps1'
    Assert-True ($apply -match "'OpenCodeExtensions'" -and $apply -match 'Set-OpenCodeExtensionsState\.ps1') 'the workstation orchestrator routes the module'
    $capabilities = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\capabilities.psd1')
    $route = @($capabilities.Capabilities | Where-Object Id -eq 'ai-tools-isolation')[0]
    Assert-True ($route.Modules -contains 'OpenCodeExtensions') 'the AI tools capability owns the focused module route'
    Assert-True (@($route.InspectCommands | Where-Object { $_ -match 'Set-OpenCodeExtensionsState.+-Mode Test' }).Count -ge 1) 'a direct human inspection command precedes orchestration'
    Assert-True (@($route.StateCommands | Where-Object { $_ -match 'Set-OpenCodeExtensionsState.+-Mode Ensure' }).Count -eq 1) 'the explicit human reconciliation command is routed'
}

function Test-Documentation {
    $combined = (Get-Source 'docs\ai-tools-isolation.md') + (Get-Source 'docs\desired-state.md') + (Get-Source 'docs\workstation-modules.md')
    Assert-True ($combined -match 'cream-blue-cobalt' -and $combined -match 'OpenUltraCode 0\.1\.3') 'operator docs identify the selected theme and release'
    Assert-True ($combined -match 'Set-OpenCodeExtensionsState\.ps1 -Mode Test' -and $combined -match 'Set-OpenCodeExtensionsState\.ps1 -Mode Ensure') 'operator docs show inspect-before-ensure commands'
}

$sections = if ($Section -eq 'All') { @('Declaration', 'StateContract', 'ModuleRouting', 'Documentation') } else { @($Section) }
foreach ($name in $sections) { & (Get-Command "Test-$name" -CommandType Function) }
if ($failures.Count -gt 0) { throw "$($failures.Count) OpenCode extension contract assertion(s) failed." }
