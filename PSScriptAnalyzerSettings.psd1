# PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning', 'Information')
    ExcludeRules = @('PSAvoidUsingCmdletAliases' ,'PSAvoidUsingPlainTextForPassword','PSAvoidUsingWriteHost','PSAvoidUsingInvokeExpression','PSUseShouldProcessForStateChangingFunctions',
    'PSAvoidUsingUsernameAndPasswordParams','PSUseProcessBlockForPipelineCommand')
}