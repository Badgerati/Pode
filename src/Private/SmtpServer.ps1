using namespace Pode

function Start-PodeSmtpServer {
    # ensure we have smtp handlers
    if (Test-PodeIsEmpty (Get-PodeHandler -Type Smtp)) {
        # No SMTP handlers have been defined
        throw ($PodeLocale.noSmtpHandlersDefinedExceptionMessage)
    }

    # work out which endpoints to listen on
    $endpoints = @()

    @(Get-PodeEndpointByProtocolType -Type Smtp) | ForEach-Object {
        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1
        $_ip = Get-PodeIPAddress $_ip -DualMode:($_.DualMode)

        # dual mode?
        $addrs = $_ip
        if ($_.DualMode) {
            $addrs = Resolve-PodeIPDualMode -IP $_ip
        }

        # the endpoint
        $_endpoint = @{
            Name                   = $_.Name
            Key                    = "$($_ip):$($_.Port)"
            Address                = $addrs
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
            DualMode               = $_.DualMode
        }

        # add endpoint to list
        $endpoints += $_endpoint
    }

    # create the listener
    $listener = [PodeListener]::new($PodeContext.Tokens.Cancellation.Token)
    $listener.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)
    $listener.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevel)
    $listener.RequestTimeout = $PodeContext.Server.Request.Timeout
    $listener.RequestBodySize = $PodeContext.Server.Request.BodySize

    try {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $socket = [PodeSocket]::new($_.Name, $_.Address, $_.Port, $_.SslProtocols, [PodeProtocolType]::Smtp, $_.Certificate, $_.AllowClientCertificate, $_.TlsMode, $_.DualMode)
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

        do {
            try {
                while ($Listener.IsConnected -and !$PodeContext.Tokens.Terminate.IsCancellationRequested) {
                    # get email
                    $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

                    try {
                        try {
                            $Request = $context.Request
                            $Response = $context.Response

                            $script:SmtpEvent = @{
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
                                    Name     = $context.EndpointName
                                }
                                Timestamp = [datetime]::UtcNow
                                Metadata  = @{}
                            }

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
                                    $null = Invoke-PodeScriptBlock -ScriptBlock $handler.Logic -Arguments $handler.Arguments -UsingVariables $handler.UsingVariables -Scoped -Splat
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
                    }
                    finally {
                        $script:SmtpEvent = $null
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
        } while (Test-PodeSuspensionToken) # Check for suspension or dump tokens and wait for the debugger to reset if active

    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads.General | ForEach-Object {
        Add-PodeRunspace -Type Smtp -Name 'Listener' -ScriptBlock $listenScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep smtp server listening until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            $Listener
        )

        try {
            while ($Listener.IsConnected -and !$PodeContext.Tokens.Terminate.IsCancellationRequested) {
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

    Add-PodeRunspace -Type Smtp -Name 'KeepAlive' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener } -NoProfile

    # state where we're running
    return @(foreach ($endpoint in $endpoints) {
            @{
                Url      = $endpoint.Url
                Pool     = $endpoint.Pool
                DualMode = $endpoint.DualMode
            }
        })
}