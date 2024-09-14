<#
.SYNOPSIS
    PowerShell script to set up a Pode server with file upload routes.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and provides routes
    for uploading single and multiple files.

.PARAMETER Port
    Specifies the port on which the server will listen. Default is 8081.

.EXAMPLE
    To run the sample: ./Web-Upload.ps1

    Invoke-RestMethod -Uri http://localhost:8081/upload -Method Post
    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get

    Invoke-RestMethod -Uri http://localhost:8081/upload-multi -Method Post
    Invoke-RestMethod -Uri http://localhost:8081/multi -Method Get

#.LINK doesn't work
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-Upload.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [int]
    $Port = 8081
)

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
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