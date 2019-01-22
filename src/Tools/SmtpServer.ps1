function Start-SmtpServer
{
    # ensure we have smtp handlers
    if ($null -eq (Get-PodeTcpHandler -Type 'SMTP')) {
        throw 'No SMTP handler has been passed'
    }

    # grab the relavant port
    $port = $PodeContext.Server.Endpoints[0].Port
    if ($port -eq 0) {
        $port = 25
    }

    # get the IP address for the server
    $ipAddress = $PodeContext.Server.Endpoints[0].Address
    if (Test-Hostname -Hostname $ipAddress) {
        $ipAddress = (Get-IPAddressesForHostname -Hostname $ipAddress -Type All | Select-Object -First 1)
        $ipAddress = (Get-IPAddress $ipAddress)
    }

    try
    {
        # create the listener for smtp
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

    # state where we're running
    Write-Host "Listening on smtp://$($PodeContext.Server.Endpoints[0].HostName):$($port) [$($PodeContext.Threads) thread(s)]" -ForegroundColor Yellow

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

        # scriptblock for the core smtp message processing logic
        $process = {
            # if there's no client, just return
            if ($null -eq $TcpEvent.Client) {
                return
            }

            # variables to store data for later processing
            $mail_from = [string]::Empty
            $rcpt_tos = @()
            $data = [string]::Empty

            # open response to smtp request
            tcp write "220 $($PodeContext.Server.Endpoints[0].HostName) -- Pode Proxy Server"
            $msg = [string]::Empty

            # respond to smtp request
            while ($true)
            {
                try { $msg = (tcp read) }
                catch { break }

                try {
                    if (!(Test-Empty $msg)) {
                        if ($msg.StartsWith('QUIT')) {
                            tcp write '221 Bye'

                            if ($null -ne $TcpEvent.Client -and $TcpEvent.Client.Connected) {
                                dispose $TcpEvent.Client -Close
                            }

                            break
                        }

                        if ($msg.StartsWith('EHLO') -or $msg.StartsWith('HELO')) {
                            tcp write '250 OK'
                        }

                        if ($msg.StartsWith('RCPT TO')) {
                            tcp write '250 OK'
                            $rcpt_tos += (Get-SmtpEmail $msg)
                        }

                        if ($msg.StartsWith('MAIL FROM')) {
                            tcp write '250 OK'
                            $mail_from = Get-SmtpEmail $msg
                        }

                        if ($msg.StartsWith('DATA'))
                        {
                            tcp write '354 Start mail input; end with <CR><LF>.<CR><LF>'
                            $data = (tcp read)
                            tcp write '250 OK'

                            # set event data
                            $SmtpEvent.From = $mail_from
                            $SmtpEvent.To = $rcpt_tos
                            $SmtpEvent.Data = $data
                            $SmtpEvent.Lockable = $PodeContext.Lockable

                            # call user handlers for processing smtp data
                            Invoke-ScriptBlock -ScriptBlock (Get-PodeTcpHandler -Type 'SMTP') -Arguments $SmtpEvent -Scoped

                            # reset the to list
                            $rcpt_tos = @()
                        }
                    }
                }
                catch [exception] {
                    throw $_.exception
                }
            }
        }

        try
        {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get an incoming request
                $task = $Listener.AcceptTcpClientAsync()
                $task.Wait($PodeContext.Tokens.Cancellation.Token)
                $client = $task.Result

                # convert the ip
                $ip = (ConvertTo-IPAddress -Endpoint $client.Client.RemoteEndPoint)

                # ensure the request ip is allowed
                if (!(Test-IPAccess -IP $ip) -or !(Test-IPLimit -IP $ip)) {
                    dispose $client -Close
                }

                # deal with smtp call
                else {
                    $SmtpEvent = @{}
                    $TcpEvent = @{
                        'Client' = $client;
                        'Lockable' = $PodeContext.Lockable
                    }

                    Invoke-ScriptBlock -ScriptBlock $process
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
    1..$PodeContext.Threads | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep smtp server listening until cancelled
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
}


function Get-SmtpEmail
{
    param (
        [Parameter()]
        [string]
        $Value
    )

    $tmp = ($Value -isplit ':')
    if ($tmp.Length -gt 1) {
        return $tmp[1].Trim().Trim('<', '>')
    }

    return [string]::Empty
}