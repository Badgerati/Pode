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

    $PodeSession.ViewEngine.Extension = $Engine.ToLowerInvariant()
    $PodeSession.ViewEngine.Script = $ScriptBlock
}

function Start-WebServer
{
    param (
        [switch]
        $Https
    )

    $script = {
        param (
            [Parameter()]
            [boolean]
            $Https
        )

        try
        {
            # create the listener on http and/or https
            $listener = New-Object System.Net.HttpListener

            # grab the protocol
            $protocol = 'http'
            if ($Https) {
                $protocol = 'https'
            }

            # grab the ip address
            $_ip = "$($PodeSession.IP.Address)"
            if ($_ip -ieq '0.0.0.0') {
                $_ip = '*'
            }

            # grab the port
            $port = $PodeSession.IP.Port
            if ($port -eq 0) {
                $port = 8080
                if ($Https) {
                    $port = 8443
                }
            }

            $listener.Prefixes.Add("$($protocol)://$($_ip):$($port)/")

            # start listener
            $listener.Start()

            # state where we're running
            Write-Host "Listening on $($protocol)://$($PodeSession.IP.Name):$($port)/" -ForegroundColor Yellow

            # loop for http request
            while ($listener.IsListening)
            {
                # get request and response
                $task = $listener.GetContextAsync()
                $task.Wait($PodeSession.Tokens.Cancellation.Token)

                $context = $task.Result
                $request = $context.Request
                $response = $context.Response

                # clear session
                $PodeSession.Web = @{}
                $PodeSession.Web.Response = $response
                $PodeSession.Web.Request = $request
                $PodeSession.Web.Lockable = $PodeSession.Lockable

                # get url path and method
                $path = ($request.RawUrl -isplit "\?")[0]
                $method = $request.HttpMethod.ToLowerInvariant()

                # setup the base request to log later
                $logObject = @{
                    'Host' = $request.RemoteEndPoint.Address.IPAddressToString;
                    'RfcUserIdentity' = '-';
                    'User' = '-';
                    'Date' = [DateTime]::Now.ToString('dd/MMM/yyyy:HH:mm:ss zzz');
                    'Request' = @{
                        'Method' = $method.ToUpperInvariant();
                        'Resource' = $path;
                        'Protocol' = "HTTP/$($request.ProtocolVersion)";
                        'Referrer' = $request.UrlReferrer;
                        'Agent' = $request.UserAgent;
                    };
                    'Response' = @{
                        'StatusCode' = '-';
                        'StautsDescription' = '-'
                        'Size' = '-';
                    };
                }

                # ensure the request ip is allowed
                if (!(Test-ValueAccess -Type IP -Value $request.RemoteEndPoint.Address.IPAddressToString)) {
                    status 403
                }

                # check to see if the path is a file, so we can check the public folder
                elseif ((Split-Path -Leaf -Path $path).IndexOf('.') -ne -1) {
                    $path = Join-ServerRoot 'public' $path
                    Write-ToResponseFromFile -Path $path
                }

                else {
                    # ensure the path has a route
                    $route = Get-PodeRoute -HttpMethod $method -Route $path
                    if ($route -eq $null -or $route.Logic -eq $null) {
                        status 404
                    }

                    # run the scriptblock
                    else {
                        # read and parse any post data
                        $stream = $request.InputStream
                        $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $stream, $request.ContentEncoding
                        $data = $reader.ReadToEnd()
                        $reader.Close()

                        switch ($request.ContentType) {
                            { $_ -ilike '*json*' } {
                                $data = ($data | ConvertFrom-Json)
                            }

                            { $_ -ilike '*xml*' } {
                                $data = ($data | ConvertFrom-Xml)
                            }
                        }

                        # set session data
                        $PodeSession.Web.Data = $data
                        $PodeSession.Web.Query = $request.QueryString
                        $PodeSession.Web.Parameters = $route.Parameters

                        # invoke route
                        Invoke-ScriptBlock -ScriptBlock (($route.Logic).GetNewClosure()) -Arguments $PodeSession.Web -Scoped
                    }
                }

                # close response stream (check if exists, as closing the writer closes this stream on unix)
                if ($response.OutputStream) {
                    $response.OutputStream.Close()
                }

                # add the log object to the list
                $logObject.Response.StatusCode = $response.StatusCode
                $logObject.Response.StatusDescription = $response.StatusDescription

                if ($response.ContentLength64 -gt 0) {
                    $logObject.Response.Size = $response.ContentLength64
                }

                if (!$PodeSession.DisableLogging -and ($PodeSession.Loggers | Measure-Object).Count -gt 0) {
                    $PodeSession.RequestsToLog.Add($logObject) | Out-Null
                }
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
        finally {
            if ($listener -ne $null) {
                $listener.Stop()
                $listener.Close()
                $listener.Dispose()
            }
        }
    }

    Add-PodeRunspace $script -Parameters @{ 'Https' = [bool]$Https }
}