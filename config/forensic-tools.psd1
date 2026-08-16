@{
    SchemaVersion = 1
    Records = @(
        @{
            RecordId = 'forensic-ewfverify-20231119-b1'
            ToolId = 'ewfverify'
            UpstreamVersion = '20231119'
            BuildRevision = 'b1'
            ReviewState = 'Candidate'
            InstallRoot = '%LOCALAPPDATA%\Programs\DataWorkStation\Forensics\ewfverify-20231119-b1'
            SupportedFormats = @(
                @{ ProfileId = 'encase6-classic-e01'; Family = 'E01'; FirstExtension = '.E01'; MaximumOrdinal = 99 }
            )
            ParserProfile = @{
                Id = 'libewf-20231119-en-us-v1'
                Banner = 'ewfverify 20231119'
                SupportedStatusGrammar = 1
            }
            ReleaseIdentity = @{
                Repository = 'norandom/PowerShell'
                Tag = 'forensic-ewfverify-20231119-b1'
                AssetName = 'ewfverify-20231119-windows-x64-b1.zip'
                AssetUrl = 'https://github.com/norandom/PowerShell/releases/download/forensic-ewfverify-20231119-b1/ewfverify-20231119-windows-x64-b1.zip'
                AssetSize = $null
                PackageSha256 = $null
                AttestationIdentity = $null
            }
            SourceArtifacts = @(
                @{ Name = 'libewf-experimental-20231119.tar.gz'; Size = 2659358; Sha256 = 'EC08D411A5DAB0ECC957D12B64AD9AE073136AA85C05B2CA77C33E03949B2AB7'; Origin = 'https://github.com/libyal/libewf/releases/download/20231119/libewf-experimental-20231119.tar.gz'; SignatureSha256 = 'E38080BBDD22E4652E03F02635F2BC10C94CB46A51EF784AB8C8E93CE3A72EF7'; Authenticity = 'DetachedSignaturePendingBuildVerification' }
                @{ Name = 'zlib132.zip'; Size = 1616754; Sha256 = 'E8BF55F3017AA181690990CB58A994E77885DA140609FC8F94ABE9B65D2CAE28'; Origin = 'https://github.com/madler/zlib/releases/download/v1.3.2/zlib132.zip'; Authenticity = 'PinnedUpstreamReleaseDigest' }
                @{ Name = 'bzip2-1.0.8.tar.gz'; Size = 810029; Sha256 = 'AB5A03176EE106D3F0FA90E381DA478DDAE405918153CCA248E682CD0C4A2269'; Origin = 'https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz'; Authenticity = 'PinnedUpstreamReleaseDigest' }
            )
            BuildIdentity = @{
                BuildRecordSha256 = 'F5253B5D8ADC42B1286EC54BB96A35C0B219005892DBF99BE9BF4ECF09ABBF20'
                Commit = $null
                Workflow = '.github/workflows/forensic-tool-build.yml'
                Runner = 'windows-2025; exact image required in provenance'
                Architecture = 'x64'
                Compiler = 'MSVC 14.44.35207'
                Linker = 'Microsoft LINK 14.44.35207'
                MSBuild = '17.14.37516.0'
                WindowsSdk = '10.0.26100.0'
                ConverterCommit = 'ce1bd73b3e23b34e98c206b26df4c2d663500554'
                Arguments = @('Release', 'x64', 'v143', '10.0.26100.0')
                SbomSha256 = $null
            }
            PackageFiles = @(
                @{ RelativePath = 'ewfverify.exe'; Role = 'Executable'; Size = $null; Sha256 = $null; PeMachine = 'AMD64'; ExpectedImports = @() }
                @{ RelativePath = 'libewf.dll'; Role = 'Dependency'; Size = $null; Sha256 = $null; PeMachine = 'AMD64'; ExpectedImports = @() }
                @{ RelativePath = 'zlib.dll'; Role = 'Dependency'; Size = $null; Sha256 = $null; PeMachine = 'AMD64'; ExpectedImports = @() }
                @{ RelativePath = 'manifest.json'; Role = 'Manifest'; Size = $null; Sha256 = $null }
                @{ RelativePath = 'checksums.sha256'; Role = 'Checksums'; Size = $null; Sha256 = $null }
                @{ RelativePath = 'LICENSE-libewf.txt'; Role = 'License'; Size = $null; Sha256 = $null }
                @{ RelativePath = 'LICENSE-zlib.txt'; Role = 'License'; Size = $null; Sha256 = $null }
                @{ RelativePath = 'LICENSE-bzip2.txt'; Role = 'License'; Size = $null; Sha256 = $null }
                @{ RelativePath = 'sbom.spdx.json'; Role = 'Sbom'; Size = $null; Sha256 = $null }
                @{ RelativePath = 'provenance.json'; Role = 'Provenance'; Size = $null; Sha256 = $null }
            )
            LicenseSummary = @{
                Spdx = @('LGPL-3.0-or-later', 'Zlib', 'bzip2-1.0.6')
                Paths = @('LICENSE-libewf.txt', 'LICENSE-zlib.txt', 'LICENSE-bzip2.txt')
            }
            Certification = @{
                CorpusVersion = '008-v1'
                Lanes = @('WindowsPowerShell-5.1', 'PowerShell-7')
                Result = 'Pending'
                WorkflowRun = $null
                AttestationIdentity = $null
                ReviewedBuildSha256 = $null
                ApprovalDecision = $null
                Reviewer = $null
                ReviewedAtUtc = $null
            }
        }
    )
}
