using namespace System.Security.Cryptography

function Invoke-PodeMiddleware {
    param(
        [Parameter()]
        $Middleware,

        [Parameter()]
        [string]
        $Route
    )

    # if there's no middleware, do nothing
    if (($null -eq $Middleware) -or ($Middleware.Length -eq 0)) {
        return $true
    }

    # filter the middleware down by route (retaining order)
    if (![string]::IsNullOrWhiteSpace($Route)) {
        $Middleware = @(foreach ($mware in $Middleware) {
                if ($null -eq $mware) {
                    continue
                }

                if ([string]::IsNullOrWhiteSpace($mware.Route) -or ($mware.Route -ieq '/') -or ($mware.Route -ieq $Route) -or ($Route -imatch "^$($mware.Route)$")) {
                    $mware
                }
            })
    }

    # continue or halt?
    $continue = $true

    # loop through each of the middleware, invoking the next if it returns true
    foreach ($midware in @($Middleware)) {
        if (($null -eq $midware) -or ($null -eq $midware.Logic)) {
            continue
        }

        try {
            $continue = Invoke-PodeScriptBlock -ScriptBlock $midware.Logic -Arguments $midware.Arguments -UsingVariables $midware.UsingVariables -Return -Scoped -Splat
            if ($null -eq $continue) {
                $continue = $true
            }
        }
        catch {
            Set-PodeResponseStatus -Code 500 -Exception $_
            $continue = $false
            $_ | Write-PodeErrorLog
        }

        if (!$continue) {
            break
        }
    }

    return $continue
}

function New-PodeMiddlewareInternal {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $PSSession
    )

    if (Test-PodeIsEmpty $ScriptBlock) {
        # No ScriptBlock supplied
        throw ($PodeLocale.noScriptBlockSuppliedExceptionMessage)
    }

    # if route is empty, set it to root
    $Route = ConvertTo-PodeRouteRegex -Path $Route

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSSession

    # create the middleware hashtable from a scriptblock
    $HashTable = @{
        Route          = $Route
        Logic          = $ScriptBlock
        Arguments      = $ArgumentList
        UsingVariables = $usingVars
    }

    # return the middleware, so it can be cached/added at a later date
    return $HashTable
}

function Get-PodeInbuiltMiddleware {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # check if middleware contains an override
    $override = ($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name })

    # if override there, remove it from middleware
    if ($override) {
        $PodeContext.Server.Middleware = @($PodeContext.Server.Middleware | Where-Object { $_.Name -ine $Name })
        $ScriptBlock = $override.Logic
    }

    # return the script
    return @{
        Name  = $Name
        Logic = $ScriptBlock
    }
}

function Get-PodeAccessMiddleware {
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_access__' -ScriptBlock {
            # are there any rules?
            if ($PodeContext.Server.Limits.Access.Rules.Count -eq 0) {
                return $true
            }

            # generate the rule order, if rules have been altered
            if ($PodeContext.Server.Limits.Access.RulesAltered) {
                $PodeContext.Server.Limits.Access.RulesOrder = $PodeContext.Server.Limits.Access.Rules.Values |
                    Sort-Object -Property { $_.Priority } -Descending |
                    Select-Object -ExpandProperty Name
                $PodeContext.Server.Limits.Access.RulesAltered = $false
            }

            # loop through each access rule
            foreach ($ruleName in $PodeContext.Server.Limits.Access.RulesOrder) {
                $rule = $PodeContext.Server.Limits.Access.Rules[$ruleName]

                # loop through each component of the rule, checking if the request matches
                $skip = $false
                foreach ($component in $rule.Components) {
                    $result = Invoke-PodeScriptBlock -ScriptBlock $component.ScriptBlock -Arguments $component.Options -Return

                    # if result is null/empty then move to the next rule
                    if ([string]::IsNullOrWhiteSpace($result)) {
                        $skip = $true
                        break
                    }
                }

                # if we skipped the rule, then move to the next one
                if ($skip) {
                    continue
                }

                # if we get here, then the request matches all the components - so allow or deny the request
                if ($rule.Action -ieq 'Allow') {
                    return $true
                }
                else {
                    Set-PodeResponseStatus -Code $rule.StatusCode
                    return $false
                }
            }

            # if we get here, then the request didn't match any rules
            # if we have any allow rules, then deny the request
            if ($PodeContext.Server.Limits.Access.HaveAllowRules) {
                Set-PodeResponseStatus -Code 403
                return $false
            }

            return $true
        })
}

