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

# include the external function module
Import-PodeModule -Path './modules/external-funcs.psm1'

# create a server, and start listening on port 8081
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # GET request for "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'result' = (Get-Greeting) }
    }

}