function Start-PodeSocketServer
{
    param (
        [switch]
        $Browse
    )

    # setup the callback for sockets
    $PodeContext.Server.Sockets.Ssl.Callback = Get-PodeSocketCertifcateCallback

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
    @(Get-PodeEndpoints -Type Http) | ForEach-Object {
        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = (Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1)
        $_ip = (Get-PodeIPAddress $_ip)

        # add endpoint to list
        $endpoints += @{
            Address = $_ip
            Port = $_.Port
            Certificate = $_.Certificate.Raw
            HostName = $_.Url
        }
    }

    try
    {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $PodeContext.Server.Sockets.Listeners += (Initialize-PodeSocketListenerEndpoint `
                -Type Sockets `
                -Address $_.Address `
                -Port $_.Port `
                -Certificate $_.Certificate)
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeSocketListener -Type Sockets
        throw $_.Exception
    }

    # script for listening out for incoming requests
    $listenScript = {
        param (
            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            Start-PodeSocketListener -Listeners $PodeContext.Server.Sockets.Listeners

            [System.Threading.Thread]::CurrentThread.IsBackground = $true
            [System.Threading.Thread]::CurrentThread.Priority = [System.Threading.ThreadPriority]::Lowest

            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                Wait-PodeTask ([System.Threading.Tasks.Task]::Delay(60))
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads.Web | ForEach-Object {
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
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
        finally {
            Close-PodeSocketListener -Type Sockets
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].HostName
    }

    return @($endpoints.HostName)
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
            try {
                $stream = [System.Net.Security.SslStream]::new($stream, $false, $PodeContext.Server.Sockets.Ssl.Callback)
                $stream.AuthenticateAsServer($Context.Certificate, $true, $PodeContext.Server.Sockets.Ssl.Protocols, $false)
            }
            catch {
                # immediately close http connections
                Close-PodeSocket -Socket $Context.Socket -Shutdown
                return
            }
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
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
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

        Close-PodeSocket -Socket $Context.Socket -Shutdown
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