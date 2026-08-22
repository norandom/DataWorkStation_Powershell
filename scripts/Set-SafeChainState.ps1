[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\safe-chain.psd1')
$wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
$distribution = [string] $wslEnvironment.WSL_DISTRIBUTION
$linuxUser = [string] $wslEnvironment.WSL_USER
$linuxHome = "/home/$linuxUser"
$linuxRoot = "$linuxHome/.safe-chain"
$linuxBinary = "$linuxRoot/bin/safe-chain"
$linuxInit = "$linuxRoot/scripts/init-posix.sh"
$linuxBashRc = "$linuxHome/.bashrc"
$windowsRoot = Join-Path $env:USERPROFILE '.safe-chain'
$windowsBinary = Join-Path $windowsRoot 'bin\safe-chain.exe'
$windowsInit = Join-Path $windowsRoot 'scripts\init-pwsh.ps1'
$documents = [Environment]::GetFolderPath('MyDocuments')
$windowsProfiles = @(
    (Join-Path $documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
    (Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1')
)
$windowsProfileLine = ". `"$windowsInit`" # Safe-chain PowerShell initialization script"
$linuxProfileLine = "source $linuxInit # Safe-chain bash initialization script"
$releaseBase = "https://github.com/$($configuration.Repository)/releases/download/$($configuration.Version)"
$downloadRoot = Join-Path $env:LOCALAPPDATA "PowerShellWorkstation\downloads\safe-chain\$($configuration.Version)"

function Test-FileHash {
    param([string] $Path, [string] $Expected)
    (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ieq $Expected
}

function Test-VersionOutput {
    param([object[]] $Output)
    ($Output -join [Environment]::NewLine) -match
        "Current safe-chain version:\s*$([regex]::Escape($configuration.Version))(?:\s|$)"
}

function Test-WindowsVersion {
    if (-not (Test-FileHash -Path $windowsBinary -Expected $configuration.Windows.BinarySha256)) { return $false }
    $output = & $windowsBinary --version 2>$null
    $LASTEXITCODE -eq 0 -and (Test-VersionOutput $output)
}

function Test-WindowsProfile {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    @(Get-Content -LiteralPath $Path | Where-Object { $_ -ceq $windowsProfileLine }).Count -eq 1
}

function Test-CommandWrappers {
    param([AllowEmptyString()][string] $Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return $false }
    foreach ($name in @($configuration.SupportedCommands)) {
        $pattern = '(?m)^\s*function\s+' + [regex]::Escape([string] $name) + '(?:\s*\(\s*\))?\s*\{'
        if ($Content -notmatch $pattern) { return $false }
    }
    $true
}

function Test-WindowsInitScript {
    if (-not (Test-Path -LiteralPath $windowsInit -PathType Leaf)) { return $false }
    Test-CommandWrappers -Content (Get-Content -LiteralPath $windowsInit -Raw)
}

function Invoke-Wsl {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]] $ArgumentList)
    & wsl.exe -d $distribution --user $linuxUser -- @ArgumentList
}

function Test-LinuxFile {
    param([string] $Path)
    Invoke-Wsl test -f $Path
    $LASTEXITCODE -eq 0
}

function Get-LinuxFileHash {
    param([string] $Path)
    $output = Invoke-Wsl sha256sum $Path 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    (("$output" -replace "`0", '').Trim() -split '\s+')[0]
}

function Test-LinuxVersion {
    if (-not (Test-LinuxFile -Path $linuxBinary)) { return $false }
    if ((Get-LinuxFileHash -Path $linuxBinary) -ine $configuration.Linux.BinarySha256) { return $false }
    $output = Invoke-Wsl $linuxBinary --version 2>$null
    $LASTEXITCODE -eq 0 -and (Test-VersionOutput $output)
}

function Test-LinuxProfile {
    Invoke-Wsl grep -Fqx -- $linuxProfileLine $linuxBashRc
    $LASTEXITCODE -eq 0
}

function Test-LinuxInitScript {
    if (-not (Test-LinuxFile -Path $linuxInit)) { return $false }
    $output = @(Invoke-Wsl cat -- $linuxInit 2>$null)
    if ($LASTEXITCODE -ne 0) { return $false }
    Test-CommandWrappers -Content ($output -join "`n")
}

function Get-WindowsManagerNames {
    @($configuration.SupportedCommands | Where-Object {
        Get-Command $_ -CommandType Application,ExternalScript -ErrorAction Ignore | Select-Object -First 1
    })
}

function Get-LinuxManagerNames {
    $found = foreach ($name in @($configuration.SupportedCommands)) {
        Invoke-Wsl sh -lc "command -v $name >/dev/null 2>&1"
        if ($LASTEXITCODE -eq 0) { $name }
    }
    @($found)
}

function Get-SafeChainState {
    $windowsHash = Test-FileHash -Path $windowsBinary -Expected $configuration.Windows.BinarySha256
    $linuxHash = (Get-LinuxFileHash -Path $linuxBinary) -ieq $configuration.Linux.BinarySha256
    [ordered]@{
        WindowsBinary = Test-Path -LiteralPath $windowsBinary -PathType Leaf
        WindowsBinaryHash = $windowsHash
        WindowsVersion = $windowsHash -and (Test-WindowsVersion)
        WindowsInitScript = Test-WindowsInitScript
        WindowsPowerShellProfile = Test-WindowsProfile -Path $windowsProfiles[0]
        PowerShellCoreProfile = Test-WindowsProfile -Path $windowsProfiles[1]
        DebianBinary = Test-LinuxFile -Path $linuxBinary
        DebianBinaryHash = $linuxHash
        DebianVersion = $linuxHash -and (Test-LinuxVersion)
        DebianInitScript = Test-LinuxInitScript
        DebianBashProfile = Test-LinuxProfile
    }
}

function Write-SafeChainState {
    param([Collections.IDictionary] $State)
    $State.GetEnumerator() | ForEach-Object {
        Write-Host ("{0}: {1}" -f $_.Key, $(if ($_.Value) { 'compliant' } else { 'drift detected' }))
    }
    Write-Host "Declared Safe-Chain wrappers: $($configuration.SupportedCommands -join ', ')"
    Write-Host "Protected Windows commands: $((Get-WindowsManagerNames) -join ', ')"
    Write-Host "Protected Debian commands: $((Get-LinuxManagerNames) -join ', ')"
}

function Get-VerifiedInstaller {
    param(
        [string] $Name,
        [string] $ExpectedHash
    )
    New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
    $path = Join-Path $downloadRoot $Name
    Invoke-WebRequest -Uri "$releaseBase/$Name" -OutFile $path -UseBasicParsing
    $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($actualHash -ine $ExpectedHash) {
        throw "Safe-Chain installer hash mismatch for '$Name': $actualHash"
    }
    $path
}

function Move-UnexpectedWindowsBinary {
    if (-not (Test-Path -LiteralPath $windowsBinary -PathType Leaf)) { return }
    if (Test-FileHash -Path $windowsBinary -Expected $configuration.Windows.BinarySha256) { return }
    $backup = "$windowsBinary.unexpected-hash.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
    Move-Item -LiteralPath $windowsBinary -Destination $backup
    Write-Warning "Preserved the unexpected Windows binary as: $backup"
}

function Move-UnexpectedLinuxBinary {
    if (-not (Test-LinuxFile -Path $linuxBinary)) { return }
    if ((Get-LinuxFileHash -Path $linuxBinary) -ieq $configuration.Linux.BinarySha256) { return }
    $backup = "$linuxBinary.unexpected-hash.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
    Invoke-Wsl mv -- $linuxBinary $backup
    if ($LASTEXITCODE -ne 0) { throw 'Failed to preserve the unexpected Debian Safe-Chain binary.' }
    Write-Warning "Preserved the unexpected Debian binary as: $backup"
}

function Install-WindowsSafeChain {
    Move-UnexpectedWindowsBinary
    $installer = Get-VerifiedInstaller -Name $configuration.Windows.Installer -ExpectedHash $configuration.Windows.InstallerSha256
    & $installer
    if ($LASTEXITCODE -ne 0) { throw "Safe-Chain Windows installer failed: $LASTEXITCODE" }
}

function Install-LinuxSafeChain {
    Move-UnexpectedLinuxBinary
    $installer = Get-VerifiedInstaller -Name $configuration.Linux.Installer -ExpectedHash $configuration.Linux.InstallerSha256
    $installerPortable = [IO.Path]::GetFullPath($installer).Replace('\', '/')
    $installerWsl = (Invoke-Wsl wslpath -a $installerPortable).Trim()
    if (-not $installerWsl) { throw 'Failed to resolve the Safe-Chain installer path inside Debian.' }
    $setupPath = "/home/linuxbrew/.linuxbrew/bin:$linuxHome/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    Invoke-Wsl env "PATH=$setupPath" sh $installerWsl
    if ($LASTEXITCODE -ne 0) { throw "Safe-Chain Debian installer failed: $LASTEXITCODE" }
}

function Repair-WindowsIntegration {
    & $windowsBinary setup
    if ($LASTEXITCODE -ne 0) { throw "Safe-Chain Windows setup failed: $LASTEXITCODE" }
}

function Repair-LinuxIntegration {
    $setupPath = "/home/linuxbrew/.linuxbrew/bin:$linuxHome/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$linuxRoot/bin"
    Invoke-Wsl env "PATH=$setupPath" $linuxBinary setup
    if ($LASTEXITCODE -ne 0) { throw "Safe-Chain Debian setup failed: $LASTEXITCODE" }
}

$state = Get-SafeChainState
if ($Mode -eq 'Test') {
    Write-SafeChainState -State $state
    if ($state.Values -contains $false) { exit 1 }
    exit 0
}

$windowsChanged = $false
if (-not $state.WindowsBinaryHash -or -not $state.WindowsVersion) {
    Install-WindowsSafeChain
    $windowsChanged = $true
}
$state = Get-SafeChainState
if ($Mode -eq 'Reinitialize' -or -not $state.WindowsInitScript -or
    -not $state.WindowsPowerShellProfile -or -not $state.PowerShellCoreProfile) {
    Repair-WindowsIntegration
    $windowsChanged = $true
}

$state = Get-SafeChainState
if (-not $state.DebianBinaryHash -or -not $state.DebianVersion) {
    Install-LinuxSafeChain
} elseif ($Mode -eq 'Reinitialize' -or $windowsChanged -or
    -not $state.DebianInitScript -or -not $state.DebianBashProfile) {
    Repair-LinuxIntegration
}

$state = Get-SafeChainState
Write-SafeChainState -State $state
if ($state.Values -contains $false) { throw 'Safe-Chain did not reach the requested state.' }
Write-Host "Safe-Chain state '$Mode' completed successfully."
