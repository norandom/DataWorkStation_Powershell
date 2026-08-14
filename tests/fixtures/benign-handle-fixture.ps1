[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$fixturePath = Join-Path ([IO.Path]::GetTempPath()) 'dataworkstation-benign-handle-fixture.txt'
$stream = [IO.File]::Open($fixturePath, 'OpenOrCreate', 'ReadWrite', 'ReadWrite')
try {
    $payload = [Text.Encoding]::UTF8.GetBytes("benign Windows Sandbox handle validation`r`n")
    $stream.SetLength(0)
    $stream.Write($payload, 0, $payload.Length)
    $stream.Flush()
    Start-Sleep -Seconds 4
} finally {
    $stream.Dispose()
}
