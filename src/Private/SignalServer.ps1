function Start-PodeSignalServer
{
    # setup the callback for sockets
    $PodeContext.Server.WebSockets.Ssl.Callback = Get-PodeSocketCertifcateCallback

    # work out which endpoints to listen on
    $endpoints = @()
    @(Get-PodeEndpoints -Type Ws) | ForEach-Object {
        # get the protocol
        $_protocol = (Resolve-PodeValue -Check $_.Ssl -TrueValue 'wss' -FalseValue 'ws')

        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = (Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1)
        $_ip = (Get-PodeIPAddress $_ip)

        # get the port
        $_port = [int]($_.Port)
        if ($_port -eq 0) {
            $_port = (Resolve-PodeValue $_.Ssl -TrueValue 9443 -FalseValue 9080)
        }

        # add endpoint to list
        $endpoints += @{
            Address = $_ip
            Port = $_port
            Certificate = $_.Certificate.Raw
            HostName = "$($_protocol)://$($_.HostName):$($_port)/"
        }
    }

    try
    {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $PodeContext.Server.WebSockets.Listeners += (Initialize-PodeSocketListenerEndpoint `
                -Type WebSockets `
                -Address $_.Address `
                -Port $_.Port `
                -Certificate $_.Certificate)
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeSocketListener -Type WebSockets
        throw $_.Exception
    }

    # script for listening out for incoming requests
    $listenScript = {
        param (
            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            Start-PodeSocketListener -Listeners $PodeContext.Server.WebSockets.Listeners

            [System.Threading.Thread]::CurrentThread.IsBackground = $true
            [System.Threading.Thread]::CurrentThread.Priority = [System.Threading.ThreadPriority]::Lowest

            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                Wait-PodeTask ([System.Threading.Tasks.Task]::Delay(60))
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
    1..$PodeContext.Threads | ForEach-Object {
        Add-PodeRunspace -Type 'Signals' -ScriptBlock $listenScript `
            -Parameters @{ 'ThreadId' = $_ }
    }

    # script to write messages back to the client(s)
    $signalScript = {
        try {
            [System.Threading.Thread]::CurrentThread.IsBackground = $true
            [System.Threading.Thread]::CurrentThread.Priority = [System.Threading.ThreadPriority]::Lowest

            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                Wait-PodeTask ([System.Threading.Tasks.Task]::Delay(100))

                # check if we have any messages to send
                $message = $null
                if (!$PodeContext.Server.WebSockets.Queues.Messages.TryDequeue([ref]$message)) {
                    $message = $null
                }

                if ($null -eq $message) {
                    continue
                }

                # get the sockets for the message
                $sockets = @()

                # by clientId
                if (![string]::IsNullOrWhiteSpace($message.ClientId)) {
                    $sockets = @($PodeContext.Server.WebSockets.Queues.Sockets[$message.ClientId])
                }
                else {
                    $sockets = @($PodeContext.Server.WebSockets.Queues.Sockets.Values)

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
                $buffer = [byte[]]@()
                $buffer += [byte]([byte]0x80 -bor [byte]1)

                $payload = $PodeContext.Server.Encoding.GetBytes($message.Value)
                if ($payload.Length -lt 126) {
                    $buffer += [byte]([byte]0x00 -bor [byte]$payload.Length)
                }
                elseif ($payload.Length -le [uint16]::MaxValue) {
                    $buffer += [byte]([byte]0x00 -bor [byte]126)
                }
                else {
                    $buffer += [byte]([byte]0x00 -bor [byte]127)
                }

                $buffer += $payload

                # send the message to all found sockets
                foreach ($socket in $sockets) {
                    try {
                        Wait-PodeTask -Task $socket.Stream.WriteAsync($buffer, 0, $buffer.Length)
                    }
                    catch {
                        $PodeContext.Server.WebSockets.Queues.Sockets.Remove($socket.ClientId) | Out-Null
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

    Add-PodeRunspace -Type 'Signals' -ScriptBlock $signalScript

    # script to keep web server listening until cancelled
    $waitScript = {
        try {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
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
            Close-PodeSocketListener -Type WebSockets
        }
    }

    Add-PodeRunspace -Type 'Signals' -ScriptBlock $waitScript

    # state where we're running
    Write-Host "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads) thread(s)]:" -ForegroundColor Yellow

    $endpoints | ForEach-Object {
        Write-Host "`t- $($_.HostName)" -ForegroundColor Yellow
    }
}

function Invoke-PodeWebSocketHandler
{
    param(
        [Parameter(Mandatory)]
        [hashtable]
        $Context
    )

    try
    {
        # make the stream (use an ssl stream if we have a cert)
        $stream = [System.Net.Sockets.NetworkStream]::new($Context.Socket, $true)

        if ($null -ne $Context.Certificate) {
            try {
                $stream = [System.Net.Security.SslStream]::new($stream, $false, $PodeContext.Server.WebSockets.Ssl.Callback)
                $stream.AuthenticateAsServer($Context.Certificate, $true, $PodeContext.Server.WebSockets.Ssl.Protocols, $false)
            }
            catch {
                # immediately close http connections
                Close-PodeSocket -Socket $Context.Socket -Shutdown
                return
            }
        }

        # read the request headers - once again, I apologise profusely.
        try {
            $bytes = New-Object byte[] 0
            $Context.Socket.Receive($bytes) | Out-Null
        }
        catch {
            $err = [System.Net.Http.HttpRequestException]::new()
            $err.Data.Add('PodeStatusCode', 408)
            throw $err
        }

        $bytes = New-Object byte[] $Context.Socket.Available
        (Wait-PodeTask -Task $stream.ReadAsync($bytes, 0, $Context.Socket.Available)) | Out-Null
        $req_info = Get-PodeServerRequestDetails -Bytes $bytes -Protocol $Context.Protocol

        # if the method is not a GET, close immediately
        if ($req_info.Method -ine 'GET') {
            Close-PodeSocket -Socket $Context.Socket -Shutdown
            return
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

    try {
        # get the path, and generate a clientId
        $path = $req_info.Uri.AbsolutePath
        $clientId = New-PodeGuid -Secure

        # send back headers to upgrade the client to a websocket
        $magicGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
        $secSocketKey = $req_info.Headers['Sec-WebSocket-Key'].Trim()

        $resHeaders = @{
            'Connection' = 'Upgrade'
            'Upgrade' = 'websocket'
            'Sec-WebSocket-Accept' = Invoke-PodeSHA1Hash -Value "$($secSocketKey)$($magicGuid)"
        }

        # write the response line
        $protocol = $req_info.Protocol
        if ([string]::IsNullOrWhiteSpace($protocol)) {
            $protocol = 'HTTP/1.1'
        }

        $newLine = "`r`n"
        $res_msg = "$($protocol) 101 Switching Protocols$($newLine)"

        # write the response headers
        foreach ($key in $resHeaders.Keys) {
            $res_msg += "$($key): $($resHeaders[$key])$($newLine)"
        }

        $res_msg += $newLine

        # stream response output
        $buffer = $PodeContext.Server.Encoding.GetBytes($res_msg)
        Wait-PodeTask -Task $stream.WriteAsync($buffer, 0, $buffer.Length)

        # add the socket/stream to all sockets, and path sockets (and clientId)
        $PodeContext.Server.WebSockets.Queues.Sockets[$clientId] = @{
            Socket = $Context.Socket
            Stream = $stream
            Path = $path
            ClientId = $clientId
        }
    }
    catch [System.Management.Automation.MethodInvocationException] { }
}