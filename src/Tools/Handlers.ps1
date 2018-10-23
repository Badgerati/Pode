function Get-PodeTcpHandler
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('SMTP', 'TCP', 'Service')]
        [string]
        $Type
    )

    return $PodeSession.Server.Handlers[$Type]
}

function Handler
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('SMTP', 'TCP', 'Service')]
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
    if ($null -ne $PodeSession.Server.Handlers[$Type]) {
        throw "Handler for $($Type) already defined"
    }

    # add the handler
    $PodeSession.Server.Handlers[$Type] = $ScriptBlock
}