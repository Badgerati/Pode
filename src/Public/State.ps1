<#
.SYNOPSIS
    Sets an object within the shared state.

.DESCRIPTION
    Sets an object within the shared state, allowing for the creation of different collection types, such as a Hashtable, ConcurrentDictionary, or other concurrent collections.

.PARAMETER Name
    The name of the state object.

.PARAMETER Value
    The value to set in the state. If a collection type is specified using `-NewCollectionType`, this value is ignored.

.PARAMETER Scope
    An optional scope for the state object, used when saving the state.

.PARAMETER NewCollectionType
    Specifies the type of collection to create. Supported options include:
    - Hashtable
    - ConcurrentDictionary
    - OrderedDictionary
    - ConcurrentBag
    - ConcurrentQueue
    - ConcurrentStack

    If this parameter is used, the state object will be initialized as the specified collection type.

.EXAMPLE
    Set-PodeState -Name 'Data' -Value @{ 'Name' = 'Rick Sanchez' }

.EXAMPLE
    Set-PodeState -Name 'Users' -Value @('user1', 'user2') -Scope General, Users

.EXAMPLE
    Set-PodeState -Name 'Cache' -NewCollectionType 'ConcurrentDictionary'

.EXAMPLE
    Set-PodeState -Name 'Tasks' -NewCollectionType 'ConcurrentQueue'

.NOTES
    - `NewCollectionType` and `Value` are mutually exclusive; only one can be used at a time.
    - The function ensures thread safety when using concurrent collections.
    - Pode must be initialized before calling this function.
