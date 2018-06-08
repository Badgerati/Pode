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

        $listener.Prefixes.Add("$($protocol)://*:$($PodeSession.Port)/")

        # start listener
        $listener.Start()

        # state where we're running
        Write-Host "Listening on $($protocol)://localhost:$($PodeSession.Port)/" -ForegroundColor Yellow

        # loop for http request
        while ($listener.IsListening)
        {
            # get request and response
            $task = $listener.GetContextAsync()
            while (!$task.IsCompleted) {
                Start-Sleep -Milliseconds 1
                Test-CtrlCPressed
            }

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

            # check to see if the path is a file, so we can check the public folder
            if ((Split-Path -Leaf -Path $path).IndexOf('.') -ne -1) {
                $path = (Join-Path 'public' $path)
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
        }
    }
    finally {
        if ($listener -ne $null) {
            $listener.Stop()
        }
    }
}