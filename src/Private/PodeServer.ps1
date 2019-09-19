function Start-PodeSocketServer
{
    param (
        [switch]
        $Browse
    )

    # setup any inbuilt middleware
    $inbuilt_middleware = @(
        (Get-PodeAccessMiddleware),
        (Get-PodeLimitMiddleware),
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeQueryMiddleware),
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
        $_ | Write-PodeErrorLog
        Close-PodeSocketListener
        throw $_.Exception
    }

    # script for accepting sockets
    $eventScript = {
        try
        {
            # start the listener events
            Register-PodeSocketListenerEvents

            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                Wait-PodeTask ([System.Threading.Tasks.Task]::Delay(10))
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $eventScript

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
                $context = $null
                while ($null -eq $context) {
                    $context = Get-PodeSocketContext
                    if ($null -eq $context) {
                        Wait-PodeTask ([System.Threading.Tasks.Task]::Delay(10))
                    }
                }

                $ThreadId | Out-Default
                Invoke-PodeSocketHandler -Context $context
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
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
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
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
    catch [System.Net.Http.HttpRequestException] {
        Set-PodeResponseStatus -Code 400 -Exception $_
    }
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
    if ($WebEvent.Response.ContentLength64 -gt 0) {
        Set-PodeHeader -Name 'Content-Length' -Value $WebEvent.Response.ContentLength64
    }
    else {
        $WebEvent.Response.Headers.Remove('Content-Length')
    }

    # add the date of the response
    Set-PodeHeader -Name 'Date' -Value ([DateTime]::UtcNow.ToString("r", [CultureInfo]::InvariantCulture))

    # state to close the connection (no support for keep-alive yet)
    Set-PodeHeader -Name 'Connection' -Value 'Close'
}

function Get-PodeServerRequestDetails
{
    param(
        [Parameter()]
        [string]
        $Content,

        [Parameter(Mandatory=$true)]
        [string]
        $Protocol
    )

    # parse the request headers
    $newLine = "`r`n"
    if ($Content.Contains($newLine)) {
        $newLine = "`n"
    }

    $req_lines = ($Content -isplit $newLine)
    $req_lines = @(foreach ($line in $req_lines) {
        $line.Trim()
    })

    # first line is the request info
    $req_line_info = ($req_lines[0] -isplit '\s+')
    if ($req_line_info.Length -ne 3) {
        throw [System.Net.Http.HttpRequestException]::new("Invalid request line: $($req_lines[0]) [$($req_line_info.Length)]")
    }

    $req_method = $req_line_info[0]
    if (@('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE') -inotcontains $req_method) {
        throw [System.Net.Http.HttpRequestException]::new("Invalid request HTTP method: $($req_method)")
    }

    $req_query = $req_line_info[1]
    $req_proto = $req_line_info[2]
    if (!$req_proto.StartsWith('HTTP/')) {
        throw [System.Net.Http.HttpRequestException]::new("Invalid request version: $($req_proto)")
    }

    # then, read the headers
    $req_headers = @{}
    $req_body_index = 0
    for ($i = 1; $i -le $req_lines.Length -1; $i++) {
        $line = $req_lines[$i]
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

    # build required URI details
    $req_uri = [uri]::new("$($Protocol)://$($req_headers['Host'])$($req_query)")

    # return the details
    return @{
        Method = $req_method
        Query = $req_query
        Protocol = $req_proto
        Headers = $req_headers
        Body = $req_body
        Uri = $req_uri
    }
}