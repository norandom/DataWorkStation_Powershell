@{
    Paths = @(
        'D:\'
        '%USERPROFILE%\Source'
    )

    Preferences = @{
        ScanAvgCPULoadFactor               = 15
        ScanOnlyIfIdleEnabled              = $true
        DisableCpuThrottleOnIdleScans      = $false
        EnableLowCpuPriority               = $true
        DisableCatchupQuickScan            = $true
        DisableCatchupFullScan             = $true
        CheckForSignaturesBeforeRunningScan = $true
        ThrottleForScheduledScanOnly       = $true
    }
}
