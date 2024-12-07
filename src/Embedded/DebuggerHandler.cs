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

        // Flag to control whether variables should be collected during the DebuggerStop event
        private bool _collectVariables = true;

        // Runspace object to store the runspace that the debugger is attached to
        private readonly Runspace _runspace;

        public DebuggerHandler(Runspace runspace, bool collectVariables = true)
        {
            // Ensure the runspace is not null
            if (runspace == null)
            {
                throw new ArgumentNullException("runspace"); // Use string literal for older C# compatibility
            }

            _runspace = runspace;
            _collectVariables = collectVariables;

            // Initialize the event handler
            _debuggerStopHandler = OnDebuggerStop;
            _runspace.Debugger.DebuggerStop += _debuggerStopHandler;

            // Initialize variables collection
            Variables = new PSDataCollection<PSObject>();
            IsEventTriggered = false;
        }

        /// <summary>
        /// Detaches the DebuggerStop event handler and releases resources.
        /// </summary>
        public void Dispose()
        {
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

            // Cast the sender to a Debugger object
            var debugger = sender as Debugger;
            if (debugger == null)
            {
                return;
            }
            if (_collectVariables)
            {
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
        }
    }
}
