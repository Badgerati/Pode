<#
.SYNOPSIS
    Captures a memory dump with runspace and exception details when a fatal exception occurs, with an optional halt switch to close the application.

.DESCRIPTION
    The Invoke-PodeDump function gathers diagnostic information, including process memory usage, exception details, runspace information, and
    variables from active runspaces. It saves this data in the specified format (JSON, CLIXML, Plain Text, Binary, or YAML) in a "Dump" folder within
    the current directory. If the folder does not exist, it will be created. An optional `-Halt` switch is available to terminate the PowerShell process
    after saving the dump.

.PARAMETER ErrorRecord
    The ErrorRecord object representing the fatal exception that triggered the memory dump. This provides details on the error, such as message and stack trace.
    Accepts input from the pipeline.

.PARAMETER Format
    Specifies the format for saving the dump file. Supported formats are 'json', 'clixml', 'txt', 'bin', and 'yaml'.

.PARAMETER Halt
    Switch to specify whether to terminate the application after saving the memory dump. If set, the function will close the PowerShell process.

.PARAMETER Path
    Specifies the directory where the dump file will be saved. If the directory does not exist, it will be created. Defaults to a "Dump" folder.

.PARAMETER MaxDepth
    Specifies the maximum depth to traverse when collecting information.

.EXAMPLE
    try {
        # Simulate a critical error
        throw [System.OutOfMemoryException] "Simulated out of memory error"
    }
    catch {
        # Capture the dump in JSON format and halt the application
        $_ | Invoke-PodeDump -Format 'json' -Halt
    }

    This example catches a simulated OutOfMemoryException and pipes it to Invoke-PodeDump to capture the error in JSON format and halt the application.

.EXAMPLE
    try {
        # Simulate a critical error
        throw [System.AccessViolationException] "Simulated access violation error"
    }
    catch {
        # Capture the dump in YAML format without halting
        $_ | Invoke-PodeDump -Format 'yaml'
    }

    This example catches a simulated AccessViolationException and pipes it to Invoke-PodeDump to capture the error in YAML format without halting the application.

.NOTES
    This function is designed to assist with post-mortem analysis by capturing critical application state information when a fatal error occurs.
    It may be further adapted to log additional details or support different formats for captured data.

