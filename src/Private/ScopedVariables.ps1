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
        throw ($PodeLocale.scopedVariableAlreadyDefinedExceptionMessage -f $Name)#"Scoped Variable already defined: $($Name)"
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
        -GetReplace "`$PodeContext.Server.State['{{name}}'].Value"
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
    $usingVars = Get-PodeScopedVariableUsingVariable -ScriptBlock $ScriptBlock
    if (($null -eq $usingVars) -or ($usingVars.Count -eq 0)) {
        return $ScriptBlock, $null
    }

    # convert any using vars to use new names
    $usingVars = Find-PodeScopedVariableUsingVariableValue -UsingVariable $usingVars -PSSession $PSSession

    # now convert the script
    $newScriptBlock = Convert-PodeScopedVariableUsingVariable -ScriptBlock $ScriptBlock -UsingVariables $usingVars

    # return converted script
    return $newScriptBlock, $usingVars
}

<#
.SYNOPSIS
    Retrieves all occurrences of using variables within a given script block.

.DESCRIPTION
    The `Get-PodeScopedVariableUsingVariable` function analyzes a script block and identifies all instances of using variables.
    It returns an array of `UsingExpressionAst` objects representing these occurrences.

.PARAMETER ScriptBlock
    Specifies the script block to analyze. This parameter is mandatory.

.OUTPUTS
    Returns an array of `UsingExpressionAst` objects representing using variables found in the script block.

.EXAMPLE
    # Example usage:
    $scriptBlock = {
        $usingVar1 = "Hello"
        $usingVar2 = "World"
        Write-Host "Using variables: $usingVar1, $usingVar2"
    }

    $usingVariables = Get-PodeScopedVariableUsingVariable -ScriptBlock $scriptBlock
    # Process the identified using variables as needed.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeScopedVariableUsingVariable {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    # Analyze the script block AST to find using variables
    return $ScriptBlock.Ast.FindAll({ $args[0] -is [System.Management.Automation.Language.UsingExpressionAst] }, $true)
}

<#
.SYNOPSIS
    Finds and maps using variables within a given script block to their corresponding values.

.DESCRIPTION
    The `Find-PodeScopedVariableUsingVariableValue` function analyzes a collection of using variables
    (represented as `UsingExpressionAst` objects) within a script block. It retrieves the values of these
    variables from the specified session state (`$PSSession`) and maps them for further processing.

.PARAMETER UsingVariable
    Specifies an array of `UsingExpressionAst` objects representing using variables found in the script block.
    This parameter is mandatory.

.PARAMETER PSSession
    Specifies the session state from which to retrieve variable values. This parameter is mandatory.

.OUTPUTS
    Returns an array of custom objects, each containing the following properties:
    - `OldName`: The original expression text for the using variable.
    - `NewName`: The modified name for the using variable (prefixed with "__using_").
    - `NewNameWithDollar`: The modified name with a dollar sign prefix (e.g., `$__using_VariableName`).
    - `SubExpressions`: An array of sub-expressions associated with the using variable.
    - `Value`: The value of the using variable retrieved from the session state.

.EXAMPLE
    # Example usage:
    $usingVariables = Get-PodeScopedVariableUsingVariable -ScriptBlock $scriptBlock
    $mappedVariables = Find-PodeScopedVariableUsingVariableValue -UsingVariable $usingVariables -PSSession $sessionState
    # Process the mapped variables as needed.

.NOTES
    - The function handles both direct using variables and child script using variables (prefixed with "__using_").
    - This is an internal function and may change in future releases of Pode.
