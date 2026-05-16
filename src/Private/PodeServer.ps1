using namespace Pode.Protocols.Http
using namespace Pode.Transport.Sockets
using namespace Pode.Utilities

function Start-PodeWebServer {
    param(
        [switch]
        $Browse
    )

    # setup any inbuilt middleware
    $inbuilt_middleware = @(
        (Get-PodeLimitMiddleware),
        (Get-PodeSecurityMiddleware),
        (Get-PodeFaviconMiddleware),
        (Get-PodeAccessMiddleware),
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

    @(Get-PodeEndpointByProtocolType -Type Http, Ws) | ForEach-Object {
        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1
        $_ip = Get-PodeIPAddress -IP $_ip -DualMode:($_.DualMode)

        # dual mode?
        $addrs = $_ip
        if ($_.DualMode) {
            $addrs = Resolve-PodeIPDualMode -IP $_ip
        }

        # the endpoint
        $_endpoint = @{
            Name                    = $_.Name
            Key                     = "$($_ip):$($_.Port)"
            Address                 = $addrs
            Hostname                = $_.HostName
            IsIPAddress             = $_.IsIPAddress
            Port                    = $_.Port
            Certificate             = $_.Certificate.Raw
            AllowClientCertificate  = $_.Certificate.AllowClientCertificate
            Url                     = $_.Url
            Protocol                = $_.Protocol
            Type                    = $_.Type
            Pool                    = $_.Runspace.PoolName
            SslProtocols            = $_.Ssl.Protocols
            DualMode                = $_.DualMode
            Default                 = $_.Default
            NoAutoUpgradeWebSockets = $_.WebSockets.NoAutoUpgrade
        }

        # add endpoint to list
        $endpoints += $_endpoint

        # add to map
        if (!$endpointsMap.ContainsKey($_endpoint.Key)) {
            $endpointsMap[$_endpoint.Key] = @{ Type = $_.Type }
        }
        elseif ($endpointsMap[$_endpoint.Key].Type -ine $_.Type) {
            $endpointsMap[$_endpoint.Key].Type = 'HttpAndWs'
        }
    }

    # Create the listener
    $listener = [PodeHttpListener]::new($PodeContext.Tokens.Cancellation.Token)
    $listener.ErrorLoggingEnabled = Test-PodeErrorLogTypeEnabled
    $listener.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevel)
    $listener.RequestTimeout = $PodeContext.Server.Request.Timeout
    $listener.RequestBodySize = $PodeContext.Server.Request.BodySize
    $listener.ShowServerDetails = [bool]$PodeContext.Server.Security.ServerDetails
    $listener.TrackClientConnectionEvents = Test-PodeSignalEvent -Type Connect, Disconnect

    try {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            # Initialize a new listener socket with splatting
            $socket = [PodeSocket]::new($_.Name, $_.Address, $_.Port, $_.SslProtocols, $endpointsMap[$_.Key].Type, $_.Certificate, $_.AllowClientCertificate, 'Implicit', $_.DualMode)
            $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout
            $socket.NoAutoUpgradeWebSockets = $_.NoAutoUpgradeWebSockets

            if (!$_.IsIPAddress) {
                $socket.Hostnames.Add($_.HostName)
            }

            $listener.Add($socket)
        }

        $listener.Start()
        $PodeContext.Listeners += $listener
        $PodeContext.Server.Http.Listener = $listener
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $listener
        throw $_.Exception
    }

    # only if HTTP endpoint
    if (Test-PodeEndpointByProtocolType -Type Http) {
        # script for listening out for incoming requests
        $listenScript = {
            param(
                [Parameter(Mandatory = $true)]
                $Listener,

                [Parameter(Mandatory = $true)]
                [int]
                $ThreadId
            )

            # Waits for the Pode server to fully start before proceeding with further operations.
            Wait-PodeCancellationTokenRequest -Type Start

            do {
                try {
                    while ($Listener.IsConnected -and !(Test-PodeCancellationTokenRequest -Type Terminate, Cancellation -Match All)) {
                        # get request and response
                        $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

                        try {
                            try {
                                $Request = $context.Request.Strategy
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
                                        Name     = $context.EndpointName
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
                                    Sse              = $null
                                    Signal           = $null
                                    Metadata         = @{}
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
                                $WebEvent.Ranges = (Get-PodeRange -Range (Get-PodeHeader -Name 'Range') -ThrowError)

                                # add logging endware for post-request
                                Add-PodeRequestLogEndware -WebEvent $WebEvent

                                # stop now if the request has an error
                                if ($Request.Handler.IsAborted) {
                                    throw $Request.Handler.Error
                                }

                                # if we have an sse clientId, verify it and then set details in WebEvent
                                if ($null -ne $WebEvent.Request.ServerEvent) {
                                    if (!(Test-PodeSseClientIdValid)) {
                                        throw (New-PodeRequestException StatusCode 400 Message "The X-PODE-SSE-CLIENT-ID value is not valid: $($WebEvent.Request.ServerEvent.ClientId)")
                                    }

                                    # setup the SSE property, as a reference to the request's ServerEvent
                                    $WebEvent.Sse = $WebEvent.Request.ServerEvent
                                }

                                # if we have a signal clientId, verify it and then set details in WebEvent
                                if ($null -ne $WebEvent.Request.Signal) {
                                    if (!(Test-PodeSignalClientIdValid)) {
                                        throw (New-PodeRequestException StatusCode 400 Message "The X-PODE-SIGNAL-CLIENT-ID value is not valid: $($WebEvent.Request.Signal.ClientId)")
                                    }

                                    # setup the Signal property, as a reference to the request's Signal
                                    $WebEvent.Signal = $WebEvent.Request.Signal
                                }

                                # invoke global and route middleware
                                if ((Invoke-PodeMiddleware -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
                                    # has the request been aborted
                                    if ($Request.Handler.IsAborted) {
                                        throw $Request.Handler.Error
                                    }

                                    if ((Invoke-PodeMiddleware -Middleware $WebEvent.Route.Middleware)) {
                                        # has the request been aborted
                                        if ($Request.Handler.IsAborted) {
                                            throw $Request.Handler.Error
                                        }

                                        # invoke the route
                                        if ($null -ne $WebEvent.StaticContent) {
                                            $fileBrowser = $WebEvent.Route.FileBrowser
                                            if ($WebEvent.StaticContent.IsDownload) {
                                                Write-PodeAttachmentResponseInternal -FileInfo $WebEvent.StaticContent.FileInfo -FileBrowser:$fileBrowser
                                            }
                                            elseif ($WebEvent.StaticContent.RedirectToDefault) {
                                                $file = [System.IO.Path]::GetFileName($WebEvent.StaticContent.Source)
                                                Move-PodeResponseUrl -Url "$($WebEvent.Path)/$($file)"
                                            }
                                            else {
                                                $cachable = $WebEvent.StaticContent.IsCachable
                                                Write-PodeFileResponseInternal -FileInfo $WebEvent.StaticContent.FileInfo -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge -Cache:$cachable -FileBrowser:$fileBrowser
                                            }
                                        }
                                        elseif ($null -ne $WebEvent.Route.Logic) {
                                            $null = Invoke-PodeScriptBlock -ScriptBlock $WebEvent.Route.Logic -Arguments $WebEvent.Route.Arguments -UsingVariables $WebEvent.Route.UsingVariables -Scoped -Splat
                                        }
                                    }
                                }
                            }
                            catch [System.OperationCanceledException] {
                                $_ | Write-PodeErrorLog -Level Debug
                            }
                            catch [Pode.Protocols.Common.Requests.PodeRequestException] {
                                $_.Exception | Write-PodeErrorLog -Level "$($_.Exception.LoggingLevel)" -CheckInnerException:($_.Exception.IsServerError)

                                $code = $_.Exception.StatusCode
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
                                Update-PodeServerRequestMetric -WebEvent $WebEvent
                            }

                            # invoke endware specific to the current web event
                            $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
                            Invoke-PodeEndware -Endware $_endware
                        }
                        finally {
                            $WebEvent = $null
                            Close-PodeDisposable -Disposable $context
                        }
                    }
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Write-PodeErrorLog
                    $_.Exception | Write-PodeErrorLog -CheckInnerException
                    throw $_.Exception
                }

                # end do-while
            } while (Test-PodeSuspensionToken) # Check for suspension token and wait for the debugger to reset if active
        }

        # start the runspace for listening on x-number of threads
        Write-Verbose 'Starting the Web Listener runspace(s)...'
        1..$PodeContext.Threads.General | ForEach-Object {
            Add-PodeRunspace -Type Web -Name 'Listener' -ScriptBlock $listenScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
        }
    }

    # only if WS endpoint
    if (Test-PodeEndpointByProtocolType -Type Ws) {
        # script to queue messages from clients to send back to other clients from the server
        $clientScript = {
            param(
                [Parameter(Mandatory = $true)]
                $Listener,

                [Parameter(Mandatory = $true)]
                [int]
                $ThreadId
            )

            # Waits for the Pode server to fully start before proceeding with further operations.
            Wait-PodeCancellationTokenRequest -Type Start

            do {
                try {
                    while ($Listener.IsConnected -and !(Test-PodeCancellationTokenRequest -Type Terminate, Cancellation -Match All)) {
                        $context = (Wait-PodeTask -Task $Listener.GetClientSignalAsync($PodeContext.Tokens.Cancellation.Token))

                        try {
                            $payload = ($context.Message | ConvertFrom-Json)
                            $Request = $context.Signal.Context.Request.Strategy
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
                                    Group    = $payload.group
                                    Direct   = [bool]$payload.direct
                                }
                                Endpoint  = @{
                                    Protocol = $Request.Url.Scheme
                                    Address  = $Request.Host
                                    Name     = $context.Signal.Context.EndpointName
                                }
                                Route     = $null
                                ClientId  = $context.Signal.ClientId
                                Timestamp = $context.Timestamp
                                Streamed  = $true
                                Metadata  = @{}
                            }

                            # see if we have a route and invoke it, otherwise auto-send
                            $SignalEvent.Route = Find-PodeSignalRoute -Path $SignalEvent.Path -EndpointName $SignalEvent.Endpoint.Name

                            if ($null -ne $SignalEvent.Route) {
                                $null = Invoke-PodeScriptBlock -ScriptBlock $SignalEvent.Route.Logic -Arguments $SignalEvent.Route.Arguments -UsingVariables $SignalEvent.Route.UsingVariables -Scoped -Splat
                            }
                            else {
                                Send-PodeSignal -Value $SignalEvent.Data.Message -Path $SignalEvent.Data.Path -ClientId $SignalEvent.Data.ClientId
                            }
                        }
                        catch [System.OperationCanceledException] {
                            $_ | Write-PodeErrorLog -Level Debug
                        }
                        catch {
                            $_ | Write-PodeErrorLog
                            $_.Exception | Write-PodeErrorLog -CheckInnerException
                        }
                        finally {
                            Update-PodeServerSignalMetric -SignalEvent $SignalEvent
                            Close-PodeDisposable -Disposable $context
                        }
                    }
                }
                catch [System.OperationCanceledException] {
                    $_ | Write-PodeErrorLog -Level Debug
                }
                catch {
                    $_ | Write-PodeErrorLog
                    $_.Exception | Write-PodeErrorLog -CheckInnerException
                    throw $_.Exception
                }

                # end do-while
            } while (Test-PodeSuspensionToken) # Check for suspension token and wait for the debugger to reset if active

        }

        # start the runspace for listening on x-number of threads
        Write-Verbose 'Starting the Signals Listener runspace(s)...'
        1..$PodeContext.Threads.General | ForEach-Object {
            Add-PodeRunspace -Type Signals -Name 'Listener' -ScriptBlock $clientScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
        }
    }

    # only if tracking client connection events
    if ((Test-PodeSseEvent -Type Connect, Disconnect) -or (Test-PodeSignalEvent -Type Connect, Disconnect)) {
        Start-PodeWebConnectionEventsRunspace
    }

    # script to keep web server listening until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            $Listener
        )

        try {
            while ($Listener.IsConnected -and !(Test-PodeCancellationTokenRequest -Type Terminate)) {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
        finally {
            Close-PodeDisposable -Disposable $Listener
        }
    }

    $rsType = 'Web'
    if (Test-PodeEndpointByProtocolType -Type Ws) {
        $rsType = 'Signals'
    }

    Write-Verbose "Starting the $($rsType) KeepAlive runspace..."
    Add-PodeRunspace -Type $rsType -Name 'KeepAlive' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener } -NoProfile

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].Url
    }

    return @(foreach ($endpoint in $endpoints) {
            @{
                Protocol = $endpoint.Protocol
                Url      = $endpoint.Url
                Pool     = $endpoint.Pool
                DualMode = $endpoint.DualMode
                Name     = $endpoint.Name
                Default  = $endpoint.Default
                Order    = ($endpoint.Protocol | Get-PodeEndpointProtocolOrder)
            }
        })
}