#>
function Invoke-PodeDumpInternal {
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter()]
        [ValidateSet('json', 'clixml', 'txt', 'bin', 'yaml')]
        [string]
        $Format,

        [string]
        $Path,

        [int]
        $MaxDepth
    )

    # Begin block to handle pipeline input
    begin {
        Invoke-PodeEvent -Type Dump
        # Default format and path from PodeContext
        if ([string]::IsNullOrEmpty($Format)) {
            if ($PodeContext.Server.Debug.Dump.Param.Format) {
                $Format = $PodeContext.Server.Debug.Dump.Param.Format
            }
            else {
                $Format = $PodeContext.Server.Debug.Dump.Format
            }
        }
        if ([string]::IsNullOrEmpty($Path)) {
            if ($PodeContext.Server.Debug.Dump.Param.Path) {
                $Path = $PodeContext.Server.Debug.Dump.Param.Path
            }
            else {
                $Path = $PodeContext.Server.Debug.Dump.Path
            }
        }
        if ($null -eq $ErrorRecord) {
            if ($PodeContext.Server.Debug.Dump.Param.ErrorRecord) {
                $ErrorRecord = $PodeContext.Server.Debug.Dump.Param.ErrorRecord
            }
            else {
                $ErrorRecord = $null
            }
        }

        if ($MaxDepth -lt 1) {
            if ($PodeContext.Server.Debug.Dump.Param.MaxDepth) {
                $MaxDepth = $PodeContext.Server.Debug.Dump.Param.MaxDepth
            }
            else {
                $MaxDepth = $PodeContext.Server.Debug.Dump.MaxDepth
            }
        }
        $PodeContext.Server.Debug.Dump.Param.Clear()

        Write-PodeHost -ForegroundColor Yellow 'Preparing Memory Dump ...'
    }

    # Process block to handle each pipeline input
    process {
        # Ensure Dump directory exists in the specified path
        if ( $Path -match '^\.{1,2}([\\\/]|$)') {
            $Path = [System.IO.Path]::Combine($PodeContext.Server.Root, $Path.Substring(2))
        }

        if (!(Test-Path -Path $Path)) {
            New-Item -ItemType Directory -Path $Path | Out-Null
        }

        # Capture process memory details
        $process = Get-Process -Id $PID
        $memoryDetails = @(
            [Ordered]@{
                ProcessId     = $process.Id
                ProcessName   = $process.ProcessName
                WorkingSet    = [math]::Round($process.WorkingSet64 / 1MB, 2)
                PrivateMemory = [math]::Round($process.PrivateMemorySize64 / 1MB, 2)
                VirtualMemory = [math]::Round($process.VirtualMemorySize64 / 1MB, 2)
            }
        )

        # Capture the code causing the exception
        $scriptContext = @()
        $exceptionDetails = @()
        $stackTrace = ''

        if ($null -ne $ErrorRecord) {

            $scriptContext += [Ordered]@{
                ScriptName      = $ErrorRecord.InvocationInfo.ScriptName
                Line            = $ErrorRecord.InvocationInfo.Line
                PositionMessage = $ErrorRecord.InvocationInfo.PositionMessage
            }

            # Capture stack trace information if available
            $stackTrace = if ($ErrorRecord.Exception.StackTrace) {
                $ErrorRecord.Exception.StackTrace -split "`n"
            }
            else {
                'No stack trace available'
            }

            # Capture exception details
            $exceptionDetails += [Ordered]@{
                ExceptionType  = $ErrorRecord.Exception.GetType().FullName
                Message        = $ErrorRecord.Exception.Message
                InnerException = if ($ErrorRecord.Exception.InnerException) { $ErrorRecord.Exception.InnerException.Message } else { $null }
            }
        }

        # Collect variables by scope
        $scopedVariables = Get-PodeDumpScopedVariable

        # Check if RunspacePools is not null before iterating
        $runspacePoolDetails = @()
        $runspaces = Get-Runspace -name 'Pode_*'
        $runspaceDetails = @{}
        foreach ($r in $runspaces) {
                $runspaceDetails[$r.Name] = @{
                    Id                  = $r.Id
                    Name                = $r.Name
                    InitialSessionState = $r.InitialSessionState
                    RunspaceStateInfo   = $r.RunspaceStateInfo
                }
                $runspaceDetails[$r.Name].ScopedVariables = Get-PodeRunspaceVariablesViaDebugger -Runspace $r
        }

        if ($null -ne $PodeContext.RunspacePools) {
            foreach ($poolName in $PodeContext.RunspacePools.Keys) {
                $pool = $PodeContext.RunspacePools[$poolName]

                if ($null -ne $pool -and $null -ne $pool.Pool) {
                    $runspacePoolDetails += @(
                        [Ordered]@{
                            PoolName                 = $poolName
                            State                    = $pool.State
                            Result                   = $pool.result
                            InstanceId               = $pool.Pool.InstanceId
                            IsDisposed               = $pool.Pool.IsDisposed
                            RunspacePoolStateInfo    = $pool.Pool.RunspacePoolStateInfo
                            InitialSessionState      = $pool.Pool.InitialSessionState
                            CleanupInterval          = $pool.Pool.CleanupInterval
                            RunspacePoolAvailability = $pool.Pool.RunspacePoolAvailability
                            ThreadOptions            = $pool.Pool.ThreadOptions
                        }
                    )
                }
            }
        }

        # Combine all captured information into a single object
        $dumpInfo = [Ordered]@{
            Timestamp        = (Get-Date).ToString('s')
            Memory           = $memoryDetails
            ScriptContext    = $scriptContext
            StackTrace       = $stackTrace
            ExceptionDetails = $exceptionDetails
            ScopedVariables  = $scopedVariables
            RunspacePools    = $runspacePoolDetails
            Runspace         = $runspaceDetails
        }

        # Determine file extension and save format based on selected Format
        switch ($Format) {
            'json' {
                $dumpFilePath = Join-Path -Path $Path -ChildPath "PowerShellDump_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                $dumpInfo | ConvertTo-Json -Depth $MaxDepth -WarningAction SilentlyContinue | Out-File -FilePath $dumpFilePath
                break
            }
            'clixml' {
                $dumpFilePath = Join-Path -Path $Path -ChildPath "PowerShellDump_$(Get-Date -Format 'yyyyMMdd_HHmmss').clixml"
                $dumpInfo | Export-Clixml -Path $dumpFilePath
                break
            }
            'txt' {
                $dumpFilePath = Join-Path -Path $Path -ChildPath "PowerShellDump_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
                $dumpInfo | Out-String | Out-File -FilePath $dumpFilePath
                break
            }
            'bin' {
                $dumpFilePath = Join-Path -Path $Path -ChildPath "PowerShellDump_$(Get-Date -Format 'yyyyMMdd_HHmmss').bin"
                [System.IO.File]::WriteAllBytes($dumpFilePath, [System.Text.Encoding]::UTF8.GetBytes([System.Management.Automation.PSSerializer]::Serialize($dumpInfo, $MaxDepth )))
                break
            }
            'yaml' {
                $dumpFilePath = Join-Path -Path $Path -ChildPath "PowerShellDump_$(Get-Date -Format 'yyyyMMdd_HHmmss').yaml"
                $dumpInfo | ConvertTo-PodeYaml -Depth $MaxDepth | Out-File -FilePath $dumpFilePath
                break
            }
        }

        Write-PodeHost -ForegroundColor Yellow "Memory dump saved to $dumpFilePath"
    }
    end {
        Close-PodeDisposable -Disposable $PodeContext.Tokens.Dump
        $PodeContext.Tokens.Dump = [System.Threading.CancellationTokenSource]::new()
    }
}

