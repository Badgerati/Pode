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
    ExcludeRules = @( 'PSAvoidUsingPlainTextForPassword','PSUseShouldProcessForStateChangingFunctions',
    'PSAvoidUsingUsernameAndPasswordParams','PSUseProcessBlockForPipelineCommand','PSAvoidUsingConvertToSecureStringWithPlainText','PSReviewUnusedParameter' )

}