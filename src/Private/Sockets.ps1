function Initialize-PodeSocketListenerEndpoint
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Sockets', 'WebSockets')]
        [string]
        $Type,

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
    $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout
    $socket.Bind($endpoint)
    $socket.Listen([int]::MaxValue)

    $protocol = (Resolve-PodeValue -Check ($null -eq $Certificate) -TrueValue 'http' -FalseValue 'https')
    if ($Type -ieq 'WebSockets') {
        $protocol = (Resolve-PodeValue -Check ($null -eq $Certificate) -TrueValue 'ws' -FalseValue 'wss')
    }

    return @{
        Type = $Type
        Socket = $socket
        Certificate = $Certificate
        Protocol = $protocol
    }
}

function New-PodeSocketListenerEvent
{
    param(
        [Parameter(Mandatory=$true)]
        $Listener,

        [Parameter()]
        [int]
        $Index = 0
    )

    Lock-PodeObject -Object $PodeContext.Server[$Listener.Type] -Return -ScriptBlock {
        $socketArgs = [System.Net.Sockets.SocketAsyncEventArgs]::new()

        if ($Index -eq 0) {
            $PodeContext.Server[$Listener.Type].MaxConnections++
            $Index = $PodeContext.Server[$Listener.Type].MaxConnections
        }

        $name = (Get-PodeSocketListenerConnectionEventName -Type $Listener.Type -Id $Index)
        Register-ObjectEvent -InputObject $socketArgs -EventName 'Completed' -SourceIdentifier $name -Action {
            Invoke-PodeSocketProcessAccept -Arguments $Event.SourceEventArgs
        } | Out-Null

        return $socketArgs
    }
}

function Start-PodeSocketListener
{
    param(
        [Parameter(Mandatory=$true)]
        [hashtable[]]
        $Listeners
    )

    foreach ($listener in $Listeners) {
        Invoke-PodeSocketAccept -Listener $listener
    }
}

function Close-PodeSocket
{
    param(
        [Parameter()]
        [System.Net.Sockets.Socket]
        $Socket,

        [switch]
        $Shutdown
    )

    if ($null -eq $Socket) {
        return
    }

    if ($Shutdown -and $Socket.Connected) {
        $Socket.Shutdown([System.Net.Sockets.SocketShutdown]::Both)
    }

    Close-PodeDisposable -Disposable $Socket -Close
}

function Close-PodeSocketListener
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Sockets', 'WebSockets')]
        [string]
        $Type
    )

    try {
        # close all open sockets
        if ($Type -ieq 'WebSockets') {
            for ($i = $PodeContext.Server[$Type].Queues.Sockets.Count - 1; $i -ge 0; $i--) {
                Close-PodeSocket -Socket $PodeContext.Server[$Type].Queues.Sockets[$i].Socket -Shutdown
            }

            $PodeContext.Server[$Type].Queues.Sockets.Clear()
        }

        # close all open listeners and unbind events
        for ($i = $PodeContext.Server[$Type].Listeners.Length - 1; $i -ge 0; $i--) {
            Close-PodeSocket -Socket $PodeContext.Server[$Type].Listeners[$i].Socket -Shutdown
        }

        $PodeContext.Server[$Type].Listeners = @()
    }
    catch {
        $_.Exception | Out-PodeHost
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
    if (!$PodeContext.Server[$Listener.Type].Queues.Connections.TryDequeue([ref]$arguments)) {
        $arguments = New-PodeSocketListenerEvent -Listener $Listener
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
    $errors = $Arguments.SocketError

    # reset the socket args
    $Arguments.AcceptSocket = $null
    $Arguments.UserToken = $null

    # start accepting connections again for the listener
    Invoke-PodeSocketAccept -Listener $listener

    # if not success, close this accept socket and accept again
    if (($null -eq $accepted) -or ($errors -ne [System.Net.Sockets.SocketError]::Success)) {
        # close socket
        if ($null -ne $accepted) {
            $accepted.Close()
        }

        # add args back to pool
        $PodeContext.Server[$listener.Type].Queues.Connections.Enqueue($Arguments)
        return
    }

    # add args back to pool
    $PodeContext.Server[$listener.Type].Queues.Connections.Enqueue($Arguments)

    switch ($listener.Type.ToLowerInvariant()) {
        'sockets' {
            Invoke-PodeSocketHandler -Context @{
                Socket = $accepted
                Certificate = $listener.Certificate
                Protocol = $listener.Protocol
            }
        }

        'websockets' {
            Invoke-PodeWebSocketHandler -Context @{
                Socket = $accepted
                Certificate = $listener.Certificate
                Protocol = $listener.Protocol
            }
        }
    }
}

function Get-PodeSocketCertifcateCallback
{
    return ([System.Net.Security.RemoteCertificateValidationCallback]{
        param(
            [Parameter()]
            [object]
            $Sender,

            [Parameter()]
            [X509Certificate]
            $Certificate,

            [Parameter()]
            [System.Security.Cryptography.X509Certificates.X509Chain]
            $Chain,

            [Parameter()]
            [System.Net.Security.SslPolicyErrors]
            $SslPolicyErrors
        )

        # if there is no client cert, just allow it
        if ($null -eq $Certificate) {
            return $true
        }

        # if we have a cert, but there are errors, fail
        return ($SslPolicyErrors -ne [System.Net.Security.SslPolicyErrors]::None)
    })
}

function Get-PodeSocketListenerConnectionEventName
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Sockets', 'WebSockets')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [int]
        $Id
    )

    return "PodeListenerConnection$($Type)Completed_$($Id)"
}

