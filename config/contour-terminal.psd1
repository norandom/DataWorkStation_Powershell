@{
    SchemaVersion = 1
    Package = @{
        Version = '0.7.0.8982'
        Sha256 = '29bed53dd40ae8625a0489deaea6a7303e18678869116622cad69f687440042e'
        ProductCode = '{0E736497-2B72-4117-95E9-54EC6D000700}'
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
