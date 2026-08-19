@{
    CodeQL = @{
        Version = '2.26.3'
        Sha256 = '628ab5a3cca3ed06b57d96ac6657aefe07af1546fd76893531ce7111be8f1d09'
    }
    TTD = @{
        Version = '1.11.611.0'
        Url = 'https://windbg.download.prss.microsoft.com/dbazure/prod/1-11-611-0/TTD.msixbundle'
    }
    Dagger = @{
        Version = '0.21.8'
        Formula = 'dagger/tap/dagger'
        BrewPath = '/home/linuxbrew/.linuxbrew/bin/brew'
        Executable = '/home/linuxbrew/.linuxbrew/bin/dagger'
        Deploy = 'linux/developer_tools.py'
    }
    TrailOfBitsPacks = @(
        'trailofbits/cpp-all'
        'trailofbits/cpp-queries'
        'trailofbits/go-queries'
        'trailofbits/java-queries'
    )
}