<#
.SYNOPSIS
Retrieves the rate limit middleware for Pode.

.DESCRIPTION
This function returns the inbuilt rate limit middleware for Pode.
It checks if the request IP address, route, and endpoint have hit their respective rate limits.
If any of these checks fail, a 429 status code is set, and the request is denied.

.EXAMPLE
Get-PodeLimitMiddleware
Retrieves the rate limit middleware and adds it to the middleware pipeline.

.RETURNS
[ScriptBlock] - Returns a script block that represents the rate limit middleware.

.NOTES
This is an internal function and may change in future releases of Pode.
#>
function Get-PodeLimitMiddleware {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_rate_limit__' -ScriptBlock {
            # are there any rate rules?
            if ($PodeContext.Server.Limits.Rate.Rules.Count -eq 0) {
                return $true
            }

            # generate the rule order, if rules have been altered
            if ($PodeContext.Server.Limits.Rate.RulesAltered) {
                $PodeContext.Server.Limits.Rate.RulesOrder = $PodeContext.Server.Limits.Rate.Rules.Values |
                    Sort-Object -Property { $_.Priority } -Descending |
                    Select-Object -ExpandProperty Name
                $PodeContext.Server.Limits.Rate.RulesAltered = $false
            }

            # loop through each rate rule
            foreach ($ruleName in $PodeContext.Server.Limits.Rate.RulesOrder) {
                $rule = $PodeContext.Server.Limits.Rate.Rules[$ruleName]
                $ruleKey = @()
                $now = [DateTime]::UtcNow

                # loop through each component of the rule
                $skip = $false
                foreach ($component in $rule.Components) {
                    $result = Invoke-PodeScriptBlock -ScriptBlock $component.ScriptBlock -Arguments $component.Options -Return

                    # if result is null/empty then move to the next rule
                    if ([string]::IsNullOrWhiteSpace($result)) {
                        $skip = $true
                        break
                    }

                    # add the result to the rule key
                    $ruleKey += $result
                }

                # if we skipped the rule, then move to the next one
                if ($skip) {
                    continue
                }

                # concatenate the rule key
                $ruleKey = $ruleKey -join '|'

                # if it's not in the active dictionary, or the timeout has passed, then add/reset it
                if (!$rule.Active.ContainsKey($ruleKey) -or ($rule.Active[$ruleKey].Timeout -le $now)) {
                    $rule.Active[$ruleKey] = @{
                        Timeout = $now.AddMilliseconds($rule.Duration)
                        Counter = 0
                    }
                }

                # increment the counter
                $rule.Active[$ruleKey].Counter++

                # if the key is in the active dictionary, then check the timeout/counter and set the status code if needed
                if ($rule.Active.ContainsKey($ruleKey) -and
                    ($rule.Active[$ruleKey].Timeout -gt $now) -and
                    ($rule.Active[$ruleKey].Counter -ge $rule.Limit)) {
                    $retryAfter = [int][System.Math]::Ceiling(($rule.Active[$ruleKey].Timeout - $now).TotalSeconds)
                    Set-PodeHeader -Name 'Retry-After' -Value $retryAfter
                    Set-PodeResponseStatus -Code $rule.StatusCode
                    return $false
                }
            }

            # request is allowed
            return $true
        })
}

<#
.SYNOPSIS
    Retrieves middleware for serving public static content in a Pode web server.
.DESCRIPTION
    This function retrieves middleware for serving public static content in a Pode web server.
    It searches for static content based on the requested path and serves it if found.
.PARAMETER WebEvent
    The PodeWebEvent object representing the incoming web request.
.PARAMETER PodeContext
    The PodeContext object representing the current Pode server context.
.EXAMPLE
    Get-PodePublicMiddleware
    Retrieves middleware for serving public static content.
#>
function Get-PodePublicMiddleware {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_static_content__' -ScriptBlock {
            # only find public static content here
            $path = Find-PodePublicRoute -Path $WebEvent.Path
            if ([string]::IsNullOrWhiteSpace($path)) {
                return $true
            }

            # check current state of caching
            $cachable = Test-PodeRouteValidForCaching -Path $WebEvent.Path

            # write the file to the response
            Write-PodeFileResponse -Path $path -MaxAge $PodeContext.Server.Web.Static.Cache.MaxAge -Cache:$cachable

            # public static content found, stop
            return $false
        })
}

