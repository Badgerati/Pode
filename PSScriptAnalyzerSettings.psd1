@{
    Severity            = @('Error', 'Warning', 'Information')
    IncludeDefaultRules = $true

    CustomRulePath      = @(
        './analyzers/AvoidNewObjectRule.psm1'
    )

    Rules               = @{
        PSReviewUnusedParameter = @{
            CommandsToTraverse = @(
                'Where-Object',
                'Remove-PodeRoute'
            )
        }
        AvoidNewObjectRule      = @{
            Severity = 'Warning'
        }
    }

    ExcludeRules        = @(
        'PSAvoidUsingPlainTextForPassword',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSUseProcessBlockForPipelineCommand',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSReviewUnusedParameter',
        'PSAvoidAssignmentToAutomaticVariable',
        'PSUseBOMForUnicodeEncodedFile',
        'PSAvoidTrailingWhitespace'
    )

}