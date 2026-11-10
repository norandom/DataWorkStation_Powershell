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
        Version = '0.21.11'
        Sha256 = '7afd2804cbc66463a31d6bddc79e93504e1b467cfc70773a040304e493951ea0'
        EngineImage = 'registry.dagger.io/engine:v0.21.11'
        Machine = 'podman-machine-default'
    }
    TrailOfBitsPacks = @(
        'trailofbits/cpp-all'
        'trailofbits/cpp-queries'
        'trailofbits/go-queries'
        'trailofbits/java-queries'
    )
}
