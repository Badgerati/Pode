using namespace Pode

function Start-PodeSmtpServer
{
    # ensure we have smtp handlers
    if (Test-PodeIsEmpty (Get-PodeHandler -Type Smtp)) {
        throw 'No SMTP handlers have been defined'
    }

    # the endpoint to listen on
    $endpoint = @($PodeContext.Server.Endpoints.Values)[0]

    # grab the relavant port
    $port = $endpoint.Port

    # get the IP address for the server
    $ipAddress = $endpoint.Address
    if (Test-PodeHostname -Hostname $ipAddress) {
        $ipAddress = (Get-PodeIPAddressesForHostname -Hostname $ipAddress -Type All | Select-Object -First 1)
        $ipAddress = (Get-PodeIPAddress $ipAddress)
    }

    # create the listener
    $listener = [PodeListener]::new($PodeContext.Tokens.Cancellation.Token, [PodeListenerType]::Smtp)
    $listener.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)

    try
    {
        # register endpoint on the listener
        $socket = [PodeSocket]::new($ipAddress, $port, $PodeContext.Server.Sockets.Ssl.Protocols, $null)
        $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout
        $socket.Hostnames.Add($endpoint.HostName)
        $listener.Add($socket)
        $listener.Start()
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
            while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get email
                $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

                try
                {
                    $Request = $context.Request
                    $Response = $context.Response

                    $TcpEvent = @{
                        Response = $Response
                        Request = $Request
                        Lockable = $PodeContext.Lockable
                        Email = @{
                            From = $Request.From
                            To = $Request.To
                            Data = $Request.RawBody
                            Headers = $Request.Headers
                            Subject = $Request.Subject
                            IsUrgent = $Request.IsUrgent
                            ContentType = $Request.ContentType
                            ContentEncoding = $Request.ContentEncoding
                            Body = $Request.Body
                        }
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

                            $_args = @($TcpEvent) + @($handler.Arguments)
                            if ($null -ne $handler.UsingVariables) {
                                $_args = @($handler.UsingVariables.Value) + $_args
                            }

                            Invoke-PodeScriptBlock -ScriptBlock $handler.Logic -Arguments $_args -Scoped -Splat
                        }
                    }
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
    1..$PodeContext.Threads.Web | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep smtp server listening until cancelled
    $waitScript = {
        param (
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

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }

    # state where we're running
    return @("smtp://$($endpoint.HostName):$($port)")
}