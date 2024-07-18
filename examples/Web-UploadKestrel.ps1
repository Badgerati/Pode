<#
.SYNOPSIS
    PowerShell script to set up a Pode server with Kestrel listener and file upload functionality.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port using the Kestrel listener type.
    It serves a web page for file upload and processes file uploads, saving them to the server.

.PARAMETER Port
    The port number on which the server will listen. Default is 8081.

.EXAMPLE
    To run the sample: ./Web-UploadKestrel.ps1

    Invoke-RestMethod -Uri http://localhost:8081/upload -Method Post
    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-UploadKestrel.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
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
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
    Import-Module -Name Pode.Kestrel -ErrorAction Stop
}
catch { throw }


# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 -ListenerType Kestrel {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port $port -Protocol Http

    Set-PodeViewEngine -Type HTML

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'web-upload'
    }

    # POST request to upload a file
    Add-PodeRoute -Method Post -Path '/upload' -ScriptBlock {
        Save-PodeRequestFile -Key 'avatar'
        Move-PodeResponseUrl -Url '/'
    }

}