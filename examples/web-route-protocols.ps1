try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8080 and 8443
Start-PodeServer {

    # listen on localhost:8080/8443
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http -Name Endpoint1
    Add-PodeEndpoint -Address localhost -Port 8443 -Protocol Https -Name Endpoint2 -SelfSigned

    # set view engine to pode
    Set-PodeViewEngine -Type Pode

    # GET request for web page
    Add-PodeRoute -Method Get -Path '/' -EndpointName Endpoint2 -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

    # GET request with parameters
    Add-PodeRoute -Method Get -Path '/:userId/details' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'userId' = $WebEvent.Parameters['userId'] }
    }

    # ALL requests for http only to redirect to https
    Add-PodeRoute -Method * -Path * -EndpointName Endpoint1 -ScriptBlock {
        Move-PodeResponseUrl -Protocol Https -Port 8443
    }

}