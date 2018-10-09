# File Monitor

Pode has inbuilt file monitoring which can trigger an internal server restart if it detects file changes within the same directory as your Pode script. To enable the monitoring supply the `-FileMonitor` switch to your [`Server`](../../Functions/Core/Server):

```powershell
Server {
    # logic
} -FileMonitor
```

Once enabled, Pode will actively monitor all file changes within the directory of your script. Ie, if your script was at `C:/Apps/Pode/server.ps1`, then Pode will monitor the `C:/Apps/Pode` directory and sub-directories for changes. When a change is detected, Pode will wait a couple of seconds before triggering the restart; this is so multiple rapid changes don't trigger multiple restarts.

The changes that are being monitored by Pode are:

* Updates
* Creation
* Deletion

!!! info
    If you change the main server script itself, those changes will not be picked up. It's best to import/dot-source other modules/scripts into your `Server` scriptblock, as the internal restart re-executes this scriptblock. If you do make changes to the main server script, you'll need to terminate and restart the server.