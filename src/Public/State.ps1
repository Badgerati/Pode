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
        return $removedValue.Value
    }

    # If not removed (key didn't exist), return $null
    return $null
}

<#
.SYNOPSIS
Saves the current shared state to a supplied JSON file.

.DESCRIPTION
Saves the current shared state to a supplied JSON file. When using this function,
it's recommended to wrap it in a Lock-PodeObject block.

.PARAMETER Path
The path to a JSON file which the current state will be saved to.

.PARAMETER Scope
An optional array of scopes for state objects that should be saved. (Lower precedence than Exclude/Include.)

.PARAMETER Exclude
An optional array of state object names to exclude from being saved. (Higher precedence than Include.)

.PARAMETER Include
An optional array of state object names to only include when being saved.

.PARAMETER Depth
Saved JSON maximum depth. Will be passed to ConvertTo-PodeCustomDictionaryJson's -Depth parameter. Default is 10.

.PARAMETER Compress
If supplied, the saved JSON will be compressed (no extra whitespace).

.EXAMPLE
Save-PodeState -Path './state.json'

.EXAMPLE
Save-PodeState -Path './state.json' -Exclude Name1, Name2

.EXAMPLE
Save-PodeState -Path './state.json' -Scope Users

.OUTPUTS
[System.Void]

.NOTES
This function is for internal Pode usage and may be subject to change.
For more details, refer to the Pode repository: https://github.com/Badgerati/Pode/tree/develop
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

    #------------------------------------------------------------------------------
    # Convert to JSON (Preserve Dictionary Type) and Save
    #------------------------------------------------------------------------------
    $json = ConvertTo-PodeCustomDictionaryJson -Dictionary $state -Depth $Depth -Compress:$Compress
    $json | Out-File -FilePath $Path -Force
}

<#
.SYNOPSIS
Restores the shared state from some JSON file.

.DESCRIPTION
Restores the shared state from some JSON file. If the file doesn't exist,
the function simply returns.

.PARAMETER Path
The path to a JSON file that contains the state information.

.PARAMETER Merge
If supplied, the state loaded from the JSON file will be merged with the current
state, instead of overwriting it.

