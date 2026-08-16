@{
    SchemaVersion = 1

    Media = @{
        Description = 'Deterministic non-case test bytes'
        Pattern = 'byte[N] = ((N * 31) + 17) modulo 251'
        Length = 2621440
        MD5 = '91D8AE3BEABCD4F8469A2FCB8055BA14'
        SHA256 = 'EDFAD2B84481209605168A88120F414883D6A4072E3C283D792E2524D4EAD324'
    }

    Sets = @(
        @{
            Name = 'ordinary'
            FirstSegment = 'ordinary.E01'
            ExpectedSegmentCount = 3
            ExpectedStoredMD5 = '91D8AE3BEABCD4F8469A2FCB8055BA14'
            Segments = @(
                @{
                    Name = 'ordinary.E01'
                    Length = 1018526
                    SHA256 = '127230E674725877B7E00E18F284A0563E44C4AC967C429FBA9D659D4C1B4EE7'
                }
                @{
                    Name = 'ordinary.E02'
                    Length = 1017681
                    SHA256 = '75A8ED3DC252AF92DF18AA958D4513B914E264BA272A81102ADFF502A07B964D'
                }
                @{
                    Name = 'ordinary.E03'
                    Length = 591653
                    SHA256 = '0142DA72B11B8F1B6AF7B1321D89DDB2E8759C1ECC020C54131E30CA9544ECB8'
                }
            )
        }
        @{
            Name = 'hashless'
            FirstSegment = 'hashless.E01'
            ExpectedSegmentCount = 3
            ExpectedStoredMD5 = $null
            Segments = @(
                @{
                    Name = 'hashless.E01'
                    Length = 1018276
                    SHA256 = '03255A3A5C75D2DB4DB105DB7D6B4A2A5ECA07A165F6B4EF5B96361C1C019E15'
                }
                @{
                    Name = 'hashless.E02'
                    Length = 1017681
                    SHA256 = 'FB155C52BD08372A3AE76D726DAE5F387B11C7503A31602ECE673F3D947A1887'
                }
                @{
                    Name = 'hashless.E03'
                    Length = 591541
                    SHA256 = '10288D306DF9F3D23274A60B6EE489458700C9F3752AAA99E5698F755282F892'
                }
            )
        }
    )

    Generator = @{
        LibewfVersion = '20231119'
        VSToolsCommit = 'ce1bd73b3e23b34e98c206b26df4c2d663500554'
        MSVCCompilerVersion = '19.44.35228.0'
        MSBuildVersion = '17.14.51.32402'
        SourceSHA256 = '5C75A524782F8DFAACB24CB4D227CA9DDE59110D584EC64C92DB8A6E95D9D76C'
        ExecutableSHA256 = 'EF8F9700ABFBAA38FF489A64511045786367186C8B029A82A1D0113E7FB5F1B7'
        ExecutableCommitted = $false
    }

    Toolchain = @{
        LibewfSourceSHA256 = 'EC08D411A5DAB0ECC957D12B64AD9AE073136AA85C05B2CA77C33E03949B2AB7'
        ZlibSourceSHA256 = 'E8BF55F3017AA181690990CB58A994E77885DA140609FC8F94ABE9B65D2CAE28'
        Bzip2SourceSHA256 = 'AB5A03176EE106D3F0FA90E381DA478DDAE405918153CCA248E682CD0C4A2269'
        EwfAcquireStreamSHA256 = '57DC2709E66E9195EF5132468BC58E4FECBD4A70F307B7CB1D840CA1C1344A9D'
        EwfVerifySHA256 = '4B592FA9ADD6118D40818DE9202AB7E3AC2F38817C7EE83DFC57840EDA5E6D90'
        LibewfDllSHA256 = 'C8AFE83AE817F7EE1D192B1114D23CB0638A9C0886F2ACC7348C13D18224241D'
        ZlibDllSHA256 = '729CC00D0BD3548A5C4586B3B3238E79F13718175F001C8FC7D66750BF9BD9EA'
    }
}
