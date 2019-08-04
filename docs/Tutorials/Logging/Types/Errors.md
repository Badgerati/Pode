# Error Logging

Pode has inbuilt Error logging logic, that parses Exceptions and ErrorRecords, and will return a valid log item for whatever method of logging you supply.

It also has support for error levels (such as Error, Warning, Verbose), with support for only allowing certain levels to be logged. By default, Error is always logged.

## Enabling

To enable and use the Error logging you use the `Enable-PodeErrorLogging` function, supplying a logging method from `New-PodeLoggingMethod`. You can supply your own errors to be logged by using `Write-PodeErrorLog`.

When Pode logs an error, the information being logged is as follows:

* `Date` - The date/time the error occurred.
* `Level` - The level of the error, such as Error or verbose.
* `Server` - The name of the machine from where the error occurred.
* `Category` - The category/type of error that was thrown.
* `Message` - The error message.
* `StackTrace` - The error StackTrace.

## Error Levels

The Error logging logic uses the following Error levels:

* `Error`
* `Warning`
* `Informational`
* `Verbose`
* `Debug`

## Examples

### Log to Terminal

The following example simply enables Error logging, and will output all items to the terminal - by default, only Error level items are logged:

```powershell
New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
```

### Log Verbose

The following example will enable Error logging, however it will log all Error levels up to Verbose, excluding Debug:

```powershell
New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Levels @('Error', 'Warning', 'Information', 'Verbose')
```

### Using Raw Item

The following example uses a Custom logging method, and sets Error logging to return and supply the raw hashtable to the Custom method's scriptblock. The Custom method simply logs the Server and Message to the terminal (but could be to something like an S3 bucket):

```powershell
$method = New-PodeLoggingMethod -Custom -ScriptBlock {
    param($item)
    "$($item.Server) - $($item.Message)" | Out-Default
}

$method | Enable-PodeErrorLogging -Raw
```

## Raw Error

The raw Error hashtable that will be supplied to any Custom logging methods will look as follows:

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