<#
.SYNOPSIS
    Collects scoped variables from a specified runspace using the PowerShell debugger.

.DESCRIPTION
    This function attaches a debugger to a given runspace, breaks execution, and collects scoped variables using a custom C# class.
    It waits until the debugger stop event is triggered or until a specified timeout period elapses.
    If the timeout is reached without triggering the event, it returns an empty hashtable.

.PARAMETER Runspace
    The runspace from which to collect scoped variables. This parameter is mandatory.

.PARAMETER Timeout
    The maximum time (in seconds) to wait for the debugger stop event to be triggered. Defaults to 60 seconds.

.EXAMPLE
    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $variables = Get-PodeRunspaceVariablesViaDebugger -Runspace $runspace -Timeout 30
    $runspace.Close()

    This example opens a runspace, collects scoped variables with a 30-second timeout, and then closes the runspace.

.NOTES
    The function uses an embedded C# class to handle the `DebuggerStop` event. This class attaches and detaches the debugger and processes commands in the stopped state.
    The collected variables are returned as a `PSObject`.

.COMPONENT
    Pode

#>
function Get-PodeRunspaceVariablesViaDebugger {
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.Runspace]$Runspace,

        [Parameter()]
        [int]$Timeout = 60
    )

    # Initialize variables collection
    $variables = @()
    try {

        # Attach the debugger using the embedded C# method
        [Pode.Embedded.DebuggerHandler]::AttachDebugger($Runspace, $true)

        # Enable debugging and break all
        Enable-RunspaceDebug -BreakAll -Runspace $Runspace

        Write-PodeHost "Waiting for $($Runspace.Name) to enter in debug ." -NoNewLine

        # Initialize the timer
        $startTime = [DateTime]::UtcNow

        # Wait for the event to be triggered or timeout
        while (! [Pode.Embedded.DebuggerHandler]::IsEventTriggered()) {
            Start-Sleep -Milliseconds 1000
            Write-PodeHost '.' -NoNewLine

            if (([DateTime]::UtcNow - $startTime).TotalSeconds -ge $Timeout) {
                Write-PodeHost "Failed (Timeout reached after $Timeout seconds.)"
                return @{}
            }
        }

        Write-PodeHost 'Done'

        # Retrieve and output the collected variables from the embedded C# code
        $variables = [Pode.Embedded.DebuggerHandler]::GetVariables()
    }
    catch {
        # Log the error details using Write-PodeErrorLog.
        # This ensures that any exceptions thrown during the execution are logged appropriately.
        $_ | Write-PodeErrorLog
    }
    finally {
        # Detach the debugger from the runspace to clean up resources and prevent any lingering event handlers.
        [Pode.Embedded.DebuggerHandler]::DetachDebugger($Runspace)

        # Disable debugging for the runspace. This ensures that the runspace returns to its normal execution state.
        Disable-RunspaceDebug -Runspace $Runspace
    }

    return $variables[0]
}

