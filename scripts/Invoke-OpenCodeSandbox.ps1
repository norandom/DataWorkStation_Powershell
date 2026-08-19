[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Project,
    [string[]] $ArgumentList = @(),
    [switch] $CheckOnly,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$selection = Import-WslEnvironment $repositoryRoot
if (-not $selection.ContainsKey('WSL_AI_DISTRIBUTION') -or -not $selection.ContainsKey('WSL_AI_USER')) { throw 'AI WSL selectors are missing from config.json.' }
$distribution = [string] $selection.WSL_AI_DISTRIBUTION
$user = [string] $selection.WSL_AI_USER
$projectPrefix = "/home/$user/projects/"
if (-not $Project.StartsWith($projectPrefix, [StringComparison]::Ordinal) -or $Project.Contains('..') -or $Project -match '[\r\n]') {
    throw "Project must be an absolute private AI-WSL path beneath $projectPrefix."
}
$guestProject = $Project.TrimEnd('/')
$installed = @(& wsl.exe --list --quiet 2>$null | ForEach-Object { (([string] $_) -replace "`0", '').Trim() })
if ($distribution -notin $installed) { throw "AI distribution '$distribution' is not installed." }

# The restricted guest cannot mount a Windows source. Keep agent projects in the private AI VHD;
# Windows VS Code may open that distribution explicitly without exposing host drives to the guest.
$arguments = @('-d', $distribution, '-u', $user, '--', 'opencode-sandbox')
if ($CheckOnly -or $Json) { $arguments += '--check-only' }
$arguments += $guestProject
$arguments += @($ArgumentList)
$output = @(& wsl.exe @arguments 2>&1)
$exitCode = $LASTEXITCODE
if ($Json) {
    [pscustomobject]@{
        SchemaVersion = 1; Distribution = $distribution; User = $user; Project = $guestProject
        Sandbox = 'nono'; Profile = 'nolabs-ai/opencode'; NetworkEnforcement = if ($exitCode -eq 0) { 'verified' } else { 'failed' }
        Status = if ($exitCode -eq 0) { 'compliant' } else { 'blocked' }; Detail = ($output -join "`n").Trim()
    } | ConvertTo-Json -Depth 5
}
if ($exitCode -ne 0) { throw "OpenCode sandbox preflight/launch failed closed (exit $exitCode): $($output -join ' ')" }
if (-not $Json) { $output | ForEach-Object { Write-Host $_ } }