#>
function Find-PodeScopedVariableUsingVariableValue {
    param(
        [Parameter(Mandatory = $true)]
        $UsingVariable,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    $mapped = @{}

    foreach ($usingVar in $UsingVariable) {
        # Extract variable name
        $varName = $usingVar.SubExpression.VariablePath.UserPath

        # only retrieve value if new var
        if (!$mapped.ContainsKey($varName)) {
            # get value, or get __using_ value for child scripts
            $value = $PSSession.PSVariable.Get($varName)
            if ([string]::IsNullOrEmpty($value)) {
                $value = $PSSession.PSVariable.Get("__using_$($varName)")
            }

            if ([string]::IsNullOrEmpty($value)) {
                throw ($PodeLocale.valueForUsingVariableNotFoundExceptionMessage -f $varName) #"Value for `$using:$($varName) could not be found"
            }

            # Add to mapped variables
            $mapped[$varName] = @{
                OldName           = $usingVar.SubExpression.Extent.Text
                NewName           = "__using_$($varName)"
                NewNameWithDollar = "`$__using_$($varName)"
                SubExpressions    = @()
                Value             = $value.Value
            }
        }

        # Add the variable's sub-expression for later replacement
        $mapped[$varName].SubExpressions += $usingVar.SubExpression
    }

    return @($mapped.Values)
}

<#
.SYNOPSIS
    Converts a script block by replacing using variables with their corresponding values.

.DESCRIPTION
    The `Convert-PodeScopedVariableUsingVariable` function takes a script block and a collection of using variables.
    It replaces the using variables within the script block with their associated values.

.PARAMETER ScriptBlock
    Specifies the script block to convert. This parameter is mandatory.

.PARAMETER UsingVariables
    Specifies an array of custom objects representing using variables and their values.
    Each object should have the following properties:
    - `OldName`: The original expression text for the using variable.
    - `NewNameWithDollar`: The modified name with a dollar sign prefix (e.g., `$__using_VariableName`).
    - `SubExpressions`: An array of sub-expressions associated with the using variable.
    - `Value`: The value of the using variable.

.OUTPUTS
    Returns a new script block with replaced using variables.

.EXAMPLE
    # Example usage:
    $usingVariables = @(
        @{
            OldName           = '$usingVar1'
            NewNameWithDollar = '$__using_usingVar1'
            SubExpressions    = @($usingVar1.SubExpression1, $usingVar1.SubExpression2)
            Value             = 'SomeValue1'
        },
        # Add other using variables here...
    )

    $convertedScriptBlock = Convert-PodeScopedVariableUsingVariable -ScriptBlock $originalScriptBlock -UsingVariables $usingVariables
    # Use the converted script block as needed.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Convert-PodeScopedVariableUsingVariable {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $UsingVariables
    )
    # Create a list of variable expressions for replacement
    $varsList = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
    $newParams = New-Object System.Collections.ArrayList

    foreach ($usingVar in $UsingVariables) {
        foreach ($subExp in $usingVar.SubExpressions) {
            $null = $varsList.Add($subExp)
        }
    }

    # Create a comma-separated list of new parameters
    $null = $newParams.AddRange(@($UsingVariables.NewNameWithDollar))
    $newParams = ($newParams -join ', ')
    $tupleParams = [tuple]::Create($varsList, $newParams)

    # Invoke the internal method to replace variables in the script block
    $bindingFlags = [System.Reflection.BindingFlags]'Default, NonPublic, Instance'
    $_varReplacerMethod = $ScriptBlock.Ast.GetType().GetMethod('GetWithInputHandlingForInvokeCommandImpl', $bindingFlags)
    $convertedScriptBlockStr = $_varReplacerMethod.Invoke($ScriptBlock.Ast, @($tupleParams))

    if (!$ScriptBlock.Ast.ParamBlock) {
        $convertedScriptBlockStr = "param($($newParams))`n$($convertedScriptBlockStr)"
    }

    $convertedScriptBlock = [scriptblock]::Create($convertedScriptBlockStr)

    # Handle cases where the script block starts with '$input |'
    if ($convertedScriptBlock.Ast.EndBlock[0].Statements.Extent.Text.StartsWith('$input |')) {
        $convertedScriptBlockStr = ($convertedScriptBlockStr -ireplace '\$input \|')
        $convertedScriptBlock = [scriptblock]::Create($convertedScriptBlockStr)
    }

    return $convertedScriptBlock
}