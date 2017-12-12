
function Add-PodeSmtpHandler
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # add the handler
    $PodeSession.SmtpHandlers += $ScriptBlock
}