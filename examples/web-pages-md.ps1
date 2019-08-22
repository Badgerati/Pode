$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8090
Start-PodeServer -Threads 2 {

    # listen on localhost:8090
    Add-PodeEndpoint -Address localhost:8090 -Protocol Http

    # set view engine
    Set-PodeViewEngine -Type Markdown

    # GET request for web page on "localhost:8090/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
    }

}