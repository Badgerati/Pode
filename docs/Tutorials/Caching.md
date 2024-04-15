# Caching

Pode has an inbuilt in-memory caching feature, allowing you to cache values for a duration of time to speed up slower queries. You can also set up custom caching storage solutions - such as Redis, and others.

The default TTL for cached items is 3,600 seconds (1 hour), and this value can be customised either globally or per item. There is also a `$cache:` scoped variable available for use.

## Caching Items

To add an item to the cache use [`Set-PodeCache`](../../Functions/Caching/Set-PodeCache), and then to retrieve the value from the cache use [`Get-PodeCache`](../../Functions/Caching/Get-PodeCache). If the item has expired when `Get-PodeCache` is called then `$null` will be returned.

For example, the following would retrieve the current CPU on Windows machines and cache it for 60 seconds:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    # check cache
    $cpu = Get-PodeCache -Key 'cpu'
    if ($null -ne $cpu) {
        Write-PodeJsonResponse -Value @{ CPU = $cpu }
        return
    }

    # get cpu, and cache for 60s
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $cpu | Set-PodeCache -Key 'cpu' -Ttl 60

    Write-PodeJsonResponse -Value @{ CPU = $cpu }
}
```

Alternatively, you could use the `$cache:` scoped variable instead. However, using this there is no way to pass the TTL when setting new cached items, so all items cached in this manner will use the default TTL (1 hour, unless changed). Changing the default TTL is discussed [below](#default-ttl).

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    # check cache
    $cpu = $cache:cpu
    if ($null -ne $cpu) {
        Write-PodeJsonResponse -Value @{ CPU = $cpu }
        return
    }

    # get cpu, and cache for 1hr
    $cache:cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    Write-PodeJsonResponse -Value @{ CPU = $cache:cpu }
}
```

You can test if an item exists in the cache, and isn't expired, using [`Test-PodeCache`](../../Functions/Caching/Test-PodeCache) - this is useful to call if the cached value for a key happens to genuinely be `$null`, so you can see if the key does exist.

If you need to invalidate a cached value you can use [`Remove-PodeCache`](../../Functions/Caching/Remove-PodeCache), or if you need to invalidate the whole cache you can use [`Clear-PodeCache`](../../Functions/Caching/Clear-PodeCache).

### Default TTL

The default TTL for cached items, when the server starts, is 1 hour. This can be changed by using [`Set-PodeCacheDefaultTtl`](../../Functions/Caching/Set-PodeCacheDefaultTtl). The following updates the default TTL to 60 seconds:

```powershell
Start-PodeServer {
    Set-PodeCacheDefaultTtl -Value 60
}
```

All new cached items will use this TTL by default unless the one is explicitly specified on [`Set-PodeCache`](../../Functions/Caching/Set-PodeCache) using the `-Ttl` parameter.

## Custom Storage

The inbuilt storage used by Pode is a simple in-memory synchronized hashtable, if you're running multiple instances of your Pode server then you'll have multiple caches as well - potentially with different values for the keys.

You can set up custom storage devices for your cached values using [`Add-PodeCacheStorage`](../../Functions/Caching/Add-PodeCacheStorage) - you can also set up multiple different storages, and specify where certain items should be cached using the `-Storage` parameter on `Get-PodeCache` and `Set-PodeCache`.

When setting up a new cache storage, you are required to specific a series of scriptblocks for:

* Setting a cached item (create/update). (`-Set`)
* Getting a cached item's value. (`-Get`)
* Testing if a cached item exists. (`-Test`)
* Removing a cached item. (`-Remove`)
* Clearing a cache of all items. (`-Clear`)

!!! note
    Not all providers will support all options, such as clearing the whole cache. When this is the case simply pass an empty scriptblock to the parameter.

The `-Test` and `-Remove` scriptblocks will each be supplied the key for the cached item; the `-Test` scriptblock should return a boolean value. The `-Set` scriptblock will be supplied with the key, value, and TTL for the cached item. The `-Get` scriptblock will be supplied with the key of the item to retrieve, but also a boolean "metadata" flag - if this metadata flag is false, just return the item's value, but if it's true return a hashtable of the value and other metadata properties for expiry and ttl.

For example, say you want to use Redis to store your cached items, then you would have a similar setup to the one below.

```powershell
$params = @{
    Set    = {
        param($key, $value, $ttl)
        $null = redis-cli -h localhost -p 6379 SET $key "$($value)" EX $ttl
    }
    Get    = {
        param($key, $metadata)
        $result = redis-cli -h localhost -p 6379 GET $key
        $result = [System.Management.Automation.Internal.StringDecorated]::new($result).ToString('PlainText')
        if ([string]::IsNullOrEmpty($result) -or ($result -ieq '(nil)')) {
            return $null
        }

        if ($metadata) {
            $ttl = redis-cli -h localhost -p 6379 TTL $key
            $ttl = [int]([System.Management.Automation.Internal.StringDecorated]::new($result).ToString('PlainText'))

            $result = @{
                Value = $result
                Ttl = $ttl
                Expiry = [datetime]::UtcNow.AddSeconds($ttl)
            }
        }

        return $result
    }
    Test   = {
        param($key)
        $result = redis-cli -h localhost -p 6379 EXISTS $key
        return ([System.Management.Automation.Internal.StringDecorated]::new($result).ToString('PlainText') -eq '1')
    }
    Remove = {
        param($key)
        $null = redis-cli -h localhost -p 6379 EXPIRE $key -1
    }
    Clear  = {}
}

Add-PodeCacheStorage -Name 'Redis' @params
```

Then to use the storage, pass the name to the `-Storage` parameter:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    # check cache
    $cpu = Get-PodeCache -Key 'cpu' -Storage 'Redis'
    if ($null -ne $cpu) {
        Write-PodeJsonResponse -Value @{ CPU = $cpu }
        return
    }

    # get cpu, and cache for 60s
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $cpu | Set-PodeCache -Key 'cpu' -Ttl 60 -Storage 'Redis'

    Write-PodeJsonResponse -Value @{ CPU = $cpu }
}
```

### Default Storage

Similar to the TTL, you can change the default cache storage from Pode's in-memory one to a custom-added one. This default storage will be used for all cached items when `-Storage` is supplied, and when using `$cache:` as well.

```powershell
Start-PodeServer {
    Set-PodeCacheDefaultStorage -Name 'Redis'
}
```
