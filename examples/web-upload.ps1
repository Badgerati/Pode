param(
    [int]
    $Port = 8081
)

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
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port $port -Protocol Http

    Set-PodeViewEngine -Type HTML
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'web-upload'
    }

    # POST request to upload a file
    Add-PodeRoute -Method Post -Path '/upload' -ScriptBlock {
        Save-PodeRequestFile -Key 'avatar'
        Move-PodeResponseUrl -Url '/'
    }

    # GET request for web page on "localhost:8081/multi"
    Add-PodeRoute -Method Get -Path '/multi' -ScriptBlock {
        Write-PodeViewResponse -Path 'web-upload-multi'
    }

    # POST request to upload multiple files
    Add-PodeRoute -Method Post -Path '/upload-multi' -ScriptBlock {
        Save-PodeRequestFile -Key 'avatar' -Path 'C:/temp' -FileName 'Ruler.png'
        Move-PodeResponseUrl -Url '/multi'
    }

}