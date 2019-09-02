# Overview

There are two aspects to logging in Pode: Methods and Types.

* Methods define how log items should be recorded, such as to a file or terminal.
* Types define how items to log are transformed, and what should be supplied to the Method.

For example when you supply an Exception to  [`Write-PodeErrorLog`](../../../Functions/Logging/Write-PodeErrorLog), this Exception is first supplied to Pode's inbuilt Error type. This type transforms any Exception (or Error Record) into a string which can then be supplied to the File logging method.

In Pode you can use File, Terminal or a Custom method. As well as Request, Error, or a Custom type.

This means you could write a logging method to output to an S3 bucket, Splunk, or any other logging platform.

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

For example, expanding on the above example, to keep the `Password=` text you could use the following:

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
