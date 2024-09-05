# Overview

Logging in Pode consists of two main components: Methods and Types.

- **Methods**: Define how log items should be recorded, such as to a file, terminal, or event viewer. Each logging method operates in its own runspace, providing isolation and efficiency. The exception to this is the Custom method, which by default runs in the same runspace as the log dispatcher unless the `-UseRunspace` parameter is specified.

- **Types**: Define how log items are transformed and what data should be supplied to the Method.

When you supply an Exception to [`Write-PodeErrorLog`](../../../Functions/Logging/Write-PodeErrorLog), the Exception is first processed by Pode's built-in Error logging type. This type transforms the Exception (or Error Record) into a string format, which can then be recorded by the logging method (e.g., File).

Pode supports various logging methods, including File, Terminal, Event Viewer, Syslog, Restful, or Custom methods. Additionally, you can utilize different logging types such as Request, Error, or Custom types.

This flexibility allows you to create a custom logging method that can output logs to various platforms, such as an S3 bucket, Splunk, or any other logging service.


## Masking Values

When logging items Pode has support to mask sensitive information. This is supported in File and Terminal methods by default, but can also be supported in Custom methods via the [`Protect-PodeLogItem`](../../../Functions/Logging/Protect-PodeLogItem) function.

Information to mask is determined using RegEx defined within the `server.psd1` configuration file. You can supply multiple patterns, and even define what the mask is - the default being `********`.

!!! note
    Patterns are case-insensitive.

For example, to mask all password fields that could be logged you could use the following:

```powershell
@{
    Server = @{
        Logging = @{
            Masking = @{
                Patterns = @('Password=\w+')
            }
        }
    }
}
```

This would turn:

```plain
Username, Password=Hunter, Email
```

into

```plain
Username, ********, Email
```

Instead of masking the whole value that matches, there is support for two RegEx groups:

* `keep_before`
* `keep_after`

Specifying either of these groups in your pattern will keep the original value in place rather than masking it.

For example, expanding on the above, to keep the `Password=` text you could use the following:

```powershell
@{
    Server = @{
        Logging = @{
            Masking = @{
                Patterns = @('(?<keep_before>Password=)\w+')
            }
        }
    }
}
```

This would turn:

```plain
Username, Password=Hunter, Email
```

into

```plain
Username, Password=********, Email
```

To specify a custom mask, you can do this in the configuration file:

```powershell
@{
    Server = @{
        Logging = @{
            Masking = @{
                Patterns = @('(?<keep_before>Password=)\w+')
                Mask = '--MASKED--'
            }
        }
    }
}
```

## Batches

By default all log items are recorded one-by-one, but this can obviously become very slow if a lot of log items are being processed.

To help speed this up, you can specify a batch size on your logging method:

```powershell
New-PodeLoggingMethod -Terminal -Batch 10 | Enable-PodeRequestLogging
```

Instead of writing logs one-by-one, the above will keep transformed log items in an array. Once the array matches the batch size of 10, all items will be sent to the method at once.

This means that the method's scriptblock will receive an array of items, rather than a single item.

You can also sent a `-BatchTimeout` value, in seconds, so that if your batch size it 10 but only 5 log items are added, then after the timeout value the logs items will be sent to your method.



## Configuring Failure Actions for Log Writing

Defines the behavior in case of failure to write a log. This can happen if the disk is full, the Syslog server is offline, or if the number of logs in the queue reaches the maximum allowed. The options are:
- **Ignore** : Does nothing and continues execution. **(Default)**
- **Report** : Writes a message to the console for any failure.
- **Halt** : Writes a message to the console and shuts down the Pode server.

```powershell
New-PodeLoggingMethod -File -Path './logs' -Name 'errors' -FailureAction 'Report' | Enable-PodeRequestLogging
```

## QueueLimit
Defines the maximum number of logs allowed in the queue before throwing an event.
The default value is 500.  The exception is handled based on the `-FailureAction` parameter.

```powershell
@{
    Server = @{
        Logging = @{
            QueueLimit = 1000
        }
    }
}
```

## DataFormat
The date format to use for the log entries. The default format is `'dd/MMM/yyyy:HH:mm:ss zzz'`.

```powershell
New-PodeLoggingMethod -File -Path './logs' -Name 'access' -DataFormat 'yyyy-MM-dd HH:mm:ss' | Enable-PodeErrorLogging
```

## ISO8601
If set, the date format will be ISO 8601 compliant (equivalent to `-DataFormat 'yyyy-MM-ddTHH:mm:ssK'`). This parameter is mutually exclusive with DataFormat.

```powershell
New-PodeLoggingMethod -File -Path './logs' -Name 'access' -ISO8601 | Enable-PodeErrorLogging
```

## AsUTC
If set, the time will be logged in UTC instead of local time.

```powershell
New-PodeLoggingMethod -File -Path './logs' -Name 'access' -AsUTC -ISO8601 | Enable-PodeErrorLogging