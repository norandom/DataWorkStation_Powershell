@{
    PreCommitVersion = '4.6.2'
    PSScriptAnalyzerVersion = '1.25.0'
    Tools = @(
        @{
            Name = 'Hadolint'
            PackageId = 'hadolint.hadolint'
            Commands = @('hadolint.exe', 'hadolint')
            MinimumVersion = '2.14.0'
        }
        @{
            Name = 'Actionlint'
            PackageId = 'rhysd.actionlint'
            Commands = @('actionlint.exe', 'actionlint')
            MinimumVersion = '1.7.12'
        }
    )
}
