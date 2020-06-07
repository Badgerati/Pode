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
            $listener.Add($socket)
        }

        $listener.Start()
        $PodeContext.Server.WebSockets.Listener = $listener
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeSocketListener -Type WebSockets
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
                #Invoke-PodeWebSocketHandler -Context $context

                try {
                    $Request = $context.Request
                    $Response = $context.Response

                    # get the path, and generate a clientId
                    #$path = $Request.Url.AbsolutePath
                    $clientId = New-PodeGuid -Secure

                    # upgrade the socket
                    $Response.UpgradeWebSocket($clientId)

                    # add the socket/stream to all sockets, and path sockets (and clientId)
                    # $PodeContext.Server.WebSockets.Queues.Sockets[$clientId] = @{
                    #     Context = $context
                    #     Path = $path
                    #     ClientId = $clientId
                    # }
                }
                catch [System.Management.Automation.MethodInvocationException] { }
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
        Add-PodeRunspace -Type 'Signals' -ScriptBlock $listenScript `
            -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
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
                $message = (Wait-PodeTask -Task $Listener.GetSignalAsync($PodeContext.Tokens.Cancellation.Token))

                # get the sockets for the message
                $sockets = @()

                # by clientId
                if (![string]::IsNullOrWhiteSpace($message.ClientId)) {
                    $sockets = @($Listener.WebSockets[$message.ClientId])
                    #$sockets = @($PodeContext.Server.WebSockets.Queues.Sockets[$message.ClientId])
                }
                else {
                    $sockets = @($Listener.WebSockets.Values)
                    #$sockets = @($PodeContext.Server.WebSockets.Queues.Sockets.Values)

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

                # frame the message
                # $buffer = [byte[]]@()
                # $buffer += [byte]([byte]0x80 -bor [byte]1)

                # $payload = $PodeContext.Server.Encoding.GetBytes($message.Value)
                # if ($payload.Length -lt 126) {
                #     $buffer += [byte]([byte]0x00 -bor [byte]$payload.Length)
                # }
                # elseif ($payload.Length -le [uint16]::MaxValue) {
                #     $buffer += [byte]([byte]0x00 -bor [byte]126)
                # }
                # else {
                #     $buffer += [byte]([byte]0x00 -bor [byte]127)
                # }

                # $buffer += $payload

                # send the message to all found sockets
                foreach ($socket in $sockets) {
                    try {
                        #$socket.Context.Response.Write($buffer)
                        $socket.Context.Response.Write($message.Value)
                    }
                    catch {
                        $Listener.WebSockets.Remove($socket.ClientId) | Out-Null
                        #$PodeContext.Server.WebSockets.Queues.Sockets.Remove($socket.ClientId) | Out-Null
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

# function Invoke-PodeWebSocketHandler
# {
#     param(
#         [Parameter(Mandatory)]
#         [Pode.PodeContext]
#         $Context
#     )

#     try {
#         $Request = $Context.Request
#         $Response = $Context.Response

#         # get the path, and generate a clientId
#         $path = $Request.Url.AbsolutePath
#         $clientId = New-PodeGuid -Secure

#         # upgrade the socket
#         $Response.UpgradeWebSocket($clientId)

#         # add the socket/stream to all sockets, and path sockets (and clientId)
#         $PodeContext.Server.WebSockets.Queues.Sockets[$clientId] = @{
#             Context = $Context
#             Path = $path
#             ClientId = $clientId
#         }
#     }
#     catch [System.Management.Automation.MethodInvocationException] { }
# }