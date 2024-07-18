<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with session persistent authentication.

.DESCRIPTION
    This script sets up a Pode server listening on port 8085 with session persistent authentication.
    It demonstrates a simple server setup with a view counter. Each visit to the root URL ('http://localhost:8085')
    increments the view counter stored in the session.

.EXAMPLE
    To run the sample: ./Web-Sessions.ps1

    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-Sessions.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
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

# create a server, and start listening on port 8085
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address localhost -Port 8085 -Protocol Http

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend -Generator {
        return [System.IO.Path]::GetRandomFileName()
    }

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $WebEvent.Session.Data.Views++
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @($WebEvent.Session.Data.Views); }
    }

}