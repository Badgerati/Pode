
## Housekeeping for Async Tasks

Housekeeping for asynchronous routes in Pode is responsible for maintaining the health and efficiency of asynchronous tasks. This process sets up a timer that periodically cleans up expired or completed asynchronous tasks, ensuring that resources are properly managed and stale tasks are removed from the context.

### Overview

The housekeeping process runs a timer, named `__pode_asyncroutes_housekeeper__`, which executes every 30 seconds by default. The primary purpose of this housekeeper is to check and handle expired or completed asynchronous routes.

### Key Features

- **Periodic Cleanup**: The housekeeper runs at a configurable interval (default is 30 seconds) to check for and clean up expired or completed tasks.
- **Automatic Disposal**: It ensures that runspaces associated with completed or expired tasks are properly disposed of, freeing up resources.
- **State Management**: Updates the state of tasks to 'Aborted' if they have expired without completing, marking them with a 'Timeout' error.
- **Retention Policy**: Completed tasks are removed based on a retention period specified in minutes. By default, tasks are retained for a specific period before being cleaned up.

### Configuration

The configuration can be done using the `server.psd1` configuration file:

```powershell
@{
    Server = @{
        HouseKeeping = @{
            AsyncRoutes = @{
                TimerInterval    = 20  # seconds
                RetentionMinutes = 5   # minutes
            }
        }
    }
}
```

The default values are:
- `TimerInterval = 30`: The interval in seconds at which the housekeeper runs to perform cleanup tasks.
- `RetentionMinutes = 10`: The duration in minutes for which completed tasks are retained before being removed.

Usually, no configuration is necessary, as the default settings are sufficient for most use cases.

**Note**: The `TimerInterval` configuration can be changed but will not be enforced until the server is restarted.

### Notes

- The housekeeper function is an internal mechanism and may change in future releases of Pode.
- The function ensures that the system remains efficient by regularly cleaning up unnecessary or stale asynchronous task data.
