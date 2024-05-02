using namespace Pode

function Start-PodeTcpServer {
    # work out which endpoints to listen on
    $endpoints = @()

    @(Get-PodeEndpointInternal -Type Tcp) | ForEach-Object {
        # get the ip address
        $_ip = [string]($_.Address)
        $_ip = Get-PodeIPAddressesForHostname -Hostname $_ip -Type All | Select-Object -First 1
        $_ip = Get-PodeIPAddress $_ip -DualMode:($_.DualMode)

        # dual mode?
        $addrs = $_ip
        if ($_.DualMode) {
            $addrs = Resolve-PodeIPDualMode -IP $_ip
        }

        # the endpoint
        $_endpoint = @{
            Name                   = $_.Name
            Key                    = "$($_ip):$($_.Port)"
            Address                = $addrs
            Hostname               = $_.HostName
            IsIPAddress            = $_.IsIPAddress
            Port                   = $_.Port
            Certificate            = $_.Certificate.Raw
            AllowClientCertificate = $_.Certificate.AllowClientCertificate
            TlsMode                = $_.Certificate.TlsMode
            Url                    = $_.Url
            Protocol               = $_.Protocol
            Type                   = $_.Type
            Pool                   = $_.Runspace.PoolName
            Acknowledge            = $_.Tcp.Acknowledge
            CRLFMessageEnd         = $_.Tcp.CRLFMessageEnd
            SslProtocols           = $_.Ssl.Protocols
            DualMode               = $_.DualMode
        }

        # add endpoint to list
        $endpoints += $_endpoint
    }

    # create the listener
    $listener = [PodeListener]::new($PodeContext.Tokens.Cancellation.Token)
    $listener.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)
    $listener.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevel)
    $listener.RequestTimeout = $PodeContext.Server.Request.Timeout
    $listener.RequestBodySize = $PodeContext.Server.Request.BodySize

    try {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            $socket = [PodeSocket]::new($_.Name, $_.Address, $_.Port, $_.SslProtocols, [PodeProtocolType]::Tcp, $_.Certificate, $_.AllowClientCertificate, $_.TlsMode, $_.DualMode)
            $socket.ReceiveTimeout = $PodeContext.Server.Sockets.ReceiveTimeout
            $socket.AcknowledgeMessage = $_.Acknowledge
            $socket.CRLFMessageEnd = $_.CRLFMessageEnd

            if (!$_.IsIPAddress) {
                $socket.Hostnames.Add($_.HostName)
            }

            $listener.Add($socket)
        }

        $listener.Start()
        $PodeContext.Listeners += $listener
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $listener
        throw $_.Exception
    }

    # script for listening out of for incoming requests
    $listenScript = {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            $Listener,

            [Parameter(Mandatory = $true)]
            [int]
            $ThreadId
        )

        try {
            while ($Listener.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # get email
                $context = (Wait-PodeTask -Task $Listener.GetContextAsync($PodeContext.Tokens.Cancellation.Token))

                try {
                    try {
                        $Request = $context.Request
                        $Response = $context.Response

                        $TcpEvent = @{
                            Response   = $Response
                            Request    = $Request
                            Lockable   = $PodeContext.Threading.Lockables.Global
                            Endpoint   = @{
                                Protocol = $Request.Scheme
                                Address  = $Request.Address
                                Name     = $context.EndpointName
                            }
                            Parameters = $null
                            Timestamp  = [datetime]::UtcNow
                            Metadata   = @{}
                        }

                        # stop now if the request has an error
                        if ($Request.IsAborted) {
                            throw $Request.Error
                        }

                        # convert the ip
                        $ip = (ConvertTo-PodeIPAddress -Address $Request.RemoteEndPoint)

                        # ensure the request ip is allowed
                        if (!(Test-PodeIPAccess -IP $ip)) {
                            $Response.WriteLine('Your IP address was rejected', $true)
                            Close-PodeTcpClient
                            continue
                        }

                        # has the ip hit the rate limit?
                        if (!(Test-PodeIPLimit -IP $ip)) {
                            $Response.WriteLine('Your IP address has hit the rate limit', $true)
                            Close-PodeTcpClient
                            continue
                        }

                        # deal with tcp call and find the verb, and for the endpoint
                        if ([string]::IsNullOrEmpty($TcpEvent.Request.Body)) {
                            continue
                        }

                        $verb = Find-PodeVerb -Verb $TcpEvent.Request.Body -EndpointName $TcpEvent.Endpoint.Name
                        if ($null -eq $verb) {
                            $verb = Find-PodeVerb -Verb '*' -EndpointName $TcpEvent.Endpoint.Name
                        }

                        if ($null -eq $verb) {
                            continue
                        }

                        # set the route parameters
                        if ($verb.Verb -ine '*') {
                            $TcpEvent.Parameters = @{}
                            if ($TcpEvent.Request.Body -imatch "$($verb.Verb)$") {
                                $TcpEvent.Parameters = $Matches
                            }
                        }

                        # invoke it
                        if ($null -ne $verb.Logic) {
                            $null = Invoke-PodeScriptBlock -ScriptBlock $verb.Logic -Arguments $verb.Arguments -UsingVariables $verb.UsingVariables -Scoped -Splat
                        }

                        # is the verb auto-close?
                        if ($verb.Connection.Close) {
                            Close-PodeTcpClient
                            continue
                        }

                        # is the verb auto-upgrade to ssl?
                        if ($verb.Connection.UpgradeToSsl) {
                            $Request.UpgradeToSSL()
                        }
                    }
                    catch [System.OperationCanceledException] {
                        $_ | Write-PodeErrorLog -Level Debug
                    }
                    catch {
                        $_ | Write-PodeErrorLog
                        $_.Exception | Write-PodeErrorLog -CheckInnerException
                    }
                }
                finally {
                    $TcpEvent = $null
                    Close-PodeDisposable -Disposable $context
                }
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads.General | ForEach-Object {
        Add-PodeRunspace -Type Tcp -ScriptBlock $listenScript -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep tcp server listening until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            $Listener
        )

        try {
            while ($Listener.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
        finally {
            Close-PodeDisposable -Disposable $Listener
        }
    }

    Add-PodeRunspace -Type Tcp -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener } -NoProfile

    # state where we're running
    return @(foreach ($endpoint in $endpoints) {
            @{
                Url      = $endpoint.Url
                Pool     = $endpoint.Pool
                DualMode = $endpoint.DualMode
            }
        })
}
