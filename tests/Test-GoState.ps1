[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0
function Assert-True { param([bool] $Condition, [string] $Message); $script:assertions++; if (-not $Condition) { throw "Assertion failed: $Message" } }

$package = Get-Content -LiteralPath (Join-Path $repositoryRoot '.config\go.winget') -Raw
Assert-True ($package -match 'id:\s*GoLang\.Go') 'official Go WinGet package is declared'
$state = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-GoState.ps1') -Raw
Assert-True ($state -match 'GOPATH') 'Go workspace is declared'
Assert-True ($state -match 'GOTOOLCHAIN') 'built-in toolchain selection is declared'
Assert-True ($state -match 'GoRootUnmanaged') 'the MSI-owned GOROOT is not overridden'
Assert-True ($state -match 'GoBinOnUserPath') 'installed Go commands are exposed on user PATH'
$catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
$goModule = @($catalog.Modules | Where-Object Name -eq 'Go')
$developerTools = @($catalog.Modules | Where-Object Name -eq 'DeveloperTools')
Assert-True ($goModule.Count -eq 1 -and $goModule[0].Default) 'Go is a focused default module'
Assert-True ($developerTools[0].DependsOn -contains 'Go') 'Go precedes the developer bundle'
$capabilities = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\capabilities.psd1')
Assert-True (@($capabilities.Capabilities | Where-Object Id -eq 'go-development').Count -eq 1) 'Go human commands are routed'
Write-Host "Go state tests passed ($script:assertions assertions)."
