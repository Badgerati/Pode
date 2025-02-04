
<#
.SYNOPSIS
    Deserializes JSON from ConvertTo-PodeCustomDictionaryJson (nested) back into
    the original dictionary/collection type (Hashtable, ConcurrentDictionary, OrderedDictionary,
    ConcurrentBag, ConcurrentQueue, ConcurrentStack, or PSCustomObject with PsTypeName).

.DESCRIPTION
    Recursively reads the JSON, checks the "Type" property, and reconstructs
    the corresponding dictionary/collection. Also handles arrays, PSCustomObjects, and primitive types.

.PARAMETER Json
    A JSON string containing "Type" and "Items" at each dictionary/collection level.

.OUTPUTS
    - [Hashtable]
    - [System.Collections.Concurrent.ConcurrentDictionary[string, object]]
    - [System.Collections.Specialized.OrderedDictionary]
    - [System.Collections.Concurrent.ConcurrentBag[object]]
    - [System.Collections.Concurrent.ConcurrentQueue[object]]
    - [System.Collections.Concurrent.ConcurrentStack[object]]
    - [PSCustomObject] (when applicable, with preserved PsTypeName)
    - Arrays, primitives, or other structures.

.NOTES
    This function is for internal Pode usage and may be subject to change.
#>
function ConvertFrom-PodeCustomDictionaryJson {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Json
    )

    function Construct {
        param([object]$obj)

        <# Handle Null Values #>
        if ($null -eq $obj) {
            return $null
        }

        <# Handle Arrays/Lists #>
        if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
            $resultList = @()
            foreach ($item in $obj) {
                $resultList += Construct $item
            }
            return $resultList
        }

        <# Handle PSCustomObject (Check for "Type" Property) #>
        if ($obj -is [PSCustomObject]) {
            if ($obj.PSObject.Properties.Name -contains 'Type') {
                # Reconstruct Dictionaries & Collections
                switch ($obj.Type) {
                    'Hashtable' {
                        $dict = @{}
                        foreach ($pair in $obj.Items) {
                            $dict[$pair.Key] = (Construct -obj $pair.Value)
                        }
                        return $dict
                    }
                    'ConcurrentDictionary' {
                        $dict = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
                        foreach ($pair in $obj.Items) {
                            $null = $dict.TryAdd($pair.Key, (Construct -obj $pair.Value))
                        }
                        return $dict
                    }
                    'OrderedDictionary' {
                        $dict = [ordered]@{}
                        foreach ($pair in $obj.Items) {
                            $dict[$pair.Key] = (Construct -obj $pair.Value)
                        }
                        return $dict
                    }
                    'ConcurrentBag' {
                        # Rebuild a ConcurrentBag[object]
                        $bag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
                        foreach ($item in $obj.Items) {
                            $bag.Add((Construct -obj $item))
                        }
                        return , $bag  # Prepend with a comma to return it as an object, not Object[]
                    }
                    'ConcurrentQueue' {
                        # Rebuild a ConcurrentQueue[object]
                        $queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
                        foreach ($item in $obj.Items) {
                            $queue.Enqueue((Construct -obj $item))
                        }
                        return $queue
                    }
                    'ConcurrentStack' {
                        # Rebuild a ConcurrentStack[object]
                        $stack = [System.Collections.Concurrent.ConcurrentStack[object]]::new()
                        foreach ($item in $obj.Items) {
                            $stack.Push((Construct -obj $item))
                        }
                        return $stack
                    }
                    default {
                        throw ($PodeLocale.unknownJsonDictionaryTypeExceptionMessage -f $obj.Type)
                    }
                }
            }
            else {
                <# Preserve PSCustomObject Instead of Converting to Hashtable #>
                $restoredObject = [PSCustomObject]@{}

                <# Add Other Properties #>
                $properties = $obj | Get-Member -MemberType NoteProperty, AliasProperty, ScriptProperty
                foreach ($prop in $properties) {
                    if ($prop.Name -ne '__PsTypeName__') {
                        $restoredObject | Add-Member -MemberType NoteProperty -Name $prop.Name -Value (Construct($obj.$($prop.Name))) -Force
                    }
                    else {
                        if ( $obj.$($prop.Name) -ne 'System.Management.Automation.PSCustomObject') {
                            $restoredObject.PSTypeNames.Insert(0, $obj.$($prop.Name))
                        }
                    }
                }

                return $restoredObject
            }
        }

        <# Return Primitive Values as-is #>
        return $obj
    }


    # Parse the top-level JSON into a PSObject/Array
    $parsed = $Json | ConvertFrom-Json
    if ($parsed.Metadata) {
        if ($parsed.Metadata.Product -ne 'Pode') {
            # 'The provided data does not represent a valid Pode state.'
            throw $PodeLocale.invalidPodeStateDataExceptionMessage
        }
        $podeVersion = (Get-PodeVersion -Raw)
        if (!($podeVersion -eq '[dev]' -or ( ([System.Version]$parsed.Metadata) -le ([System.Version]$podeVersion))) ) {
            # The provided state data originates from a newer Pode version:
            throw ($PodeLocale.podeStateVersionMismatchExceptionMessage -f $parsed.Metadata)
        }
        if ($parsed.Metadata.Application -ne (Get-PodeApplicationName)) {
            # The provided state data belongs to a different application
            throw ($PodeLocale.podeStateApplicationMismatchExceptionMessage -f $parsed.Metadata.Application)
        }

        <# Rebuild the Full Structure from JSON #>
        return Construct -obj $parsed.Data
    }
    else {
        return ConvertTo-PodeHashtable -InputObject $parsed
    }
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
#>
function ConvertTo-PodeCustomDictionaryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Dictionary,

        [Parameter()]
        [int16]
        $Depth = 20,

        [switch]
        $Compress
    )

    # Nested helper to recursively deconstruct objects
    function Deconstruct {
        param([Parameter()] $Object)

        if ($null -eq $Object) {
            return $null  # Return null without modification
        }

        # Return common primitives directly
        if ($Object.PSObject.BaseObject.GetType().IsPrimitive -or
            $Object -is [string] -or
            $Object -is [datetime]) {
            return $Object
        }

        <# Handle PSCustomObject (Preserve PsTypeName) #>
        if ($Object -is [PSCustomObject]) {
            $serializedObject = [ordered]@{}
            if ($Object.PSTypeNames.Count -gt 0) {
                $serializedObject['__PsTypeName__'] = $Object.PSTypeNames[0]  # Preserve the first PsTypeName
            }
            foreach ($prop in $Object.PSObject.Properties) {
                $serializedObject[$prop.Name] = Deconstruct($prop.Value)
            }
            return $serializedObject
        }

        # Handle OrderedDictionary
        if ($Object -is [System.Collections.Specialized.OrderedDictionary]) {
            $wrapper = [PSCustomObject]@{ Type = 'OrderedDictionary'; Items = @() }
            foreach ($key in $Object.Keys) {
                $wrapper.Items += [PSCustomObject]@{
                    Key   = $key
                    Value = Deconstruct($Object[$key])
                }
            }
            return $wrapper
        }

        # Handle Hashtable
        if ($Object -is [System.Collections.Hashtable]) {
            $wrapper = [PSCustomObject]@{ Type = 'Hashtable'; Items = @() }
            foreach ($key in $Object.Keys) {
                $wrapper.Items += [PSCustomObject]@{
                    Key   = $key
                    Value = Deconstruct($Object[$key])
                }
            }
            return $wrapper
        }

        # Handle ConcurrentDictionary
        if ($Object -is [System.Collections.Concurrent.ConcurrentDictionary[string, object]]) {
            $wrapper = [PSCustomObject]@{ Type = 'ConcurrentDictionary'; Items = @() }
            foreach ($key in $Object.Keys) {
                $wrapper.Items += [PSCustomObject]@{
                    Key   = $key
                    Value = Deconstruct($Object[$key])
                }
            }
            return $wrapper
        }

        # Handle ConcurrentBag[object]
        if ($Object -is [System.Collections.Concurrent.ConcurrentBag[object]]) {
            $wrapper = [PSCustomObject]@{ Type = 'ConcurrentBag'; Items = @() }
            foreach ($item in $Object) {
                $wrapper.Items += Deconstruct($item)
            }
            return $wrapper
        }

        # Handle ConcurrentQueue[object]
        if ($Object -is [System.Collections.Concurrent.ConcurrentQueue[object]]) {
            $wrapper = [PSCustomObject]@{ Type = 'ConcurrentQueue'; Items = @() }
            foreach ($item in $Object) {
                $wrapper.Items += Deconstruct($item)
            }
            return $wrapper
        }

        # Handle ConcurrentStack[object]
        if ($Object -is [System.Collections.Concurrent.ConcurrentStack[object]]) {
            $wrapper = [PSCustomObject]@{ Type = 'ConcurrentStack'; Items = @() }
            foreach ($item in $Object) {
                $wrapper.Items += Deconstruct($item)
            }
            return $wrapper
        }

        # If it's a list/array, process each item but return as array
        if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
            if ($Object.Count -eq 0) {
                return , @()
            }
            $convertedArray = @()
            foreach ($item in $Object) {
                $convertedArray += Deconstruct($item)
            }
            return $convertedArray
        }

        # If it's a PSCustomObject, process each property individually
        if ($Object -is [PSCustomObject]) {
            $newObj = [ordered]@{}
            $properties = $Object | Get-Member -MemberType NoteProperty, AliasProperty, ScriptProperty
            foreach ($prop in $properties) {
                $newObj[$prop.Name] = Deconstruct($Object.$($prop.Name))
            }
            return $newObj
        }

        # Fallback: Return object as-is (any other primitive or type)
        return $Object
    }

    $converted = [ordered]@{
        Metadata = [ordered]@{
            Product     = 'Pode'
            Version     = Get-PodeVersion
            Timestamp   = Get-Date -AsUTC
            Application = Get-PodeApplicationName
        }
        Data     = @{}
    }
    # If top-level is null, treat as an empty dictionary
    if ($null -ne $Dictionary) {
        # Recursively convert any nested structures
        $converted.Data = Deconstruct -Object $Dictionary
    }

    # Finally convert to JSON
    return $converted | ConvertTo-Json -Depth $Depth -Compress:$Compress
}


