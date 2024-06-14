$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Code500Details {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging



    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $result = @{
            something = 'here'
            complex   = 10 / 0
        }
        Write-PodeJsonResponse -Value  $result
    }


}