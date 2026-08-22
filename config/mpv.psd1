@{
    SchemaVersion = 1
    PackageId = 'mpv-player.mpv-CI.MSVC'
    PackageConfiguration = '.config\mpv.winget'
    ManagedConfiguration = 'config\mpv.conf'
    UserConfiguration = '%APPDATA%\mpv\mpv.conf'
    CommandPath = '%USERPROFILE%\.local\bin\mpv.cmd'
    BackupDirectory = 'state\mpv-config-backups'
    ManagedBlockBegin = '# BEGIN DATAWORKSTATION MPV GPU'
    ManagedBlockEnd = '# END DATAWORKSTATION MPV GPU'
    RequiredHardwareDecoder = 'd3d11va'
}
