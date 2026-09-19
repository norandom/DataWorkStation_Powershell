@{
    Settings = @{
        OocOn = 'true'
        ManageOnlyCurrentUser = 'false'
        ExcludeForegroundProcesses2 = 'true'
        ExcludeChildrenOfForeground = 'false'
        ExcludeServices = 'true'
        TameOnlyNormal = 'true'
        LowerToIdleInsteadOfBelowNormal = 'false'
        DoNotLowerPriorityClass = 'false'
        UseEfficiencyMode = 'false'
        BoostForegroundProcess = 'false'
        SmartTrimIsEnabled = 'false'
        SmartTrimWorkingSetTrims = 'false'
        SmartTrimClearStandbyList = 'false'
        SmartTrimClearFileCache = 'false'
    }
    ProtectedProcesses = @('dwm.exe', 'explorer.exe', 'taskmgr.exe', 'ProcessGovernor.exe', 'MemoryLimits.exe')
}