#>
function Set-PodeState {
    [CmdletBinding(DefaultParameterSetName = 'Value')]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(ValueFromPipeline = $true, Position = 0, ParameterSetName = 'Value')]
        [object]
        $Value,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter(Mandatory = $true, ParameterSetName = 'Collection')]
        [ValidateSet('Hashtable', 'ConcurrentDictionary', 'OrderedDictionary', 'ConcurrentBag', 'ConcurrentQueue', 'ConcurrentStack')]
        [string]
        $NewCollectionType
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
        # Collect piped-in values
        $pipelineValue += $_
    }

    end {
        # If multiple values were piped in, store them as an array
        if ($pipelineValue.Count -gt 1) {
            $Value = $pipelineValue
        }

        # Initialize the state as a case-insensitive ConcurrentDictionary
        $PodeContext.Server.State[$Name] = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)

        # Create the specified collection type, or use the provided value
        $PodeContext.Server.State[$Name].Value = switch ($NewCollectionType) {
            'Hashtable' { @{} }
            'ConcurrentDictionary' { [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase) }
            'OrderedDictionary' { [ordered]@{} }
            'ConcurrentBag' { [System.Collections.Concurrent.ConcurrentBag[object]]::new() }
            'ConcurrentQueue' { [System.Collections.Concurrent.ConcurrentQueue[object]]::new() }
            'ConcurrentStack' { [System.Collections.Concurrent.ConcurrentStack[object]]::new() }
            default { $Value }  # If no collection type is specified, use the provided value
        }

        # Store the scope for the state object
        $PodeContext.Server.State[$Name].Scope = $Scope

        return $PodeContext.Server.State[$Name].Value
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
                if ($PodeContext.Server.State.ContainsKey($key)) {
                    $scopeValue = $PodeContext.Server.State[$key]['Scope']
                    if ($scopeValue -is [string] -and ($scopeValue -iin $Scope)) {
                        $key
                    }
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
    Saves the current Pode server state to a JSON file.

.DESCRIPTION
    This function serializes the Pode state into a JSON file while preserving the structure
    of dictionaries (`ConcurrentDictionary`, `Hashtable`, `OrderedDictionary`). It allows
    filtering the saved state by scope, inclusion, or exclusion of specific keys.

    For thread safety, it is recommended to wrap this function inside a `Lock-PodeObject` block.

.PARAMETER Path
    Specifies the file path where the state should be saved.

.PARAMETER Scope
    Filters the state objects to be saved based on their scope.
    Only state objects within the specified scope(s) will be included.
    This filter has **lower precedence** than Exclude and Include.

.PARAMETER Exclude
    Specifies state object names to **exclude** from being saved.
    This filter has **higher precedence** than Include.

.PARAMETER Include
    Specifies state object names to **only** include in the saved state.
    This filter has **lower precedence** than Exclude.

.PARAMETER Depth
    Defines the maximum depth for JSON serialization.
    This value is passed to `ConvertTo-PodeCustomDictionaryJson`. Default is **20**.

.PARAMETER Compress
    If specified, the JSON output will be minified (no extra whitespace).

.EXAMPLE
    Save-PodeState -Path './state.json'
    Saves the entire Pode state to `state.json`.

.EXAMPLE
    Save-PodeState -Path './state.json' -Exclude 'SessionData', 'UserCache'
    Saves the Pode state but **excludes** the specified state keys.

.EXAMPLE
    Save-PodeState -Path './state.json' -Scope 'Users'
    Saves **only** state objects that belong to the `"Users"` scope.

.OUTPUTS
    [System.Void] - This function does not return an output. The state is saved to a file.
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
    # Validate Pode Server Context

    if ($null -eq $PodeContext -or
        $null -eq $PodeContext.Server -or
        $null -eq $PodeContext.Server.State) {
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # Convert relative path to absolute
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    $params = @{
        Scope    = $Scope
        Exclude  = $Exclude
        Include  = $Include
        Depth    = $Depth
        Compress = $Compress
    }
    $json = ConvertFrom-PodeState  @params

    # Save the JSON to the specified file path
    $json | Out-File -FilePath $Path -Force
}

<#
.SYNOPSIS
	Serializes the current Pode server state into a JSON string.

.DESCRIPTION
	This function extracts and serializes the in-memory Pode state into a JSON-formatted string. It supports filtering by state scopes,
	as well as selective inclusion or exclusion of state keys. The output can be formatted for readability or compressed for minimal size.
	Dictionaries such as `ConcurrentDictionary`, `Hashtable`, and `OrderedDictionary` are preserved during serialization.

.PARAMETER Scope
	Filters the state entries based on their defined scope values.
	Only state entries that match one or more of the specified scopes will be retained.
	This filter has lower precedence than Exclude and Include.

.PARAMETER Exclude
	A list of state keys to be excluded from the serialized output.
	This filter takes precedence over both Scope and Include.

.PARAMETER Include
	A list of specific state keys to include in the output.
	This filter has higher precedence than Scope, but lower than Exclude.

.PARAMETER Depth
	Specifies the maximum object depth used during JSON serialization.
	Passed directly to `ConvertTo-PodeCustomDictionaryJson`. Default is 20.

.PARAMETER Compress
	If set, the resulting JSON string will be minified (compact format without extra whitespace).

.OUTPUTS
	System.String

.EXAMPLE
	$state = ConvertFrom-PodeState
	# Returns a JSON string representing the full current Pode state.

.EXAMPLE
	$state = ConvertFrom-PodeState -Exclude 'SessionData', 'Cache'
	# Returns the state excluding the specified keys.

.EXAMPLE
	$state = ConvertFrom-PodeState -Scope 'Users'
	# Returns only state entries that belong to the "Users" scope.
#>
function ConvertFrom-PodeState {
    [CmdletBinding()]
    param(
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

    # Validate Pode Server Context

    if ($null -eq $PodeContext -or
        $null -eq $PodeContext.Server -or
        $null -eq $PodeContext.Server.State) {
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # Create a Shallow Copy of the Current State

    # A new ConcurrentDictionary is created to store a snapshot of the current state,
    # preventing modifications while the state is being serialized.
    $state = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($kvp in $PodeContext.Server.State.GetEnumerator()) {
        $null = $state.TryAdd($kvp.Key, $kvp.Value)
    }

    # Filter State by Scope
    if (($null -ne $Scope) -and ($Scope.Length -gt 0)) {
        $keys = $state.Keys
        foreach ($key in $keys) {
            if ($state.ContainsKey($key)) {
                $value = $state[$key]

                # Remove state objects that lack a scope
                if (($null -eq $value.Scope) -or ($value.Scope.Count -eq 0)) {
                    $null = $state.TryRemove($key, [ref]$null)
                    continue
                }

                # Remove objects that do not match the specified scope(s)
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


    # If Include is defined, only keep the specified keys
    if (($null -ne $Include) -and ($Include.Length -gt 0)) {
        $keys = $state.Keys
        foreach ($key in $keys) {
            if ($Include -inotcontains $key) {
                $null = $state.TryRemove($key, [ref]$null)
            }
        }
    }

    # If Exclude is defined, remove the specified keys from the state
    if (($null -ne $Exclude) -and ($Exclude.Length -gt 0)) {
        $keys = $state.Keys
        foreach ($key in $keys) {
            if ($Exclude -icontains $key) {
                $null = $state.TryRemove($key, [ref]$null)
            }
        }
    }

    # The state is converted to JSON while preserving dictionary types (Hashtable,
    # OrderedDictionary, ConcurrentDictionary). The Compress flag minifies output.
    return ConvertTo-PodeCustomDictionaryJson -Dictionary $state -Depth $Depth -Compress:$Compress
}

<#
.SYNOPSIS
	Restores the Pode shared state from a JSON string.

.DESCRIPTION
	This function restores the in-memory Pode server state from a JSON string, ensuring compatibility
	with dictionary-based structures such as `ConcurrentDictionary`, `Hashtable`, and `OrderedDictionary`.
	If the JSON string is empty or null, the function exits silently without making changes.

	The restored state can either **overwrite** the current Pode state or **merge** with it,
	depending on the `-Merge` switch.

.PARAMETER Json
	The JSON string containing the previously saved Pode state.
	This must be a valid dictionary structure compatible with Pode's state format.

.PARAMETER Merge
	If specified, the loaded state will be merged with the existing Pode state.
	Otherwise, the current state will be fully replaced with the new data.

.OUTPUTS
	None

.EXAMPLE
	ConvertTo-PodeState -Json '{"Key1": "Value1", "Key2": "Value2"}'
	# Restores the Pode state, replacing all existing state values.

.EXAMPLE
	ConvertTo-PodeState -Json '{"Key1": "Value1", "Key2": "Value2"}' -Merge
	# Merges the restored state with the current Pode state, keeping existing keys.
#>
function ConvertTo-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Json,

        [switch]$Merge
    )

    <# Validate Pode Server Context #>
    if ($null -eq $PodeContext -or
        $null -eq $PodeContext.Server -or
        $null -eq $PodeContext.Server.State) {
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    if (![string]::IsNullOrWhiteSpace($Json)) {
        # Deserialize the JSON, preserving dictionary structures
        $state = ConvertFrom-PodeCustomDictionaryJson -Json $Json
    }
    else {
        return  # Exit if the file is empty
    }

    <# Ensure Backward Compatibility for Missing Scopes #>
    # Older versions of Pode may not include scope properties in state objects.
    foreach ($_key in $state.Keys) {
        if ($_key) {
            if ($null -eq $state[$_key].Scope) {
                $state[$_key].Scope = @()

            }
        }
    }

    <# Validate and Apply the Restored State #>
    if ($state -is [System.Collections.IDictionary]) {
        if (! $Merge) {
            # If not merging, clear the existing state before applying the restored data
            $PodeContext.Server.State.Clear()
        }
        # Merge or replace each key in the state
        foreach ($key in $state.Keys) {
            $null = $PodeContext.Server.State.TryAdd($key, $state[$key])
        }
    }
    else {
        # Raise an error if the file format is invalid
        throw ($PodeLocale.invalidPodeStateFormatExceptionMessage -f $Path, $state.GetType().FullName)
    }
}

<#
.SYNOPSIS
    Restores the Pode shared state from a JSON file.

.DESCRIPTION
    This function reads a JSON file and restores the Pode server state.
    It preserves dictionary types (ConcurrentDictionary, Hashtable, OrderedDictionary)
    and ensures state integrity. If the file does not exist, the function exits silently.

    The function supports **merging** the restored state with the current Pode state or
    **overwriting** it entirely.

.PARAMETER Path
    Specifies the JSON file path containing the saved state.

.PARAMETER Merge
    If specified, the loaded state will be merged with the existing Pode state instead
    of replacing it.

.EXAMPLE
    Restore-PodeState -Path './state.json'
    Restores the Pode state from `state.json`, replacing the current state.

.EXAMPLE
    Restore-PodeState -Path './state.json' -Merge
    Merges the loaded state with the existing Pode state.
#>
function Restore-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$Merge
    )

    <# Validate Pode Server Context #>
    if ($null -eq $PodeContext -or
        $null -eq $PodeContext.Server -or
        $null -eq $PodeContext.Server.State) {
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    <# Resolve File Path and Check Existence #>
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot
    if (!(Test-Path $Path)) {
        return  # Exit silently if the file does not exist
    }
    <# Read and Deserialize JSON #>
    $json = Get-Content -Path $Path -Raw -Force
    if ([string]::IsNullOrWhiteSpace($json)) {
        return  # Exit if the file is empty
    }

    ConvertTo-PodeState -Json $json -Merge:$Merge
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
