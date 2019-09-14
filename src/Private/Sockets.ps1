function Initialize-PodeSocketListener
{
    param(
        [Parameter(Mandatory=$true)]
        [ipaddress]
        $Address,

        [Parameter(Mandatory=$true)]
        [int]
        $Port
    )

    $PodeContext.Server.Sockets = @{
        Socket = $null
        Queue = [System.Collections.Generic.List[System.Net.Sockets.Socket]]::new()
    }

    $endpoint = [IPEndpoint]::new($Address, $Port)
    $PodeContext.Server.Sockets.Socket = [System.Net.Sockets.Socket]::new($endpoint.AddressFamily, [System.Net.Sockets.SocketType]::Stream, [System.Net.Sockets.ProtocolType]::Tcp)
    $PodeContext.Server.Sockets.Socket.Bind($endpoint)
}

function Start-PodeSocketListener
{
    $PodeContext.Server.Sockets.Socket.Listen(501)

    $socketArgs = [System.Net.Sockets.SocketAsyncEventArgs]::new()

    Register-ObjectEvent -InputObject $socketArgs -EventName 'Completed' -SourceIdentifier 'PodeListenerSocketCompleted' -SupportEvent -Action {
        Invoke-PodeSocketProcessAccept -Arguments $Event.SourceEventArgs
    }

    Invoke-PodeSocketAccept -Arguments $socketArgs
}

function Get-PodeSocket
{
    if ($PodeContext.Server.Sockets.Queue.Count -eq 0) {
        return $null
    }

    $socket = $PodeContext.Server.Sockets.Queue[0]
    $PodeContext.Server.Sockets.Queue.RemoveAt(0)
    return $socket
}

function Close-PodeSocket
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.Sockets.Socket]
        $Socket
    )

    if ($Socket.Connected) {
        $Socket.Shutdown([System.Net.Sockets.SocketShutdown]::Both)
    }

    Close-PodeDisposable -Disposable $Socket -Close
}

function Close-PodeSocketListener
{
    for ($i = $PodeContext.Server.Sockets.Queue.Count - 1; $i -ge 0; $i--) {
        Close-PodeSocket -Socket $PodeContext.Server.Sockets.Queue[$i]
    }

    $PodeContext.Server.Sockets.Queue.Clear()
    Close-PodeSocket -Socket $PodeContext.Server.Sockets.Socket
}

function Invoke-PodeSocketAccept
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.Sockets.SocketAsyncEventArgs]
        $Arguments
    )

    $Arguments.AcceptSocket = $null
    $raised = $false

    try {
        $raised = $PodeContext.Server.Sockets.Socket.AcceptAsync($Arguments)
    }
    catch [System.ObjectDisposedException] {
        return
    }

    if (!$raised) {
        Invoke-PodeSocketProcessAccept -Arguments $Arguments
    }
}

function Invoke-PodeSocketProcessAccept
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.Sockets.SocketAsyncEventArgs]
        $Arguments
    )

    $accepted = $null
    if ($Arguments.SocketError -eq [System.Net.Sockets.SocketError]::Success) {
        $accepted = $Arguments.AcceptSocket
    }

    Invoke-PodeSocketAccept -Arguments $Arguments

    if ($null -eq $accepted) {
        return
    }

    Register-PodeSocket -Socket $accepted
}

function Register-PodeSocket
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.Sockets.Socket]
        $Socket
    )

    $PodeContext.Server.Sockets.Queue.Add($Socket)
}