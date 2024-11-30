using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Collections.ObjectModel;

namespace Pode.Embedded
{
    public static class DebuggerHandler
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