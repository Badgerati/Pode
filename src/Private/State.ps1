function ConvertTo-PodeStateData {
    param(
        [Parameter()]
        [object]
        $InputObject
    )

    # return null if no object
    if ($null -eq $InputObject) {
        return $null
    }

    # for date/times, return in ISO 8601 format
    if ($InputObject -is [datetime]) {
        return @{
            Type  = 'DateTime'
            Value = $InputObject.ToString('o')
        }
    }

    # for time spans, return as ticks
    if ($InputObject -is [timespan]) {
        return @{
            Type  = 'TimeSpan'
            Value = $InputObject.Ticks
        }
    }

    # for a guid, return as string
    if ($InputObject -is [guid]) {
        return @{
            Type  = 'Guid'
            Value = $InputObject.ToString()
        }
    }

    # return raw object if it's a value type or string
    if (($InputObject -is [valuetype]) -or ($InputObject -is [string])) {
        return @{
            Type  = $InputObject.GetType().Name
            Value = $InputObject
        }
    }

    # handle each key for hashtables, and dictionaries
    if (
        ($InputObject -is [hashtable]) -or
        ($InputObject -is [System.Collections.Specialized.OrderedDictionary]) -or
        ($InputObject -is [System.Collections.Generic.Dictionary[string, object]]) -or
        ($InputObject -is [System.Collections.Concurrent.ConcurrentDictionary[string, object]]) -or
        ($InputObject -is [Pode.Utilities.Structures.PodeConcurrentOrderedDictionary[string, object]])
    ) {
        $result = @{
            Type  = ($InputObject.GetType().Name -split '`')[0]
            Items = @()
        }

        foreach ($key in $InputObject.Keys) {
            $result.Items += @{
                Key   = $key
                Value = ConvertTo-PodeStateData -InputObject $InputObject[$key]
            }
        }

        return $result
    }

    # handle each item in lists, set, and bags
    if (
        ($InputObject -is [System.Collections.Generic.List[object]]) -or
        ($InputObject -is [System.Collections.Generic.HashSet[object]]) -or
        ($InputObject -is [System.Collections.Generic.SortedSet[object]]) -or
        ($InputObject -is [System.Collections.Concurrent.ConcurrentBag[object]]) -or
        ($InputObject -is [Pode.Utilities.Structures.PodeConcurrentList[object]]) -or
        ($InputObject -is [Pode.Utilities.Structures.PodeConcurrentSet[object]])
    ) {
        $result = @{
            Type  = ($InputObject.GetType().Name -split '`')[0]
            Items = @()
        }

        foreach ($item in $InputObject) {
            $result.Items += ConvertTo-PodeStateData -InputObject $item
        }

        return $result
    }

    # handle generic arrays / IEnumerable
    if (($InputObject -is [array]) -or ($InputObject -is [System.Collections.IEnumerable])) {
        if ($InputObject.Length -eq 0) {
            return , @()
        }

        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-PodeStateData -InputObject $item
        }

        return , $items
    }

    # handle PSCustomObject
    if ($InputObject -is [PSCustomObject]) {
        $result = @{
            Type  = 'PSCustomObject'
            Items = @()
        }

        foreach ($key in $InputObject.PSObject.Properties.Name) {
            $result.Items += @{
                Key   = $key
                Value = ConvertTo-PodeStateData -InputObject $InputObject.$key
            }
        }

        return $result
    }

    # return object as is
    return $InputObject
}

function ConvertFrom-PodeStateJson {
    param(
        [Parameter()]
        [pscustomobject]
        $InputObject
    )

    # legacy version, convert to concurrent dictionary and return
    if ($null -eq $InputObject.__pode_state_metadata__) {
        $state = New-PodeStateDictionary

        if ($InputObject -is [hashtable]) {
            foreach ($key in $InputObject.Keys) {
                $state[$key] = $InputObject[$key]
            }
        }
        else {
            foreach ($key in $InputObject.psobject.properties.name) {
                $state[$key] = $InputObject.$key
            }
        }

        return $state
    }

    # convert based on the version of the state file
    switch ($InputObject.__pode_state_metadata__.Version) {
        2 {
            return ConvertFrom-PodeStateData -InputObject $InputObject.__pode_state_data__
        }
    }
}

