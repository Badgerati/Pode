function Start-PodeServiceServer
{
    # ensure we have service handlers
    if (Test-IsEmpty (Get-PodeHandler -Type Service)) {
        throw 'No Service handlers have been defined'
    }

    # state we're running
    Write-Host "Server looping every $($PodeContext.Server.Interval)secs" -ForegroundColor Yellow

    # script for the looping server
    $serverScript = {
        try
        {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # invoke the service handlers
                $handlers = Get-PodeHandler -Type Service
                foreach ($name in $handlers.Keys) {
                    Invoke-PodeScriptBlock -ScriptBlock $handlers[$name].Logic -Scoped
                }

                # sleep before next run
                Start-Sleep -Seconds $PodeContext.Server.Interval
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            Write-PodeErrorLog -Exception $_
            throw $_.Exception
        }
    }

    # start the runspace for the server
    Add-PodeRunspace -Type 'Main' -ScriptBlock $serverScript
}