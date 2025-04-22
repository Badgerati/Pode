@{
    Severity            = @('Error', 'Warning', 'Information')
    IncludeDefaultRules = $true

    CustomRulePath      = @(
        './analyzers/AvoidNewObjectRule.psm1',
        './analyzers/AvoidForEachObjectRule.psm1',
        './analyzers/AvoidWhereObjectRule.psm1',
        './analyzers/AvoidSelectObjectRule.psm1',
        './analyzers/AvoidMeasureObjectRule.psm1'
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
        AvoidForEachObjectRule  = @{
            Severity = 'Warning'
        }
        AvoidWhereObjectRule    = @{
            Severity = 'Warning'
        }
        AvoidSelectObjectRule   = @{
            Severity = 'Warning'
        }
        AvoidMeasureObjectRule  = @{
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