[CmdletBinding()]
param([string] $Distribution = 'Debian')

$ErrorActionPreference = 'Stop'
# Integration test: use only a disposable /tmp file in the trusted guest.
$tokens = $null
$parseErrors = $null
$path = Join-Path $PSScriptRoot '../scripts/Set-RootlessPodmanState.ps1'
$ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref] $tokens, [ref] $parseErrors)
if ($parseErrors) { throw ($parseErrors | Out-String) }
$definition = $ast.Find({
    param($Node)
    $Node -is [Management.Automation.Language.FunctionDefinitionAst] -and $Node.Name -eq 'Send-BytesToMalwareGuest'
}, $true)
. ([scriptblock]::Create($definition.Extent.Text))
$distribution = $Distribution # used by the production function extracted above
$destination = '/tmp/workstation-byte-transfer-' + [guid]::NewGuid().ToString('N')
$bytes = [Text.Encoding]::UTF8.GetBytes("Unicode: ü`nSecond line`n")
try {
    Send-BytesToMalwareGuest -Bytes $bytes -Destination $destination
    $encoded = (& wsl.exe -d $Distribution --user root --exec base64 -w 0 $destination | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $encoded -cne [Convert]::ToBase64String($bytes)) { throw 'WSL byte roundtrip failed.' }
    $rejected = $false
    try { Send-BytesToMalwareGuest -Bytes $bytes -Destination "/tmp/invalid'path" } catch { $rejected = $true }
    if (-not $rejected) { throw 'Shell metacharacters in destination must be rejected.' }
    Write-Output 'PASS: Windows CRLF transport, Unicode byte preservation and destination validation.'
} finally {
    & wsl.exe -d $Distribution --user root --exec rm -f -- $destination
}
