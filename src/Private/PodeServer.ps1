using namespace Pode

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
        (Get-PodeQueryMiddleware),
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
            Hostname = $_.HostName
            IsIPAddress = $_.IsIPAddress
            Port = $_.Port
            Certificate = $_.Certificate.Raw
            AllowClientCertificate = $_.Certificate.AllowClientCertificate
            Url = $_.Url
        }
    }

    # create the listener
    $listener = (. ([scriptblock]::Create("New-Pode$($PodeContext.Server.ListenerType)Listener -CancellationToken `$PodeContext.Tokens.Cancellation.Token -Type 'Http'")))
    $listener.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)

    try
    {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $socket = (. ([scriptblock]::Create("New-Pode$($PodeContext.Server.ListenerType)ListenerSocket -Address `$_.Address -Port `$_.Port -SslProtocols `$PodeContext.Server.Sockets.Ssl.Protocols -Certificate `$_.Certificate -AllowClientCertificate `$_.AllowClientCertificate")))
            $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout

            if (!$_.IsIPAddress) {
                $socket.Hostnames.Add($_.HostName)
            }

            $listener.Add($socket)
        }

        $listener.Start()
        $PodeContext.Server.Sockets.Listener = $listener
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $listener
        throw $_.Exception
    }

    # script for listening out for incoming requests
    $listenScript = {
        param(
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
                $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

                try
                {
                    try
                    {
                        $Request = $context.Request
                        $Response = $context.Response

                        # reset with basic event data
                        $WebEvent = @{
                            OnEnd = @()
                            Auth = @{}
                            Response = $Response
                            Request = $Request
                            Lockable = $PodeContext.Lockable
                            Path = [System.Web.HttpUtility]::UrlDecode($Request.Url.AbsolutePath)
                            Method = $Request.HttpMethod.ToLowerInvariant()
                            Query = $null
                            Endpoint = @{
                                Protocol = $Request.Url.Scheme
                                Address = $Request.Host
                                Name = $null
                            }
                            ContentType = $Request.ContentType
                            ErrorType = $null
                            Cookies = @{}
                            PendingCookies = @{}
                            Parameters = $null
                            Data = $null
                            Files = $null
                            Streamed = $true
                            Route = $null
                            StaticContent = $null
                            Timestamp = [datetime]::UtcNow
                            TransferEncoding = $null
                            AcceptEncoding = $null
                        }

                        # accept/transfer encoding
                        $WebEvent.TransferEncoding = (Get-PodeTransferEncoding -TransferEncoding (Get-PodeHeader -Name 'Transfer-Encoding') -ThrowError)
                        $WebEvent.AcceptEncoding = (Get-PodeAcceptEncoding -AcceptEncoding (Get-PodeHeader -Name 'Accept-Encoding') -ThrowError)

                        # endpoint name
                        $WebEvent.Endpoint.Name = (Find-PodeEndpointName -Protocol $WebEvent.Endpoint.Protocol -Address $WebEvent.Endpoint.Address)

                        # add logging endware for post-request
                        Add-PodeRequestLogEndware -WebEvent $WebEvent

                        # stop now if the request has an error
                        if ($null -ne $Request.Error) {
                            $Request.Error | Write-PodeErrorLog -CheckInnerException
                            throw $Request.Error
                        }

                        # invoke global and route middleware
                        if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
                            if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $WebEvent.Route.Middleware))
                            {
                                # invoke the route
                                if ($null -ne $WebEvent.StaticContent) {
                                    if ($WebEvent.StaticContent.IsDownload) {
                                        Set-PodeResponseAttachment -Path $WebEvent.Path
                                    }
                                    else {
                                        $cachable = $WebEvent.StaticContent.IsCachable
                                        Write-PodeFileResponse -Path $WebEvent.StaticContent.Source -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge -Cache:$cachable
                                    }
                                }
                                elseif ($null -ne $WebEvent.Route.Logic) {
                                    $_args = @($WebEvent.Route.Arguments)
                                    if ($null -ne $WebEvent.Route.UsingVariables) {
                                        $_args = @($WebEvent.Route.UsingVariables.Value) + $_args
                                    }

                                    Invoke-PodeScriptBlock -ScriptBlock $WebEvent.Route.Logic -Arguments $_args -Scoped -Splat
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
                    finally {
                        Update-PodeServerRequestMetrics -WebEvent $WebEvent
                    }

                    # invoke endware specifc to the current web event
                    $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
                    Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware
                }
                finally {
                    Close-PodeDisposable -Disposable $context
                }
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
    1..$PodeContext.Threads.General | ForEach-Object {
        Add-PodeRunspace -Type Web -ScriptBlock $listenScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep web server listening until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener
        )

        try {
            while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
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
            Close-PodeDisposable -Disposable $Listener
        }
    }

    Add-PodeRunspace -Type Web -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].Url
    }

    return @($endpoints.Url)
}

function New-PodeListener
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Threading.CancellationToken]
        $CancellationToken,

        [Parameter(Mandatory=$true)]
        [PodeListenerType]
        $Type
    )

    return [PodeListener]::new($CancellationToken, $Type)
}

function New-PodeListenerSocket
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ipaddress]
        $Address,

        [Parameter(Mandatory=$true)]
        [int]
        $Port,

        [Parameter()]
        [System.Security.Authentication.SslProtocols]
        $SslProtocols,

        [Parameter()]
        [X509Certificate]
        $Certificate,

        [Parameter()]
        [bool]
        $AllowClientCertificate
    )

    return [PodeSocket]::new($Address, $Port, $SslProtocols, $Certificate, $AllowClientCertificate)
}