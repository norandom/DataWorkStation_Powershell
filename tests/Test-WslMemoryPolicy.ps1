[CmdletBinding()]
param([string] $Distribution = 'Debian')

$ErrorActionPreference = 'Stop'

function Test-WslMemoryPolicy {
    param([string] $Distribution)
    # Read-only integration test; requires the configured trusted Debian deployment.
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $policy = Get-Content -LiteralPath (Join-Path $root 'config/wslconfig.ini') -Raw
    foreach ($setting in @('memory=6GB', 'swap=6GB', 'autoMemoryReclaim=gradual')) {
        if ($policy -notmatch "(?m)^$([regex]::Escape($setting))\s*$") { throw "Missing host declaration: $setting" }
    }
    $linuxRoot = (& wsl.exe -d $Distribution -- wslpath -a $root.Replace('\', '/') | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $linuxRoot.StartsWith('/')) { throw 'Cannot resolve repository inside WSL.' }
    foreach ($script in @('earlyoom.sh', 'zram.sh', 'start-zram.sh')) {
        & wsl.exe -d $Distribution -- sh -n "$linuxRoot/linux/$script"
        if ($LASTEXITCODE -ne 0) { throw "Shell syntax failed: $script" }
    }
    foreach ($script in @('earlyoom.sh', 'zram.sh')) {
        & wsl.exe -d $Distribution -- sh "$linuxRoot/linux/$script" InvalidMode
        if ($LASTEXITCODE -ne 2) { throw "Invalid mode was not rejected: $script" }
        & wsl.exe -d $Distribution -- sh "$linuxRoot/linux/$script" Test
        if ($LASTEXITCODE -ne 0) { throw "Deployed state is not compliant: $script" }
    }
    Write-Output 'PASS: host declarations, shell syntax, invalid modes and deployed Debian memory policy. No state changes requested.'
}

Test-WslMemoryPolicy -Distribution $Distribution
