<#
.SYNOPSIS
    PowerShell script to set up a Pode server with various endpoints and error logging.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and provides both HTTP and WebSocket
    endpoints. It demonstrates how to set up WebSockets in Pode, using a manual upgrade path, and logs
    errors and other request details to the terminal.

.PARAMETER Port
    The port number on which the server will listen. Default is 8091.

.EXAMPLE
    To run the sample: ./Web-SignalManual.ps1

    Invoke-RestMethod -Uri http://localhost:8091/ -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-SignalManual.ps1

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
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Ws -NoAutoUpgradeWebSockets

    # log errors to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Levels Error

    # register a connect event
    Register-PodeSignalEvent -Name 'Msg' -Type Connect -EventName 'SignalConnected' -ScriptBlock {
        "Connected: $($TriggeredEvent.Connection.Name) ($($TriggeredEvent.Connection.ClientId))" | Out-Default
    }

    # register a disconnect event
    Register-PodeSignalEvent -Name 'Msg' -Type Disconnect -EventName 'SignalDisconnected' -ScriptBlock {
        "Disconnected: $($TriggeredEvent.Connection.Name) ($($TriggeredEvent.Connection.ClientId))" | Out-Default
    }

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # GET request for web page
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'websockets'
    }

    # GET request for websocket upgrade
    Add-PodeRoute -Method Get -Path '/msg' -ScriptBlock {
        ConvertTo-PodeSignalConnection -Name 'Msg'
    }

    # SIGNAL route, to return current date
    Add-PodeSignalRoute -Path '/msg' -ScriptBlock {
        $msg = $SignalEvent.Data.Message

        if ($msg -ieq '[date]') {
            $msg = [datetime]::Now.ToString()
        }

        Send-PodeSignal -Value @{ message = $msg }
    }
}