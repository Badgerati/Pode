
function Add-PodeRoute
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('DELETE', 'GET', 'PATCH', 'POST', 'PUT')]
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
    if ([string]::IsNullOrWhiteSpace($Route))
    {
        throw "No route supplied for $($HttpMethod) request"
    }

    # ensure route starts with a '/'
    if (!$Route.StartsWith('/'))
    {
        $Route = "/$($Route)"
    }

    # ensure route doesn't already exist
    if ($PodeSession.Routes[$HttpMethod][$Route] -ne $null)
    {
        throw "Route '$($Route)' already has $($HttpMethod) request logic added"
    }

    # add the route logic
    $PodeSession.Routes[$HttpMethod][$Route] = $ScriptBlock
}