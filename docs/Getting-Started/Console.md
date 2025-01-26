# Console Output

Pode introduces a configurable **console output** feature, enabling you to monitor server activities, control its behavior, and customize the console's appearance and functionality to suit your needs. The console displays key server information such as active endpoints, OpenAPI documentation links, and control commands.

Additionally, several console settings can be configured dynamically when starting the Pode server using the `Start-PodeServer` function.

---

## Typical Console Output

Below is an example of the console output during server runtime:

```plaintext
[2025-01-12 10:28:05] Pode [dev] (PID: 29748) [Running]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Listening on 10 endpoint(s) [4 thread(s)]:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 - HTTP  : http://localhost:8081/     [Name:General, Default]
           http://localhost:8083/     [DualMode]
           http://localhost:8091/     [Name:WS]
 - HTTPS : https://localhost:8082/
 - SMTP  : smtp://localhost:8025
 - SMTPS : smtps://localhost:8026
 - TCP   : tcp://localhost:8100
 - TCPS  : tcps://localhost:9002
 - WS    : ws://localhost:8091        [Name:WS1]
 - WSS   : wss://localhost:8093

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OpenAPI Information:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 'default':
   Specification:
     - http://localhost:8081/docs/openapi
     - http://localhost:8083/docs/openapi
     - http://localhost:8091/docs/openapi
     - https://localhost:8082/docs/openapi
   Documentation:
     - http://localhost:8081/docs
     - http://localhost:8083/docs
     - http://localhost:8091/docs
     - https://localhost:8082/docs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Server Control Commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ctrl-C  : Gracefully terminate the server.
Ctrl-R  : Restart the server and reload configurations.
Ctrl-P  : Suspend the server.
Ctrl-D  : Disable Server
Ctrl-H  : Hide Help
Ctrl-B  : Open the first HTTP endpoint in the default browser.
 ----
Ctrl-M  : Show Metrics
Ctrl-E  : Hide Endpoints
Ctrl-O  : Hide OpenAPI
Ctrl-L  : Clear the Console
Ctrl-Q  : Enable Quiet Mode
```

---

## Console Configuration

The behavior, appearance, and functionality of the console are highly customizable through the `server.psd1` configuration file. Additionally, some console-related settings can be configured dynamically via parameters in the `Start-PodeServer` function.

### Configurable Settings via `Start-PodeServer`

| **Parameter**         | **Description**                                                                                  |
|-----------------------|--------------------------------------------------------------------------------------------------|
| `DisableTermination`  | Prevents termination, suspension, or resumption of the server via keyboard interactive commands. |
| `DisableConsoleInput` | Disables all console keyboard interactions for the server.                                       |
| `ClearHost`           | Clears the console whenever the server changes state (e.g., running → suspend → resume).         |
| `Quiet`               | Suppresses all console output for a clean execution experience.                                  |
| `HideOpenAPI`         | Hides OpenAPI details such as specification and documentation URLs in the console output.        |
| `HideEndpoints`       | Hides the list of active endpoints in the console output.                                        |
| `ShowHelp`            | Displays a help menu in the console with available control commands.                             |
| `Daemon`              | Configures the server to run as a daemon with minimal console interaction and output.            |

#### Example Usage

```powershell
# Start a server with custom console settings
Start-PodeServer -HideEndpoints -HideOpenAPI -ClearHost {
    # Server logic
}
```

```powershell
# Start a server in quiet mode without console interaction
Start-PodeServer -DisableConsoleInput -Quiet {
    # Server logic
}
```

### Default Configuration

Here is the default `Server.Console` configuration:

