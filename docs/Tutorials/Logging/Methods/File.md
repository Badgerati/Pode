# File

You can log items to a file using Pode's inbuilt file Log Method, via [`New-PodeLogFileMethod`](../../../../Functions/Logging/New-PodeLogFileMethod). This allows you to define a maximum number of days to keep files, as well as a maximum file size.

!!! note
    This will convert the supplied transformed log items into a string, if it isn't one already.

!!! important
    The `New-PodeLoggingMethod` function is now deprecated, please use [`New-PodeLogFileMethod`](../../../../Functions/Logging/New-PodeLogFileMethod) instead.

By default, Pode will store all log files in a `./logs` directory at the root of your server. Each log file will be stored by day, eg: `<name>_2019-08-02_001.log`. The last `001` number specifies the log number for that day - if files are be limited by size.

## Override

You can use [`New-PodeLogFileOverride`](../../../../Functions/Logging/New-PodeLogFileOverride) to override certain properties of the File Log Method, when calling either [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog) or [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

The only option available for File is `-Ignore`, which allows you to specify that certain log items will not be logged via to File.

If you don't specify an `-Id` then the override will apply to all File Log Methods configured for a Log Type.

```powershell
# if you have an error log method configured with file and terminal logging,
# the below will only log the error to the terminal and ignore logging to file
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogFileOverride -Ignore
)
```

## Examples

### Basic

The following example will setup the file Log Method for logging Requests:

```powershell
New-PodeLogFileMethod -Name 'requests' | Enable-PodeLogRequestType
```

### Maximum Days

The following example will configure file logging to only keep a maximum number of days of logs. Ie, if you set `-MaxDays` to 4, then Pode will only store the last 4 days worth of logs.

```powershell
New-PodeLogFileMethod -Name 'requests' -MaxDays 4 | Enable-PodeLogRequestType
```

### Maximum Size

The following example will configure file logging to keep logging to a file until it reaches a maximum size. Once the size is reach, Pode will start logging to a new file; in this case, you'll see the last 3 digits increment: `001 > 002`.

In this example, the maximum size it limited to 10MB:

```powershell
New-PodeLogFileMethod -Name 'requests' -MaxSize 10MB | Enable-PodeLogRequestType
```

### Custom Path

By default Pode puts all logs in the `./logs` directory. You can use a custom path by using `-Path`:

```powershell
New-PodeLogFileMethod -Name 'requests' -Path 'E:/logs' | Enable-PodeLogRequestType
```
