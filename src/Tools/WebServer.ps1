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

    $PodeSession.ViewEngine = @{
        'Extension' = $Engine.ToLowerInvariant();
        'Script' = $ScriptBlock;
    }
}

function Start-WebServer
{
    param (
        [switch]
        $Https
    )

    try
    {
        # create the listener on http and/or https
        $listener = New-Object System.Net.HttpListener
        $protocol = 'http'
        if ($Https) {
            $protocol = 'https'
        }

        $_ip = "$($PodeSession.IP.Address)"
        if ($_ip -ieq '0.0.0.0') {
            $_ip = '*'
        }

        $listener.Prefixes.Add("$($protocol)://$($_ip):$($PodeSession.Port)/")

        # start listener
        $listener.Start()

        # state where we're running
        Write-Host "Listening on $($protocol)://$($PodeSession.IP.Name):$($PodeSession.Port)/" -ForegroundColor Yellow

        # loop for http request
        while ($listener.IsListening)
        {
            # get request and response
            $task = $listener.GetContextAsync()
            $task.Wait($PodeSession.CancelToken.Token)

            $context = $task.Result
            $request = $context.Request
            $response = $context.Response

            # clear session
            $PodeSession.Web = @{}
            $PodeSession.Web.Response = $response
            $PodeSession.Web.Request = $request

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

            # check to see if the path is a file, so we can check the public folder
            if ((Split-Path -Leaf -Path $path).IndexOf('.') -ne -1) {
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
                    Invoke-Command -ScriptBlock $route.Logic -ArgumentList $PodeSession.Web
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

            $PodeSession.RequestsToLog.Add($logObject) | Out-Null
        }
    }
    catch [System.OperationCanceledException] {
        Close-Pode -Exit
    }
    finally {
        if ($listener -ne $null) {
            $listener.Stop()
        }
    }
}