Set-StrictMode -Version Latest

function Get-WslDistributionNames {
    param([switch] $RunningOnly)
    $arguments = if ($RunningOnly) { @('--list', '--running', '--quiet') } else { @('--list', '--quiet') }
    @(& wsl.exe @arguments 2>$null | ForEach-Object { (([string] $_) -replace "`0", '').Trim() } | Where-Object { $_ })
}

function Invoke-WslBoundaryRead {
    param(
        [Parameter(Mandatory = $true)][string] $Distribution,
        [Parameter(Mandatory = $true)][string] $User,
        [Parameter(Mandatory = $true)][string] $Command
    )
    $output = @(& wsl.exe -d $Distribution -u $User -- sh -lc $Command 2>$null)
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n").Trim() }
}

function Test-WslConfBoolean {
    param([string] $Content, [string] $Section, [string] $Key, [bool] $Expected)
    $sectionMatch = [regex]::Match($Content, "(?ims)^\s*\[$([regex]::Escape($Section))\]\s*(.*?)(?=^\s*\[|\z)")
    if (-not $sectionMatch.Success) { return $false }
    $valueMatch = [regex]::Match($sectionMatch.Groups[1].Value, "(?im)^\s*$([regex]::Escape($Key))\s*=\s*(true|false)\s*$")
    $valueMatch.Success -and ([bool]::Parse($valueMatch.Groups[1].Value) -eq $Expected)
}

function Get-WslCredentialMetadata {
    param([string] $Distribution, [string] $User, [string[]] $RelativePaths)
    foreach ($relative in $RelativePaths) {
        if ($relative -notmatch '^[A-Za-z0-9._/-]+$' -or $relative.Contains('..')) { continue }
        $command = 'p="$HOME/__RELATIVE__"; if test -e "$p" -o -L "$p"; then printf ''present|''; stat -c ''%U|%a|%F'' -- "$p"; printf ''|''; readlink -f -- "$p"; else printf ''absent||||''; fi'.Replace('__RELATIVE__', $relative)
        $record = Invoke-WslBoundaryRead $Distribution $User $command
        $parts = @($record.Text -split '\|', 6)
        $present = $parts.Count -ge 1 -and $parts[0] -eq 'present'
        [pscustomobject]@{
            RelativePath = $relative
            Present = $present
            Owner = if ($parts.Count -gt 1) { $parts[1] } else { $null }
            Mode = if ($parts.Count -gt 2) { $parts[2] } else { $null }
            Kind = if ($parts.Count -gt 3) { $parts[3] } else { $null }
            ResolvedPath = if ($parts.Count -gt 4) { $parts[4] } else { $null }
            SecretContentRead = $false
        }
    }
}

