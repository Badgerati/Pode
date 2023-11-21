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

    # get cpu, and cache it
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        if ($null -ne $cache:cpu) {
            Write-PodeJsonResponse -Value @{ CPU = $cache:cpu }
            # Write-PodeHost 'here - cached'
            return
        }

        $cache:cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
        Write-PodeJsonResponse -Value @{ CPU = $cache:cpu }
        # Write-PodeHost 'here - raw'
    }

}