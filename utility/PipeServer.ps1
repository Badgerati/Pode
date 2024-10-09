param (
    [string]$PipeName = '28752_Watchdog'
)
# $global:PodeWatchdog = '{"PipeName":"28752_Watchdog","MonitoringPort":5051,"Type":"Client","Quiet":true,"EnableMonitoring":true,"Interval":10,"MonitoringAddress":"localhost","PreSharedKey":"a5eec3c8-1470-44f2-8c3e-caa267ce14b7","DisableTermination":true}' | ConvertFrom-Json;

# Create a named pipe server stream with the specified pipe name
$pipeServer = [System.IO.Pipes.NamedPipeServerStream]::new(
    $PipeName,
    [System.IO.Pipes.PipeDirection]::InOut,
    1,
    [System.IO.Pipes.PipeTransmissionMode]::Message,
    [System.IO.Pipes.PipeOptions]::None
)

# Informational output with Write-Verbose, only shown with -Verbose switch
Write-Verbose "Named Pipe Server started with pipe name '$PipeName'..."

try {
    while ($true) {
        Write-Verbose 'Waiting for client connection...'

        # Wait for the client connection
        $pipeServer.WaitForConnection()
        Write-Verbose 'Client connected.'

        try {
            # Create a StreamReader to read the incoming message from the connected client
            $reader = [System.IO.StreamReader]::new($pipeServer)

            while ($pipeServer.IsConnected) {
                # Read the next message, which contains the serialized hashtable
                $receivedData = $reader.ReadLine()

                # Check if data was received
                if ($receivedData) {
                    Write-Verbose "Received data: $receivedData"

                    # Deserialize the received JSON string back into a hashtable
                    $hashtable = $receivedData | ConvertFrom-Json
                    Write-Verbose 'Received hashtable:'
                    Write-Host $hashtable | Format-List -Force  # Keep this as Write-Host to display data regardless
                }
                else {
                    Write-Verbose 'No data received from client. Waiting for more data...'
                }
            }
            Write-Verbose 'Client disconnected. Waiting for a new connection...'
        }
        catch {
            Write-Host "Error reading from pipe: $_"
        }
        finally {
            # Clean up after client disconnection
            Write-Verbose 'Cleaning up resources...'
            $reader.Dispose()
            # Disconnect the pipe server to reset it for the next client
            $pipeServer.Disconnect()
        }
    }
}
catch {
    Write-Host "An unexpected error occurred: $_"
}
finally {
    # Clean up
    Write-Verbose 'Closing pipe server...'
    $pipeServer.Dispose()
}
