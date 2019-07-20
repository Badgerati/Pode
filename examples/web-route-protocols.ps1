$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8080 and 8443
Start-PodeServer {

    # listen on localhost:8080/8443
    Add-PodeEndpoint -Address *:8080 -Protocol Http
    Add-PodeEndpoint -Address *:8443 -Protocol HTTPS

    # set view engine to pode
    Set-PodeViewEngine -Type Pode

    # GET request for web page
    Add-PodeRoute -Method Get -Path '/' -Endpoint *:8443 -Protocol Http -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

    # GET request with parameters
    Add-PodeRoute -Method Get -Path '/:userId/details' -ScriptBlock {
        param($event)
        Write-PodeJsonResponse -Value @{ 'userId' = $event.Parameters['userId'] }
    }

    # ALL requests for http only to redirect to https
    Add-PodeRoute -Method * -Path * -Protocol Http {
        Move-PodeResponseUrl -Protocol https -Port 8443
    }

}