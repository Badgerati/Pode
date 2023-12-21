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
        return (Invoke-PodeScriptBlock -ScriptBlock $scopedVar.ScriptBlock -Arguments $ScriptBlock, $PSSession -Splat -Return -NoNewClosure)
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

        # loop and replace "set" syntax
        while ($strScriptBlock -imatch $scopedVar.Set.Pattern) {
            $setReplace = $scopedVar.Set.Replace.Replace('{{name}}', $Matches['name'])
            $strScriptBlock = $strScriptBlock.Replace($Matches['full'], $setReplace)
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

function Add-PodeScopedVariable {
    [CmdletBinding(DefaultParameterSetName = 'Replace')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Replace')]
        [string]
        $SetReplace,

        [Parameter(Mandatory = $true, ParameterSetName = 'Replace')]
        [string]
        $GetReplace,

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
        Set         = @{
            Pattern = "(?<full>\`$$($Name)\:(?<name>[a-z0-9_\?]+)\s*=)"
            Replace = $SetReplace
        }
        Get         = @{
            Pattern = "(?<full>\`$$($Name)\:(?<name>[a-z0-9_\?]+))"
            Replace = $GetReplace
        }
    }
}

function Remove-PodeScopedVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Server.ScopedVariables.Remove($Name)
}

function Test-PodeScopedVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.ScopedVariables.Contains($Name)
}

function Clear-PodeScopedVariables {
    $null = $PodeContext.Server.ScopedVariables.Clear()
}

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

function Use-PodeScopedVariables {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'scoped-vars'
}