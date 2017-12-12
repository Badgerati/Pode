
function Start-PodeMailServer
{
    # ensure we have smtp handlers
    if (($PodeSession.SmtpHandlers | Measure-Object).Count -eq 0)
    {
        throw 'No SMTP handlers have been passed'
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
        Write-ToSmtpStream -Client $Client -Message '220 localhost -- Pode Proxy Server'
        $msg = [string]::Empty

        # respond to smtp request
        while ($true)
        {
            try { $msg = Read-FromSmtpStream -Client $Client }
            catch { break }
            
            if (![string]::IsNullOrWhiteSpace($msg))
            {
                if ($msg.StartsWith('QUIT'))
                {
                    Write-ToSmtpStream -Client $Client -Message '221 Bye'
                    $Client.Close()
                    break
                }

                if ($msg.StartsWith('EHLO') -or $msg.StartsWith('HELO'))
                {
                    Write-ToSmtpStream -Client $Client -Message '250 OK'
                }

                if ($msg.StartsWith('RCPT TO'))
                {
                    Write-ToSmtpStream -Client $Client -Message '250 OK'
                    $rcpt_tos += (Get-SmtpEmail $msg)
                }

                if ($msg.StartsWith('MAIL FROM'))
                {
                    Write-ToSmtpStream -Client $Client -Message '250 OK'
                    $mail_from = Get-SmtpEmail $msg
                }

                if ($msg.StartsWith('DATA'))
                {
                    Write-ToSmtpStream -Client $Client -Message '354 Start mail input; end with <CR><LF>.<CR><LF>'
                    $data = Read-FromSmtpStream -Client $Client
                    Write-ToSmtpStream -Client $Client -Message '250 OK'
                    
                    # call user handlers for processing smtp data
                    $PodeSession.SmtpHandlers | ForEach-Object {
                        Invoke-Command -ScriptBlock $_ -ArgumentList $mail_from, $rcpt_tos, $data
                    }
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
                Invoke-Command -ScriptBlock $process -ArgumentList $client
            }
        }
    }
    finally
    {
        if ($listener -ne $null)
        {
            $listener.Stop()
        }
    }
}

function Write-ToSmtpStream
{
    param (
        [Parameter()]
        $Client,

        [Parameter()]
        [string]
        $Message
    )

    $stream = $Client.GetStream()
    $encoder = New-Object System.Text.ASCIIEncoding
    $buffer = $encoder.GetBytes("$($Message)`r`n")
    $stream.Write($buffer, 0, $buffer.Length)
    $stream.Flush()
}

function Read-FromSmtpStream
{
    param (
        [Parameter()]
        $Client
    )

    $bytes = New-Object byte[] 8192
    $stream = $client.GetStream()
    $encoder = New-Object System.Text.ASCIIEncoding
    $bytesRead = $stream.Read($bytes, 0, 8192)
    $message = $encoder.GetString($bytes, 0, $bytesRead)
    return $message
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