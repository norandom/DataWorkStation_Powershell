@{
    SchemaVersion = 1
    Package = @{
        Version = '0.6.3.8249'
        Uri = 'https://github.com/contour-terminal/contour/releases/download/v0.6.3.8249/contour-0.6.3.8249-win64.msi'
        Sha256 = '5c8b55c5580a3e263c971c6a9a3ced35014d94b210305a8cb5099177fb89e6a0'
        ProductCode = '{0E736497-2B72-4117-95E9-54EC6D000603}'
        UpgradeCode = '{0E736497-2B72-4117-95E9-54EC6D000000}'
        DisplayName = 'Contour'
        InstallRoot = '%ProgramFiles%\Contour Terminal Emulator 0.6'
        Binary = 'bin\contour.exe'
    }
    LegacyScoopAppName = 'contour'
    ScoopRoot = '%USERPROFILE%\scoop'
    DesiredConfig = 'config\contour.yml'
    UserConfig = '%LOCALAPPDATA%\contour\contour.yml'
    FontPreferenceFile = '.terminal-fonts'
    FontPreferenceSample = '.terminal-fonts-sample'
    FontFamilyPlaceholder = '__TERMINAL_FONT_FAMILY__'
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
