<#
.SYNOPSIS
    PowerShell script to set up a Pode server with various endpoints and error logging.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and provides both HTTP and WebSocket
    endpoints. It also logs errors and other request details to the terminal.

.PARAMETER Port
    The port number on which the server will listen. Default is 8091.

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
Start-PodeServer -Threads 3 {

    # listen
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Ws
    #Add-PodeEndpoint -Address localhost -Port 8090 -Certificate './certs/pode-cert.pfx' -CertificatePassword '1234' -Protocol Https
    #Add-PodeEndpoint -Address localhost -Port 8091 -Certificate './certs/pode-cert.pfx' -CertificatePassword '1234' -Protocol Wss

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Level Error, Debug, Verbose

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Html

    # GET request for web page
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'websockets'
    }

    # SIGNAL route, to return current date
    Add-PodeSignalRoute -Path '/' -ScriptBlock {
        $msg = $SignalEvent.Data.Message

        if ($msg -ieq '[date]') {
            $msg = [datetime]::Now.ToString()
        }

        Send-PodeSignal -Value @{ message = $msg }
    }
}