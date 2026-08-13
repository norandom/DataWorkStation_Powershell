@{
    CodeQL = @{
        Version = '2.26.3'
        Url = 'https://github.com/github/codeql-cli-binaries/releases/download/v2.26.3/codeql-win64.zip'
        Sha256 = '628ab5a3cca3ed06b57d96ac6657aefe07af1546fd76893531ce7111be8f1d09'
    }
    TTD = @{
        Version = '1.11.611.0'
        Url = 'https://windbg.download.prss.microsoft.com/dbazure/prod/1-11-611-0/TTD.msixbundle'
    }
    TrailOfBitsPacks = @(
        'trailofbits/cpp-all'
        'trailofbits/cpp-queries'
        'trailofbits/go-queries'
        'trailofbits/java-queries'
    )
    DebianDistribution = 'Debian'
}
