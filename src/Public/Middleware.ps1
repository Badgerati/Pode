<#
.SYNOPSIS
Adds an access rule to allow or deny IP addresses.

.DESCRIPTION
Adds an access rule to allow or deny IP addresses.

.PARAMETER Access
The type of access to enable.

.PARAMETER Type
What type of request are we configuring?

.PARAMETER Values
A single, or an array of values.

.EXAMPLE
Add-PodeAccessRule -Access Allow -Type IP -Values '127.0.0.1'

.EXAMPLE
Add-PodeAccessRule -Access Deny -Type IP -Values @('192.168.1.1', '10.10.1.0/24')
#>
function Add-PodeAccessRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Access,

        [Parameter(Mandatory = $true)]
        [ValidateSet('IP')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Values
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'Add-PodeAccessRule' -ThrowError

    # call the appropriate access method
    switch ($Type.ToLowerInvariant()) {
        'ip' {
            foreach ($ip in $Values) {
                Add-PodeIPAccess -Access $Access -IP $ip
            }
        }
    }
}

<#
.SYNOPSIS
Adds rate limiting rules for an IP addresses, Routes, or Endpoints.

.DESCRIPTION
Adds rate limiting rules for an IP addresses, Routes, or Endpoints.

.PARAMETER Type
What type of request is being rate limited: IP, Route, or Endpoint?

.PARAMETER Values
A single, or an array of values.

.PARAMETER Limit
The maximum number of requests to allow.

.PARAMETER Seconds
The number of seconds to count requests before restarting the count.

.PARAMETER Group
If supplied, groups of IPs in a subnet will be considered as one IP.

.EXAMPLE
Add-PodeLimitRule -Type IP -Values '127.0.0.1' -Limit 10 -Seconds 1

.EXAMPLE
Add-PodeLimitRule -Type IP -Values @('192.168.1.1', '10.10.1.0/24') -Limit 50 -Seconds 1 -Group

.EXAMPLE
Add-PodeLimitRule -Type Route -Values '/downloads' -Limit 5 -Seconds 1
#>
function Add-PodeLimitRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('IP', 'Route', 'Endpoint')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Values,

        [Parameter(Mandatory = $true)]
        [int]
        $Limit,

        [Parameter(Mandatory = $true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # call the appropriate limit method
    foreach ($value in $Values) {
        switch ($Type.ToLowerInvariant()) {
            'ip' {
                Test-PodeIsServerless -FunctionName 'Add-PodeLimitRule' -ThrowError
                Add-PodeIPLimit -IP $value -Limit $Limit -Seconds $Seconds -Group:$Group
            }

            'route' {
                Add-PodeRouteLimit -Path $value -Limit $Limit -Seconds $Seconds -Group:$Group
            }

            'endpoint' {
                Add-PodeEndpointLimit -EndpointName $value -Limit $Limit -Seconds $Seconds -Group:$Group
            }
        }
    }
}

<#
.SYNOPSIS
Creates and returns a new secure token for use with CSRF.

.DESCRIPTION
Creates and returns a new secure token for use with CSRF.

.EXAMPLE
$token = New-PodeCsrfToken
#>
function New-PodeCsrfToken {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # fail if the csrf logic hasn't been initialised
    if (!(Test-PodeCsrfConfigured)) {
        # CSRF Middleware has not been initialized
        throw $PodeLocale.csrfMiddlewareNotInitializedExceptionMessage
    }

    # generate a new secret and salt
    $Secret = New-PodeCsrfSecret
    $Salt = (New-PodeSalt -Length 8)

    # return a new token
    return "t:$($Salt).$(Invoke-PodeSHA256Hash -Value "$($Salt)-$($Secret)")"
}

<#
.SYNOPSIS
Returns adhoc CSRF CSRF verification Middleware, for use on Routes.

.DESCRIPTION
Returns adhoc CSRF CSRF verification Middleware, for use on Routes.

.EXAMPLE
$csrf = Get-PodeCsrfMiddleware
Add-PodeRoute -Method Get -Path '/cpu' -Middleware $csrf -ScriptBlock { /* logic */ }
#>
function Get-PodeCsrfMiddleware {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # fail if the csrf logic hasn't been initialised
    if (!(Test-PodeCsrfConfigured)) {
        # CSRF Middleware has not been initialized
        throw $PodeLocale.csrfMiddlewareNotInitializedExceptionMessage
    }

    # return scriptblock for the csrf route middleware to test tokens
    $script = {
        # if there's not a secret, generate and store it
        $secret = New-PodeCsrfSecret

        # verify the token on the request, if invalid, throw a 403
        $token = Get-PodeCsrfToken

        if (!(Test-PodeCsrfToken -Secret $secret -Token $token)) {
            Set-PodeResponseStatus -Code 403 -Description 'Invalid CSRF Token'
            return $false
        }

        # token is valid, move along
        return $true
    }

    return (New-PodeMiddleware -ScriptBlock $script)
}

<#
.SYNOPSIS
Initialises CSRF within Pode for adhoc usage.

.DESCRIPTION
Initialises CSRF within Pode for adhoc usage, with configurable HTTP methods to ignore verification.

.PARAMETER IgnoreMethods
An array of HTTP methods to ignore CSRF verification.

.PARAMETER Secret
A secret to use when signing cookies - for when using CSRF with cookies.

.PARAMETER UseCookies
If supplied, CSRF will used cookies rather than sessions.

.EXAMPLE
Initialize-PodeCsrf -IgnoreMethods @('Get', 'Trace')

.EXAMPLE
Initialize-PodeCsrf -Secret 'some-secret' -UseCookies
#>
function Initialize-PodeCsrf {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string[]]
        $IgnoreMethods = @('Get', 'Head', 'Options', 'Trace'),

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $UseCookies
    )

    # check that csrf logic hasn't already been intialised
    if (Test-PodeCsrfConfigured) {
        return
    }

    # if sessions haven't been setup and we're not using cookies, error
    if (!$UseCookies -and !(Test-PodeSessionsEnabled)) {
        # Sessions are required to use CSRF unless you want to use cookies
        throw $PodeLocale.sessionsRequiredForCsrfExceptionMessage
    }

    # if we're using cookies, ensure a global secret exists
    if ($UseCookies) {
        $Secret = (Protect-PodeValue -Value $Secret -Default (Get-PodeCookieSecret -Global))

        if (Test-PodeIsEmpty $Secret) {
            throw "When using cookies for CSRF, a Secret is required. You can either supply a Secret, or set the Cookie global secret - (Set-PodeCookieSecret '<value>' -Global)"
        }
    }

    # set the options against the server context
    $PodeContext.Server.Cookies.Csrf = @{
        Name           = 'pode.csrf'
        UseCookies     = $UseCookies
        Secret         = $Secret
        IgnoredMethods = $IgnoreMethods
    }
}