function Get-PodeServerRequestDetails
{
    param(
        [Parameter()]
        [byte[]]
        $Bytes,

        [Parameter(Mandatory=$true)]
        [string]
        $Protocol
    )

    # convert array to string
    $Content = $PodeContext.Server.Encoding.GetString($Bytes, 0, $Bytes.Length)

    # parse the request headers
    $newLine = "`r`n"
    if (!$Content.Contains($newLine)) {
        $newLine = "`n"
    }

    $req_lines = ($Content -isplit $newLine)

    # first line is the request info
    $req_line_info = ($req_lines[0].Trim() -isplit '\s+')
    if ($req_line_info.Length -ne 3) {
        throw [System.Net.Http.HttpRequestException]::new("Invalid request line: $($req_lines[0]) [$($req_line_info.Length)]")
    }

    $req_method = $req_line_info[0].Trim()
    if (@('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE') -inotcontains $req_method) {
        throw [System.Net.Http.HttpRequestException]::new("Invalid request HTTP method: $($req_method)")
    }

    $req_query = $req_line_info[1].Trim()
    $req_proto = $req_line_info[2].Trim()
    if (!$req_proto.StartsWith('HTTP/')) {
        throw [System.Net.Http.HttpRequestException]::new("Invalid request version: $($req_proto)")
    }

    # then, read the headers
    $req_headers = @{}
    $req_body_index = 0
    for ($i = 1; $i -le $req_lines.Length -1; $i++) {
        $line = $req_lines[$i].Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            $req_body_index = $i + 1
            break
        }

        $index = $line.IndexOf(':')
        $name = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1).Trim()
        $req_headers[$name] = $value
    }

    # attempt to get content length, and see if content is chunked
    $contentLength = $req_headers['Content-Length']
    if (![string]::IsNullOrWhiteSpace($contentLength)) {
        $contentLength = 0
    }

    $transferEncoding = $req_headers['Transfer-Encoding']
    if (![string]::IsNullOrWhiteSpace($transferEncoding)) {
        $isChunked = $transferEncoding.Contains('chunked')
    }

    # if chunked, and we have a content-length, fail
    if ($isChunked -and ($contentLength -gt 0)) {
        throw [System.Net.Http.HttpRequestException]::new("Cannot supply a Content-Length and a chunked Transfer-Encoding")
    }

    # then set the request body
    $req_body = ($req_lines[($req_body_index)..($req_lines.Length - 1)] -join $newLine)

    # then set the raw bytes of the request body
    $start = 0

    $lines = $req_lines[0..($req_body_index - 1)]
    foreach ($line in $lines) {
        $start += $line.Length
    }

    $start += ($lines.Length * $newLine.Length)

    # if chunked
    if ($isChunked) {
        $length = -1
        $req_body_bytes = [byte[]]@()

        while ($length -ne 0) {
            # get index of newline char, read start>index bytes as HEX for length
            $index = [array]::IndexOf($Bytes, [byte]$newLine[0], $start)
            $hexBytes = $Bytes[$start..($index - 1)]

            $hex = [string]::Empty
            foreach ($b in $hexBytes) {
                $hex += ([char]$b)
            }

            # if length is 0, end
            $length = [System.Convert]::ToInt32($hex, 16)
            if ($length -eq 0) {
                continue
            }

            # read those X hex bytes from (newline index + newline length)
            $start = $index + $newLine.Length
            $end = $start + $length - 1
            $req_body_bytes += $Bytes[$start..$end]

            # skip bytes for ending newline, and set new start
            $start = ($end + $newLine.Length + 1)
        }
    }

    # else if content-length
    elseif ($contentLength -gt 0) {
        $req_body_bytes = $Bytes[$start..($start + $contentLength)]
    }

    # else read all
    else {
        $req_body_bytes = $Bytes[$start..($Bytes.Length - 1)]
    }

    # build required URI details
    $req_uri = [uri]::new("$($Protocol)://$($req_headers['Host'])$($req_query)")

    # return the details
    return @{
        Method = $req_method
        Query = $req_query
        Protocol = $req_proto
        Headers = $req_headers
        Body = $req_body
        RawBody = $req_body_bytes
        Uri = $req_uri
    }
}