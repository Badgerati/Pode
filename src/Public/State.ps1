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

.PARAMETER NoPassThru
If supplied, the value that was set will not be returned.

.EXAMPLE
$value = Set-PodeState -Name 'Data' -Value @{ 'Name' = 'Rick Sanchez' }

.EXAMPLE
$value = Set-PodeState -Name 'Users' -Value @('user1', 'user2') -Scope General, Users

.EXAMPLE
Set-PodeState -Name 'Data' -Value @{ 'Name' = 'Rick Sanchez' } -NoPassThru
#>
function Set-PodeState {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [object]
        $Value,

        [Parameter()]
        [string[]]
        $Scope,

        [switch]
        $NoPassThru
    )

    begin {
        if ($null -eq $PodeContext.Server.State) {
            # Pode has not been initialized
            throw ($PodeLocale.podeNotInitializedExceptionMessage)
        }

        if ($null -eq $Scope) {
            $Scope = @()
        }

        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # Set Value to the array of values
        if ($pipelineValue.Count -gt 1) {
            $Value = $pipelineValue
        }

        # create state object
        $PodeContext.Server.State[$Name] = New-PodeStateDictionary -Data @{
            Value = $Value
            Scope = $Scope
        }

        # return the value that was set
        if (!$NoPassThru) {
            return $Value
        }
    }
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
$value = Get-PodeState -Name 'Data'
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

    return $PodeContext.Server.State[$Name].Value
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

.PARAMETER Exclude
An optional array of state names to exclude from the result.

.PARAMETER Include
An optional array of state names to include in the result.

.EXAMPLE
$names = Get-PodeStateNames -Scope '<scope>'

.EXAMPLE
$names = Get-PodeStateNames -Pattern '^\w+[0-9]{0,2}$'

