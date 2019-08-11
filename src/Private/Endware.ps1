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
        try {
            Invoke-PodeScriptBlock -ScriptBlock $eware.Logic -Arguments (@($WebEvent) + @($eware.Arguments)) -Scoped -Splat | Out-Null
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}