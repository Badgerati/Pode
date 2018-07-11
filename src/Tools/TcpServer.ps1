function Start-TcpServer
{
    $script = {
        # setup and run the tcp listener
        try
        {
            # ensure we have smtp handlers
            if ($null -eq (Get-PodeTcpHandler -Type 'TCP')) {
                throw 'No TCP handler has been passed'
            }

            # grab the relavant port
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
                if (Test-IPAccess -IP (ConvertTo-IPAddress -Endpoint $client.Client.RemoteEndPoint)) {
                    $TcpSession = @{
                        'Client' = $client;
                        'Lockalble' = $PodeSession.Lockable
                    }

                    Invoke-ScriptBlock -ScriptBlock (Get-PodeTcpHandler -Type 'TCP') -Arguments $TcpSession -Scoped
                }

                # close the connection
                if ($null -ne $client -and $client.Connected) {
                    dispose $client -Close
                }
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
        finally {
            if ($null -ne $listener) {
                $listener.Stop()
            }
        }
    }

    Add-PodeRunspace $script
}
