function Start-PodeSocketServer
{
    param (
        [switch]
        $Browse
    )

    # setup any inbuilt middleware
    $inbuilt_middleware = @(
        (Get-PodeAccessMiddleware),
        (Get-PodeLimitMiddleware),
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeQueryMiddleware),
        (Get-PodeCookieMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

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

        # add endpoint to list
        $endpoints += @{
            Address = $_ip
            Port = $_port
            Certificate = $_.Certificate.Raw
            HostName = "$($_protocol)://$($_.HostName):$($_port)/"
        }
    }

    try
    {
        # register endpoints on the listener
        $endpoints | ForEach-Object {
            Initialize-PodeSocketListenerEndpoint -Address $_.Address -Port $_.Port -Certificate $_.Certificate
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        Close-PodeSocketListener
        throw $_.Exception
    }

    # script for listening out for incoming requests
    $listenScript = {
        param (
            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            # start the listener events
            if ($ThreadId -eq 1) {
                Register-PodeSocketListenerEvents
                Start-PodeSocketListener
            }

            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # wait for a socket to be connected
                $context = $null
                while ($null -eq $context) {
                    $context = Get-PodeSocketContext
                    if ($null -eq $context) {
                        Wait-PodeTask ([System.Threading.Tasks.Task]::Delay(10))
                    }
                }

                Invoke-PodeSocketHandler -Context $context
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            'LISTEN-EEK!' | Out-Default
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
            Close-PodeSocketListener
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

function Set-PodeServerResponseHeaders
{
    param(
        [Parameter(Mandatory=$true)]
        $WebEvent
    )

    # add content-type
    if (![string]::IsNullOrWhiteSpace($WebEvent.Response.ContentType)) {
        Set-PodeHeader -Name 'Content-Type' -Value $WebEvent.Response.ContentType
    }
    else {
        $WebEvent.Response.Headers.Remove('Content-Type')
    }

    # add content-length
    if ($WebEvent.Response.ContentLength64 -gt 0) {
        Set-PodeHeader -Name 'Content-Length' -Value $WebEvent.Response.ContentLength64
    }
    else {
        $WebEvent.Response.Headers.Remove('Content-Length')
    }

    # add the date of the response
    Set-PodeHeader -Name 'Date' -Value ([DateTime]::UtcNow.ToString("r", [CultureInfo]::InvariantCulture))

    # state to close the connection (no support for keep-alive yet)
    Set-PodeHeader -Name 'Connection' -Value 'Close'
}

function Get-PodeServerRequestDetails
{
    param(
        [Parameter()]
        [string]
        $Content,

        [Parameter(Mandatory=$true)]
        [string]
        $Protocol
    )

    # parse the request headers
    $req_lines = ($Content -isplit [System.Environment]::NewLine)

    # first line is the request info
    $req_line_info = ($req_lines[0] -isplit '\s+')
    $req_method = $req_line_info[0]
    $req_query = $req_line_info[1]
    $req_proto = $req_line_info[2]

    # then, read the headers
    $req_headers = @{}
    $req_body_index = 0
    for ($i = 1; $i -le $req_lines.Length -1; $i++) {
        $line = $req_lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) {
            $req_body_index = $i + 1
            break
        }

        $index = $line.IndexOf(':')
        $name = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1).Trim()
        $req_headers[$name] = $value
    }

    # then set the request body
    $req_body = ($req_lines[($req_body_index)..($req_lines.Length - 1)] -join [System.Environment]::NewLine)

    # build required URI details
    $req_uri = [uri]::new("$($Protocol)://$($req_headers['Host'])$($req_query)")

    # return the details
    return @{
        Method = $req_method
        Query = $req_query
        Protocol = $req_proto
        Headers = $req_headers
        Body = $req_body
        Uri = $req_uri
    }
}