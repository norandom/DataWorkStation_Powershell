[CmdletBinding()]
param(
    [ValidateSet('All', 'Inspection', 'PodmanState', 'Boundary', 'MigrationOrder', 'ModuleContract', 'LegacyCleanup', 'CommandSurface', 'Documentation', 'Validation')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-Source {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$RelativePath exists"
    Get-Content -LiteralPath $path -Raw
}

function Test-Inspection {
    $configurationPath = Join-Path $repositoryRoot 'config\rootless-podman.psd1'
    Assert-True (Test-Path -LiteralPath $configurationPath -PathType Leaf) 'rootless Podman configuration exists'
    $configuration = Import-PowerShellDataFile $configurationPath
    foreach ($property in @('BaseDistribution', 'PyinfraVersion', 'RequiredPackages', 'LegacyDockerPackages', 'LegacyDockerDataPaths', 'Deploy', 'RetireDeploy')) {
        Assert-True ($configuration.ContainsKey($property)) "configuration declares $property"
    }
    foreach ($package in @('podman', 'uidmap', 'fuse-overlayfs', 'passt')) {
        Assert-True ($configuration.RequiredPackages -contains $package) "$package is declared"
    }
    foreach ($package in @('docker-ce', 'docker-ce-cli', 'docker-ce-rootless-extras')) {
        Assert-True ($configuration.LegacyDockerPackages -contains $package) "$package retirement is declared"
    }
    $state = Get-Source 'scripts/Set-RootlessPodmanState.ps1'
    Assert-True ($state -match 'if \(\$Mode -eq ''Test''\)') 'Test has an early observational branch'
    Assert-True ($state -match 'MigrationImpact|PendingChanges') 'state reports migration impact'
    Assert-True ($state -match 'LegacyDockerData') 'state reports retained Docker data'
    Assert-True ($state -match 'ConvertTo-Json') 'machine-readable state is supported'
    Assert-True ($state -match 'db:Status-Abbrev' -and $state -match "\^ii") 'removed packages with residual config are not counted as installed'
}

function Test-PodmanState {
    $deploy = Get-Source 'linux/rootless_podman.py'
    foreach ($package in @('podman', 'uidmap', 'fuse-overlayfs', 'passt')) {
        Assert-True ($deploy -match [regex]::Escape('"' + $package + '"')) "deploy installs $package"
    }
    Assert-True ($deploy -match '/etc/subuid' -and $deploy -match '/etc/subgid') 'subordinate IDs are maintained'
    Assert-True ($deploy -match 'podman info') 'Ensure initializes and validates Podman locally'
    Assert-True ($deploy -match 'systemctl --user disable --now podman\.socket podman\.service') 'Podman API units are disabled'
    Assert-True ($deploy -notmatch 'podman system service') 'no Podman API service is started'
    $state = Get-Source 'scripts/Set-RootlessPodmanState.ps1'
    foreach ($signal in @('rootless', 'serviceIsRemote', 'graphRoot', 'graphDriverName', 'seccompEnabled')) {
        Assert-True ($state -match $signal) "state validates Podman $signal"
    }
    Assert-True ($state -match 'podman\.socket' -and $state -match 'podman\.service') 'state inspects API units'
    Assert-True ($state -match 'StorageInitialized') 'Test avoids initializing an absent local store'
    Assert-True ($state -match '--exec @ArgumentList') 'bounded state probes bypass the default Linux shell'
}

function Test-Boundary {
    $state = Get-Source 'scripts/Set-RootlessPodmanState.ps1'
    Assert-True ($state -match 'WSL_MALWARE_DISTRIBUTION' -and $state -match 'WSL_DISTRIBUTION') 'malware and developer selectors are compared'
    Assert-True ($state -match "Uid -ne '0'|\$uid -ne '0'") 'root is rejected as the analysis user'
    Assert-True ($state -match 'DockerDesktopIntegrated|DockerCommandAbsent') 'Docker Desktop or Docker routing is rejected'
    Assert-True ($state -notmatch 'wsl\.exe --export|wsl\.exe --import') 'the developer distro is never cloned'
    Assert-True ($state -match 'wsl\.exe --install.*--name \$distribution.*--no-launch') 'a missing distro is installed cleanly'
}

function Test-MigrationOrder {
    $state = Get-Source 'scripts/Set-RootlessPodmanState.ps1'
    $provision = $state.IndexOf('rootless_podman.py')
    $ready = $state.IndexOf('PodmanProvisioned')
    $retire = $state.IndexOf('retire_rootless_docker.py')
    Assert-True ($provision -ge 0 -and $ready -gt $provision -and $retire -gt $ready) 'Podman is provisioned and gated before Docker retirement'
    $retirement = Get-Source 'linux/retire_rootless_docker.py'
    Assert-True ($retirement -match 'systemctl --user disable --now docker\.service') 'rootless Docker service is stopped and disabled'
    Assert-True ($retirement -match 'present=False') 'legacy Docker packages and repository files are removed'
    Assert-True ($retirement -match 'docker\.sources' -and $retirement -match 'docker\.asc') 'Docker repository trust state is retired'
    Assert-True ($retirement -notmatch '\.local/share/docker.*present=False|rm\s+-rf') 'legacy Docker data is not deleted by migration'
    foreach ($oldPath in @('config/rootless-docker.psd1', 'linux/rootless_docker.py', 'scripts/Set-RootlessDockerState.ps1')) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $oldPath))) "$oldPath is superseded"
    }
}