<#
.SYNOPSIS
    Converts a PSCustomObject or nested object structure into a hashtable.

.DESCRIPTION
    The `ConvertTo-PodeHashtable` function recursively converts a PowerShell `PSCustomObject`
    into a hashtable while preserving the original data structure. It ensures that objects,
    arrays, and collections are properly transformed, while primitive types such as numbers,
    booleans, and strings remain unchanged.

.PARAMETER InputObject
    Specifies the input object to convert. The function can accept:
    - A `PSCustomObject`, which will be transformed into a hashtable.
    - A collection (`Array`, `List`), which will be processed recursively.
    - A primitive type (`String`, `Number`, `Boolean`), which will remain unchanged.

.EXAMPLE
    $psCustomObject = [PSCustomObject]@{
        Name    = "Pode"
        Version = 2.0
        Active  = $true
        Metadata = [PSCustomObject]@{
            Author  = "Pode Team"
            Created = "2025-02-03"
            Stats   = [PSCustomObject]@{
                Users   = 150
                Servers = 5
            }
        }
        Features = @("Fast", "Lightweight", "Modular")
    }

    $hashtable = ConvertTo-PodeHashtable -InputObject $psCustomObject
    $hashtable

.EXAMPLE
    # Convert a list of PSCustomObjects to an array of hashtables
    $users = @(
        [PSCustomObject]@{ ID = 1; Name = "Alice" }
        [PSCustomObject]@{ ID = 2; Name = "Bob" }
    )

    $hashtableList = ConvertTo-PodeHashtable -InputObject $users
    $hashtableList

.EXAMPLE
    # Using pipeline input
    $users | ConvertTo-PodeHashtable

.NOTES
    - This function ensures deep conversion of nested PSCustomObjects while leaving primitive values intact.
    - Collections (e.g., Arrays, Lists) are processed recursively, preserving structure.
    - This function is for internal Pode usage and may be subject to change.
#>

function ConvertTo-PodeHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        [psobject]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            Write-Output -NoEnumerate -InputObject  @(
                foreach ($object in $InputObject) { ConvertTo-PodeHashtable -InputObject $object }
            )
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = (ConvertTo-PodeHashtable -InputObject $property.Value).PSObject.BaseObject
            }
            $hash
        }
        else {
            $InputObject
        }
    }
}
