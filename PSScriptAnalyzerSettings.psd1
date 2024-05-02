# PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning', 'Information')

    Rules = @{
        PSReviewUnusedParameter = @{
            CommandsToTraverse = @(
                'Where-Object','Remove-PodeRoute'
            )
        }
    }
    ExcludeRules = @('PSAvoidUsingCmdletAliases' ,'PSAvoidUsingPlainTextForPassword','PSAvoidUsingWriteHost','PSAvoidUsingInvokeExpression','PSUseShouldProcessForStateChangingFunctions',
    'PSAvoidUsingUsernameAndPasswordParams','PSUseProcessBlockForPipelineCommand','PSAvoidUsingConvertToSecureStringWithPlainText','PSReviewUnusedParameter' )

}