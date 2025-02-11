# Overview

Pode offers a suite of server management operations to provide granular control over server behavior. These operations include **suspending**, **resuming**, **restarting**, and **disabling/enabling** the server. Each operation is designed to address specific use cases, such as debugging, maintenance, or load management, ensuring the server can adapt to dynamic requirements without a complete shutdown.

### Learn More About Server Operations

- [**Suspending**](./Suspending/Overview.md): Temporarily pause server activities and later restore them without a full restart.
- [**Restarting**](./Restarting/Overview.md): Multiple ways to restart the server, including file monitoring, scheduled restarts, and manual commands.
- [**Disabling**](./Disabling/Overview.md): Block or allow new incoming requests without affecting the server’s state.

---

## Configuring Allowed Actions

Pode introduces the ability to configure and control server behaviors using the `AllowedActions` section in the `server.psd1` configuration file. This feature enables fine-grained management of server operations, including suspend, restart, and disable functionality.

### Default Configuration

```powershell
@{
    Server = @{
        AllowedActions = @{
            Suspend = $true       # Enable or disable the suspend operation
            Restart = $true       # Enable or disable the restart operation
            Disable = $true       # Enable or disable the disable operation
            DisableSettings = @{
                RetryAfter = 3600                           # Default retry time (in seconds) for Disable-PodeServer
                LimitRuleName = '__Pode_Disable_Code_503__' # Name of the rate limit rule
            }
            Timeout = @{
                Suspend = 30       # Maximum seconds to wait before suspending
                Resume  = 30       # Maximum seconds to wait before resuming
            }
        }
    }
}
```

### Key Configuration Options

1. **Suspend**: Enables or disables the ability to suspend the server via `Suspend-PodeServer`.
2. **Restart**: Allows you to enable or disable server restarts.
3. **Disable**: Controls whether the server can block new incoming requests using `Disable-PodeServer`.
4. **DisableSettings**:
    - `RetryAfter`: Specifies the default retry time (in seconds) included in the `Retry-After` header when the server is disabled.
    - `LimitRuleName`: Defines the name of the rate limit rule responsible for handling `503 Service Unavailable` responses.
5. **Timeout**:
    - `Suspend`: Defines the maximum wait time (in seconds) for runspaces to suspend.
    - `Resume`: Defines the maximum wait time (in seconds) for runspaces to resume.

### Benefits of Allowed Actions

- **Customizable Behavior**: Tailor server operations to match your application’s requirements.
- **Enhanced Control**: Prevent unwanted actions like suspending or restarting during critical operations.
- **Predictability**: Enforce consistent timeouts for suspend and resume actions to avoid delays.
- **Middleware Control**: Specify a custom middleware scriptblock for handling specific scenarios, such as client retries during downtime.

---

## Monitoring the Server State

In addition to managing operations, Pode allows you to monitor the server's state using the `Get-PodeServerState` function. This command evaluates the server’s internal state and returns a status such as:

- **Starting**: The server is initializing.
- **Running**: The server is actively processing requests.
- **Suspending**: The server is pausing all activities.
- **Suspended**: The server has paused all activities and is not accepting new requests.
- **Resuming**: The server is restoring paused activities to normal operation.
- **Restarting**: The server is in the process of restarting.
- **Terminating**: The server is shutting down gracefully.
- **Terminated**: The server has fully stopped.

### Example Usage

```powershell
# Retrieve the current state of the Pode server
$state = Get-PodeServerState
Write-Output "The server is currently: $state"
```

The `Get-PodeServerState` function is especially useful for integrating server monitoring into automated workflows or debugging complex operations.
