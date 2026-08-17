@{
    SchemaVersion = 1
    Distributions = @(
        @{
            Role = 'TrustedUtility'
            TrustLevel = 'trusted'
            DistributionVariable = 'WSL_DISTRIBUTION'
            UserVariable = 'WSL_USER'
            Interop = $true
            AppendWindowsPath = $true
            Automount = $true
            Sudo = $true
            CredentialPaths = @()
            ReadSecretContent = $false
        }
        @{
            Role = 'MalwareAnalysis'
            TrustLevel = 'restricted'
            DistributionVariable = 'WSL_MALWARE_DISTRIBUTION'
            UserVariable = 'WSL_MALWARE_USER'
            Interop = $false
            AppendWindowsPath = $false
            Automount = $false
            Sudo = $false
            CredentialPaths = @()
            ReadSecretContent = $false
        }
        @{
            Role = 'DevOps'
            TrustLevel = 'restricted-secrets'
            DistributionVariable = 'WSL_NIXOS_DISTRIBUTION'
            UserVariable = 'WSL_NIXOS_USER'
            Interop = $false
            AppendWindowsPath = $false
            Automount = $false
            Sudo = $false
            CredentialPaths = @('.ssh', '.aws', '.azure', '.kube', '.config/gcloud')
            ReadSecretContent = $false
        }
        @{
            Role = 'AiAgent'
            TrustLevel = 'restricted-agent'
            DistributionVariable = 'WSL_AI_DISTRIBUTION'
            UserVariable = 'WSL_AI_USER'
            Interop = $false
            AppendWindowsPath = $false
            Automount = $false
            Sudo = $false
            CredentialPaths = @()
            ReadSecretContent = $false
        }
    )
    ForbiddenMountPrefixes = @('/mnt/c', '/mnt/d', '/mnt/wsl', '/run/desktop', '/run/guest-services')
    ForbiddenSocketNames = @('ssh-agent', 'docker.sock', 'podman.sock', 'gpg-agent')
    ResidualHostAccess = 'The trusted Windows user and Windows administrators can enter every WSL distribution as root and access its VHD.'
}
