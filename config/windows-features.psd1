@{
    SchemaVersion = 1
    WindowsOptionalFeatures = @(
        @{
            Id = 'hyper-v'
            DisplayName = 'Hyper-V'
            FeatureName = 'Microsoft-Hyper-V'
            IncludeAllParents = $true
            DependsOn = @()
        }
        @{
            Id = 'windows-sandbox'
            DisplayName = 'Windows Sandbox'
            FeatureName = 'Containers-DisposableClientVM'
            IncludeAllParents = $true
            DependsOn = @('hyper-v')
        }
    )
}