function Get-WslTrustBoundaryState {
    param(
        [Parameter(Mandatory = $true)][hashtable] $Configuration,
        [Parameter(Mandatory = $true)][hashtable] $Selection
    )
    $installed = @(Get-WslDistributionNames)
    $running = @(Get-WslDistributionNames -RunningOnly)
    $records = foreach ($declaration in @($Configuration.Distributions)) {
        $distribution = if ($Selection.ContainsKey($declaration.DistributionVariable)) { [string] $Selection[$declaration.DistributionVariable] } else { $null }
        $user = if ($Selection.ContainsKey($declaration.UserVariable)) { [string] $Selection[$declaration.UserVariable] } else { $null }
        $failures = [Collections.Generic.List[string]]::new()
        if (-not $distribution -or -not $user) { $failures.Add('LocalSelectionMissing') }
        $isInstalled = [bool] ($distribution -and $distribution -in $installed)
        $isRunning = [bool] ($distribution -and $distribution -in $running)
        if (-not $isInstalled) { $failures.Add('DistributionAbsent') }
        if ($isInstalled -and -not $isRunning) { $failures.Add('StoppedNotInspected') }

        $interop = $null
        $appendPath = $null
        $automount = $null
        $nonRoot = $null
        $withoutSudo = $null
        $sharedPaths = @()
        $sockets = @()
        $credentials = @()
        if ($isRunning) {
            $wslConf = (Invoke-WslBoundaryRead $distribution root 'cat /etc/wsl.conf 2>/dev/null || true').Text
            $interop = Test-WslConfBoolean $wslConf 'interop' 'enabled' ([bool] $declaration.Interop)
            $appendPath = Test-WslConfBoolean $wslConf 'interop' 'appendWindowsPath' ([bool] $declaration.AppendWindowsPath)
            $automount = Test-WslConfBoolean $wslConf 'automount' 'enabled' ([bool] $declaration.Automount)
            if (-not $interop) { $failures.Add('Interop') }
            if (-not $appendPath) { $failures.Add('WindowsPathInjection') }
            if (-not $automount) { $failures.Add('Automount') }

            $uid = (Invoke-WslBoundaryRead $distribution $user 'id -u').Text
            $groups = (Invoke-WslBoundaryRead $distribution $user 'id -nG').Text -split '\s+'
            $nonRoot = $uid -match '^\d+$' -and $uid -ne '0'
            $withoutSudo = @($groups | Where-Object { $_ -in @('sudo', 'wheel', 'admin') }).Count -eq 0
            if (-not $nonRoot) { $failures.Add('DailyUserIsRoot') }
            if (-not $declaration.Sudo -and -not $withoutSudo) { $failures.Add('SudoCapableGroup') }

            $mountLines = (Invoke-WslBoundaryRead $distribution $user 'findmnt -rn -o TARGET,SOURCE,FSTYPE 2>/dev/null || true').Text -split "`n"
            $sharedPaths = @($mountLines | Where-Object {
                $line = $_
                @($Configuration.ForbiddenMountPrefixes | Where-Object { $line.StartsWith("$_ ") -or $line -match "^$([regex]::Escape($_))/" }).Count -gt 0
            })
            if (-not $declaration.Automount -and $sharedPaths.Count -gt 0) { $failures.Add('SharedPaths') }

            if ($uid -match '^\d+$') {
                $socketText = (Invoke-WslBoundaryRead $distribution $user "find /run/user/$uid -maxdepth 3 -type s -printf '%p\n' 2>/dev/null || true").Text
                $sockets = @($socketText -split "`n" | Where-Object { $_ })
                $forbiddenSockets = @($sockets | Where-Object {
                    $socket = $_
                    @($Configuration.ForbiddenSocketNames | Where-Object { $socket -match [regex]::Escape($_) }).Count -gt 0
                })
                if (-not $declaration.Sudo -and $forbiddenSockets.Count -gt 0) { $failures.Add('SharedAgentOrEngineSocket') }
            }

            $credentials = @(Get-WslCredentialMetadata $distribution $user @($declaration.CredentialPaths))
            foreach ($credential in @($credentials | Where-Object Present)) {
                $privatePath = $credential.ResolvedPath -and $credential.ResolvedPath.StartsWith("/home/$user/", [StringComparison]::Ordinal)
                $owned = $credential.Owner -eq $user
                $restrictive = $credential.Mode -match '^[0-7]{3,4}$' -and (([Convert]::ToInt32($credential.Mode, 8) -band 63) -eq 0)
                $notLink = $credential.Kind -notmatch 'symbolic link'
                if (-not ($privatePath -and $owned -and $restrictive -and $notLink)) { $failures.Add("Credential:$($credential.RelativePath)") }
            }
        }
        [pscustomobject]@{
            Role = $declaration.Role
            TrustLevel = $declaration.TrustLevel
            Distribution = $distribution
            User = $user
            Installed = $isInstalled
            Running = $isRunning
            NonRoot = $nonRoot
            WithoutSudo = $withoutSudo
            Interop = $interop
            AppendWindowsPath = $appendPath
            Automount = $automount
            SharedPaths = $sharedPaths
            Credentials = $credentials
            Sockets = $sockets
            Sandbox = if ($declaration.Role -eq 'AiAgent') { 'reported-by-ai-nixos-state' } else { 'not-applicable' }
            ResidualHostAccess = $Configuration.ResidualHostAccess
            Failures = @($failures)
            Status = if ($failures.Count -eq 0) { 'compliant' } else { 'drifted' }
        }
    }
    [pscustomobject]@{
        SchemaVersion = 1
        Status = if (@($records | Where-Object Status -ne 'compliant').Count -eq 0) { 'compliant' } else { 'drifted' }
        Distributions = @($records)
        ResidualHostAccess = $Configuration.ResidualHostAccess
        Observational = $true
    }
}

function Get-WslTrustBoundaryHumanText {
    param([Parameter(Mandatory = $true)] $State)
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("WSL trust boundary: $($State.Status)")
    foreach ($item in @($State.Distributions)) {
        $lines.Add("  $($item.Role): $($item.User)@$($item.Distribution); trust=$($item.TrustLevel); status=$($item.Status); interop=$($item.Interop); automount=$($item.Automount)")
        foreach ($failure in @($item.Failures)) { $lines.Add("    failure: $failure") }
    }
    $lines.Add("  Residual host access: $($State.ResidualHostAccess)")
    $lines -join [Environment]::NewLine
}
