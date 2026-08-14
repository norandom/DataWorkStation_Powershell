[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\linux-homebrew.psd1')
$distribution = $wslEnvironment.WSL_DISTRIBUTION
$brew = "$($configuration.Prefix)/bin/brew"

function Test-LinuxHomebrew {
    & wsl.exe -d $distribution -- sh -lc "test -x '$brew' && '$brew' --version >/dev/null 2>&1"
    $LASTEXITCODE -eq 0
}

if ($Mode -eq 'Test') {
    $compliant = Test-LinuxHomebrew
    Write-Host "LinuxHomebrew: $(if ($compliant) { 'compliant' } else { 'drift detected' })"
    if (-not $compliant) { exit 1 }
    exit 0
}

if (-not (Test-LinuxHomebrew)) {
    $missingPackages = @(
        foreach ($package in @($configuration.RequiredPackages)) {
            $status = & wsl.exe -d $distribution -- dpkg-query -W '-f=${db:Status-Abbrev}' $package 2>$null
            if ($LASTEXITCODE -ne 0 -or "$status" -notmatch '^ii') { $package }
        }
    )
    if ($missingPackages) {
        $installPackages = @($missingPackages) -join ' '
        Write-Host "Installing missing Debian prerequisites as root: $installPackages"
        & wsl.exe -d $distribution -u root -- sh -lc "DEBIAN_FRONTEND=noninteractive apt-get install -y $installPackages"
        if ($LASTEXITCODE -ne 0) { throw "Failed to install Homebrew prerequisites in $distribution." }
    }

    if ($configuration.Prefix -ne '/home/linuxbrew/.linuxbrew') {
        throw "Refusing to prepare unexpected Homebrew prefix '$($configuration.Prefix)'."
    }
    $linuxUser = $wslEnvironment.WSL_USER
    $activeUser = (& wsl.exe -d $distribution -- id -un).Trim()
    if ($activeUser -ne $linuxUser) {
        throw ".wsl-env selects user '$linuxUser', but $distribution starts as '$activeUser'."
    }
    $linuxGroup = (& wsl.exe -d $distribution -- id -gn).Trim()
    if (-not $linuxUser -or -not $linuxGroup) { throw "Failed to resolve the default $distribution user." }
    & wsl.exe -d $distribution -u root -- install -d -m 0755 -o $linuxUser -g $linuxGroup /home/linuxbrew $configuration.Prefix
    if ($LASTEXITCODE -ne 0) { throw "Failed to prepare the bounded Homebrew prefix in $distribution." }

    $installer = '/tmp/dataworkstation-homebrew-install.sh'
    Write-Host "Installing Homebrew as the default $distribution user."
    & wsl.exe -d $distribution -- sh -lc "curl --fail --location --silent --show-error '$($configuration.InstallerUrl)' --output '$installer' && NONINTERACTIVE=1 CI=1 /bin/bash '$installer'"
    if ($LASTEXITCODE -ne 0) { throw "Homebrew installation failed in $distribution." }
}

if ($Mode -eq 'Reinitialize') {
    & wsl.exe -d $distribution -- sh -lc "'$brew' update"
    if ($LASTEXITCODE -ne 0) { throw "Homebrew update failed in $distribution." }
}

if (-not (Test-LinuxHomebrew)) { throw "Homebrew did not reach the requested state in $distribution." }
Write-Host "LinuxHomebrew: compliant ($brew)"
