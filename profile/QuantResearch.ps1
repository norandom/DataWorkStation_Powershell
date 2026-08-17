# Quantitative research commands. Each wrapper delegates to a documented script.

function global:quant-status {
    [CmdletBinding()]
    param([string] $Project = 'All', [switch] $Json)

    $scriptPath = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-QuantResearchEnvironmentState.ps1'
    & $scriptPath -Mode Test -Project $Project -Json:$Json
}

function global:quant-sync {
    [CmdletBinding()]
    param([string] $Project = 'All', [switch] $ConfirmPyXllInstall, [switch] $Json)

    $scriptPath = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-QuantResearchEnvironmentState.ps1'
    & $scriptPath -Mode Ensure -Project $Project -ConfirmPyXllInstall:$ConfirmPyXllInstall -Json:$Json
}

function global:quant-rebuild {
    [CmdletBinding()]
    param([string] $Project = 'All', [switch] $ConfirmPyXllInstall, [switch] $Json)

    $scriptPath = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Set-QuantResearchEnvironmentState.ps1'
    & $scriptPath -Mode Reinitialize -Project $Project -ConfirmPyXllInstall:$ConfirmPyXllInstall -Json:$Json
}

function global:quant-notebook {
    [CmdletBinding()]
    param(
        [string] $Project = 'thesis',
        [Parameter(ValueFromRemainingArguments = $true)][string[]] $JupyterArguments = @()
    )

    $scriptPath = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Start-QuantResearchNotebook.ps1'
    & $scriptPath -Project $Project -JupyterArguments $JupyterArguments
}

function global:quant-overlay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [string[]] $Dependency = @(),
        [switch] $Run,
        [switch] $Json
    )

    $scriptPath = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\New-QuantResearchOverlay.ps1'
    & $scriptPath -Name $Name -Dependency $Dependency -Run:$Run -Json:$Json
}

function global:source-relocation-plan {
    [CmdletBinding()]
    param([string] $Source, [string] $Target = 'D:\Source', [switch] $Json)

    $scriptPath = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Get-SourceRelocationPlan.ps1'
    $parameters = @{ Target = $Target; Json = $Json }
    if ($Source) { $parameters.Source = $Source }
    & $scriptPath @parameters
}
