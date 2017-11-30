if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

Server -Port 8085 {
    # GET request for web page on "localhost:8085/"
    Add-PodeRoute 'get' '/' {
        param($res, $req, $data)
        Write-HtmlFromFile 'simple.html' $res
    }

    # starts the server listening on port 8085
    Start-PodeServer
}