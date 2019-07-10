function Start-PodeServiceServer
{
    # ensure we have svc handler
    if ($null -eq (Get-PodeTcpHandler -Type 'Service')) {
        throw 'No Service handler has been passed'
    }

    # state we're running
    Write-Host "Server looping every $($PodeContext.Server.Interval)secs" -ForegroundColor Yellow

    # script for the looping server
    $serverScript = {
        try
        {
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # invoke the service logic
                Invoke-PodeScriptBlock -ScriptBlock (Get-PodeTcpHandler -Type 'Service') -Scoped
                #Invoke-PodeScriptBlock -ScriptBlock $PodeContext.Server.Logic -NoNewClosure

                # sleep before next run
                Start-Sleep -Seconds $PodeContext.Server.Interval
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $Error[0] | Out-Default
            throw $_.Exception
        }
    }

    # start the runspace for the server
    Add-PodeRunspace -Type 'Main' -ScriptBlock $serverScript
}