function Start-PodeSmtpServer
{
    # ensure we have smtp handlers
    if ((Get-PodeTcpHandler -Type 'SMTP') -eq $null)
    {
        throw 'No SMTP handler has been passed'
    }

    # scriptblock for the core smtp message processing logic
    $process = {
        param (
            [Parameter()]
            $Client
        )

        # if there's no client, just return
        if ($Client -eq $null)
        {
            return
        }

        # variables to store data for later processing
        $mail_from = [string]::Empty
        $rcpt_tos = @()
        $data = [string]::Empty

        # open response to smtp request
        Write-ToTcpStream -Client $Client -Message '220 localhost -- Pode Proxy Server'
        $msg = [string]::Empty

        # respond to smtp request
        while ($true)
        {
            try { $msg = Read-FromTcpStream -Client $Client }
            catch { break }
            
            if (![string]::IsNullOrWhiteSpace($msg))
            {
                if ($msg.StartsWith('QUIT'))
                {
                    Write-ToTcpStream -Client $Client -Message '221 Bye'
                    $Client.Close()
                    break
                }

                if ($msg.StartsWith('EHLO') -or $msg.StartsWith('HELO'))
                {
                    Write-ToTcpStream -Client $Client -Message '250 OK'
                }

                if ($msg.StartsWith('RCPT TO'))
                {
                    Write-ToTcpStream -Client $Client -Message '250 OK'
                    $rcpt_tos += (Get-SmtpEmail $msg)
                }

                if ($msg.StartsWith('MAIL FROM'))
                {
                    Write-ToTcpStream -Client $Client -Message '250 OK'
                    $mail_from = Get-SmtpEmail $msg
                }

                if ($msg.StartsWith('DATA'))
                {
                    Write-ToTcpStream -Client $Client -Message '354 Start mail input; end with <CR><LF>.<CR><LF>'
                    $data = Read-FromTcpStream -Client $Client
                    Write-ToTcpStream -Client $Client -Message '250 OK'

                    # set session data
                    $PodeSession.Smtp.From = $mail_from
                    $PodeSession.Smtp.To = $rcpt_tos
                    $PodeSession.Smtp.Data = $data

                    # call user handlers for processing smtp data
                    Invoke-Command -ScriptBlock (Get-PodeTcpHandler -Type 'SMTP') -ArgumentList $PodeSession.Smtp
                }
            }
        }
    }

    # setup and run the smtp listener
    try
    {
        $endpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $PodeSession.Port)
        $listener = New-Object System.Net.Sockets.TcpListener -ArgumentList $endpoint
        
        # start listener
        $listener.Start()

        # state where we're running
        Write-Host "Listening on smtp://localhost:$($PodeSession.Port)" -ForegroundColor Yellow

        # loop for tcp request
        while ($true)
        {
            if ($listener.Pending())
            {
                $client = $listener.AcceptTcpClient()
                $PodeSession.Smtp = @{}
                Invoke-Command -ScriptBlock $process -ArgumentList $client
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


function Get-SmtpEmail
{
    param (
        [Parameter()]
        [string]
        $Value
    )

    $tmp = ($Value -isplit ':')
    if ($tmp.Length -gt 1)
    {
        return $tmp[1].Trim().Trim('<', '>')
    }

    return [string]::Empty
}