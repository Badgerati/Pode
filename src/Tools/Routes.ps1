function Get-PodeRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Route
    )

    # first ensure we have the method
    $method = $PodeSession.Routes[$HttpMethod] 
    if ($method -eq $null) {
        return $null
    }

    # if we have a perfect match for the route, return it
    if ($method[$Route] -ne $null) {
        return @{ 'Logic' = $method[$Route]; 'Parameters' = $null }
    }

    # otherwise, attempt to match on regex parameters
    else {
        $valid = ($method.Keys | Where-Object {
            $Route -imatch "$($_)$"
        } | Select-Object -First 1)

        if ($valid -eq $null) {
            return $null
        }

        $Route -imatch "$($valid)$" | Out-Null
        return @{ 'Logic' = $method[$valid]; 'Parameters' = $Matches }
    }
}

function Route
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'HEAD', 'MERGE', 'OPTIONS', 'PATCH', 'POST', 'PUT', 'TRACE')]
        [string]
        $HttpMethod,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Route,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

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

    # ensure route doesn't already exist
    if ($PodeSession.Routes[$HttpMethod].ContainsKey($Route)) {
        throw "Route '$($Route)' already has $($HttpMethod) request logic added"
    }

    # add the route logic
    $PodeSession.Routes[$HttpMethod][$Route] = $ScriptBlock
}