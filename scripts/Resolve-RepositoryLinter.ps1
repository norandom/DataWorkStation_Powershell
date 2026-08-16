function Resolve-RepositoryLinter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $Tool,
        [switch] $Require
    )

    foreach ($name in @($Tool.Commands)) {
        $command = Get-Command $name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
        if ($command) { return $command.Source }
    }

    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $packageRoot -PathType Container) {
        foreach ($name in @($Tool.Commands)) {
            $match = Get-ChildItem -Path $packageRoot -Recurse -File -Filter $name -ErrorAction Ignore |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($match) { return $match.FullName }
        }
    }

    if ($Require) {
        throw "$($Tool.Name) is required. Run: precommit-install"
    }
    $null
}
