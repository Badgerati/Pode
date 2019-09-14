function Start-PodeSocketServer
{
    param (
        [switch]
        $Browse
    )

    # work out which endpoints to listen on
    $endpoints = @()
    $PodeContext.Server.Endpoints | ForEach-Object {
        # get the protocol
        $_protocol = (Resolve-PodeValue -Check $_.Ssl -TrueValue 'https' -FalseValue 'http')

        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = (Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1)
        $_ip = (Get-PodeIPAddress $_ip)

        # get the port
        $_port = [int]($_.Port)
        if ($_port -eq 0) {
            $_port = (Resolve-PodeValue $_.Ssl -TrueValue 8443 -FalseValue 8080)
        }

        # if this endpoint is https, generate a self-signed cert or bind an existing one
        #if ($_.Ssl) {
        #    $addr = (Resolve-PodeValue -Check $_.IsIPAddress -TrueValue $_.Address -FalseValue $_.HostName)
        #    $selfSigned = $_.Certificate.SelfSigned
        #    Set-PodeCertificate -Address $addr -Port $_port -Certificate $_.Certificate.Name -Thumbprint $_.Certificate.Thumbprint -SelfSigned:$selfSigned
        #}

        # add endpoint to list
        $endpoints += @{
            Address = $_ip
            Port = $_port
            Ssl = $_.Ssl
            HostName = "$($_protocol)://$($_.HostName):$($_port)/"
        }
    }

    # create the listener on http and/or https
    #$listener = [Pode.PodeListener]::new($endpoints[0].Address, $endpoints[0].Port)
    #$listener = [PodeListener]::new($endpoints[0].Address, $endpoints[0].Port)
    Initialize-PodeSocketListener -Address $endpoints[0].Address -Port $endpoints[0].Port

    # try
    # {
    #     # start listening on defined endpoints
    #     $endpoints | ForEach-Object {
    #         $listener.Prefixes.Add($_.Prefix)
    #     }

    #     $listener.Start()
    # }
    # catch {
    #     $_ | Write-PodeErrorLog

    #     if ($null -ne $Listener) {
    #         if ($Listener.IsListening) {
    #             $Listener.Stop()
    #         }

    #         Close-PodeDisposable -Disposable $Listener -Close
    #     }

    #     throw $_.Exception
    # }

    # script for listening out for incoming requests
    $listenScript = {
        param (
            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            #$listener = . { [PodeListener]::new($endpoints[0].Address, $endpoints[0].Port) }
            #$listener.Start()
            Start-PodeSocketListener

            'here1' | Out-Default
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                'here2' | Out-Default
                # wait for a socket to be connected
                while ($null -eq $socket) {
                    $socket = Get-PodeSocket
                    if ($null -eq $socket) {
                        Start-Sleep -Milliseconds 10
                    }
                }

                #$socket = (Wait-PodeTask -Task $Listener.GetSocketAsync())
                'here3' | Out-Default

                #$stream = [System.Net.Sockets.NetworkStream]::new($socket, $false)
                #$encoder = New-Object System.Text.ASCIIEncoding
                #$buffer = $encoder.GetBytes("$($Message)`r`n")
                #$stream = $Client.GetStream()
                #Wait-PodeTask -Task $stream.WriteAsync($buffer, 0, $buffer.Length)
                #$stream.Flush()

                # close socket stream
                Close-PodeSocket -Socket $socket
                #Close-PodeDisposable -Disposable $socket -Close
                'here4' | Out-Default
            }
            'here5' | Out-Default
        }
        catch [System.OperationCanceledException] {}
        catch {
            'here6' | Out-Default
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'ThreadId' = $_ }
    }

    # script to keep web server listening until cancelled
    $waitScript = {
        try {
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
            if ($null -ne $PodeContext.Server.Sockets.Socket) {
                Close-PodeSocketListener
            }
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript

    # state where we're running
    Write-Host "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeContext.Threads) thread(s)]:" -ForegroundColor Yellow

    $endpoints | ForEach-Object {
        Write-Host "`t- $($_.HostName)" -ForegroundColor Yellow
    }

    # browse to the first endpoint, if flagged
    if ($Browse) {
        Start-Process $endpoints[0].HostName
    }
}