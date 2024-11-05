

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
        $runspaces = Get-Runspace
        $runspaceDetails = @{}
        foreach ($r in $runspaces) {
            if ($r.Name.StartsWith('Pode_') ) {
                $runspaceDetails[$r.Name] = @{
                    Id                  = $r.Id
                    Name                = $r.Name
                    InitialSessionState = $r.InitialSessionState
                    RunspaceStateInfo   = $r.RunspaceStateInfo
                }
                $runspaceDetails[$r.Name].ScopedVariables = Get-PodeRunspaceVariablesViaDebugger -Runspace $r

            }
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
function Get-PodeRunspaceVariablesViaDebugger {
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.Runspace]$Runspace
    )

    $variables = @()
    try {
        Add-Type @'
using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Collections.ObjectModel;

public class DebuggerHandler
{
    private static PSDataCollection<PSObject> variables = new PSDataCollection<PSObject>();
    private static EventHandler<DebuggerStopEventArgs> debuggerStopHandler;
    private static bool eventTriggered = false;

    public static void AttachDebugger(Runspace runspace)
    {
        debuggerStopHandler = new EventHandler<DebuggerStopEventArgs>(OnDebuggerStop);
        runspace.Debugger.DebuggerStop += debuggerStopHandler;
    }

    public static void DetachDebugger(Runspace runspace)
    {
        if (debuggerStopHandler != null)
        {
            runspace.Debugger.DebuggerStop -= debuggerStopHandler;
            debuggerStopHandler = null;
        }
    }

    private static void OnDebuggerStop(object sender, DebuggerStopEventArgs args)
    {
        eventTriggered = true;

        var debugger = sender as Debugger;
        Console.WriteLine("Debugger stop event triggered.");
        if (debugger != null)
        {
            debugger.SetDebuggerStepMode(true);

            // Prepare the command to run in the debugger
            PSCommand command = new PSCommand();
            command.AddCommand("Get-PodeDumpScopedVariable");

            // Create output collection for ProcessCommand
            PSDataCollection<PSObject> outputCollection = new PSDataCollection<PSObject>();

            // Process the command within the debugger
            debugger.ProcessCommand(command, outputCollection);

            // Store output in a static collection
            foreach (var output in outputCollection)
            {
                variables.Add(output);
            }

            // Resume execution
      //      debugger.SetDebuggerAction(DebuggerResumeAction.Continue);
         //   Console.WriteLine("Debugger resumed.");
        }else{
          Console.WriteLine("Debugger stop event triggered, but no debugger found.");
        }

    }

    public static bool IsEventTriggered()
    {
        return eventTriggered;
    }

    public static PSDataCollection<PSObject> GetVariables()
    {
        return variables;
    }
}
'@
        # Attach the debugger using the embedded C# method
        [DebuggerHandler]::AttachDebugger($Runspace)
        #   $Runspace.Debugger.SetDebuggerStepMode($true)
        # Enable debugging and break all
        Enable-RunspaceDebug -BreakAll -Runspace $Runspace

        Write-PodeHost "Waiting for $($Runspace.Name) to enter in debug ." -NoNewLine

        # Wait for the event to be triggered
        while (! [DebuggerHandler]::IsEventTriggered()) {
            Start-Sleep -Milliseconds 1000
            Write-PodeHost '.' -NoNewLine
        }

        Write-PodeHost 'Done'
        Start-Sleep -Milliseconds 1000
        # Retrieve and output the collected variables from the embedded C# code
        $variables = [DebuggerHandler]::GetVariables()

    }
    catch {
        Write-Error -Message $_
    }
    finally {
        [DebuggerHandler]::DetachDebugger($Runspace)
        # Disable debugging for the runspace
        Disable-RunspaceDebug -Runspace $Runspace
    }

    return $variables[0]
}


