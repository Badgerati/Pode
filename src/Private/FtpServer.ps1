using namespace Pode

function Start-PodeFtpServer
{
    # ensure we have ftp handlers
    if (Test-PodeIsEmpty (Get-PodeHandler -Type Ftp)) {
        throw 'No FTP handlers have been defined'
    }

    # work out which endpoints to listen on
    $endpoints = @()

    @(Get-PodeEndpoints -Type Ftp) | ForEach-Object {
        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = (Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1)
        $_ip = (Get-PodeIPAddress $_ip)

        # the endpoint
        $_endpoint = @{
            Key = "$($_ip):$($_.Port)"
            Address = $_ip
            Hostname = $_.HostName
            IsIPAddress = $_.IsIPAddress
            Port = $_.Port
            Certificate = $_.Certificate.Raw
            AllowClientCertificate = $_.Certificate.AllowClientCertificate
            TlsMode = $_.Certificate.TlsMode
            Url = $_.Url
            Protocol = $_.Protocol
            Type = $_.Type
            Pool = $_.Runspace.PoolName
            Acknowledge = $_.Tcp.Acknowledge
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

    try
    {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $socket = [PodeSocket]::new($_.Address, $_.Port, $PodeContext.Server.Sockets.Ssl.Protocols, [PodeProtocolType]::Ftp, $_.Certificate, $_.AllowClientCertificate, $_.TlsMode)
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
            while ($Listener.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get email
                $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

                try
                {
                    try
                    {
                        $Request = $context.Request
                        $Response = $context.Response

                        $FtpEvent = @{
                            Response = $Response
                            Request = $Request
                            Lockable = $PodeContext.Lockables.Global
                            File = @{
                                Name = $null
                                Extension = $null
                                Path = $null
                                ContentLength = $null
                                ContentType = $null
                                Body = $null
                            }
                            Endpoint = @{
                                Protocol = $Request.Scheme
                                Address = $Request.Address
                                Name = $null
                            }
                            Timestamp = [datetime]::UtcNow
                        }

                        # endpoint name
                        $FtpEvent.Endpoint.Name = (Find-PodeEndpointName -Protocol $FtpEvent.Endpoint.Protocol -Address $FtpEvent.Endpoint.Address -LocalAddress $FtpEvent.Request.LocalEndPoint -Enabled:($PodeContext.Server.FindEndpoints.Ftp))

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

                        # deal with ftp call
                        else {
                            $handlers = Get-PodeHandler -Type Ftp
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
                    $FtpEvent = $null
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
        Add-PodeRunspace -Type Ftp -ScriptBlock $listenScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep ftp server listening until cancelled
    $waitScript = {
        param (
            [Parameter(Mandatory=$true)]
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

    Add-PodeRunspace -Type Ftp -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener } -NoProfile

    # state where we're running
    return @(foreach ($endpoint in $endpoints) {
        @{
            Url  = $endpoint.Url
            Pool = $endpoint.Pool
        }
    })
}