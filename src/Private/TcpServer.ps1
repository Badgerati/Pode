function Start-PodeTcpServer
{
    # ensure we have service handlers
    if (Test-PodeIsEmpty (Get-PodeHandler -Type Tcp)) {
        throw 'No TCP handlers have been defined'
    }

    # the endpoint to listen on
    $endpoint = @(Get-PodeEndpoints -Type Tcp)[0]

    # grab the relavant port
    $port = $endpoint.Port

    # get the IP address for the server
    $ipAddress = $endpoint.Address
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
                $ip = (ConvertTo-PodeIPAddress -Address $client.Client.RemoteEndPoint)

                # ensure the request ip is allowed and deal with the tcp call
                if ((Test-PodeIPAccess -IP $ip) -and (Test-PodeIPLimit -IP $ip)) {
                    $TcpEvent = @{
                        Client = $client
                        Lockable = $PodeContext.Lockables.Global
                    }

                    # invoke the tcp handlers
                    $handlers = Get-PodeHandler -Type Tcp
                    foreach ($name in $handlers.Keys) {
                        $handler = $handlers[$name]

                        $_args = @($handler.Arguments)
                        if ($null -ne $handler.UsingVariables) {
                            $_vars = @()
                            foreach ($_var in $handler.UsingVariables) {
                                $_vars += ,$_var.Value
                            }
                            $_args = $_vars + $_args
                        }

                        Invoke-PodeScriptBlock -ScriptBlock $handler.Logic -Arguments $_args -Scoped -Splat
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
    1..$PodeContext.Threads.General | ForEach-Object {
        Add-PodeRunspace -Type Tcp -ScriptBlock $listenScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
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

    Add-PodeRunspace -Type Tcp -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener } -NoProfile

    # state where we're running
    return @(@{
        Url  = "tcp://$($endpoint.FriendlyName):$($port)"
        Pool = $endpoint.Runspace.PoolName
    })
}
