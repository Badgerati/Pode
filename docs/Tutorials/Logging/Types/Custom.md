# Custom

You can define a Custom Log Type in Pode by using [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType). Much like Requests and Errors, this function too accepts one or more Log Methods - such as the [Terminal](../../Methods/Terminal) Method.

!!! important
    The `Add-PodeLogger` function is now deprecated, please use [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType) instead. The former is aliased to the latter for now.

## Creation

When adding a Custom Log Type, you supply a `-ScriptBlock` plus an array of optional arguments in `-ArgumentList`. The function also requires a unique `-Name`, so that it can be referenced from [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

The scriptblock will be supplied with the following parameters, depending on the `-Version` supplied (default: 1)

**Version 1**

1. A raw log item that was supplied via [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).
2. The arguments that were supplied from [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType)'s `-ArgumentList` parameter.

**Version 2**

1. A [Log Event](../../Objects#log-event) object, with references to the raw data from [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog), the log Level, Timestamp, any Metadata, and the Log Type's Name.
2. The arguments that were supplied from [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType)'s `-ArgumentList` parameter.

## Formatting

More information on formatting can be [found here](../../Formatting).

## Log Levels

The Custom Log Type uses the following log levels:

* Emergency
* Alert
* Critical
* Error
* Warning
* Notice
* Informational (default)
* Verbose
* Debug

You can alter the log level by supplying `-Levels` to [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType) - you can supply one or more.

!!! tip
    To enable all log levels more easily, simply supply `-Levels '*'`

You can control the log level of custom log items being written, by supplying `-Level` to [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog) - Informational being the default.

## Examples

### Log to File

This example will create a Custom Log Type that will take some custom hashtable, transform it into a string, and then pass that to the inbuilt File Log Method:

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

### Log as JSON

This example will create a Custom Log Type that will take some custom hashtable, select appropriate data, serialise it into JSON, and then pass that to the inbuilt File Log Method. This example also uses `-Version 2` of the supplied parameters.

```powershell
New-PodeLogFileMethod -Name 'Custom' | Add-PodeLogType -Name 'Main' -Version 2 -SerialiseFormat Json -ScriptBlock {
    param($logEvent)
    return [ordered]@{
        Level     = $logEvent.Level
        Key1      = $logEvent.Data.Key1
        MergedKey = "$($logEvent.Data.Key2) & $($logEvent.Data.Key3)"
    }
}

Write-PodeLog -Name 'Main' -InputObject @{
    Key1 = 'Value1'
    Key2 = 'Value2'
    Key3 = 'Value3'
}
```

### Log as Syslog

This example will create a Custom Log Type that will take some custom hashtable, select appropriate data, convert it to Syslog format, and then pass that to the inbuilt File Log Method. This example also uses `-Version 2` of the supplied parameters.

```powershell
New-PodeLogFileMethod -Name 'Custom' | Add-PodeLogType -Name 'Main' -Version 2 -LogFormat -ScriptBlock {
    param($logEvent)
    return [ordered]@{
        Level     = $logEvent.Level
        Key1      = $logEvent.Data.Key1
        MergedKey = "$($logEvent.Data.Key2) & $($logEvent.Data.Key3)"
    }
}

Write-PodeLog -Name 'Main' -InputObject @{
    Key1 = 'Value1'
    Key2 = 'Value2'
    Key3 = 'Value3'
}
```

### Log to Multiple

The following example will also enable a Custom Log Type, but will output all items to the Terminal and to a File:

```powershell
$methods = @(
    New-PodeLogTerminalMethod
    New-PodeLogFileMethod -Name 'Custom'
)

$methods | Add-PodeLogType -Name 'Main' -ScriptBlock {
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

The following example uses the Terminal Log Method, and sets a Custom Log Type to return and supply the raw log item to the Terminal Method's scriptblock. The Terminal Method simply outputs the raw item to the CLI.

```powershell
New-PodeLogTerminalMethod | Add-PodeLogType -Name 'Example' -Raw

# then log to it via:
Write-PodeLog -Name 'Example' -InputObject 'This message will simply be outputted to CLI'
```

This is useful when all you're supplying to your Custom Log Type is strings or other primitive value types.
