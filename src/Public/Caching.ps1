<#
.SYNOPSIS
Return the value of a key from the cache. You can use "$value = $cache:key" as well.

.DESCRIPTION
Return the value of a key from the cache, or returns the value plus metadata such as expiry time if required. You can use "$value = $cache:key" as well.

.PARAMETER Key
The Key to be retrieved.

.PARAMETER Storage
An optional cache Storage name. (Default: in-memory)

.PARAMETER Metadata
If supplied, and if supported by the cache storage, an metadata such as expiry times will also be returned.

.EXAMPLE
$value = Get-PodeCache -Key 'ExampleKey'

.EXAMPLE
$value = Get-PodeCache -Key 'ExampleKey' -Storage 'ExampleStorage'

.EXAMPLE
$value = Get-PodeCache -Key 'ExampleKey' -Metadata

.EXAMPLE
$value = $cache:ExampleKey
#>
function Get-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Storage = $null,

        [switch]
        $Metadata
    )

    # inmem or custom storage?
    if ([string]::IsNullOrEmpty($Storage)) {
        $Storage = $PodeContext.Server.Cache.DefaultStorage
    }

    # use inmem cache
    if ([string]::IsNullOrEmpty($Storage)) {
        return (Get-PodeCacheInternal -Key $Key -Metadata:$Metadata)
    }

    # used custom storage
    if (Test-PodeCacheStorage -Name $Storage) {
        return (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Get -Arguments @($Key, $Metadata.IsPresent) -Splat -Return)
    }

    # storage not found!
    # Cache storage with name not found when attempting to retrieve cached item
    throw ($PodeLocale.cacheStorageNotFoundForRetrieveExceptionMessage -f $Storage, $Key)
}

<#
.SYNOPSIS
Set (create/update) a key in the cache. You can use "$cache:key = 'value'" as well.

.DESCRIPTION
Set (create/update) a key in the cache, with an optional TTL value. You can use "$cache:key = 'value'" as well.

.PARAMETER Key
The Key to be set.

.PARAMETER InputObject
The value of the key to be set, can be any object type.

.PARAMETER Ttl
An optional TTL value, in seconds. The default is whatever "Get-PodeCacheDefaultTtl" retuns, which will be 3600 seconds when not set.

.PARAMETER Storage
An optional cache Storage name. (Default: in-memory)

.EXAMPLE
Set-PodeCache -Key 'ExampleKey' -InputObject 'ExampleValue'

.EXAMPLE
Set-PodeCache -Key 'ExampleKey' -InputObject 'ExampleValue' -Storage 'ExampleStorage'

.EXAMPLE
Set-PodeCache -Key 'ExampleKey' -InputObject 'ExampleValue' -Ttl 300

.EXAMPLE
Set-PodeCache -Key 'ExampleKey' -InputObject @{ Value = 'ExampleValue' }

.EXAMPLE
@{ Value = 'ExampleValue' } | Set-PodeCache -Key 'ExampleKey'

.EXAMPLE
$cache:ExampleKey = 'ExampleValue'
#>
function Set-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [int]
        $Ttl = 0,

        [Parameter()]
        [string]
        $Storage = $null
    )

    begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    end {
        # If there are multiple piped-in values, set InputObject to the array of values
        if ($pipelineValue.Count -gt 1) {
            $InputObject = $pipelineValue
        }

        # use the global settable default here
        if ($Ttl -le 0) {
            $Ttl = $PodeContext.Server.Cache.DefaultTtl
        }

        # inmem or custom storage?
        if ([string]::IsNullOrEmpty($Storage)) {
            $Storage = $PodeContext.Server.Cache.DefaultStorage
        }

        # use inmem cache
        if ([string]::IsNullOrEmpty($Storage)) {
            Set-PodeCacheInternal -Key $Key -InputObject $InputObject -Ttl $Ttl
        }

        # used custom storage
        elseif (Test-PodeCacheStorage -Name $Storage) {
            $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Set -Arguments @($Key, $InputObject, $Ttl) -Splat
        }

        # storage not found!
        else {
            # Cache storage with name not found when attempting to set cached item
            throw ($PodeLocale.cacheStorageNotFoundForSetExceptionMessage -f $Storage, $Key)
        }
    }
}