<#
.SYNOPSIS
Enables Middleware for verifying CSRF tokens on Requests.

.DESCRIPTION
Enables Middleware for verifying CSRF tokens on Requests, with configurable HTTP methods to ignore verification.

.PARAMETER IgnoreMethods
An array of HTTP methods to ignore CSRF verification.

.PARAMETER Secret
A secret to use when signing cookies - for when using CSRF with cookies.

.PARAMETER UseCookies
If supplied, CSRF will used cookies rather than sessions.

.EXAMPLE
Enable-PodeCsrfMiddleware -IgnoreMethods @('Get', 'Trace')

.EXAMPLE
Enable-PodeCsrfMiddleware -Secret 'some-secret' -UseCookies
#>
function Enable-PodeCsrfMiddleware {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string[]]
        $IgnoreMethods = @('Get', 'Head', 'Options', 'Trace'),

        [Parameter(ParameterSetName = 'Cookies')]
        [string]
        $Secret,

        [Parameter(ParameterSetName = 'Cookies')]
        [switch]
        $UseCookies
    )

    Initialize-PodeCsrf -IgnoreMethods $IgnoreMethods -Secret $Secret -UseCookies:$UseCookies

    # return scriptblock for the csrf middleware
    $script = {
        # if the current route method is ignored, just return
        $ignored = @($PodeContext.Server.Cookies.Csrf.IgnoredMethods)
        if (!(Test-PodeIsEmpty $ignored) -and ($ignored -icontains $WebEvent.Method)) {
            return $true
        }

        # if there's not a secret, generate and store it
        $secret = New-PodeCsrfSecret

        # verify the token on the request, if invalid, throw a 403
        $token = Get-PodeCsrfToken

        if (!(Test-PodeCsrfToken -Secret $secret -Token $token)) {
            Set-PodeResponseStatus -Code 403 -Description 'Invalid CSRF Token'
            return $false
        }

        # token is valid, move along
        return $true
    }

    (New-PodeMiddleware -ScriptBlock $script) | Add-PodeMiddleware -Name '__pode_mw_csrf__'
}

<#
.SYNOPSIS
Adds a custom body parser middleware.

.DESCRIPTION
Adds a custom body parser middleware script for a content-type, which will be used if a payload is sent with a Request.

.PARAMETER ContentType
The ContentType of the custom body parser.

.PARAMETER ScriptBlock
The ScriptBlock that will parse the body content, and return the result.

.EXAMPLE
Add-PodeBodyParser -ContentType 'application/json' -ScriptBlock { param($body) /* parsing logic */ }
#>
function Add-PodeBodyParser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock
    )

    # if a parser for the type already exists, fail
    if ($PodeContext.Server.BodyParsers.ContainsKey($ContentType)) {
        throw "There is already a body parser defined for the $($ContentType) content-type"
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    $PodeContext.Server.BodyParsers[$ContentType] = @{
        ScriptBlock    = $ScriptBlock
        UsingVariables = $usingVars
    }
}

<#
.SYNOPSIS
Removes a custom body parser.

.DESCRIPTION
Removes a custom body parser middleware script for a content-type.

.PARAMETER ContentType
The ContentType of the custom body parser.

