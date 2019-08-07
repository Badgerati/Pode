# Overview

There are 3 ways to restart a running Pode server:

1. **Ctrl+R**: If you press `Ctrl+R` on a running server, it will trigger a restart to take place.
2. [**File Monitoring**](../Types/FileMonitoring): This will watch for file changes, and if enabled will trigger the server to restart.
3. [**Auto-Restarting**](../Types/AutoRestarting): Defined within the `server.psd1` configuration file, you can set schedules for the server to automatically restart.

When the server restarts, it will re-invoke the `scripblock` supplied to the `Start-PodeServer` function. This means the best approach to reload new modules/scripts it to dot-source your scripts into your server, as any changes to the main `scriptblock` will **not** take place.
