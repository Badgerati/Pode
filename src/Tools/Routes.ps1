function Get-PodeRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', '*')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Route
    )

    # first ensure we have the method
    $method = $PodeSession.Server.Routes[$HttpMethod]
    if ($null -eq $method) {
        return $null
    }

    # if we have a perfect match for the route, return it
    $found = $method[$Route]
    if ($null -ne $found) {
        return @{
            'Logic' = $found.Logic;
            'Middleware' = $found.Middleware;
            'Parameters' = $null;
        }
    }

    # otherwise, attempt to match on regex parameters
    else {
        $valid = ($method.Keys | Where-Object {
            $Route -imatch "$($_)$"
        } | Select-Object -First 1)

        if ($null -eq $valid) {
            return $null
        }

        $found = $method[$valid]
        $Route -imatch "$($valid)$" | Out-Null
        return @{
            'Logic' = $found.Logic;
            'Middleware' = $found.Middleware;
            'Parameters' = $Matches;
        }
    }
}

function Route
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE', '*')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [string]
        $Route,

        [Parameter()]
        $Middleware,

        [Parameter()]
        [scriptblock]
        $ScriptBlock
    )

    # if middleware and scriptblock are null, error
    if ($null -eq $Middleware -and $null -eq $ScriptBlock) {
        throw "[$($HttpMethod)] $($Route) has no logic defined"
    }

    # if middleware set, but not scriptblock, set middle and script
    if (!(Test-Empty $Middleware) -and $null -eq $ScriptBlock) {
        if ((Get-Type $Middleware).BaseName -ieq 'array') {
            throw "[$($HttpMethod)] $($Route) has no logic defined"
        }

        $ScriptBlock = $Middleware
        $Middleware = $null
    }

    # lower the method
    $HttpMethod = $HttpMethod.ToLowerInvariant()

    # split route on '?' for query
    $Route = ($Route -isplit "\?")[0]

    # ensure route isn't empty
    if ([string]::IsNullOrWhiteSpace($Route)) {
        throw "No route supplied for $($HttpMethod) request"
    }

    # ensure route starts with a '/'
    if (!$Route.StartsWith('/')) {
        $Route = "/$($Route)"
    }

    # replace placeholder parameters with regex
    $placeholder = '\:(?<tag>[\w]+)'
    if ($Route -imatch $placeholder) {
        $Route = [regex]::Escape($Route)
    }

    while ($Route -imatch $placeholder) {
        $Route = ($Route -ireplace $Matches[0], "(?<$($Matches['tag'])>[\w-_]+?)")
    }

    # replace * with .*
    $Route = ($Route -ireplace '\*', '.*')

    # ensure route doesn't already exist
    if ($PodeSession.Server.Routes[$HttpMethod].ContainsKey($Route)) {
        throw "[$($HttpMethod)] $($Route) is already defined"
    }

    # add the route logic
    $PodeSession.Server.Routes[$HttpMethod][$Route] = @{
        'Logic' = $ScriptBlock;
        'Middleware' = $Middleware;
    }
}