<#
.SYNOPSIS
Test if a key exists in the cache.

.DESCRIPTION
Test if a key exists in the cache, and isn't expired.

.PARAMETER Key
The Key to test.

.PARAMETER Storage
An optional cache Storage name. (Default: in-memory)

.EXAMPLE
Test-PodeCache -Key 'ExampleKey'

.EXAMPLE
Test-PodeCache -Key 'ExampleKey' -Storage 'ExampleStorage'
#>
function Test-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Storage = $null
    )

    # inmem or custom storage?
    if ([string]::IsNullOrEmpty($Storage)) {
        $Storage = $PodeContext.Server.Cache.DefaultStorage
    }

    # use inmem cache
    if ([string]::IsNullOrEmpty($Storage)) {
        return (Test-PodeCacheInternal -Key $Key)
    }

    # used custom storage
    if (Test-PodeCacheStorage -Name $Storage) {
        return (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Test -Arguments @($Key) -Splat -Return)
    }

    # storage not found!
    # Cache storage with name not found when attempting to check if cached item exists
    throw ($PodeLocale.cacheStorageNotFoundForExistsExceptionMessage -f $Storage, $Key)
}

<#
.SYNOPSIS
Remove a key from the cache.

.DESCRIPTION
Remove a key from the cache.

.PARAMETER Key
The Key to be removed.

.PARAMETER Storage
An optional cache Storage name. (Default: in-memory)

.EXAMPLE
Remove-PodeCache -Key 'ExampleKey'

.EXAMPLE
Remove-PodeCache -Key 'ExampleKey' -Storage 'ExampleStorage'
#>
function Remove-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Storage = $null
    )

    # inmem or custom storage?
    if ([string]::IsNullOrEmpty($Storage)) {
        $Storage = $PodeContext.Server.Cache.DefaultStorage
    }

    # use inmem cache
    if ([string]::IsNullOrEmpty($Storage)) {
        Remove-PodeCacheInternal -Key $Key
    }

    # used custom storage
    elseif (Test-PodeCacheStorage -Name $Storage) {
        $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Remove -Arguments @($Key) -Splat
    }

    # storage not found!
    else {
        # Cache storage with name not found when attempting to remove cached item
        throw ($PodeLocale.cacheStorageNotFoundForRemoveExceptionMessage -f $Storage, $Key)
    }
}

<#
.SYNOPSIS
Clear all keys from the cache.

.DESCRIPTION
Clear all keys from the cache.

.PARAMETER Storage
An optional cache Storage name. (Default: in-memory)

.EXAMPLE
Clear-PodeCache

.EXAMPLE
Clear-PodeCache -Storage 'ExampleStorage'
#>
function Clear-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Storage = $null
    )

    # inmem or custom storage?
    if ([string]::IsNullOrEmpty($Storage)) {
        $Storage = $PodeContext.Server.Cache.DefaultStorage
    }

    # use inmem cache
    if ([string]::IsNullOrEmpty($Storage)) {
        Clear-PodeCacheInternal
    }

    # used custom storage
    elseif (Test-PodeCacheStorage -Name $Storage) {
        $null = Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Clear
    }

    # storage not found!
    else {
        # Cache storage with name not found when attempting to clear the cache
        throw ($PodeLocale.cacheStorageNotFoundForClearExceptionMessage -f $Storage)
    }
}

<#
.SYNOPSIS
Add a cache storage.

.DESCRIPTION
Add a cache storage.

.PARAMETER Name
The Name of the cache storage.

.PARAMETER Get
A Get ScriptBlock, to retrieve a key's value from the cache, or the value plus metadata if required. Supplied parameters: Key, Metadata.

