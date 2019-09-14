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

    # create the listener on the needed endpoints
    $e = $endpoints[0]
    Initialize-PodeSocketListener -Address $e.Address -Port $e.Port -Certificate $e.Certificate

    # try
    # {
    #     # start listening on defined endpoints
    #     $endpoints | ForEach-Object {
    #         $listener.Prefixes.Add($_.Prefix)
    #     }

    #     $listener.Start()
    # }
    # catch {
    #     $_ | Write-PodeErrorLog

    #     if ($null -ne $Listener) {
    #         if ($Listener.IsListening) {
    #             $Listener.Stop()
    #         }

    #         Close-PodeDisposable -Disposable $Listener -Close
    #     }

    #     throw $_.Exception
    # }

    # script for listening out for incoming requests
    $listenScript = {
        param (
            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            # start the listeners
            Start-PodeSocketListeners

            # create general defaults
            $encoder = New-Object System.Text.ASCIIEncoding

            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # wait for a socket to be connected
                $context = $null
                while ($null -eq $context) {
                    $context = Get-PodeSocketContext
                    if ($null -eq $context) {
                        Start-Sleep -Milliseconds 10
                    }
                }

                try
                {
                    # make the stream (use an ssl stream if we have a cert)
                    $stream = [System.Net.Sockets.NetworkStream]::new($context.Socket, $true)
                    if ($null -ne $context.Certificate) {
                        $stream = [System.Net.Security.SslStream]::new($stream, $false)
                        $stream.AuthenticateAsServer($context.Certificate, $false, $false)
                    }

                    # read the request headers
                    $bytes = New-Object byte[] 8192
                    $bytesRead = (Wait-PodeTask -Task $stream.ReadAsync($bytes, 0, 8192))
                    $req_msg = $encoder.GetString($bytes, 0, $bytesRead)

                    # parse the request headers
                    $req_lines = ($req_msg -isplit [System.Environment]::NewLine)

                    # first line is the request info
                    $req_line_info = ($req_lines[0] -isplit '\s+')
                    $req_method = $req_line_info[0]
                    $req_query = $req_line_info[1]
                    $req_proto = $req_line_info[2]

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
                    $req_body = ($req_lines[($req_body_index)..($req_lines.Length - 1)] -join [System.Environment]::NewLine)

                    # build required URI details
                    $req_uri = [uri]::new("$($context.Protocol)://$($req_headers['Host'])$($req_query)")

                    # reset the event data
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
                            RawBody = $req_body
                            Headers = $req_headers
                            Url = $req_uri
                            UrlReferrer = $req_headers['Referer']
                            UserAgent = $req_headers['User-Agent']
                            HttpMethod = $req_method
                            RemoteEndPoint = $context.Socket.RemoteEndPoint
                            Protocol = $req_proto
                            ProtocolVersion = ($req_proto -isplit '/')[1]
                            ContentEncoding = (Get-PodeEncodingFromContentType -ContentType $req_headers['Content-Type'])
                        }
                        Lockable = $PodeContext.Lockable
                        Path = $req_uri.AbsolutePath
                        Method = $req_method.ToLowerInvariant()
                        Query = [System.Web.HttpUtility]::ParseQueryString($req_uri.Query)
                        Protocol = $context.Protocol
                        Endpoint = $req_headers['Host']
                        ContentType = $req_headers['Content-Type']
                        ErrorType = $null
                        Cookies = $null
                        PendingCookies = @{}
                        Streamed = $false
                    }

                    # set pode in server response header
                    Set-PodeServerHeader

                    # add logging endware for post-request
                    Add-PodeRequestLogEndware -WebEvent $WebEvent

                    #$WebEvent | Out-Default
                    #$WebEvent.Request | Out-Default
                    #$WebEvent.Request.Headers | Out-Default

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

                    # write the response line
                    $res_msg = "$($req_proto) $($WebEvent.Response.StatusCode) $($WebEvent.Response.StatusDescription)$([Environment]::NewLine)"

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

                    $buffer = $encoder.GetBytes($res_msg)
                    Wait-PodeTask -Task $stream.WriteAsync($buffer, 0, $buffer.Length)
                    $stream.Flush()
                }
                catch {
                    Set-PodeResponseStatus -Code 500 -Exception $_
                    $_ | Write-PodeErrorLog
                }

                # invoke endware specifc to the current web event
                $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
                Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

                # close socket stream
                Close-PodeDisposable -Disposable $stream
                $context.Socket.Close()
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
            if ($PodeContext.Server.Sockets.Listeners.Length -gt 0) {
                Close-PodeSocketListener
            }
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript

    # state where we're running
    Write-Host "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads) thread(s)]:" -ForegroundColor Yellow

    $endpoints | ForEach-Object {
        Write-Host "`t- $($_.HostName)" -ForegroundColor Yellow
    }

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].HostName
    }
}