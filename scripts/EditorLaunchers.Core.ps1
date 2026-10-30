function Get-EditorLauncherTarget {
    param([hashtable] $Launcher)
    $candidates = @($Launcher.Candidates)
    if ($Launcher.ContainsKey('RegisteredApplicationName')) {
        # Installer records support an existing custom location without trusting PATH.
        $registrations = @(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object {
                $_.PSObject.Properties['DisplayName'] -and $_.PSObject.Properties['Publisher'] -and
                $_.PSObject.Properties['InstallLocation'] -and $_.DisplayName -eq $Launcher.RegisteredApplicationName -and
                $_.Publisher -eq $Launcher.RegisteredPublisher -and $_.InstallLocation
            })
        foreach ($registration in $registrations) {
            $candidates += Join-Path $registration.InstallLocation 'bin\code.cmd'
        }
    }
    foreach ($template in $candidates) {
        $candidate = [Environment]::ExpandEnvironmentVariables($template)
        $sibling = Join-Path (Split-Path -Parent $candidate) $Launcher.RequiredSibling
        if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and (Test-Path -LiteralPath $sibling -PathType Leaf)) {
            if ($Launcher.ContainsKey('RegisteredApplicationName')) {
                $signature = Get-AuthenticodeSignature -LiteralPath $sibling
                if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'CN=Microsoft Corporation') { continue }
            }
            return $candidate
        }
    }
    ''
}

function Get-EditorLauncherContent {
    param([string] $Target)
    # CALL returns from VS Code's batch launcher; native executables need no CALL.
    $prefix = if ([IO.Path]::GetExtension($Target) -eq '.cmd') { 'call ' } else { '' }
    "@echo off`r`n$prefix`"$Target`" %*`r`nexit /b %ERRORLEVEL%`r`n"
}

function Get-EditorPathWithoutBundle {
    param([AllowNull()][AllowEmptyString()][string] $Path, [string] $SupersededPath)
    (@($Path -split ';' | Where-Object {
        [Environment]::ExpandEnvironmentVariables($_).Trim().Trim('"').TrimEnd('\') -ine $SupersededPath.TrimEnd('\')
    }) -join ';')
}

function Get-EditorLauncherState {
    param([hashtable] $Configuration)
    $directory = [Environment]::ExpandEnvironmentVariables($Configuration.CommandDirectory)
    $superseded = [Environment]::ExpandEnvironmentVariables($Configuration.SupersededPath)
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $launchers = @(foreach ($launcher in $Configuration.Launchers) {
        $target = Get-EditorLauncherTarget $launcher
        $shim = Join-Path $directory ($launcher.Name + '.cmd')
        $contentMatches = $target -and (Test-Path -LiteralPath $shim -PathType Leaf) -and
            (Get-Content -LiteralPath $shim -Raw) -ceq (Get-EditorLauncherContent $target)
        [pscustomobject]@{ Name = $launcher.Name; Target = $target; CommandPath = $shim; Compliant = [bool] $contentMatches }
    })
    $machineClean = (Get-EditorPathWithoutBundle $machinePath $superseded) -ceq $machinePath
    $userClean = (Get-EditorPathWithoutBundle $userPath $superseded) -ceq $userPath
    $binOnPath = $directory -in @($userPath -split ';')
    [pscustomobject]@{
        Launchers = $launchers
        MachinePathClean = $machineClean
        UserPathClean = $userClean
        CommandDirectoryOnPath = $binOnPath
        Compliant = @($launchers | Where-Object { -not $_.Compliant }).Count -eq 0 -and $machineClean -and $userClean -and $binOnPath
    }
}

function Set-EditorLaunchers {
    param([hashtable] $Configuration, [string] $BackupDirectory)
    $directory = [Environment]::ExpandEnvironmentVariables($Configuration.CommandDirectory)
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    foreach ($launcher in $Configuration.Launchers) {
        $target = Get-EditorLauncherTarget $launcher
        if (-not $target) { throw "No installed target found for $($launcher.Name)." }
        $shim = Join-Path $directory ($launcher.Name + '.cmd')
        $desired = Get-EditorLauncherContent $target
        if ((Test-Path -LiteralPath $shim) -and (Get-Content -LiteralPath $shim -Raw) -ceq $desired) { continue }
        if (Test-Path -LiteralPath $shim) {
            New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
            Copy-Item -LiteralPath $shim -Destination (Join-Path $BackupDirectory "$($launcher.Name)-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')).cmd")
        }
        [IO.File]::WriteAllText($shim, $desired, [Text.Encoding]::Default)
    }
    $superseded = [Environment]::ExpandEnvironmentVariables($Configuration.SupersededPath)
    $before = [Environment]::GetEnvironmentVariable('Path', 'User')
    $after = Get-EditorPathWithoutBundle $before $superseded
    if ($directory -notin @($after -split ';')) { $after = "$directory;$after" }
    if ($before -cne $after) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
        $before | Set-Content -LiteralPath (Join-Path $BackupDirectory "user-path-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')).txt")
        [Environment]::SetEnvironmentVariable('Path', $after, 'User')
    }
    $env:Path = "$directory;" + (Get-EditorPathWithoutBundle $env:Path $superseded)
}

function Repair-EditorMachinePath {
    param([hashtable] $Configuration, [string] $BackupDirectory)
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Machine PATH repair requires an elevated PowerShell. Use sudo with -Mode Ensure -RepairMachinePath.'
    }
    $before = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $after = Get-EditorPathWithoutBundle $before ([Environment]::ExpandEnvironmentVariables($Configuration.SupersededPath))
    if ($before -ceq $after) { return }
    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    $before | Set-Content -LiteralPath (Join-Path $BackupDirectory "machine-path-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')).txt")
    [Environment]::SetEnvironmentVariable('Path', $after, 'Machine')
}
