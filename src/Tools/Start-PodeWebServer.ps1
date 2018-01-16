function Set-PodeViewEngine
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('HTML', 'PSHTML')]
        [string]
        $Engine
    )

    $PodeSession.ViewEngine = $Engine
}

function Start-PodeWebServer
{
    param (
        [switch]
        $Https
    )

    try
    {
        # create the listener on http and/or https
        $listener = New-Object System.Net.HttpListener

        if ($Https)
        {
            $listener.Prefixes.Add("https://*:$($PodeSession.Port)/")
        }
        else
        {
            $listener.Prefixes.Add("http://*:$($PodeSession.Port)/")
        }

        # start listener
        $listener.Start()

        # state where we're running
        Write-Host "Listening on http://localhost:$($PodeSession.Port)/" -ForegroundColor Yellow
        [Console]::TreatControlCAsInput = $true

        # loop for http request
        while ($listener.IsListening)
        {
            # get request and response
            $task = $listener.GetContextAsync()
            while (!$task.IsCompleted)
            {
                if ([Console]::KeyAvailable)
                {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -ieq 'c' -and $key.Modifiers -band [ConsoleModifiers]::Control)
                    {
                        Write-Host 'Terminating...'
                        return
                    }
                }
            }

            $context = $task.Result

            # clear session
            $PodeSession.Web = @{}

            $request = $context.Request
            $response = $context.Response

            # get url path and method
            $path = ($request.RawUrl -isplit "\?")[0]
            $method = $request.HttpMethod.ToLowerInvariant()

            # check to see if the path is a file, so we can check the public folder
            if ((Split-Path -Leaf -Path $path).IndexOf('.') -ne -1)
            {
                $path = (Join-Path 'public' $path)
                Write-ToResponseFromFile $path $response
            }

            else
            {
                # ensure the path has a route
                if ($PodeSession.Routes[$method][$path] -eq $null)
                {
                    $response.StatusCode = 404
                }

                # run the scriptblock
                else
                {
                    # read and parse any post data
                    $stream = $request.InputStream
                    $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList $stream, $request.ContentEncoding
                    $data = $reader.ReadToEnd()
                    $reader.Close()

                    switch ($request.ContentType)
                    {
                        { $_ -ilike '*json*' }
                            {
                                $data = ($data | ConvertFrom-Json)
                            }

                        { $_ -ilike '*xml*' }
                            {
                                $data = ($data | ConvertFrom-Xml)
                            }
                    }

                    # set session data
                    $PodeSession.Web.Response = $response
                    $PodeSession.Web.Request = $request
                    $PodeSession.Web.Data = $data

                    # invoke route
                    Invoke-Command -ScriptBlock $PodeSession.Routes[$method][$path] -ArgumentList $PodeSession.Web
                }
            }

            # close response stream (check if exists, as closing the writer closes this stream on unix)
            if ($response.OutputStream)
            {
                $response.OutputStream.Close()
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