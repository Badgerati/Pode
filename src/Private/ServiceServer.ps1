function Start-PodeServiceServer {
    # ensure we have service handlers
    if (Test-PodeIsEmpty (Get-PodeHandler -Type Service)) {
        # No Service handlers have been defined
        throw ($PodeLocale.noServiceHandlersDefinedExceptionMessage)
    }

    # state we're running
    # Server looping every $PodeContext.Server.Interval secs
    Write-PodeHost ($PodeLocale.serverLoopingMessage -f $PodeContext.Server.Interval) -ForegroundColor Yellow

    # script for the looping server
    $serverScript = {
        # Sets the name of the current runspace
        Set-PodeCurrentRunspaceName -Name 'ServiceServer'

        try {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                # the event object
                $script:ServiceEvent = @{
                    Lockable = $PodeContext.Threading.Lockables.Global
                    Metadata = @{}
                }

                # invoke the service handlers
                $handlers = Get-PodeHandler -Type Service
                foreach ($name in $handlers.Keys) {
                    $handler = $handlers[$name]
                    $null = Invoke-PodeScriptBlock -ScriptBlock $handler.Logic -Arguments $handler.Arguments -UsingVariables $handler.UsingVariables -Scoped -Splat
                }

                # sleep before next run
                Start-Sleep -Seconds $PodeContext.Server.Interval
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            throw $_.Exception
        }
    }

    # start the runspace for the server
    Add-PodeRunspace -Type Main -ScriptBlock $serverScript
}