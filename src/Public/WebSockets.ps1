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
    [CmdletBinding(DefaultParameterSetName='Script')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $Url,

        [Parameter(ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
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

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # check for state/session vars
    $ScriptBlock = Invoke-PodeStateScriptConversion -ScriptBlock $ScriptBlock
    $ScriptBlock = Invoke-PodeSessionScriptConversion -ScriptBlock $ScriptBlock

    # connect
    try {
        $PodeContext.Server.WebSockets.Receiver.ConnectWebSocket($Name, $Url, $ContentType)
    }
    catch {
        throw "Failed to connect to websocket: $($_.Exception.Message)"
    }

    $PodeContext.Server.WebSockets.Connections[$Name] = @{
        Name = $Name
        Url = $Url
        Logic = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = $ArgumentList
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

    if (Test-PodeWebSocket -Name $Name) {
        $PodeContext.Server.WebSockets.Receiver.DisconnectWebSocket($Name)
    }
}

function Remove-PodeWebSocket
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
        throw "No Name for a WebSocket to remove supplied"
    }

    $PodeContext.Server.WebSockets.Receiver.RemoveWebSocket($Name)
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
        throw "No Name for a WebSocket to send message to supplied"
    }

    # do the socket exist?
    if (!(Test-PodeWebSocket -Name $Name)) {
        return
    }

    # get the websocket
    $ws = $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name)

    # parse message
    $Message = ConvertTo-PodeResponseContent -InputObject $Message -ContentType $ws.ContentType

    # send message
    $ws.Send($Message, $Type)
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

    if (Test-PodeWebSocket -Name $Name) {
        $PodeContext.Server.WebSockets.Receiver.GetWebSocket($Name).Reconnect($Url)
    }
}

function Test-PodeWebSocket
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
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