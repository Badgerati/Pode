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
    This value is passed to `ConvertTo-PodeCustomDictionaryJson`. Default is **10**.

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

.NOTES
    - This function is intended for internal Pode usage and may be subject to changes.
    - For more information, refer to: https://github.com/Badgerati/Pode/tree/develop
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


    # Validate Pode Server Context

    if ($null -eq $PodeContext -or
        $null -eq $PodeContext.Server -or
        $null -eq $PodeContext.Server.State) {
        throw ($PodeLocale.podeNotInitializedExceptionMessage)
    }

    # Convert relative path to absolute
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot


    # Create a Shallow Copy of the Current State

    # A new ConcurrentDictionary is created to store a snapshot of the current state,
    # preventing modifications while the state is being serialized.
    $state = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
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
    $json = ConvertTo-PodeCustomDictionaryJson -Dictionary $state -Depth $Depth -Compress:$Compress
    $json | Out-File -FilePath $Path -Force
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

.PARAMETER Depth
    Defines the maximum depth for JSON deserialization.
    This value is passed to `ConvertFrom-PodeCustomDictionaryJson`. Default is **10**.

.EXAMPLE
    Restore-PodeState -Path './state.json'
    Restores the Pode state from `state.json`, replacing the current state.

.EXAMPLE
    Restore-PodeState -Path './state.json' -Merge
    Merges the loaded state with the existing Pode state.

.OUTPUTS
    [System.Void] - The function updates `$PodeContext.Server.State` but does not return a value.

.NOTES
    - This function is intended for internal Pode usage and may be subject to changes.
    - For more details, refer to: https://github.com/Badgerati/Pode/tree/develop
#>
function Restore-PodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$Merge,

        [int16]$Depth = 10
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
    if (![string]::IsNullOrWhiteSpace($json)) {
        # Deserialize the JSON, preserving dictionary structures
        $state = ConvertFrom-PodeCustomDictionaryJson -Json $json
    }
    else {
        return  # Exit if the file is empty
    }

    <# Ensure Backward Compatibility for Missing Scopes #>
    # Older versions of Pode may not include scope properties in state objects.
    # This ensures each state entry has a 'Scope' property for compatibility.
    $convert = $false
    foreach ($_key in $state.Keys) {
        if ($null -eq $state[$_key].Scope) {
            $convert = $true
            break
        }
    }

    if ($convert) {
        foreach ($_key in $state.Keys) {
            $old = $state[$_key]
            $state[$_key] = @{
                Value = $old
                Scope = @()  # Ensure an empty array if scope was missing
            }
        }
    }

    <# Validate and Apply the Restored State #>
    if ($state -is [System.Collections.IDictionary]) {
        if (-not $Merge) {
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
 