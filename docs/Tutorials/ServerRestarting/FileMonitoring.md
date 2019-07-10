# File Monitoring

Pode has support for file monitoring which can trigger the server to restart, this occurs if Pode detects any file changes within the root directory of your server. To enable file monitoring you can enable it through the `pode.json` configuration file as follows:

```json
{
    "server": {
        "fileMonitor": {
            "enable": true
        }
    }
}
```

Once enabled, Pode will actively monitor all file changes made within the root directory of your server. For example, if your server was at `C:/Apps/Pode/server.ps1`, then Pode will monitor the `C:/Apps/Pode` directory and all sub-directories/files for changes (exclusions can be configured, see below). When a change is detected, Pode will wait 2 seconds before initiating the restart - this is so multiple rapid file changes don't trigger multiple restarts.

The file changes which are being monitored by Pode are:

* Updates
* Creation
* Deletion

!!! important
    If you change the main `server` script itself, the changes will not be picked up. It's best to import/dot-source other modules/scripts into your `server` script, as the internal restart re-invokes this `scriptblock`. If you do make changes to the main server script, you'll need to terminate the server first and then restart it.

## Include/Exclude

You can include/exclude paths/files/extensions from triggering a server restart. To include/exclude specific paths/files you can configure them within the `pode.json` configuration file.

Both of the settings are arrays, and the values should be patterns for paths/files/extensions - for paths, they should always be from the root directory of your server.

For example, to state that all `txt` and `ps1` files should only trigger restarts, you would do:

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

## Show Files

You can enable the showing of what file changes triggered the server to restart. To do this, you can set the `showFiles` property in your `pode.json` file:

```json
{
    "server": {
        "fileMonitor": {
            "enable": true,
            "showFiles": true
        }
    }
}
```

Once enabled, just before a restart occurs, the following is an example of what will be visible above the `Restarting...` output in the terminal:

```plain
The following files have changed:
> [Changed] pode.json
> [Created] views/about.pode
> [Deleted] public/styles/main.css
```
