function Start-PodeServiceServer
{
    # ensure we have service handlers
    if (Test-PodeIsEmpty (Get-PodeHandler -Type Service)) {
        throw 'No Service handlers have been defined'
    }

    # state we're running
    Write-PodeHost "Server looping every $($PodeContext.Server.Interval)secs" -ForegroundColor Yellow

    # script for the looping server
    $serverScript = {
        try
        {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # the event object
                $ServiceEvent = @{
                    Lockable = $PodeContext.Lockables.Global
                }

                # invoke the service handlers
                $handlers = Get-PodeHandler -Type Service
                foreach ($name in $handlers.Keys) {
                    $handler = $handlers[$name]
                    $_args = @(Get-PodeScriptblockArguments -ArgumentList $handler.Arguments -UsingVariables $handler.UsingVariables)
                    Invoke-PodeScriptBlock -ScriptBlock $handler.Logic -Arguments $_args -Scoped -Splat
                }

                # sleep before next run
                Start-Sleep -Seconds $PodeContext.Server.Interval
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    # start the runspace for the server
    Add-PodeRunspace -Type Main -ScriptBlock $serverScript
}