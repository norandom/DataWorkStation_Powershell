@{
    SchemaVersion = 1
    Products = @(
        @{
            Name = 'OpenCode Desktop'
            Enabled = $true
            Target = 'Windows'
            Channel = 'GitHubRelease'
            Command = $null
            InstallerMode = 'ExtractedRelease'
            Version = '1.18.19'
            Sha256 = '59f19cebc0b0de0303b20b73686d5cfbf9734a8d4ab152d02719ebf95e714c87'
            InstallPath = '%LOCALAPPDATA%\Programs\OpenCode\OpenCode.exe'
            ShortcutPath = '%APPDATA%\Microsoft\Windows\Start Menu\Programs\OpenCode.lnk'
            FormerScoopPackage = 'opencode-desktop'
            FormerScoopPath = '%USERPROFILE%\scoop\apps\opencode-desktop\current\OpenCode.exe'
        }
        @{
            Name = 'OpenCode CLI'
            Enabled = $true
            Target = 'Windows'
            Channel = 'NpmGlobal'
            Command = 'opencode'
            NpmPackage = 'opencode-ai'
            InstallCommand = 'npm install -g opencode-ai'
            ExpectedPath = '%APPDATA%\npm\opencode.cmd'
            FormerScoopPackage = 'opencode'
            FormerScoopPath = '%USERPROFILE%\scoop\shims\opencode.exe'
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
            Name = 'Cursor CLI'
            Enabled = $true
            Target = 'Windows'
            Channel = 'OfficialPowerShell'
            Command = 'cursor-cli'
            InstallCommand = "irm 'https://cursor.com/install?win32=true' | iex"
            ExpectedPath = '%LOCALAPPDATA%\cursor-agent\cursor-agent.cmd'
            CommandShimPath = '%LOCALAPPDATA%\Microsoft\WinGet\Links\cursor-cli.cmd'
            ForbiddenCommandPaths = @(
                '%LOCALAPPDATA%\cursor-agent\agent.exe'
                '%LOCALAPPDATA%\cursor-agent\agent.cmd'
                '%LOCALAPPDATA%\cursor-agent\agent.ps1'
            )
        }
        @{
            Name = 'Grok Build CLI'
            Enabled = $true
            Target = 'Windows'
            Channel = 'OfficialPowerShell'
            Command = 'grok'
            InstallCommand = 'irm https://x.ai/cli/install.ps1 | iex'
            ExpectedPath = '%USERPROFILE%\.grok\bin\grok.exe'
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
            Channel = 'OfficialBash'
            Command = 'copilot'
            InstallCommand = 'curl -fsSL https://gh.io/copilot-install | bash'
            ExpectedPath = '%LOCALAPPDATA%\Microsoft\WinGet\Packages\GitHub.Copilot_Microsoft.Winget.Source_8wekyb3d8bbwe\copilot.exe'
            CommandShimPath = '%LOCALAPPDATA%\Microsoft\WinGet\Links\copilot.cmd'
        }
    )
}
