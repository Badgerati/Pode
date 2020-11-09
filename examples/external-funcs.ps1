$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# include the external function module
Import-PodeModule -Path './modules/external-funcs.psm1'

# create a server, and start listening on port 8085
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http

    # GET request for "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'result' = (Get-Greeting) }
    }

}