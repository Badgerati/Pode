try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

try {
    if (Get-Command redis-cli -ErrorAction Stop) {
        Write-Output 'redis-cli exists.'
    }
}
catch {
    throw 'Cannot continue redis-cli does not exist.'
}

# create a server, and start listening on port 8081
Start-PodeServer -Threads 3 {
    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # log errors
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Set-PodeCacheDefaultTtl -Value 60

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
            return $result
        }
        Test   = {
            param($key)
            $result = redis-cli -h localhost -p 6379 EXISTS $key
            return [System.Management.Automation.Internal.StringDecorated]::new($result).ToString('PlainText')
        }
        Remove = {
            param($key)
            $null = redis-cli -h localhost -p 6379 EXPIRE $key -1
        }
        Clear  = {}
    }
    if ($params) {
        Add-PodeCacheStorage -Name 'Redis' @params

        # set default value for cache
        $cache:cpu = (Get-Random -Minimum 1 -Maximum 1000)

        # get cpu, and cache it
        Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
            if ((Test-PodeCache -Key 'cpu') -and ($null -ne $cache:cpu)) {
                Write-PodeJsonResponse -Value @{ CPU = $cache:cpu }
                # Write-PodeHost 'here - cached'
                return
            }

            # $cache:cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
            Start-Sleep -Milliseconds 500
            $cache:cpu = (Get-Random -Minimum 1 -Maximum 1000)
            Write-PodeJsonResponse -Value @{ CPU = $cache:cpu }
            # $cpu = (Get-Random -Minimum 1 -Maximum 1000)
            # Write-PodeJsonResponse -Value @{ CPU = $cpu }
            # Write-PodeHost 'here - raw'
        }
    }

}