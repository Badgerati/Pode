param (
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port $port -Protocol Http

    Set-PodeViewEngine -Type HTML

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'web-upload'
    }

    # POST request to upload a file
    Add-PodeRoute -Method Post -Path '/upload' -ScriptBlock {
        Save-PodeRequestFile -Key 'avatar'
        Move-PodeResponseUrl -Url '/'
    }

}