function Engine
{
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Engine,

        [Parameter()]
        [scriptblock]
        $ScriptBlock = $null
    )

    $PodeSession.Server.ViewEngine.Extension = $Engine.ToLowerInvariant()
    $PodeSession.Server.ViewEngine.Script = $ScriptBlock
}

function Start-WebServer
{
    param (
        [switch]
        $Https
    )

    # grab the protocol
    $protocol = (iftet $Https 'https' 'http')

    # grab the ip address
    $_ip = "$($PodeSession.Server.IP.Address)"
    if ($_ip -ieq '0.0.0.0') {
        $_ip = '*'
    }

    # grab the port
    $port = $PodeSession.Server.IP.Port
    if ($port -eq 0) {
        $port = (iftet $Https 8443 8080)
    }

    # if it's https, generate a self-signed cert or bind an existing one
    if ($Https -and $PodeSession.Server.IP.Ssl) {
        New-PodeSelfSignedCertificate -IP $PodeSession.Server.IP.Address -Port $port -Certificate $PodeSession.Server.IP.Certificate.Name
    }

    # setup any inbuilt middleware
    $inbuilt_middleware = @(
        (Get-PodeAccessMiddleware),
        (Get-PodeLimitMiddleware),
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeQueryMiddleware)
    )

    $PodeSession.Server.Middleware = ($inbuilt_middleware + $PodeSession.Server.Middleware)

    # create the listener on http and/or https
    $listener = New-Object System.Net.HttpListener

    try
    {
        # start listening on ip:port
        $listener.Prefixes.Add("$($protocol)://$($_ip):$($port)/")
        $listener.Start()
    }
    catch {
        $Error[0] | Out-Default

        if ($null -ne $Listener) {
            if ($Listener.IsListening) {
                $Listener.Stop()
            }

            dispose $Listener -Close
        }

        throw $_.Exception
    }

    # state where we're running
    Write-Host "Listening on $($protocol)://$($PodeSession.Server.IP.Name):$($port)/ [$($PodeSession.Threads) thread(s)]" -ForegroundColor Yellow

    # script for listening out for incoming requests
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
            while ($Listener.IsListening -and !$PodeSession.Tokens.Cancellation.IsCancellationRequested)
            {
                # get request and response
                $task = $Listener.GetContextAsync()
                $task.Wait($PodeSession.Tokens.Cancellation.Token)

                $context = $task.Result
                $request = $context.Request
                $response = $context.Response

                # reset session data
                $WebSession = @{}
                $WebSession.Response = $response
                $WebSession.Request = $request
                $WebSession.Lockable = $PodeSession.Lockable
                $WebSession.Path = ($request.RawUrl -isplit "\?")[0]
                $WebSession.Method = $request.HttpMethod.ToLowerInvariant()

                # setup the base request to log later
                $logObject = New-PodeLogObject -Request $request -Path $WebSession.Path

                # invoke middleware
                $_midware = ($PodeSession.Server.Middleware).Logic
                if ((Invoke-PodeMiddleware -Session $WebSession -Middleware $_midware)) {
                    # get the route logic
                    $route = Get-PodeRoute -HttpMethod $WebSession.Method -Route $WebSession.Path
                    if ($null -eq $route) {
                        $route = Get-PodeRoute -HttpMethod '*' -Route $WebSession.Path
                    }

                    # invoke route and custom middleware
                    if ((Invoke-PodeMiddleware -Session $WebSession -Middleware $route.Middleware)) {
                        Invoke-ScriptBlock -ScriptBlock (($route.Logic).GetNewClosure()) -Arguments $WebSession -Scoped
                    }
                }

                # close response stream (check if exists, as closing the writer closes this stream on unix)
                if ($response.OutputStream) {
                    dispose $response.OutputStream -Close -CheckNetwork
                }

                # add the log object to the list
                Add-PodeLogObject -LogObject $logObject -Response $response
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeSession.Threads | ForEach-Object {
        Add-PodeRunspace -Type 'Main' -ScriptBlock $listenScript `
            -Parameters @{ 'Listener' = $listener; 'ThreadId' = $_ }
    }

    # script to keep web server listening until cancelled
    $waitScript = {
        param (
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Listener
        )

        try
        {
            while ($Listener.IsListening -and !$PodeSession.Tokens.Cancellation.IsCancellationRequested)
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
                if ($Listener.IsListening) {
                    $Listener.Stop()
                }

                dispose $Listener -Close
            }
        }
    }

    Add-PodeRunspace -Type 'Main' -ScriptBlock $waitScript -Parameters @{ 'Listener' = $listener }
}