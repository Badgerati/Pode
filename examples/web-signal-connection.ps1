param($token)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening
Start-PodeServer {

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

    $slack = Invoke-RestMethod -Method Post -Uri 'https://slack.com/api/apps.connections.open' -Headers @{ Authorization = "Bearer $token" }
    Connect-PodeWebSocket -Name 'Slack' -Url $slack.url -ScriptBlock {
        # $WsEvent.Request.Body | out-default

        $msg = $WsEvent.Request.Body | ConvertFrom-Json -AsHashtable
        $msg | out-default
        switch ($msg.type) {
            'disconnect' {
                Disconnect-PodeWebSocket
            }

            'events_api' {
                Send-PodeWebSocket -Message (@{
                    envelope_id = $msg.envelope_id
                } | ConvertTo-Json -Compress) # acknowledge

            }
        }
    }

    # Add-PodeRoute -Method Get -Path '/reset' -ScriptBlock {
    #     Reset-PodeWebSocket -Name 'Example'
    # }
}