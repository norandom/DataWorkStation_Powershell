@{
    Severity = @('Error', 'Warning')

    # Exclude rules that conflict with repository conventions: command-oriented
    # terminal output, Linux-compatible names, explicit state wrappers, and UTF-8
    # without a BOM. Keep every other Error and Warning rule enabled.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        'PSUseApprovedVerbs'
        'PSUseSingularNouns'
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseBOMForUnicodeEncodedFile'
    )
}
