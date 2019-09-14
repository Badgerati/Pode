function Initialize-PodeSocketListener
{
    param(
        [Parameter(Mandatory=$true)]
        [ipaddress]
        $Address,

        [Parameter(Mandatory=$true)]
        [int]
        $Port,

        [Parameter()]
        [X509Certificate]
        $Certificate
    )

    $endpoint = [IPEndpoint]::new($Address, $Port)
    $socket = [System.Net.Sockets.Socket]::new($endpoint.AddressFamily, [System.Net.Sockets.SocketType]::Stream, [System.Net.Sockets.ProtocolType]::Tcp)
    $socket.Bind($endpoint)

    $PodeContext.Server.Sockets.Listeners += @{
        Socket = $socket
        Certificate = $Certificate
        Protocol = (Resolve-PodeValue -Check ($null -eq $Certificate) -TrueValue 'http' -FalseValue 'https')
    }
}

function Start-PodeSocketListeners
{
    for ($i = 0; $i -lt $PodeContext.Server.Sockets.Listeners.Length; $i++) {
        $PodeContext.Server.Sockets.Listeners[$i].Socket.Listen([int]::MaxValue)

        $socketArgs = [System.Net.Sockets.SocketAsyncEventArgs]::new()
        $socketArgs.UserToken = $PodeContext.Server.Sockets.Listeners[$i]

        Register-ObjectEvent -InputObject $socketArgs -EventName 'Completed' -SourceIdentifier "PodeListenerSocketCompleted_$($i)" -SupportEvent -Action {
            Invoke-PodeSocketProcessAccept -Arguments $Event.SourceEventArgs
        }

        Invoke-PodeSocketAccept -Arguments $socketArgs
    }
}

function Get-PodeSocketContext
{
    if ($PodeContext.Server.Sockets.Queue.Count -eq 0) {
        return $null
    }

    $context = $PodeContext.Server.Sockets.Queue[0]
    $PodeContext.Server.Sockets.Queue.RemoveAt(0)
    return $context
}

function Close-PodeSocket
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.Sockets.Socket]
        $Socket,

        [switch]
        $Shutdown
    )

    if ($Shutdown -and $Socket.Connected) {
        $Socket.Shutdown([System.Net.Sockets.SocketShutdown]::Both)
    }

    Close-PodeDisposable -Disposable $Socket -Close
}

function Close-PodeSocketListener
{
    # close all open sockets
    for ($i = $PodeContext.Server.Sockets.Queue.Count - 1; $i -ge 0; $i--) {
        Close-PodeSocket -Socket $PodeContext.Server.Sockets.Queue[$i] -Shutdown
    }

    $PodeContext.Server.Sockets.Queue.Clear()

    # close all open listeners
    for ($i = $PodeContext.Server.Sockets.Listeners.Count - 1; $i -ge 0; $i--) {
        Close-PodeSocket -Socket $PodeContext.Server.Sockets.Listeners[$i].Socket -Shutdown
    }

    $PodeContext.Server.Sockets.Listeners = @()
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
        $raised = $Arguments.UserToken.Socket.AcceptAsync($Arguments)
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

    Register-PodeSocketContext -Socket $accepted -Certificate $Arguments.UserToken.Certificate -Protocol $Arguments.UserToken.Protocol
}

function Register-PodeSocketContext
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.Sockets.Socket]
        $Socket,

        [Parameter()]
        [X509Certificate]
        $Certificate,

        [Parameter()]
        [string]
        $Protocol
    )

    if (!$Socket.Connected) {
        Close-PodeSocket -Socket $Socket -Shutdown
    }

    $PodeContext.Server.Sockets.Queue.Add(@{
        Socket = $Socket
        Certificate = $Certificate
        Protocol = $Protocol
    })
}