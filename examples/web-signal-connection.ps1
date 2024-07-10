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
    Add-PodeEndpoint -Address localhost -Port 8092 -Protocol Http

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Level Error, Debug, Verbose

    # connect to web socket from web-signal.ps1
    Connect-PodeWebSocket -Name 'Example' -Url 'ws://localhost:8091' -ScriptBlock {
        $WsEvent.Data | Out-Default
        if ($WsEvent.Data.message -inotlike '*Ex:*') {
            Send-PodeWebSocket -Message @{ message = "Ex: $($WsEvent.Data.message)" }
        }
    }

    # Add-PodeRoute -Method Get -Path '/connect' -ScriptBlock {
    #     Connect-PodeWebSocket -Name 'Test' -Url 'wss://ws.ifelse.io/' -ScriptBlock {
    #         $WsEvent.Request | out-default
    #     }
    # }

    # Add-PodeTimer -Name 'Test' -Interval 10 -ScriptBlock {
    #     $rand = Get-Random -Minimum 10 -Maximum 1000
    #     Send-PodeWebSocket -Name 'Test' -Message "hello $rand"
    # }

    # Add-PodeRoute -Method Get -Path '/reset' -ScriptBlock {
    #     Reset-PodeWebSocket -Name 'Example'
    # }
}