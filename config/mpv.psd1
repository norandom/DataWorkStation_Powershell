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
    VideoAssociations = @{
        ApplicationName = 'mpv Video'
        ProgId = 'DataWorkStation.mpv.Video'
        CapabilitiesPath = 'Software\DataWorkStation\MpvVideo\Capabilities'
        Extensions = @('.3g2', '.3gp', '.avi', '.flv', '.ivf', '.m2ts', '.m4v', '.mkv', '.mov', '.mp4', '.mpeg', '.mpg', '.mxf', '.ogv', '.rmvb', '.webm', '.wmv', '.y4m')
    }
}
