function Invoke-PodeEndware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Session,

        [Parameter()]
        $Endware
    )

    # if there's no endware, do nothing
    if (Test-Empty $Endware) {
        return $true
    }

    # continue or halt?
    $continue = $true

    # loop through each of the endware, invoking the next if it returns true
    foreach ($eware in @($Endware))
    {
        try {
            $continue = Invoke-ScriptBlock -ScriptBlock ($eware.GetNewClosure()) `
                -Arguments $Session -Scoped -Return
        }
        catch {
            $Error[0] | Out-Default
            $continue = $false
        }

        if (!$continue) {
            break
        }
    }
}

function Endware
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    # add the scriptblock to array of endware that needs to be run
    $PodeSession.Server.Endware += $ScriptBlock
}