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

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Name 'local1'
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Http -Name 'local2'

    # tell this server to run as a desktop gui
    Show-PodeGui -Title 'Pode Desktop Application' -Icon '../images/icon.png' -EndpointName 'local2' -ResizeMode 'NoResize'

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'gui' -Data @{ 'numbers' = @(1, 2, 3); }
    }

}