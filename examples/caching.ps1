$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 3 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    # log errors
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Set-PodeCacheDefaultTtl -Value 60

    $params = @{
        Set    = {
            param($name, $value, $ttl)
            $null = redis-cli -h localhost -p 6379 SET $name "$($value)" EX $ttl
        }
        Get    = {
            param($name, $metadata)
            $result = redis-cli -h localhost -p 6379 GET $name
            $result = [System.Management.Automation.Internal.StringDecorated]::new($result).ToString('PlainText')
            if ([string]::IsNullOrEmpty($result) -or ($result -ieq '(nil)')) {
                return $null
            }
            return $result
        }
        Test   = {
            param($name)
            $result = redis-cli -h localhost -p 6379 EXISTS $name
            return [System.Management.Automation.Internal.StringDecorated]::new($result).ToString('PlainText')
        }
        Remove = {
            param($name)
            $null = redis-cli -h localhost -p 6379 EXPIRE $name -1
        }
        Clear  = {}
    }
    Add-PodeCacheStorage -Name 'Redis' @params


    # get cpu, and cache it
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        if ($null -ne $cache:cpu) {
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