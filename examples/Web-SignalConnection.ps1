<#
.SYNOPSIS
    Sample script to set up a Pode server with WebSocket support, listening on localhost.

.DESCRIPTION
    This script initializes a Pode server that listens on localhost:8081 with WebSocket support.
    It includes logging to the terminal and several routes and timers for WebSocket connections.
    The server can connect to a WebSocket from an external script and respond to messages.

.PARAMETER ScriptPath
    Path of the script being executed.

.PARAMETER podePath
    Path of the Pode module.

.EXAMPLE
    Run this script to start the Pode server and navigate to 'http://localhost:8081' in your browser.
    The server supports WebSocket connections and includes routes for connecting and resetting
    WebSocket connections.

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
Start-PodeServer -EnablePool WebSockets {

    # listen
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Level Error, Debug, Verbose

    # connect to web socket from web-signal.ps1
    Connect-PodeWebSocket -Name 'Example' -Url 'ws://localhost:8091' -ScriptBlock {
        $WsEvent.Data | Out-Default
        if ($WsEvent.Data.message -inotlike '*Ex:*') {
            Send-PodeWebSocket -Message @{ message = "Ex: $($WsEvent.Data.message)" }
        }
    }

    Add-PodeRoute -Method Get -Path '/connect' -ScriptBlock {
        Connect-PodeWebSocket -Name 'Test' -Url 'wss://ws.ifelse.io/' -ScriptBlock {
            $WsEvent.Request | out-default
        }
    }

    Add-PodeTimer -Name 'Test' -Interval 10 -ScriptBlock {
        $rand = Get-Random -Minimum 10 -Maximum 1000
        Send-PodeWebSocket -Name 'Test' -Message "hello $rand"
    }

    Add-PodeRoute -Method Get -Path '/reset' -ScriptBlock {
        Reset-PodeWebSocket -Name 'Example'
    }
}