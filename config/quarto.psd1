@{
    SchemaVersion = 1
    Package = @{
        Version = '1.10.18'
        Repository = 'quarto-dev/quarto-cli'
        Uri = 'https://github.com/quarto-dev/quarto-cli/releases/download/v1.10.18/quarto-1.10.18-win.zip'
        Sha256 = '4e824652ff0da3f646868277582ed59c0872d1456e35350b7d7cdc4243ee18c2'
        InstallRoot = '%LOCALAPPDATA%\Programs\Quarto'
        Command = 'bin\quarto.cmd'
    }
    TinyTeX = @{
        InstallRoot = '%APPDATA%\TinyTeX'
        UpdatePath = $false
    }
    QuantConfiguration = 'config\quant-research.psd1'
}
