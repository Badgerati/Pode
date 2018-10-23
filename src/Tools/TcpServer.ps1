function Start-TcpServer
{
    # ensure we have tcp handler
    if ($null -eq (Get-PodeTcpHandler -Type 'TCP')) {
        throw 'No TCP handler has been passed'
    }

    # grab the relavant port
    $port = $PodeSession.Server.IP.Port
    if ($port -eq 0) {
        $port = 9001
    }

    $endpoint = New-Object System.Net.IPEndPoint($PodeSession.Server.IP.Address, $port)
    $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endpoint

    try
    {
        # start listener
        $listener.Start()
    }
    catch {
        $Error[0] | Out-Default

        if ($null -ne $listener) {
            $listener.Stop()
        }

        throw $_.Exception
    }

    # state where we're running
    Write-Host "Listening on tcp://$($PodeSession.Server.IP.Name):$($port) [$($PodeSession.Threads) thread(s)]" -ForegroundColor Yellow

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
            while (!$PodeSession.Tokens.Cancellation.IsCancellationRequested)
            {
                # get an incoming request
                $task = $Listener.AcceptTcpClientAsync()
                $task.Wait($PodeSession.Tokens.Cancellation.Token)
                $client = $task.Result

                # convert the ip
                $ip = (ConvertTo-IPAddress -Endpoint $client.Client.RemoteEndPoint)

                # ensure the request ip is allowed and deal with the tcp call
                if ((Test-IPAccess -IP $ip) -and (Test-IPLimit -IP $ip)) {
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
    }

    # start the runspace for listening on x-number of threads
    1..$PodeSession.Threads | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep tcp server listening until cancelled
    $waitScript = {
        param (
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener
        )

        try
        {
            while (!$PodeSession.Tokens.Cancellation.IsCancellationRequested)
            {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
        finally {
            if ($null -ne $Listener) {
                $Listener.Stop()
            }
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }
}
