@{
    SchemaVersion = 1
    Targets = @(
        @{
            Name = 'Windows'; Title = 'Windows software updates'; Order = 10; DependsOn = @()
            Privilege = 'WindowsAdministrator'; Executor = 'WindowsUpdate'; RestartMayBeRequired = $true
            Detail = 'Install accepted Windows software updates; drivers and automatic restart are excluded.'
        }
        @{
            Name = 'WinGet'; Title = 'WinGet applications'; Order = 20; DependsOn = @()
            Privilege = 'CurrentUser'; Executor = 'WinGet'; RestartMayBeRequired = $true
            Detail = 'Upgrade known-version unpinned applications; forced uninstall and unknown versions are excluded.'
        }
        @{
            Name = 'Scoop'; Title = 'Scoop applications'; Order = 30; DependsOn = @('WinGet')
            Privilege = 'CurrentUser'; Executor = 'Scoop'; RestartMayBeRequired = $false
            Detail = 'Update declared Scoop sources, buckets, and installed applications without cleanup.'
        }
        @{
            Name = 'Wsl'; Title = 'WSL runtime'; Order = 40; DependsOn = @('WinGet')
            Privilege = 'CurrentUser'; Executor = 'Wsl'; RestartMayBeRequired = $true
            Detail = 'Update the supported WSL runtime without shutting down active distributions.'
        }
        @{
            Name = 'Linux'; Title = 'Declared Debian distributions'; Order = 50; DependsOn = @('Wsl')
            Privilege = 'WslRoot'; Executor = 'Linux'; RestartMayBeRequired = $false
            Detail = 'Refresh and upgrade packages in the declared developer and malware-analysis distributions.'
        }
        @{
            Name = 'Homebrew'; Title = 'Declared Homebrew instances'; Order = 60; DependsOn = @('Linux')
            Privilege = 'CurrentUser'; Executor = 'Homebrew'; RestartMayBeRequired = $false
            Detail = 'Update declared Homebrew instances and unpinned formulae while preserving release pins.'
        }
        @{
            Name = 'Containers'; Title = 'Managed container engines'; Order = 70; DependsOn = @('Linux')
            Privilege = 'WslRoot'; Executor = 'Containers'; RestartMayBeRequired = $false
            Detail = 'Reconcile developer rootful Docker and malware-analysis rootless Podman through pyinfra.'
        }
        @{
            Name = 'PowerShellEnvironment'; Title = 'Current-release workstation state'; Order = 80
            DependsOn = @('WinGet', 'Scoop', 'Wsl', 'Linux', 'Homebrew', 'Containers')
            Privilege = 'Mixed'; Executor = 'PowerShellEnvironment'; RestartMayBeRequired = $true
            Detail = 'Ensure and test the current release default state, including both PowerShell profiles.'
        }
    )
    HomebrewInstances = @(
        @{
            Name = 'Developer'; Role = 'Developer'; DistributionVariable = 'WSL_DISTRIBUTION'
            UserVariable = 'WSL_USER'; Executable = '/home/linuxbrew/.linuxbrew/bin/brew'
            PinnedFormulae = @('dagger')
        }
    )
    ProhibitedOperations = @(
        'Restart-Computer'
        'shutdown.exe'
        'wsl.exe --shutdown'
        'docker system prune'
        'podman system prune'
        'scoop cleanup'
        '--include-pinned'
        '--include-unknown'
        '--uninstall-previous'
    )
    AcceptedExitCodes = @{
        WinGet = @(0, -1978335189)
    }
}
