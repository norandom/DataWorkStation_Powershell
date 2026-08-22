BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-AiToolsIsolation.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') {
        (Get-Command powershell.exe -ErrorAction Stop).Source
    } else {
        (Get-Command pwsh.exe -ErrorAction Stop).Source
    }
}

Describe 'AI tools and WSL isolation contracts' -Tag 'AiToolsIsolation' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'EnabledProducts' }, @{ Section = 'OptInBoundary' },
        @{ Section = 'ObservationalStatus' }, @{ Section = 'OutputParity' },
        @{ Section = 'OpenCodeTargets' }, @{ Section = 'FocusedProductSelection' }, @{ Section = 'ClaudeInstallChannel' },
        @{ Section = 'AntigravityCliChannel' }, @{ Section = 'ClineCliChannel' },
        @{ Section = 'CopilotCli' }, @{ Section = 'EditorInventory' },
        @{ Section = 'LocalFontPreference' }, @{ Section = 'PortableFontFallback' },
        @{ Section = 'EditorMerge' }, @{ Section = 'BergActivation' }, @{ Section = 'AiDistributionIdentity' },
        @{ Section = 'AiNixIntegrity' }, @{ Section = 'NonoInstallChannel' },
        @{ Section = 'NonoLaunchContract' }, @{ Section = 'NonoFailClosed' },
        @{ Section = 'NonoFilesystemPolicy' }, @{ Section = 'NonoCredentialPolicy' },
        @{ Section = 'NonoNetworkPolicy' }, @{ Section = 'NonoProfileDrift' },
        @{ Section = 'AiDailyPrivilege' }, @{ Section = 'AiInteropBoundary' },
        @{ Section = 'AiMountBoundary' }, @{ Section = 'DevOpsInteropBoundary' },
        @{ Section = 'DevOpsCredentialBoundary' }, @{ Section = 'MalwareWslBoundary' },
        @{ Section = 'MalwareCaseImport' }, @{ Section = 'MalwareCaseExport' },
        @{ Section = 'TrustedDebianRole' }, @{ Section = 'TrustMatrixStatus' },
        @{ Section = 'BoundaryFailure' }, @{ Section = 'UpdateRevalidation' },
        @{ Section = 'RoutingAndDocumentation' }, @{ Section = 'FocusedModuleBoundary' },
        @{ Section = 'PortableSecretExclusions' }
    ) {
        $arguments = @('-NoLogo', '-NoProfile')
        if ($script:runtime -like '*powershell.exe') { $arguments += @('-ExecutionPolicy', 'Bypass') }
        $arguments += @('-File', $script:contract, '-Section', $Section)
        $output = @(& $script:runtime @arguments 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
