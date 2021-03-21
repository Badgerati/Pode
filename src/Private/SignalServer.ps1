using namespace Pode

function Start-PodeSignalServer
{
    # work out which endpoints to listen on
    $endpoints = @()
    @(Get-PodeEndpoints -Type Ws) | ForEach-Object {
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
    $listener = [PodeListener]::new($PodeContext.Tokens.Cancellation.Token, [PodeListenerType]::WebSocket)
    $listener.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)

    try
    {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $socket = [PodeSocket]::new($_.Address, $_.Port, $PodeContext.Server.Sockets.Ssl.Protocols, $_.Certificate, $_.AllowClientCertificate)
            $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout

            if (!$_.IsIPAddress) {
                $socket.Hostnames.Add($_.HostName)
            }

            $listener.Add($socket)
        }

        $listener.Start()
        $PodeContext.Listeners += $listener
        $PodeContext.Server.WebSockets.Listener = $listener
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $listener
        throw $_.Exception
    }

    # script to write messages back to the client(s)
    $signalScript = {
        param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener
        )

        try {
            while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                $message = (Wait-PodeTask -Task $Listener.GetServerSignalAsync($PodeContext.Tokens.Cancellation.Token))

                try
                {
                    # get the sockets for the message
                    $sockets = @()

                    # by clientId
                    if (![string]::IsNullOrWhiteSpace($message.ClientId)) {
                        $sockets = @($Listener.WebSockets[$message.ClientId])
                    }
                    else {
                        $sockets = @($Listener.WebSockets.Values)

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
                            $Listener.WebSockets.Remove($socket.ClientId) | Out-Null
                        }
                    }
                }
                catch [System.OperationCanceledException] {}
                catch {
                    $_ | Write-PodeErrorLog
                    $_.Exception | Write-PodeErrorLog -CheckInnerException
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

    # script to queue messages from clients to send back to other clients from the server
    $clientScript = {
        param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener
        )

        try {
            while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                $context = (Wait-PodeTask -Task $Listener.GetClientSignalAsync($PodeContext.Tokens.Cancellation.Token))

                try
                {
                    $payload = ($context.Message | ConvertFrom-Json)
                    $Request = $context.WebSocket.Context.Request
                    $Response = $context.WebSocket.Context.Response

                    $SignalEvent = @{
                        Response = $Response
                        Request = $Request
                        Lockable = $PodeContext.Lockable
                        Path = [System.Web.HttpUtility]::UrlDecode($Request.Url.AbsolutePath)
                        Data = @{
                            Path = [System.Web.HttpUtility]::UrlDecode($payload.path)
                            Message = $payload.message
                            ClientId = $payload.clientId
                        }
                        Endpoint = @{
                            Protocol = $Request.Url.Scheme
                            Address = $Request.Host
                            Name = $null
                        }
                        Route = $null
                        Timestamp = $context.Timestamp
                        Streamed = $true
                    }

                    # endpoint name
                    $SignalEvent.Endpoint.Name = (Find-PodeEndpointName -Protocol $SignalEvent.Endpoint.Protocol -Address $SignalEvent.Endpoint.Address -LocalAddress $SignalEvent.Request.LocalEndPoint)

                    # see if we have a route and invoke it, otherwise auto-send
                    $SignalEvent.Route = Find-PodeSignalRoute -Path $SignalEvent.Path -EndpointName $SignalEvent.Endpoint.Name

                    if ($null -ne $SignalEvent.Route) {
                        $_args = @($SignalEvent.Route.Arguments)
                        if ($null -ne $SignalEvent.Route.UsingVariables) {
                            $_vars = @()
                            foreach ($_var in $SignalEvent.Route.UsingVariables) {
                                $_vars += ,$_var.Value
                            }
                            $_args = $_vars + $_args
                        }

                        Invoke-PodeScriptBlock -ScriptBlock $SignalEvent.Route.Logic -Arguments $_args -Scoped -Splat
                    }
                    else {
                        Send-PodeSignal -Value $SignalEvent.Message -Path $SignalEvent.Path -ClientId $SignalEvent.ClientId
                    }
                }
                catch [System.OperationCanceledException] {}
                catch {
                    $_ | Write-PodeErrorLog
                    $_.Exception | Write-PodeErrorLog -CheckInnerException
                }
                finally {
                    Update-PodeServerSignalMetrics -SignalEvent $SignalEvent
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

    Add-PodeRunspace -Type Signals -ScriptBlock $clientScript -Parameters @{ 'Listener' = $listener }

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

    Add-PodeRunspace -Type Signals -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }
    return @($endpoints.Url)
}