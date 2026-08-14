@{
    SchemaVersion = 1
    Install = @{
        Uri = 'https://get.scoop.sh'
        Root = '%USERPROFILE%\scoop'
        Repository = 'https://github.com/ScoopInstaller/Scoop'
        RequiredExecutionPolicy = 'RemoteSigned'
        RequiredLanguageMode = 'FullLanguage'
    }
    Buckets = @(
        @{
            Name = 'main'
            Repository = 'https://github.com/ScoopInstaller/Main'
        }
        @{
            Name = 'extras'
            Repository = 'https://github.com/ScoopInstaller/Extras'
        }
    )
}
