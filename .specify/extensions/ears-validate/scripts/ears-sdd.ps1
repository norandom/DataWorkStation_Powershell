[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $RemainingArguments
)

$earsCommand = Get-Command ears-sdd -ErrorAction SilentlyContinue
if ($null -ne $earsCommand) {
    & $earsCommand.Source @RemainingArguments
    exit $LASTEXITCODE
}

$pythonCommand = Get-Command py -ErrorAction SilentlyContinue
if ($null -ne $pythonCommand) {
    $validator = Join-Path $PSScriptRoot 'ears_sdd.py'
    & $pythonCommand.Source -3 $validator @RemainingArguments
    exit $LASTEXITCODE
}

throw 'Install the versioned spec-kit-ears-tdd tool release before running this command.'
