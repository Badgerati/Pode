using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Collections.ObjectModel;

namespace Pode.Embedded
{
    public class DebuggerHandler : IDisposable
    {
        // Collection to store variables collected during the debugging session
        public PSDataCollection<PSObject> Variables { get; private set; }

        // Event handler for the DebuggerStop event
        private EventHandler<DebuggerStopEventArgs> _debuggerStopHandler;

        // Flag to indicate whether the DebuggerStop event has been triggered
        public bool IsEventTriggered { get; private set; }

        private readonly bool _verboseEnabled; // Indicates if verbose is enabled

        // Runspace object to store the runspace that the debugger is attached to
        private readonly Runspace _runspace;

        public DebuggerHandler(Runspace runspace, bool verboseEnabled = false)
        {
            // Ensure the runspace is not null
            if (runspace == null)
            {
                throw new ArgumentNullException("runspace"); // Use string literal for older C# compatibility
            }

            _verboseEnabled = verboseEnabled;

            _runspace = runspace;

            // Initialize the event handler
            _debuggerStopHandler = OnDebuggerStop;
            _runspace.Debugger.DebuggerStop += _debuggerStopHandler;

            // Initialize variables collection
            Variables = new PSDataCollection<PSObject>();
            IsEventTriggered = false;

            WriteVerbose("DebuggerHandler initialized. Enabling debug break on all execution contexts.");

            // Enable debugging and break on all contexts
            //  EnableDebugBreakAll();
        }

        /// <summary>
        /// Enables debugging for the entire runspace and breaks on all execution contexts.
        /// </summary>
        private void EnableDebugBreakAll()
        {
            if (_runspace.Debugger.InBreakpoint)
            {
                throw new InvalidOperationException("The debugger is already active and in a breakpoint state.");
            }

            WriteVerbose("Enabling debug break on all contexts...");

            // Console.WriteLine("Enabling debugging with BreakAll mode...");
            _runspace.Debugger.SetDebugMode(DebugModes.LocalScript | DebugModes.RemoteScript);
        }


        /// <summary>
        /// Exits the debugger by processing the 'exit' command.
        /// </summary>
        private void ExitDebugger(int timeoutInSeconds = 10)
        {
            // Check if exiting the debugger is required
            if (_runspace.Debugger.InBreakpoint)
            {
                WriteVerbose("Exiting the debugger...");

                // Create a command to execute the "exit" command
                var command = new PSCommand();
                command.AddCommand("exit");

                // Execute the command within the debugger
                var outputCollection = new PSDataCollection<PSObject>();
                _runspace.Debugger.ProcessCommand(command, outputCollection);
            }
            else
            {
                throw new InvalidOperationException("The debugger is not in a breakpoint state.");
            }

            // Start a stopwatch to enforce the timeout
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();

            // Wait until debugger exits or timeout is reached
            while (_runspace.Debugger.InBreakpoint)
            {
                if (stopwatch.Elapsed.TotalSeconds >= timeoutInSeconds)
                {
                    WriteVerbose("Timeout reached while waiting for the debugger to exit.");

                    break;
                }

                System.Threading.Thread.Sleep(1000); // Wait for 1 second
            }

            stopwatch.Stop();
            WriteVerbose("ExitDebugger method completed.");
        }



        /// <summary>
        /// Detaches the DebuggerStop event handler and releases resources.
        /// </summary>
        public void Dispose()
        {

            ExitDebugger();


            if (_debuggerStopHandler != null)
            {
                _runspace.Debugger.DebuggerStop -= _debuggerStopHandler;
                _debuggerStopHandler = null;
            }

            // Clear variables and release the runspace
            Variables.Clear();
            GC.SuppressFinalize(this);
        }


        /// <summary>
        /// Event handler for the DebuggerStop event.
        /// </summary>
        private void OnDebuggerStop(object sender, DebuggerStopEventArgs args)
        {
            IsEventTriggered = true;
            WriteVerbose("DebuggerStop event triggered.");
            // Cast the sender to a Debugger object
            var debugger = sender as Debugger;
            if (debugger == null)
            {
                return;
            }

            // Enable step mode for command execution
            debugger.SetDebuggerStepMode(true);

            // Create the command to execute
            var command = new PSCommand();
            command.AddCommand("Get-PodeDumpScopedVariable");

            // Execute the command within the debugger
            var outputCollection = new PSDataCollection<PSObject>();
            debugger.ProcessCommand(command, outputCollection);

            // Collect the variables if required
            foreach (var output in outputCollection)
            {
                Variables.Add(output);
            }
        }


        private void WriteVerbose(string message)
        {
            // Check if verbose output is enabled
            if (_verboseEnabled)
            {
                Console.WriteLine($"VERBOSE: {message}");
            }
        }

    }
}