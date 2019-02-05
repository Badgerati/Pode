function Get-PodeTcpHandler
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('SMTP', 'TCP', 'Service')]
        [string]
        $Type
    )

    return $PodeContext.Server.Handlers[$Type]
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
    if ($null -ne $PodeContext.Server.Handlers[$Type]) {
        throw "Handler for $($Type) already defined"
    }

    # add the handler
    $PodeContext.Server.Handlers[$Type] = $ScriptBlock
}