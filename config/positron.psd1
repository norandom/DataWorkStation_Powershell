@{
    SchemaVersion = 1
    Product = @{
        Name = 'Positron'
        Release = '2026.08.1-2'
        MinimumProductVersion = '2026.8.1.0'
        Architecture = 'x64'
        InstallerUri = 'https://cdn.posit.co/positron/releases/win/x86_64/Positron-2026.08.1-2-UserSetup-x64.exe'
        InstallerSha256 = 'ea67b92db7afb263b3cbd370ecaa82c8ec136d4ca1da5be083b5fdcde981dc26'
        LicenseUri = 'https://positron.posit.co/licensing.html'
        DownloadPage = 'https://positron.posit.co/download.html'
        PublisherPattern = 'Posit Software'
        InstallRoot = '%LOCALAPPDATA%\Programs\Positron'
        Executable = 'Positron.exe'
        Command = 'bin\positron.cmd'
        InstallerArguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-')
    }
}
