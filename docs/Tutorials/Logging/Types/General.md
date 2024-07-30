
# General Logging

Pode supports general logging, allowing you to define custom logging methods and log levels. This feature enables you to write logs based on specified methods, ensuring flexibility and control over logging outputs.

To enable general logging, use the `Enable-PodeGeneralLogging` function. This function takes a hashtable defining the logging method, including a ScriptBlock for log output. You can specify various log levels to be enabled, such as Error, Emergency, Alert, Critical, Warning, Notice, Informational, Info, Verbose, and Debug.

## Enabling General Logging

To enable general logging, use the `Enable-PodeGeneralLogging` function, supplying the necessary parameters:

- `Method`: The hashtable defining the logging method, including the ScriptBlock for log output.
- `Levels`: An array of log levels to be enabled for the logging method (default includes Error, Emergency, Alert, Critical, Warning, Notice, Informational, Info, Verbose, Debug).
- `Name`: The name of the logging method to be enabled.
- `Raw`: If set, the raw log data will be included in the logging output.

### Example

```powershell
$method = New-PodeLoggingMethod -syslog -Server 127.0.0.1 -Transport UDP
$method | Enable-PodeGeneralLogging -Name "mysyslog"
```

## Disabling General Logging

To disable a general logging method, use the `Disable-PodeGeneralLogging` function with the `Name` parameter:

### Example

```powershell
Disable-PodeGeneralLogging -Name 'mysyslog'
```

With these functions, Pode ensures robust and customizable logging capabilities, allowing you to manage logs effectively based on your specific requirements.

## Writing to General Logs

Pode allows you to write logs to configured custom or inbuilt logging methods using the `Write-PodeLog` function. This function supports both custom and inbuilt logging methods, enabling structured logging with various log levels and messages.

### Writing to General Logs

To write logs, you can use the `Write-PodeLog` function with different parameters to specify the logging method, log level, message, and other details.

#### Example Usage

##### Logging an Object

To write an object to a configured logging method:

```powershell
$logItem = @{
    Date     = [datetime]::Now
    Level    = 'Informational'
    Server   = 'MyServer'
    Category = 'General'
    Message  = 'This is a log message'
    StackTrace = ''
}
$logItem | Write-PodeLog -Name 'mysyslog'
```

##### Logging with Custom Levels and Messages

To log a custom message with a specific log level:

```powershell
Write-PodeLog -Name 'mysyslog' -Level 'Error' -Message 'An error occurred.' -Tag 'MyApp'
```

In these examples, `Write-PodeLog` is used to write structured log items or custom messages to the specified logging methods, helping you maintain organized and detailed logs.
