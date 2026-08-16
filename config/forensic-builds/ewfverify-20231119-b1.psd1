@{
    SchemaVersion = 1
    RecordId = 'forensic-ewfverify-20231119-b1'
    ReviewState = 'Candidate'
    ToolId = 'ewfverify'
    UpstreamVersion = '20231119'
    BuildRevision = 'b1'
    Target = @{
        OperatingSystem = 'Windows'
        Architecture = 'x64'
        PeMachine = 'AMD64'
        Configuration = 'Release'
    }
    SourceArtifacts = @(
        @{
            ArtifactId = 'libewf-source-20231119'
            FileName = 'libewf-experimental-20231119.tar.gz'
            Size = 2659358
            Sha256 = 'EC08D411A5DAB0ECC957D12B64AD9AE073136AA85C05B2CA77C33E03949B2AB7'
            Url = 'https://github.com/libyal/libewf/releases/download/20231119/libewf-experimental-20231119.tar.gz'
            SignatureArtifactId = 'libewf-signature-20231119'
            License = 'LGPL-3.0-or-later'
        }
        @{
            ArtifactId = 'libewf-signature-20231119'
            FileName = 'libewf-experimental-20231119.tar.gz.asc'
            Size = 488
            Sha256 = 'E38080BBDD22E4652E03F02635F2BC10C94CB46A51EF784AB8C8E93CE3A72EF7'
            Url = 'https://github.com/libyal/libewf/releases/download/20231119/libewf-experimental-20231119.tar.gz.asc'
            Authenticity = 'DetachedOpenPgpSignature'
        }
        @{
            ArtifactId = 'zlib-source-1.3.2'
            FileName = 'zlib132.zip'
            Size = 1616754
            Sha256 = 'E8BF55F3017AA181690990CB58A994E77885DA140609FC8F94ABE9B65D2CAE28'
            Url = 'https://github.com/madler/zlib/releases/download/v1.3.2/zlib132.zip'
            License = 'Zlib'
        }
        @{
            ArtifactId = 'bzip2-source-1.0.8'
            FileName = 'bzip2-1.0.8.tar.gz'
            Size = 810029
            Sha256 = 'AB5A03176EE106D3F0FA90E381DA478DDAE405918153CCA248E682CD0C4A2269'
            Url = 'https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz'
            License = 'bzip2-1.0.6'
        }
    )
    SignatureVerification = @{
        Provider = 'GnuPG-Standalone-Windows'
        InstallerFileName = 'gnupg-w32-2.5.21_20260702.exe'
        InstallerUrl = 'https://gnupg.org/ftp/gcrypt/binary/gnupg-w32-2.5.21_20260702.exe'
        InstallerSize = 5772160
        InstallerSha256 = '6246C925A73167253444AFC24A0DEB83A3F43B7D636AF84D6AAF48A98A62F024'
        AuthenticodeSubject = 'CN=g10 Code GmbH, O=g10 Code GmbH, L=Erkrath, C=DE'
        AuthenticodeThumbprint = '83CC4E382E5E4AF554C66E429E8F66FFE499910D'
        Executable = 'gpgv.exe'
        KeyFile = 'keys/libyal-0ED9020DA90D3F6E70BD3945D9625E5D7AD0177E.asc'
        SignerFingerprint = '0ED9020DA90D3F6E70BD3945D9625E5D7AD0177E'
        IsolatedKeyring = $true
    }
    Converter = @{
        Repository = 'https://github.com/libyal/vstools.git'
        Commit = 'ce1bd73b3e23b34e98c206b26df4c2d663500554'
        GitHubVerification = 'valid'
        PythonVersion = '3.12.10'
    }
    Toolchain = @{
        Product = 'Microsoft.VisualStudio.Product.BuildTools'
        VisualStudioVersion = '17.14.37516.0'
        MsvcToolsVersion = '14.44.35207'
        PlatformToolset = 'v143'
        WindowsSdkVersion = '10.0.26100.0'
        Architecture = 'x64'
        Compiler = 'cl.exe'
        Linker = 'link.exe'
        BuildEngine = 'MSBuild.exe'
    }
    Build = @{
        Workflow = '.github/workflows/forensic-tool-build.yml'
        RunnerLabel = 'windows-2025'
        ResolvedRunnerImageRequired = $true
        RepositoryCommitRequired = $true
        Arguments = @('/m:1', '/p:Configuration=Release', '/p:Platform=x64', '/p:PlatformToolset=v143', '/p:WindowsTargetPlatformVersion=10.0.26100.0')
        RuntimeCompilationAllowed = $false
    }
    Package = @{
        AssetName = 'ewfverify-20231119-windows-x64-b1.zip'
        ReleaseTag = 'forensic-ewfverify-20231119-b1'
        AllowedRuntimeFiles = @('ewfverify.exe', 'libewf.dll', 'zlib.dll')
        RequiredMetadataFiles = @('manifest.json', 'checksums.sha256', 'LICENSE-libewf.txt', 'LICENSE-zlib.txt', 'LICENSE-bzip2.txt', 'sbom.spdx.json', 'provenance.json')
        ForbiddenImports = @('cygwin1.dll', 'msys-2.0.dll', 'libwinpthread-1.dll', 'ws2_32.dll', 'winhttp.dll', 'wininet.dll')
        AllowedImports = @('kernel32.dll', 'vcruntime140.dll', 'api-ms-win-crt-*.dll', 'libewf.dll', 'zlib.dll')
    }
    ParserProfile = @{
        Id = 'libewf-20231119-en-us-v1'
        Banner = 'ewfverify 20231119'
        SupportedStatusGrammar = 1
    }
}
