function Initialize-PodeSocketListenerEndpoint
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
    $socket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::KeepAlive, $false)
    $socket.Bind($endpoint)
    $socket.Listen([int]::MaxValue)

    $PodeContext.Server.Sockets.Listeners += @{
        Socket = $socket
        Certificate = $Certificate
        Protocol = (Resolve-PodeValue -Check ($null -eq $Certificate) -TrueValue 'http' -FalseValue 'https')
    }
}

function New-PodeSocketListenerEvent
{
    param(
        [Parameter()]
        [int]
        $Index = 0
    )

    Lock-PodeObject -Object $PodeContext.Server.Sockets -Return -ScriptBlock {
        $socketArgs = [System.Net.Sockets.SocketAsyncEventArgs]::new()

        if ($Index -eq 0) {
            $PodeContext.Server.Sockets.MaxConnections++
            $Index = $PodeContext.Server.Sockets.MaxConnections
        }

        Register-ObjectEvent -InputObject $socketArgs -EventName 'Completed' -SourceIdentifier (Get-PodeSocketListenerConnectionEventName -Id $Index) -SupportEvent -Action {
            Invoke-PodeSocketProcessAccept -Arguments $Event.SourceEventArgs
        }

        return $socketArgs
    }
}

function Register-PodeSocketListenerEvents
{
    # populate the connections pool
    foreach ($i in (1..$PodeContext.Server.Sockets.MaxConnections)) {
        $socketArgs = New-PodeSocketListenerEvent -Index $i
        $PodeContext.Server.Sockets.Queues.Connections.Enqueue($socketArgs)
    }
}

function Start-PodeSocketListener
{
    foreach ($listener in $PodeContext.Server.Sockets.Listeners) {
        Invoke-PodeSocketAccept -Listener $listener
    }
}

function Get-PodeSocketContext
{
    Lock-PodeObject -Object $PodeContext.Server.Sockets.Queues.Contexts -Return -ScriptBlock {
        if ($PodeContext.Server.Sockets.Queues.Contexts.Count -eq 0) {
            return $null
        }

        $context = $PodeContext.Server.Sockets.Queues.Contexts[0]
        $PodeContext.Server.Sockets.Queues.Contexts.RemoveAt(0)
        return $context
    }
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
    try {
        # close all open sockets
        for ($i = $PodeContext.Server.Sockets.Queues.Contexts.Count - 1; $i -ge 0; $i--) {
            Close-PodeSocket -Socket $PodeContext.Server.Sockets.Queues.Contexts[$i] -Shutdown
        }

        $PodeContext.Server.Sockets.Queues.Contexts.Clear()

        # close all open listeners and unbind events
        for ($i = $PodeContext.Server.Sockets.Listeners.Length - 1; $i -ge 0; $i--) {
            Unregister-Event -SourceIdentifier (Get-PodeSocketListenerConnectionEventName -Id $i) -Force
            Close-PodeSocket -Socket $PodeContext.Server.Sockets.Listeners[$i].Socket -Shutdown
        }

        $PodeContext.Server.Sockets.Listeners = @()
    }
    catch {
        $_.Exception | Out-Default
    }
}

function Invoke-PodeSocketAccept
{
    param(
        [Parameter(Mandatory=$true)]
        $Listener
    )

    # pop args from queue (or create a new one)
    $arguments = $null
    if (!$PodeContext.Server.Sockets.Queues.Connections.TryDequeue([ref]$arguments)) {
        $arguments = New-PodeSocketListenerEvent
    }

    $arguments.AcceptSocket = $null
    $arguments.UserToken = $Listener
    $raised = $false

    try {
        $raised = $arguments.UserToken.Socket.AcceptAsync($arguments)
    }
    catch [System.ObjectDisposedException] {
        return
    }

    if (!$raised) {
        Invoke-PodeSocketProcessAccept -Arguments $arguments
    }
}

function Invoke-PodeSocketProcessAccept
{
    param(
        [Parameter(Mandatory=$true)]
        [System.Net.Sockets.SocketAsyncEventArgs]
        $Arguments
    )

    # get the socket and listener
    $accepted = $Arguments.AcceptSocket
    $listener = $Arguments.UserToken

    # reset the socket args
    $Arguments.AcceptSocket = $null
    $Arguments.UserToken = $null

    # start accepting connections again for the listener
    Invoke-PodeSocketAccept -Listener $listener

    # if not success, close this accept socket and accept again
    if (($null -eq $accepted) -or ($Arguments.SocketError -ne [System.Net.Sockets.SocketError]::Success) -or ($accepted.Available -le 0)) {
        # close socket
        if ($null -ne $accepted) {
            $accepted.Close()
        }

        # add args back to pool
        $PodeContext.Server.Sockets.Queues.Connections.Enqueue($Arguments)
        return
    }

    # add args back to pool
    $PodeContext.Server.Sockets.Queues.Connections.Enqueue($Arguments)
    Register-PodeSocketContext -Socket $accepted -Certificate $listener.Certificate -Protocol $listener.Protocol
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

    Lock-PodeObject -Object $PodeContext.Server.Sockets.Queues.Contexts -ScriptBlock {
        $PodeContext.Server.Sockets.Queues.Contexts.Add(@{
            Socket = $Socket
            Certificate = $Certificate
            Protocol = $Protocol
        })
    }
}

