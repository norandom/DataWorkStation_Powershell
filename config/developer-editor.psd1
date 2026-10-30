@{
    SchemaVersion = 1
    PackageId = 'Microsoft.VisualStudioCode'
    PackageConfiguration = '.config/developer-editor.winget'
    Command = 'code'
    CommandDirectory = '%USERPROFILE%\.local\bin'
    SupersededPath = '%LOCALAPPDATA%\AMD\AI_Bundle\VSCode\bin'
    Launchers = @(
        @{
            Name = 'code'
            RegisteredApplicationName = 'Microsoft Visual Studio Code'
            RegisteredPublisher = 'Microsoft Corporation'
            Candidates = @('%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd', '%ProgramFiles%\Microsoft VS Code\bin\code.cmd')
            RequiredSibling = '..\Code.exe'
        }
        @{
            Name = 'zed'
            Candidates = @('%LOCALAPPDATA%\Programs\Zed\bin\zed.exe', '%ProgramFiles%\Zed\bin\zed.exe')
            RequiredSibling = 'zed.exe'
        }
    )
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
        ExtensionId = 'teehausamberg.berg'
        ExtensionVersion = '0.0.4'
        DisplayName = 'Berg Theme'
        ThemeLabel = 'Berg Theme'
        ExtensionRoot = '%USERPROFILE%\.vscode\extensions'
    }
    SettingsPath = '%APPDATA%\Code\User\settings.json'
    BackupDirectory = 'state\developer-editor-backups'
    PortableFontFamily = 'Fira Code'
    ManagedSettings = @(
        'workbench.colorTheme'
        'editor.fontFamily'
        'terminal.integrated.fontFamily'
    )
}
