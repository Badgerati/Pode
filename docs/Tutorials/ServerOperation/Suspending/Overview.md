# Overview

In addition to restarting, Pode provides a way to temporarily **suspend** and **resume** the server, allowing you to pause all activities and connections without completely stopping the server. This can be especially useful for debugging, troubleshooting, or performing maintenance tasks where you don’t want to fully restart the server.

## Suspending

To suspend a running Pode server, use the `Suspend-PodeServer` function. This function will pause all active server runspaces, effectively putting the server into a suspended state. Here’s how to do it:

1. **Run the Suspension Command**:
   - Simply call `Suspend-PodeServer` from within your Pode environment or script.

   ```powershell
   Suspend-PodeServer -Timeout 60
   ```

   The `-Timeout` parameter specifies how long the function should wait (in seconds) for each runspace to be fully suspended. This is optional, with a default timeout of 30 seconds.

2. **Suspension Process**:
   - When you run `Suspend-PodeServer`, Pode will:
     - Pause all runspaces associated with the server, putting them into a debug state.
     - Trigger a "Suspend" event to signify that the server is paused.
     - Update the server’s status to reflect that it is now suspended.

3. **Outcome**:
   - After suspension, all server operations are halted, and the server will not respond to incoming requests until it is resumed.

## Resuming

Once you’ve completed any tasks or troubleshooting, you can resume the server using `Resume-PodeServer`. This will restore the Pode server to its normal operational state:

1. **Run the Resume Command**:
   - Call `Resume-PodeServer` to bring the server back online.

   ```powershell
   Resume-PodeServer
   ```

2. **Resumption Process**:
   - When `Resume-PodeServer` is executed, Pode will:
     - Restore all paused runspaces back to their active states.
     - Trigger a "Resume" event, marking the server as active again.
     - Clear the console, providing a refreshed view of the server status.

3. **Outcome**:
   - The server resumes normal operations and can now handle incoming requests again.

## When to Use Suspend and Resume

These functions are particularly useful when:

- **Debugging**: If you encounter an issue, you can pause the server to inspect state or troubleshoot without a full restart.
- **Maintenance**: Suspend the server briefly during configuration changes, and then resume when ready.
- **Performance Management**: Temporarily pause during high load or for throttling purposes if required by your application logic.
