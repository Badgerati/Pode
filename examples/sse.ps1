$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 3 {
    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    # log errors
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Levels *

    # open local sse connection, and send back data
    Add-PodeRoute -Method Get -Path '/data' -ScriptBlock {
        Set-PodeSseConnection -Name 'Data' -Scope Local
        Send-PodeSseMessage -Id 1234 -EventType Action -Data 'hello, there!'
        Start-Sleep -Seconds 3
        Send-PodeSseMessage -Id 1337 -EventType BoldOne -Data 'general kenobi'
    }

    # home page to get sse events
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'sse-home'
    }

    Add-PodeRoute -Method Get -Path '/sse' -ScriptBlock {
        $clientId = Set-PodeSseConnection -Name 'Test' -Scope Global
    }

    Add-PodeTimer -Name 'SendMessage' -Interval 10 -ScriptBlock {
        Send-PodeSseMessage -Name 'Test' -Data "A Message! $(Get-Random -Minimum 1 -Maximum 100)"
    }
}