function Start-PodeWebConnectionEventsRunspace {
    # script to handle client connection events
    $connectionEventScript = {
        param(
            [Parameter(Mandatory = $true)]
            $Listener
        )

        # Waits for the Pode server to fully start before proceeding with further operations.
        Wait-PodeCancellationTokenRequest -Type Start

        do {
            try {
                while ($Listener.IsConnected -and !(Test-PodeCancellationTokenRequest -Type Terminate, Cancellation -Match All)) {
                    $evt = (Wait-PodeTask -Task $Listener.GetClientConnectionEventAsync($PodeContext.Tokens.Cancellation.Token))

                    try {
                        switch ("$($evt.Connection.ConnectionType)".ToLowerInvariant()) {
                            'sse' {
                                Invoke-PodeSseEvent -Name $evt.Connection.Name -Type $evt.EventType -Connection $evt.Connection.ToHashtable()
                            }
                            'signal' {
                                Invoke-PodeSignalEvent -Name $evt.Connection.Name -Type $evt.EventType -Connection $evt.Connection.ToHashtable()
                            }
                        }
                    }
                    catch [System.OperationCanceledException] {
                        $_ | Write-PodeErrorLog -Level Debug
                    }
                    catch {
                        $_ | Write-PodeErrorLog
                        $_.Exception | Write-PodeErrorLog -CheckInnerException
                    }
                    finally {
                        Close-PodeDisposable -Disposable $evt
                        $evt = $null
                    }
                }
            }
            catch [System.OperationCanceledException] {
                $_ | Write-PodeErrorLog -Level Debug
            }
            catch {
                $_ | Write-PodeErrorLog
                $_.Exception | Write-PodeErrorLog -CheckInnerException
                throw $_.Exception
            }
        } while (Test-PodeSuspensionToken) # Check for suspension token and wait for the debugger to reset if active
    }

    # create and run the runspace
    $rsType = 'Web'
    if (Test-PodeEndpointByProtocolType -Type Ws) {
        $rsType = 'Signals'
    }

    Write-Verbose "Starting the $($rsType) ConnectionEvents runspace..."
    Add-PodeRunspace -Type $rsType -Name 'ConnectionEvents' -ScriptBlock $connectionEventScript -Parameters @{ 'Listener' = $PodeContext.Server.Http.Listener }
}