@{
    SchemaVersion = 1
    Package = @{
        Version = '4.23.1'
        Tag = 'autopsy-4.23.1'
        AssetName = 'autopsy-4.23.1-64bit.msi'
        Uri = 'https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.23.1/autopsy-4.23.1-64bit.msi'
        Size = 1289204224
        Sha256 = 'F0F368E10CF615A805C85248356673A00C88A5E19C3B632859A1C98569AE03B6'
        SignatureUri = 'https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.23.1/autopsy-4.23.1-64bit.msi.asc'
        SignatureSha256 = '9CADE64F1B5A8B1B2606BAA3BE42D8BE79D4FBE79E11236AD7BF77760929C037'
        SigningKeyFingerprint = '0917A7EE58A9308B13D3963338AD602EC7454C8B'
        AuthenticodeSigner = 'CN=Sleuth Kit Labs LLC'
        AuthenticodeThumbprint = '920137D9E87EFED2EF5A5B620F9CDE1432A474F8'
        ProductCode = '{FA56FDAD-66A0-40DB-A0E9-3F8FCBFF40B6}'
        UpgradeCode = '{6AAD1A1D-40C1-4515-B4D6-EA5A167FFA77}'
        DisplayName = 'Autopsy'
        Publisher = 'Sleuth Kit Labs'
        InstallRoot = '%ProgramFiles%\Autopsy-4.23.1'
        GuiBinary = 'bin\autopsy64.exe'
    }
    SleuthKitVersion = '4.15.0'
    CaseRoot = '%USERPROFILE%\Documents\Autopsy Cases'
    Defender = @{
        CasePathExclusion = $true
        ProcessPathExclusion = $true
        ServiceMustRemainInstalled = $true
        FullProtectionDisableIsExplicit = $true
    }
    PrivateCommands = @(
        @{ Name = 'autopsy-regripper'; RelativePath = 'autopsy\rr-full\rip.exe'; WorkingDirectory = 'autopsy\rr-full'; Purpose = 'Run the bundled RegRipper CLI and custom Recent Activity plugins.' }
        @{ Name = 'autopsy-ewfexport'; RelativePath = 'autopsy\ewfexport_exec\64-bit\ewfexport.exe'; Purpose = 'Run Autopsy patched libewf export tooling explicitly.' }
        @{ Name = 'autopsy-tesseract'; RelativePath = 'autopsy\Tesseract-OCR\tesseract.exe'; Purpose = 'Run the OCR binary bundled for Autopsy ingest.' }
        @{ Name = 'autopsy-yara'; RelativePath = 'autopsy\yara\yarac64.exe'; Purpose = 'Compile YARA rules with the Autopsy-bundled binary.' }
        @{ Name = 'autopsy-photorec'; RelativePath = 'autopsy\photorec_exec\bin\photorec_win.exe'; Purpose = 'Run the bundled PhotoRec console explicitly.' }
        @{ Name = 'autopsy-testdisk'; RelativePath = 'autopsy\photorec_exec\bin\testdisk_win.exe'; Purpose = 'Run the bundled TestDisk console explicitly.' }
        @{ Name = 'autopsy-gst-inspect'; RelativePath = 'autopsy\gstreamer\1.0\x86_64\bin\gst-inspect-1.0.exe'; Purpose = 'Inspect Autopsy media plugins.' }
        @{ Name = 'autopsy-log2timeline'; RelativePath = 'autopsy\plaso\plaso-20180818-amd64\log2timeline.exe'; Purpose = 'Run Autopsy private Plaso; retained for compatibility, not as a current general Plaso.' }
        @{ Name = 'autopsy-tsk-logical-imager'; RelativePath = 'autopsy\tsk_logical_imager\tsk_logical_imager.exe'; Purpose = 'Run the bundled TSK logical imager explicitly.' }
    )
    ManagedFiles = @(
        @{ RelativePath = 'bin\autopsy64.exe'; Size = 210944; Sha256 = 'EE790ADFCF8436D7B128DDB43D6F6DF1A8404DF7612972B2BEF7022B4F27BF69' }
        @{ RelativePath = 'autopsy\rr-full\rip.exe'; Size = 1903187; Sha256 = '3FBBC1EDECC53449734E7335982AD7CC0D7DA300C1B62EA6B1F6E4ECAF25207B' }
        @{ RelativePath = 'autopsy\ewfexport_exec\64-bit\ewfexport.exe'; Size = 743424; Sha256 = 'CC69DA0E84BAF3092E8BA984C1FB85073E69656B6CA72286B801A932CE104D8C' }
        @{ RelativePath = 'autopsy\Tesseract-OCR\tesseract.exe'; Size = 854704; Sha256 = 'FE175BB55C0247C58A7A3BCD73FE5EA013EF4194AFA2B1766A1411CE66571FA8' }
        @{ RelativePath = 'autopsy\yara\yarac64.exe'; Size = 2174464; Sha256 = 'C9356334C991502E9CA3F1ED1EC1BB29F91228ECC16FBA203B1B786F60B986F8' }
        @{ RelativePath = 'autopsy\photorec_exec\bin\photorec_win.exe'; Size = 870456; Sha256 = '6D8B94A72A61B13560AD60F0B455597524E16BF3F53B7A2977CA798EE9109CC4' }
        @{ RelativePath = 'autopsy\photorec_exec\bin\testdisk_win.exe'; Size = 679992; Sha256 = '1B478018B9513E1C1F9DA96C88A571D84B30A10748544B9B06F00DA9CE761E56' }
        @{ RelativePath = 'autopsy\gstreamer\1.0\x86_64\bin\gst-inspect-1.0.exe'; Size = 57856; Sha256 = 'BC11A92617FAA7D30275011B8951CA3955D1D4AA84EA74BAF57B0F5B0955FA36' }
        @{ RelativePath = 'autopsy\plaso\plaso-20180818-amd64\log2timeline.exe'; Size = 5179019; Sha256 = '6D292918BCE1ED947614D6C9C4FF13CBD9D0C9CADC116DB75D335120AA7918E6' }
        @{ RelativePath = 'autopsy\tsk_logical_imager\tsk_logical_imager.exe'; Size = 1486336; Sha256 = 'EF8CD0B1B5188A9C84E9D993957DFEEBD36C9DF126DA799CB6FBB9A6ECC4D030' }
        @{ RelativePath = 'jre\bin\java.exe'; Size = 54952; Sha256 = '8C6D49B508D222CDA1E3765E66C74905DFFA3312DB4044A43547E5196A2E94C4' }
    )
    EmbeddedComponents = @(
        @{ Name = 'JRE'; Version = '21.0.10'; Exposure = 'Private' }
        @{ Name = 'NetBeans RCP'; Version = '15'; Exposure = 'Private' }
        @{ Name = 'Sleuth Kit'; Version = '4.15.0'; Exposure = 'PrivateLibraryAndSeparatePinnedCli' }
        @{ Name = 'libewf'; Version = 'Autopsy-patched'; Exposure = 'Private' }
        @{ Name = 'RegRipper'; Version = 'Autopsy-bundled'; Exposure = 'PrivateCliBinding' }
        @{ Name = 'Solr/Lucene/Tika'; Version = 'Autopsy-bundled'; Exposure = 'Private' }
        @{ Name = 'GStreamer'; Version = 'Autopsy-bundled'; Exposure = 'PrivateCliBinding' }
    )
}
