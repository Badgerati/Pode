# PSScriptAnalyzerSettings.psd1
@{
    Severity     = @('Error', 'Warning', 'Information')

    Rules = @{
        PSReviewUnusedParameter = @{
            CommandsToTraverse = @(
                'Where-Object',
                'Remove-PodeRoute',
                'Lock-PodeObject',
                'Use-PodeStream'
            )
        }
    }
    ExcludeRules = @( 'PSAvoidUsingPlainTextForPassword','PSUseShouldProcessForStateChangingFunctions',
    'PSAvoidUsingUsernameAndPasswordParams','PSUseProcessBlockForPipelineCommand','PSAvoidUsingConvertToSecureStringWithPlainText','PSReviewUnusedParameter' )

}