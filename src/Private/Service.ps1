<#
.SYNOPSIS
    Tests if the Pode service is enabled.

.DESCRIPTION
    This function checks if the Pode service is enabled by verifying if the `Service` key exists in the `$PodeContext.Server` hashtable.

.EXAMPLE
    Test-PodeServiceEnabled

    Returns `$true` if the Pode service is enabled, otherwise returns `$false`.

.RETURNS
    [Bool] - `$true` if the 'Service' key exists, `$false` if it does not.

.NOTES
    This function simply checks the existence of the 'Service' key in `$PodeContext.Server` to determine if the service is enabled.
#>
function Test-PodeServiceEnabled {

    # Check if the 'Service' key exists in the $PodeContext.Server hashtable
    return $PodeContext.Server.ContainsKey('Service')
}


#$global:PodeService=@{DisableTermination=$true;Quiet=$false;Pipename='ssss'}
<#
.SYNOPSIS
    Starts the Pode Service Heartbeat using a named pipe for communication with a C# service.

.DESCRIPTION
    This function starts a named pipe server in PowerShell that listens for commands from a C# application. It supports two commands:
    - 'shutdown': to gracefully stop the Pode server.
    - 'restart': to restart the Pode server.

.PARAMETER None
    The function takes no parameters. It retrieves the pipe name from the Pode service context.

.EXAMPLE
    Start-PodeServiceHearthbeat

    This command starts the Pode service monitoring and waits for 'shutdown' or 'restart' commands from the named pipe.

.NOTES
    The function uses Pode's context for the service to manage the pipe server. The pipe listens for messages sent from a C# client
    and performs actions based on the received message.

    If the pipe receives a 'shutdown' message, the Pode server is stopped.
    If the pipe receives a 'restart' message, the Pode server is restarted.

.AUTHOR
    Your Name
#>

function Start-PodeServiceHearthbeat {

    # Check if the Pode service is enabled
    if (Test-PodeServiceEnabled) {

        # Define the script block for the client receiver, listens for commands via the named pipe
        $scriptBlock = {
            Write-PodeServiceLog -Message "Start client receiver for pipe $($PodeContext.Server.Service.PipeName)"

            try {
                # Create a named pipe server stream
                $pipeStream = [System.IO.Pipes.NamedPipeServerStream]::new(
                    $PodeContext.Server.Service.PipeName,
                    [System.IO.Pipes.PipeDirection]::InOut,
                    2,  # Max number of allowed concurrent connections
                    [System.IO.Pipes.PipeTransmissionMode]::Message,
                    [System.IO.Pipes.PipeOptions]::None
                )

                Write-PodeServiceLog -Message "Waiting for connection to the $($PodeContext.Server.Service.PipeName) pipe."
                $pipeStream.WaitForConnection()  # Wait until a client connects
                Write-PodeServiceLog -Message "Connected to the $($PodeContext.Server.Service.PipeName) pipe."

                # Create a StreamReader to read incoming messages from the pipe
                $reader = [System.IO.StreamReader]::new($pipeStream)

                # Process incoming messages in a loop as long as the pipe is connected
                while ($pipeStream.IsConnected) {
                    $message = $reader.ReadLine()  # Read message from the pipe

                    if ($message) {
                        Write-PodeServiceLog -Message "Received message: $message"

                        # Process 'shutdown' message
                        if ($message -eq 'shutdown') {
                            Write-PodeServiceLog -Message 'Server requested shutdown. Closing client...'
                            Close-PodeServer  # Gracefully stop the Pode server
                            break  # Exit the loop

                        # Process 'restart' message
                        } elseif ($message -eq 'restart') {
                            Write-PodeServiceLog -Message 'Server requested restart. Restarting client...'
                            Restart-PodeServer  # Restart the Pode server
                            break  # Exit the loop
                        }
                    }
                }
            }
            catch {
                $_ | Write-PodeServiceLog  # Log any errors that occur during pipe operation
            }
            finally {
                $pipeStream.Dispose()  # Always dispose of the pipe stream when done
            }
        }

        # Assign a name to the Pode service
        $PodeContext.Server.Service['Name'] = 'Service'
        Write-PodeServiceLog -Message 'Starting service monitoring'

        # Start the runspace that runs the client receiver script block
        $PodeContext.Server.Service['Runspace'] = Add-PodeRunspace -Type 'Service' -ScriptBlock ($scriptBlock) -PassThru
    }
    else {
        # Log when the service is not enabled
        Write-PodeServiceLog -Message 'Service is not working'
        Write-PodeServiceLog -Message ($PodeService | ConvertTo-Json -Compress)
    }
}



function Write-PodeServiceLog {
    [CmdletBinding(DefaultParameterSetName = 'Message')]
    param(


        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName = 'Exception')]
        [switch]
        $CheckInnerException,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Error')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Message')]
        [string]
        $Message,

        [string]
        $Level = 'Informational',

        [string]
        $Tag = '-',

        [Parameter()]
        [int]
        $ThreadId

    )
    Process {
        $Service = $PodeContext.Server.Service
        if ($null -eq $Service ) {
            $Service = @{Name = 'Not a service' }
        }
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {

            'message' {
                $logItem = @{
                    Name = $Service.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Level   = $Level
                        Message = $Message
                        Tag     = $Tag
                    }
                }
                break
            }
            'custom' {
                $logItem = @{
                    Name = $Service.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Level   = $Level
                        Message = $Message
                        Tag     = $Tag
                    }
                }
                break
            }
            'exception' {
                $logItem = @{
                    Name = $Service.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Category   = $Exception.Source
                        Message    = $Exception.Message
                        StackTrace = $Exception.StackTrace
                        Level      = $Level
                    }
                }
                Write-PodeErrorLog -Level $Level -CheckInnerException:$CheckInnerException -Exception $Exception
            }

            'error' {
                $logItem = @{
                    Name = $Service.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Category   = $ErrorRecord.CategoryInfo.ToString()
                        Message    = $ErrorRecord.Exception.Message
                        StackTrace = $ErrorRecord.ScriptStackTrace
                        Level      = $Level
                    }
                }
                Write-PodeErrorLog -Level $Level -ErrorRecord $ErrorRecord
            }
        }

        $lpath = Get-PodeRelativePath -Path './logs' -JoinRoot
        $logItem | ConvertTo-Json -Compress -Depth 5 | Add-Content "$lpath/watchdog-$($Service.Name).log"

    }
}