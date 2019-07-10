$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server listening on port 8085, set to monitor file changes and restart the server
Start-PodeServer {

    Add-PodeEndpoint -Endpoint *:8085 -Protocol HTTP
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        param($session)
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

}