<#
.SYNOPSIS
    Collects and serializes variables from different scopes (Local, Script, Global).

.DESCRIPTION
    This function retrieves variables from Local, Script, and Global scopes and serializes them to ensure they can be output or logged.
    It includes a safeguard against deeply nested objects by limiting the depth of serialization to prevent stack overflow or excessive memory usage.

.PARAMETER MaxDepth
    Specifies the maximum depth for serializing nested objects. Defaults to 5 levels deep.

.EXAMPLE
    Get-PodeDumpScopedVariable -MaxDepth 3

    This example retrieves variables from all scopes and serializes them with a maximum depth of 3.

.NOTES
    This function is useful for debugging and logging purposes where variable data from different scopes needs to be safely serialized and inspected.

#>
function Get-PodeDumpScopedVariable {
    param (
        [int]
        $MaxDepth = 5
    )
    # Collect variables from Local, Script, and Global scopes
    $scopes = @{
        Local  = Get-Variable -Scope 0
        Script = Get-Variable -Scope Script
        Global = Get-Variable -Scope Global
    }

    # Dictionary to hold serialized variables by scope
    $scopedVariables = @{}
    foreach ($scope in $scopes.Keys) {
        $variables = @{}
        foreach ($var in $scopes[$scope]) {
            # Attempt to retrieve the variable's value, handling any errors
            $variables[$var.Name] = try { $var.Value } catch { 'Error retrieving value' }
        }
        # Serialize the variables to ensure safe output
        $scopedVariables[$scope] = ConvertTo-PodeSerializableObject -InputObject $variables -MaxDepth $MaxDepth
    }

    # Return the serialized variables by scope
    return $scopedVariables
}

<#
.SYNOPSIS
    Safely serializes an object, ensuring it doesn't exceed the specified depth.

.DESCRIPTION
    This function recursively serializes an object to a simpler, more displayable form, handling complex or deeply nested objects by limiting the serialization depth.
    It supports various object types like hashtables, PSCustomObjects, and collections while avoiding overly deep recursion that could cause stack overflow or excessive resource usage.

.PARAMETER InputObject
    The object to be serialized.

.PARAMETER MaxDepth
    Specifies the maximum depth for serialization. Defaults to 5 levels deep.

.PARAMETER CurrentDepth
    The current depth in the recursive serialization process. Defaults to 0 and is used internally during recursion.

.EXAMPLE
    ConvertTo-PodeSerializableObject -InputObject $complexObject -MaxDepth 3

    This example serializes a complex object with a maximum depth of 3.

.NOTES
    This function is useful for logging, debugging, and safely displaying complex objects in a readable format.

#>
function ConvertTo-PodeSerializableObject {
    param (
        [object]
        $InputObject,

        [int]
        $MaxDepth = 5,

        [int]
        $CurrentDepth = 0
    )

    # Check if the current depth has reached or exceeded the maximum allowed depth
    if ($CurrentDepth -ge $MaxDepth) {
        # Return a simple message indicating that the maximum depth has been reached
        return 'Max depth reached'
    }

    # Handle null input
    if ($null -eq $InputObject) {
        return $null  # Return null if the input object is null
    }
    # Handle hashtables
    elseif ($InputObject -is [hashtable]) {
        $result = @{}
        try {
            foreach ($key in $InputObject.Keys) {
                try {
                    # Serialize each key-value pair in the hashtable
                    $strKey = $key.ToString()
                    $result[$strKey] = ConvertTo-PodeSerializableObject -InputObject $InputObject[$key] -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                }
                catch {
                    Write-PodeHost $_ -ForegroundColor Red
                }
            }
        }
        catch {
            Write-PodeHost $_ -ForegroundColor Red
        }
        return $result
    }
    # Handle PSCustomObjects
    elseif ($InputObject -is [PSCustomObject]) {
        $result = @{}
        try {
            foreach ($property in $InputObject.PSObject.Properties) {
                try {
                    # Serialize each property in the PSCustomObject
                    $result[$property.Name.ToString()] = ConvertTo-PodeSerializableObject -InputObject $property.Value -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                }
                catch {
                    Write-PodeHost $_ -ForegroundColor Red
                }
            }
        }
        catch {
            Write-PodeHost $_ -ForegroundColor Red
        }
        return $result
    }
    # Handle enumerable collections, excluding strings
    elseif ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        # Serialize each item in the collection
        return $InputObject | ForEach-Object { ConvertTo-PodeSerializableObject -InputObject $_ -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1) }
    }
    else {
        # Convert other object types to string for serialization
        return $InputObject.ToString()
    }
}

