function Import-WslEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepositoryRoot
    )

    $environmentFile = Join-Path $RepositoryRoot '.wsl-env'
    if (-not (Test-Path -LiteralPath $environmentFile -PathType Leaf)) {
        throw "Missing $environmentFile. Copy .wsl-env.sample to .wsl-env and select the local distribution and user."
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $environmentFile) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $parts = $trimmed -split '=', 2
        if ($parts.Count -ne 2 -or $parts[0] -notmatch '^WSL_[A-Z_]+$' -or -not $parts[1].Trim()) {
            throw "Invalid .wsl-env entry: $line"
        }
        $values[$parts[0]] = $parts[1].Trim()
    }

    foreach ($required in @('WSL_DISTRIBUTION', 'WSL_USER', 'WSL_MALWARE_DISTRIBUTION', 'WSL_MALWARE_USER', 'WSL_NIXOS_DISTRIBUTION', 'WSL_NIXOS_USER')) {
        if (-not $values.ContainsKey($required)) { throw "Missing $required in $environmentFile." }
    }
    foreach ($key in @('WSL_DISTRIBUTION', 'WSL_MALWARE_DISTRIBUTION', 'WSL_NIXOS_DISTRIBUTION')) {
        if ($values[$key] -notmatch '^[A-Za-z0-9._-]+$') { throw "Invalid distribution name in $key." }
    }
    foreach ($key in @('WSL_USER', 'WSL_MALWARE_USER', 'WSL_NIXOS_USER')) {
        if ($values[$key] -notmatch '^[a-z_][a-z0-9_-]*$') { throw "Invalid Linux user name in $key." }
    }
    $distributions = @($values.WSL_DISTRIBUTION, $values.WSL_MALWARE_DISTRIBUTION, $values.WSL_NIXOS_DISTRIBUTION)
    if (@($distributions | Sort-Object -Unique).Count -ne $distributions.Count) {
        throw 'Developer Debian, malware Debian, and NixOS distribution names must be different.'
    }

    return $values
}
