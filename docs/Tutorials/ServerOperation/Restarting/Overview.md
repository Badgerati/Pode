# Overview

There are 4 ways to restart a running Pode server:

1. **Ctrl+R**: If you press `Ctrl+R` on a running server, it will trigger a restart to take place.
    1a. On Unix you can use `Shift+R`.
2. [**File Monitoring**](../Types/FileMonitoring): This will watch for file changes, and if enabled will trigger the server to restart.
3. [**Auto-Restarting**](../Types/AutoRestarting): Defined within the `server.psd1` configuration file, you can set schedules for the server to automatically restart.
4. [`Restart-PodeServer`](../../../Functions/Core/Restart-PodeServer): This function lets you manually restart Pode from within the server.

When the server restarts, it will re-invoke the `-ScriptBlock` supplied to the [`Start-PodeServer`](../../../Functions/Core/Start-PodeServer) function. This means the best approach to reload new modules/scripts it to dot-source/[`Use-PodeScript`](../../../Functions/Utilities/Use-PodeScript) your scripts into your server, as any changes to the main `scriptblock` will **not** take place.

Certainly! Here’s an explanation on how to achieve suspending and resuming a Pode server using [`Suspend-PodeServer`](../../../Functions/Core/Resume-PodeServer) and [`Resume-PodeServer`](../../../Functions/Core/Suspend-PodeServer).
