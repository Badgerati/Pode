
function Add-PodeTcpHandler
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
    if ($PodeSession.TcpHandlers[$Type] -ne $null)
    {
        throw "Handler '$($Type)' already added"
    }

    # add the handler
    $PodeSession.TcpHandlers[$Type] = $ScriptBlock
}