function Add-PodeScopedVariableInternal {
    [CmdletBinding(DefaultParameterSetName = 'Replace')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Replace')]
        [string]
        $GetReplace,

        [Parameter(ParameterSetName = 'Replace')]
        [string]
        $SetReplace = $null,

        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ParameterSetName = 'Internal')]
        [switch]
        $InternalFunction
    )

    # lowercase the name
    $Name = $Name.ToLowerInvariant()

    # check if var already defined
    if (Test-PodeScopedVariable -Name $Name) {
        throw ($msgTable.scopedVariableAlreadyDefinedExceptionMessage -f $Name)#"Scoped Variable already defined: $($Name)"
    }

    # add scoped var definition
    $PodeContext.Server.ScopedVariables[$Name] = @{
        Name             = $Name
        Type             = $PSCmdlet.ParameterSetName.ToLowerInvariant()
        ScriptBlock      = $ScriptBlock
        Get              = @{
            Pattern = "(?<full>\`$$($Name)\:(?<name>[a-z0-9_\?]+))"
            Replace = $GetReplace
        }
        Set              = @{
            Pattern = "(?<full>\`$$($Name)\:(?<name>[a-z0-9_\?]+)\s*=)"
            Replace = $SetReplace
        }
        InternalFunction = $InternalFunction.IsPresent
    }
}

function Add-PodeScopedVariablesInbuilt {
    Add-PodeScopedVariableInbuiltUsing
    Add-PodeScopedVariableInbuiltCache
    Add-PodeScopedVariableInbuiltSecret
    Add-PodeScopedVariableInbuiltSession
    Add-PodeScopedVariableInbuiltState
}

function Add-PodeScopedVariableInbuiltCache {
    Add-PodeScopedVariable -Name 'cache' `
        -SetReplace "Set-PodeCache -Key '{{name}}' -InputObject " `
        -GetReplace "Get-PodeCache -Key '{{name}}'"
}

function Add-PodeScopedVariableInbuiltSecret {
    Add-PodeScopedVariable -Name 'secret' `
        -SetReplace "Update-PodeSecret -Name '{{name}}' -InputObject " `
        -GetReplace "Get-PodeSecret -Name '{{name}}'"
}

function Add-PodeScopedVariableInbuiltSession {
    Add-PodeScopedVariable -Name 'session' `
        -SetReplace "`$WebEvent.Session.Data.'{{name}}'" `
        -GetReplace "`$WebEvent.Session.Data.'{{name}}'"
}

function Add-PodeScopedVariableInbuiltState {
    Add-PodeScopedVariable -Name 'state' `
        -SetReplace "Set-PodeState -Name '{{name}}' -Value " `
        -GetReplace "`$PodeContext.Server.State.'{{name}}'.Value"
}

function Add-PodeScopedVariableInbuiltUsing {
    Add-PodeScopedVariableInternal -Name 'using' -InternalFunction
}

function Convert-PodeScopedVariableInbuiltUsing {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    # do nothing if no script or session
    if (($null -eq $ScriptBlock) -or ($null -eq $PSSession)) {
        return $ScriptBlock, $null
    }

    # rename any __using_ vars for inner timers, etcs
    $strScriptBlock = "$($ScriptBlock)"
    $foundInnerUsing = $false

    while ($strScriptBlock -imatch '(?<full>\$__using_(?<name>[a-z0-9_\?]+))') {
        $foundInnerUsing = $true
        $strScriptBlock = $strScriptBlock.Replace($Matches['full'], "`$using:$($Matches['name'])")
    }

    # just return if there are no $using:
    if ($strScriptBlock -inotmatch '\$using:') {
        return $ScriptBlock, $null
    }

    # if we found any inner usings, recreate the scriptblock
    if ($foundInnerUsing) {
        $ScriptBlock = [scriptblock]::Create($strScriptBlock)
    }

    # get any using variables
    $usingVars = Get-PodeScopedVariableUsingVariables -ScriptBlock $ScriptBlock
    if (($null -eq $usingVars) -or ($usingVars.Count -eq 0)) {
        return $ScriptBlock, $null
    }

    # convert any using vars to use new names
    $usingVars = Find-PodeScopedVariableUsingVariableValues -UsingVariables $usingVars -PSSession $PSSession

    # now convert the script
    $newScriptBlock = Convert-PodeScopedVariableUsingVariables -ScriptBlock $ScriptBlock -UsingVariables $usingVars

    # return converted script
    return $newScriptBlock, $usingVars
}

function Get-PodeScopedVariableUsingVariables {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    return $ScriptBlock.Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.UsingExpressionAst] }, $true)
}

function Find-PodeScopedVariableUsingVariableValues {
    param(
        [Parameter(Mandatory = $true)]
        $UsingVariables,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    $mapped = @{}

    foreach ($usingVar in $UsingVariables) {
        # var name
        $varName = $usingVar.SubExpression.VariablePath.UserPath

        # only retrieve value if new var
        if (!$mapped.ContainsKey($varName)) {
            # get value, or get __using_ value for child scripts
            $value = $PSSession.PSVariable.Get($varName)
            if ([string]::IsNullOrEmpty($value)) {
                $value = $PSSession.PSVariable.Get("__using_$($varName)")
            }

            if ([string]::IsNullOrEmpty($value)) {
                throw ($msgTable.valueForUsingVariableNotFoundExceptionMessage -f $varName) #"Value for `$using:$($varName) could not be found"
            }

            # add to mapped
            $mapped[$varName] = @{
                OldName           = $usingVar.SubExpression.Extent.Text
                NewName           = "__using_$($varName)"
                NewNameWithDollar = "`$__using_$($varName)"
                SubExpressions    = @()
                Value             = $value.Value
            }
        }

        # add the vars sub-expression for replacing later
        $mapped[$varName].SubExpressions += $usingVar.SubExpression
    }

    return @($mapped.Values)
}

function Convert-PodeScopedVariableUsingVariables {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $UsingVariables
    )

    $varsList = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
    $newParams = New-Object System.Collections.ArrayList

    foreach ($usingVar in $UsingVariables) {
        foreach ($subExp in $usingVar.SubExpressions) {
            $null = $varsList.Add($subExp)
        }
    }

    $null = $newParams.AddRange(@($UsingVariables.NewNameWithDollar))
    $newParams = ($newParams -join ', ')
    $tupleParams = [tuple]::Create($varsList, $newParams)

    $bindingFlags = [System.Reflection.BindingFlags]'Default, NonPublic, Instance'
    $_varReplacerMethod = $ScriptBlock.Ast.GetType().GetMethod('GetWithInputHandlingForInvokeCommandImpl', $bindingFlags)
    $convertedScriptBlockStr = $_varReplacerMethod.Invoke($ScriptBlock.Ast, @($tupleParams))

    if (!$ScriptBlock.Ast.ParamBlock) {
        $convertedScriptBlockStr = "param($($newParams))`n$($convertedScriptBlockStr)"
    }

    $convertedScriptBlock = [scriptblock]::Create($convertedScriptBlockStr)

    if ($convertedScriptBlock.Ast.EndBlock[0].Statements.Extent.Text.StartsWith('$input |')) {
        $convertedScriptBlockStr = ($convertedScriptBlockStr -ireplace '\$input \|')
        $convertedScriptBlock = [scriptblock]::Create($convertedScriptBlockStr)
    }

    return $convertedScriptBlock
}