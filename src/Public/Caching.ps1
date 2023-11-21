#TODO: do we need a housekeeping timer?
#TODO: test support for custom storage in get/set


function Get-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

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
        return (Get-PodeCacheInternal -Name $Name -Metadata:$Metadata)
    }

    # used custom storage
    if (Test-PodeCacheStorage -Name $Storage) {
        return (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Get -Arguments @($Name, $Metadata.IsPresent) -Splat -Return)
    }

    # storage not found!
    throw "Cache storage with name '$($Storage)' not found when attempting to retrieve cached item '$($Name)'"
}

function Set-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [int]
        $Ttl = 0,

        [Parameter()]
        [string]
        $Storage = $null
    )

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
        Set-PodeCacheInternal -Name $Name -InputObject $InputObject -Ttl $Ttl
    }

    # used custom storage
    elseif (Test-PodeCacheStorage -Name $Storage) {
        Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Set -Arguments @($Name, $Value, $Ttl) -Splat
    }

    # storage not found!
    else {
        throw "Cache storage with name '$($Storage)' not found when attempting to set cached item '$($Name)'"
    }
}

function Test-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

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
        return (Test-PodeCacheInternal -Name $Name)
    }

    # used custom storage
    if (Test-PodeCacheStorage -Name $Storage) {
        return (Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Test -Arguments @($Name) -Splat -Return)
    }

    # storage not found!
    throw "Cache storage with name '$($Storage)' not found when attempting to check if cached item '$($Name)' exists"
}

function Remove-PodeCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

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
        Remove-PodeCacheInternal -Name $Name
    }

    # used custom storage
    elseif (Test-PodeCacheStorage -Name $Storage) {
        Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Remove -Arguments @($Name) -Splat
    }

    # storage not found!
    else {
        throw "Cache storage with name '$($Storage)' not found when attempting to remove cached item '$($Name)'"
    }
}

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
        Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Cache.Storage[$Storage].Clear
    }

    # storage not found!
    else {
        throw "Cache storage with name '$($Storage)' not found when attempting to clear cached"
    }
}

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
        throw "Cache Storage with name '$($Name) already exists"
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

function Remove-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Server.Cache.Storage.Remove($Name)
}

function Get-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Cache.Storage[$Name]
}

function Test-PodeCacheStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Cache.ContainsKey($Name)
}

function Set-PodeCacheDefaultStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $PodeContext.Server.Cache.DefaultStorage = $Name
}

function Get-PodeCacheDefaultStorage {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Cache.DefaultStorage
}

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

function Get-PodeCacheDefaultTtl {
    [CmdletBinding()]
    param()

    return $PodeContext.Server.Cache.DefaultTtl
}