.PARAMETER Depth
Maximum JSON depth used by ConvertFrom-PodeCustomDictionaryJson (if needed).
Default is 10.

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

    # Error if attempting to use outside of the pode server
    if ($null -eq $PodeContext -or
        $null -eq $PodeContext.Server -or
        $null -eq $PodeContext.Server.State) {
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # Get the full path to the state file
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    if (!(Test-Path $Path)) {
        # If file doesn't exist, just return
        return
    }

    # Read the JSON content as a single string
    $json = Get-Content -Path $Path -Raw -Force
    if (![string]::IsNullOrWhiteSpace($json)) {
        # Recreate the dictionary (or dictionaries) from JSON
        $restored = ConvertFrom-PodeCustomDictionaryJson -Json $json

        # We want $state to end up as a [ConcurrentDictionary[string,object]]
        # If $restored is already a concurrent dict, use it directly.
        # Otherwise, copy keys/values into a new concurrent dictionary.
        if ($restored -is [System.Collections.Concurrent.ConcurrentDictionary[string, object]]) {
            $state = $restored
        }
        else {
            # If $restored is a Hashtable/OrderedDictionary or something else,
            # we'll populate a new concurrent dictionary from it.
            $state = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
            if ($restored -is [System.Collections.IDictionary]) {
                foreach ($key in $restored.Keys) {
                    $null = $state.TryAdd($key, $restored[$key])
                }
            }
            else {
                # 'The PodeState file "{0}" contains an invalid format. Expected a dictionary-like structure (ConcurrentDictionary, Hashtable, or OrderedDictionary), but found [{1}]. Please verify the file content or reinitialize the state.'
                throw ($PodeLocale.invalidPodeStateFormatExceptionMessage -f $Path, $restored.GetType().FullName)

            }
        }
    }
    else {
        # The file exists but is empty
        return
    }

    #---------------------------------------------------------------------
    # Check for no scopes, and add them for backwards compatibility
    #---------------------------------------------------------------------
    $convert = $false
    foreach ($_key in $state.Keys) {
        if ($null -eq $state[$_key].Scope) {
            $convert = $true
            break
        }
    }

    if ($convert) {
        foreach ($_key in $state.Keys) {
            # Build a new object with Value/Scope if needed
            $old = $state[$_key]
            $state[$_key] = @{
                Value = $old
                Scope = @()
            }
        }
    }

    #---------------------------------------------------------------------
    # Merge or Overwrite
    #---------------------------------------------------------------------
    if ($Merge) {
        # Merge the loaded state with the current server state
        foreach ($_key in $state.Keys) {
            $PodeContext.Server.State[$_key] = $state[$_key]
        }
    }
    else {
        # Overwrite the entire state
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
Deserializes JSON from ConvertTo-PodeCustomDictionaryJson (nested) back into
the original dictionary/collection type (Hashtable, ConcurrentDictionary, OrderedDictionary,
ConcurrentBag, ConcurrentQueue, ConcurrentStack).

.DESCRIPTION
Recursively reads the JSON, checks the "Type" property, and reconstructs
the corresponding dictionary/collection. Also handles arrays and primitive types so they
round-trip correctly.

.PARAMETER Json
A JSON string containing "Type" and "Items" at each dictionary/collection level.

.OUTPUTS
- [Hashtable]
- [System.Collections.Concurrent.ConcurrentDictionary[string, object]]
- [System.Collections.Specialized.OrderedDictionary]
- [System.Collections.Concurrent.ConcurrentBag[object]]
- [System.Collections.Concurrent.ConcurrentQueue[object]]
- [System.Collections.Concurrent.ConcurrentStack[object]]
- Arrays, primitives, or PSCustomObjects for non-dictionary structures.

.NOTES
This function is for internal Pode usage and may be subject to change.
For more details, refer to the Pode repository:
https://github.com/Badgerati/Pode/tree/develop
#>
function ConvertFrom-PodeCustomDictionaryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    # Parse the top-level JSON into a PSObject/Array
    $parsed = $Json | ConvertFrom-Json

    # A nested helper function that reconstructs objects from the "Type" + "Items" structure
    function ConvertFromPodeDictionaryObject {
        param(
            [Parameter()]
            [object]$obj
        )

        # 1) null => return null
        if ($null -eq $obj) {
            return $null
        }

        # 2) If it's an array, recursively handle each element
        if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
            $resultList = @()
            foreach ($item in $obj) {
                $resultList += ConvertFromPodeDictionaryObject $item
            }
            return $resultList
        }

        # 3) If it's a PSCustomObject, check if there's a "Type" property
        if ($obj -is [PSCustomObject]) {
            if ($obj.PSObject.Properties.Name -contains 'Type') {
                # This object might be a dictionary/collection wrapper
                switch ($obj.Type) {
                    'Hashtable' {
                        $dict = @{}
                        foreach ($pair in $obj.Items) {
                            $key = $pair.Key
                            $value = ConvertFromPodeDictionaryObject $pair.Value
                            $dict[$key] = $value
                        }
                        return $dict
                    }
                    'ConcurrentDictionary' {
                        $dict = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
                        foreach ($pair in $obj.Items) {
                            $key = $pair.Key
                            $value = ConvertFromPodeDictionaryObject $pair.Value
                            $dict.TryAdd($key, $value) | Out-Null
                        }
                        return $dict
                    }
                    'OrderedDictionary' {
                        $dict = [System.Collections.Specialized.OrderedDictionary]::new()
                        foreach ($pair in $obj.Items) {
                            $key = $pair.Key
                            $value = ConvertFromPodeDictionaryObject $pair.Value
                            $dict[$key] = $value
                        }
                        return $dict
                    }
                    'ConcurrentBag' {
                        # Rebuild a ConcurrentBag[object]
                        $bag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
                        foreach ($item in $obj.Items) {
                            $convertedItem = ConvertFromPodeDictionaryObject $item
                            $bag.Add($convertedItem)
                        }
                        return , $bag # <----  Prepend with a comma to return it as an object, not Object[]
                    }
                    'ConcurrentQueue' {
                        # Rebuild a ConcurrentQueue[object]
                        $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
                        foreach ($item in $obj.Items) {
                            $convertedItem = ConvertFromPodeDictionaryObject $item
                            $queue.Enqueue($convertedItem)
                        }
                        return $queue
                    }
                    'ConcurrentStack' {
                        # Rebuild a ConcurrentStack[object]
                        $stack = [System.Collections.Concurrent.ConcurrentStack[object]]::new()
                        foreach ($item in $obj.Items) {
                            $convertedItem = ConvertFromPodeDictionaryObject $item
                            $stack.Push($convertedItem)
                        }
                        return $stack
                    }
                    default {
                        throw "Unknown dictionary/collection type in JSON: $($obj.Type)"
                    }
                }
            }
            else {
                # It's a plain PSCustomObject, so reconstruct each property
                $ht = @{}
                $props = $obj | Get-Member -MemberType NoteProperty, AliasProperty, ScriptProperty
                foreach ($prop in $props) {
                    $ht[$prop.Name] = ConvertFromPodeDictionaryObject($obj.$($prop.Name))
                }
                return $ht
            }
        }

        # 4) If it's not an array or PSCustomObject, it's presumably a primitive => return as-is
        return $obj
    }

    # Rebuild the full structure from the parsed JSON
    return ConvertFromPodeDictionaryObject -obj $parsed
}


<#
.SYNOPSIS
Serializes specialized PowerShell/Concurrent collections to JSON, preserving type info.

.DESCRIPTION
This function checks the .NET type of the supplied object. If it's a [Hashtable],
[OrderedDictionary], [ConcurrentDictionary], [ConcurrentBag], [ConcurrentQueue], or [ConcurrentStack],
it serializes the data in a structured format with a "Type" property. Arrays and custom objects
are similarly processed recursively.

.PARAMETER Dictionary
The object/collection to serialize.

