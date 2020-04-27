function Start-PodeSmtpServer
{
    # ensure we have smtp handlers
    if (Test-IsEmpty (Get-PodeHandler -Type Smtp)) {
        throw 'No SMTP handlers have been defined'
    }

    # grab the relavant port
    $port = $PodeContext.Server.Endpoints[0].Port

    # get the IP address for the server
    $ipAddress = $PodeContext.Server.Endpoints[0].Address
    if (Test-PodeHostname -Hostname $ipAddress) {
        $ipAddress = (Get-PodeIPAddressesForHostname -Hostname $ipAddress -Type All | Select-Object -First 1)
        $ipAddress = (Get-PodeIPAddress $ipAddress)
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
            Write-PodeTcpClient -Message "220 $($PodeContext.Server.Endpoints[0].HostName) -- Pode Proxy Server"
            $msg = [string]::Empty

            # respond to smtp request
            while ($true)
            {
                try { $msg = (Read-PodeTcpClient) }
                catch [System.OperationCanceledException] {
                    throw
                }
                catch {
                    $_ | Write-PodeErrorLog
                    break
                }

                try {
                    if (!(Test-IsEmpty $msg)) {
                        if ($msg.StartsWith('QUIT')) {
                            Write-PodeTcpClient -Message '221 Bye'
                            Close-PodeTcpConnection
                            break
                        }

                        if ($msg.StartsWith('EHLO') -or $msg.StartsWith('HELO')) {
                            Write-PodeTcpClient -Message '250 OK'
                        }

                        if ($msg.StartsWith('RCPT TO')) {
                            Write-PodeTcpClient -Message '250 OK'
                            $rcpt_tos += (Get-PodeSmtpEmail $msg)
                        }

                        if ($msg.StartsWith('MAIL FROM')) {
                            Write-PodeTcpClient -Message '250 OK'
                            $mail_from = (Get-PodeSmtpEmail $msg)
                        }

                        if ($msg.StartsWith('DATA'))
                        {
                            Write-PodeTcpClient -Message '354 Start mail input; end with <CR><LF>.<CR><LF>'
                            $data = (Read-PodeTcpClient)
                            Write-PodeTcpClient -Message '250 OK'

                            # set event data/headers
                            $TcpEvent.Email.From = $mail_from
                            $TcpEvent.Email.To = $rcpt_tos
                            $TcpEvent.Email.Data = $data
                            $TcpEvent.Email.Headers = (Get-PodeSmtpHeadersFromData $data)

                            # set the subject/priority/content-types
                            $TcpEvent.Email.Subject = $TcpEvent.Email.Headers['Subject']
                            $TcpEvent.Email.IsUrgent = (($TcpEvent.Email.Headers['Priority'] -ieq 'urgent') -or ($TcpEvent.Email.Headers['Importance'] -ieq 'high'))
                            $TcpEvent.Email.ContentType = $TcpEvent.Email.Headers['Content-Type']
                            $TcpEvent.Email.ContentEncoding = $TcpEvent.Email.Headers['Content-Transfer-Encoding']

                            # set the email body
                            $TcpEvent.Email.Body = (Get-PodeSmtpBody -Data $data -ContentType $TcpEvent.ContentType -ContentEncoding $TcpEvent.ContentEncoding)

                            # call user handlers for processing smtp data
                            $handlers = Get-PodeHandler -Type Smtp
                            foreach ($name in $handlers.Keys) {
                                $handler = $handlers[$name]
                                Invoke-PodeScriptBlock -ScriptBlock $handler.Logic -Arguments (@($TcpEvent) + @($handler.Arguments)) -Scoped -Splat
                            }

                            # reset the to list
                            $rcpt_tos = @()
                        }
                    }
                }
                catch [System.OperationCanceledException] {
                    throw
                }
                catch [exception] {
                    $_ | Write-PodeErrorLog
                    throw $_.exception
                }
            }
        }

        try
        {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get an incoming request
                $client = (Wait-PodeTask -Task $Listener.AcceptTcpClientAsync())
                $TcpEvent = @{
                    Client = $client
                    Lockable = $PodeContext.Lockable
                    Email = @{}
                }

                # convert the ip
                $ip = (ConvertTo-PodeIPAddress -Endpoint $client.Client.RemoteEndPoint)

                # ensure the request ip is allowed
                if (!(Test-PodeIPAccess -IP $ip)) {
                    Close-PodeTcpConnection -Quit -Message '550 Your IP address was rejected'
                }

                elseif (!(Test-PodeIPLimit -IP $ip)) {
                    Close-PodeTcpConnection -Quit -Message '550 Your IP address has hit the rate limit'
                }

                # deal with smtp call
                else {
                    Invoke-PodeScriptBlock -ScriptBlock $process
                    Close-PodeTcpConnection -Quit
                }
            }
        }
        catch [System.OperationCanceledException] {
            Close-PodeTcpConnection -Quit
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads.Web | ForEach-Object {
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
    return @("smtp://$($PodeContext.Server.Endpoints[0].HostName):$($port)")
}


function Get-PodeSmtpEmail
{
    param (
        [Parameter()]
        [string]
        $Value
    )

    $tmp = @($Value -isplit ':')
    if ($tmp.Length -gt 1) {
        return $tmp[1].Trim().Trim(' <>')
    }

    return [string]::Empty
}

function Get-PodeSmtpBody
{
    param (
        [Parameter()]
        [string]
        $Data,

        [Parameter()]
        [string]
        $ContentType,

        [Parameter()]
        [string]
        $ContentEncoding
    )

    # split the message up
    $dataSplit = @($Data -isplit [System.Environment]::NewLine)

    # get the index of the first blank line, and last dot
    $indexOfBlankLine = $dataSplit.IndexOf([string]::Empty)
    $indexOfLastDot = [array]::LastIndexOf($dataSplit, '.')

    # get the body
    $body = ($dataSplit[($indexOfBlankLine + 1)..($indexOfLastDot - 2)] -join [System.Environment]::NewLine)

    # if there's no body, just return
    if (($indexOfLastDot -eq -1) -or (Test-IsEmpty $body)) {
        return $body
    }

    # decode body based on encoding
    switch ($ContentEncoding.ToLowerInvariant()) {
        'base64' {
            $body = [System.Convert]::FromBase64String($body)
        }
    }

    # only if body is bytes, first decode based on type
    switch ($ContentType) {
        { $_ -ilike '*utf-7*' } {
            $body = [System.Text.Encoding]::UTF7.GetString($body)
        }

        { $_ -ilike '*utf-8*' } {
            $body = [System.Text.Encoding]::UTF8.GetString($body)
        }

        { $_ -ilike '*utf-16*' } {
            $body = [System.Text.Encoding]::Unicode.GetString($body)
        }

        { $_ -ilike '*utf-32*' } {
            $body = [System.Text.Encoding]::UTF32.GetString($body)
        }
    }

    return $body
}

function Get-PodeSmtpHeadersFromData
{
    param (
        [Parameter()]
        [string]
        $Data
    )

    $headers = @{}
    $lines = @($Data -isplit [System.Environment]::NewLine)

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            break
        }

        if ($line -imatch '^(?<name>.*?)\:\s+(?<value>.*?)$') {
            $headers[$Matches['name'].Trim()] = $Matches['value'].Trim()
        }
    }

    return $headers
}