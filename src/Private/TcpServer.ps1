function Start-PodeTcpServer
{
    # ensure we have service handlers
    if (Test-IsEmpty (Get-PodeHandler -Type Tcp)) {
        throw 'No TCP handlers have been defined'
    }

    # grab the relavant port
    $port = $PodeContext.Server.Endpoints[0].Port
    if ($port -eq 0) {
        $port = 9001
    }

    # get the IP address for the server
    $ipAddress = $PodeContext.Server.Endpoints[0].Address
    if (Test-PodeHostname -Hostname $ipAddress) {
        $ipAddress = (Get-PodeIPAddressesForHostname -Hostname $ipAddress -Type All | Select-Object -First 1)
        $ipAddress = (Get-PodeIPAddress $ipAddress)
    }

    try
    {
        # create the listener for tcp
        $endpoint = New-Object System.Net.IPEndPoint($ipAddress, $port)
        $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endpoint

        # start listener
        $listener.Start()
    }
    catch {
        if ($null -ne $listener) {
            $listener.Stop()
        }

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
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get an incoming request
                $client = (Wait-PodeTask -Task $Listener.AcceptTcpClientAsync())

                # convert the ip
                $ip = (ConvertTo-PodeIPAddress -Endpoint $client.Client.RemoteEndPoint)

                # ensure the request ip is allowed and deal with the tcp call
                if ((Test-PodeIPAccess -IP $ip) -and (Test-PodeIPLimit -IP $ip)) {
                    $TcpEvent = @{
                        'Client' = $client;
                        'Lockalble' = $PodeContext.Lockable
                    }

                    # invoke the tcp handlers
                    $handlers = Get-PodeHandler -Type Tcp
                    foreach ($name in $handlers.Keys) {
                        Invoke-PodeScriptBlock -ScriptBlock $handlers[$name].Logic -Arguments $TcpEvent -Scoped
                    }
                }

                # close the connection
                Close-PodeTcpConnection
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads | ForEach-Object {
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
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
        finally {
            if ($null -ne $Listener) {
                $Listener.Stop()
            }
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }

    # state where we're running
    Write-Host "Listening on tcp://$($PodeContext.Server.Endpoints[0].HostName):$($port) [$($PodeContext.Threads) thread(s)]" -ForegroundColor Yellow
}
