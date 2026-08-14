@{
    SchemaVersion = 1
    Package = @{
        Name = 'Fira Code'
        Version = '6.2'
        Uri = 'https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip'
        Sha256 = '0949915ba8eb24d89fd93d10a7ff623f42830d7c5ffc3ecbf960e4ecad3e3e79'
    }
    InstallDirectory = '%LOCALAPPDATA%\Microsoft\Windows\Fonts'
    RegistryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    BackupDirectory = 'state\font-backups'
    Fonts = @(
        @{ FileName = 'FiraCode-Bold.ttf'; RegistryName = 'Fira Code Bold (TrueType)'; Sha256 = '41f6554e845e2f5b70adad3950122334b866aac436793b7742ade600067701be' }
        @{ FileName = 'FiraCode-Light.ttf'; RegistryName = 'Fira Code Light (TrueType)'; Sha256 = 'c146c9a7a61914f9f5a47d24c199c50c8f143f5710b93efd3a3953af50816443' }
        @{ FileName = 'FiraCode-Medium.ttf'; RegistryName = 'Fira Code Medium (TrueType)'; Sha256 = '97091f90623661fb4f7979c10d188f30f4806d8ce326b0bc8d1acc79dcc20d8f' }
        @{ FileName = 'FiraCode-Regular.ttf'; RegistryName = 'Fira Code Regular (TrueType)'; Sha256 = '5992ab9640e2df491b2f609467b1de60e8bc39b2c28db184342a0592d98f6117' }
        @{ FileName = 'FiraCode-Retina.ttf'; RegistryName = 'Fira Code Retina (TrueType)'; Sha256 = '4fe2df1cea543281e8ec0fa512d1b493eacb859cf62bc7a84886daa89268b3f3' }
        @{ FileName = 'FiraCode-SemiBold.ttf'; RegistryName = 'Fira Code SemiBold (TrueType)'; Sha256 = '500c74eec6249b06d49aef922dd3e8fc754c70c3b3f7791cd7b1a09ca9a26140' }
    )
}
