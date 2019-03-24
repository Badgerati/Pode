function Start-TcpServer
{
    # ensure we have tcp handler
    if ($null -eq (Get-PodeTcpHandler -Type 'TCP')) {
        throw 'No TCP handler has been passed'
    }

    # grab the relavant port
    $port = $PodeContext.Server.Endpoints[0].Port
    if ($port -eq 0) {
        $port = 9001
    }

    # get the IP address for the server
    $ipAddress = $PodeContext.Server.Endpoints[0].Address
    if (Test-Hostname -Hostname $ipAddress) {
        $ipAddress = (Get-IPAddressesForHostname -Hostname $ipAddress -Type All | Select-Object -First 1)
        $ipAddress = (Get-IPAddress $ipAddress)
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
                $client = (await $Listener.AcceptTcpClientAsync())

                # convert the ip
                $ip = (ConvertTo-IPAddress -Endpoint $client.Client.RemoteEndPoint)

                # ensure the request ip is allowed and deal with the tcp call
                if ((Test-IPAccess -IP $ip) -and (Test-IPLimit -IP $ip)) {
                    $TcpEvent = @{
                        'Client' = $client;
                        'Lockalble' = $PodeContext.Lockable
                    }

                    Invoke-ScriptBlock -ScriptBlock (Get-PodeTcpHandler -Type 'TCP') -Arguments $TcpEvent -Scoped
                }

                # close the connection
                Close-PodeTcpConnection
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $Error[0] | Out-Default
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

    # state where we're running
    Write-Host "Listening on tcp://$($PodeContext.Server.Endpoints[0].HostName):$($port) [$($PodeContext.Threads) thread(s)]" -ForegroundColor Yellow
}
