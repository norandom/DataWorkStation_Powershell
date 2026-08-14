@{
    SchemaVersion = 1
    PackageId = 'frippery.busybox-w32'
    PackageCommand = 'busybox.exe'
    PackageDirectoryPrefix = 'frippery.busybox-w32_'
    PackageExecutable = 'busybox.exe'
    ShimDirectory = '.local\bin'
    Applets = @('awk', 'sed')
}
