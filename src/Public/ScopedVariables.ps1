<#
.SYNOPSIS
Converts Scoped Variables within a given ScriptBlock.

.DESCRIPTION
Converts Scoped Variables within a given ScriptBlock, and returns the updated ScriptBlock back, including any
using-variable values that will need to be supplied as parameters to the ScriptBlock first.

.PARAMETER ScriptBlock
The ScriptBlock to be converted.

.PARAMETER PSSession
An optional SessionState object, used to retrieve using-variable values.
If not supplied, using-variable values will not be converted.

.PARAMETER Exclude
An optional array of one or more Scoped Variable Names to Exclude from converting. (ie: Session, Using, or a Name from Add-PodeScopedVariable)

.EXAMPLE
$ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

.EXAMPLE
$ScriptBlock = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -Exclude Session, Using
#>
function Convert-PodeScopedVariables {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [System.Management.Automation.SessionState]
        $PSSession,

        [Parameter()]
        [string[]]
        $Exclude
    )

    # do nothing if no scriptblock
    if ($null -eq $ScriptBlock) {
        return $ScriptBlock
    }

    # using vars
    $usingVars = $null

    # loop through each defined scoped variable and convert, unless excluded
    foreach ($key in $PodeContext.Server.ScopedVariables.Keys) {
        # excluded?
        if ($Exclude -icontains $key) {
            continue
        }

        # convert scoped var
        $ScriptBlock, $otherResults = Convert-PodeScopedVariable -Name $key -ScriptBlock $ScriptBlock -PSSession $PSSession

        # using vars?
        if (($null -ne $otherResults) -and ($key -ieq 'using')) {
            $usingVars = $otherResults
        }
    }

    # return just the scriptblock, or include using vars as well
    if ($null -ne $usingVars) {
        return $ScriptBlock, $usingVars
    }

    return $ScriptBlock
}

<#
.SYNOPSIS
Converts a Scoped Variable within a given ScriptBlock.

.DESCRIPTION
Converts a Scoped Variable within a given ScriptBlock, and returns the updated ScriptBlock back, including any
other values that will need to be supplied as parameters to the ScriptBlock first.

.PARAMETER Name
The Name of the Scoped Variable to convert. (ie: Session, Using, or a Name from Add-PodeScopedVariable)

.PARAMETER ScriptBlock
The ScriptBlock to be converted.

.PARAMETER PSSession
An optional SessionState object, used to retrieve using-variable values or other values where scope is required.

.EXAMPLE
$ScriptBlock = Convert-PodeScopedVariable -Name State -ScriptBlock $ScriptBlock

