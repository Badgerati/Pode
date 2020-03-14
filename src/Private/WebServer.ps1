function Start-PodeWebServer
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
        (Get-PodeQueryMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

    # work out which endpoints to listen on
    $endpoints = @()
    @(Get-PodeEndpoints -Type Http) | ForEach-Object {
        # get the ip address
        $_ip = "$($_.Address)"
        if ($_ip -ieq '0.0.0.0') {
            $_ip = '*'
        }

        # if this endpoint is https, generate a self-signed cert or bind an existing one
        if ($_.Ssl) {
            $addr = (Resolve-PodeValue -Check $_.IsIPAddress -TrueValue $_.Address -FalseValue $_.HostName)
            $selfSigned = $_.Certificate.SelfSigned
            Set-PodeCertificate -Address $addr -Port $_.Port -Certificate $_.Certificate.Name -Thumbprint $_.Certificate.Thumbprint -SelfSigned:$selfSigned
        }

        # add endpoint to list
        $endpoints += @{
            Prefix = "$($_.Protocol)://$($_ip):$($_.Port)/"
            HostName = $_.Url
        }
    }

    # create the listener on http and/or https
    $listener = New-Object System.Net.HttpListener

    try
    {
        # start listening on defined endpoints
        $endpoints | ForEach-Object {
            $listener.Prefixes.Add($_.Prefix)
        }

        $listener.Start()
    }
    catch {
        $_ | Write-PodeErrorLog

        if ($null -ne $Listener) {
            if ($Listener.IsListening) {
                $Listener.Stop()
            }

            Close-PodeDisposable -Disposable $Listener -Close
        }

        throw $_.Exception
    }

    # script for listening out for incoming requests
    $listenScript = {
        param (
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener,

            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get request and response
                $context = (Wait-PodeTask -Task $Listener.GetContextAsync())

                try
                {
                    $request = $context.Request
                    $response = $context.Response

                    # reset event data
                    $WebEvent = @{
                        OnEnd = @()
                        Auth = @{}
                        Response = $response
                        Request = $request
                        Lockable = $PodeContext.Lockable
                        Path = ($request.RawUrl -isplit "\?")[0]
                        Method = $request.HttpMethod.ToLowerInvariant()
                        Protocol = $request.Url.Scheme
                        Endpoint = $request.Url.Authority
                        ContentType = $request.ContentType
                        ErrorType = $null
                        Cookies = $request.Cookies
                        PendingCookies = @{}
                        Streamed = $true
                        Route = $null
                        Timestamp = [datetime]::UtcNow
                        TransferEncoding = $null
                        AcceptEncoding = $null
                    }

                    $WebEvent.TransferEncoding = (Get-PodeTransferEncoding -TransferEncoding (Get-PodeHeader -Name 'X-Transfer-Encoding') -ThrowError)
                    $WebEvent.AcceptEncoding = (Get-PodeAcceptEncoding -AcceptEncoding (Get-PodeHeader -Name 'Accept-Encoding') -ThrowError)

                    # set pode in server response header
                    Set-PodeServerHeader -AllowEmptyType

                    # add logging endware for post-request
                    Add-PodeRequestLogEndware -WebEvent $WebEvent

                    # invoke middleware
                    if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
                        # invoke route and custom middleware
                        if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $WebEvent.Route.Middleware)) {
                            if ($null -ne $WebEvent.Route.Logic) {
                                Invoke-PodeScriptBlock -ScriptBlock $WebEvent.Route.Logic -Arguments (@($WebEvent) + @($WebEvent.Route.Arguments)) -Scoped -Splat
                            }
                        }
                    }
                }
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
                finally {
                    Update-PodeServerRequestMetrics -WebEvent $WebEvent
                }

                # invoke endware specifc to the current web event
                $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
                Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

                # close response stream (check if exists, as closing the writer closes this stream on unix)
                if ($response.OutputStream) {
                    Close-PodeDisposable -Disposable $response.OutputStream -Close -CheckNetwork
                }
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads.Web | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep web server listening until cancelled
    $waitScript = {
        param (
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener
        )

        try
        {
            while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
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
            if ($null -ne $Listener) {
                if ($Listener.IsListening) {
                    $Listener.Stop()
                }

                Close-PodeDisposable -Disposable $Listener -Close
            }
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].HostName
    }

    return @($endpoints.HostName)
}