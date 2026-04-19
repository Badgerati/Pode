using namespace Pode.Adapters
using namespace Pode.Adapters.Consumers

function Test-PodeWebSocketsExist {
    return (($null -ne $PodeContext.Server.WebSockets) -and (($PodeContext.Server.WebSockets.Enabled) -or ($PodeContext.Server.WebSockets.Connections.Count -gt 0)))
}

function Find-PodeWebSocket {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.WebSockets.Connections[$Name]
}

function New-PodeWebSocketConsumer {
    if ($null -ne $PodeContext.Server.WebSockets.Consumer) {
        return
    }

    try {
        $consumer = [PodeConsumer]::new([PodeAdapterType]::WebSocket, $PodeContext.Tokens.Cancellation.Token)
        $consumer.ErrorLoggingEnabled = (Test-PodeErrorLoggingEnabled)
        $consumer.ErrorLoggingLevels = @(Get-PodeErrorLoggingLevel)
        $PodeContext.Server.WebSockets.Consumer = $consumer
        $PodeContext.Consumers += $consumer
    }
    catch {
        $_ | Write-PodeErrorLog
        $_.Exception | Write-PodeErrorLog -CheckInnerException
        Close-PodeDisposable -Disposable $consumer
        throw $_.Exception
    }
}

function Start-PodeWebSocketRunspace {
    if (!(Test-PodeWebSocketsExist)) {
        return
    }

    # script for listening out of for incoming requests (Consumer)
    $consumerScript = {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            $Consumer,

            [Parameter(Mandatory = $true)]
            [int]
            $ThreadId
        )
        # Waits for the Pode server to fully start before proceeding with further operations.
        Wait-PodeCancellationTokenRequest -Type Start

        do {
            try {
                while ($Consumer.IsConnected -and !(Test-PodeCancellationTokenRequest -Type Terminate, Cancellation -Match All)) {
                    # get request
                    $request = (Wait-PodeTask -Task $Consumer.GetWebSocketRequestAsync($PodeContext.Tokens.Cancellation.Token))

                    try {
                        try {
                            $WsEvent = @{
                                Request   = $request
                                Data      = $null
                                Files     = $null
                                Lockable  = $PodeContext.Threading.Lockables.Global
                                Timestamp = [datetime]::UtcNow
                                Metadata  = @{}
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
                            $null = Invoke-PodeScriptBlock -ScriptBlock $websocket.Logic -Arguments $websocket.Arguments -UsingVariables $websocket.UsingVariables -Scoped -Splat
                        }
                        catch [System.OperationCanceledException] {
                            $_ | Write-PodeErrorLog -Level Debug
                        }
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
            catch [System.OperationCanceledException] {
                $_ | Write-PodeErrorLog -Level Debug
            }
            catch {
                $_ | Write-PodeErrorLog
                $_.Exception | Write-PodeErrorLog -CheckInnerException
                throw $_.Exception
            }

            # end do-while
        } while (Test-PodeSuspensionToken) # Check for suspension token and wait for the debugger to reset if active

    }

    # start the runspace for listening on x-number of threads
    Write-Verbose 'Starting the WebSockets Consumer runspace(s)...'
    1..$PodeContext.Threads.WebSockets | ForEach-Object {
        Add-PodeRunspace -Type WebSockets -Name 'Consumer' -ScriptBlock $consumerScript -Parameters @{ 'Consumer' = $PodeContext.Server.WebSockets.Consumer; 'ThreadId' = $_ }
    }

    # script to keep websocket server consuming until cancelled
    $waitScript = {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNull()]
            $Consumer
        )

        try {
            while ($Consumer.IsConnected -and !(Test-PodeCancellationTokenRequest -Type Terminate)) {
                Start-Sleep -Seconds 1
            }
        }
        catch [System.OperationCanceledException] {
            $_ | Write-PodeErrorLog -Level Debug
        }
        catch {
            $_ | Write-PodeErrorLog
            $_.Exception | Write-PodeErrorLog -CheckInnerException
            throw $_.Exception
        }
        finally {
            Close-PodeDisposable -Disposable $Consumer
        }
    }

    Write-Verbose 'Starting the WebSockets KeepAlive runspace...'
    Add-PodeRunspace -Type WebSockets -Name 'KeepAlive' -ScriptBlock $waitScript -Parameters @{ 'Consumer' = $PodeContext.Server.WebSockets.Consumer } -NoProfile
}