.EXAMPLE
$names = Get-PodeStateNames -Include 'Name1', 'Name2' -Exclude 'Name3'
#>
function Get-PodeStateNames {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Pattern,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $Exclude,

        [Parameter()]
        [string[]]
        $Include
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    if ($null -eq $Scope) {
        $Scope = @()
    }

    # get the keys from the state
    $keys = $PodeContext.Server.State.Keys

    # filter by scope if supplied
    if ($Scope.Length -gt 0) {
        $keys = @(foreach ($key in $keys) {
                $value = $null
                if ($PodeContext.Server.State.TryGetValue($key, [ref]$value)) {
                    foreach ($_scope in $value.Scope) {
                        if ($Scope -icontains $_scope) {
                            $key
                            break
                        }
                    }
                }
            })
    }

    # filter by include if supplied
    if ($Include.Length -gt 0) {
        $keys = @(foreach ($key in $keys) {
                if ($Include -inotcontains $key) {
                    continue
                }

                $key
            })
    }

    # filter by exclude if supplied
    if ($Exclude.Length -gt 0) {
        $keys = @(foreach ($key in $keys) {
                if ($Exclude -icontains $key) {
                    continue
                }

                $key
            })
    }

    # filter by pattern if supplied
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

.PARAMETER NoPassThru
If supplied, the removed state object will not be returned.

.EXAMPLE
$value = Remove-PodeState -Name 'Data'

.EXAMPLE
Remove-PodeState -Name 'Data' -NoPassThru
#>
function Remove-PodeState {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $NoPassThru
    )

    if ($null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    $item = $null
    if (!$PodeContext.Server.State.TryRemove($Name, [ref]$item)) {
        return $null
    }

    if (!$NoPassThru) {
        return $item.Value
    }
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
Saved JSON maximum depth. Will be passed to ConvertTo-JSON's -Depth parameter. Default is 20.

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
        [int16]
        $Depth = 20,

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

    # which keys in the state do we need to save?
    $keys = Get-PodeStateNames -Scope $Scope -Exclude $Exclude -Include $Include

    # create a clone of the state, using only the keys we want to save
    $state = New-PodeStateDictionary
    foreach ($key in $keys) {
        $value = $null
        if ($PodeContext.Server.State.TryGetValue($key, [ref]$value)) {
            $state[$key] = $value
        }
    }

    # save the state
    $result = @{
        '__pode_state_metadata__' = @{
            Version   = 2
            Timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        }
        '__pode_state_data__'     = ConvertTo-PodeStateData -InputObject $state
    }

    $null = $result |
        ConvertTo-Json -Depth $Depth -Compress:$Compress |
        Out-File -FilePath $Path -Force

    $state = $null
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
Saved JSON maximum depth. Will be passed to ConvertFrom-JSON's -Depth parameter (Powershell >=6). Default is 20.

.EXAMPLE
Restore-PodeState -Path './state.json'
#>
function Restore-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [switch]
        $Merge,

        [int16]
        $Depth = 20
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

    # load the json state from file
    $params = @{}
    if (Test-PodeIsPSCore) {
        $params['AsHashtable'] = $true
        $params['Depth'] = $Depth
    }

    $content = Get-Content -Path $Path -Force | ConvertFrom-Json @params
    if ([string]::IsNullOrEmpty($content)) {
        return
    }

    # convert into a concurrent dictionary based on the version of the state file
    $state = ConvertFrom-PodeStateJson -InputObject $content

    # check for no scopes, and add for backwards compat
    foreach ($_key in $state.Keys) {
        if ($null -eq $state[$_key].Scope) {
            $state[$_key] = @{
                Value = $state[$_key]
                Scope = @()
            }
        }
    }

    # set the scope to the main context
    if ($Merge) {
        foreach ($_key in $state.Keys) {
            $PodeContext.Server.State[$_key] = $state[$_key]
        }
    }
    else {
        $PodeContext.Server.State = $state
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

<#
.SYNOPSIS
Creates a new concurrent dictionary for use in the shared state.

.DESCRIPTION
Creates a new concurrent dictionary for use in the shared state. This is useful for storing key-value pairs in a thread-safe manner.

.PARAMETER Data
An optional hashtable of initial key-value pairs to populate the dictionary.

.EXAMPLE
Set-PodeState -Name 'MyDictionary' -Value (New-PodeStateDictionary)

.EXAMPLE
Set-PodeState -Name 'MyDictionary' -Value (New-PodeStateDictionary -Data @{ 'Key1' = 'Value1'; 'Key2' = 'Value2' })
#>
function New-PodeStateDictionary {
    [CmdletBinding()]
    [OutputType([System.Collections.Concurrent.ConcurrentDictionary[string, object]])]
    param(
        [Parameter()]
        [hashtable]
        $Data
    )

    $dict = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([StringComparer]::InvariantCultureIgnoreCase)
    if (($null -eq $Data) -or ($Data.Count -eq 0)) {
        return $dict
    }

    foreach ($key in $Data.Keys) {
        $dict[$key] = $Data[$key]
    }

    return $dict
}

<#
.SYNOPSIS
Creates a new concurrent ordered dictionary for use in the shared state.

.DESCRIPTION
Creates a new concurrent ordered dictionary for use in the shared state. This is useful for storing key-value pairs in a thread-safe manner while maintaining the order of insertion.

.PARAMETER Data
An optional hashtable of initial key-value pairs to populate the ordered dictionary.

.EXAMPLE
Set-PodeState -Name 'MyOrderedDictionary' -Value (New-PodeStateOrderedDictionary)

.EXAMPLE
Set-PodeState -Name 'MyOrderedDictionary' -Value (New-PodeStateOrderedDictionary -Data @{ 'Key1' = 'Value1'; 'Key2' = 'Value2' })

.NOTES
This uses a custom concurrent ordered dictionary implementation to ensure thread safety and maintain order of insertion.
The PodeConcurrentOrderedDictionary class is defined in the Pode.Utilities.Structures namespace.
#>
function New-PodeStateOrderedDictionary {
    [CmdletBinding()]
    [OutputType([Pode.Utilities.Structures.PodeConcurrentOrderedDictionary[string, object]])]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [hashtable]
        $Data
    )

    $dict = [Pode.Utilities.Structures.PodeConcurrentOrderedDictionary[string, object]]::new()
    if (($null -eq $Data) -or ($Data.Count -eq 0)) {
        return , $dict
    }

    foreach ($key in $Data.Keys) {
        $dict[$key] = $Data[$key]
    }

    return , $dict
}

<#
.SYNOPSIS
Creates a new concurrent bag for use in the shared state.

.DESCRIPTION
Creates a new concurrent bag for use in the shared state. This is useful for storing a collection of objects in a thread-safe manner.

.PARAMETER Data
An optional array of initial objects to populate the bag.

.EXAMPLE
Set-PodeState -Name 'MyBag' -Value (New-PodeStateBag)

.EXAMPLE
Set-PodeState -Name 'MyBag' -Value (New-PodeStateBag -Data @(1, 2, 3))
#>
function New-PodeStateBag {
    [CmdletBinding()]
    [OutputType([System.Collections.Concurrent.ConcurrentBag[object]])]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [object[]]
        $Data
    )

    $bag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    if (($null -eq $Data) -or ($Data.Count -eq 0)) {
        return , $bag
    }

    foreach ($item in $Data) {
        $null = $bag.Add($item)
    }

    return , $bag
}

<#
.SYNOPSIS
Creates a new concurrent hash set for use in the shared state.

.DESCRIPTION
Creates a new concurrent hash set for use in the shared state. This is useful for storing a collection of unique objects in a thread-safe manner.

.PARAMETER Data
An optional array of initial objects to populate the hash set.

.EXAMPLE
Set-PodeState -Name 'MySet' -Value (New-PodeStateSet)

.EXAMPLE
Set-PodeState -Name 'MySet' -Value (New-PodeStateSet -Data @('Item1', 'Item2', 'Item3'))

.NOTES
This uses a custom concurrent set implementation to ensure thread safety and uniqueness of items.
The PodeConcurrentSet class is defined in the Pode.Utilities.Structures namespace.
#>
function New-PodeStateSet {
    [CmdletBinding()]
    [OutputType([Pode.Utilities.Structures.PodeConcurrentSet[object]])]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [object[]]
        $Data
    )

    $set = [Pode.Utilities.Structures.PodeConcurrentSet[object]]::new()
    if (($null -eq $Data) -or ($Data.Count -eq 0)) {
        return , $set
    }

    foreach ($item in $Data) {
        $null = $set.TryAdd($item)
    }

    return , $set
}

<#
.SYNOPSIS
Creates a new concurrent list for use in the shared state.

.DESCRIPTION
Creates a new concurrent list for use in the shared state. This is useful for storing a collection of objects in a thread-safe manner while maintaining the order of insertion.

.PARAMETER Data
An optional array of initial objects to populate the list.

.EXAMPLE
Set-PodeState -Name 'MyList' -Value (New-PodeStateList)

.EXAMPLE
Set-PodeState -Name 'MyList' -Value (New-PodeStateList -Data @('Item1', 'Item2'))

.NOTES
This uses a custom concurrent list implementation to ensure thread safety and maintain order of insertion.
The PodeConcurrentList class is defined in the Pode.Utilities.Structures namespace.
#>
function New-PodeStateList {
    [CmdletBinding()]
    [OutputType([Pode.Utilities.Structures.PodeConcurrentList[object]])]
    [OutputType([System.Object[]])]
    param(
        [Parameter()]
        [object[]]
        $Data
    )

    $list = [Pode.Utilities.Structures.PodeConcurrentList[object]]::new()
    if (($null -eq $Data) -or ($Data.Count -eq 0)) {
        return , $list
    }

    foreach ($item in $Data) {
        $null = $list.Add($item)
    }

    return , $list
}