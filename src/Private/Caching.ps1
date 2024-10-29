function Get-PodeCacheInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [switch]
        $Metadata
    )

    $meta = $PodeContext.Server.Cache.Items[$Key]
    if ($null -eq $meta) {
        return $null
    }

    # check ttl/expiry
    if ($meta.Expiry -lt [datetime]::UtcNow) {
        Remove-PodeCacheInternal -Key $Key
        return $null
    }

    # return value an metadata if required
    if ($Metadata) {
        return $meta
    }

    # return just the value as default
    return $meta.Value
}

function Set-PodeCacheInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter(Mandatory = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [int]
        $Ttl = 0
    )

    # crete (or update) value value
    $PodeContext.Server.Cache.Items[$Key] = @{
        Value  = $InputObject
        Ttl    = $Ttl
        Expiry = [datetime]::UtcNow.AddSeconds($Ttl)
    }
}

function Test-PodeCacheInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key
    )

    # if it's not in the cache at all, return false
    if (!$PodeContext.Server.Cache.Items.ContainsKey($Key)) {
        return $false
    }

    # fetch the items metadata, and check expiry. If it's expired return false.
    $meta = $PodeContext.Server.Cache.Items[$Key]

    # check ttl/expiry
    if ($meta.Expiry -lt [datetime]::UtcNow) {
        Remove-PodeCacheInternal -Key $Key
        return $false
    }

    # it exists, and isn't expired
    return $true
}

function Remove-PodeCacheInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Key
    )

    Lock-PodeObject -Object $PodeContext.Threading.Lockables.Cache -ScriptBlock {
        $null = $PodeContext.Server.Cache.Items.Remove($Key)
    }
}

function Clear-PodeCacheInternal {
    Lock-PodeObject -Object $PodeContext.Threading.Lockables.Cache -ScriptBlock {
        $null = $PodeContext.Server.Cache.Items.Clear()
    }
}

function Start-PodeCacheHousekeeper {
    # if we have a custom default storage, or we're in serverless mode, then we don't need to run the housekeeper
    if (![string]::IsNullOrEmpty((Get-PodeCacheDefaultStorage)) -or $PodeContext.Server.IsServerless) {
        return
    }

    Add-PodeTimer -Name '__pode_cache_housekeeper__' -Interval 10 -ScriptBlock {
        $keys = Lock-PodeObject -Object $PodeContext.Threading.Lockables.Cache -Return -ScriptBlock {
            if ($PodeContext.Server.Cache.Items.Count -eq 0) {
                return
            }

            return $PodeContext.Server.Cache.Items.Keys.Clone()
        }

        if (Test-PodeIsEmpty $keys) {
            return
        }

        $now = [datetime]::UtcNow

        foreach ($key in $keys) {
            if ($PodeContext.Server.Cache.Items[$key].Expiry -lt $now) {
                Remove-PodeCacheInternal -Key $key
            }
        }
    }
}