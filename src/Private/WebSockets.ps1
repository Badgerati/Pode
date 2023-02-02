using namespace Pode

function Test-PodeWebSocketsExist
{
    return (($null -ne $PodeContext.Server.WebSockets) -and (($PodeContext.Server.WebSockets.Enabled) -or ($PodeContext.Server.WebSockets.Connections.Count -gt 0)))
}

function Find-PodeWebSocket
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.WebSockets.Connections[$Name]
}

function New-PodeWebSocketReceiver
{
    if ($null -ne $PodeContext.Server.WebSockets.Receiver) {
        return
    }

    try {
        $receiver = [PodeReceiver]::new($PodeContext.Tokens.Cancellation.Token)
        $receiver.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)
        $receiver.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevels)
        $PodeContext.Server.WebSockets.Receiver = $receiver
        $PodeContext.Receivers += $receiver
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $receiver
        throw $_.Exception
    }
}

function Start-PodeWebSocketRunspace
{
    if (!(Test-PodeWebSocketsExist)) {
        return
    }

    # script for listening out of for incoming requests
    $receiveScript = {
        param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Receiver,

            [Parameter(Mandatory=$true)]
            [int]
            $ThreadId
        )

        try
        {
            while ($Receiver.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested)
            {
                # get request
                $request = (Wait-PodeTask -Task $Receiver.GetWebSocketRequestAsync($PodeContext.Tokens.Cancellation.Token))

                try
                {
                    try
                    {
                        $WsEvent = @{
                            Request = $request
                            Data = $null
                            Files = $null
                            Lockable = $PodeContext.Threading.Lockables.Global
                            Timestamp = [datetime]::UtcNow
                        }

                        # find the websocket definition
                        $websocket = Find-PodeWebSocket -Name $request.WebSocket.Name
                        if ($null -eq $websocket.Logic) {
                            continue
                        }

                        # parse data
                        $result = ConvertFrom-PodeRequestContent -Request $request -ContentType $request.WebSocket.ContentType
                        $WsEvent.Data = $result.Data
                        $WsEvent.Files = $result.Files

                        # invoke websocket script
                        $_args = @(Get-PodeScriptblockArguments -ArgumentList $websocket.Arguments -UsingVariables $websocket.UsingVariables)
                        Invoke-PodeScriptBlock -ScriptBlock $websocket.Logic -Arguments $_args -Scoped -Splat
                    }
                    catch [System.OperationCanceledException] {}
                    catch {
                        $_ | Write-PodeErrorLog
                        $_.Exception | Write-PodeErrorLog -CheckInnerException
                    }
                }
                finally {
                    $WsEvent = $null
                    Close-PodeDisposable -Disposable $request
                }
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
    }

    # start the runspace for listening on x-number of threads
    1..$PodeContext.Threads.WebSockets | ForEach-Object {
        Add-PodeRunspace -Type WebSockets -ScriptBlock $receiveScript -Parameters @{ 'Receiver' = $PodeContext.Server.WebSockets.Receiver; 'ThreadId' = $_ }
    }

    # script to keep websocket server receiving until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            $Receiver
        )

        try {
            while ($Receiver.IsConnected -and !$PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {}
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
        finally {
            Close-PodeDisposable -Disposable $Receiver
        }
    }

    Add-PodeRunspace -Type WebSockets -ScriptBlock $waitScript -Parameters @{ 'Receiver' = $PodeContext.Server.WebSockets.Receiver } -NoProfile
}