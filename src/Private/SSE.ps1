function Invoke-PodeSseEvent {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name, # Name of the SSE connection

        [Parameter(Mandatory = $true)]
        [Pode.PodeClientConnectionEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Connection,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )

    $strType = $Type.ToString()

    # do nothing if no events
    if (!$PodeContext.Server.Sse.Connections.ContainsKey($Name) -or
        !$PodeContext.Server.Sse.Connections[$Name].Events.ContainsKey($strType) -or
        $PodeContext.Server.Sse.Connections[$Name].Events[$strType].Count -eq 0) {
        return
    }

    # setup a triggered event object
    $TriggeredEvent = @{
        Lockable   = $PodeContext.Threading.Lockables.Global
        Name       = $Name
        Type       = $strType
        Timestamp  = [DateTime]::UtcNow
        Connection = $Connection
        Metadata   = @{}
    }

    if (($null -ne $ArgumentList) -and ($ArgumentList.Count -gt 0)) {
        foreach ($key in $ArgumentList.Keys) {
            $TriggeredEvent.Metadata[$key] = $ArgumentList[$key]
        }
    }

    # invoke each event's scriptblock
    foreach ($evt in $PodeContext.Server.Sse.Connections[$Name].Events[$strType].Values) {
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