function Initialize-PodeDebugHandler {
    # Embed C# code to handle the DebuggerStop event
    Add-Type @'
using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Collections.ObjectModel;

namespace Pode.Embedded
{
    public class DebuggerHandler
    {
        // Collection to store variables collected during the debugging session
        private static PSDataCollection<PSObject> variables = new PSDataCollection<PSObject>();

        // Event handler for the DebuggerStop event
        private static EventHandler<DebuggerStopEventArgs> debuggerStopHandler;

        // Flag to indicate whether the DebuggerStop event has been triggered
        private static bool eventTriggered = false;

        // Flag to control whether variables should be collected during the DebuggerStop event
        private static bool shouldCollectVariables = true;

        // Method to attach the DebuggerStop event handler to the runspace's debugger
        public static void AttachDebugger(Runspace runspace, bool collectVariables = true)
        {
            // Set the collection flag based on the parameter
            shouldCollectVariables = collectVariables;

            // Initialize the event handler with the OnDebuggerStop method
            debuggerStopHandler = new EventHandler<DebuggerStopEventArgs>(OnDebuggerStop);

            // Attach the event handler to the DebuggerStop event of the runspace's debugger
            runspace.Debugger.DebuggerStop += debuggerStopHandler;
        }

        // Method to detach the DebuggerStop event handler from the runspace's debugger
        public static void DetachDebugger(Runspace runspace)
        {
            if (debuggerStopHandler != null)
            {
                // Remove the event handler to prevent further event handling
                runspace.Debugger.DebuggerStop -= debuggerStopHandler;

                // Set the handler to null to clean up
                debuggerStopHandler = null;
            }
        }

        // Event handler method that gets called when the debugger stops
        private static void OnDebuggerStop(object sender, DebuggerStopEventArgs args)
        {
            // Set the eventTriggered flag to true
            eventTriggered = true;

            // Cast the sender to a Debugger object
            var debugger = sender as Debugger;
            if (debugger != null)
            {
                // Enable step mode to allow for command execution during the debug stop
                debugger.SetDebuggerStepMode(true);

                PSCommand command = new PSCommand();

                if (shouldCollectVariables)
                {
                    // Collect variables
                    command.AddCommand("Get-PodeDumpScopedVariable");
                }
                else
                {
                    // Execute a break
                    command.AddCommand( "while( $PodeContext.Server.Suspended){ Start-sleep 1}");
                }

                // Create a collection to store the command output
                PSDataCollection<PSObject> outputCollection = new PSDataCollection<PSObject>();

                // Execute the command within the debugger
                debugger.ProcessCommand(command, outputCollection);

                // Add results to the variables collection if collecting variables
                if (shouldCollectVariables)
                {
                    foreach (var output in outputCollection)
                    {
                        variables.Add(output);
                    }
                }
                else
                {
                    // Ensure the debugger remains ready for further interaction
                    debugger.SetDebuggerStepMode(true);
                }
            }
        }


        // Method to check if the DebuggerStop event has been triggered
        public static bool IsEventTriggered()
        {
            return eventTriggered;
        }

        // Method to retrieve the collected variables
        public static PSDataCollection<PSObject> GetVariables()
        {
            return variables;
        }
    }
}
'@
}