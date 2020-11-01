$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # GET request that recieves gzip'd json
    Add-PodeRoute -Method Post -Path '/users' -ScriptBlock {
        Write-PodeJsonResponse -Value $WebEvent.Data
    }

}