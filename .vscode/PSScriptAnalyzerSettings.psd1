# PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @('PSAvoidUsingCmdletAliases' ,'PSAvoidUsingPlainTextForPassword')
    # Add more rules to exclude as needed
}