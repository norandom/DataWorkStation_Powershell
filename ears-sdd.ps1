[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $RemainingArguments
)

$script = Join-Path $PSScriptRoot '.specify\extensions\ears-validate\scripts\ears-sdd.ps1'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
    throw "EARS/TDD extension script not found. Re-run the standalone repository's init command."
}
& $script @RemainingArguments
exit $LASTEXITCODE
