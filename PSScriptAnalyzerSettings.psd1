@{
    Severity = @('Error', 'Warning')

    # These rules conflict with deliberate repository conventions: command-style
    # terminal output, Linux-compatible names, explicit state wrappers, and UTF-8
    # without a BOM. All other Error and Warning rules remain enabled.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        'PSUseApprovedVerbs'
        'PSUseSingularNouns'
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseBOMForUnicodeEncodedFile'
    )
}
