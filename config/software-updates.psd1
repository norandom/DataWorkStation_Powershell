@{
    SchemaVersion = 1
    Releases = @(
        @{
            Name = 'Contour'; Provider = 'GitHubRelease'; Repository = 'contour-terminal/contour'
            TagTemplate = 'v{version}'
            TagPattern = '^v(?<version>\d+\.\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('contour-{version}-win64.msi')
            Locations = @(
                @{ ConfigPath = 'config\contour-terminal.psd1'; VersionPath = 'Package.Version'; IntegrityPath = 'Package.Sha256' }
            )
        }
        @{
            Name = 'Autopsy'; Provider = 'GitHubRelease'; Repository = 'sleuthkit/autopsy'
            TagTemplate = 'autopsy-{version}'
            TagPattern = '^autopsy-(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('autopsy-{version}-64bit.msi', 'autopsy-{version}-64bit.msi.asc')
            Locations = @(
                @{ ConfigPath = 'config\autopsy.psd1'; VersionPath = 'Package.Version'; IntegrityPath = 'Package.Sha256' }
            )
            Review = 'signature-and-embedded-inventory'
        }
        @{
            Name = 'NixOS-WSL'; Provider = 'GitHubRelease'; Repository = 'nix-community/NixOS-WSL'
            TagTemplate = '{version}'
            TagPattern = '^(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('nixos.wsl')
            Locations = @(
                @{ ConfigPath = 'config\nixos-wsl.psd1'; VersionPath = 'ReleaseTag'; IntegrityPath = 'AssetSha256' }
                @{ ConfigPath = 'config\ai-nixos-wsl.psd1'; VersionPath = 'ReleaseTag'; IntegrityPath = 'AssetSha256' }
            )
        }
        @{
            Name = 'OpenCode'; Provider = 'GitHubRelease'; Repository = 'anomalyco/opencode'
            TagTemplate = 'v{version}'
            TagPattern = '^v(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('opencode-desktop-win-x64.exe', 'opencode-linux-x64.tar.gz')
            Locations = @(
                @{ ConfigPath = 'config\ai-tools.psd1'; CollectionPath = 'Products'; MatchProperty = 'Name'; MatchValue = 'OpenCode Desktop'; VersionPath = 'Version'; IntegrityPath = 'Sha256' }
                @{ ConfigPath = 'config\ai-nixos-wsl.psd1'; VersionPath = 'OpenCode.Version'; IntegrityPath = 'OpenCode.Sha256' }
            )
        }
        @{
            Name = 'CodeQL'; Provider = 'GitHubRelease'; Repository = 'github/codeql-cli-binaries'
            TagTemplate = 'v{version}'
            TagPattern = '^v(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('codeql-win64.zip')
            Locations = @(
                @{ ConfigPath = 'config\developer-tools.psd1'; VersionPath = 'CodeQL.Version'; IntegrityPath = 'CodeQL.Sha256' }
            )
        }
        @{
            Name = 'capa'; Provider = 'GitHubRelease'; Repository = 'mandiant/capa'
            TagTemplate = 'v{version}'
            TagPattern = '^v(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('capa-v{version}-windows.zip')
            Locations = @(
                @{ ConfigPath = 'config\malware-analysis-tools.psd1'; CollectionPath = 'Archives'; MatchProperty = 'Name'; MatchValue = 'capa'; VersionPath = 'Version'; IntegrityPath = 'Sha256' }
                @{ ConfigPath = 'config\malware-container.psd1'; CollectionPath = 'Tools'; MatchProperty = 'Id'; MatchValue = 'capa'; VersionPath = 'Version'; IntegrityPath = 'Integrity' }
            )
            Review = 'host-and-container-artifacts'
        }
        @{
            Name = 'Ghidra'; Provider = 'GitHubRelease'; Repository = 'NationalSecurityAgency/ghidra'
            TagTemplate = 'Ghidra_{version}_build'
            TagPattern = '^Ghidra_(?<version>\d+\.\d+\.\d+)_build$'
            AssetNameRegexTemplates = @('^ghidra_{version}_PUBLIC_\d{8}\.zip$')
            Locations = @(
                @{ ConfigPath = 'config\malware-analysis-tools.psd1'; CollectionPath = 'Archives'; MatchProperty = 'Name'; MatchValue = 'Ghidra'; VersionPath = 'Version'; IntegrityPath = 'Sha256' }
                @{ ConfigPath = 'config\malware-container.psd1'; CollectionPath = 'Tools'; MatchProperty = 'Id'; MatchValue = 'ghidra'; VersionPath = 'Version'; IntegrityPath = 'Integrity' }
            )
            Review = 'host-and-container-artifacts'
        }
        @{
            Name = 'malware_hashes'; Provider = 'GitHubRelease'; Repository = 'norandom/malware_hashes'
            TagTemplate = 'v{version}'
            TagPattern = '^v(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('malware_hashes-windows-amd64.exe')
            Locations = @(
                @{ ConfigPath = 'config\malware-hashes.psd1'; VersionPath = 'Package.Version'; IntegrityPath = 'Package.Sha256' }
            )
        }
        @{
            Name = 'Quarto'; Provider = 'GitHubRelease'; Repository = 'quarto-dev/quarto-cli'
            TagTemplate = 'v{version}'
            TagPattern = '^v(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('quarto-{version}-win.zip')
            Locations = @(
                @{ ConfigPath = 'config\quarto.psd1'; VersionPath = 'Package.Version'; IntegrityPath = 'Package.Sha256' }
            )
        }
        @{
            Name = 'Sleuth Kit'; Provider = 'GitHubRelease'; Repository = 'sleuthkit/sleuthkit'
            TagTemplate = 'sleuthkit-{version}'
            TagPattern = '^sleuthkit-(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('sleuthkit-{version}-win32.zip', 'sleuthkit-{version}-win32.zip.asc')
            Locations = @(
                @{ ConfigPath = 'config\sleuthkit.psd1'; VersionPath = 'Package.Version'; IntegrityPath = 'Package.Sha256' }
            )
            Review = 'signature-and-installed-tree'
        }
        @{
            Name = 'Spec Kit EARS/TDD'; Provider = 'GitHubRelease'; Repository = 'norandom/spec-kit-ears-tdd'
            TagTemplate = 'v{version}'
            TagPattern = '^v(?<version>\d+\.\d+\.\d+)$'
            AssetNameTemplates = @('ears-sdd-x86_64-pc-windows-msvc.zip')
            Locations = @(
                @{ ConfigPath = 'config\spec-driven-development.psd1'; VersionPath = 'Version'; IntegrityPath = 'Sha256' }
            )
            Review = 'packaging-migration-required'
        }
        @{
            Name = 'Fira Code'; Provider = 'GitHubRelease'; Repository = 'tonsky/FiraCode'
            TagTemplate = '{version}'
            TagPattern = '^(?<version>\d+\.\d+)$'
            AssetNameTemplates = @('Fira_Code_v{version}.zip')
            Locations = @(
                @{ ConfigPath = 'config\terminal-fonts.psd1'; VersionPath = 'Package.Version'; IntegrityPath = 'Package.Sha256' }
            )
            Review = 'archive-and-font-file-locks'
        }
    )
}
