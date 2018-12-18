function Engine
{
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('t')]
        [string]
        $Engine,

        [Parameter()]
        [Alias('s')]
        [scriptblock]
        $ScriptBlock = $null,

        [Parameter()]
        [Alias('ext')]
        [string]
        $Extension
    )

    if ([string]::IsNullOrWhiteSpace($Extension)) {
        $Extension = $Engine.ToLowerInvariant()
    }

    $PodeSession.Server.ViewEngine.Engine = $Engine.ToLowerInvariant()
    $PodeSession.Server.ViewEngine.Extension = $Extension
    $PodeSession.Server.ViewEngine.Script = $ScriptBlock
}

function Start-WebServer
{
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

    # work out which endpoints to listen on
    $endpoints = @()
    $PodeSession.Server.Endpoints | ForEach-Object {
        # get the protocol
        $_protocol = (iftet $_.Ssl 'https' 'http')

        # get the ip address
        $_ip = "$($_.Address)"
        if ($_ip -ieq '0.0.0.0') {
            $_ip = '*'
        }

        # get the port
        $_port = [int]($_.Port)
        if ($_port -eq 0) {
            $_port = (iftet $_.Ssl 8443 8080)
        }

        # if this endpoint is https, generate a self-signed cert or bind an existing one
        if ($_.Ssl) {
            New-PodeSelfSignedCertificate -IP $_.Address -Port $_port -Certificate $_.Certificate.Name
        }

        # add endpoint to list
        $endpoints += @{
            'Prefix' = "$($_protocol)://$($_ip):$($_port)/";
            'Name' = "$($_protocol)://$($_.Name):$($_port)/";
        }
    }

    # create the listener on http and/or https
    $listener = New-Object System.Net.HttpListener

    try
    {
        # start listening on defined endpoints
        $endpoints | ForEach-Object {
            $listener.Prefixes.Add($_.Prefix)
        }

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
    Write-Host "Listening on the following $($endpoints.Length) endpoint(s) [$($PodeSession.Threads) thread(s)]:" -ForegroundColor Yellow

    $endpoints | ForEach-Object {
        Write-Host "`t- $($_.Name)" -ForegroundColor Yellow
    }

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

                try
                {
                    $context = $task.Result
                    $request = $context.Request
                    $response = $context.Response

                    # reset event data
                    $WebEvent = @{}
                    $WebEvent.OnEnd = @()
                    $WebEvent.Auth = @{}
                    $WebEvent.Response = $response
                    $WebEvent.Request = $request
                    $WebEvent.Lockable = $PodeSession.Lockable
                    $WebEvent.Path = ($request.RawUrl -isplit "\?")[0]
                    $WebEvent.Method = $request.HttpMethod.ToLowerInvariant()
                    $WebEvent.Protocol = $request.Url.Scheme
                    $WebEvent.Endpoint = $request.Url.Authority

                    # add logging endware for post-request
                    Add-PodeLogEndware -WebEvent $WebEvent

                    # invoke middleware
                    if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $PodeSession.Server.Middleware -Route $WebEvent.Path)) {
                        # get the route logic
                        $route = Get-PodeRoute -HttpMethod $WebEvent.Method -Route $WebEvent.Path -Protocol $WebEvent.Protocol `
                            -Endpoint $WebEvent.Endpoint -CheckWildMethod

                        # invoke route and custom middleware
                        if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $route.Middleware)) {
                            Invoke-ScriptBlock -ScriptBlock $route.Logic -Arguments $WebEvent -Scoped
                        }
                    }
                }
                catch {
                    status 500
                    $Error[0] | Out-Default
                }

                # invoke endware specifc to the current web event
                $_endware = ($WebEvent.OnEnd + @($PodeSession.Server.Endware))
                Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

                # close response stream (check if exists, as closing the writer closes this stream on unix)
                if ($response.OutputStream) {
                    dispose $response.OutputStream -Close -CheckNetwork
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