.PARAMETER Depth
Specifies how many levels of contained objects should be included in the JSON. Default is 10.

.PARAMETER Compress
If supplied, the output JSON will be condensed (no extra whitespace).

.OUTPUTS
[string] (JSON)

.NOTES
This function is for internal Pode usage and may be subject to change.
Refer to the Pode repository: https://github.com/Badgerati/Pode/tree/develop
#>
function ConvertTo-PodeCustomDictionaryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Dictionary,

        [Parameter()]
        [int16]
        $Depth = 10,

        [switch]
        $Compress
    )

    # Nested helper to recursively deconstruct objects
    function deconstructs {
        param([Parameter()] $Object)

        if ($null -eq $Object) {
            return $null  # Return null without modification
        }

        #---------------------------------------------------------
        # 1) Return common primitives directly
        #---------------------------------------------------------
        if ($Object -is [string] -or
            $Object -is [int] -or
            $Object -is [bool] -or
            $Object -is [double] -or
            $Object -is [float] -or
            $Object -is [datetime]) {
            return $Object
        }

        #---------------------------------------------------------
        # 2) Handle OrderedDictionary
        #---------------------------------------------------------
        if ($Object -is [System.Collections.Specialized.OrderedDictionary]) {
            $wrapper = [PSCustomObject]@{ Type = 'OrderedDictionary'; Items = @() }
            foreach ($key in $Object.Keys) {
                $wrapper.Items += [PSCustomObject]@{
                    Key   = $key
                    Value = deconstructs($Object[$key])
                }
            }
            return $wrapper
        }

        #---------------------------------------------------------
        # 3) Handle Hashtable
        #---------------------------------------------------------
        if ($Object -is [System.Collections.Hashtable]) {
            $wrapper = [PSCustomObject]@{ Type = 'Hashtable'; Items = @() }
            foreach ($key in $Object.Keys) {
                $wrapper.Items += [PSCustomObject]@{
                    Key   = $key
                    Value = deconstructs($Object[$key])
                }
            }
            return $wrapper
        }

        #---------------------------------------------------------
        # 4) Handle ConcurrentDictionary
        #---------------------------------------------------------
        if ($Object -is [System.Collections.Concurrent.ConcurrentDictionary[string, object]]) {
            $wrapper = [PSCustomObject]@{ Type = 'ConcurrentDictionary'; Items = @() }
            foreach ($key in $Object.Keys) {
                $wrapper.Items += [PSCustomObject]@{
                    Key   = $key
                    Value = deconstructs($Object[$key])
                }
            }
            return $wrapper
        }

        #---------------------------------------------------------
        # 5) Handle ConcurrentBag[object]
        #---------------------------------------------------------
        if ($Object -is [System.Collections.Concurrent.ConcurrentBag[object]]) {
            $wrapper = [PSCustomObject]@{ Type = 'ConcurrentBag'; Items = @() }
            foreach ($item in $Object) {
                $wrapper.Items += deconstructs($item)
            }
            return $wrapper
        }

        #---------------------------------------------------------
        # 6) Handle ConcurrentQueue[object]
        #---------------------------------------------------------
        if ($Object -is [System.Collections.Concurrent.ConcurrentQueue[object]]) {
            $wrapper = [PSCustomObject]@{ Type = 'ConcurrentQueue'; Items = @() }
            foreach ($item in $Object) {
                $wrapper.Items += deconstructs($item)
            }
            return $wrapper
        }

        #---------------------------------------------------------
        # 7) Handle ConcurrentStack[object]
        #---------------------------------------------------------
        if ($Object -is [System.Collections.Concurrent.ConcurrentStack[object]]) {
            $wrapper = [PSCustomObject]@{ Type = 'ConcurrentStack'; Items = @() }
            foreach ($item in $Object) {
                $wrapper.Items += deconstructs($item)
            }
            return $wrapper
        }

        #---------------------------------------------------------
        # 8) If it's a list/array, process each item but return as array
        #---------------------------------------------------------
        if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
            $convertedArray = @()
            foreach ($item in $Object) {
                $convertedArray += deconstructs($item)
            }
            return $convertedArray
        }

        #---------------------------------------------------------
        # 9) If it's a PSCustomObject, process each property individually
        #---------------------------------------------------------
        if ($Object -is [PSCustomObject]) {
            $newObj = @{}
            $properties = $Object | Get-Member -MemberType NoteProperty, AliasProperty, ScriptProperty
            foreach ($prop in $properties) {
                $newObj[$prop.Name] = deconstructs($Object.$($prop.Name))
            }
            return $newObj
        }

        #---------------------------------------------------------
        # 10) Fallback: Return object as-is (any other primitive or type)
        #---------------------------------------------------------
        return $Object
    }

    # If top-level is null, treat as an empty dictionary
    if ($null -eq $Dictionary) {
        $converted = @{ }
    }
    else {
        # Recursively convert any nested structures
        $converted = deconstructs -Object $Dictionary
    }

    # Finally convert to JSON
    return $converted | ConvertTo-Json -Depth $Depth -Compress:$Compress
}
