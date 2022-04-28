using namespace Pode

function Set-PodeWebSocketConcurrency
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]
        $Maximum
    )

    # error if <=0
    if ($Maximum -le 0) {
        throw "Maximum concurrent WebSocket threads must be >=1 but got: $($Maximum)"
    }

    # add 1, for the waiting script
    $Maximum++

    # ensure max > min
    $_min = 1
    if ($null -ne $PodeContext.RunspacePools.WebSockets) {
        $_min = $PodeContext.RunspacePools.WebSockets.Pool.GetMinRunspaces()
    }

    if ($_min -gt $Maximum) {
        throw "Maximum concurrent WebSocket threads cannot be less than the minimum of $($_min) but got: $($Maximum)"
    }

    # set the max tasks
    $PodeContext.Threads.WebSockets = $Maximum
    if ($null -ne $PodeContext.RunspacePools.WebSockets) {
        $PodeContext.RunspacePools.WebSockets.Pool.SetMaxRunspaces($Maximum)
    }
}

function Connect-PodeWebSocket
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $Url,

        [Parameter(Mandatory=$true)]
        [scriptblock]
        $ScriptBlock
    )

    # ensure we have a receiver
    New-PodeWebSocketReceiver

    # connect
    $PodeContext.Server.WebSockets.Receiver.ConnectWebSocket($Name, $Url)
    $PodeContext.Server.WebSockets.Connections[$Name] = @{
        Name = $Name
        Url = $Url
        Logic = $ScriptBlock
        #TODO: using-vars
        UsingVariables = $null
        #TODO: args list
        Arguments = $null
    }
}

function Disconnect-PodeWebSocket
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name) -and ($null -ne $WsEvent)) {
        $Name = $WsEvent.Request.WebSocket.Name
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "No Name for a WebSocket to disconnect from supplied"
    }

    $PodeContext.Server.WebSockets.Receiver.DisconnectWebSocket($Name)
    $PodeContext.Server.WebSockets.Connections.Remove($Name)
}

function Send-PodeWebSocket
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Message
    )

    if ([string]::IsNullOrWhiteSpace($Name) -and ($null -ne $WsEvent)) {
        $WsEvent.Request.WebSocket.Send($Message)
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "No Name for a WebSocket to send message to supplied"
    }

    $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name).Send($Message)
}

function Reset-PodeWebSocket
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Url
    )

    if ([string]::IsNullOrWhiteSpace($Name) -and ($null -ne $WsEvent)) {
        $WsEvent.Request.WebSocket.Reconnect($Url)
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "No Name for a WebSocket to reset supplied"
    }

    $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name).Reconnect($Url)
}