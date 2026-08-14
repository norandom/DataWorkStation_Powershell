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

    foreach ($required in @('WSL_DISTRIBUTION', 'WSL_USER', 'WSL_MALWARE_DISTRIBUTION', 'WSL_MALWARE_USER')) {
        if (-not $values.ContainsKey($required)) { throw "Missing $required in $environmentFile." }
    }
    if ($values.WSL_DISTRIBUTION -eq $values.WSL_MALWARE_DISTRIBUTION) {
        throw 'WSL_DISTRIBUTION and WSL_MALWARE_DISTRIBUTION must be different so developer and malware-analysis state remain distinct.'
    }

    return $values
}