.EXAMPLE
$ScriptBlock, $otherResults = Convert-PodeScopedVariable -Name Using -ScriptBlock $ScriptBlock
#>
function Convert-PodeScopedVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    # do nothing if no scriptblock
    if ($null -eq $ScriptBlock) {
        return $ScriptBlock
    }

    # check if scoped var defined
    if (!(Test-PodeScopedVariable -Name $Name)) {
        throw "Scoped Variable not found: $($Name)"
    }

    # get the scoped var metadata
    $scopedVar = $PodeContext.Server.ScopedVariables[$Name]

    # scriptblock or replace?
    if ($null -ne $scopedVar.ScriptBlock) {
        return Invoke-PodeScriptBlock `
            -ScriptBlock $scopedVar.ScriptBlock `
            -Arguments $ScriptBlock, $PSSession, $scopedVar.Get.Pattern, $scopedVar.Set.Pattern `
            -Splat `
            -Return `
            -NoNewClosure
    }

    # replace style
    else {
        # convert scriptblock to string
        $strScriptBlock = "$($ScriptBlock)"

        # see if the script contains any form of the scoped variable, and if not just return
        $found = $strScriptBlock -imatch "\`$$($Name)\:"
        if (!$found) {
            return $ScriptBlock
        }

        # loop and replace "set" syntax if replace template supplied
        if (![string]::IsNullOrEmpty($scopedVar.Set.Replace)) {
            while ($strScriptBlock -imatch $scopedVar.Set.Pattern) {
                $setReplace = $scopedVar.Set.Replace.Replace('{{name}}', $Matches['name'])
                $strScriptBlock = $strScriptBlock.Replace($Matches['full'], $setReplace)
            }
        }

        # loop and replace "get" syntax
        while ($strScriptBlock -imatch $scopedVar.Get.Pattern) {
            $getReplace = $scopedVar.Get.Replace.Replace('{{name}}', $Matches['name'])
            $strScriptBlock = $strScriptBlock.Replace($Matches['full'], "($($getReplace))")
        }

        # convert update scriptblock back
        return [scriptblock]::Create($strScriptBlock)
    }
}

<#
.SYNOPSIS
Adds a new Scoped Variable.

.DESCRIPTION
Adds a new Scoped Variable, to make calling certain functions simpler.
For example "$state:Name" instead of "Get-PodeState" and "Set-PodeState".

.PARAMETER Name
The Name of the Scoped Variable.

.PARAMETER GetReplace
A template to be used when converting "$var = $SV:<name>" to a "Get-SVValue -Name <name>" syntax.
You can use the "{{name}}" placeholder to show where the <name> would be placed in the conversion. The result will also be automatically wrapped in brackets.
For example, "$var = $state:<name>" to "Get-PodeState -Name <name>" would need a GetReplace value of "Get-PodeState -Name '{{name}}'".

.PARAMETER SetReplace
An optional template to be used when converting "$SV:<name> = <value>" to a "Set-SVValue -Name <name> -Value <value>" syntax.
You can use the "{{name}}" placeholder to show where the <name> would be placed in the conversion. The <value> will automatically be appended to the end.
For example, "$state:<name> = <value>" to "Set-PodeState -Name <name> -Value <value>" would need a SetReplace value of "Set-PodeState -Name '{{name}}' -Value ".

.PARAMETER ScriptBlock
For more advanced conversions, that aren't as simple as a simple find/replace, you can supply a ScriptBlock instead.
This ScriptBlock will be supplied ScriptBlock to convert, followed by a SessionState object, and the Get/Set regex patterns, as parameters.
The ScriptBlock should returned a converted ScriptBlock that works, plus an optional array of values that should be supplied to the ScriptBlock when invoked.

.EXAMPLE
Add-PodeScopedVariable -Name 'cache' -SetReplace "Set-PodeCache -Key '{{name}}' -InputObject " -GetReplace "Get-PodeCache -Key '{{name}}'"

.EXAMPLE
Add-PodeScopedVariable -Name 'config' -ScriptBlock {
    param($ScriptBlock, $SessionState, $GetPattern, $SetPattern)
    $strScriptBlock = "$($ScriptBlock)"
    $template = "(Get-PodeConfig).'{{name}}'"

    # allows "$port = $config:port" instead of "$port = (Get-PodeConfig).port"
    while ($strScriptBlock -imatch $GetPattern) {
        $getReplace = $template.Replace('{{name}}', $Matches['name'])
        $strScriptBlock = $strScriptBlock.Replace($Matches['full'], "($($getReplace))")
    }

    return [scriptblock]::Create($strScriptBlock)
}
#>
function Add-PodeScopedVariable {
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
        $ScriptBlock
    )

    # check if var already defined
    if (Test-PodeScopedVariable -Name $Name) {
        throw "Scoped Variable already defined: $($Name)"
    }

    # add scoped var definition
    $PodeContext.Server.ScopedVariables[$Name] = @{
        $Name       = $Name
        ScriptBlock = $ScriptBlock
        Get         = @{
            Pattern = "(?<full>\`$$($Name)\:(?<name>[a-z0-9_\?]+))"
            Replace = $GetReplace
        }
        Set         = @{
            Pattern = "(?<full>\`$$($Name)\:(?<name>[a-z0-9_\?]+)\s*=)"
            Replace = $SetReplace
        }
    }
}

<#
.SYNOPSIS
Removes a Scoped Variable.

.DESCRIPTION
Removes a Scoped Variable.

.PARAMETER Name
The Name of a Scoped Variable to remove.

.EXAMPLE
Remove-PodeScopedVariable -Name State
#>
function Remove-PodeScopedVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Server.ScopedVariables.Remove($Name)
}

<#
.SYNOPSIS
Tests if a Scoped Variable exists.

.DESCRIPTION
Tests if a Scoped Variable exists.

.PARAMETER Name
The Name of the Scoped Variable to check.

.EXAMPLE
if (Test-PodeScopedVariable -Name $Name) { ... }
#>
function Test-PodeScopedVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.ScopedVariables.Contains($Name)
}

<#
.SYNOPSIS
Removes all Scoped Variables.

.DESCRIPTION
Removes all Scoped Variables.

.EXAMPLE
Clear-PodeScopedVariables
#>
function Clear-PodeScopedVariables {
    $null = $PodeContext.Server.ScopedVariables.Clear()
}

<#
.SYNOPSIS
Get a Scoped Variable(s).

.DESCRIPTION
Get a Scoped Variable(s).

.PARAMETER Name
The Name of the Scoped Variable(s) to retrieve.

.EXAMPLE
Get-PodeScopedVariable -Name State

.EXAMPLE
Get-PodeScopedVariable -Name State, Using
#>
function Get-PodeScopedVariable {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    # return all if no Name
    if ([string]::IsNullOrEmpty($Name) -or ($Name.Length -eq 0)) {
        return $PodeContext.Server.ScopedVariables.Values
    }

    # return filtered
    return @(foreach ($n in $Name) {
            $PodeContext.Server.ScopedVariables[$n]
        })
}

<#
.SYNOPSIS
Automatically loads Scoped Variable ps1 files

.DESCRIPTION
Automatically loads Scoped Variable ps1 files from either a /scoped-vars folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeScopedVariables

.EXAMPLE
Use-PodeScopedVariables -Path './my-vars'
#>
function Use-PodeScopedVariables {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'scoped-vars'
}