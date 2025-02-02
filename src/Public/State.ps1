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
        $Scope
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
        #Wait-Debugger
        $PodeContext.Server.State[$Name] = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
        $PodeContext.Server.State[$Name].Value = $Value
        $PodeContext.Server.State[$Name].Scope = $Scope
        write-podehost $PodeContext.Server.State[$Name]  -Explode -ShowType
        return $Value
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
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
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    if ($null -eq $Scope) {
        $Scope = @()
    }

    # Directly retrieve the keys from the ConcurrentDictionary
    $keys = $PodeContext.Server.State.Keys

    if ($Scope.Length -gt 0) {
        $keys = @(foreach ($key in $keys) {
                if ($PodeContext.Server.State.ContainsKey($key) -and ($PodeContext.Server.State[$key].Scope -iin $Scope)) {
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
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if ($null -eq $PodeContext -or $null -eq $PodeContext.Server -or $null -eq $PodeContext.Server.State) {
        # Pode has not been initialized
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # ConcurrentDictionary requires TryRemove to remove and retrieve the value
    $removedValue = $null
    $removed = $PodeContext.Server.State.TryRemove($Name, [ref]$removedValue)

    if ($removed) {
        return $removedValue
    }

    # If not removed (key didn't exist), return $null
    return $null
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
        [int16]
        $Depth = 10,

        [switch]
        $Compress

    )

    # Error if attempting to use outside of a running Pode server
    if ($null -eq $PodeContext -or
        $null -eq $PodeContext.Server -or
        $null -eq $PodeContext.Server.State) {
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # Convert relative path to absolute
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    write-podehost "Path=$Path"
    # Create a shallow copy of the current ConcurrentDictionary
    $state = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
    foreach ($kvp in $PodeContext.Server.State.GetEnumerator()) {
        $null = $state.TryAdd($kvp.Key, $kvp.Value)
    }

    #------------------------------------------------------------------------------
    # Filter by Scope
    #------------------------------------------------------------------------------
    if (($null -ne $Scope) -and ($Scope.Length -gt 0)) {
        $keys = $state.Keys
        foreach ($key in $keys) {
            # Ensure the key still exists (another thread might have removed it)
            if ($state.ContainsKey($key)) {
                $value = $state[$key]

                # If there's no Scope property, or it has no entries, remove
                if (($null -eq $value.Scope) -or ($value.Scope.Count -eq 0)) {
                    $null = $state.TryRemove($key, [ref]$null)
                    continue
                }

                # Check for any matching scope
                $found = $false
                foreach ($item in $value.Scope) {
                    if ($Scope -icontains $item) {
                        $found = $true
                        break
                    }
                }

                # Remove if no scope matched
                if (!$found) {
                    $null = $state.TryRemove($key, [ref]$null)
                }
            }
        }
    }
    #------------------------------------------------------------------------------
    # Include Keys
    #------------------------------------------------------------------------------
    if (($null -ne $Include) -and ($Include.Length -gt 0)) {
        $keys = $state.Keys
        foreach ($key in $keys) {
            if ($Include -inotcontains $key) {
                $null = $state.TryRemove($key, [ref]$null)
            }
        }
    }

    #------------------------------------------------------------------------------
    # Exclude Keys
    #------------------------------------------------------------------------------
    if (($null -ne $Exclude) -and ($Exclude.Length -gt 0)) {
        $keys = $state.Keys
        foreach ($key in $keys) {
            if ($Exclude -icontains $key) {
                $null = $state.TryRemove($key, [ref]$null)
            }
        }
    }

    $null = ConvertTo-Json -InputObject $state -Depth $Depth -Compress:$Compress |
        Out-File -FilePath $Path -Force

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

        [switch]
        $Merge,

        [int16]
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
    $state = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()

    $null = ConvertTo-Json -InputObject $state -Depth $Depth -Compress:$Compress |
        Out-File -FilePath $Path -Force


    # restore the state from file

    if (Test-PodeIsPSCore) {
        $props = (Get-Content $Path -Force | ConvertFrom-Json -AsHashtable -Depth $Depth)
        foreach ($key in $props.Keys) {
            $state[$key] = $props[$key]
        }
    }
    else {
        $props = (Get-Content $Path -Force | ConvertFrom-Json).psobject.properties
        foreach ($prop in $props) {
            $state[$prop.Name] = $prop.Value
        }
    }

    write-podehost 'restore'
    # check for no scopes, and add for backwards compat
    $convert = $false
    foreach ($_key in $state.Keys) {
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
    if ($Merge) {
        foreach ($_key in $state.Clone().Keys) {
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
    Deserializes JSON from ConvertTo-PodeCustomDictionaryJson back into the original dictionary type.

.DESCRIPTION
    Reads the JSON, checks the "Type" property, and constructs either a Hashtable or
    ConcurrentDictionary. Then populates it with all the Items (key-value pairs).

.PARAMETER Json
    A JSON string or file content containing "Type" and "Items".

.OUTPUTS
    [Hashtable] or [System.Collections.Concurrent.ConcurrentDictionary[string, object]]
#>
function ConvertFrom-PodeCustomDictionaryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    # Parse JSON
    $wrapper = $Json | ConvertFrom-Json

    # Check "Type" property
    switch ($wrapper.Type) {
        'Hashtable' {
            $dict = @{}
        }
        'ConcurrentDictionary' {
            $dict = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
        }
        Default {
            throw "Unknown dictionary type in JSON: $($wrapper.Type)"
        }
    }

    # Re-populate
    foreach ($item in $wrapper.Items) {
        $key = $item.Key
        $value = $item.Value

        if ($dict -is [System.Collections.Concurrent.ConcurrentDictionary[string, object]]) {
            $null = $dict.TryAdd($key, $value)
        }
        else {
            $dict[$key] = $value
        }
    }

    return $dict
}

<#
.SYNOPSIS
    Serializes either a Hashtable or ConcurrentDictionary to JSON, preserving which type it was.

.DESCRIPTION
    This function checks the .NET type of the supplied object. If it's a [Hashtable] or
    [System.Collections.Concurrent.ConcurrentDictionary], it serializes the data (keys + values)
    and a "Type" property that indicates which dictionary you had. Otherwise, it throws.

.PARAMETER Dictionary
    The hashtable or concurrent dictionary to serialize.

.OUTPUTS
    [string] (JSON)
#>
function ConvertTo-PodeCustomDictionaryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Dictionary
    )

    # Identify the dictionary type
    $dictType = $Dictionary.GetType().FullName
    switch ($dictType) {
        'System.Collections.Hashtable' {
            $typeIndicator = 'Hashtable'
        }
        'System.Collections.Concurrent.ConcurrentDictionary`2[[System.String],[System.Object]]' {
            $typeIndicator = 'ConcurrentDictionary'
        }
        Default {
            throw "Unsupported dictionary type: $dictType"
        }
    }

    # Build an array of {Key, Value} objects
    $items = @()
    foreach ($key in $Dictionary.Keys) {
        $items += [PSCustomObject]@{
            Key   = $key
            Value = $Dictionary[$key]
        }
    }

    # Build a wrapper object with Type + Items
    $wrapper = [PSCustomObject]@{
        'Type'  = $typeIndicator
        'Items' = $items
    }

    # Convert to JSON
    return $wrapper | ConvertTo-Json -Depth 50
}
