[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [string] $InstallerPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\autopsy.psd1')
$package = $configuration.Package
$installRoot = [Environment]::ExpandEnvironmentVariables($package.InstallRoot)
$guiPath = Join-Path $installRoot $package.GuiBinary
$caseRoot = [Environment]::ExpandEnvironmentVariables($configuration.CaseRoot)
$uninstallRoots = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

function Test-Administrator {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-AutopsyEntry {
    Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $package.DisplayName } |
        Select-Object -First 1
}

function Test-DefenderExclusion {
    param([string] $Value, [ValidateSet('Path','Process')] [string] $Kind)
    $preference = Get-MpPreference
    $property = if ($Kind -eq 'Path') { 'ExclusionPath' } else { 'ExclusionProcess' }
    @($preference.$property | Where-Object { $_ -and $_.TrimEnd('\') -ieq $Value.TrimEnd('\') }).Count -gt 0
}

function Get-AutopsyState {
    $entry = Get-AutopsyEntry
    $privateMissing = @($configuration.PrivateCommands | Where-Object { -not (Test-Path -LiteralPath (Join-Path $installRoot $_.RelativePath) -PathType Leaf) } | ForEach-Object Name)
    $managedFileDrift = @($configuration.ManagedFiles | Where-Object {
        $path = Join-Path $installRoot $_.RelativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $true }
        $file = Get-Item -LiteralPath $path
        $file.Length -ne [long] $_.Size -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $_.Sha256
    } | ForEach-Object RelativePath)
    $caseExists = Test-Path -LiteralPath $caseRoot -PathType Container
    $caseExcluded = if ($caseExists) { Test-DefenderExclusion -Value $caseRoot -Kind Path } else { $false }
    $processExcluded = if (Test-Path -LiteralPath $guiPath -PathType Leaf) { Test-DefenderExclusion -Value $guiPath -Kind Process } else { $false }
    $service = Get-Service WinDefend -ErrorAction SilentlyContinue
    [pscustomobject]@{
        InstalledVersion = if ($entry) { [string] $entry.DisplayVersion } else { '' }
        ProductCode = if ($entry) { [string] $entry.PSChildName } else { '' }
        InstallRoot = $installRoot
        GuiPath = $guiPath
        GuiExists = Test-Path -LiteralPath $guiPath -PathType Leaf
        PrivateCommandsMissing = $privateMissing
        ManagedFileDrift = $managedFileDrift
        CaseRoot = $caseRoot
        CaseRootExists = $caseExists
        CaseRootExcluded = $caseExcluded
        ProcessExcluded = $processExcluded
        DefenderServiceInstalled = [bool] $service
        DefenderServiceStatus = if ($service) { [string] $service.Status } else { 'Absent' }
        Compliant = $entry.DisplayVersion -eq $package.Version -and
            (Test-Path -LiteralPath $guiPath -PathType Leaf) -and $privateMissing.Count -eq 0 -and $managedFileDrift.Count -eq 0 -and
            $caseExists -and $caseExcluded -and $processExcluded -and [bool] $service
    }
}

function Write-AutopsyState {
    param($State)
    @(
        [pscustomobject]@{ Resource = 'AutopsyMsi'; State = if ($State.InstalledVersion -eq $package.Version -and $State.GuiExists) { 'compliant' } else { 'drift detected' }; Detail = "$($State.InstalledVersion) installed; $($package.Version) required; $($State.ProductCode)" }
        [pscustomobject]@{ Resource = 'AutopsyPrivateTools'; State = if ($State.PrivateCommandsMissing.Count -eq 0) { 'complete' } else { 'drift detected' }; Detail = if ($State.PrivateCommandsMissing.Count) { $State.PrivateCommandsMissing -join ', ' } else { "$($configuration.PrivateCommands.Count) reviewed bindings" } }
        [pscustomobject]@{ Resource = 'AutopsyManagedFiles'; State = if ($State.ManagedFileDrift.Count -eq 0) { 'verified' } else { 'drift detected' }; Detail = if ($State.ManagedFileDrift.Count) { $State.ManagedFileDrift -join ', ' } else { "$($configuration.ManagedFiles.Count) exact size/SHA-256 records" } }
        [pscustomobject]@{ Resource = 'AutopsyCaseRoot'; State = if ($State.CaseRootExists) { 'present' } else { 'drift detected' }; Detail = $State.CaseRoot }
        [pscustomobject]@{ Resource = 'DefenderCaseExclusion'; State = if ($State.CaseRootExcluded) { 'active' } else { 'drift detected' }; Detail = $State.CaseRoot }
        [pscustomobject]@{ Resource = 'DefenderProcessExclusion'; State = if ($State.ProcessExcluded) { 'active' } else { 'drift detected' }; Detail = $State.GuiPath }
        [pscustomobject]@{ Resource = 'DefenderService'; State = if ($State.DefenderServiceInstalled) { 'retained' } else { 'missing' }; Detail = $State.DefenderServiceStatus }
    ) | Format-Table -AutoSize -Wrap
}

function Test-InstallerIdentity {
    param([string] $Path)
    if ((Get-Item -LiteralPath $Path).Length -ne [long] $package.Size) { throw 'Autopsy MSI size does not match the catalog.' }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($hash -ine $package.Sha256) { throw "Autopsy MSI SHA-256 mismatch: $hash" }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $package.AuthenticodeThumbprint -or
        $signature.SignerCertificate.Subject -notlike "$($package.AuthenticodeSigner)*") {
        throw 'Autopsy MSI Authenticode identity is not the declared Sleuth Kit Labs signer.'
    }
}

function Invoke-Msi {
    param([ValidateSet('Install','Repair','Uninstall')] [string] $Operation, [string] $Target)
    $logRoot = Join-Path $repositoryRoot 'state\autopsy'
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    $log = Join-Path $logRoot "autopsy-$($Operation.ToLowerInvariant())-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss')).log"
    $arguments = if ($Operation -eq 'Install') {
        @('/i', $Target, '/qn', '/norestart', '/L*v', $log)
    } elseif ($Operation -eq 'Repair') {
        @('/fa', $Target, '/qn', '/norestart', '/L*v', $log)
    } else { @('/x', $Target, '/qn', '/norestart', '/L*v', $log) }
    $process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) { throw "Autopsy MSI $Operation failed with exit code $($process.ExitCode). Inspect $log" }
    if ($process.ExitCode -eq 3010) { Write-Warning 'Autopsy requested a restart; this resource did not restart Windows.' }
    Write-Host "Autopsy MSI log: $log"
}

if (-not (Test-Administrator)) { throw 'Administrator rights are required. Run this script through sudo.' }
$state = Get-AutopsyState
if ($Mode -eq 'Test') {
    Write-AutopsyState $state
    if (-not $state.Compliant) { exit 1 }
    exit 0
}

if ($Mode -eq 'Reinitialize' -and $state.ProductCode) {
    Invoke-Msi -Operation Uninstall -Target $state.ProductCode
    $state = Get-AutopsyState
}

if ($state.InstalledVersion -ne $package.Version -or -not $state.GuiExists -or $state.ManagedFileDrift.Count -gt 0) {
    $downloaded = $false
    if (-not $InstallerPath) {
        $InstallerPath = Join-Path ([IO.Path]::GetTempPath()) "autopsy-$($package.Version)-$([guid]::NewGuid().ToString('N')).msi"
        Invoke-WebRequest -Uri $package.Uri -OutFile $InstallerPath -UseBasicParsing
        $downloaded = $true
    }
    try {
        Test-InstallerIdentity -Path $InstallerPath
        $operation = if ($state.InstalledVersion -eq $package.Version) { 'Repair' } else { 'Install' }
        Invoke-Msi -Operation $operation -Target $InstallerPath
    } finally {
        if ($downloaded) { Remove-Item -LiteralPath $InstallerPath -Force -ErrorAction SilentlyContinue }
    }
}

if (-not (Test-Path -LiteralPath $caseRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
}
if (-not (Test-DefenderExclusion -Value $caseRoot -Kind Path)) {
    Add-MpPreference -ExclusionPath $caseRoot
}
if (-not (Test-DefenderExclusion -Value $guiPath -Kind Process)) {
    Add-MpPreference -ExclusionProcess $guiPath
}

$result = Get-AutopsyState
Write-AutopsyState $result
if (-not $result.Compliant) { throw 'Autopsy did not reach the declared MSI, private-tool, case-root, and Defender-exclusion state.' }
Write-Host 'Autopsy is ready. Defender remains installed; case/output and Autopsy process exclusions are active.'
