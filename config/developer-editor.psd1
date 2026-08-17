@{
    SchemaVersion = 1
    PackageId = 'Microsoft.VisualStudioCode'
    PackageConfiguration = '.config/developer-editor.winget'
    Command = 'code'
    Extensions = @(
        'saoudrizwan.claude-dev'
        'ms-toolsai.jupyter'
        'ms-python.python'
        'GitHub.copilot-chat'
    )
    Berg = @{
        Repository = 'https://github.com/jx22/berg'
        Commit = '32e03bf59ae9408edc2d0c382a7003a57f1d2bc0'
        Uri = 'https://raw.githubusercontent.com/jx22/berg/32e03bf59ae9408edc2d0c382a7003a57f1d2bc0/Berg%20Theme-color-theme.json'
        Sha256 = '290433bf27cd893a3f13bd3c5e01238f0885d1dbbad7934bfc20f9f63b3873e1'
        ExtensionId = 'dataworkstation.berg'
        ExtensionVersion = '1.0.0'
        DisplayName = 'Berg'
        ThemeLabel = 'Berg'
        InstallDirectory = '%USERPROFILE%\.vscode\extensions\dataworkstation.berg-1.0.0'
    }
    SettingsPath = '%APPDATA%\Code\User\settings.json'
    BackupDirectory = 'state\developer-editor-backups'
    LocalFontPreference = '.terminal-fonts'
    PortableFontFamily = 'Fira Code'
    ManagedSettings = @(
        'workbench.colorTheme'
        'editor.fontFamily'
        'terminal.integrated.fontFamily'
    )
}
