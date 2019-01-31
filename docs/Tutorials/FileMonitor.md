# File Monitor

Pode has inbuilt support for file monitoring which can trigger an internal server restart, this occurs if Pode detects any file changes within the same directory as your server's script. To enable monitoring you can use the `-FileMonitor` switch in your [`Server`](../../Functions/Core/Server) script, or enable it through the `pode.json` configuration file:

```powershell
Server {
    # logic
} -FileMonitor
```

or:

```json
{
    "server": {
        "fileMonitor": {
            "enable": true
        }
    }
}
```

Once enabled, Pode will actively monitor all file changes within the directory of your script. Ie, if your script was at `C:/Apps/Pode/server.ps1`, then Pode will monitor the `C:/Apps/Pode` directory and all sub-directories/files for changes. When a change is detected, Pode will wait 2 seconds before triggering the restart - this is so multiple rapid changes don't trigger multiple restarts.

The file changes that are being monitored by Pode are:

* Updates
* Creation
* Deletion

!!! info
    If you change the main `Server` script itself, the changes will not be picked up. It's best to import/dot-source other modules/scripts into your `Server` script, as the internal restart re-executes this scriptblock. If you do make changes to the main server script, you'll need to terminate and restart the server.

## Include/Exclude

You can include/exclude paths/files/extensions from triggering an internal restart. To include specific paths/files you can use the `-FileMonitorInclude` parameter on your `Server`, and to exclude you can use the `-FileMonitorExclude` parameter. You can also configure them within the `pode.json` configuration file.

Both of the parameters are arrays, and the values should be patterns for paths/files/extensions - for paths, they should always be from the root directory of your server.

For example, to state that all `txt` and `ps1` files should only trigger restarts, you would do:

```powershell
Server {
    # logic
} -FileMonitor -FileMonitorInclude @('*.txt', '*.ps1')
```

or:

```json
{
    "server": {
        "fileMonitor": {
            "enable": true,
            "include": [ "*.txt", "*.ps1" ]
        }
    }
}
```

And to state that changes within the `public` directory should not trigger a restart, you would do:

```powershell
Server {
    # logic
} -FileMonitor -FileMonitorExclude @('public/*')
```

or:

```json
{
    "server": {
        "fileMonitor": {
            "enable": true,
            "exclude": [ "public/*" ]
        }
    }
}
```