function Invoke-PodeDebuggerStopEvent {
    param (
        [System.Management.Automation.Runspaces.Runspace]$Runspace
    )

    try {
        # Using reflection to get the protected RaiseDebuggerStopEvent method
        $methodInfo = $Runspace.Debugger.GetType().GetMethod('RaiseDebuggerStopEvent', [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)

        if ($null -eq $methodInfo) {
            Write-Error 'Could not find the method RaiseDebuggerStopEvent.'
            return
        }

        # Create an empty collection of breakpoints
        $breakpoints = [System.Collections.ObjectModel.Collection[System.Management.Automation.Breakpoint]]::new()

        # Set resume action to Continue
        $resumeAction = [System.Management.Automation.DebuggerResumeAction]::Stop

        # Create the DebuggerStopEventArgs
        $eventArgs = [System.Management.Automation.DebuggerStopEventArgs]::new($null, $breakpoints, $resumeAction)

        # Invoke the method
        $methodInfo.Invoke($Runspace.Debugger, @($eventArgs))

        Write-Host 'DebuggerStopEvent raised successfully.'
    }
    catch {
        Write-Error "Error invoking RaiseDebuggerStopEvent: $_"
    }
}




function Get-RunspaceFromPipeline {
    param(
        [System.Management.Automation.PowerShell]
        $Pipeline
    )

    if ($null -ne $Pipeline.Runspace) {
        return $Pipeline.Runspace
    }
    # Define BindingFlags for non-public and instance members
    $Flag = [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance

    # Access _worker field
    $_worker = $Pipeline.GetType().GetField('_worker', $Flag)
    $worker = $_worker.GetValue($Pipeline)

    # Access CurrentlyRunningPipeline property
    $_CRPProperty = $worker.GetType().GetProperty('CurrentlyRunningPipeline', $Flag)
    $currentPipeline = $_CRPProperty.GetValue($worker)

    # return Runspace
    return $currentPipeline.Runspace
}




# Function to collect variables by scope
function Get-PodeDumpScopedVariable {
    param (
        [int]
        $MaxDepth = 5  # Default max depth
    )
    # Safeguard against deeply nested objects
    function ConvertTo-SerializableObject {
        param (
            [object]$InputObject,
            [int]$MaxDepth = 5, # Default max depth
            [int]$CurrentDepth = 0
        )

        if ($CurrentDepth -ge $MaxDepth) {
            return 'Max depth reached'
        }

        if ($null -eq $InputObject ) {
            return $null
        }
        elseif (  $InputObject -is [hashtable]) {
            $result = @{}
            try {
                foreach ($key in $InputObject.Keys) {
                    try {
                        $strKey = $key.ToString()
                        $result[$strKey] = ConvertTo-SerializableObject -InputObject $InputObject[$key] -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                    }
                    catch {
                        write-podehost $_ -ForegroundColor Red
                    }
                }
            }
            catch {
                write-podehost $_ -ForegroundColor Red
            }
            return $result
        }
        elseif ($InputObject -is [PSCustomObject]) {
            $result = @{}
            try {
                foreach ($property in $InputObject.PSObject.Properties) {
                    try {
                        $result[$property.Name.ToString()] = ConvertTo-SerializableObject -InputObject $property.Value -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                    }
                    catch {
                        write-podehost $_ -ForegroundColor Red
                    }
                }
            }
            catch {
                write-podehost $_ -ForegroundColor Red
            }
            return $result
        }
        elseif ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
            return $InputObject | ForEach-Object { ConvertTo-SerializableObject -InputObject $_ -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1) }
        }
        else {
            return $InputObject.ToString()
        }
    }

    $scopes = @{
        Local  = Get-Variable -Scope 0
        Script = Get-Variable -Scope Script
        Global = Get-Variable -Scope Global
    }

    $scopedVariables = @{}
    foreach ($scope in $scopes.Keys) {
        $variables = @{}
        foreach ($var in $scopes[$scope]) {
            $variables[$var.Name] = try { $var.Value } catch { 'Error retrieving value' }
        }
        $scopedVariables[$scope] = ConvertTo-SerializableObject -InputObject $variables -MaxDepth $MaxDepth
    }
    return $scopedVariables
}

