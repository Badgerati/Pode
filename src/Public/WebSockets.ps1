using namespace Pode

<#
.SYNOPSIS
Set the maximum number of concurrent WebSocket connection threads.

.DESCRIPTION
Set the maximum number of concurrent WebSocket connection threads.

.PARAMETER Maximum
The Maximum number of threads available to process WebSocket connection messages received.

.EXAMPLE
Set-PodeWebSocketConcurrency -Maximum 5
#>
function Set-PodeWebSocketConcurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
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

<#
.SYNOPSIS
Connect to an external WebSocket.

.DESCRIPTION
Connect to an external WebSocket.

.PARAMETER Name
The Name of the WebSocket connection.

.PARAMETER Url
The URL of the WebSocket. Should start with either ws:// or wss://.

.PARAMETER ScriptBlock
The ScriptBlock to invoke for processing received messages from the WebSocket. The ScriptBlock will have access to a $WsEvent variable with details of the received message.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the WebSocket's logic.

.PARAMETER ContentType
An optional ContentType for parsing/converting received/sent messages. (default: application/json)

.PARAMETER ArgumentList
AN optional array of extra arguments, that will be passed to the ScriptBlock.

.EXAMPLE
Connect-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket' -ScriptBlock { ... }

.EXAMPLE
Connect-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket' -ScriptBlock { param($arg1, $arg2) ... } -ArgumentList 'arg1', 'arg2'

.EXAMPLE
Connect-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket' -FilePath './some/path/file.ps1'

.EXAMPLE
Connect-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket' -ScriptBlock { ... } -ContentType 'text/xml'
#>
function Connect-PodeWebSocket {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Url,

        [Parameter(ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [string]
        $ContentType = 'application/json',

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure we have a receiver
    New-PodeWebSocketReceiver

    # fail if already exists
    if (Test-PodeWebSocket -Name $Name) {
        throw "Already connected to websocket with name '$($Name)'"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # connect
    try {
        $PodeContext.Server.WebSockets.Receiver.ConnectWebSocket($Name, $Url, $ContentType)
    }
    catch {
        throw "Failed to connect to websocket: $($_.Exception.Message)"
    }

    $PodeContext.Server.WebSockets.Connections[$Name] = @{
        Name           = $Name
        Url            = $Url
        Logic          = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = $ArgumentList
    }
}

<#
.SYNOPSIS
Disconnect from a WebSocket connection.

.DESCRIPTION
Disconnect from a WebSocket connection. These connections can be reconnected later using Reset-PodeWebSocket

.PARAMETER Name
The Name of the WebSocket connection (optional if in the scope where $WsEvent is available).

.EXAMPLE
Disconnect-PodeWebSocket -Name 'Example'
#>
function Disconnect-PodeWebSocket {
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
        throw 'No Name for a WebSocket to disconnect from supplied'
    }

    if (Test-PodeWebSocket -Name $Name) {
        $PodeContext.Server.WebSockets.Receiver.DisconnectWebSocket($Name)
    }
}

<#
.SYNOPSIS
Remove a WebSocket connection.

.DESCRIPTION
Disconnects and then removes a WebSocket connection.

.PARAMETER Name
The Name of the WebSocket connection (optional if in the scope where $WsEvent is available).

.EXAMPLE
Remove-PodeWebSocket -Name 'Example'
#>
function Remove-PodeWebSocket {
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
        throw 'No Name for a WebSocket to remove supplied'
    }

    $PodeContext.Server.WebSockets.Receiver.RemoveWebSocket($Name)
    $PodeContext.Server.WebSockets.Connections.Remove($Name)
}

<#
.SYNOPSIS
Send a message back to a WebSocket connection.

.DESCRIPTION
Send a message back to a WebSocket connection.

.PARAMETER Name
The Name of the WebSocket connection (optional if in the scope where $WsEvent is available).

.PARAMETER Message
The Message to send. Can either be a raw string, hashtable, or psobject. Non-strings will be parsed to JSON, or the WebSocket's ContentType.

.PARAMETER Depth
An optional Depth to parse any JSON or XML messages. (default: 10)

.PARAMETER Type
An optional message Type. (default: Text)

.EXAMPLE
Send-PodeWebSocket -Name 'Example' -Message @{ message = 'Hello, there' }
#>
function Send-PodeWebSocket {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        $Message,

        [Parameter()]
        [int]
        $Depth = 10,

        [Parameter()]
        [ValidateSet('Text', 'Binary')]
        [string]
        $Type = 'Text'
    )

    # get ws name
    if ([string]::IsNullOrWhiteSpace($Name) -and ($null -ne $WsEvent)) {
        $Name = $WsEvent.Request.WebSocket.Name
    }

    # do we have a name?
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw 'No Name for a WebSocket to send message to supplied'
    }

    # do the socket exist?
    if (!(Test-PodeWebSocket -Name $Name)) {
        return
    }

    # get the websocket
    $ws = $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name)

    # parse message
    $Message = ConvertTo-PodeResponseContent -InputObject $Message -ContentType $ws.ContentType -Depth $Depth

    # send message
    $ws.Send($Message, $Type)
}

<#
.SYNOPSIS
Reset an existing WebSocket connection.

.DESCRIPTION
Reset an existing WebSocket connection, either using it's current URL or a new one.

.PARAMETER Name
The Name of the WebSocket connection (optional if in the scope where $WsEvent is available).

.PARAMETER Url
An optional new URL to reset the connection to. If not supplied, the connection's original URL will be used.

.EXAMPLE
Reset-PodeWebSocket -Name 'Example'

.EXAMPLE
Reset-PodeWebSocket -Name 'Example' -Url 'ws://example.com/some/socket'
#>
function Reset-PodeWebSocket {
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
        throw 'No Name for a WebSocket to reset supplied'
    }

    if (Test-PodeWebSocket -Name $Name) {
        $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name).Reconnect($Url)
    }
}

<#
.SYNOPSIS
Test whether an WebSocket connection exists.

.DESCRIPTION
Test whether an WebSocket connection exists for the given Name.

.PARAMETER Name
The Name of the WebSocket connection.

.EXAMPLE
Test-PodeWebSocket -Name 'Example'
#>
function Test-PodeWebSocket {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $found = ($null -ne $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name))
    if ($found) {
        return $true
    }

    if ($PodeContext.Server.WebSockets.Connections.ContainsKey($Name)) {
        Remove-PodeWebSocket -Name $Name
    }

    return $false
}