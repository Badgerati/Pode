
function Start-PodeTcpServer
{
    # ensure we have smtp handlers
    if ($PodeSession.TcpHandlers['tcp'] -eq $null)
    {
        throw 'No TCP handler has been passed'
    }

    # setup and run the smtp listener
    try
    {
        $endpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $PodeSession.Port)
        $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endpoint
        
        # start listener
        $listener.Start()

        # state where we're running
        Write-Host "Listening on tcp://localhost:$($PodeSession.Port)" -ForegroundColor Yellow

        # loop for tcp request
        while ($true)
        {
            if ($listener.Pending())
            {
                $client = $listener.AcceptTcpClient()
                $PodeSession.Tcp.Client = $client
                Invoke-Command -ScriptBlock $PodeSession.TcpHandlers['tcp'] -ArgumentList $PodeSession.Tcp
                
                if ($client.Connected)
                {
                    $client.Close()
                }
            }
        }

        Write-Host 'Terminating...'
    }
    finally
    {
        if ($listener -ne $null)
        {
            $listener.Stop()
        }
    }
}