function Test-ModuleContract {
    $catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $podman = @($catalog.Modules | Where-Object Name -eq 'RootlessPodman')
    $docker = @($catalog.Modules | Where-Object Name -eq 'RootlessDocker')
    $cleanup = @($catalog.Modules | Where-Object Name -eq 'LegacyDockerCleanup')
    $image = @($catalog.Modules | Where-Object Name -eq 'MalwareContainerImage')
    Assert-True ($podman.Count -eq 1 -and $podman[0].Default) 'RootlessPodman is the default dedicated runtime module'
    Assert-True ($podman[0].Privileged -and -not $podman[0].Destructive) 'runtime migration is privileged but retains user data'
    Assert-True ($docker.Count -eq 0) 'RootlessDocker module is absent'
    Assert-True ($cleanup.Count -eq 1 -and -not $cleanup[0].Default -and $cleanup[0].Destructive) 'legacy cleanup is opt-in and destructive'
    Assert-True ($cleanup[0].DependsOn -contains 'RootlessPodman') 'cleanup depends on compliant Podman state'
    Assert-True ($image[0].DependsOn -contains 'RootlessPodman') 'parser image depends on Podman'
    $apply = Get-Source 'Apply-Workstation.ps1'
    foreach ($name in @('RootlessPodman', 'LegacyDockerCleanup')) {
        Assert-True ($apply -match [regex]::Escape("'$name'")) "$name is routable"
    }
    Assert-True ($apply -match 'ConfirmDestructive') 'the DSL has a generic destructive confirmation gate'
}

function Test-LegacyCleanup {
    $cleanup = Get-Source 'scripts/Remove-LegacyDockerMwState.ps1'
    foreach ($guard in @('ConfirmDestructive', 'ReparsePoint', 'Owner', 'RootlessPodman', 'LegacyDockerDataPaths', 'home itself', 'distribution root')) {
        Assert-True ($cleanup -match [regex]::Escape($guard)) "cleanup implements $guard guard"
    }
    Assert-True ($cleanup -match 'if \(\$Mode -eq ''Test''\)') 'cleanup Test is observational'
    Assert-True ($cleanup -match 'Remove-Item|rm --recursive') 'cleanup has an explicit deletion operation'
    Assert-True ($cleanup -match "Resolve-Path|@\('readlink', '-f'") 'cleanup resolves targets before deletion'
}

function Test-CommandSurface {
    $aliases = Get-Source 'profile/Aliases.ps1'
    Assert-True ($aliases -match 'function global:wsl-mw') 'generic malware WSL command remains'
    Assert-True ($aliases -match '--exec @ArgumentList') 'generic WSL argument forwarding bypasses the default Linux shell'
    foreach ($alias in @('docker-mw', 'docker-mw-compose', 'podman-mw')) {
        Assert-True ($aliases -notmatch ('function global:' + [regex]::Escape($alias))) "$alias is not defined"
    }
    $capabilities = Get-Source 'config/capabilities.psd1'
    Assert-True ($capabilities -match 'Set-RootlessPodmanState\.ps1') 'capabilities route the Podman state command'
    Assert-True ($capabilities -match 'wsl-mw podman info') 'capabilities expose generic low-level inspection'
    Assert-True ($capabilities -notmatch 'Set-RootlessDockerState\.ps1|docker-mw') 'capabilities omit Docker-MW commands'
}

function Test-Documentation {
    $combined = @(
        'README.md', 'docs/desired-state.md', 'docs/workstation-modules.md', 'docs/Aliases.md',
        'docs/malware-analysis.md', 'docs/sample-outputs.md', '.agents/skills/is-this-malware/SKILL.md'
    ) | ForEach-Object { Get-Source $_ }
    $text = $combined -join "`n"
    Assert-True ($text -match 'RootlessPodman|rootless Podman') 'Podman boundary is documented'
    Assert-True ($text -match 'wsl-mw podman') 'generic low-level command is documented'
    Assert-True ($text -match 'LegacyDockerCleanup|legacy Docker') 'retained data and cleanup are documented'
    Assert-True ($text -notmatch '`docker-mw|`docker-mw-compose|`podman-mw') 'removed aliases are not documented as commands'
    $featureTwo = Get-Source 'specs/002-is-this-malware/spec.md'
    Assert-True ($featureTwo -match '003-migrate-podman-mw') 'the prior malware spec cross-links the superseding feature'
}

function Test-Validation {
    $traceability = Get-Source 'specs/003-migrate-podman-mw/traceability.toml'
    foreach ($number in 1..28) {
        Assert-True ($traceability -match ('requirements\.REQ-{0:000}' -f $number)) "REQ-$('{0:000}' -f $number) is mapped"
    }
    Assert-True ($traceability -notmatch 'verification = "pending"') 'all verification mappings are complete'
}

$sections = if ($Section -eq 'All') {
    @('Inspection', 'PodmanState', 'Boundary', 'MigrationOrder', 'ModuleContract', 'LegacyCleanup', 'CommandSurface', 'Documentation', 'Validation')
} else {
    @($Section)
}

foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}

Write-Host "Rootless Podman migration tests passed ($script:assertions assertions)."
