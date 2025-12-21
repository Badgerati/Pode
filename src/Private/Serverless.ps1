function Start-PodeAzFuncServer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    param(
        [Parameter(Mandatory = $true)]
        $Data
    )

    # setup any inbuilt middleware that works for azure functions
    $inbuilt_middleware = @(
        (Get-PodeSecurityMiddleware),
        (Get-PodeFaviconMiddleware),
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeCookieMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

    try {
        try {
            # get the request
            $request = $Data.Request

            # setup the response
            $response = New-PodeAzFuncResponse
            $response.StatusCode = 200
            $response.Headers = @{}

            # reset event data
            $global:WebEvent = @{
                OnEnd            = @()
                Auth             = @{}
                Response         = $response
                Request          = $request
                Lockable         = $PodeContext.Threading.Lockables.Global
                Path             = [string]::Empty
                Method           = $request.Method.ToLowerInvariant()
                Query            = $request.Query
                Endpoint         = @{
                    Protocol = ($request.Url -split '://')[0]
                    Address  = $null
                    Name     = $null
                }
                ContentType      = $null
                ErrorType        = $null
                Cookies          = @{}
                PendingCookies   = @{}
                Parameters       = $null
                Data             = $null
                Files            = $null
                Streamed         = $false
                Route            = $null
                StaticContent    = $null
                Timestamp        = [datetime]::UtcNow
                TransferEncoding = $null
                AcceptEncoding   = $null
                Ranges           = $null
                Metadata         = @{}
            }

            $global:WebEvent.Endpoint.Address = ((Get-PodeHeader -Name 'host') -split ':')[0]
            $global:WebEvent.ContentType = (Get-PodeHeader -Name 'content-type')

            # set the path, using static content query parameter if passed
            if (![string]::IsNullOrWhiteSpace($request.Query['static-file'])) {
                $global:WebEvent.Path = $request.Query['static-file']
            }
            else {
                $funcName = $Data.sys.MethodName
                if ([string]::IsNullOrWhiteSpace($funcName)) {
                    $funcName = $Data.FunctionName
                }

                $global:WebEvent.Path = "/api/$($funcName)"
            }

            $global:WebEvent.Path = [System.Web.HttpUtility]::UrlDecode($global:WebEvent.Path)

            # set pode in server response header
            Set-PodeServerHeader -Type 'Kestrel'

            # invoke global and route middleware
            if ((Invoke-PodeMiddleware -Middleware $PodeContext.Server.Middleware -Route $global:WebEvent.Path)) {
                if ((Invoke-PodeMiddleware -Middleware $global:WebEvent.Route.Middleware)) {
                    # invoke the route
                    if ($null -ne $global:WebEvent.StaticContent) {
                        $fileBrowser = $global:WebEvent.Route.FileBrowser
                        if ($global:WebEvent.StaticContent.IsDownload) {
                            Write-PodeAttachmentResponseInternal -FileInfo $global:WebEvent.StaticContent.FileInfo -FileBrowser:$fileBrowser
                        }
                        elseif ($global:WebEvent.StaticContent.RedirectToDefault) {
                            $file = [System.IO.Path]::GetFileName($global:WebEvent.StaticContent.Source)
                            Move-PodeResponseUrl -Url "$($global:WebEvent.Path)/$($file)"
                        }
                        else {
                            $cachable = $global:WebEvent.StaticContent.IsCachable
                            Write-PodeFileResponseInternal -FileInfo $global:WebEvent.StaticContent.FileInfo -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge -Cache:$cachable -FileBrowser:$fileBrowser
                        }
                    }
                    else {
                        $null = Invoke-PodeScriptBlock -ScriptBlock $global:WebEvent.Route.Logic -Arguments $global:WebEvent.Route.Arguments -UsingVariables $global:WebEvent.Route.UsingVariables -Scoped -Splat
                    }
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            Set-PodeResponseStatus -Code 500 -Exception $_
        }
        finally {
            Update-PodeServerRequestMetric -WebEvent $global:WebEvent
        }

        # invoke endware specific to the current web event
        $_endware = ($global:WebEvent.OnEnd + @($PodeContext.Server.Endware))
        Invoke-PodeEndware -Endware $_endware

        # close and send the response
        Push-OutputBinding -Name Response -Value $response
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
    finally {
        $global:WebEvent = $null
    }
}

function New-PodeAzFuncResponse {
    return [HttpResponseContext]::new()
}

function Start-PodeAwsLambdaServer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    param(
        [Parameter(Mandatory = $true)]
        $Data
    )

    # setup any inbuilt middleware that works for aws lambda
    $inbuilt_middleware = @(
        (Get-PodeSecurityMiddleware),
        (Get-PodeFaviconMiddleware),
        (Get-PodePublicMiddleware),
        (Get-PodeRouteValidateMiddleware),
        (Get-PodeBodyMiddleware),
        (Get-PodeCookieMiddleware)
    )

    $PodeContext.Server.Middleware = ($inbuilt_middleware + $PodeContext.Server.Middleware)

    try {
        try {
            # get the request
            $request = $Data

            # setup the response
            $response = @{
                StatusCode = 200
                Headers    = @{}
                Body       = [string]::Empty
            }

            # reset event data
            $global:WebEvent = @{
                OnEnd            = @()
                Auth             = @{}
                Response         = $response
                Request          = $request
                Lockable         = $PodeContext.Threading.Lockables.Global
                Path             = [System.Web.HttpUtility]::UrlDecode($request.path)
                Method           = $request.httpMethod.ToLowerInvariant()
                Query            = $request.queryStringParameters
                Endpoint         = @{
                    Protocol = $null
                    Address  = $null
                    Name     = $null
                }
                ContentType      = $null
                ErrorType        = $null
                Cookies          = @{}
                PendingCookies   = @{}
                Parameters       = $null
                Data             = $null
                Files            = $null
                Streamed         = $false
                Route            = $null
                StaticContent    = $null
                Timestamp        = [datetime]::UtcNow
                TransferEncoding = $null
                AcceptEncoding   = $null
                Ranges           = $null
                Metadata         = @{}
            }

            $global:WebEvent.Endpoint.Protocol = (Get-PodeHeader -Name 'X-Forwarded-Proto')
            $global:WebEvent.Endpoint.Address = ((Get-PodeHeader -Name 'Host') -split ':')[0]
            $global:WebEvent.ContentType = (Get-PodeHeader -Name 'Content-Type')

            # set pode in server response header
            Set-PodeServerHeader -Type 'Lambda'

            # invoke global and route middleware
            if ((Invoke-PodeMiddleware -Middleware $PodeContext.Server.Middleware -Route $global:WebEvent.Path)) {
                if ((Invoke-PodeMiddleware -Middleware $global:WebEvent.Route.Middleware)) {
                    # invoke the route
                    if ($null -ne $global:WebEvent.StaticContent) {
                        $fileBrowser = $global:WebEvent.Route.FileBrowser
                        if ($global:WebEvent.StaticContent.IsDownload) {
                            Write-PodeAttachmentResponseInternal -FileInfo $global:WebEvent.StaticContent.FileInfo -FileBrowser:$fileBrowser
                        }
                        elseif ($global:WebEvent.StaticContent.RedirectToDefault) {
                            $file = [System.IO.Path]::GetFileName($global:WebEvent.StaticContent.Source)
                            Move-PodeResponseUrl -Url "$($global:WebEvent.Path)/$($file)"
                        }
                        else {
                            $cachable = $global:WebEvent.StaticContent.IsCachable
                            Write-PodeFileResponseInternal -FileInfo $global:WebEvent.StaticContent.FileInfo -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge -Cache:$cachable -FileBrowser:$fileBrowser
                        }
                    }
                    else {
                        $null = Invoke-PodeScriptBlock -ScriptBlock $global:WebEvent.Route.Logic -Arguments $global:WebEvent.Route.Arguments -UsingVariables $global:WebEvent.Route.UsingVariables -Scoped -Splat
                    }
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            Set-PodeResponseStatus -Code 500 -Exception $_
        }
        finally {
            Update-PodeServerRequestMetric -WebEvent $global:WebEvent
        }

        # invoke endware specific to the current web event
        $_endware = ($global:WebEvent.OnEnd + @($PodeContext.Server.Endware))
        Invoke-PodeEndware -Endware $_endware

        # close and send the response
        if (![string]::IsNullOrWhiteSpace($response.ContentType)) {
            Set-PodeHeader -Name 'Content-Type' -Value $response.ContentType
        }

        return (@{
                'statusCode' = $response.StatusCode
                'headers'    = $response.Headers
                'body'       = $response.Body
            } | ConvertTo-Json -Depth 10 -Compress)
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
    finally {
        $global:WebEvent = $null
    }
}