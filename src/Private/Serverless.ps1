function Start-PodeAzFuncServer
{
    param (
        [Parameter(Mandatory=$true)]
        $Data
    )

    # setup any inbuilt middleware that works for azure functions
    $inbuilt_middleware = @(
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeCookieMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

    try
    {
        try
        {
            # get the request
            $request = $Data.Request

            # setup the response
            $response = New-Object -TypeName HttpResponseContext
            $response.StatusCode = 200
            $response.Headers = @{}

            # reset event data
            $WebEvent = @{
                OnEnd = @()
                Auth = @{}
                Response = $response
                Request = $request
                Lockable = $PodeContext.Lockable
                Method = $request.Method.ToLowerInvariant()
                Query = $request.Query
                Protocol = ($request.Url -split '://')[0]
                Endpoint = ((Get-PodeHeader -Name 'host') -split ':')[0]
                ContentType = (Get-PodeHeader -Name 'content-type')
                ErrorType = $null
                Cookies = @{}
                PendingCookies = @{}
                Path = [string]::Empty
            }

            # set the path, using static content query parameter if passed
            if (![string]::IsNullOrWhiteSpace($request.Query['static-file'])) {
                $WebEvent.Path = $request.Query['static-file']
            }
            else {
                $WebEvent.Path = "/api/$($Data.sys.MethodName)"
            }

            # set pode in server response header
            Set-PodeServerHeader -Type 'Kestrel'

            # invoke middleware
            if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
                # get the route logic
                $route = Get-PodeRoute -Method $WebEvent.Method -Route $WebEvent.Path -Protocol $WebEvent.Protocol `
                    -Endpoint $WebEvent.Endpoint -CheckWildMethod

                # invoke route and custom middleware
                if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $route.Middleware)) {
                    Invoke-PodeScriptBlock -ScriptBlock $route.Logic -Arguments $WebEvent -Scoped
                }
            }
        }
        catch {
            Set-PodeResponseStatus -Code 500 -Exception $_
            Write-Host $Error[0]
        }

        # invoke endware specifc to the current web event
        $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
        Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

        # close and send the response
        Push-OutputBinding -Name Response -Value $response
    }
    catch {
        Write-Host $Error[0]
        throw $_.Exception
    }
}

function Start-PodeAwsLambdaServer
{
    param (
        [Parameter(Mandatory=$true)]
        $Data
    )

    # setup any inbuilt middleware that works for aws lambda
    $inbuilt_middleware = @(
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeCookieMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

    try
    {
        try
        {
            # get the request
            $request = $Data

            # setup the response
            $response = @{
                StatusCode = 200
                Headers = @{}
                Body = [string]::Empty
            }

            # reset event data
            $WebEvent = @{
                OnEnd = @()
                Auth = @{}
                Response = $response
                Request = $request
                Lockable = $PodeContext.Lockable
                Path = $request.path
                Method = $request.httpMethod.ToLowerInvariant()
                Query = $request.queryStringParameters
                Protocol = (Get-PodeHeader -Name 'X-Forwarded-Proto')
                Endpoint = ((Get-PodeHeader -Name 'Host') -split ':')[0]
                ContentType = (Get-PodeHeader -Name 'Content-Type')
                ErrorType = $null
                Cookies = @{}
                PendingCookies = @{}
            }

            # set pode in server response header
            Set-PodeServerHeader -Type 'Lambda'

            # invoke middleware
            if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $PodeContext.Server.Middleware -Route $WebEvent.Path)) {
                # get the route logic
                $route = Get-PodeRoute -Method $WebEvent.Method -Route $WebEvent.Path -Protocol $WebEvent.Protocol `
                    -Endpoint $WebEvent.Endpoint -CheckWildMethod

                # invoke route and custom middleware
                if ((Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware $route.Middleware)) {
                    Invoke-PodeScriptBlock -ScriptBlock $route.Logic -Arguments $WebEvent -Scoped
                }
            }
        }
        catch {
            Set-PodeResponseStatus -Code 500 -Exception $_
            Write-Host $Error[0]
        }

        # invoke endware specifc to the current web event
        $_endware = ($WebEvent.OnEnd + @($PodeContext.Server.Endware))
        Invoke-PodeEndware -WebEvent $WebEvent -Endware $_endware

        # close and send the response
        if (![string]::IsNullOrWhiteSpace($response.ContentType)) {
            Set-PodeHeader -Name 'Content-Type' -Value $response.ContentType
        }

        return (@{
            'statusCode' = $response.StatusCode;
            'headers' = $response.Headers;
            'body' = $response.Body;
        } | ConvertTo-Json -Depth 10 -Compress) 
    }
    catch {
        Write-Host $Error[0]
        throw $_.Exception
    }
}