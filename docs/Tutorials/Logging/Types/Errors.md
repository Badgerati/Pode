# Errors

Pode has an inbuilt Error Log Type, that parses and transforms Exceptions/ErrorRecords, and will return a valid log item for whatever Log Method you supply.

It also has support for error levels (such as Error, Warning, Verbose), with support for only allowing certain levels to be logged. By default the following levels are always logged if no levels are supplied: Emergency, Alert, Critical, and Error.

## Enabling

To enable the Error Log Type use [`Enable-PodeLogErrorType`](../../../../Functions/Logging/Enable-PodeLogErrorType), and supply one or more Log Methods - such as the [Terminal](../../Methods/Terminal) Method.

You can call [`Enable-PodeLogErrorType`](../../../../Functions/Logging/Enable-PodeLogErrorType) multiple times, supplying a different `-Name` for each, to enable multiple Error Log Types. When multiple are enabled, an Error will be sent to all enabled Error Log Types.

!!! note
    For backwards compatibility support: if you call `Enable-PodeLogErrorType` with no `-Name`, then a default name will be used. Subsequent `Enable-PodeLogErrorType` calls **must** supply a `-Name`.

!!! important
    The `Enable-PodeErrorLogging` function is now deprecated, please use [`Enable-PodeLogErrorType`](../../../../Functions/Logging/Enable-PodeLogErrorType) instead. The former is aliased to the latter for now.

## Custom Logic

By default, if you supply no `-ScriptBlock`, Pode will use inbuilt data selection logic on error log items. However, if you do supply a custom `-ScriptBlock` then you can select/return your own data.

This custom scriptblock will be supplied the [Log Event](../../Objects#log-event), and any arguments supplied to `-ArgumentList`, as parameters.

```powershell
Enable-PodeLogRequestType -ScriptBlock {
    param($logEvent)
    return @{
        Message = $logEvent.Data.Message
    }
}
```

!!! note
    The `$logEvent.Data` will be the same raw data as found in below in [Raw Request](#raw-request).

## Formatting

More information on formatting can be [found here](../../Formatting).

When Pode logs an error, the information logged is as follows:

| Property     | Description                                           |
| ------------ | ----------------------------------------------------- |
| `Category`   | The category/type of error that was thrown            |
| `ContextId`  | The Pode Context ID of the current request            |
| `Date`       | The date/time the error occurred                      |
| `Kind`       | The kind of the error, such as Server or Client       |
| `Level`      | The level of the error, such as Error or Verbose      |
| `Message`    | The error message                                     |
| `Server`     | The name of the machine from where the error occurred |
| `StackTrace` | The error StackTrace                                  |
| `ThreadId`   | The thread ID of the current runspace/process         |

## Log Levels

The Error Log Type uses the following log levels:

* Emergency (default)
* Alert (default)
* Critical (default)
* Error (default)
* Warning
* Notice
* Informational
* Verbose
* Debug

You can alter the log level by supplying `-Levels` to [`Enable-PodeLogErrorType`](../../../../Functions/Logging/Enable-PodeLogErrorType) - you can supply one or more.

!!! tip
    To enable all log levels more easily, simply supply `-Levels '*'`

## Error Categories

The Error Log Type uses the following error categories, the default is Server:

| Type    | Description                                                                                                      |
| ------- | ---------------------------------------------------------------------------------------------------------------- |
| Server  | Errors thrown by the server itself; unhandled exceptions; or those requests which result in an HTTP 5XX response |
| Client  | Request Errors which result in an HTTP 4XX response                                                              |
| Timeout | Request Errors which result in an HTTP 408 response                                                              |

You can alter the error categories which are logged by supplying `-Category` to [`Enable-PodeLogErrorType`](../../../../Functions/Logging/Enable-PodeLogErrorType) - you can supply one or more.

## Writing Errors

You can log additional errors by using [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog), which takes an Exception, ErrorRecord, or Message. If you log an Exception you can optionally pass `-CheckInnerException`, which will also log the inner exception.

For example, to log an error:

```powershell
try {
    # ...
}
catch {
    $_ | Write-PodeErrorLog
}
```

Or, a raw string message:

```powershell
'Some error message' | Write-PodeErrorLog -Level Warning
```

## Internal Logging

When error logging is enabled, you'll also see internal logging from Pode. Pode at present has internal Error logging, as well as Debug and Verbose logging from its various Adapters.

The internal error logging will show you unhandled exceptions from routes, middleware, etc.

## Timestamps

By default all timestamps will use the hosting server's local time, if you require the timestamps to be explicitly UTC then supply `-AsUtc` to `Enable-PodeLogErrorType`.

## Examples

### Log to Terminal

The following example enables the Error Log Type, and will output all items to the terminal - by default, only Emergency, Alert, Critical, and Error level items are logged:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogErrorType
```

### Log Multiple

The following example enables 2 Error Log Types, one with the inbuilt default name and one with a custom name:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogErrorType
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -Name 'custom-err'
```

### Log as JSON

The following example enables the Error Log Type, and will output all items to the terminal as JSON - by default, only Emergency, Alert, Critical, and Error level items are logged:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -SerialiseFormat Json
```

### Log as Syslog

The following example enables the Error Log Type, and will output all items to the terminal in Syslog format - by default, only Emergency, Alert, Critical, and Error level items are logged:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -LogFormat Syslog
```

### Log to Multiple

The following example will also enable the Error Log Type, but will output all items to the Terminal and to a File:

```powershell
$methods = @(
    New-PodeLogTerminalMethod
    New-PodeLogFileMethod -Name 'errors'
)

$methods | Enable-PodeLogErrorType
```

### Log Verbose

The following example will enable Error logging, and it will log all errors levels except Debug:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogErrorType -Levels Error, Warning, Informational, Verbose
```

### Using Raw Item

The following example uses a Custom Log Method, and sets Error logging to supply the raw log item to the Custom Method's scriptblock instead of a transformed one. The Custom Method simply logs the Server and Message to the terminal (but could be to something like an S3 bucket):

```powershell
$method = New-PodeLogCustomMethod -ScriptBlock {
    param($item)
    "$($item.Server) - $($item.Message)" | Out-Default
}

$method | Enable-PodeLogErrorType -Raw
```

## Raw Error

The raw log item that the Error Log Type will supply to any Custom Log Methods will be the following hashtable - this is also the data that will be supplied to any custom `-ScriptBlock`:

```powershell
@{
    Date       = [datetime]::Now
    Level      = 'Error'
    Server     = 'APP-VM-1'
    ContextId  = '6087a032-8e02-43ed-bbd8-e783b9839f3a'
    ThreadId   = 1
    Category   = 'InvalidOperation: (:) [], RuntimeException'
    Message    = 'You cannot call a method on a null-valued expression.'
    StackTrace = 'at <ScriptBlock>, <No file>: line 45'
}
```

## Serialise Data

If you supply your own custom `-SerialiseScriptBlock`, the following hashtable will be supplied - unless you also supply your own custom `-ScriptBlock`:

```powershell
[ordered]@{
    Date       = '2026-07-04 16:59:00'
    Level      = 'Error'
    ThreadId   = 1
    ContextId  = '6087a032-8e02-43ed-bbd8-e783b9839f3a'
    Server     = 'APP-VM-1'
    Category   = 'InvalidOperation: (:) [], RuntimeException'
    Message    = 'You cannot call a method on a null-valued expression.'
    StackTrace = 'at <ScriptBlock>, <No file>: line 45'
}
```