```powershell
@{
    Server = @{
        Console = @{
            DisableTermination  = $false    # Prevent Ctrl+C from terminating the server.
            DisableConsoleInput = $false    # Disable all console input controls.
            Quiet               = $false    # Suppress console output.
            ClearHost           = $false    # Clear the console output at startup.
            ShowOpenAPI         = $true     # Display OpenAPI information.
            ShowEndpoints       = $true     # Display listening endpoints.
            ShowHelp            = $false    # Show help instructions in the console.
            ShowDivider         = $true     # Display dividers between sections.
            DividerLength       = 75        # Length of dividers in the console.
            ShowTimeStamp       = $true     # Display timestamp in the header.

            Colors              = @{            # Customize console colors.
                Header           = 'White'      # The server's header section, including the Pode version and timestamp.
                EndpointsHeader  = 'Yellow'     # The header for the endpoints list.
                Endpoints        = 'Cyan'       # The endpoints themselves, including protocol and URLs.
                OpenApiUrls      = 'Cyan'       # URLs listed under the OpenAPI information section.
                OpenApiHeaders   = 'Yellow'     # Section headers for OpenAPI information.
                OpenApiTitles    = 'White'      # The OpenAPI "default" title.
                OpenApiSubtitles = 'Yellow'     # Subtitles under OpenAPI (e.g., Specification, Documentation).
                HelpHeader       = 'Yellow'     # Header for the Help section.
                HelpKey          = 'Green'      # Key bindings listed in the Help section (e.g., Ctrl+c).
                HelpDescription  = 'White'      # Descriptions for each Help section key binding.
                HelpDivider      = 'Gray'       # Dividers used in the Help section.
                Divider          = 'DarkGray'   # Dividers between console sections.
                MetricsHeader    = 'Yellow'     # Header for the Metric section.
                MetricsLabel     = 'White'      # Labels for values displayed in the Metrics section.
                MetricsValue     = 'Green'      # The actual values displayed in the Metrics section.
            }

            KeyBindings         = @{        # Define custom key bindings for controls.
                Browser   = 'B'             # Open the default browser.
                Help      = 'H'             # Show/hide help instructions.
                OpenAPI   = 'O'             # Show/hide OpenAPI information.
                Endpoints = 'E'             # Show/hide endpoints.
                Clear     = 'L'             # Clear the console output.
                Quiet     = 'Q'             # Toggle quiet mode.
                Terminate = 'C'             # Terminate the server.
                Restart   = 'R'             # Restart the server.
                Disable   = 'D'             # Disable the server.
                Suspend   = 'P'             # Suspend the server.
                Metrics   = 'M'             # Show Metrics.
            }
        }
    }
}
```

