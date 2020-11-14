$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8080 and 8443
Start-PodeServer {

    # listen on localhost:8080/8443
    Add-PodeEndpoint -Address 127.0.0.1 -Port 8080 -Protocol Http -Name 'local1'
    Add-PodeEndpoint -Address 127.0.0.2 -Port 8080 -Protocol Http -Name 'local2'
    Add-PodeEndpoint -Address 127.0.0.3 -Port 8080 -Protocol Http -Name 'local3'
    Add-PodeEndpoint -Address 127.0.0.4 -Port 8080 -Protocol Http -Name 'local4'

    # set view engine to pode
    Set-PodeViewEngine -Type Pode

    # GET request for web page - all endpoints
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request for web page -  local2 endpoint
    Add-PodeRoute -Method Get -Path '/' -EndpointName 'local2' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3, 4, 5, 6, 7, 8); }
    }

    # GET request for web page -  local3 and local4 endpoints
    Add-PodeRoute -Method Get -Path '/' -EndpointName 'local3', 'local4' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(2, 4, 6, 8, 10, 12, 14, 16); }
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

    # GET request with parameters
    Add-PodeRoute -Method Get -Path '/:userId/details' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'userId' = $WebEvent.Parameters['userId'] }
    }

}