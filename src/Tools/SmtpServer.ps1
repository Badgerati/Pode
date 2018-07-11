function Start-SmtpServer
{
    $script = {
        # scriptblock for the core smtp message processing logic
        $process = {
            # if there's no client, just return
            if ($null -eq $PodeSession.Tcp.Client) {
                return
            }

            # variables to store data for later processing
            $mail_from = [string]::Empty
            $rcpt_tos = @()
            $data = [string]::Empty

            # open response to smtp request
            tcp write "220 $($PodeSession.IP.Name) -- Pode Proxy Server"
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

                            if ($null -ne $PodeSession.Tcp.Client -and $PodeSession.Tcp.Client.Connected) {
                                dispose $PodeSession.Tcp.Client -Close
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

                            # set session data
                            $PodeSession.Smtp.From = $mail_from
                            $PodeSession.Smtp.To = $rcpt_tos
                            $PodeSession.Smtp.Data = $data
                            $PodeSession.Smtp.Lockable = $PodeSession.Lockable

                            # call user handlers for processing smtp data
                            Invoke-ScriptBlock -ScriptBlock (Get-PodeTcpHandler -Type 'SMTP') -Arguments $PodeSession.Smtp -Scoped
                        }
                    }
                }
                catch [exception] {
                    throw $_.exception
                }
            }
        }

        # setup and run the smtp listener
        try
        {
            # ensure we have smtp handlers
            if ($null -eq (Get-PodeTcpHandler -Type 'SMTP')) {
                throw 'No SMTP handler has been passed'
            }

            # grab the relavant port
            $port = $PodeSession.IP.Port
            if ($port -eq 0) {
                $port = 25
            }

            $endpoint = New-Object System.Net.IPEndPoint($PodeSession.IP.Address, $port)
            $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endpoint

            # start listener
            $listener.Start()

            # state where we're running
            Write-Host "Listening on smtp://$($PodeSession.IP.Name):$($port)" -ForegroundColor Yellow

            # loop for tcp request
            while ($true)
            {
                $task = $listener.AcceptTcpClientAsync()
                $task.Wait($PodeSession.Tokens.Cancellation.Token)
                $client = $task.Result

                # ensure the request ip is allowed
                if (!(Test-IPAccess -IP (ConvertTo-IPAddress -Endpoint $client.Client.RemoteEndPoint))) {
                    dispose $client -Close
                }

                # deal with smtp call
                else {
                    $PodeSession.Tcp.Client = $client
                    $PodeSession.Smtp = @{}
                    Invoke-ScriptBlock -ScriptBlock $process
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