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