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
