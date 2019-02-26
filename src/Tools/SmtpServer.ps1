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
                            $mail_from = (Get-SmtpEmail $msg)
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
                            $SmtpEvent.Subject = (Get-SmtpSubject $data)
                            $SmtpEvent.Lockable = $PodeContext.Lockable

                            # set the email body/type
                            $info = (Get-SmtpBody $data)
                            $SmtpEvent.Body = $info.Body
                            $SmtpEvent.ContentType = $info.ContentType
                            $SmtpEvent.ContentEncoding = $info.ContentEncoding

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
                $client = (await $Listener.AcceptTcpClientAsync())

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
        catch [System.OperationCanceledException] {
            if ($null -ne $TcpEvent.Client) {
                dispose $TcpEvent.Client -Close
            }
        }
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

    $tmp = @($Value -isplit ':')
    if ($tmp.Length -gt 1) {
        return $tmp[1].Trim().Trim(' <>')
    }

    return [string]::Empty
}

function Get-SmtpSubject
{
    param (
        [Parameter()]
        [string]
        $Data
    )

    return (Get-SmtpLineFromData -Data $Data -Name 'Subject')
}

function Get-SmtpBody
{
    param (
        [Parameter()]
        [string]
        $Data
    )

    # body info object
    $BodyInfo = @{
        'ContentType' = $null;
        'ContentEncoding' = $null;
        'Body' = $null;
    }

    # get the content type
    $BodyInfo.ContentType = (Get-SmtpLineFromData -Data $Data -Name 'Content-Type')

    # get the content encoding
    $BodyInfo.ContentEncoding = (Get-SmtpLineFromData -Data $Data -Name 'Content-Transfer-Encoding')

    # split the message up
    $dataSplit = @($Data -isplit [System.Environment]::NewLine)

    # get the index of the first blank line, and last dot
    $indexOfBlankLine = $dataSplit.IndexOf([string]::Empty)
    $indexOfLastDot = [array]::LastIndexOf($dataSplit, '.')

    # get the body
    $BodyInfo.Body = ($dataSplit[($indexOfBlankLine + 1)..($indexOfLastDot - 2)] -join [System.Environment]::NewLine)

    # if there's no body, just return
    if (($indexOfLastDot -eq -1) -or (Test-Empty $BodyInfo.Body)) {
        return $BodyInfo
    }

    # decode body based on encoding
    switch ($BodyInfo.ContentEncoding.ToLowerInvariant()) {
        'base64' {
            $BodyInfo.Body = [System.Convert]::FromBase64String($BodyInfo.Body)
        }
    }

    # only if body is bytes, first decode based on type
    switch ($BodyInfo.ContentType) {
        { $_ -ilike '*utf-7*' } {
            $BodyInfo.Body = [System.Text.Encoding]::UTF7.GetString($BodyInfo.Body)
        }

        { $_ -ilike '*utf-8*' } {
            $BodyInfo.Body = [System.Text.Encoding]::UTF8.GetString($BodyInfo.Body)
        }

        { $_ -ilike '*utf-16*' } {
            $BodyInfo.Body = [System.Text.Encoding]::Unicode.GetString($BodyInfo.Body)
        }

        { $_ -ilike '*utf-32*' } {
            $BodyInfo.Body = [System.Text.Encoding]::UTF32.GetString($BodyInfo.Body)
        }
    }

    return $BodyInfo
}

function Get-SmtpLineFromData
{
    param (
        [Parameter()]
        [string]
        $Data,

        [Parameter()]
        [string]
        $Name
    )

    $line = (@($Data -isplit [System.Environment]::NewLine) | Where-Object {
        $_ -ilike "$($Name):*"
    } | Select-Object -First 1)

    return ($line -ireplace "^$($Name)\:\s+", '').Trim()

}