<#
.SYNOPSIS
    Middleware function to validate the route for an incoming web request.

.DESCRIPTION
    This function is used as middleware to validate the route for an incoming web request. It checks if the route exists for the requested method and path. If the route does not exist, it sets the appropriate response status code (404 for not found, 405 for method not allowed) and returns false to halt further processing. If the route exists, it sets various properties on the WebEvent object, such as parameters, content type, and transfer encoding, and returns true to continue processing.

.PARAMETER None

.EXAMPLE
    $middleware = Get-PodeRouteValidateMiddleware
    Add-PodeMiddleware -Middleware $middleware

.NOTES
    This function is part of the internal Pode server logic and is typically not called directly by users.

#>
function Get-PodeRouteValidateMiddleware {
    return @{
        Name  = '__pode_mw_route_validation__'
        Logic = {
            if ($PodeContext.Server.Web.Static.ValidateLast) {
                #  check the main routes and check the static routes
                $route = Find-PodeRoute -Method $WebEvent.Method -Path $WebEvent.Path -EndpointName $WebEvent.Endpoint.Name -CheckWildMethod
                if ($null -eq $route) {
                    $route = Find-PodeStaticRoute -Path $WebEvent.Path -EndpointName $WebEvent.Endpoint.Name
                }
            }
            else {
                # check if the path is static route first, then check the main routes
                $route = Find-PodeStaticRoute -Path $WebEvent.Path -EndpointName $WebEvent.Endpoint.Name
                if ($null -eq $route) {
                    $route = Find-PodeRoute -Method $WebEvent.Method -Path $WebEvent.Path -EndpointName $WebEvent.Endpoint.Name -CheckWildMethod
                }
            }

            # if there's no route defined, it's a 404 - or a 405 if a route exists for any other method
            if ($null -eq $route) {
                # check if a route exists for another method
                $methods = @('CONNECT', 'DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE')
                $diff_route = @(foreach ($method in $methods) {
                        $r = Find-PodeRoute -Method $method -Path $WebEvent.Path -EndpointName $WebEvent.Endpoint.Name
                        if ($null -ne $r) {
                            $r
                            break
                        }
                    })[0]

                if ($null -ne $diff_route) {
                    Set-PodeResponseStatus -Code 405
                    return $false
                }

                # otheriwse, it's a 404
                Set-PodeResponseStatus -Code 404
                return $false
            }

            # check if static and split
            if ($null -ne $route.Content) {
                $WebEvent.StaticContent = $route.Content
                $route = $route.Route
            }

            # set the route parameters
            $WebEvent.Parameters = @{}
            if ($WebEvent.Path -imatch "$($route.Path)$") {
                $WebEvent.Parameters = $Matches
            }

            # set the route on the WebEvent
            $WebEvent.Route = $route

            # override the content type from the route if it's not empty
            if (![string]::IsNullOrWhiteSpace($route.ContentType)) {
                $WebEvent.ContentType = $route.ContentType
            }

            # override the transfer encoding from the route if it's not empty
            if (![string]::IsNullOrWhiteSpace($route.TransferEncoding)) {
                $WebEvent.TransferEncoding = $route.TransferEncoding
            }

            # set the content type for any pages for the route if it's not empty
            $WebEvent.ErrorType = $route.ErrorType

            # route exists
            return $true
        }
    }
}

function Get-PodeBodyMiddleware {
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_body_parsing__' -ScriptBlock {
            try {
                # attempt to parse that data
                $result = ConvertFrom-PodeRequestContent -Request $WebEvent.Request -ContentType $WebEvent.ContentType -TransferEncoding $WebEvent.TransferEncoding

                # set session data
                $WebEvent.Data = $result.Data
                $WebEvent.Files = $result.Files

                # payload parsed
                return $true
            }
            catch {
                Set-PodeResponseStatus -Code 400 -Exception $_
                return $false
            }
        })
}

function Get-PodeQueryMiddleware {
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_query_parsing__' -ScriptBlock {
            try {
                # set the query string from the request
                $WebEvent.Query = (ConvertFrom-PodeNameValueToHashTable -Collection $WebEvent.Request.QueryString)
                return $true
            }
            catch {
                Set-PodeResponseStatus -Code 400 -Exception $_
                return $false
            }
        })
}

