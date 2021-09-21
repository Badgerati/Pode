<#
.SYNOPSIS
Sets an object within the shared state.

.DESCRIPTION
Sets an object within the shared state.

.PARAMETER Name
The name of the state object.

.PARAMETER Value
The value to set in the state.

.PARAMETER Scope
An optional Scope for the state object, used when saving the state.

.EXAMPLE
Set-PodeState -Name 'Data' -Value @{ 'Name' = 'Rick Sanchez' }

.EXAMPLE
Set-PodeState -Name 'Users' -Value @('user1', 'user2') -Scope General, Users
#>
function Set-PodeState
{
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(ValueFromPipeline=$true)]
        [object]
        $Value,

        [Parameter()]
        [string[]]
        $Scope
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    if ($null -eq $Scope) {
        $Scope = @()
    }

    $PodeContext.Server.State[$Name] = @{
        Value = $Value
        Scope = $Scope
    }

    return $Value
}

<#
.SYNOPSIS
Retrieves some state object from the shared state.

.DESCRIPTION
Retrieves some state object from the shared state.

.PARAMETER Name
The name of the state object.

.PARAMETER WithScope
If supplied, the state's value and scope will be returned as a hashtable.

.EXAMPLE
Get-PodeState -Name 'Data'
#>
function Get-PodeState
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [switch]
        $WithScope
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    if ($WithScope) {
        return $PodeContext.Server.State[$Name]
    }
    else {
        return $PodeContext.Server.State[$Name].Value
    }
}

<#
.SYNOPSIS
Returns the current names of state variables.

.DESCRIPTION
Returns the current names of state variables that have been set. You can filter the result using Scope or a Pattern.

.PARAMETER Pattern
An optional regex Pattern to filter the state names.

.PARAMETER Scope
An optional Scope to filter the state names.

.EXAMPLE
$names = Get-PodeStateNames -Scope '<scope>'

.EXAMPLE
$names = Get-PodeStateNames -Pattern '^\w+[0-9]{0,2}$'
#>
function Get-PodeStateNames
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [string[]]
        $Scope
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    if ($null -eq $Scope) {
        $Scope = @()
    }

    $tempState = $PodeContext.Server.State.Clone()
    $keys = $tempState.Keys

    if ($Scope.Length -gt 0) {
        $keys = @(foreach($key in $keys) {
            if ($tempState[$key].Scope -iin $Scope) {
                $key
            }
        })
    }

    if (![string]::IsNullOrWhiteSpace($Pattern)) {
        $keys = @(foreach($key in $keys) {
            if ($key -imatch $Pattern) {
                $key
            }
        })
    }

    return $keys
}

<#
.SYNOPSIS
Removes some state object from the shared state.

.DESCRIPTION
Removes some state object from the shared state. After removal, the original object being stored is returned.

.PARAMETER Name
The name of the state object.

.EXAMPLE
Remove-PodeState -Name 'Data'
#>
function Remove-PodeState
{
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    $value = $PodeContext.Server.State[$Name].Value
    $PodeContext.Server.State.Remove($Name) | Out-Null
    return $value
}

<#
.SYNOPSIS
Saves the current shared state to a supplied JSON file.

.DESCRIPTION
Saves the current shared state to a supplied JSON file. When using this function, it's recommended to wrap it in a Lock-PodeObject block.

.PARAMETER Path
The path to a JSON file which the current state will be saved to.

.PARAMETER Scope
An optional array of scopes for state objects that should be saved. (This has a lower precedence than Exclude/Include)

.PARAMETER Exclude
An optional array of state object names to exclude from being saved. (This has a higher precedence than Include)

.PARAMETER Include
An optional array of state object names to only include when being saved.

.PARAMETER Compress
If supplied, the saved JSON will be compressed.

.EXAMPLE
Save-PodeState -Path './state.json'

.EXAMPLE
Save-PodeState -Path './state.json' -Exclude Name1, Name2

.EXAMPLE
Save-PodeState -Path './state.json' -Scope Users
#>
function Save-PodeState
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $Exclude,

        [Parameter()]
        [string[]]
        $Include,

        [switch]
        $Compress
    )

    # error if attempting to use outside of the pode server
    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    # get the full path to save the state
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    # contruct the state to save (excludes, etc)
    $state = $PodeContext.Server.State.Clone()

    # scopes
    if (($null -ne $Scope) -and ($Scope.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            # remove if no scope
            if (($null -eq $state[$_key].Scope) -or ($state[$_key].Scope.Length -eq 0)) {
                $state.Remove($_key) | Out-Null
                continue
            }

            # check scopes (only remove if none match)
            $found = $false

            foreach ($_scope in $state[$_key].Scope) {
                if ($Scope -icontains $_scope) {
                    $found = $true
                    break
                }
            }

            if ($found) {
                continue
            }

            # none matched, remove
            $state.Remove($_key) | Out-Null
        }
    }

    # include keys
    if (($null -ne $Include) -and ($Include.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            if ($Include -inotcontains $_key) {
                $state.Remove($_key) | Out-Null
            }
        }
    }

    # exclude keys
    if (($null -ne $Exclude) -and ($Exclude.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            if ($Exclude -icontains $_key) {
                $state.Remove($_key) | Out-Null
            }
        }
    }

    # save the state
    $state | ConvertTo-Json -Depth 10 -Compress:$Compress | Out-File -FilePath $Path -Force | Out-Null
}

<#
.SYNOPSIS
Restores the shared state from some JSON file.

.DESCRIPTION
Restores the shared state from some JSON file.

.PARAMETER Path
The path to a JSON file that contains the state information.

.EXAMPLE
Restore-PodeState -Path './state.json'
#>
function Restore-PodeState
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    # error if attempting to use outside of the pode server
    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    # get the full path to the state
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    if (!(Test-Path $Path)) {
        return
    }

    # restore the state from file
    $state = @{}

    if (Test-PodeIsPSCore) {
        $state = (Get-Content $Path -Force | ConvertFrom-Json -AsHashtable -Depth 10)
    }
    else {
        $props = (Get-Content $Path -Force | ConvertFrom-Json).psobject.properties
        foreach ($prop in $props) {
            $state[$prop.Name] = $prop.Value
        }
    }

    # check for no scopes, and add for backwards compat
    $convert = $false
    foreach ($_key in $state.Clone().Keys) {
        if ($null -eq $state[$_key].Scope) {
            $convert = $true
            break
        }
    }

    if ($convert) {
        foreach ($_key in $state.Clone().Keys) {
            $state[$_key] = @{
                Value = $state[$_key]
                Scope = @()
            }
        }
    }

    # set the scope to the main context
    $PodeContext.Server.State = $state.Clone()
}

<#
.SYNOPSIS
Tests if the shared state contains some state object.

.DESCRIPTION
Tests if the shared state contains some state object.

.PARAMETER Name
The name of the state object.

.EXAMPLE
Test-PodeState -Name 'Data'
#>
function Test-PodeState
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        throw "Pode has not been initialised"
    }

    return $PodeContext.Server.State.ContainsKey($Name)
}