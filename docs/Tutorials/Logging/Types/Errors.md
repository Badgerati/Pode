# Errors

Pode has an inbuilt Error logging Type, that parses and transforms Exceptions/ErrorRecords, and will return a valid log item for whatever logging Method you supply.

It also has support for error levels (such as Error, Warning, Verbose), with support for only allowing certain levels to be logged. By default, Error is always logged if no levels are supplied.

## Enabling

To enable and use the Error logging Type you use [`Enable-PodeErrorLogging`](../../../../Functions/Logging/Enable-PodeErrorLogging), supplying a logging Method - such as the [Terminal](../../Methods/Terminal) Method.

When Pode logs an error, the information being logged is as follows:

| Property     | Description                                           |
| ------------ | ----------------------------------------------------- |
| `Date`       | The date/time the error occurred                      |
| `Level`      | The level of the error, such as Error or verbose      |
| `Server`     | The name of the machine from where the error occurred |
| `Category`   | The category/type of error that was thrown            |
| `Message`    | The error message                                     |
| `StackTrace` | The error StackTrace                                  |

## Error Levels

The Error logging logic uses the following Error levels (Error is the default):

* `Error`
* `Warning`
* `Informational`
* `Verbose`
* `Debug`

## Writing Errors

You can log additional errors by using [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog), which takes an Exception or an ErrorRecord (both of which can be piped). If you log an Exception you can optionally pass `-CheckInnerException`, which will also log the inner exception.

For example, to log an error:

```powershell
try {
    # ...
}
catch {
    $_ | Write-PodeErrorLog
}
```

To log an error at a different level, you can also supply a `-Level`.

## Internal Logging

When error logging is enabled, you'll start to also see internal logging from Pode. Pode at present has internal Error logging, as well as Debug and Verbose logging from its various Adapters.

The internal error logging will show you unhandled exceptions from routes, middleware, etc.

## Examples

### Log to Terminal

The following example simply enables Error logging, and will output all items to the terminal - by default, only Error level items are logged:

```powershell
New-PodeLogTerminalMethod | Enable-PodeErrorLogging
```

### Log Verbose

The following example will enable Error logging, and it will log all errors levels except Debug:

```powershell
New-PodeLogTerminalMethod | Enable-PodeErrorLogging -Levels Error, Warning, Informational, Verbose
```

### Using Raw Item

The following example uses a Custom logging Method, and sets Error logging to return and supply the raw log item to the Custom Method's scriptblock. The Custom Method simply logs the Server and Message to the terminal (but could be to something like an S3 bucket):

```powershell
$method = New-PodeLogCustomMethod -ScriptBlock {
    param($item)
    "$($item.Server) - $($item.Message)" | Out-Default
}

$method | Enable-PodeErrorLogging -Raw
```

## Raw Error

The raw log item that the Error log Type will supply to any Custom logging Methods will look as follows:

```powershell
@{
    Date = [datetime]::Now
    Level = 'Error'
    Server = 'ComputerName'
    Category = 'InvalidOperation: (:) [], RuntimeException'
    Message = 'You cannot call a method on a null-valued expression.'
    StackTrace = 'at <ScriptBlock>, <No file>: line 45'
}
```
