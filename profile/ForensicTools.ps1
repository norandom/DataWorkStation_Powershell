# Native Windows forensic commands shared by Windows PowerShell and PowerShell.

function global:ewf-verify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ReportDirectory,

        [switch] $Plan,
        [switch] $Json
    )

    $verificationScript = Join-Path $env:USERPROFILE 'Source\PowerShell\scripts\Invoke-EwfVerification.ps1'
    & $verificationScript -Path $Path -ReportDirectory $ReportDirectory -Plan:$Plan -Json:$Json
}

function global:autopsy {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][object[]] $Arguments)

    $configuration = Import-PowerShellDataFile (Join-Path $env:USERPROFILE 'Source\PowerShell\config\autopsy.psd1')
    $root = [Environment]::ExpandEnvironmentVariables($configuration.Package.InstallRoot)
    $binary = Join-Path $root $configuration.Package.GuiBinary
    if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
        throw "Autopsy is not installed at the declared path: $binary"
    }
    Start-Process -FilePath $binary -ArgumentList $Arguments
}

function global:Invoke-AutopsyPrivateTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(ValueFromRemainingArguments = $true)][object[]] $Arguments
    )

    $configuration = Import-PowerShellDataFile (Join-Path $env:USERPROFILE 'Source\PowerShell\config\autopsy.psd1')
    $record = @($configuration.PrivateCommands | Where-Object Name -eq $Name)
    if ($record.Count -ne 1) { throw "Unknown or ambiguous Autopsy private command: $Name" }
    $root = [Environment]::ExpandEnvironmentVariables($configuration.Package.InstallRoot)
    $binary = Join-Path $root $record[0].RelativePath
    if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw "Autopsy private tool is missing: $binary" }
    $workingDirectory = if ($record[0].WorkingDirectory) { Join-Path $root $record[0].WorkingDirectory } else { Split-Path -Parent $binary }
    Push-Location $workingDirectory
    try { & $binary @Arguments } finally { Pop-Location }
}

function global:autopsy-regripper { Invoke-AutopsyPrivateTool -Name autopsy-regripper -Arguments $args }
function global:autopsy-ewfexport { Invoke-AutopsyPrivateTool -Name autopsy-ewfexport -Arguments $args }
function global:autopsy-tesseract { Invoke-AutopsyPrivateTool -Name autopsy-tesseract -Arguments $args }
function global:autopsy-yara { Invoke-AutopsyPrivateTool -Name autopsy-yara -Arguments $args }
function global:autopsy-photorec { Invoke-AutopsyPrivateTool -Name autopsy-photorec -Arguments $args }
function global:autopsy-testdisk { Invoke-AutopsyPrivateTool -Name autopsy-testdisk -Arguments $args }
function global:autopsy-gst-inspect { Invoke-AutopsyPrivateTool -Name autopsy-gst-inspect -Arguments $args }
function global:autopsy-log2timeline { Invoke-AutopsyPrivateTool -Name autopsy-log2timeline -Arguments $args }
function global:autopsy-tsk-logical-imager { Invoke-AutopsyPrivateTool -Name autopsy-tsk-logical-imager -Arguments $args }

function global:autopsy-defender-off { Invoke-ManagedDefenderState -Mode Disable }
function global:autopsy-defender-on { Invoke-ManagedDefenderState -Mode Enable }
function global:autopsy-defender-status { Invoke-ManagedDefenderState -Mode Status }
