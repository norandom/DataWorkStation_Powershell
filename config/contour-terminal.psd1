@{
    SchemaVersion = 1
    Package = @{
        Version = '0.8.0.9335'
        Sha256 = '7f426f0ccbf0ea12204945c4c5dd01428107c7541d48e3498d297b033326c7d8'
        ProductCode = '{0E736497-2B72-4117-95E9-54EC6D000800}'
        UpgradeCode = '{0E736497-2B72-4117-95E9-54EC6D000000}'
        DisplayName = 'Contour'
        InstallRoot = '%ProgramFiles%\Contour Terminal Emulator 0.6'
        Binary = 'bin\contour.exe'
    }
    LegacyScoopAppName = 'contour'
    ScoopRoot = '%USERPROFILE%\scoop'
    DesiredConfig = 'config\contour.yml'
    UserConfig = '%LOCALAPPDATA%\contour\contour.yml'
    FontFamilyPlaceholder = '__TERMINAL_FONT_FAMILY__'
    WslProfilePlaceholders = @{
        '__WSL_DEVELOPER__' = 'developer'
        '__WSL_MALWARE__' = 'malware'
        '__WSL_NIXOS__' = 'nixos'
        '__WSL_AI__' = 'ai'
    }
    BackupDirectory = 'state\contour-backups'
    DesktopShortcutName = 'Contour Terminal Emulator.lnk'
    LegacyDesktopShortcutName = 'Contour.lnk'
    ThemeSource = '%USERPROFILE%\Source\BlueTerm'
    GraphicsCompatibilityGate = @{
        Enabled = $true
        MinimumRuntimeSeconds = 2
        TimeoutSeconds = 15
        PingCount = 4
    }
}
