using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Collections.ObjectModel;

namespace Pode.Embedded
{
    public class DebuggerHandler : IDisposable
    {
        // Collection to store variables collected during the debugging session
        public PSDataCollection<PSObject> Variables { get; private set; } = new PSDataCollection<PSObject>();

        // Event handler for the DebuggerStop event
        private EventHandler<DebuggerStopEventArgs> DebuggerStopHandler;

        // Flag to indicate whether the DebuggerStop event has been triggered
        public bool IsEventTriggered { get; private set; } = false;

        // Flag to control whether variables should be collected during the DebuggerStop event
        private bool CollectVariables = true;

        // Runspace object to store the runspace that the debugger is attached to
        private Runspace Runspace;

        public DebuggerHandler(Runspace runspace, bool collectVariables = true)
        {
            // Set the collection flag and Runspace object
            CollectVariables = collectVariables;
            Runspace = runspace;

            // Initialize the event handler with the OnDebuggerStop method
            DebuggerStopHandler = new EventHandler<DebuggerStopEventArgs>(OnDebuggerStop);
            Runspace.Debugger.DebuggerStop += DebuggerStopHandler;
        }

        // Method to detach the DebuggerStop event handler from the runspace's debugger, and general clean-up
        public void Dispose()
        {
            IsEventTriggered = false;

            // Remove the event handler to prevent further event handling
            if (DebuggerStopHandler != default(EventHandler<DebuggerStopEventArgs>))
            {
                Runspace.Debugger.DebuggerStop -= DebuggerStopHandler;
                DebuggerStopHandler = null;
            }

            // Clean-up variables
            Runspace = default(Runspace);
            Variables.Clear();

            // Garbage collection
            GC.SuppressFinalize(this);
        }

        // Event handler method that gets called when the debugger stops
        private void OnDebuggerStop(object sender, DebuggerStopEventArgs args)
        {
            // Set the eventTriggered flag to true
            IsEventTriggered = true;

            // Cast the sender to a Debugger object
            var debugger = sender as Debugger;
            if (debugger == default(Debugger))
            {
                return;
            }

            // Enable step mode to allow for command execution during the debug stop
            debugger.SetDebuggerStepMode(true);

            // Collect variables or hang the debugger
            var command = new PSCommand();
            command.AddCommand(CollectVariables
                ? "Get-PodeDumpScopedVariable"
                : "while($PodeContext.Server.Suspended) { Start-Sleep -Milliseconds 500 }");

            // Execute the command within the debugger
            var outputCollection = new PSDataCollection<PSObject>();
            debugger.ProcessCommand(command, outputCollection);

            // Add results to the variables collection if collecting variables
            if (CollectVariables)
            {
                foreach (var output in outputCollection)
                {
                    Variables.Add(output);
                }
            }
            else
            {
                // Ensure the debugger remains ready for further interaction
                debugger.SetDebuggerStepMode(true);
            }
        }
    }
}