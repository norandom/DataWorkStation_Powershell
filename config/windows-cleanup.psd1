@{
    SchemaVersion = 1
    Volume = 'C:'
    StateFlag = 9347
    ComponentStoreCleanup = $true
    DiskCleanupHandlers = @(
        'Delivery Optimization Files'
        'Diagnostic Data Viewer database files'
        'Feedback Hub Archive log files'
        'Setup Log Files'
        'Temporary Files'
        'Temporary Setup Files'
        'Update Cleanup'
        'Windows Error Reporting Files'
        'Windows Reset Log Files'
        'Windows Upgrade Log Files'
    )
    Preserved = @(
        'Prefetch'
        'Event logs'
        'D3D Shader Cache'
        'Thumbnail Cache'
        'System error memory dump files'
        'System error minidump files'
        'Device Driver Packages'
        'DownloadsFolder'
        'Recycle Bin'
        'Previous Installations'
        'Windows ESD installation files'
    )
    RestorePoints = @{
        Enabled = $true
        KeepNewest = 1
        ConfirmationSwitch = 'ConfirmRestorePoints'
    }
}
