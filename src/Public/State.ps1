<#
.SYNOPSIS
    Sets an object within the shared state of Pode.

.DESCRIPTION
    Sets an object within the shared state, allowing shared data management across various scopes.
    Supports thread-safe operations by converting the state to a concurrent dictionary when required.

.PARAMETER Name
    Specifies the name of the state object, used as the key to identify the object within the shared state.

.PARAMETER Value
    Specifies the value to set in the state. This can be any object, such as a string, array, or hash table.

.PARAMETER Scope
    An optional array of scopes to categorize the state object, enabling specific management based on scope.

.PARAMETER Threadsafe
    Ensures the shared state operates in a thread-safe manner by converting it to a concurrent dictionary.

.EXAMPLE
    Set-PodeState -Name 'Data' -Value @{ 'Name' = 'Rick Sanchez' }
    Sets a hash table with a key-value pair in the shared state under the name 'Data'.

.EXAMPLE
    Set-PodeState -Name 'Users' -Value @('user1', 'user2') -Scope General, Users
    Sets an array of user names within the shared state under the name 'Users' with specified scopes.
#>
function Set-PodeState {
    [CmdletBinding(DefaultParameterSetName = 'Builtin')]
    [OutputType([object])]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Builtin')]
        [object]
        $Value,

        [Parameter(Mandatory = $true, ParameterSetName = 'Builtin')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'Builtin')]
        [string[]]
        $Scope,

        [Parameter(Mandatory = $true, ParameterSetName = 'ThreadSafe')]
        [switch]
        $Threadsafe
    )

    # Check if Pode has been initialized; if not, throw an exception
    if ($null -eq $PodeContext.Server.State) {
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # Convert the state to a concurrent dictionary if thread-safe operations are requested
    if ($Threadsafe.IsPresent) {
        # If the state is already a concurrent dictionary, no conversion is needed
        if (Test-PodeStateIsThreadSafe) {
            return
        }
        # Convert the current state to a concurrent dictionary for thread safety
        $PodeContext.Server.State = ConvertTo-PodeConcurrentDictionary -Hashtable $PodeContext.Server.State
        return
    }

    # Set the scope to an empty array if none is provided
    if ($null -eq $Scope) {
        $Scope = @()
    }

    # Check if the state is a concurrent dictionary
    if (Test-PodeStateIsThreadSafe) {
        # Create a new concurrent dictionary item with case-insensitive keys
        $item = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new([StringComparer]::OrdinalIgnoreCase)

        # If the value is an ordered dictionary or hashtable, convert it to a concurrent dictionary
        if (($Value -is [System.Collections.Specialized.OrderedDictionary]) -or ($Value -is [hashtable])) {
            $Value = (ConvertTo-PodeConcurrentDictionary -Hashtable $Value)
        }

        # Add the value to the dictionary
        $item['Value'] = $Value

        # Add the scope to the item
        $item['Scope'] = $Scope

        # Try to add the new item to the shared state
        $PodeContext.Server.State[$Name] = $item
    }
    else {
        # If not using a concurrent dictionary, add the item as a regular hashtable
        $PodeContext.Server.State[$Name] = @{
            Value = $Value
            Scope = $Scope
        }
    }

    # Return the value that was set
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
function Get-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $WithScope
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
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
function Get-PodeStateNames {
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
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    if ($null -eq $Scope) {
        $Scope = @()
    }

    if (Test-PodeStateIsThreadSafe) {
        $tempState = $PodeContext.Server.State
        $keys = $tempState.Keys.clone()
    }
    else {
        $tempState = $PodeContext.Server.State.Clone()
        $keys = $tempState.Keys
    }

    if ($Scope.Length -gt 0) {
        $keys = @(foreach ($key in $keys) {
                if ($tempState[$key].Scope -iin $Scope) {
                    $key
                }
            })
    }

    if (![string]::IsNullOrWhiteSpace($Pattern)) {
        $keys = @(foreach ($key in $keys) {
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
function Remove-PodeState {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    if (Test-PodeStateIsThreadSafe) {
        $item = ''
        $null = $PodeContext.Server.State.tryRemove($Name, [ref]$item)
        return $item.value
    }

    $value = $PodeContext.Server.State[$Name].Value
    $null = $PodeContext.Server.State.Remove($Name)
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

.PARAMETER Depth
Saved JSON maximum depth. Will be passed to ConvertTo-JSON's -Depth parameter. Default is 10.

.PARAMETER Compress
If supplied, the saved JSON will be compressed.

.EXAMPLE
Save-PodeState -Path './state.json'

.EXAMPLE
Save-PodeState -Path './state.json' -Exclude Name1, Name2

.EXAMPLE
Save-PodeState -Path './state.json' -Scope Users
#>
function Save-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
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

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]
        $Depth = 10,

        [switch]
        $Compress
    )

    # error if attempting to use outside of the pode server
    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # get the full path to save the state
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    # contruct the state to save (excludes, etc)
    if (Test-PodeStateIsThreadSafe) {
        $state = Convert-PodeConcurrentDictionaryToHashtable -concurrentDictionary $PodeContext.Server.State
    }
    else {
        $state = $PodeContext.Server.State.Clone()
    }

    # scopes
    if (($null -ne $Scope) -and ($Scope.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            # remove if no scope
            if (($null -eq $state[$_key].Scope) -or ($state[$_key].Scope.Length -eq 0)) {
                $null = $state.Remove($_key)
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
            $null = $state.Remove($_key)
        }
    }

    # include keys
    if (($null -ne $Include) -and ($Include.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            if ($Include -inotcontains $_key) {
                $null = $state.Remove($_key)
            }
        }
    }

    # exclude keys
    if (($null -ne $Exclude) -and ($Exclude.Length -gt 0)) {
        foreach ($_key in $state.Clone().Keys) {
            if ($Exclude -icontains $_key) {
                $null = $state.Remove($_key)
            }
        }
    }

    # save the state
    $null = ConvertTo-Json -InputObject $state -Depth $Depth -Compress:$Compress | Out-File -FilePath $Path -Force
}

<#
.SYNOPSIS
Restores the shared state from some JSON file.

.DESCRIPTION
Restores the shared state from some JSON file.

.PARAMETER Path
The path to a JSON file that contains the state information.

.PARAMETER Merge
If supplied, the state loaded from the JSON file will be merged with the current state, instead of overwriting it.

.PARAMETER Depth
Saved JSON maximum depth. Will be passed to ConvertFrom-JSON's -Depth parameter (Powershell >=6). Default is 10.

.EXAMPLE
Restore-PodeState -Path './state.json'
#>
function Restore-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [switch]
        $Merge,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]
        $Depth = 10
    )

    # error if attempting to use outside of the pode server
    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # get the full path to the state
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    if (!(Test-Path $Path)) {
        return
    }

    # restore the state from file
    $state = @{}

    if (Test-PodeIsPSCore) {
        $state = (Get-Content $Path -Force | ConvertFrom-Json -AsHashtable -Depth $Depth)
    }
    else {
        $props = (Get-Content $Path -Force | ConvertFrom-Json).psobject.properties
        foreach ($prop in $props) {
            $state[$prop.Name] = $prop.Value
        }
    }

    # if the file is empty exit
    if ($state.Count -eq 0){
        return
    }

    # Clone the keys
    $keys = $state.Keys.clone()

    # check for no scopes, and add for backwards compat
    $convert = $false
    foreach ($_key in $keys) {
        if ($null -eq $state[$_key].Scope) {
            $convert = $true
            break
        }
    }

    if ($convert) {
        foreach ($_key in $keys) {
            $state[$_key] = @{
                Value = $state[$_key]
                Scope = @()
            }
        }
    }

    # set the scope to the main context
    if (! $Merge) {
        $PodeContext.Server.State.clear()
    }

    #clone the state
    if (Test-PodeStateIsThreadSafe) {
        $PodeContext.Server.State = ConvertTo-PodeConcurrentDictionary $state
    }
    else {
        foreach ($_key in $keys) {
            $PodeContext.Server.State[$_key] = $state[$_key]
        }
    }
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
function Test-PodeState {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    return $PodeContext.Server.State.ContainsKey($Name)
}
