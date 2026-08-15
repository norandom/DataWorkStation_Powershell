[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\native-development.psd1')
$packageFile = Join-Path $repositoryRoot '.config\java.winget'

function Get-JavaHome {
    $candidates = [Collections.Generic.List[string]]::new()
    foreach ($scope in @('User', 'Machine')) {
        $declared = [Environment]::GetEnvironmentVariable('JAVA_HOME', $scope)
        if ($declared) { $candidates.Add($declared) }
    }
    foreach ($root in @(
        (Join-Path $env:ProgramFiles 'Microsoft'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft')
    )) {
        if (Test-Path -LiteralPath $root -PathType Container) {
            Get-ChildItem -LiteralPath $root -Directory -Filter 'jdk-21*' -ErrorAction Ignore |
                Sort-Object Name -Descending |
                ForEach-Object { $candidates.Add($_.FullName) }
        }
    }
    foreach ($candidate in $candidates) {
        if ((Test-Path -LiteralPath (Join-Path $candidate 'bin\java.exe') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $candidate 'bin\javac.exe') -PathType Leaf)) {
            return [IO.Path]::GetFullPath($candidate).TrimEnd('\')
        }
    }
    $null
}

function Test-UserPathEntry {
    param([string] $Entry)
    $path = [Environment]::GetEnvironmentVariable('Path', 'User')
    @($path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $Entry.TrimEnd('\') }).Count -eq 1
}

function Set-JavaUserPath {
    $entry = '%JAVA_HOME%\bin'
    $path = [Environment]::GetEnvironmentVariable('Path', 'User')
    $items = [Collections.Generic.List[string]]::new()
    foreach ($item in @($path -split ';')) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        if ($item.TrimEnd('\') -ieq $entry.TrimEnd('\')) { continue }
        if ($item -match '(?i)\\Microsoft\\jdk-21[^\\;]*\\bin\\?$') { continue }
        $items.Add($item)
    }
    $items.Add($entry)
    [Environment]::SetEnvironmentVariable('Path', ($items -join ';'), 'User')
}

function Get-JavaMajorVersion {
    param([string] $Executable)
    if (-not $Executable -or -not (Test-Path -LiteralPath $Executable -PathType Leaf)) { return $null }
    $text = @(& $Executable -version 2>&1) -join "`n"
    if ($text -match '(?m)(?:version\s+")?([0-9]+)(?:\.|\")') { return [int] $Matches[1] }
    $null
}

function Get-JavaState {
    $javaRoot = Get-JavaHome
    $declaredHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
    $commands = [ordered]@{}
    foreach ($name in $configuration.Java.Commands) {
        $commands[$name] = if ($javaRoot) { Test-Path -LiteralPath (Join-Path $javaRoot "bin\$name") -PathType Leaf } else { $false }
    }
    $javaMajor = if ($javaRoot) { Get-JavaMajorVersion -Executable (Join-Path $javaRoot 'bin\java.exe') } else { $null }
    $javacMajor = if ($javaRoot) { Get-JavaMajorVersion -Executable (Join-Path $javaRoot 'bin\javac.exe') } else { $null }
    $checks = [ordered]@{
        Package = [bool] $javaRoot
        Commands = -not ($commands.Values -contains $false)
        MajorVersion = ($javaMajor -eq $configuration.Java.MajorVersion -and $javacMajor -eq $configuration.Java.MajorVersion)
        VersionMatch = ($javaMajor -and $javaMajor -eq $javacMajor)
        JavaHome = ($javaRoot -and $declaredHome -and $declaredHome.TrimEnd('\') -ieq $javaRoot)
        JavaBinOnUserPath = Test-UserPathEntry -Entry '%JAVA_HOME%\bin'
    }
    [pscustomobject]@{
        SchemaVersion = 1
        Resource = 'JavaToolchain'
        State = if ($checks.Values -contains $false) { 'drift detected' } else { 'compliant' }
        Changed = $false
        PackageId = $configuration.Packages.Java
        JavaHome = $javaRoot
        RuntimeMajor = $javaMajor
        CompilerMajor = $javacMajor
        Commands = [pscustomobject] $commands
        Checks = [pscustomobject] $checks
    }
}

function Write-JavaState {
    param([object] $State, [switch] $AsJson)
    if ($AsJson) { $State | ConvertTo-Json -Depth 6; return }
    Write-Host "Java toolchain: $($State.State)"
    Write-Host "  package: $($State.PackageId)"
    Write-Host "  JAVA_HOME: $($State.JavaHome)"
    Write-Host "  runtime/compiler major: $($State.RuntimeMajor)/$($State.CompilerMajor)"
    $State.Checks.PSObject.Properties | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Name, $(if ($_.Value) { 'compliant' } else { 'drift detected' }))
    }
}

$before = Get-JavaState
if ($Mode -eq 'Test') {
    Write-JavaState $before -AsJson:$Json
    if ($before.State -ne 'compliant') { exit 1 }
    exit 0
}

if (-not $before.Checks.Package -or $Mode -eq 'Reinitialize') {
    & winget.exe configure --file $packageFile --accept-configuration-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "OpenJDK WinGet Configuration failed with exit code $LASTEXITCODE." }
}
$javaHome = Get-JavaHome
if (-not $javaHome) { throw 'Microsoft OpenJDK 21 installed, but its JDK root could not be resolved.' }
[Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHome, 'User')
$env:JAVA_HOME = $javaHome
Set-JavaUserPath
$javaBin = Join-Path $javaHome 'bin'
$processEntries = @($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ine $javaBin.TrimEnd('\') })
$env:Path = (@($javaBin) + $processEntries) -join ';'

$after = Get-JavaState
$after.Changed = ($before.State -ne 'compliant' -or $Mode -eq 'Reinitialize')
Write-JavaState $after -AsJson:$Json
if ($after.State -ne 'compliant') { throw 'Java toolchain did not reach the declared state.' }
