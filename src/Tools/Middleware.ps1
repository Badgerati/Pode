function Invoke-PodeMiddleware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session
    )

    # if there's no middleware, do nothing
    if (Test-Empty $PodeSession.Server.Middleware) {
        return $true
    }

    # continue or halt?
    $continue = $true

    # loop through each of the middleware, invoking the next if it returns true
    foreach ($midware in $PodeSession.Server.Middleware)
    {
        $continue = Invoke-ScriptBlock -ScriptBlock ($midware.GetNewClosure()) `
            -Arguments $Session -Scoped -Return

        if (!$continue) {
            break
        }
    }

    return $continue
}

function Middleware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # add the scriptblock to array of middleware that needs to be run
    # is it really that simple? yup.
    $PodeSession.Server.Middleware += $ScriptBlock
}