
function Start-TcpServer
{
    # ensure we have smtp handlers
    if ((Get-PodeTcpHandler -Type 'TCP') -eq $null) {
        throw 'No TCP handler has been passed'
    }

    # setup and run the smtp listener
    try
    {
        $port = $PodeSession.IP.Port
        if ($port -eq 0) {
            $port = 9001
        }

        $endpoint = New-Object System.Net.IPEndPoint($PodeSession.IP.Address, $port)
        $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endpoint

        # start listener
        $listener.Start()

        # state where we're running
        Write-Host "Listening on tcp://$($PodeSession.IP.Name):$($port)" -ForegroundColor Yellow

        # loop for tcp request
        while ($true)
        {
            $task = $listener.AcceptTcpClientAsync()
            $task.Wait($PodeSession.Tokens.Cancellation.Token)
            $client = $task.Result

            # ensure the request ip is allowed and deal with the tcp call
            if (Test-IPAccess -IP (ConvertTo-IPEndpoint -Endpoint $client.Client.RemoteEndPoint)) {
                $PodeSession.Tcp.Client = $client
                $PodeSession.Tcp.Lockable = $PodeSession.Lockable
                Invoke-ScriptBlock -ScriptBlock (Get-PodeTcpHandler -Type 'TCP') -Arguments $PodeSession.Tcp -Scoped
            }

            # close the connection
            if ($client -ne $null -and $client.Connected) {
                try {
                    $client.Close()
                    $client.Dispose()
                } catch { }
            }
        }
    }
    catch [System.OperationCanceledException] {
        Close-Pode -Exit
    }
    finally {
        if ($listener -ne $null) {
            $listener.Stop()
        }
    }
}
