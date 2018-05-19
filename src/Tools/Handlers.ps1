function Get-PodeTcpHandler
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('SMTP', 'TCP')]
        [string]
        $Type
    )

    return $PodeSession.Handlers[$Type]
}

function Handler
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('SMTP', 'TCP')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # lower the type
    $Type = $Type.ToLowerInvariant()

    # ensure handler isn't already set
    if ($PodeSession.Handlers[$Type] -ne $null) {
        throw "Handler for $($Type) already added"
    }

    # add the handler
    $PodeSession.Handlers[$Type] = $ScriptBlock
}