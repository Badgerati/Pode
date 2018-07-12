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
    if ($null -ne $PodeSession.Handlers[$Type]) {
        throw "Handler for $($Type) already defined"
    }

    # add the handler
    $PodeSession.Handlers[$Type] = $ScriptBlock
}