[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0
function Assert-True { param([bool] $Condition, [string] $Message); $script:assertions++; if (-not $Condition) { throw "Assertion failed: $Message" } }

foreach ($path in @('config/developer-docker.psd1', 'linux/developer_docker.py', 'scripts/Set-DeveloperDockerState.ps1')) {
    Assert-True (Test-Path (Join-Path $repositoryRoot $path)) "$path exists"
}
$deploy = Get-Content (Join-Path $repositoryRoot 'linux/developer_docker.py') -Raw
Assert-True ($deploy -match 'docker\.service') 'developer daemon is managed'
Assert-True ($deploy -match 'running=True') 'developer daemon remains running'
Assert-True ($deploy -match 'groups=\["docker"\]') 'selected developer user is declared'
Assert-True ($deploy -match 'developer-docker\.managed') 'pyinfra adoption is recorded without migrating Docker data'
$catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config/workstation-modules.psd1')
$developerDocker = @($catalog.Modules | Where-Object Name -eq 'DeveloperDocker')
$developerTools = @($catalog.Modules | Where-Object Name -eq 'DeveloperTools')
Assert-True ($developerDocker.Count -eq 1) 'DeveloperDocker module exists once'
Assert-True ($developerDocker[0].DependsOn -contains 'LinuxAutomation') 'pyinfra precedes developer Docker'
Assert-True ($developerTools[0].DependsOn -contains 'DeveloperDocker') 'developer Docker precedes Dagger'
$state = Get-Content (Join-Path $repositoryRoot 'scripts\Set-DeveloperDockerState.ps1') -Raw
Assert-True ($state -match '--user root -- env') 'privileged pyinfra state runs as WSL root without changing user sudo policy'
$aliases = Get-Content (Join-Path $repositoryRoot 'profile\Aliases.ps1') -Raw
Assert-True ($aliases -match 'function global:wsl-dev') 'the developer WSL boundary has an explicit human command'
Assert-True ($aliases -match 'wsl-dev docker @args') 'the ordinary Docker command routes through the configured developer WSL boundary'
Assert-True ($aliases -notmatch 'function global:docker \{[^}]*wsl-mw') 'the ordinary Docker command never routes through the malware WSL boundary'
Write-Host "Developer Docker state tests passed ($script:assertions assertions)."
