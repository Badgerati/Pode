# File

You can log items to a file using Pode's inbuilt file logging logic. The inbuilt logic allows you to define a maximum number of days to keep files, as well as a maximum file size. The logic will convert any item to a string, and then write it to file.

By default, Pode will create all log files in a `./logs` directory at the root of your server. Each log file will be stored by day, eg: `<name>_2019-08-02_001.log`. The last `001` number specifies the log number for that day - if files are be limited by size.

## Examples

### Basic

The following example will setup the file logging method for logging Requests:

```powershell
New-PodeLoggingMethod -File -Name 'requests' | Enable-PodeRequestLogging
```

### Maximum Days

The following example will configure file logging to only keep a maximum number of days of logs. Ie, if you set `-MaxDays` to 4, then Pode will only store the last 4 days worth of logs.

```powershell
New-PodeLoggingMethod -File -Name 'requests' -MaxDays 4 | Enable-PodeRequestLogging
```

### Maximum Size

The following example will configure file logging to keep logging to a file until it reaches a maximum size. Once the size is reach, Pode will start logging to a new file; in this case, you'll see the last 3 digits increment: `001 > 002`.

In this example, the maximum size it limited to 10MB:

```powershell
New-PodeLoggingMethod -File -Name 'requests' -MaxSize 10MB | Enable-PodeRequestLogging
```

### Custom Path

By default Pode puts all logs in the `./logs` directory. You can use a custom path by using `-Path`:

```powershell
New-PodeLoggingMethod -File -Name 'requests' -Path 'E:/logs' | Enable-PodeRequestLogging
```

### Format

The Format parameter allows you to specify the format of the log entries. Available options are:

- RFC3164
- RFC5424
- Simple
- Default (default option)

The Simple format uses the following structure: timestamp level source message. The Default format uses the legacy Pode format.

```powershell
New-PodeLoggingMethod -File -Name 'requests' -Format 'Simple' | Enable-PodeRequestLogging
```
A log entry using the Simple format might look like this:

```arduino
2024-08-01T12:00:00Z INFO MyApp "Request received"
```

### Custom Separator
When using the Simple format, you can specify a custom separator for log entries:

```powershell
New-PodeLoggingMethod -File -Name 'requests' -Format 'Simple' -Separator ',' | Enable-PodeRequestLogging
```

A log entry using the Simple format with a comma separator might look like this:
```arduino
2024-08-01T12:00:00Z,INFO,MyApp,"Request received"
```

### Maximum Log Entry Length
The MaxLength parameter sets the maximum length of log entries. The default value is -1, which means no limit.

```powershell
New-PodeLoggingMethod -File -Name 'requests' -MaxLength 500 | Enable-PodeRequestLogging
```