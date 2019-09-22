function Start-PodeSocketServer
{
    param (
        [switch]
        $Browse
    )

    # setup the callback for sockets
    $PodeContext.Server.Sockets.Ssl.Callback = [System.Net.Security.RemoteCertificateValidationCallback]{
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
    }

    # setup any inbuilt middleware
    $inbuilt_middleware = @(
        (Get-PodeAccessMiddleware),
        (Get-PodeLimitMiddleware),
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeCookieMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

    # work out which endpoints to listen on
    $endpoints = @()
    $PodeContext.Server.Endpoints | ForEach-Object {
        # get the protocol
        $_protocol = (Resolve-PodeValue -Check $_.Ssl -TrueValue 'https' -FalseValue 'http')

        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = (Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1)
        $_ip = (Get-PodeIPAddress $_ip)

        # get the port
        $_port = [int]($_.Port)
        if ($_port -eq 0) {
            $_port = (Resolve-PodeValue $_.Ssl -TrueValue 8443 -FalseValue 8080)
        }

        # add endpoint to list
        $endpoints += @{
            Address = $_ip
            Port = $_port
            Certificate = $_.Certificate.Raw
            HostName = "$($_protocol)://$($_.HostName):$($_port)/"
        }
    }

    try
    {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            Initialize-PodeSocketListenerEndpoint -Address $_.Address -Port $_.Port -Certificate $_.Certificate
        }
    }
    catch {
        $_ | Write-PodeErrorLog -CheckInnerException
        Close-PodeSocketListener
        throw $_.Exception
    }

    # script for accepting sockets
    $eventScript = {
        try
        {
            # start the listener events
            Register-PodeSocketListenerEvents
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                Wait-PodeTask ([System.Threading.Tasks.Task]::Delay(0))
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
    }

    Add-PodeRunspace -Type 'Events' -ScriptBlock $eventScript

    # script for listening out for incoming requests
    $listenScript = {
        param (
            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            Start-PodeSocketListener

            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # wait for a socket to be connected
                $context = Get-PodeSocketContext
                Invoke-PodeSocketHandler -Context $context
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'ThreadId' = $_ }
    }

    # script to keep web server listening until cancelled
    $waitScript = {
        try {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
        finally {
            Close-PodeSocketListener
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript

    # state where we're running
    Write-Host 'Note: This server type is experimental' -ForegroundColor Magenta
    Write-Host "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads) thread(s)]:" -ForegroundColor Yellow

    $endpoints | ForEach-Object {
        Write-Host "`t- $($_.HostName)" -ForegroundColor Yellow
    }

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].HostName
    }
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
            Auth = @{}
            Response = @{
                Headers = @{}
                ContentLength64 = 0
                ContentType = $null
                OutputStream = New-Object -TypeName System.IO.MemoryStream
                StatusCode = 200
                StatusDescription = 'OK'
            }
            Request = @{}
            Lockable = $PodeContext.Lockable
            Path = $null
            Method = $null
            Query = $null
            Protocol = $Context.Protocol
            Endpoint = $null
            ContentType = $null
            ErrorType = $null
            Cookies = @{}
            PendingCookies = @{}
            Parameters = $null
            Data = $null
            Files = $null
            Streamed = $true
        }

        # set pode in server response header
        Set-PodeServerHeader

        # make the stream (use an ssl stream if we have a cert)
        $stream = [System.Net.Sockets.NetworkStream]::new($Context.Socket, $true)

        if ($null -ne $Context.Certificate) {
            $stream = [System.Net.Security.SslStream]::new($stream, $false, $PodeContext.Server.Sockets.Ssl.Callback)
            $stream.AuthenticateAsServer($Context.Certificate, $true, $PodeContext.Server.Sockets.Ssl.Protocols, $false)
        }

        # read the request headers - prepare for the dodgest of hacks ever. I apologise profusely.
        try {
            $bytes = New-Object byte[] 0
            $Context.Socket.Receive($bytes) | Out-Null
        }
        catch {
            $err = [System.Net.Http.HttpRequestException]::new()
            $err.Data.Add('PodeStatusCode', 408)
            throw $err
        }

        $bytes = New-Object byte[] $Context.Socket.Available
        (Wait-PodeTask -Task $stream.ReadAsync($bytes, 0, $Context.Socket.Available)) | Out-Null
        $req_info = Get-PodeServerRequestDetails -Bytes $bytes -Protocol $Context.Protocol

        # set the rest of the event data
        $WebEvent.Request = @{
            Body = @{
                Value = $req_info.Body
                Bytes = $req_info.RawBody
            }
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

        $WebEvent.Path = $req_info.Uri.AbsolutePath
        $WebEvent.Method = $req_info.Method.ToLowerInvariant()
        $WebEvent.Endpoint = $req_info.Headers['Host']
        $WebEvent.ContentType = $req_info.Headers['Content-Type']

        $WebEvent.Query = [System.Web.HttpUtility]::ParseQueryString($req_info.Query)
        if ($null -eq $WebEvent.Query) {
            $WebEvent.Query = @{}
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
    catch [System.Net.Http.HttpRequestException] {
        $code = [int]($_.Exception.Data['PodeStatusCode'])
        if ($code -le 0) {
            $code = 400
        }

        Set-PodeResponseStatus -Code $code -Exception $_
    }
    catch {
        $_ | Write-PodeErrorLog -CheckInnerException
        Set-PodeResponseStatus -Code 500 -Exception $_
    }

    try {
        # invoke endware specifc to the current web event
        $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
        Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

        # write the response line
        $protocol = $req_info.Protocol
        if ([string]::IsNullOrWhiteSpace($protocol)) {
            $protocol = 'HTTP/1.1'
        }

        $newLine = "`r`n"
        $res_msg = "$($protocol) $($WebEvent.Response.StatusCode) $($WebEvent.Response.StatusDescription)$($newLine)"

        # set response headers before adding
        Set-PodeServerResponseHeaders -WebEvent $WebEvent

        # write the response headers
        if ($WebEvent.Response.Headers.Count -gt 0) {
            foreach ($key in $WebEvent.Response.Headers.Keys) {
                foreach ($value in $WebEvent.Response.Headers[$key]) {
                    $res_msg += "$($key): $($value)$($newLine)"
                }
            }
        }

        $res_msg += $newLine

        # stream response output
        $buffer = $PodeContext.Server.Encoding.GetBytes($res_msg)
        Wait-PodeTask -Task $stream.WriteAsync($buffer, 0, $buffer.Length)
        $WebEvent.Response.OutputStream.WriteTo($stream)
        $stream.Flush()
    }
    catch [System.Management.Automation.MethodInvocationException] { }
    finally {
        # close socket stream
        if ($null -ne $WebEvent.Response.OutputStream) {
            Close-PodeDisposable -Disposable $WebEvent.Response.OutputStream -Close -CheckNetwork
        }

        if ($null -ne $Context.Socket) {
            $Context.Socket.Shutdown([System.Net.Sockets.SocketShutdown]::Both)
            $Context.Socket.Close()
        }
    }
}

function Set-PodeServerResponseHeaders
{
    param(
        [Parameter(Mandatory=$true)]
        $WebEvent
    )

    # add content-type
    if (![string]::IsNullOrWhiteSpace($WebEvent.Response.ContentType)) {
        Set-PodeHeader -Name 'Content-Type' -Value $WebEvent.Response.ContentType
    }
    else {
        $WebEvent.Response.Headers.Remove('Content-Type')
    }

    # add content-length
    if (($WebEvent.Response.ContentLength64 -eq 0) -and ($WebEvent.Response.OutputStream.Length -gt 0)) {
        $WebEvent.Response.ContentLength64 = $WebEvent.Response.OutputStream.Length
    }

    if ($WebEvent.Response.ContentLength64 -gt 0) {
        Set-PodeHeader -Name 'Content-Length' -Value $WebEvent.Response.ContentLength64
    }
    else {
        $WebEvent.Response.Headers.Remove('Content-Length')
    }

    # add the date of the response
    Set-PodeHeader -Name 'Date' -Value ([DateTime]::UtcNow.ToString("r", [CultureInfo]::InvariantCulture))

    # state to close the connection (no support for keep-alive yet)
    Set-PodeHeader -Name 'Connection' -Value 'close'
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
    $Content = $PodeContext.Server.Encoding.GetString($bytes, 0, $bytes.Length)

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

    # then set the request body
    $req_body = ($req_lines[($req_body_index)..($req_lines.Length - 1)] -join $newLine)
    $req_body_bytes = $bytes[($bytes.Length - $req_body.Length)..($bytes.Length - 1)]

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