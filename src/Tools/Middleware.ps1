function Invoke-PodeMiddleware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session,

        [Parameter()]
        $Middleware
    )

    # if there's no middleware, do nothing
    if (Test-Empty $Middleware) {
        return $true
    }

    # continue or halt?
    $continue = $true

    # loop through each of the middleware, invoking the next if it returns true
    foreach ($midware in @($Middleware))
    {
        $continue = Invoke-ScriptBlock -ScriptBlock ($midware.GetNewClosure()) `
            -Arguments $Session -Scoped -Return

        if (!$continue) {
            break
        }
    }

    return $continue
}

function Get-PodeInbuiltMiddleware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # check if middleware contains an override
    $override = ($PodeSession.Server.Middleware | Where-Object { $_.Name -ieq $Name })

    # if override there, remove it from middleware
    if ($override) {
        $PodeSession.Server.Middleware = @($PodeSession.Server.Middleware | Where-Object { $_.Name -ine $Name })
        $ScriptBlock = $override.Logic
    }

    # return the script
    return @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    }
}

function Get-PodeAccessMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@access' -ScriptBlock {
        param($s)

        # ensure the request IP address is allowed
        if (!(Test-IPAccess -IP $s.Request.RemoteEndPoint.Address)) {
            status 403
            return $false
        }

        # IP address is allowed
        return $true
    })
}

function Get-PodeLimitMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@limit' -ScriptBlock {
        param($s)

        # ensure the request IP address has not hit a rate limit
        if (!(Test-IPLimit -IP $s.Request.RemoteEndPoint.Address)) {
            status 429
            return $false
        }

        # IP address is allowed
        return $true
    })
}

function Get-PodePublicMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@public' -ScriptBlock {
        param($s)

        # check to see if the path is a file, so we can check the public folder
        if ((Split-Path -Leaf -Path $s.Path).IndexOf('.') -ne -1) {
            $s.Path = Join-ServerRoot 'public' $s.Path
            Write-ToResponseFromFile -Path $s.Path
            return $false
        }

        # url is not for a public content path
        return $true
    })
}

function Get-PodeRouteValidateMiddleware
{
    return @{
        'Name' = '@route-valid';
        'Logic' = {
            param($s)

            # ensure the path has a route
            $route = Get-PodeRoute -HttpMethod $s.Method -Route $s.Path
            if ($null -eq $route) {
                $route = Get-PodeRoute -HttpMethod '*' -Route $s.Path
            }

            # if there's no route defined, it's a 404
            if ($null -eq $route -or $null -eq $route.Logic) {
                status 404
                return $false
            }

            # set the route parameters
            $WebSession.Parameters = $route.Parameters

            # route exists
            return $true
        }
    }
}

function Get-PodeBodyMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@body' -ScriptBlock {
        param($s)

        try
        {
            # read any post data
            $data = stream ([System.IO.StreamReader]::new($s.Request.InputStream, $s.Request.ContentEncoding)) {
                param($r)
                return $r.ReadToEnd()
            }

            # attempt to parse that data
            $data = ConvertFrom-PodeContent -ContentType $s.Request.ContentType -Content $data

            # set session data
            $s.Data = $data

            # payload parsed
            return $true
        }
        catch [exception]
        {
            status 400
            return $false
        }
    })
}

function Get-PodeQueryMiddleware
{
    return (Get-PodeInbuiltMiddleware -Name '@query' -ScriptBlock {
        param($s)

        try
        {
            # set the query string from the request
            $s.Query = $s.Request.QueryString
            return $true
        }
        catch [exception]
        {
            status 400
            return $false
        }
    })
}

function Middleware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('n')]
        [string]
        $Name
    )

    # if a name was supplied, ensure is doesn't already exist
    if (!(Test-Empty $Name)) {
        if (($PodeSession.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
            throw "Middleware with defined name of $($Name) already exists"
        }
    }

    # add the scriptblock to array of middleware that needs to be run
    $PodeSession.Server.Middleware += @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    }
}