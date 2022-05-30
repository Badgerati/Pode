function Invoke-PodeEvent
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser', 'Crash', 'Stop')]
        [string]
        $Type
    )

    # do nothing if no events
    if (($null -eq $PodeContext.Server.Events) -or ($PodeContext.Server.Events[$Type].Count -eq 0)) {
        return
    }

    # invoke each event's scriptblock
    foreach ($evt in $PodeContext.Server.Events[$Type].Values) {
        if (($null -eq $evt) -or ($null -eq $evt.ScriptBlock)) {
            continue
        }

        try {
            $_args = @(Get-PodeScriptblockArguments -ArgumentList $evt.Arguments -UsingVariables $evt.UsingVariables)
            $null = Invoke-PodeScriptBlock -ScriptBlock $evt.ScriptBlock -Arguments $_args -Scoped -Splat
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}