.EXAMPLE
Remove-PodeBodyParser -ContentType 'application/json'
#>
function Remove-PodeBodyParser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidatePattern('^\w+\/[\w\.\+-]+$')]
        [string]
        $ContentType
    )

    # if there's no parser for the type, return
    if (!$PodeContext.Server.BodyParsers.ContainsKey($ContentType)) {
        return
    }

    $null = $PodeContext.Server.BodyParsers.Remove($ContentType)
}

<#
.SYNOPSIS
Adds a new Middleware to be invoked before every Route, or certain Routes.

.DESCRIPTION
Adds a new Middleware to be invoked before every Route, or certain Routes. ScriptBlock should return $true to continue execution, or $false to stop.

.PARAMETER Name
The Name of the Middleware.

.PARAMETER ScriptBlock
The Script defining the logic of the Middleware. Should return $true to continue execution, or $false to stop.

.PARAMETER InputObject
A Middleware HashTable from New-PodeMiddleware, or from certain other functions that return Middleware as a HashTable.

.PARAMETER Route
A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER ArgumentList
An array of arguments to supply to the Middleware's ScriptBlock.

.OUTPUTS
Boolean. ScriptBlock should return $true to continue to the next middleware/route, or return $false to stop execution.

.EXAMPLE
Add-PodeMiddleware -Name 'BlockAgents' -ScriptBlock { /* logic */ }

.EXAMPLE
Add-PodeMiddleware -Name 'CheckEmailOnApi' -Route '/api/*' -ScriptBlock { /* logic */ }
#>
function Add-PodeMiddleware {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'Input', ValueFromPipeline = $true)]
        [hashtable]
        $InputObject,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # ensure name doesn't already exist
    if (($PodeContext.Server.Middleware | Where-Object { $_.Name -ieq $Name } | Measure-Object).Count -gt 0) {
        throw "[Middleware] $($Name): Middleware already defined"
    }

    # if it's a script - call New-PodeMiddleware
    if ($PSCmdlet.ParameterSetName -ieq 'script') {
        $InputObject = (New-PodeMiddlewareInternal `
                -ScriptBlock $ScriptBlock `
                -Route $Route `
                -ArgumentList $ArgumentList `
                -PSSession $PSCmdlet.SessionState)
    }
    else {
        $Route = ConvertTo-PodeRouteRegex -Path $Route
        $InputObject.Route = Protect-PodeValue -Value $Route -Default $InputObject.Route
        $InputObject.Options = Protect-PodeValue -Value $Options -Default $InputObject.Options
    }

    # ensure we have a script to run
    if (Test-PodeIsEmpty $InputObject.Logic) {
        # [Middleware]: No logic supplied in ScriptBlock
        throw $PodeLocale.middlewareNoLogicSuppliedExceptionMessage
    }

    # set name, and override route/args
    $InputObject.Name = $Name

    # add the logic to array of middleware that needs to be run
    $PodeContext.Server.Middleware += $InputObject
}

<#
.SYNOPSIS
Creates a new Middleware HashTable object, that can be piped/used in Add-PodeMiddleware or in Routes.

.DESCRIPTION
Creates a new Middleware HashTable object, that can be piped/used in Add-PodeMiddleware or in Routes. ScriptBlock should return $true to continue execution, or $false to stop.

.PARAMETER ScriptBlock
The Script that defines the logic of the Middleware. Should return $true to continue execution, or $false to stop.

.PARAMETER Route
A Route path for which Routes this Middleware should only be invoked against.

.PARAMETER ArgumentList
An array of arguments to supply to the Middleware's ScriptBlock.

.OUTPUTS
Boolean. ScriptBlock should return $true to continue to the next middleware/route, or return $false to stop execution.

.EXAMPLE
New-PodeMiddleware -ScriptBlock { /* logic */ } -ArgumentList 'Email' | Add-PodeMiddleware -Name 'CheckEmail'
#>
function New-PodeMiddleware {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string]
        $Route,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    return New-PodeMiddlewareInternal `
        -ScriptBlock $ScriptBlock `
        -Route $Route `
        -ArgumentList $ArgumentList `
        -PSSession $PSCmdlet.SessionState
}

<#
.SYNOPSIS
Removes a specific user defined Middleware.

.DESCRIPTION
Removes a specific user defined Middleware.

.PARAMETER Name
The Name of the Middleware to be removed.

.EXAMPLE
Remove-PodeMiddleware -Name 'Sessions'
#>
function Remove-PodeMiddleware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $PodeContext.Server.Middleware = @($PodeContext.Server.Middleware | Where-Object { $_.Name -ine $Name })
}

<#
.SYNOPSIS
Removes all user defined Middleware.

.DESCRIPTION
Removes all user defined Middleware.

.EXAMPLE
Clear-PodeMiddleware
#>
function Clear-PodeMiddleware {
    [CmdletBinding()]
    param()

    $PodeContext.Server.Middleware = @()
}

<#
.SYNOPSIS
Automatically loads middleware ps1 files

.DESCRIPTION
Automatically loads middleware ps1 files from either a /middleware folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeMiddleware

.EXAMPLE
Use-PodeMiddleware -Path './my-middleware'
#>
function Use-PodeMiddleware {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'middleware'
}