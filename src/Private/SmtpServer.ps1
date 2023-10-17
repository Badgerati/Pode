using namespace Pode

function Start-PodeSmtpServer {
    # ensure we have smtp handlers
    if (Test-PodeIsEmpty (Get-PodeHandler -Type Smtp)) {
        throw 'No SMTP handlers have been defined'
    }

    # work out which endpoints to listen on
    $endpoints = @()

    @(Get-PodeEndpoints -Type Smtp) | ForEach-Object {
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
            TlsMode                = $_.Certificate.TlsMode
            Url                    = $_.Url
            Protocol               = $_.Protocol
            Type                   = $_.Type
            Pool                   = $_.Runspace.PoolName
            Acknowledge            = $_.Tcp.Acknowledge
            SslProtocols           = $_.Ssl.Protocols
        }

        # add endpoint to list
        $endpoints += $_endpoint
    }

    # create the listener
    $listener = [PodeListener]::new($PodeContext.Tokens.Cancellation.Token)
    $listener.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)
    $listener.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevels)
    $listener.RequestTimeout = $PodeContext.Server.Request.Timeout
    $listener.RequestBodySize = $PodeContext.Server.Request.BodySize

    try {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $socket = [PodeSocket]::new($_.Address, $_.Port, $_.SslProtocols, [PodeProtocolType]::Smtp, $_.Certificate, $_.AllowClientCertificate, $_.TlsMode)
            $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout
            $socket.AcknowledgeMessage = $_.Acknowledge

            if (!$_.IsIPAddress) {
                $socket.Hostnames.Add($_.HostName)
            }

            $listener.Add($socket)
        }

        $listener.Start()
        $PodeContext.Listeners += $listener
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $listener
        throw $_.Exception
    }

    # script for listening out of for incoming requests
    $listenScript = {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            $Listener,

            [Parameter(Mandatory = $true)]
            [int]
            $ThreadId
        )

        try {
            while ($Listener.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # get email
                $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

                try {
                    try {
                        $Request = $context.Request
                        $Response = $context.Response

                        $SmtpEvent = @{
                            Response  = $Response
                            Request   = $Request
                            Lockable  = $PodeContext.Threading.Lockables.Global
                            Email     = @{
                                From            = $Request.From
                                To              = $Request.To
                                Data            = $Request.RawBody
                                Headers         = $Request.Headers
                                Subject         = $Request.Subject
                                IsUrgent        = $Request.IsUrgent
                                ContentType     = $Request.ContentType
                                ContentEncoding = $Request.ContentEncoding
                                Attachments     = $Request.Attachments
                                Body            = $Request.Body
                            }
                            Endpoint  = @{
                                Protocol = $Request.Scheme
                                Address  = $Request.Address
                                Name     = $null
                            }
                            Timestamp = [datetime]::UtcNow
                        }

                        # endpoint name
                        $SmtpEvent.Endpoint.Name = (Find-PodeEndpointName -Protocol $SmtpEvent.Endpoint.Protocol -Address $SmtpEvent.Endpoint.Address -LocalAddress $SmtpEvent.Request.LocalEndPoint -Enabled:($PodeContext.Server.FindEndpoints.Smtp))

                        # stop now if the request has an error
                        if ($Request.IsAborted) {
                            throw $Request.Error
                        }

                        # convert the ip
                        $ip = (ConvertTo-PodeIPAddress -Address $Request.RemoteEndPoint)

                        # ensure the request ip is allowed
                        if (!(Test-PodeIPAccess -IP $ip)) {
                            $Response.WriteLine('554 Your IP address was rejected', $true)
                        }

                        # has the ip hit the rate limit?
                        elseif (!(Test-PodeIPLimit -IP $ip)) {
                            $Response.WriteLine('554 Your IP address has hit the rate limit', $true)
                        }

                        # deal with smtp call
                        else {
                            $handlers = Get-PodeHandler -Type Smtp
                            foreach ($name in $handlers.Keys) {
                                $handler = $handlers[$name]
                                $_args = @(Get-PodeScriptblockArguments -ArgumentList $handler.Arguments -UsingVariables $handler.UsingVariables)
                                Invoke-PodeScriptBlock -ScriptBlock $handler.Logic -Arguments $_args -Scoped -Splat
                            }
                        }
                    }
                    catch [System.OperationCanceledException] {}
                    catch {
                        $_ | Write-PodeErrorLog
                        $_.Exception | Write-PodeErrorLog -CheckInnerException
                    }
                }
                finally {
                    $SmtpEvent = $null
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
        Add-PodeRunspace -Type Smtp -ScriptBlock $listenScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep smtp server listening until cancelled
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

    Add-PodeRunspace -Type Smtp -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener } -NoProfile

    # state where we're running
    return @(foreach ($endpoint in $endpoints) {
            @{
                Url  = $endpoint.Url
                Pool = $endpoint.Pool
            }
        })
}