function Invoke-PodeEvent {
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )

    $strType = $Type.ToString()

    # do nothing if no events
    if (!$PodeContext.Server.Events.ContainsKey($strType) -or
        $PodeContext.Server.Events[$strType].Count -eq 0) {
        return
    }

    # setup a triggered event object
    $TriggeredEvent = @{
        Lockable  = $PodeContext.Threading.Lockables.Global
        Type      = $strType
        Timestamp = [DateTime]::UtcNow
        Metadata  = @{}
    }

    if (($null -ne $ArgumentList) -and ($ArgumentList.Count -gt 0)) {
        foreach ($key in $ArgumentList.Keys) {
            $TriggeredEvent.Metadata[$key] = $ArgumentList[$key]
        }
    }

    # invoke each event's scriptblock
    foreach ($evt in $PodeContext.Server.Events[$strType].Values) {
        if (($null -eq $evt) -or ($null -eq $evt.ScriptBlock)) {
            continue
        }

        try {
            $null = Invoke-PodeScriptBlock -ScriptBlock $evt.ScriptBlock.GetNewClosure() -Arguments $evt.Arguments -UsingVariables $evt.UsingVariables -Scoped -Splat -NoNewClosure
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }

    $TriggeredEvent = $null
}