# Custom

You can define a Custom logging Type in Pode by using [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType). Much like Requests and Errors, this function too accepts one or more logging Methods - such as the [Terminal](../../Methods/Terminal) Method.

!!! important
    The `Add-PodeLogger` function is now deprecated, please use [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType) instead.

When adding a Custom logging Type, you supply a `-ScriptBlock` plus an array of optional arguments in `-ArgumentList`. The function also requires a unique `-Name`, so that it can be referenced from [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

The ScriptBlock will be supplied with the following arguments:

1. A transformed, or raw, log item to log that was supplied via [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).
2. The arguments that were supplied from [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType)'s `-ArgumentList` parameter.

## Log Levels

The Custom logging Type uses the following log levels (Informational is the default):

* `Error`
* `Warning`
* `Informational`
* `Verbose`
* `Debug`

You can alter the log level by supplying `-Levels` to [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType) - you can supply one or more.

!!! tip
    To enable all log levels more easily, simply supply `-Levels '*'`

You can control the log level of custom log items being written, by supplying `-Level` to [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog) - Informational being the default.

## Examples

### Write to File

This example will create a Custom logging Type that will take some custom hashtable, transform it into a string, and then pass that to the inbuilt File logging Method:

```powershell
New-PodeLogFileMethod -Name 'Custom' | Add-PodeLogType -Name 'Main' -ScriptBlock {
    param($item, $arg1, $arg2)
    return "$($item.Key1), $($item.Key2), $($item.Key3)"
} -ArgumentList $arg1, $arg2

Write-PodeLog -Name 'Main' -InputObject @{
    Key1 = 'Value1'
    Key2 = 'Value2'
    Key3 = 'Value3'
}
```

### Using Raw Item

The following example uses the Terminal logging Method, and sets a Custom logging Type to return and supply the raw log item to the Terminal Method's scriptblock. The Terminal Method simply outputs the raw item to the CLI.

```powershell
New-PodeLogTerminalMethod | Add-PodeLogType -Name 'Example' -Raw

# then log to it via:
Write-PodeLog -Name 'Example' -InputObject 'This message will simply be outputted to CLI'
```

This is useful when all you're supplying to your Custom log Type is strings or other primitive value types.