function ConvertFrom-PodeStateData {
    param(
        [Parameter()]
        [object]
        $InputObject
    )

    # return null if no object
    if ($null -eq $InputObject) {
        return $null
    }

    # if it's not a pscustomobject, or doesn't contain a Type, handle raw types
    if ([string]::IsNullOrEmpty($InputObject.Type) -or ($InputObject.Type.Count -gt 1)) {
        # handle value types and strings
        if (($InputObject -is [valuetype]) -or ($InputObject -is [string])) {
            return $InputObject
        }

        # handle arrays
        if (($InputObject -is [array]) -or ($InputObject -is [System.Collections.IEnumerable])) {
            $items = @()

            foreach ($item in $InputObject) {
                $items += ConvertFrom-PodeStateData -InputObject $item
            }

            return , $items
        }

        # else return the object as is
        return $InputObject
    }

    # convert based on the type of object
    switch ($InputObject.Type) {
        'DateTime' {
            if ($InputObject.Value -is [datetime]) {
                return $InputObject.Value
            }
            return [datetime]::Parse($InputObject.Value)
        }

        'TimeSpan' {
            return [timespan]::FromTicks($InputObject.Value)
        }

        'Guid' {
            return [guid]::Parse($InputObject.Value)
        }

        'Int32' {
            return [int]$InputObject.Value
        }

        'Int64' {
            return [long]$InputObject.Value
        }

        'Double' {
            return [double]$InputObject.Value
        }

        'Decimal' {
            return [decimal]$InputObject.Value
        }

        'Float' {
            return [float]$InputObject.Value
        }

        'Boolean' {
            return [bool]$InputObject.Value
        }

        'String' {
            return [string]$InputObject.Value
        }

        'Char' {
            return [char]$InputObject.Value
        }

        'Byte' {
            return [byte]$InputObject.Value
        }

        'SByte' {
            return [sbyte]$InputObject.Value
        }

        'UInt16' {
            return [uint16]$InputObject.Value
        }

        'UInt32' {
            return [uint32]$InputObject.Value
        }

        'UInt64' {
            return [uint64]$InputObject.Value
        }

        'Single' {
            return [single]$InputObject.Value
        }

        'Int16' {
            return [int16]$InputObject.Value
        }

        'Hashtable' {
            $result = @{}

            foreach ($item in $InputObject.Items) {
                $result[$item.Key] = ConvertFrom-PodeStateData -InputObject $item.Value
            }

            return $result
        }

        { $_ -iin @('OrderedDictionary', 'OrderedHashtable') } {
            $result = [ordered]@{}

            foreach ($item in $InputObject.Items) {
                $result[$item.Key] = ConvertFrom-PodeStateData -InputObject $item.Value
            }

            return $result
        }

        'Dictionary' {
            $result = [System.Collections.Generic.Dictionary[string, object]]::new()

            foreach ($item in $InputObject.Items) {
                $result[$item.Key] = ConvertFrom-PodeStateData -InputObject $item.Value
            }

            return $result
        }

        'ConcurrentDictionary' {
            $result = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()

            foreach ($item in $InputObject.Items) {
                $result[$item.Key] = ConvertFrom-PodeStateData -InputObject $item.Value
            }

            return $result
        }

        'PodeConcurrentOrderedDictionary' {
            $result = New-PodeStateDictionary

            foreach ($item in $InputObject.Items) {
                $result[$item.Key] = ConvertFrom-PodeStateData -InputObject $item.Value
            }

            return , $result
        }

        'List' {
            $result = [System.Collections.Generic.List[object]]::new()

            foreach ($item in $InputObject.Items) {
                $null = $result.Add((ConvertFrom-PodeStateData -InputObject $item))
            }

            return , $result
        }

        'HashSet' {
            $result = [System.Collections.Generic.HashSet[object]]::new()

            foreach ($item in $InputObject.Items) {
                $null = $result.Add((ConvertFrom-PodeStateData -InputObject $item))
            }

            return , $result
        }

        'SortedSet' {
            $result = [System.Collections.Generic.SortedSet[object]]::new()

            foreach ($item in $InputObject.Items) {
                $null = $result.Add((ConvertFrom-PodeStateData -InputObject $item))
            }

            return , $result
        }

        'ConcurrentBag' {
            $result = [System.Collections.Concurrent.ConcurrentBag[object]]::new()

            foreach ($item in $InputObject.Items) {
                $null = $result.TryAdd((ConvertFrom-PodeStateData -InputObject $item))
            }

            return , $result
        }

        'PodeConcurrentList' {
            $result = New-PodeStateList

            foreach ($item in $InputObject.Items) {
                $null = $result.TryAdd((ConvertFrom-PodeStateData -InputObject $item))
            }

            return , $result
        }

        'PodeConcurrentSet' {
            $result = New-PodeStateSet

            foreach ($item in $InputObject.Items) {
                $null = $result.TryAdd((ConvertFrom-PodeStateData -InputObject $item))
            }

            return , $result
        }

        'PSCustomObject' {
            $result = [PSCustomObject]@{}

            foreach ($item in $InputObject.Items) {
                $null = $result | Add-Member -MemberType NoteProperty -Name $item.Key -Value (ConvertFrom-PodeStateData -InputObject $item.Value) -Force
            }

            return $result
        }
    }

    # if we get here, return the object as is
    if ($InputObject.Value) {
        return $InputObject.Value
    }

    return $InputObject.Items
}