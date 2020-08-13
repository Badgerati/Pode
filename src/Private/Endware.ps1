function Invoke-PodeEndware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $WebEvent,

        [Parameter()]
        $Endware
    )

    # if there's no endware, do nothing
    if (($null -eq $Endware) -or ($Endware.Length -eq 0)) {
        return
    }

    # loop through each of the endware, invoking the next if it returns true
    foreach ($eware in @($Endware))
    {
        if (($null -eq $eware) -or ($null -eq $eware.Logic)) {
            continue
        }

        try {
            $_args = @($WebEvent) + @($eware.Arguments)
            if ($null -ne $eware.UsingVariables) {
                $_args = @($eware.UsingVariables.Value) + $_args
            }

            Invoke-PodeScriptBlock -ScriptBlock $eware.Logic -Arguments $_args -Scoped -Splat | Out-Null
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}