function Get-PodeCookieMiddleware {
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_cookie_parsing__' -ScriptBlock {
            # if cookies already set, return
            if ($WebEvent.Cookies.Count -gt 0) {
                return $true
            }

            # if the request's header has no cookies, return
            $h_cookie = (Get-PodeHeader -Name 'Cookie')
            if ([string]::IsNullOrWhiteSpace($h_cookie)) {
                return $true
            }

            # parse the cookies from the header
            $cookies = @($h_cookie -split '; ')
            $WebEvent.Cookies = @{}

            foreach ($cookie in $cookies) {
                $atoms = $cookie.Split('=', 2)

                $value = [string]::Empty
                if ($atoms.Length -gt 1) {
                    foreach ($atom in $atoms[1..($atoms.Length - 1)]) {
                        $value += $atom
                    }
                }

                $WebEvent.Cookies[$atoms[0]] = [System.Net.Cookie]::new($atoms[0], $value)
            }

            return $true
        })
}

function Get-PodeSecurityMiddleware {
    return (Get-PodeInbuiltMiddleware -Name '__pode_mw_security__' -ScriptBlock {
            # are there any security headers setup?
            if ($PodeContext.Server.Security.Headers.Count -eq 0) {
                return $true
            }

            # add security headers
            Set-PodeHeaderBulk -Value $PodeContext.Server.Security.Headers

            # continue to next middleware/route
            return $true
        })
}

function Initialize-PodeIISMiddleware {
    # do nothing if not iis
    if (!$PodeContext.Server.IsIIS) {
        return
    }

    # fail if no iis token - because there should be!
    if ([string]::IsNullOrWhiteSpace($PodeContext.Server.IIS.Token)) {
        # IIS ASPNETCORE_TOKEN is missing
        throw ($PodeLocale.iisAspnetcoreTokenMissingExceptionMessage)
    }

    # add middleware to check every request has the token
    Add-PodeMiddleware -Name '__pode_iis_token_check__' -ScriptBlock {
        $token = Get-PodeHeader -Name 'MS-ASPNETCORE-TOKEN'
        if ($token -ne $PodeContext.Server.IIS.Token) {
            Set-PodeResponseStatus -Code 400 -Description 'MS-ASPNETCORE-TOKEN header missing'
            return $false
        }

        return $true
    }

    # add middleware to check if there's a client cert
    Add-PodeMiddleware -Name '__pode_iis_clientcert_check__' -ScriptBlock {
        if (!$WebEvent.Request.AllowClientCertificate -or ($null -ne $WebEvent.Request.ClientCertificate)) {
            return $true
        }

        $headers = @('MS-ASPNETCORE-CLIENTCERT', 'X-ARR-ClientCert')
        foreach ($header in $headers) {
            if (!(Test-PodeHeader -Name $header)) {
                continue
            }

            try {
                $value = Get-PodeHeader -Name $header
                $WebEvent.Request.ClientCertificate = [X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($value))
            }
            catch {
                $WebEvent.Request.ClientCertificateErrors = [System.Net.Security.SslPolicyErrors]::RemoteCertificateNotAvailable
            }
        }

        return $true
    }

    # add route to gracefully shutdown server for iis
    Add-PodeRoute -Method Post -Path '/iisintegration' -ScriptBlock {
        $eventType = Get-PodeHeader -Name 'MS-ASPNETCORE-EVENT'

        # no x-forward
        if (Test-PodeHeader -Name 'X-Forwarded-For') {
            Set-PodeResponseStatus -Code 400
            return
        }

        # no user-agent
        if (Test-PodeHeader -Name 'User-Agent') {
            Set-PodeResponseStatus -Code 400
            return
        }

        # valid local Host
        $hostValue = Get-PodeHeader -Name 'Host'
        if ($hostValue -ine "127.0.0.1:$($PodeContext.Server.IIS.Port)") {
            Set-PodeResponseStatus -Code 400
            return
        }

        # no content-length
        if ($WebEvent.Request.ContentLength -gt 0) {
            Set-PodeResponseStatus -Code 400
            return
        }

        # valid event type
        if ($eventType -ine 'shutdown') {
            Set-PodeResponseStatus -Code 400
            return
        }

        # shutdown
        $PodeContext.Server.IIS.Shutdown = $true
        Close-PodeServer
        Set-PodeResponseStatus -Code 202
    }
}