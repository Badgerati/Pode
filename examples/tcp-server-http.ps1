<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode TCP server with multiple endpoints and error logging.

.DESCRIPTION
    This script sets up a Pode TCP server that listens on port 8081, logs errors to the terminal, and handles incoming HTTP requests. The server provides a catch-all handler for HTTP requests and returns a basic HTML response.

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

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # add two endpoints
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Tcp

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # catch-all for http
    Add-PodeVerb -Verb '*' -Close -ScriptBlock {
        $TcpEvent.Request.Body | Out-Default
        Write-PodeTcpClient -Message "HTTP/1.1 200 `r`nConnection: close`r`n`r`n<b>Hello, there</b>"
        # navigate to "http://localhost:8081"
    }

}