#pester:no-parallel
[CmdletBinding()]
param(
    [ValidateSet('All', 'EnabledProducts', 'OptInBoundary', 'ObservationalStatus', 'OutputParity',
        'OpenCodeTargets', 'ClaudeInstallChannel', 'AntigravityCliChannel', 'ClineCliChannel',
        'CopilotCli', 'EditorInventory', 'LocalFontPreference', 'PortableFontFallback', 'EditorMerge', 'BergActivation',
        'AiDistributionIdentity', 'AiNixIntegrity', 'NonoInstallChannel', 'NonoLaunchContract',
        'NonoFailClosed', 'NonoFilesystemPolicy', 'NonoCredentialPolicy', 'NonoNetworkPolicy',
        'NonoProfileDrift', 'AiDailyPrivilege', 'AiInteropBoundary', 'AiMountBoundary',
        'DevOpsInteropBoundary', 'DevOpsCredentialBoundary', 'MalwareWslBoundary',
        'MalwareCaseImport', 'MalwareCaseExport', 'TrustedDebianRole', 'TrustMatrixStatus',
        'BoundaryFailure', 'UpdateRevalidation', 'RoutingAndDocumentation', 'FocusedModuleBoundary',
        'PortableSecretExclusions')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-RequiredText {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$RelativePath exists"
    Get-Content -LiteralPath $path -Raw
}

function Get-RequiredData {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$RelativePath exists"
    Import-PowerShellDataFile -LiteralPath $path
}

function Get-WorkstationModule {
    param([string] $Name)
    $catalog = Get-RequiredData 'config/workstation-modules.psd1'
    @($catalog.Modules | Where-Object Name -eq $Name)[0]
}

function Test-EnabledProducts {
    $config = Get-RequiredData 'config/ai-tools.psd1'
    $names = @($config.Products | Where-Object Enabled | ForEach-Object Name)
    foreach ($name in @('OpenCode Desktop', 'Claude Code', 'Antigravity CLI', 'Cline CLI', 'GitHub Copilot CLI')) {
        Assert-True ($names -contains $name) "$name is enabled in the reviewed AI declaration"
    }
}

function Test-OptInBoundary {
    foreach ($name in @('AiTools', 'AiNixOsWsl')) {
        $module = Get-WorkstationModule $name
        Assert-True ($module -and -not $module.Default -and $module.FeatureSpec -eq 'specs/010-ai-tools-isolation') "$name is separately opt-in and governed"
    }
}

function Test-ObservationalStatus {
    foreach ($file in @('scripts/Set-AiToolsState.ps1', 'scripts/Set-DeveloperEditorState.ps1', 'scripts/Set-AiNixOsWslState.ps1', 'scripts/Test-WslTrustBoundary.ps1')) {
        $text = Get-RequiredText $file
        Assert-True ($text -match "'Test'" -and $text -match "'Plan'|Test-WslTrustBoundary") "$file exposes observation"
    }
}

function Test-OutputParity {
    foreach ($file in @('scripts/Set-AiToolsState.ps1', 'scripts/Set-DeveloperEditorState.ps1', 'scripts/Set-AiNixOsWslState.ps1', 'scripts/Test-WslTrustBoundary.ps1')) {
        $text = Get-RequiredText $file
        Assert-True ($text -match '\[switch\]\s*\$Json' -and $text -match 'ConvertTo-Json') "$file exposes JSON parity"
    }
}

function Test-OpenCodeTargets {
    $config = Get-RequiredData 'config/ai-tools.psd1'
    $desktop = @($config.Products | Where-Object Name -eq 'OpenCode Desktop')[0]
    Assert-True ($desktop.Target -eq 'Windows' -and $desktop.Channel -eq 'GitHubRelease') 'OpenCode Desktop is Windows-only'
    $ai = Get-RequiredData 'config/ai-nixos-wsl.psd1'
    Assert-True ($ai.RequiredCommands -contains 'opencode' -and $ai.DistributionVariable -eq 'WSL_AI_DISTRIBUTION') 'OpenCode CLI is AI-WSL-only'
}

function Test-ClaudeInstallChannel {
    $config = Get-RequiredData 'config/ai-tools.psd1'
    $item = @($config.Products | Where-Object Name -eq 'Claude Code')[0]
    Assert-True ($item.InstallCommand -eq 'irm https://claude.ai/install.ps1 | iex' -and $item.Channel -eq 'OfficialPowerShell') 'Claude uses only the selected official script'
    $wingetText = @(Get-ChildItem (Join-Path $repositoryRoot '.config') -Filter '*.winget' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    Assert-True ($wingetText -notmatch '(?i)Claude') 'Claude is absent from WinGet declarations'
}

function Test-AntigravityCliChannel {
    $config = Get-RequiredData 'config/ai-tools.psd1'
    $item = @($config.Products | Where-Object Name -eq 'Antigravity CLI')[0]
    Assert-True ($item.InstallCommand -eq 'irm https://antigravity.google/cli/install.ps1 | iex' -and $item.Command -eq 'agy') 'Antigravity is CLI-only through the official script'
}

function Test-ClineCliChannel {
    $config = Get-RequiredData 'config/ai-tools.psd1'
    $item = @($config.Products | Where-Object Name -eq 'Cline CLI')[0]
    Assert-True ($item.InstallCommand -eq 'npm i -g cline' -and $item.NpmPackage -eq 'cline') 'Cline uses the selected npm channel'
}

function Test-CopilotCli {
    $config = Get-RequiredData 'config/ai-tools.psd1'
    $item = @($config.Products | Where-Object Name -eq 'GitHub Copilot CLI')[0]
    Assert-True ($item.NpmPackage -eq '@github/copilot' -and $item.Command -eq 'copilot') 'Copilot CLI uses the official npm identity'
}

function Test-EditorInventory {
    $config = Get-RequiredData 'config/developer-editor.psd1'
    Assert-True ($config.PackageId -eq 'Microsoft.VisualStudioCode') 'stable VS Code is selected'
    foreach ($id in @('saoudrizwan.claude-dev', 'ms-toolsai.jupyter', 'ms-python.python', 'GitHub.copilot-chat')) {
        Assert-True ($config.Extensions -contains $id) "$id is declared"
    }
    Assert-True ($config.Berg.Repository -eq 'https://github.com/jx22/berg' -and $config.Berg.Sha256 -match '^[a-f0-9]{64}$') 'Berg source is pinned'
    Assert-True ((Get-RequiredText 'scripts/Set-DeveloperEditorState.ps1') -match 'BuiltIn.*Extension|resources.+extensions') 'bundled VS Code extensions participate in inventory checks'
}

function Test-LocalFontPreference {
    . (Join-Path $repositoryRoot 'scripts\DeveloperEditor.Core.ps1')
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "developer-editor-font-$([guid]::NewGuid().ToString('N'))"
    try {
        New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'BerkeleyMono-Regular.otf') -Value 'synthetic font fixture'
        $reader = { param($Path) if ($Path) { @('Berkeley Mono') } }
        Assert-True (Test-FontFamilyInDirectory -Family 'Berkeley Mono' -Directory $fixtureRoot -FamilyReader $reader) 'embedded per-user font family metadata is accepted'
        Assert-True (-not (Test-FontFamilyInDirectory -Family 'Missing Mono' -Directory $fixtureRoot -FamilyReader $reader)) 'a different embedded family is rejected'
    } finally {
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    }
}

function Test-PortableFontFallback {
    $config = Get-RequiredData 'config/developer-editor.psd1'
    Assert-True ($config.PortableFontFamily -eq 'Fira Code') 'portable editor font falls back to Fira Code'
}

function Test-EditorMerge {
    $text = Get-RequiredText 'scripts/DeveloperEditor.Core.ps1'
    Assert-True ($text -match 'Merge-DeveloperEditorSettings' -and $text -notmatch 'Remove-Item.+settings') 'editor settings use a bounded semantic merge'
}

function Test-BergActivation {
    $config = Get-RequiredData 'config/developer-editor.psd1'
    $core = Get-RequiredText 'scripts/DeveloperEditor.Core.ps1'
    $state = Get-RequiredText 'scripts/Set-DeveloperEditorState.ps1'
    Assert-True ($config.Berg.ExtensionId -eq 'teehausamberg.berg' -and $config.Berg.ExtensionVersion -eq '0.0.4') 'the VS Code-discovered Berg identity is declared exactly'
    Assert-True ($config.Berg.ThemeLabel -eq 'Berg Theme') 'the contributed Berg theme label is declared'
    Assert-True ($config.ManagedSettings -contains 'workbench.colorTheme') 'theme activation is a bounded managed setting'
    Assert-True ($core -match "workbench\.colorTheme.*ThemeLabel") 'the semantic merge activates the declared theme'
    . (Join-Path $repositoryRoot 'scripts\DeveloperEditor.Core.ps1')
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "developer-editor-berg-$([guid]::NewGuid().ToString('N'))"
    try {
        $extensionRoot = Join-Path $fixtureRoot 'teehausamberg.berg-0.0.4'
        $themeDirectory = Join-Path $extensionRoot 'themes'
        New-Item -ItemType Directory -Path $themeDirectory -Force | Out-Null
        $themePath = Join-Path $themeDirectory 'Berg Theme-color-theme.json'
        Set-Content -LiteralPath $themePath -Value '{"name":"fixture"}' -NoNewline
        $fixtureHash = (Get-FileHash -LiteralPath $themePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifest = @{
            publisher = 'teehausamberg'; name = 'berg'; version = '0.0.4'
            contributes = @{ themes = @(@{ label = 'Berg Theme'; path = './themes/Berg Theme-color-theme.json' }) }
        }
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $extensionRoot 'package.json')
        $fixtureConfig = @{} + $config.Berg
        $fixtureConfig.Sha256 = $fixtureHash
        $discovered = Get-BergExtensionState -Configuration $fixtureConfig -ExtensionInventory @('teehausamberg.berg') -ExtensionRoot $fixtureRoot
        Assert-True $discovered.Compliant 'a CLI-discovered extension with the exact manifest, contribution, and digest is compliant'
        $hashOnly = Get-BergExtensionState -Configuration $fixtureConfig -ExtensionInventory @() -ExtensionRoot $fixtureRoot
        Assert-True (-not $hashOnly.Compliant) 'a theme file that VS Code does not report is rejected'
    } finally {
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    }
    Assert-True ($state -match 'Get-BergExtensionState') 'live state validates the discovered Berg contribution'
    Assert-True ($state -notmatch '--install-extension[^\r\n]+--force') 'extension reconciliation does not force dependency downgrades'
}

function Test-AiDistributionIdentity {
    $sample = Get-RequiredText '.wsl-env.sample'
    $import = Get-RequiredText 'scripts/Import-WslEnvironment.ps1'
    Assert-True ($sample -match '(?m)^WSL_AI_DISTRIBUTION=NixOS-AI$' -and $sample -match '(?m)^WSL_AI_USER=') 'AI selectors are public'
    Assert-True ($import -match 'four.*distribution|AI.*different|distinct' -and $import -match 'WSL_AI_DISTRIBUTION') 'all four distro identities must differ'
}

function Test-AiNixIntegrity {
    $config = Get-RequiredData 'config/ai-nixos-wsl.psd1'
    $selfCheck = Get-RequiredText 'nixos-ai/self-check.nix'
    foreach ($check in @('StoreIntegrity', 'SourceIntegrity', 'CommandIntegrity', 'BoundaryIntegrity')) {
        Assert-True ($selfCheck -match $check) "AI self-check includes $check"
    }
    Assert-True ($config.SourceFiles -contains 'self-check.nix') 'AI sources are manifest-verified'
}

function Test-NonoInstallChannel {
    $config = Get-RequiredData 'config/ai-nixos-wsl.psd1'
    Assert-True ($config.Nono.InstallCommand -eq 'brew install nono' -and $config.Nono.OwnerUser -ne $config.DailyUserVariable) 'nono uses Brew under a separate owner'
}

function Test-NonoLaunchContract {
    $text = Get-RequiredText 'scripts/Invoke-OpenCodeSandbox.ps1'
    Assert-True ($text -match 'nono' -and $text -match 'opencode' -and $text -match 'nolabs-ai/opencode') 'managed launch uses the reviewed nono lineage'
}

function Test-NonoFailClosed {
    $text = (Get-RequiredText 'scripts/Invoke-OpenCodeSandbox.ps1') + "`n" + (Get-RequiredText 'nixos-ai/configuration.nix')
    Assert-True ($text -match 'setup --check-only' -and $text -match 'throw|exit 2') 'launch fails before agent startup when setup fails'
    Assert-True ($text -notmatch 'insecure_proxy') 'insecure WSL proxy fallback is never enabled'
}

function Test-NonoFilesystemPolicy {
    $profileText = Get-RequiredText 'nixos-ai/opencode-profile.json'
    Assert-True ($profileText -match 'workdir' -and $profileText -match 'readwrite' -and $profileText -match 'deny') 'profile grants the project and contains explicit denials'
}

function Test-NonoCredentialPolicy {
    $profileText = Get-RequiredText 'nixos-ai/opencode-profile.json'
    foreach ($token in @('.ssh', '.aws', '.azure', '.kube', 'docker.sock')) { Assert-True ($profileText -match [regex]::Escape($token)) "profile denies $token" }
}

function Test-NonoNetworkPolicy {
    $profileText = Get-RequiredText 'nixos-ai/opencode-profile.json'
    $launcher = Get-RequiredText 'scripts/Invoke-OpenCodeSandbox.ps1'
    Assert-True ($profileText -match 'network_profile|allow_domain' -and $launcher -match 'NetworkEnforcement') 'network policy is declared and gated'
}

function Test-NonoProfileDrift {
    $config = Get-RequiredData 'config/ai-nixos-wsl.psd1'
    $script = Get-RequiredText 'scripts/Set-AiNixOsWslState.ps1'
    Assert-True ($config.Nono.ProfileSha256 -match '^[a-f0-9]{64}$' -and $script -match 'ProfileSha256') 'profile drift is hash-checked'
}

function Test-AiDailyPrivilege {
    $config = (Get-RequiredText 'nixos-ai/configuration.nix') + "`n" + (Get-RequiredText 'nixos-ai/local.nix.in')
    Assert-True ($config -match 'isNormalUser\s*=\s*true' -and $config -match 'wheel.*false|extraGroups\s*=\s*\[\s*\]') 'AI daily user has no admin group'
    Assert-True ($config -match 'ai-maint' -and $config -match 'isSystemUser|isNormalUser\s*=\s*false') 'maintenance identity is non-login/non-daily'
}

function Test-AiInteropBoundary {
    $config = Get-RequiredText 'nixos-ai/configuration.nix'
    Assert-True ($config -match 'interop[\s\S]*enabled\s*=\s*false' -and $config -match 'appendWindowsPath\s*=\s*false') 'AI interop and Windows PATH are disabled'
}

function Test-AiMountBoundary {
    $config = Get-RequiredText 'nixos-ai/configuration.nix'
    Assert-True ($config -match 'automount[\s\S]*enabled\s*=\s*false') 'AI Windows-drive automount is disabled'
}

function Test-DevOpsInteropBoundary {
    $config = Get-RequiredText 'nixos/configuration.nix'
    Assert-True ($config -match 'interop[\s\S]*enabled\s*=\s*false' -and $config -match 'automount[\s\S]*enabled\s*=\s*false') 'DevOps NixOS host integration is disabled'
    Assert-True ((Get-RequiredText 'scripts/Set-NixOsWslState.ps1') -match 'StandardInput|stdin|InputObject') 'DevOps deployment no longer needs DrvFS'
}

function Test-DevOpsCredentialBoundary {
    $config = Get-RequiredData 'config/wsl-trust-boundaries.psd1'
    $devops = @($config.Distributions | Where-Object Role -eq 'DevOps')[0]
    Assert-True ($devops.CredentialPaths.Count -gt 0 -and $devops.ReadSecretContent -eq $false) 'DevOps credential checks are metadata-only'
}

function Test-MalwareWslBoundary {
    $config = Get-RequiredData 'config/wsl-trust-boundaries.psd1'
    $mw = @($config.Distributions | Where-Object Role -eq 'MalwareAnalysis')[0]
    Assert-True (-not $mw.Interop -and -not $mw.Automount -and -not $mw.Sudo) 'Debian-MW restricted boundary is declared'
    Assert-True ((Get-RequiredText 'scripts/Set-RootlessPodmanState.ps1') -match 'StandardInput|stdin|InputObject') 'Debian-MW deploy does not require a Windows mount'
}

function Test-MalwareCaseImport {
    $text = Get-RequiredText 'scripts/Import-MalwareCase.ps1'
    Assert-True ($text -match 'tar\.exe' -and $text -match 'SHA256' -and $text -match 'reparse|LinkType') 'case import streams, hashes, and rejects links'
}

function Test-MalwareCaseExport {
    $text = Get-RequiredText 'scripts/Export-MalwareCase.ps1'
    Assert-True ($text -match 'tar\.exe' -and $text -match 'SHA256' -and $text -match 'Destination') 'case export is bounded and attributable'
}

function Test-TrustedDebianRole {
    $config = Get-RequiredData 'config/wsl-trust-boundaries.psd1'
    $debian = @($config.Distributions | Where-Object Role -eq 'TrustedUtility')[0]
    Assert-True ($debian.TrustLevel -eq 'trusted' -and $debian.Interop -and $debian.Automount) 'ordinary Debian broader integration is explicit'
}

function Test-TrustMatrixStatus {
    $text = (Get-RequiredText 'scripts/Test-WslTrustBoundary.ps1') + "`n" + (Get-RequiredText 'scripts/WslBoundary.Core.ps1')
    foreach ($field in @('Role', 'TrustLevel', 'Interop', 'Automount', 'SharedPaths', 'Credentials', 'ResidualHostAccess')) {
        Assert-True ($text -match $field) "trust report includes $field"
    }
}

function Test-BoundaryFailure {
    $text = (Get-RequiredText 'scripts/Test-WslTrustBoundary.ps1') + "`n" + (Get-RequiredText 'scripts/WslBoundary.Core.ps1')
    Assert-True ($text -match 'exit 1|exit 2' -and $text -match 'Failures|Pending') 'boundary drift returns actionable nonzero status'
}

function Test-UpdateRevalidation {
    $text = (Get-RequiredText 'scripts/Invoke-WorkstationUpdate.ps1') + "`n" +
        (Get-RequiredText 'scripts/Set-AiToolsState.ps1') + "`n" + (Get-RequiredText 'scripts/Set-AiNixOsWslState.ps1')
    Assert-True ($text -match 'Get-AiToolsState' -and $text -match 'Get-LiveState' -and $text -match 'Test-WslTrustBoundary') 'updates and explicit AI reconciliation revalidate tool and boundary provenance'
}

function Test-RoutingAndDocumentation {
    $capabilities = Get-RequiredData 'config/capabilities.psd1'
    $route = @($capabilities.Capabilities | Where-Object Id -eq 'ai-tools-isolation')[0]
    Assert-True ($route.FeatureSpec -eq 'specs/010-ai-tools-isolation' -and $route.StateCommands.Count -gt 0) 'AI capability is governed and human-routable'
    Assert-True (Test-Path (Join-Path $repositoryRoot 'docs/ai-tools-isolation.md')) 'operator documentation exists'
}

function Test-FocusedModuleBoundary {
    foreach ($name in @('AiTools', 'AiNixOsWsl', 'DeveloperEditor')) {
        Assert-True ((Get-WorkstationModule $name).Description -notmatch 'malware execution|forensic acquisition|Exploit Protection') "$name remains focused"
    }
}

function Test-PortableSecretExclusions {
    $ignore = Get-RequiredText '.gitignore'
    foreach ($token in @('.wsl-env', '.terminal-fonts', 'state/ai', 'state/cases')) { Assert-True ($ignore -match [regex]::Escape($token)) "$token is excluded" }
    $tracked = @(git -C $repositoryRoot ls-files)
    Assert-True (@($tracked | Where-Object { $_ -match '(?i)(id_rsa|id_ed25519|\.pem$|\.key$|case-evidence|\.terminal-fonts$|\.wsl-env$)' }).Count -eq 0) 'portable files contain no obvious private material'
}

$sections = if ($Section -eq 'All') {
    @('EnabledProducts', 'OptInBoundary', 'ObservationalStatus', 'OutputParity', 'OpenCodeTargets',
        'ClaudeInstallChannel', 'AntigravityCliChannel', 'ClineCliChannel', 'CopilotCli',
        'EditorInventory', 'LocalFontPreference', 'PortableFontFallback', 'EditorMerge', 'BergActivation',
        'AiDistributionIdentity', 'AiNixIntegrity', 'NonoInstallChannel', 'NonoLaunchContract',
        'NonoFailClosed', 'NonoFilesystemPolicy', 'NonoCredentialPolicy', 'NonoNetworkPolicy',
        'NonoProfileDrift', 'AiDailyPrivilege', 'AiInteropBoundary', 'AiMountBoundary',
        'DevOpsInteropBoundary', 'DevOpsCredentialBoundary', 'MalwareWslBoundary',
        'MalwareCaseImport', 'MalwareCaseExport', 'TrustedDebianRole', 'TrustMatrixStatus',
        'BoundaryFailure', 'UpdateRevalidation', 'RoutingAndDocumentation', 'FocusedModuleBoundary',
        'PortableSecretExclusions')
} else { @($Section) }

foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}
Write-Host "AI tools and WSL isolation tests passed ($script:assertions assertions)."
