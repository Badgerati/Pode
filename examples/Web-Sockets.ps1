<#
.SYNOPSIS
    PowerShell script to set up a Pode server with HTTPS and logging.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port with HTTPS protocol using a certificate.
    It includes request logging and provides a sample route to return a JSON response.

.PARAMETER Port
    The port number on which the server will listen. Default is 8081.

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

# create a server, and start listening
Start-PodeServer -Threads 5 {

    # listen
    Add-PodeEndpoint -Address localhost -Port 8081 -Certificate './certs/pode-cert.pfx' -CertificatePassword '1234' -Protocol Https
    # Add-PodeEndpoint -Address localhost -Port 8081 -SelfSigned -Protocol Https

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Kenobi = 'Hello, there'
        }
    }
}