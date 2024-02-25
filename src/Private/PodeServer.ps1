using namespace Pode

function Start-PodeWebServer {
    param(
        [switch]
        $Browse
    )

    # setup any inbuilt middleware
    $inbuilt_middleware = @(
        (Get-PodeSecurityMiddleware),
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
    $endpointsMap = @{}

    @(Get-PodeEndpoints -Type Http, Ws) | ForEach-Object {
        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = (Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1)
        $_ip = (Get-PodeIPAddress $_ip)

        # the endpoint
        $_endpoint = @{
            Key                    = "$($_ip):$($_.Port)"
            Address                = $_ip
            Hostname               = $_.HostName
            IsIPAddress            = $_.IsIPAddress
            Port                   = $_.Port
            Certificate            = $_.Certificate.Raw
            AllowClientCertificate = $_.Certificate.AllowClientCertificate
            Url                    = $_.Url
            Protocol               = $_.Protocol
            Type                   = $_.Type
            Pool                   = $_.Runspace.PoolName
            SslProtocols           = $_.Ssl.Protocols
        }

        # add endpoint to list
        $endpoints += $_endpoint

        # add to map
        if (!$endpointsMap.ContainsKey($_endpoint.Key)) {
            $endpointsMap[$_endpoint.Key] = @{ Type = $_.Type }
        }
        else {
            if ($endpointsMap[$_endpoint.Key].Type -ine $_.Type) {
                $endpointsMap[$_endpoint.Key].Type = 'HttpAndWs'
            }
        }
    }

    # create the listener
    $listener = (. ([scriptblock]::Create("New-Pode$($PodeContext.Server.ListenerType)Listener -CancellationToken `$PodeContext.Tokens.Cancellation.Token")))
    $listener.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)
    $listener.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevels)
    $listener.RequestTimeout = $PodeContext.Server.Request.Timeout
    $listener.RequestBodySize = $PodeContext.Server.Request.BodySize
    $listener.ShowServerDetails = [bool]$PodeContext.Server.Security.ServerDetails

    try {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $socket = (. ([scriptblock]::Create("New-Pode$($PodeContext.Server.ListenerType)ListenerSocket -Address `$_.Address -Port `$_.Port -SslProtocols `$_.SslProtocols -Type `$endpointsMap[`$_.Key].Type -Certificate `$_.Certificate -AllowClientCertificate `$_.AllowClientCertificate")))
            $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout

            if (!$_.IsIPAddress) {
                $socket.Hostnames.Add($_.HostName)
            }

            $listener.Add($socket)
        }

        $listener.Start()
        $PodeContext.Listeners += $listener
        $PodeContext.Server.Signals.Enabled = $true
        $PodeContext.Server.Signals.Listener = $listener
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $listener
        throw $_.Exception
    }

    # only if HTTP endpoint
    if (Test-PodeEndpoints -Type Http) {
        # script for listening out for incoming requests
        $listenScript = {
            param(
                [Parameter(Mandatory = $true)]
                $Listener,

                [Parameter(Mandatory = $true)]
                [int]
                $ThreadId
            )

            try {
                while ($Listener.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                    # get request and response
                    $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

                    try {
                        try {
                            $Request = $context.Request
                            $Response = $context.Response

                            # reset with basic event data
                            $WebEvent = @{
                                OnEnd            = @()
                                Auth             = @{}
                                Response         = $Response
                                Request          = $Request
                                Lockable         = $PodeContext.Threading.Lockables.Global
                                Path             = [System.Web.HttpUtility]::UrlDecode($Request.Url.AbsolutePath)
                                Method           = $Request.HttpMethod.ToLowerInvariant()
                                Query            = $null
                                Endpoint         = @{
                                    Protocol = $Request.Url.Scheme
                                    Address  = $Request.Host
                                    Name     = $null
                                }
                                ContentType      = $Request.ContentType
                                ErrorType        = $null
                                Cookies          = @{}
                                PendingCookies   = @{}
                                Parameters       = $null
                                Data             = $null
                                Files            = $null
                                Streamed         = $true
                                Route            = $null
                                StaticContent    = $null
                                Timestamp        = [datetime]::UtcNow
                                TransferEncoding = $null
                                AcceptEncoding   = $null
                                Ranges           = $null
                            }

                            # if iis, and we have an app path, alter it
                            if ($PodeContext.Server.IsIIS -and $PodeContext.Server.IIS.Path.IsNonRoot) {
                                $WebEvent.Path = ($WebEvent.Path -ireplace $PodeContext.Server.IIS.Path.Pattern, '')
                                if ([string]::IsNullOrEmpty($WebEvent.Path)) {
                                    $WebEvent.Path = '/'
                                }
                            }

                            # accept/transfer encoding
                            $WebEvent.TransferEncoding = (Get-PodeTransferEncoding -TransferEncoding (Get-PodeHeader -Name 'Transfer-Encoding') -ThrowError)
                            $WebEvent.AcceptEncoding = (Get-PodeAcceptEncoding -AcceptEncoding (Get-PodeHeader -Name 'Accept-Encoding') -ThrowError)
                            $WebEvent.Ranges = (Get-PodeRanges -Range (Get-PodeHeader -Name 'Range') -ThrowError)

                            # endpoint name
                            $WebEvent.Endpoint.Name = (Find-PodeEndpointName -Protocol $WebEvent.Endpoint.Protocol -Address $WebEvent.Endpoint.Address -LocalAddress $WebEvent.Request.LocalEndPoint -Enabled:($PodeContext.Server.FindEndpoints.Route))

                            # add logging endware for post-request
                            Add-PodeRequestLogEndware -WebEvent $WebEvent

                            # stop now if the request has an error
                            if ($Request.IsAborted) {
                                throw $Request.Error
                            }

                            # invoke global and route middleware
                            if ((Invoke-PodeMiddleware -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
                                # has the request been aborted
                                if ($Request.IsAborted) {
                                    throw $Request.Error
                                }

                                if ((Invoke-PodeMiddleware -Middleware $WebEvent.Route.Middleware)) {
                                    # has the request been aborted
                                    if ($Request.IsAborted) {
                                        throw $Request.Error
                                    }

                                    # invoke the route
                                    if ($null -ne $WebEvent.StaticContent) {
                                        $fileBrowser = $WebEvent.Route.FileBrowser
                                        if ($WebEvent.StaticContent.IsDownload) {
                                            Write-PodeAttachmentResponseInternal -Path $WebEvent.StaticContent.Source -FileBrowser:$fileBrowser `
                                                -RootPath $WebEvent.StaticContent.Root
                                        }
                                        elseif ($WebEvent.StaticContent.RedirectToDefault) {
                                            $file = [System.IO.Path]::GetFileName($WebEvent.StaticContent.Source)
                                            Move-PodeResponseUrl -Url "$($WebEvent.Path)/$($file)"
                                        }
                                        else {
                                            $cachable = $WebEvent.StaticContent.IsCachable
                                            Write-PodeFileResponse -Path $WebEvent.StaticContent.Source -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge `
                                                -Cache:$cachable -FileBrowser:$fileBrowser -RootPath $WebEvent.StaticContent.Root
                                        }
                                    }
                                    elseif ($null -ne $WebEvent.Route.Logic) {
                                        $null = Invoke-PodeScriptBlock -ScriptBlock $WebEvent.Route.Logic -Arguments $WebEvent.Route.Arguments `
                                            -UsingVariables $WebEvent.Route.UsingVariables -Scoped -Splat
                                    }
                                }
                            }
                        }
                        catch [System.OperationCanceledException] {}
                        catch [System.Net.Http.HttpRequestException] {
                            if ($Response.StatusCode -ge 500) {
                                $_.Exception | Write-PodeErrorLog -CheckInnerException
                            }

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
                        Invoke-PodeEndware -Endware $_endware
                    }
                    finally {
                        $WebEvent = $null
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
    }

    # only if WS endpoint
    if (Test-PodeEndpoints -Type Ws) {
        # script to write messages back to the client(s)
        $signalScript = {
            param(
                [Parameter(Mandatory = $true)]
                $Listener
            )

            try {
                while ($Listener.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                    $message = (Wait-PodeTask -Task $Listener.GetServerSignalAsync($PodeContext.Tokens.Cancellation.Token))

                    try {
                        # get the sockets for the message
                        $sockets = @()

                        # by clientId
                        if (![string]::IsNullOrWhiteSpace($message.ClientId)) {
                            $sockets = @($Listener.Signals[$message.ClientId])
                        }
                        else {
                            $sockets = @($Listener.Signals.Values)

                            # by path
                            if (![string]::IsNullOrWhiteSpace($message.Path)) {
                                $sockets = @(foreach ($socket in $sockets) {
                                        if ($socket.Path -ieq $message.Path) {
                                            $socket
                                            break
                                        }
                                    })
                            }
                        }

                        # do nothing if no socket found
                        if (($null -eq $sockets) -or ($sockets.Length -eq 0)) {
                            continue
                        }

                        # send the message to all found sockets
                        foreach ($socket in $sockets) {
                            try {
                                $socket.Context.Response.SendSignal($message)
                            }
                            catch {
                                $null = $Listener.Signals.Remove($socket.ClientId)
                            }
                        }
                    }
                    catch [System.OperationCanceledException] {}
                    catch {
                        $_ | Write-PodeErrorLog
                        $_.Exception | Write-PodeErrorLog -CheckInnerException
                    }
                    finally {
                        Close-PodeDisposable -Disposable $message
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

        Add-PodeRunspace -Type Signals -ScriptBlock $signalScript -Parameters @{ 'Listener' = $listener }
    }

    # only if WS endpoint
    if (Test-PodeEndpoints -Type Ws) {
        # script to queue messages from clients to send back to other clients from the server
        $clientScript = {
            param(
                [Parameter(Mandatory = $true)]
                $Listener,

                [Parameter(Mandatory = $true)]
                [int]
                $ThreadId
            )

            try {
                while ($Listener.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                    $context = (Wait-PodeTask -Task $Listener.GetClientSignalAsync($PodeContext.Tokens.Cancellation.Token))

                    try {
                        $payload = ($context.Message | ConvertFrom-Json)
                        $Request = $context.Signal.Context.Request
                        $Response = $context.Signal.Context.Response

                        $SignalEvent = @{
                            Response  = $Response
                            Request   = $Request
                            Lockable  = $PodeContext.Threading.Lockables.Global
                            Path      = [System.Web.HttpUtility]::UrlDecode($Request.Url.AbsolutePath)
                            Data      = @{
                                Path     = [System.Web.HttpUtility]::UrlDecode($payload.path)
                                Message  = $payload.message
                                ClientId = $payload.clientId
                                Direct   = [bool]$payload.direct
                            }
                            Endpoint  = @{
                                Protocol = $Request.Url.Scheme
                                Address  = $Request.Host
                                Name     = $null
                            }
                            Route     = $null
                            ClientId  = $context.Signal.ClientId
                            Timestamp = $context.Timestamp
                            Streamed  = $true
                        }

                        # endpoint name
                        $SignalEvent.Endpoint.Name = (Find-PodeEndpointName -Protocol $SignalEvent.Endpoint.Protocol -Address $SignalEvent.Endpoint.Address -LocalAddress $SignalEvent.Request.LocalEndPoint -Enabled:($PodeContext.Server.FindEndpoints.Route))

                        # see if we have a route and invoke it, otherwise auto-send
                        $SignalEvent.Route = Find-PodeSignalRoute -Path $SignalEvent.Path -EndpointName $SignalEvent.Endpoint.Name

                        if ($null -ne $SignalEvent.Route) {
                            $null = Invoke-PodeScriptBlock -ScriptBlock $SignalEvent.Route.Logic -Arguments $SignalEvent.Route.Arguments -UsingVariables $SignalEvent.Route.UsingVariables -Scoped -Splat
                        }
                        else {
                            Send-PodeSignal -Value $SignalEvent.Data.Message -Path $SignalEvent.Data.Path -ClientId $SignalEvent.Data.ClientId
                        }
                    }
                    catch [System.OperationCanceledException] {}
                    catch {
                        $_ | Write-PodeErrorLog
                        $_.Exception | Write-PodeErrorLog -CheckInnerException
                    }
                    finally {
                        Update-PodeServerSignalMetrics -SignalEvent $SignalEvent
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
            Add-PodeRunspace -Type Signals -ScriptBlock $clientScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
        }
    }

    # script to keep web server listening until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            $Listener
        )

        try {
            while ($Listener.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
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

    $waitType = 'Web'
    if (!(Test-PodeEndpoints -Type Http)) {
        $waitType = 'Signals'
    }

    Add-PodeRunspace -Type $waitType -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener } -NoProfile

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].Url
    }

    return @(foreach ($endpoint in $endpoints) {
            @{
                Url  = $endpoint.Url
                Pool = $endpoint.Pool
            }
        })
}

function New-PodeListener {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Threading.CancellationToken]
        $CancellationToken
    )

    return [PodeListener]::new($CancellationToken)
}

function New-PodeListenerSocket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ipaddress]
        $Address,

        [Parameter(Mandatory = $true)]
        [int]
        $Port,

        [Parameter()]
        [System.Security.Authentication.SslProtocols]
        $SslProtocols,

        [Parameter(Mandatory = $true)]
        [PodeProtocolType]
        $Type,

        [Parameter()]
        [X509Certificate]
        $Certificate,

        [Parameter()]
        [bool]
        $AllowClientCertificate
    )

    return [PodeSocket]::new($Address, $Port, $SslProtocols, $Type, $Certificate, $AllowClientCertificate)
}