.PARAMETER Set
A Set ScriptBlock, to set/create/update a key's value in the cache. Supplied parameters: Key, Value, TTL.

.PARAMETER Remove
A Remove ScriptBlock, to remove a key from the cache. Supplied parameters: Key.

.PARAMETER Test
A Test ScriptBlock, to test if a key exists in the cache. Supplied parameters: Key.

.PARAMETER Clear
A Clear ScriptBlock, to remove all keys from the cache. Use an empty ScriptBlock if not supported.

.PARAMETER Default
If supplied, this cache storage will be set as the default storage.

.EXAMPLE
Add-PodeCacheStorage -Name 'ExampleStorage' -Get {} -Set {} -Remove {} -Test {} -Clear {}
#>
function Add-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Get,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Set,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Remove,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Test,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $Clear,

        [switch]
        $Default
    )

    # test if storage already exists
    if (Test-PodeCacheStorage -Name $Name) {
        # Cache Storage with name already exists
        throw ($PodeLocale.cacheStorageAlreadyExistsExceptionMessage -f $Name)
    }

    # add cache storage
    $PodeContext.Server.Cache.Storage[$Name] = @{
        Name    = $Name
        Get     = $Get
        Set     = $Set
        Remove  = $Remove
        Test    = $Test
        Clear   = $Clear
        Default = $Default.IsPresent
    }

    # is default storage?
    if ($Default) {
        $PodeContext.Server.Cache.DefaultStorage = $Name
    }
}

<#
.SYNOPSIS
Remove a cache storage.

.DESCRIPTION
Remove a cache storage.

.PARAMETER Name
The Name of the cache storage.

.EXAMPLE
Remove-PodeCacheStorage -Name 'ExampleStorage'
#>
function Remove-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Server.Cache.Storage.Remove($Name)
}

<#
.SYNOPSIS
Returns a cache storage.

.DESCRIPTION
Returns a cache storage.

.PARAMETER Name
The Name of the cache storage.

.EXAMPLE
$storage = Get-PodeCacheStorage -Name 'ExampleStorage'
#>
function Get-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Cache.Storage[$Name]
}

<#
.SYNOPSIS
Test if a cache storage has been added/exists.

.DESCRIPTION
Test if a cache storage has been added/exists.

.PARAMETER Name
The Name of the cache storage.

.EXAMPLE
if (Test-PodeCacheStorage -Name 'ExampleStorage') { }
#>
function Test-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Cache.Storage.ContainsKey($Name)
}

<#
.SYNOPSIS
Set a default cache storage.

.DESCRIPTION
Set a default cache storage.

.PARAMETER Name
The Name of the default storage to use for caching.

.EXAMPLE
Set-PodeCacheDefaultStorage -Name 'ExampleStorage'
#>
function Set-PodeCacheDefaultStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $PodeContext.Server.Cache.DefaultStorage = $Name
}

<#
.SYNOPSIS
Returns the current default cache Storage name.

.DESCRIPTION
Returns the current default cache Storage name. Empty/null if one isn't set.

.EXAMPLE
$storageName = Get-PodeCacheDefaultStorage
#>
function Get-PodeCacheDefaultStorage {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Cache.DefaultStorage
}

<#
.SYNOPSIS
Set a default cache TTL.

.DESCRIPTION
Set a default cache TTL.

.PARAMETER Value
A default TTL value, in seconds, to use when setting cache key expiries.

.EXAMPLE
Set-PodeCacheDefaultTtl -Value 3600
#>
function Set-PodeCacheDefaultTtl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]
        $Value
    )

    if ($Value -le 0) {
        return
    }

    $PodeContext.Server.Cache.DefaultTtl = $Value
}

<#
.SYNOPSIS
Returns the current default cache TTL value.

.DESCRIPTION
Returns the current default cache TTL value. 3600 seconds is the default TTL if not set.

.EXAMPLE
$ttl = Get-PodeCacheDefaultTtl
#>
function Get-PodeCacheDefaultTtl {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Cache.DefaultTtl
}
