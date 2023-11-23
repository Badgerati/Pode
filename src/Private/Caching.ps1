function Get-PodeCacheInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [switch]
        $Metadata
    )

    $meta = $PodeContext.Server.Cache.Items[$Name]
    if ($null -eq $meta) {
        return $null
    }

    # check ttl/expiry
    if ($meta.Expiry -lt [datetime]::UtcNow) {
        Remove-PodeCacheInternal -Name $Name
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
        $Name,

        [Parameter(Mandatory = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [int]
        $Ttl = 0
    )

    # crete (or update) value value
    $PodeContext.Server.Cache.Items[$Name] = @{
        Value  = $InputObject
        Ttl    = $Ttl
        Expiry = [datetime]::UtcNow.AddSeconds($Ttl)
    }
}

function Test-PodeCacheInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Cache.Items.ContainsKey($Name)
}

function Remove-PodeCacheInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    Lock-PodeObject -Object $PodeContext.Threading.Lockables.Cache -ScriptBlock {
        $null = $PodeContext.Server.Cache.Items.Remove($Name)
    }
}

function Clear-PodeCacheInternal {
    Lock-PodeObject -Object $PodeContext.Threading.Lockables.Cache -ScriptBlock {
        $null = $PodeContext.Server.Cache.Items.Clear()
    }
}

function Start-PodeCacheHousekeeper {
    if (![string]::IsNullOrEmpty((Get-PodeCacheDefaultStorage))) {
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
                Remove-PodeCacheInternal -Name $key
            }
        }
    }
}