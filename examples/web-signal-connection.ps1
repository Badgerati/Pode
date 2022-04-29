$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening
Start-PodeServer -EnablePool WebSockets {

    # listen
    Add-PodeEndpoint -Address * -Port 8092 -Protocol Http

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Level Error, Debug, Verbose

    # connect to web socket from web-signal.ps1
    # Connect-PodeWebSocket -Name 'Example' -Url 'ws://localhost:8091' -ScriptBlock {
    #     $WsEvent.Request | out-default
    #     if ($WsEvent.Request.Body -inotlike '*Ex:*') {
    #         Send-PodeWebSocket -Message (@{ message = "Ex: $($WsEvent.Request.Body)" } | ConvertTo-Json -Compress)
    #     }
    # }

    Add-PodeRoute -Method Get -Path '/connect' -ScriptBlock {
        Connect-PodeWebSocket -Name 'Test' -Url 'wss://ws.ifelse.io/' -ScriptBlock {
            $WsEvent.Request | out-default
        }
    }

    Add-PodeTimer -Name 'Test' -Interval 10 -ScriptBlock {
        $rand = Get-Random -Minimum 10 -Maximum 1000
        Send-PodeWebSocket -Name 'Test' -Message "hello $rand"
    }

    # Add-PodeRoute -Method Get -Path '/reset' -ScriptBlock {
    #     Reset-PodeWebSocket -Name 'Example'
    # }
}