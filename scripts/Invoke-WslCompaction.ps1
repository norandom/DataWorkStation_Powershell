[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)][ValidateNotNullOrEmpty()][string] $Distribution,
    [Parameter(DontShow = $true)][string] $ExpectedUserSid
)

function Get-WslCompactionTarget {
    param([string] $Name)
    $registrations = @(Get-ChildItem -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction Stop |
        Get-ItemProperty -ErrorAction Stop)
    $matchingDistributions = @($registrations | Where-Object DistributionName -eq $Name)
    if ($matchingDistributions.Count -ne 1) { throw "WSL distribution '$Name' was not found uniquely. Run wsl --list --verbose." }
    $registration = $matchingDistributions[0]
    if ($registration.Version -ne 2) { throw 'Compaction requires a WSL 2 distribution.' }
    $basePath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($registration.BasePath))
    $diskName = if ($registration.VhdFileName) { [string] $registration.VhdFileName } else { 'ext4.vhdx' }
    if ([IO.Path]::GetFileName($diskName) -ne $diskName -or [IO.Path]::GetExtension($diskName) -ne '.vhdx') {
        throw 'The registered VHDX filename is invalid.'
    }
    $disk = Get-Item -LiteralPath (Join-Path $basePath $diskName) -ErrorAction Stop
    if ($disk.PSIsContainer) { throw 'The registered VHDX path is not a file.' }
    if ($disk.Attributes -band [IO.FileAttributes]::SparseFile) {
        throw 'This VHDX is sparse. Offline Optimize-VHD compaction requires a non-sparse disk; sparse policy is not changed automatically.'
    }
    [pscustomobject]@{ Distribution = [string] $registration.DistributionName; Path = $disk.FullName; BeforeBytes = [long] $disk.Length }
}

function Test-WslCompactionAdministrator {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WslCompactionCommand {
    param([string[]] $ArgumentList, [switch] $PassThru)
    $output = @(& wsl.exe @ArgumentList 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($output -join "`n") -replace "`0", ''
    if ($exitCode -ne 0) { throw "wsl $($ArgumentList -join ' ') failed ($exitCode): $text" }
    if ($PassThru) { return $text.Trim() }
    if ($text.Trim()) { Write-Host $text.Trim() }
}

function Invoke-WslCompaction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string] $Distribution,
        [string] $ExpectedUserSid
    )
    $ErrorActionPreference = 'Stop'
    $userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($ExpectedUserSid -and $ExpectedUserSid -ne $userSid) {
        throw 'Elevation changed the Windows user. Run compact-wsl as the account that owns this distribution.'
    }
    $target = Get-WslCompactionTarget -Name $Distribution
    if (-not $PSCmdlet.ShouldProcess("$($target.Distribution): $($target.Path)",
        'Start if needed, trim free space as root, sync, terminate this distribution and compact its disk; leave it stopped')) { return }

    if (-not (Test-WslCompactionAdministrator)) {
        Write-Host 'Requesting administrator rights through Windows sudo for VHDX compaction.'
        $runtime = (Get-Command pwsh.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        & sudo.exe $runtime -NoProfile -File $PSCommandPath -Distribution $target.Distribution -ExpectedUserSid $userSid
        if ($LASTEXITCODE -ne 0) { throw "Elevated WSL compaction failed with exit code $LASTEXITCODE." }
        return
    }

    Import-Module Hyper-V -ErrorAction Stop
    $disk = Get-VHD -Path $target.Path -ErrorAction Stop
    if ($disk.VhdType -ne 'Dynamic' -or $disk.VhdFormat -ne 'VHDX') { throw 'Expected a dynamic VHDX disk.' }
    $beforeCapacity = $disk.Size
    Write-Host "Trimming $($target.Distribution); its sessions and containers will be stopped for compaction."
    # WSL --exec can inherit a PATH without Linux administrative directories.
    Invoke-WslCompactionCommand -ArgumentList @('--distribution', $target.Distribution, '--user', 'root', '--exec', '/bin/sh', '-c', 'export PATH="$PATH:/usr/sbin:/sbin"; exec fstrim --verbose /')
    Invoke-WslCompactionCommand -ArgumentList @('--distribution', $target.Distribution, '--user', 'root', '--exec', 'sync')
    Write-Host "Stopping $($target.Distribution)."
    Invoke-WslCompactionCommand -ArgumentList @('--terminate', $target.Distribution)

    # Some WSL versions keep a stopped distribution's disk attached to the idle VM.
    $disk = Get-VHD -Path $target.Path -ErrorAction Stop
    if ($disk.Attached) {
        $running = Invoke-WslCompactionCommand -ArgumentList @('--list', '--running', '--quiet') -PassThru
        if ([string]::IsNullOrWhiteSpace($running)) {
            Write-Host 'No distributions are running; shutting down the idle WSL VM to release the disk.'
            Invoke-WslCompactionCommand -ArgumentList @('--shutdown')
        }
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $disk = Get-VHD -Path $target.Path -ErrorAction Stop
        if (-not $disk.Attached) { break }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($disk.Attached) { throw 'The VHDX is still attached. Close WSL clients; no other distribution was stopped and compaction was not attempted.' }

    Write-Host ('Compacting {0} ({1:N2} GiB)...' -f $target.Path, ($target.BeforeBytes / 1GB))
    Optimize-VHD -Path $target.Path -Mode Full -ErrorAction Stop
    $after = Get-VHD -Path $target.Path -ErrorAction Stop
    if ($after.Size -ne $beforeCapacity) { throw 'The virtual disk capacity unexpectedly changed.' }
    $afterBytes = (Get-Item -LiteralPath $target.Path -ErrorAction Stop).Length
    [pscustomobject][ordered]@{
        Distribution = $target.Distribution
        Path = $target.Path
        BeforeGiB = [math]::Round($target.BeforeBytes / 1GB, 2)
        AfterGiB = [math]::Round($afterBytes / 1GB, 2)
        ReclaimedGiB = [math]::Round(($target.BeforeBytes - $afterBytes) / 1GB, 2)
        State = 'Stopped'
    }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-WslCompaction @PSBoundParameters }
