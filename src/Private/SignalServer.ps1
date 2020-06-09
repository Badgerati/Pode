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
            Port = $_.Port
            Certificate = $_.Certificate.Raw
            HostName = $_.Url
        }
    }

    # create the listener
    $listener = [Pode.PodeListener]::new()
    $listener.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)

    try
    {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $socket = [Pode.PodeSocket]::new($_.Address, $_.Port, $PodeContext.Server.Sockets.Ssl.Protocols, $_.Certificate)
            $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout
            $listener.Add($socket)
        }

        $listener.Start()
        $PodeContext.Server.WebSockets.Listener = $listener
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $listener
        throw $_.Exception
    }

    #TODO: use this to listen for client>server socket mesages

    # script for listening out for incoming requests
    # $listenScript = {
    #     param(
    #         [Parameter(Mandatory=$true)]
    #         [ValidateNotNull()]
    #         $Listener,

    #         [Parameter(Mandatory=$true)]
    #         [int]
    #         $ThreadId
    #     )

    #     try
    #     {
    #         while ($Listener.IsListening -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
    #         {
    #             # get request and response
    #             $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

    #             try {
    #                 $context.Response.UpgradeWebSocket((New-PodeGuid -Secure))
    #             }
    #             catch [System.Management.Automation.MethodInvocationException] { }
    #         }
    #     }
    #     catch [System.OperationCanceledException] {}
    #     catch {
    #         $_ | Write-PodeErrorLog
    #         $_.Exception | Write-PodeErrorLog -CheckInnerException
    #         throw $_.Exception
    #     }
    # }

    # # start the runspace for listening on x-number of threads
    # 1..$PodeContext.Threads.Web | ForEach-Object {
    #     Add-PodeRunspace -Type 'Signals' -ScriptBlock $listenScript `
    #         -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    # }

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
                $message = (Wait-PodeTask -Task $Listener.GetSignalAsync($PodeContext.Tokens.Cancellation.Token))

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
                        $socket.Context.Response.Write($message.Value)
                    }
                    catch {
                        $Listener.WebSockets.Remove($socket.ClientId) | Out-Nul
                    }
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

    Add-PodeRunspace -Type 'Signals' -ScriptBlock $signalScript -Parameters @{ 'Listener' = $listener }

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

    Add-PodeRunspace -Type 'Signals' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }
    return @($endpoints.HostName)
}