> **Tip:** The `KeyBindings` property uses the `[System.ConsoleKey]` type. For a complete list of valid values, refer to the [ConsoleKey Enum documentation](https://learn.microsoft.com/en-us/dotnet/api/system.consolekey?view=net-9.0). This resource provides all possible keys that can be used with `KeyBindings`.

## Examples

### **Enable Quiet Mode**

Suppress all console output by enabling quiet mode via `Start-PodeServer`:

```powershell
Start-PodeServer -Quiet {
    # Server logic
}
```

### **Custom Divider Style**

Change the divider length and disable dividers via the `server.psd1` file:

```powershell
@{
    Server = @{
        Console = @{
            ShowDivider   = $false
            DividerLength = 100
             KeyBindings         = @{
                Browser   = 'D9'             # Open the default browser with the nmumber 9.
                Metrics   = 'NumPad5'             # Show Metrics with the 5 key on the numeric keypad.
                Restart   = 'F7'             # Restart the server with the F7 key.
             }
        }
    }
}
```

### **Custom Key Bindings**

Redefine the key for terminating the server:

```powershell
@{
    Server = @{
        Console = @{
            KeyBindings = @{
                Terminate = 'x'
            }
        }
    }
}
```

---

## Customizing Console Colors

The console colors are fully customizable via the `Colors` section of the configuration. Each element of the console can have its color defined using PowerShell color names. Here’s what each color setting controls:

### Color Settings

| **Key**             | **Default Value** | **Description**                                                        |
|---------------------|-------------------|------------------------------------------------------------------------|
| `Header`            | `White`           | The server's header section, including the Pode version and timestamp. |
| `EndpointsHeader`   | `Yellow`          | The header for the endpoints list.                                     |
| `Endpoints`         | `Cyan`            | The endpoints themselves, including protocol and URLs.                 |
| `EndpointsProtocol` | `White`           | The endpoints protocol.                                                |
| `EndpointsFlag`     | `Gray`            | The endpoints flags.                                                   |
| `EndpointsName`     | `Magenta`         | The endpoints name.                                                    |
| `OpenApiUrls`       | `Cyan`            | URLs listed under the OpenAPI information section.                     |
| `OpenApiHeaders`    | `Yellow`          | Section headers for OpenAPI information.                               |
| `OpenApiTitles`     | `White`           | The OpenAPI "default" title.                                           |
| `OpenApiSubtitles`  | `Yellow`          | Subtitles under OpenAPI (e.g., Specification, Documentation).          |
| `HelpHeader`        | `Yellow`          | Header for the Help section.                                           |
| `HelpKey`           | `Green`           | Key bindings listed in the Help section (e.g., `Ctrl+c`).              |
| `HelpDescription`   | `White`           | Descriptions for each Help section key binding.                        |
| `HelpDivider`       | `Gray`            | Dividers used in the Help section.                                     |
| `Divider`           | `DarkGray`        | Dividers between console sections.                                     |
| `MetricsHeader`     | `Yellow`          | Header for the Metrics section.                                        |
| `MetricsLabel`      | `White`           | Labels for values displayed in the Metrics section.                    |
| `MetricsValue`      | `Green`           | The actual values displayed in the Metrics section.                    |

> **Tip:** Test your chosen colors against your terminal's background to ensure readability.

---

## Key Features

### **1. Customizable Appearance**

- **Colors**: Define colors for headers, endpoints, dividers, and other elements.
- **Dividers**: Enable or disable dividers and adjust their length for better visual separation.

### **2. Configurable Behavior**

- **Disable Termination**: Prevent `Ctrl+C` from stopping the server.
- **Quiet Mode**: Suppress all console output for a cleaner view.
- **Timestamp Display**: Enable or disable timestamps in the console header.

### **3. Interactive Controls**

- Control server behavior using keyboard shortcuts. For example:
  - **Ctrl+C**: Gracefully terminate the server.
  - **Ctrl+R**: Restart the server.
  - **Ctrl+D**: Disable the server, preventing new requests.
  - **Ctrl+P**: Suspend the server temporarily.
  - **Ctrl+H**: Display or hide help instructions.
  - **Ctrl+M**: Display the server metrics.

### **4. OpenAPI Integration**

- Automatically display links to OpenAPI specifications and documentation for the active endpoints.

### **5. Enhanced Visibility**

- Use colors to highlight key sections, such as endpoints or OpenAPI URLs, improving readability.

## Examples

### **Change Header and Endpoint Colors**

```powershell
@{
    Colors = @{
        Header          = 'Green'
        Endpoints       = 'Magenta'
        EndpointsHeader = 'Blue'
    }
}
```

### **Match Dark Background Themes**

Use colors that contrast well with dark themes:

```powershell
@{
    Colors = @{
        Header          = 'Gray'
        Endpoints       = 'BrightCyan'
        OpenApiUrls     = 'BrightYellow'
        Divider         = 'Gray'
    }
}
```

### **Minimalist Setup**

Reduce the use of vibrant colors for a subtle appearance:

```powershell
@{
    Colors = @{
        Header          = 'White'
        Endpoints       = 'White'
        OpenApiUrls     = 'White'
        Divider         = 'White'
    }
}
```

### **Change Metrics Section Colors**

```powershell
@{
    Colors = @{
        MetricsHeader = 'Blue'   # Change the header color to Blue
        MetricsLabel  = 'Gray'   # Use Gray for the value labels
        MetricsValue  = 'Red'    # Display metric values in Red
    }
}
```
