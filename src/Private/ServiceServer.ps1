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
                    Lockable = $PodeContext.Lockable
                }

                # invoke the service handlers
                $handlers = Get-PodeHandler -Type Service
                foreach ($name in $handlers.Keys) {
                    $handler = $handlers[$name]

                    $_args = @($handler.Arguments)
                    if ($null -ne $handler.UsingVariables) {
                        $_vars = @()
                        foreach ($_var in $handler.UsingVariables) {
                            $_vars += ,$_var.Value
                        }
                        $_args = $_vars + $_args
                    }

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