function Get-PodeSocketListenerConnectionEventName
{
    param (
        [Parameter(Mandatory=$true)]
        [int]
        $Id
    )

    return "PodeListenerConnectionSocketCompleted_$($Id)"
}

function Invoke-PodeSocketHandler
{
    param(
        [Parameter(Mandatory)]
        [hashtable]
        $Context
    )

    try
    {
        # reset with basic event data
        $WebEvent = @{
            OnEnd = @()
            Response = @{
                Headers = @{}
                ContentLength64 = 0
                ContentType = $null
                Body = $null
                StatusCode = 200
                StatusDescription = 'OK'
            }
            Lockable = $PodeContext.Lockable
            ContentType = $null
            ErrorType = $null
            Streamed = $false
        }

        # set pode in server response header
        Set-PodeServerHeader

        # make the stream (use an ssl stream if we have a cert)
        $stream = [System.Net.Sockets.NetworkStream]::new($Context.Socket, $true)
        if ($null -ne $Context.Certificate) {
            $stream = [System.Net.Security.SslStream]::new($stream, $false)
            $stream.AuthenticateAsServer($Context.Certificate, $false, $false)
        }

        # read the request headers
        $bytes = New-Object byte[] $Context.Socket.Available
        $bytesRead = (Wait-PodeTask -Task $stream.ReadAsync($bytes, 0, $Context.Socket.Available))
        $req_msg = $PodeContext.Server.Encoding.GetString($bytes, 0, $bytesRead)
        $req_info = Get-PodeServerRequestDetails -Content $req_msg -Protocol $Context.Protocol

        # set the rest of the event data
        $WebEvent = @{
            OnEnd = @()
            Auth = @{}
            Response = @{
                Headers = @{}
                ContentLength64 = 0
                ContentType = $null
                Body = $null
                StatusCode = 200
                StatusDescription = 'OK'
            }
            Request = @{
                RawBody = $req_info.Body
                Headers = $req_info.Headers
                Url = $req_info.Uri
                UrlReferrer = $req_info.Headers['Referer']
                UserAgent = $req_info.Headers['User-Agent']
                HttpMethod = $req_info.Method
                RemoteEndPoint = $Context.Socket.RemoteEndPoint
                Protocol = $req_info.Protocol
                ProtocolVersion = ($req_info.Protocol -isplit '/')[1]
                ContentEncoding = (Get-PodeEncodingFromContentType -ContentType $req_info.Headers['Content-Type'])
            }
            Lockable = $PodeContext.Lockable
            Path = $req_info.Uri.AbsolutePath
            Method = $req_info.Method.ToLowerInvariant()
            Query = [System.Web.HttpUtility]::ParseQueryString($req_info.Query)
            Protocol = $Context.Protocol
            Endpoint = $req_info.Headers['Host']
            ContentType = $req_info.Headers['Content-Type']
            ErrorType = $null
            Cookies = $null
            PendingCookies = @{}
            Streamed = $false
            Parameters = $null
            Data = $null
            Files = $null
        }

        # add logging endware for post-request
        Add-PodeRequestLogEndware -WebEvent $WebEvent

        # invoke middleware
        if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
            # get the route logic
            $route = Get-PodeRoute -Method $WebEvent.Method -Route $WebEvent.Path -Protocol $WebEvent.Protocol `
                -Endpoint $WebEvent.Endpoint -CheckWildMethod

            # invoke route and custom middleware
            if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $route.Middleware)) {
                if ($null -ne $route.Logic) {
                    Invoke-PodeScriptBlock -ScriptBlock $route.Logic -Arguments (@($WebEvent) + @($route.Arguments)) -Scoped -Splat
                }
            }
        }
    }
    catch [System.OperationCanceledException] {}
    catch {
        $_ | Write-PodeErrorLog
        Set-PodeResponseStatus -Code 500 -Exception $_
    }

    # invoke endware specifc to the current web event
    $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
    Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

    # write the response line
    $protocol = $req_info.Protocol
    if ([string]::IsNullOrWhiteSpace($protocol)) {
        $protocol = 'HTTP/1.1'
    }

    $res_msg = "$($protocol) $($WebEvent.Response.StatusCode) $($WebEvent.Response.StatusDescription)$([Environment]::NewLine)"

    # set response headers before adding
    Set-PodeServerResponseHeaders -WebEvent $WebEvent

    # write the response headers
    if ($WebEvent.Response.Headers.Count -gt 0) {
        foreach ($key in $WebEvent.Response.Headers.Keys) {
            $res_msg += "$($key): $($WebEvent.Response.Headers[$key])$([Environment]::NewLine)"
        }
    }

    $res_msg += [Environment]::NewLine

    # write the response body
    if (![string]::IsNullOrWhiteSpace($WebEvent.Response.Body)) {
        $res_msg += $WebEvent.Response.Body
    }

    $buffer = $PodeContext.Server.Encoding.GetBytes($res_msg)
    Wait-PodeTask -Task $stream.WriteAsync($buffer, 0, $buffer.Length)
    $stream.Flush()

    # close socket stream
    $Context.Socket.Shutdown([System.Net.Sockets.SocketShutdown]::Both)
    $Context.Socket.Close()
}