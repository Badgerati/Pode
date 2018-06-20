
function Start-TcpServer
{
    # ensure we have smtp handlers
    if ((Get-PodeTcpHandler -Type 'TCP') -eq $null) {
        throw 'No TCP handler has been passed'
    }

    # setup and run the smtp listener
    try
    {
        $endpoint = New-Object System.Net.IPEndPoint($PodeSession.IP.Address, $PodeSession.Port)
        $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endpoint

        # start listener
        $listener.Start()

        # state where we're running
        Write-Host "Listening on tcp://$($PodeSession.IP.Name):$($PodeSession.Port)" -ForegroundColor Yellow

        # loop for tcp request
        while ($true)
        {
            $task = $listener.AcceptTcpClientAsync()
            $task.Wait($PodeSession.CancelToken.Token)

            $PodeSession.Tcp.Client = $client
            $PodeSession.Tcp.Lockable = $PodeSession.Lockable
            & (Get-PodeTcpHandler -Type 'TCP') $PodeSession.Tcp

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
