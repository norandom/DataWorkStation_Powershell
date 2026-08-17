@{
    SchemaVersion = 1
    Products = @(
        @{
            Name = 'OpenCode Desktop'
            Enabled = $true
            Target = 'Windows'
            Channel = 'GitHubRelease'
            Command = $null
            Version = '1.18.18'
            Uri = 'https://github.com/anomalyco/opencode/releases/download/v1.18.18/opencode-desktop-win-x64.exe'
            Sha256 = 'f46c9420df889483d64fcb96637adfced89e9b3a1895fb6cc913caa0d6ee1962'
            InstallPath = '%LOCALAPPDATA%\Programs\OpenCode\OpenCode.exe'
            InstallArguments = @('/S')
        }
        @{
            Name = 'Claude Code'
            Enabled = $true
            Target = 'Windows'
            Channel = 'OfficialPowerShell'
            Command = 'claude'
            InstallCommand = 'irm https://claude.ai/install.ps1 | iex'
            ExpectedPath = '%USERPROFILE%\.local\bin\claude.exe'
            ForbiddenPathPattern = '(?i)\\Microsoft\\WinGet\\Packages\\Anthropic\.ClaudeCode_'
        }
        @{
            Name = 'Antigravity CLI'
            Enabled = $true
            Target = 'Windows'
            Channel = 'OfficialPowerShell'
            Command = 'agy'
            InstallCommand = 'irm https://antigravity.google/cli/install.ps1 | iex'
            ExpectedPath = '%LOCALAPPDATA%\agy\bin\agy.exe'
        }
        @{
            Name = 'Cline CLI'
            Enabled = $true
            Target = 'Windows'
            Channel = 'NpmGlobal'
            Command = 'cline'
            NpmPackage = 'cline'
            InstallCommand = 'npm i -g cline'
        }
        @{
            Name = 'GitHub Copilot CLI'
            Enabled = $true
            Target = 'Windows'
            Channel = 'NpmGlobal'
            Command = 'copilot'
            NpmPackage = '@github/copilot'
            InstallCommand = 'npm i -g @github/copilot'
        }
    )
}
