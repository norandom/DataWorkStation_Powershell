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
